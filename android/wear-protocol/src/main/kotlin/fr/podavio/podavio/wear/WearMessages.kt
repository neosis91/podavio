package fr.podavio.podavio.wear

/** Chemins MessageClient et capacités partagés par le téléphone et la montre. */
object WearPaths {
    const val COMMAND = "/podavio/command"
    const val REPLY = "/podavio/reply"
    const val STATE = "/podavio/state"
    const val PHONE = "podavio_phone"
    const val WATCH = "podavio_watch"
}

/** Méthodes du canal `fr.podavio.podavio/android_auto`. */
object WearCommands {
    const val PLAY = "play"
    const val PAUSE = "pause"
    const val SKIP_FORWARD = "skipForward"
    const val SKIP_BACK = "skipBack"
    const val SEEK = "seek"
    const val GET_CHILDREN = "getChildren"
    const val PLAY_FROM_MEDIA_ID = "playFromMediaId"

    val all =
        listOf(
            PLAY,
            PAUSE,
            SKIP_FORWARD,
            SKIP_BACK,
            SEEK,
            GET_CHILDREN,
            PLAY_FROM_MEDIA_ID,
        )
}

/** Dossiers déjà exposés par Android Auto. Les titres viennent du téléphone. */
object WearFolders {
    const val ROOT = "root"
    const val QUEUE = "queue"
    const val UNREAD = "unread"
    const val DOWNLOADS = "downloads"
    const val HINT_OPEN = "hint:open"

    val browse = listOf(QUEUE, UNREAD, DOWNLOADS)
}

data class WearCommand(
    val name: String,
    val argument: String? = null,
    val requestId: String,
)

data class WearItem(
    val id: String,
    val title: String,
    val subtitle: String = "",
    val playable: Boolean = false,
)

data class WearReply(
    val requestId: String,
    val ok: Boolean,
    val items: List<WearItem> = emptyList(),
)

data class WearState(
    val hasEpisode: Boolean,
    val playing: Boolean,
    val title: String,
    val artist: String,
    val positionMs: Long,
    val durationMs: Long,
)

object WearCodec {
    fun encodeCommand(command: WearCommand): ByteArray {
        val json =
            buildString {
                append("{\"requestId\":")
                append(jsonQuote(command.requestId))
                append(",\"name\":")
                append(jsonQuote(command.name))
                if (command.argument != null) {
                    append(",\"argument\":")
                    append(jsonQuote(command.argument))
                }
                append('}')
            }
        return json.toByteArray(Charsets.UTF_8)
    }

    fun decodeCommand(bytes: ByteArray): WearCommand {
        val map = jsonObject(bytes)
        val name = map["name"] as? String ?: throw IllegalArgumentException("name")
        val requestId = map["requestId"] as? String ?: throw IllegalArgumentException("requestId")
        val argument = map["argument"] as? String
        return WearCommand(name, argument, requestId)
    }

    fun encodeReply(reply: WearReply): ByteArray {
        val json =
            buildString {
                append("{\"requestId\":")
                append(jsonQuote(reply.requestId))
                append(",\"ok\":")
                append(if (reply.ok) "true" else "false")
                append(",\"items\":[")
                reply.items.forEachIndexed { index, item ->
                    if (index > 0) append(',')
                    append("{\"id\":")
                    append(jsonQuote(item.id))
                    append(",\"title\":")
                    append(jsonQuote(item.title))
                    append(",\"subtitle\":")
                    append(jsonQuote(item.subtitle))
                    append(",\"playable\":")
                    append(if (item.playable) "true" else "false")
                    append('}')
                }
                append("]}")
            }
        return json.toByteArray(Charsets.UTF_8)
    }

    fun decodeReply(bytes: ByteArray): WearReply {
        val map = jsonObject(bytes)
        val requestId = map["requestId"] as? String ?: throw IllegalArgumentException("requestId")
        val items =
            (map["items"] as? List<*>).orEmpty().mapNotNull { row ->
                val item = row as? Map<*, *> ?: return@mapNotNull null
                val id = item["id"] as? String ?: return@mapNotNull null
                WearItem(
                    id = id,
                    title = item["title"] as? String ?: "",
                    subtitle = item["subtitle"] as? String ?: "",
                    playable = item["playable"] == true,
                )
            }
        return WearReply(requestId, map["ok"] == true, items)
    }

    fun encodeState(state: WearState): ByteArray {
        val json =
            buildString {
                append("{\"hasEpisode\":")
                append(if (state.hasEpisode) "true" else "false")
                append(",\"playing\":")
                append(if (state.playing) "true" else "false")
                append(",\"title\":")
                append(jsonQuote(state.title))
                append(",\"artist\":")
                append(jsonQuote(state.artist))
                append(",\"positionMs\":")
                append(state.positionMs)
                append(",\"durationMs\":")
                append(state.durationMs)
                append('}')
            }
        return json.toByteArray(Charsets.UTF_8)
    }

    fun decodeState(bytes: ByteArray): WearState = wearStateFromMap(jsonObject(bytes))

    private fun jsonObject(bytes: ByteArray): Map<*, *> {
        val value = WearJson.parse(bytes)
        return value as? Map<*, *> ?: throw IllegalArgumentException("object")
    }
}

/** Lignes renvoyées par `getChildren` sur le canal Android Auto. */
fun wearItemsFromMaps(rows: List<*>): List<WearItem> {
    return rows.mapNotNull { row ->
        val map = row as? Map<*, *> ?: return@mapNotNull null
        val id = map["id"]?.toString() ?: return@mapNotNull null
        WearItem(
            id = id,
            title = map["title"]?.toString() ?: "",
            subtitle = map["subtitle"]?.toString() ?: "",
            playable = map["playable"] == true,
        )
    }
}

/** Charge utile de `updatePlaybackState`. `artist` est le titre du podcast. */
fun wearStateFromMap(map: Map<*, *>): WearState {
    return WearState(
        hasEpisode = map["hasEpisode"] == true,
        playing = map["playing"] == true,
        title = map["title"]?.toString().orEmpty(),
        artist = map["artist"]?.toString().orEmpty(),
        positionMs = longOf(map["positionMs"]),
        durationMs = longOf(map["durationMs"]),
    )
}

private fun longOf(value: Any?): Long =
    when (value) {
        is Long -> value
        is Int -> value.toLong()
        is Number -> value.toLong()
        is String -> value.toLongOrNull() ?: 0L
        else -> 0L
    }
