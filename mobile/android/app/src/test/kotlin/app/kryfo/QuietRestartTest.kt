// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.ActivityManager.RunningAppProcessInfo.IMPORTANCE_CACHED
import android.app.ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
import android.app.ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND_SERVICE
import android.app.ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class QuietRestartTest {
    private val min = 60_000L

    private fun allowed(
        running: Boolean = true,
        staysOn: Boolean = true,
        hasData: Boolean = true,
        importance: Int = IMPORTANCE_FOREGROUND_SERVICE,
        batteryFree: Boolean = true,
        due: Boolean = true,
    ) = QuietRestart.allowed(running, staysOn, hasData, importance, batteryFree, due)

    @Test
    fun outOfSightWithTheServiceUp() {
        assertTrue(allowed())
        assertTrue(allowed(importance = IMPORTANCE_CACHED))
    }

    @Test
    fun neverOnScreen() {
        assertFalse(allowed(importance = IMPORTANCE_FOREGROUND))
        assertFalse(allowed(importance = IMPORTANCE_VISIBLE))
    }

    @Test
    fun onlyWhereAndroidLetsTheServiceBack() {
        assertFalse(allowed(batteryFree = false))
        assertFalse(allowed(running = false))
        assertFalse(allowed(staysOn = false))
        assertFalse(allowed(hasData = false))
        assertFalse(allowed(due = false))
    }

    @Test
    fun halfAnHourOnTheClockSinceBoot() {
        assertTrue(QuietRestart.due(0L, -1, 5 * min, 7))
        assertFalse(QuietRestart.due(100 * min, 7, 129 * min, 7))
        assertTrue(QuietRestart.due(100 * min, 7, 130 * min, 7))
        // another boot, or a clock since boot that went back
        assertTrue(QuietRestart.due(100 * min, 7, 5 * min, 8))
        assertTrue(QuietRestart.due(10 * min, 7, 20 * min, 8))
        assertTrue(QuietRestart.due(100 * min, -1, 5 * min, -1))
        assertFalse(QuietRestart.due(100 * min, -1, 110 * min, -1))
    }
}
