package app.kryfo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat

class HaloListenerService : Service() {
    companion object {
        const val CHANNEL_ID = "halo_listener_v2"
        const val NOTIFICATION_ID = 1

        // up in this process: the periodic job leaves it alone then, since
        // starting it again only posts its notification anew
        @Volatile
        var running = false
            private set

        // set on a foreground start, which has a deadline to meet
        const val EXTRA_FRONT = "front"

        // when start() first ran for the next onCreate, for the timing
        // line of a debug build
        @Volatile
        private var askedAt = 0L

        fun debugLog(context: Context, line: String) {
            if (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) {
                Log.i("halo-engine", line)
            }
        }

        // a plain start has no deadline. android allows one for a service
        // that is already up, while a screen of the app is in front, and
        // inside the allowlist window of a boot or update broadcast.
        // throws what android throws when it refuses
        fun start(
            context: Context,
            plainFirst: Boolean = QuietRestart.onScreen(QuietRestart.importance())
        ) {
            if (askedAt == 0L) askedAt = SystemClock.elapsedRealtime()
            val intent = Intent(context, HaloListenerService::class.java)
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                context.startService(intent)
                return
            }
            if (running || plainFirst) {
                try {
                    context.startService(intent)
                    debugLog(context, "listener: plain start")
                    return
                } catch (e: IllegalStateException) {
                    // android counts the app as in the background after all
                    debugLog(context, "listener: plain start refused")
                }
            }
            context.startForegroundService(intent.putExtra(EXTRA_FRONT, true))
            debugLog(context, "listener: foreground start")
        }

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

    // what the notification says now, and the words it was built from
    private var note: Notification? = null
    private var noteWords: List<String>? = null

    // startForeground went through. a second call re-checks the background
    // rules on android 14+, so a service in front only updates its words
    private var inFront = false

    private fun words(): List<String> {
        val words = AppLocale.context(this)
        return listOf(
            words.getString(R.string.service_title),
            words.getString(R.string.service_text)
        )
    }

    private fun build(words: List<String>): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(words[0])
            .setContentText(words[1])
            .setSmallIcon(R.drawable.ic_halo_notification)
            .setColor(0xFFF59E0B.toInt())
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(pendingIntent)
            .setShowWhen(false)
            .build()
        note = notification
        noteWords = words
        return notification
    }

    // android 14+ refuses a typed foreground service unless the type
    // is passed here too, and the service dies on start.
    private fun front(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        inFront = true
    }

    private fun reword(notification: Notification) {
        getSystemService(NotificationManager::class.java)
            ?.notify(NOTIFICATION_ID, notification)
    }

    override fun onCreate() {
        super.onCreate()
        // to the front before anything else: the deadline of a foreground
        // start runs from the call, and this thread is dart's too
        val created = SystemClock.elapsedRealtime()
        try {
            nameChannel(this)
            front(build(words()))
        } catch (e: Exception) {
            // onStartCommand tries again and decides
        }
        val asked = askedAt
        askedAt = 0L
        val wait = if (asked > 0) "${created - asked}" else "-"
        debugLog(
            this,
            "listener: start to create $wait ms, create to front " +
                "${SystemClock.elapsedRealtime() - created} ms, front $inFront"
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            if (!inFront) front(note ?: build(words()))
        } catch (e: Exception) {
            // a foreground start that cannot go to the front fails loudly.
            // a sticky restart or a plain start android will not let into
            // the front goes rather than taking the process down. the job
            // still runs
            if (intent?.getBooleanExtra(EXTRA_FRONT, false) == true) throw e
            running = false
            stopSelf()
            return START_NOT_STICKY
        }
        // started again after a language switch too: the channel and the
        // notification take the new words. the old ones stay on a failure
        try {
            nameChannel(this)
            val words = words()
            if (words != noteWords) reword(build(words))
        } catch (e: Exception) {
        }
        // wiped, or never opened: nothing to stay connected for. a foreground
        // service that stops before startForeground takes the process down,
        // so it leaves only after that call and asks not to come back.
        if (!KryfoState.hasData(this)) {
            running = false
            stopForeground(STOP_FOREGROUND_REMOVE)
            inFront = false
            stopSelf()
            return START_NOT_STICKY
        }
        running = true
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
