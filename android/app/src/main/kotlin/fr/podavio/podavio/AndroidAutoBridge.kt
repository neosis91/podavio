package fr.podavio.podavio

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Pont MethodChannel entre Flutter et [PodavioMediaBrowserService].
 *
 * - [CHANNEL_TO_DART] : natif → Flutter (browse / commandes)
 * - [CHANNEL_TO_HOST] : Flutter → natif (état de lecture pour la session Auto)
 */
object AndroidAutoBridge {
    const val CHANNEL_TO_DART = "fr.podavio.podavio/android_auto"
    const val CHANNEL_TO_HOST = "fr.podavio.podavio/android_auto_host"
    const val ENGINE_ID = "podavio_engine"

    @Volatile
    private var service: PodavioMediaBrowserService? = null

    fun registerService(service: PodavioMediaBrowserService) {
        this.service = service
    }

    fun unregisterService(service: PodavioMediaBrowserService) {
        if (this.service === service) this.service = null
    }

    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_TO_HOST)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updatePlaybackState" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<*, *>
                        if (args != null) {
                            service?.applyPlaybackState(args)
                            // No-op tant que le pont montre n’est pas compilé.
                            runCatching { WearPlaybackFanout.dispatch?.invoke(args) }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
