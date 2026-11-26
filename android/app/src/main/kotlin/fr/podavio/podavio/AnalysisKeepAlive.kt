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

    /// Vrai après un `startForeground` réussi, jusqu’à l’arrêt demandé
    /// ou la destruction du service. Sert à mettre la notification à jour
    /// sans rappeler `startForegroundService` (refusé en arrière-plan
    /// à partir d’Android 12).
    @Volatile
    var serviceRunning: Boolean = false

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
                    val title = call.argument<String>("title") ?: "Podavio"
                    val channel = call.argument<String>("channel") ?: "Podavio"
                    AnalysisKeepAlive.active = true
                    try {
                        if (AnalysisKeepAlive.serviceRunning) {
                            AnalysisService.updateNotification(context, title, channel)
                        } else {
                            val intent = Intent(context, AnalysisService::class.java)
                                .putExtra(AnalysisService.EXTRA_TITLE, title)
                                .putExtra(AnalysisService.EXTRA_CHANNEL, channel)
                            ContextCompat.startForegroundService(context, intent)
                        }
                        result.success(null)
                    } catch (error: Exception) {
                        Log.e(TAG, "Maintien de l’analyse refusé", error)
                        if (!AnalysisKeepAlive.serviceRunning) {
                            AnalysisKeepAlive.active = false
                        }
                        result.error("foreground", error.message, null)
                    }
                }
                "stop" -> {
                    AnalysisKeepAlive.active = false
                    AnalysisKeepAlive.serviceRunning = false
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

    private const val TAG = "AnalysisKeepAlive"
}

class AnalysisService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Podavio"
        val channelName = intent?.getStringExtra(EXTRA_CHANNEL) ?: "Podavio"
        // Tout démarrage via startForegroundService doit appeler startForeground
        // tout de suite (Android 8–11 tue l’appli sinon). Pas de stopSelf avant :
        // le système considère alors que le service n’est jamais passé au premier plan.
        val notification = try {
            buildNotification(this, title, channelName)
        } catch (error: Exception) {
            Log.e(TAG, "Notification d’analyse indisponible", error)
            try {
                buildNotification(this, "Podavio", "Podavio")
            } catch (again: Exception) {
                Log.e(TAG, "Notification de repli indisponible", again)
                AnalysisKeepAlive.active = false
                AnalysisKeepAlive.serviceRunning = false
                return START_NOT_STICKY
            }
        }
        try {
            if (android.os.Build.VERSION.SDK_INT >= 29) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (error: Exception) {
            Log.e(TAG, "startForeground a échoué", error)
            AnalysisKeepAlive.active = false
            AnalysisKeepAlive.serviceRunning = false
            return START_NOT_STICKY
        }
        AnalysisKeepAlive.serviceRunning = true
        acquireWakeLock()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        AnalysisKeepAlive.serviceRunning = false
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

    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_CHANNEL = "channel"
        private const val TAG = "AnalysisService"
        private const val CHANNEL_ID = "podavio_analysis"
        private const val NOTIFICATION_ID = 43

        /// Même identifiant que le service au premier plan : Android remplace
        /// la notification sans relancer le service.
        fun updateNotification(context: Context, title: String, channelName: String) {
            val notification = buildNotification(context, title, channelName)
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.notify(NOTIFICATION_ID, notification)
        }

        private fun buildNotification(
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
    }
}
