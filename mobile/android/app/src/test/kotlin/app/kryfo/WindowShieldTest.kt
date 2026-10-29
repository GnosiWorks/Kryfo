// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// a pin keeps the app out of recents without blocking screenshots; older
// android gets the flag only on the way out
class WindowShieldTest {
    private val told = mutableListOf<Pair<Boolean, Boolean>>()
    private fun shield(sdk: Int) = WindowShield(sdk) { s, p -> told.add(s to p) }

    @Test
    fun aPinOnAndroid13HidesRecentsAndLeavesScreenshots() {
        val w = shield(33)
        w.hide(true)
        assertEquals(listOf(false to false), told)
        w.leaving()
        w.back()
        assertFalse(w.secure)
        assertEquals(1, told.size)
    }

    @Test
    fun aPinOnOlderAndroidCoversOnlyOnTheWayOut() {
        val w = shield(29)
        w.hide(true)
        assertFalse(w.secure)
        w.leaving()
        assertTrue(w.secure)
        assertEquals(true to false, told.last())
        // leave hint, then pause: told once
        w.leaving()
        assertEquals(2, told.size)
        w.back()
        assertFalse(w.secure)
        assertEquals(false to false, told.last())
    }

    @Test
    fun noPinNoCover() {
        val w = shield(29)
        w.leaving()
        assertFalse(w.secure)
        assertTrue(w.recentsPicture)
        assertTrue(told.isEmpty())
    }

    @Test
    fun theWayBackKeepsWhatDartHolds() {
        val w = shield(29)
        w.hide(true)
        w.leaving()
        // the lock went up while away
        w.hold(true)
        w.back()
        assertTrue(w.secure)
        w.hold(false)
        assertFalse(w.secure)
    }

    @Test
    fun dartLettingGoWhileAwayKeepsTheCover() {
        val w = shield(29)
        w.hide(true)
        w.hold(true)
        w.leaving()
        w.hold(false)
        assertTrue(w.secure)
        w.back()
        assertFalse(w.secure)
    }

    @Test
    fun theFlagHidesRecentsOnAndroid13WithoutAPin() {
        val w = shield(34)
        w.hold(true)
        assertEquals(true to false, told.last())
        w.hold(false)
        assertEquals(false to true, told.last())
    }

    @Test
    fun theLastRunCoversTheFirstFrame() {
        val w = shield(34)
        w.start(held = true, hidden = true)
        assertEquals(listOf(true to false), told)
        val fresh = shield(34)
        told.clear()
        fresh.start(held = false, hidden = false)
        assertTrue(told.isEmpty())
    }
}
