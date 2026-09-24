package app.kryfo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class HaloListenerService : Service() {
    companion object {
        const val CHANNEL_ID = "halo_listener_v2"
        const val NOTIFICATION_ID = 1

        // the channel keeps the words it was made with. a service that is
        // not running (check-ins) never gets to say them again, so a
        // language switch renames it from here too; [onlyIfThere] leaves a
        // phone that never had the service without one
        fun nameChannel(context: Context, onlyIfThere: Boolean = false) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = context.getSystemService(NotificationManager::class.java)
            if (onlyIfThere && nm.getNotificationChannel(CHANNEL_ID) == null) return
            val words = AppLocale.context(context)
            val channel = NotificationChannel(
                CHANNEL_ID,
                words.getString(R.string.channel_name),
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = words.getString(R.string.channel_description)
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
            nm.createNotificationChannel(channel)
        }
    }

    override fun onCreate() {
        super.onCreate()
        nameChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // started again after a language switch too: the channel and the
        // notification take the new words
        nameChannel(this)
        val words = AppLocale.context(this)
        val openIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(words.getString(R.string.service_title))
            .setContentText(words.getString(R.string.service_text))
            .setSmallIcon(R.drawable.ic_halo_notification)
            .setColor(0xFFF59E0B.toInt())
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(pendingIntent)
            .setShowWhen(false)
            .build()
        // android 14+ refuses a typed foreground service unless the type
        // is passed here too. without it the service dies on start and the
        // process gets frozen again.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        // wiped, or never opened: nothing to stay connected for. it has to
        // have called startForeground first - a service started as a
        // foreground one that stops without it takes the process down - so
        // it does, and then leaves at once and asks not to be brought back.
        if (!KryfoState.hasData(this)) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
