package fr.podavio.podavio

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.MediaDescriptionCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import androidx.media.MediaBrowserServiceCompat
import androidx.media.utils.MediaConstants
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Expose la bibliothèque Podavio à Android Auto (browse + session de contrôle).
 * La lecture réelle reste côté Flutter (`just_audio` + flutter_media_session).
 */
class PodavioMediaBrowserService : MediaBrowserServiceCompat() {
    private lateinit var session: MediaSessionCompat
    private val mainHandler = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null

    override fun onCreate() {
        super.onCreate()
        session = MediaSessionCompat(this, "PodavioAuto").apply {
            setFlags(
                MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                    MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS,
            )
            setCallback(SessionCallback())
            setPlaybackState(
                PlaybackStateCompat.Builder()
                    .setActions(BASE_ACTIONS)
                    .setState(PlaybackStateCompat.STATE_NONE, 0, 1f)
                    .build(),
            )
            isActive = true
        }
        sessionToken = session.sessionToken
        AndroidAutoBridge.registerService(this)
        ensureChannel()
    }

    override fun onDestroy() {
        AndroidAutoBridge.unregisterService(this)
        session.isActive = false
        session.release()
        super.onDestroy()
    }

    override fun onGetRoot(
        clientPackageName: String,
        clientUid: Int,
        rootHints: Bundle?,
    ): BrowserRoot {
        val extras = Bundle().apply {
            putInt(
                MediaConstants.DESCRIPTION_EXTRAS_KEY_CONTENT_STYLE_BROWSABLE,
                MediaConstants.DESCRIPTION_EXTRAS_VALUE_CONTENT_STYLE_LIST_ITEM,
            )
            putInt(
                MediaConstants.DESCRIPTION_EXTRAS_KEY_CONTENT_STYLE_PLAYABLE,
                MediaConstants.DESCRIPTION_EXTRAS_VALUE_CONTENT_STYLE_LIST_ITEM,
            )
        }
        return BrowserRoot(ROOT_ID, extras)
    }

    override fun onLoadChildren(
        parentId: String,
        result: Result<MutableList<MediaBrowserCompat.MediaItem>>,
    ) {
        result.detach()
        mainHandler.post {
            val ch = ensureChannel()
            if (ch == null) {
                result.sendResult(mutableListOf(hintOpenAppItem()))
                return@post
            }
            ch.invokeMethod(
                "getChildren",
                parentId,
                object : MethodChannel.Result {
                    override fun success(value: Any?) {
                        @Suppress("UNCHECKED_CAST")
                        val rows = value as? List<Map<String, Any?>> ?: emptyList()
                        result.sendResult(rows.map { toMediaItem(it) }.toMutableList())
                    }

                    override fun error(code: String, message: String?, details: Any?) {
                        Log.w(TAG, "getChildren($parentId) error: $code $message")
                        result.sendResult(mutableListOf())
                    }

                    override fun notImplemented() {
                        result.sendResult(mutableListOf(hintOpenAppItem()))
                    }
                },
            )
        }
    }

    fun applyPlaybackState(args: Map<*, *>) {
        val title = args["title"] as? String ?: ""
        val artist = args["artist"] as? String ?: ""
        val artworkUri = args["artworkUri"] as? String
        val durationMs = (args["durationMs"] as? Number)?.toLong() ?: 0L
        val positionMs = (args["positionMs"] as? Number)?.toLong() ?: 0L
        val playing = args["playing"] as? Boolean ?: false
        val hasEpisode = args["hasEpisode"] as? Boolean ?: false

        if (hasEpisode) {
            val meta = MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
                .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, artist)
                .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durationMs)
            if (!artworkUri.isNullOrBlank()) {
                meta.putString(MediaMetadataCompat.METADATA_KEY_ALBUM_ART_URI, artworkUri)
                meta.putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_ICON_URI, artworkUri)
            }
            session.setMetadata(meta.build())
        }

        val state = when {
            !hasEpisode -> PlaybackStateCompat.STATE_NONE
            playing -> PlaybackStateCompat.STATE_PLAYING
            else -> PlaybackStateCompat.STATE_PAUSED
        }
        session.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(BASE_ACTIONS)
                .setState(state, positionMs, if (playing) 1f else 0f)
                .build(),
        )
    }

    private fun ensureChannel(): MethodChannel? {
        channel?.let { return it }
        val engine = obtainEngine() ?: return null
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, AndroidAutoBridge.CHANNEL_TO_DART)
        return channel
    }

    private fun obtainEngine(): FlutterEngine? {
        return FlutterEngineCache.getInstance().get(AndroidAutoBridge.ENGINE_ID)
    }

    private fun invokeDart(method: String, args: Any? = null) {
        mainHandler.post {
            val ch = ensureChannel() ?: return@post
            ch.invokeMethod(method, args)
        }
    }

    private inner class SessionCallback : MediaSessionCompat.Callback() {
        override fun onPlay() = invokeDart("play")
        override fun onPause() = invokeDart("pause")
        override fun onStop() = invokeDart("pause")
        override fun onSkipToNext() = invokeDart("skipForward")
        override fun onSkipToPrevious() = invokeDart("skipBack")
        override fun onSeekTo(pos: Long) = invokeDart("seek", pos)
        override fun onPlayFromMediaId(mediaId: String?, extras: Bundle?) {
            if (mediaId.isNullOrBlank()) return
            invokeDart("playFromMediaId", mediaId)
        }
        override fun onFastForward() = invokeDart("skipForward")
        override fun onRewind() = invokeDart("skipBack")
    }

    companion object {
        private const val TAG = "PodavioAuto"
        const val ROOT_ID = "root"

        private const val BASE_ACTIONS =
            PlaybackStateCompat.ACTION_PLAY or
                PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_PLAY_PAUSE or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                PlaybackStateCompat.ACTION_SEEK_TO or
                PlaybackStateCompat.ACTION_FAST_FORWARD or
                PlaybackStateCompat.ACTION_REWIND or
                PlaybackStateCompat.ACTION_PLAY_FROM_MEDIA_ID

        private fun hintOpenAppItem(): MediaBrowserCompat.MediaItem {
            val desc = MediaDescriptionCompat.Builder()
                .setMediaId("hint:open")
                .setTitle("Ouvrez Podavio sur le téléphone")
                .setSubtitle("Puis choisissez un épisode")
                .build()
            return MediaBrowserCompat.MediaItem(
                desc,
                MediaBrowserCompat.MediaItem.FLAG_BROWSABLE,
            )
        }

        private fun toMediaItem(row: Map<String, Any?>): MediaBrowserCompat.MediaItem {
            val id = row["id"] as? String ?: ""
            val title = row["title"] as? String ?: ""
            val subtitle = row["subtitle"] as? String
            val playable = row["playable"] as? Boolean ?: false
            val artworkUri = row["artworkUri"] as? String
            val builder = MediaDescriptionCompat.Builder()
                .setMediaId(id)
                .setTitle(title)
            if (!subtitle.isNullOrBlank()) builder.setSubtitle(subtitle)
            if (!artworkUri.isNullOrBlank()) {
                builder.setIconUri(android.net.Uri.parse(artworkUri))
            }
            val flags = if (playable) {
                MediaBrowserCompat.MediaItem.FLAG_PLAYABLE
            } else {
                MediaBrowserCompat.MediaItem.FLAG_BROWSABLE
            }
            return MediaBrowserCompat.MediaItem(builder.build(), flags)
        }
    }
}
