// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.ActivityManager
import android.app.ActivityManager.RunningAppProcessInfo
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock

// the app's process ended with nothing on screen. the listener service is
// sticky, so android starts it again in a new process as after any kill, and
// a one-off job does if android does not. no screen opens, and the lock
// reads its own state on the way up
object QuietRestart {
    private const val PREFS = "kryfo_restart"
    private const val UP = "up"
    private const val BOOT = "boot"
    // dart keeps its own half hour. this one holds if that ever failed
    const val EVERY_MS = 30 * 60 * 1000L

    fun onScreen(importance: Int): Boolean =
        importance == RunningAppProcessInfo.IMPORTANCE_FOREGROUND ||
            importance == RunningAppProcessInfo.IMPORTANCE_VISIBLE

    // on the clock since boot. another boot, or a clock that went back, is a
    // phone started again
    fun due(lastUp: Long, lastBoot: Int, nowUp: Long, nowBoot: Int): Boolean {
        if (lastUp <= 0L) return true
        if (lastBoot >= 0 && nowBoot >= 0 && lastBoot != nowBoot) return true
        if (nowUp < lastUp) return true
        return nowUp - lastUp >= EVERY_MS
    }

    // only a phone that lets kryfo start its service from the background
    // gets it back for sure; elsewhere the rescue and the button stay
    fun allowed(
        running: Boolean,
        staysOn: Boolean,
        hasData: Boolean,
        importance: Int,
        batteryFree: Boolean,
        due: Boolean,
    ): Boolean = running && staysOn && hasData && !onScreen(importance) && batteryFree && due

    fun importance(): Int {
        val me = RunningAppProcessInfo()
        ActivityManager.getMyMemoryState(me)
        return me.importance
    }

    fun bootCount(context: Context): Int = try {
        android.provider.Settings.Global.getInt(
            context.contentResolver,
            android.provider.Settings.Global.BOOT_COUNT,
        )
    } catch (e: Exception) {
        -1
    }

    fun clock(context: Context): List<Long> =
        listOf(SystemClock.elapsedRealtime(), bootCount(context).toLong())

    private fun batteryFree(context: Context): Boolean = try {
        context.getSystemService(PowerManager::class.java)
            ?.isIgnoringBatteryOptimizations(context.packageName) == true
    } catch (e: Exception) {
        false
    }

    // a yes is on disk before it is given, or a restart could follow a restart
    fun arm(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val nowUp = SystemClock.elapsedRealtime()
        val nowBoot = bootCount(context)
        val ok = allowed(
            running = HaloListenerService.running,
            staysOn = DeliveryPrefs.staysOn(context),
            hasData = KryfoState.hasData(context),
            importance = importance(),
            batteryFree = batteryFree(context),
            due = due(prefs.getLong(UP, 0L), prefs.getInt(BOOT, -1), nowUp, nowBoot),
        )
        if (!ok) return false
        if (!prefs.edit().putLong(UP, nowUp).putInt(BOOT, nowBoot).commit()) return false
        JobSetup.scheduleComeBack(context)
        return true
    }

    // after dart has its answer and has shut its databases
    fun end(): Boolean {
        if (!HaloListenerService.running || onScreen(importance())) return false
        val pid = Process.myPid()
        Handler(Looper.getMainLooper()).postDelayed({
            // kryfo may have come on screen since the answer went
            if (HaloListenerService.running && !onScreen(importance())) {
                Process.killProcess(pid)
            }
        }, 300)
        return true
    }
}
