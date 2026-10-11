// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.ActivityManager
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.Process
import kotlin.math.abs

// the app's process ended with nothing on screen. the listener service is
// sticky, so android starts it again in a new process as after any kill, and
// a one-off job does if android does not. no screen opens, and the lock
// reads its own state on the way up
object QuietRestart {
    private const val PREFS = "kryfo_restart"
    private const val AT = "at"
    // dart keeps its own half hour. this one holds if that ever failed
    private const val EVERY_MS = 30 * 60 * 1000L

    fun go(context: Context): Boolean {
        if (!HaloListenerService.running) return false
        if (!DeliveryPrefs.staysOn(context) || !KryfoState.hasData(context)) return false
        // a screen of ours is showing: the person has the buttons
        val me = ActivityManager.RunningAppProcessInfo()
        ActivityManager.getMyMemoryState(me)
        if (me.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND ||
            me.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE
        ) return false
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val last = prefs.getLong(AT, 0L)
        if (last != 0L && abs(now - last) < EVERY_MS) return false
        // on disk before the process goes, or a restart could follow a restart
        if (!prefs.edit().putLong(AT, now).commit()) return false
        JobSetup.scheduleComeBack(context)
        // after dart has its answer
        val pid = Process.myPid()
        Handler(Looper.getMainLooper()).postDelayed({ Process.killProcess(pid) }, 500)
        return true
    }
}
