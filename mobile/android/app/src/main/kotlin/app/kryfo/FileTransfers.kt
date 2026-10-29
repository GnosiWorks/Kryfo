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
import androidx.annotation.VisibleForTesting
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// the notification of files sending or coming in, and a foreground service
// that keeps the process up while they do, for a phone without the always
// on service. it says how far, never which chat or which file. dart says
// what it shows and when it goes
object FileTransfers {
    const val CHANNEL = "kryfo/transfers"
    const val NOTE_CHANNEL = "kryfo_files"
    const val NOTE_ID = 7

    @Volatile
    var note: Notification? = null
        private set

    // a foreground start on its way, its onStartCommand not run yet: a stop
    // now would take the process down
    @Volatile
    var starting = false
        internal set

    // android said no, or the day's time ran out: no more tries until the
    // transfers end
    @Volatile
    var refused = false
        internal set

    // the last note's mode, for the placeholder a start that ended early fronts
    @Volatile
    var plain = false
        private set

    // plain notifications: the home screen's glyph
    fun glyph(context: Context, plain: Boolean): Int = if (plain) {
        try {
            AppIcon.current(context).glyph
        } catch (e: Exception) {
            AppIcon.kryfo.glyph
        }
    } else R.drawable.ic_halo_notification

    // the app on screen: the only time a foreground start is asked for
    @VisibleForTesting
    var onScreen: () -> Boolean = { QuietRestart.onScreen(QuietRestart.importance()) }

    fun start(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        show(
                            context,
                            channelName = call.argument<String>("channel") ?: "",
                            channelLine = call.argument<String>("channelLine") ?: "",
                            title = call.argument<String>("title") ?: "",
                            text = call.argument<String>("text"),
                            done = call.argument<Int>("done") ?: 0,
                            total = call.argument<Int>("total") ?: 0,
                            plain = call.argument<Boolean>("plain") ?: false,
                            hold = call.argument<Boolean>("hold") ?: false,
                        )
                        result.success(true)
                    }
                    "end" -> {
                        end(context)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun channel(context: Context, name: String, line: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        val ch = NotificationChannel(NOTE_CHANNEL, name, NotificationManager.IMPORTANCE_LOW).apply {
            description = line
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        nm.createNotificationChannel(ch)
    }

    // done and total in kilobytes: an int holds them. plain: the listener's
    // one neutral word and no line, whatever dart sent
    @VisibleForTesting
    internal fun show(
        context: Context,
        channelName: String,
        channelLine: String,
        title: String,
        text: String?,
        done: Int,
        total: Int,
        plain: Boolean,
        hold: Boolean,
    ) {
        channel(context, channelName, channelLine)
        val words = if (plain) {
            AppLocale.context(context).getString(R.string.service_title_plain)
        } else title
        val open = Intent().setComponent(AppIcon.entry(context)).apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val tap = PendingIntent.getActivity(
            context, NOTE_ID, open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // plain notifications: the home screen's glyph and no colour
        val icon = glyph(context, plain)
        this.plain = plain
        val b = NotificationCompat.Builder(context, NOTE_CHANNEL)
            .setContentTitle(words)
            .setSmallIcon(icon)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setContentIntent(tap)
            .setShowWhen(false)
        if (!plain && !text.isNullOrEmpty()) b.setContentText(text)
        if (total > 0) b.setProgress(total, done.coerceIn(0, total), false)
        else b.setProgress(0, 0, true)
        if (!plain) b.setColor(0xFFF59E0B.toInt())
        val n = b.build()
        note = n
        val nm = context.getSystemService(NotificationManager::class.java)
        // asked for once, and only on screen: from the background android
        // says no, or lets it in and refuses it inside startForeground. a
        // no is kept until the transfers end; the note shows all the same
        if (hold && !FileTransferService.running && !starting && !refused && onScreen()) {
            try {
                starting = true
                val i = Intent(context, FileTransferService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(i)
                else context.startService(i)
                return
            } catch (e: Exception) {
                starting = false
                refused = true
                HaloListenerService.debugLog(context, "transfers: no foreground start")
            }
        }
        nm?.notify(NOTE_ID, n)
    }

    fun end(context: Context) {
        note = null
        refused = false
        // one still starting stops itself once in front (onStartCommand
        // finds no note); one that never got there is not stopped
        if (!starting && FileTransferService.running) {
            context.stopService(Intent(context, FileTransferService::class.java))
        }
        context.getSystemService(NotificationManager::class.java)?.cancel(NOTE_ID)
    }
}

// up only while files move. android gives a data sync service six hours a
// day on 15 and later: past them it stops, and the note stays as a plain one
class FileTransferService : Service() {
    companion object {
        @Volatile
        var running = false
            private set
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        FileTransfers.starting = false
        val n = FileTransfers.note
        if (n == null) {
            // ended before it started: a foreground start still owes its
            // call, then it goes. one android refused is never stopped
            try {
                front(placeholder())
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            } catch (e: Exception) {
                FileTransfers.refused = true
            }
            return START_NOT_STICKY
        }
        try {
            front(n)
            running = true
        } catch (e: Exception) {
            // refused inside startForeground (android 15's day of data
            // sync spent, say): not stopped, and not asked for again
            running = false
            FileTransfers.refused = true
        }
        return START_NOT_STICKY
    }

    private fun placeholder(): Notification =
        NotificationCompat.Builder(this, FileTransfers.NOTE_CHANNEL)
            .setSmallIcon(FileTransfers.glyph(this, FileTransfers.plain))
            .setSilent(true)
            .build()

    private fun front(n: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(FileTransfers.NOTE_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(FileTransfers.NOTE_ID, n)
        }
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        running = false
        FileTransfers.refused = true
        stopForeground(STOP_FOREGROUND_DETACH)
        stopSelf()
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
