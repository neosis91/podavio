package fr.podavio.podavio

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.wear.ongoing.OngoingActivity
import fr.podavio.podavio.wear.WearState

/** Activité en cours sur le cadran pendant la lecture. */
object OngoingPlayback {
    private const val CHANNEL_ID = "podavio_wear_playback"
    private const val NOTIFICATION_ID = 42

    fun show(context: Context, state: WearState) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Lecture",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
        val open =
            PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        val builder =
            NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_status_play)
                .setContentTitle(state.title.ifBlank { "Podavio" })
                .setContentText(state.artist)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setLocalOnly(true)
                .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
                .setContentIntent(open)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
        runCatching {
            OngoingActivity.Builder(context, NOTIFICATION_ID, builder)
                .setStaticIcon(R.drawable.ic_status_play)
                .setAnimatedIcon(R.drawable.ic_status_play)
                .setTouchIntent(open)
                .build()
                .apply(context)
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, builder.build())
        }
    }

    fun hide(context: Context) {
        runCatching {
            NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
        }
    }
}
