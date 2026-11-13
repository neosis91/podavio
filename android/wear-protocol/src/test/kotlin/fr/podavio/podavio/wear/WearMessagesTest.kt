package fr.podavio.podavio.wear

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull

class WearMessagesTest {
    @Test
    fun commandsRoundTrip() {
        val cases =
            listOf(
                WearCommand(WearCommands.PLAY, null, "1"),
                WearCommand(WearCommands.PAUSE, null, "2"),
                WearCommand(WearCommands.SKIP_FORWARD, null, "3"),
                WearCommand(WearCommands.SKIP_BACK, null, "4"),
                WearCommand(WearCommands.SEEK, "12000", "5"),
                WearCommand(WearCommands.GET_CHILDREN, WearFolders.ROOT, "6"),
                WearCommand(WearCommands.PLAY_FROM_MEDIA_ID, "episode:12", "7"),
            )
        for (command in cases) {
            assertEquals(command, WearCodec.decodeCommand(WearCodec.encodeCommand(command)))
        }
    }

    @Test
    fun commandNamesMatchTheAutoChannel() {
        assertEquals(
            listOf(
                "play",
                "pause",
                "skipForward",
                "skipBack",
                "seek",
                "getChildren",
                "playFromMediaId",
            ),
            WearCommands.all,
        )
    }

    @Test
    fun browseFoldersArePlaylistUnreadDownloads() {
        assertEquals(listOf("queue", "unread", "downloads"), WearFolders.browse)
        for (folder in WearFolders.browse) {
            val command = WearCommand(WearCommands.GET_CHILDREN, folder, "9")
            assertEquals(folder, WearCodec.decodeCommand(WearCodec.encodeCommand(command)).argument)
        }
    }

    @Test
    fun rootChildrenKeepThePhoneFolderContract() {
        val rows =
            listOf(
                mapOf(
                    "id" to "queue",
                    "title" to "Playlist",
                    "subtitle" to "Épisodes en file",
                    "playable" to false,
                ),
                mapOf(
                    "id" to "unread",
                    "title" to "Non lus",
                    "subtitle" to "Boîte de réception",
                    "playable" to false,
                ),
                mapOf(
                    "id" to "downloads",
                    "title" to "Téléchargements",
                    "subtitle" to "Épisodes hors ligne",
                    "playable" to false,
                ),
            )
        val items = wearItemsFromMaps(rows)
        assertEquals(WearFolders.browse, items.map { it.id })
        assertEquals(listOf(false, false, false), items.map { it.playable })
        assertEquals("Playlist", items[0].title)
        assertEquals("Non lus", items[1].title)
        assertEquals("Téléchargements", items[2].title)

        val reply = WearReply("7", ok = true, items = items)
        assertEquals(reply, WearCodec.decodeReply(WearCodec.encodeReply(reply)))
    }

    @Test
    fun episodeRowsStayPlayableAndQuotesRoundTrip() {
        val rows =
            listOf(
                mapOf(
                    "id" to "episode:12",
                    "title" to "Un \"titre\"\nligne",
                    "subtitle" to "Podcast \\ essai",
                    "playable" to true,
                    "artworkUri" to "https://example.test/cover.jpg",
                ),
            )
        val items = wearItemsFromMaps(rows)
        assertEquals(true, items.single().playable)
        val reply = WearReply("8", ok = true, items = items)
        val decoded = WearCodec.decodeReply(WearCodec.encodeReply(reply))
        assertEquals(items, decoded.items)
        assertEquals("episode:12", decoded.items.single().id)
    }

    @Test
    fun playbackStateUsesTheAutoFields() {
        val raw =
            mapOf(
                "hasEpisode" to true,
                "playing" to true,
                "title" to "Épisode",
                "artist" to "Le podcast",
                "artworkUri" to "https://example.test/cover.jpg",
                "positionMs" to 1500,
                "durationMs" to 90_000,
            )
        val state = wearStateFromMap(raw)
        assertEquals(true, state.hasEpisode)
        assertEquals(true, state.playing)
        assertEquals("Épisode", state.title)
        assertEquals("Le podcast", state.artist)
        assertEquals(1500L, state.positionMs)
        assertEquals(90_000L, state.durationMs)
        assertEquals(state, WearCodec.decodeState(WearCodec.encodeState(state)))
    }

    @Test
    fun idleStateRoundTrips() {
        val state =
            WearState(
                hasEpisode = false,
                playing = false,
                title = "",
                artist = "",
                positionMs = 0,
                durationMs = 0,
            )
        assertEquals(state, WearCodec.decodeState(WearCodec.encodeState(state)))
    }

    @Test
    fun brokenPayloadsAreRejected() {
        assertFailsWith<IllegalArgumentException> {
            WearCodec.decodeCommand("{}".encodeToByteArray())
        }
        assertFailsWith<IllegalArgumentException> {
            WearCodec.decodeCommand("".encodeToByteArray())
        }
        assertFailsWith<IllegalArgumentException> {
            WearCodec.decodeState("[]".encodeToByteArray())
        }
    }

    @Test
    fun commandWithoutArgumentStaysNull() {
        val decoded = WearCodec.decodeCommand(WearCodec.encodeCommand(WearCommand("pause", null, "1")))
        assertNull(decoded.argument)
    }

    @Test
    fun pathsStayOnThePodavioPrefix() {
        assertEquals("/podavio/command", WearPaths.COMMAND)
        assertEquals("/podavio/reply", WearPaths.REPLY)
        assertEquals("/podavio/state", WearPaths.STATE)
        assertEquals("podavio_phone", WearPaths.PHONE)
        assertEquals("podavio_watch", WearPaths.WATCH)
        assertEquals("hint:open", WearFolders.HINT_OPEN)
    }
}
