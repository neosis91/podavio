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
import android.util.Log
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
    private const val TAG = "AnalysisKeepAlive"

    fun attach(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    AnalysisKeepAlive.active = true
                    val title = call.argument<String>("title") ?: "Podavio"
                    val channelName = call.argument<String>("channel") ?: "Podavio"
                    try {
                        if (AnalysisService.running) {
                            AnalysisService.update(context, title, channelName)
                        } else {
                            val intent = Intent(context, AnalysisService::class.java)
                                .putExtra(AnalysisService.EXTRA_TITLE, title)
                                .putExtra(AnalysisService.EXTRA_CHANNEL, channelName)
                            ContextCompat.startForegroundService(context, intent)
                        }
                        result.success(null)
                    } catch (error: Exception) {
                        Log.w(TAG, "Notification d’analyse", error)
                        result.error("start_failed", error.message, null)
                    }
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
        // Android 8 à 11 plante si le service s’arrête sans startForeground.
        // On promeut avant toute sortie, y compris si la notification riche échoue.
        val notification = try {
            buildNotification(this, title, channelName)
        } catch (error: Exception) {
            Log.w(TAG, "Notification d’analyse", error)
            fallbackNotification(this)
        }
        if (!promote(notification)) {
            AnalysisKeepAlive.active = false
            running = false
            stopSelf()
            return START_NOT_STICKY
        }
        running = true
        acquireWakeLock()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        running = false
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

    /// Vrai si le service est au premier plan. Sinon, un second essai avec
    /// une notification minimale a aussi échoué : stopSelf n’arrive qu’après.
    private fun promote(notification: Notification): Boolean {
        try {
            enterForeground(notification)
            return true
        } catch (error: Exception) {
            Log.w(TAG, "startForeground", error)
        }
        return try {
            enterForeground(fallbackNotification(this))
            true
        } catch (error: Exception) {
            Log.w(TAG, "startForeground de repli", error)
            false
        }
    }

    private fun enterForeground(notification: Notification) {
        if (android.os.Build.VERSION.SDK_INT >= 29) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_CHANNEL = "channel"
        internal const val TAG = "AnalysisService"
        internal const val CHANNEL_ID = "podavio_analysis"
        internal const val NOTIFICATION_ID = 43

        @Volatile
        var running: Boolean = false

        /// Met à jour la notification déjà affichée, sans relancer le service.
        fun update(context: Context, title: String, channelName: String) {
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.notify(NOTIFICATION_ID, buildNotification(context, title, channelName))
        }

        internal fun buildNotification(
            context: Context,
            title: String,
            channelName: String,
        ): Notification {
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    channelName,
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setContentTitle(title)
                .setSmallIcon(R.drawable.ic_notification)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(open)
                .build()
        }

        internal fun fallbackNotification(context: Context): Notification {
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Podavio",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setContentTitle("Podavio")
                .setSmallIcon(R.drawable.ic_notification)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .build()
        }
    }
}
