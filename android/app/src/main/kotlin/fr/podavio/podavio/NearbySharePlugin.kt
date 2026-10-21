package fr.podavio.podavio

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Expose le chemin de l’APK installé et la présence de splits (Play Store).
 */
object NearbySharePlugin {
    const val CHANNEL = "fr.podavio.podavio/nearby_share"

    fun attach(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstallApkInfo" -> {
                    try {
                        result.success(installApkInfo(context))
                    } catch (e: Exception) {
                        result.error("apk_info", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun installApkInfo(context: Context): Map<String, Any?> {
        val pm = context.packageManager
        val info: ApplicationInfo = if (android.os.Build.VERSION.SDK_INT >= 33) {
            pm.getApplicationInfo(
                context.packageName,
                PackageManager.ApplicationInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            pm.getApplicationInfo(context.packageName, 0)
        }
        val splits = info.splitSourceDirs
        val hasSplits = splits != null && splits.isNotEmpty()
        return mapOf(
            "sourceDir" to info.sourceDir,
            "hasSplits" to hasSplits,
        )
    }
}
