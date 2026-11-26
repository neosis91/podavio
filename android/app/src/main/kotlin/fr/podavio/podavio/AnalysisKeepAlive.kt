package fr.podavio.podavio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Vrai tant qu’une analyse doit survivre à la fermeture de l’activité.
 * [MainActivity] s’en sert pour ne pas détruire le moteur Flutter.
 */
object AnalysisKeepAlive {
    @Volatile
    var active: Boolean = false

    @Volatile
    var activityCount: Int = 0

    /// L’activité est déjà partie et plus rien ne tourne : le moteur gardé
    /// pour l’analyse n’a plus de raison de rester.
    fun releaseIfIdle() {
        if (active || activityCount > 0) return
        val cache = FlutterEngineCache.getInstance()
        val engine = cache.get(AndroidAutoBridge.ENGINE_ID) ?: return
        cache.remove(AndroidAutoBridge.ENGINE_ID)
        engine.destroy()
    }
}

object AnalysisPlugin {
    const val CHANNEL = "fr.podavio.podavio/analysis_keepalive"

    fun attach(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    AnalysisKeepAlive.active = true
                    val intent = Intent(context, AnalysisService::class.java)
                        .putExtra(AnalysisService.EXTRA_TITLE, call.argument<String>("title"))
                        .putExtra(AnalysisService.EXTRA_CHANNEL, call.argument<String>("channel"))
                    ContextCompat.startForegroundService(context, intent)
                    result.success(null)
                }
                "stop" -> {
                    AnalysisKeepAlive.active = false
                    context.stopService(Intent(context, AnalysisService::class.java))
                    result.success(null)
                    Handler(Looper.getMainLooper()).post {
                        AnalysisKeepAlive.releaseIfIdle()
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}

class AnalysisService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Podavio"
        val channelName = intent?.getStringExtra(EXTRA_CHANNEL) ?: "Podavio"
        try {
            val notification = notification(title, channelName)
            if (android.os.Build.VERSION.SDK_INT >= 29) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (_: Exception) {
            AnalysisKeepAlive.active = false
            stopSelf()
            return START_NOT_STICKY
        }
        acquireWakeLock()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val manager = getSystemService(PowerManager::class.java)
        wakeLock = manager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "podavio:analysis").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun notification(title: String, channelName: String): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                channelName,
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .build()
    }

    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_CHANNEL = "channel"
        private const val CHANNEL_ID = "podavio_analysis"
        private const val NOTIFICATION_ID = 43
    }
}
