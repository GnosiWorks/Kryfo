// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// a pin keeps the app out of recents without blocking screenshots; the
// flag is only ever dart's, on every android. a refused step never throws,
// never stops the other and is told back as false
class WindowShieldTest {
    private val told = mutableListOf<String>()
    private var refuse: String? = null

    private fun step(name: String, v: Boolean) {
        if (name == refuse) throw IllegalStateException("refused")
        told.add("$name=$v")
    }

    private fun shield(recents: Boolean = true) = WindowShield(
        { step("flag", it) },
        if (recents) { p -> step("picture", p) } else null,
    )

    @Test
    fun aPinHidesRecentsAndLeavesScreenshots() {
        val w = shield()
        w.hide(true)
        assertEquals(listOf("picture=false"), told)
        assertFalse(w.secure)
    }

    @Test
    fun aPinNeverPutsTheFlagOnByItself() {
        val w = shield()
        w.hide(true)
        w.hide(false)
        assertFalse(w.secure)
        assertEquals(listOf("picture=false", "picture=true"), told)
    }

    @Test
    fun beforeThirteenAPinTellsNothing() {
        val w = shield(recents = false)
        w.hide(true)
        assertTrue(told.isEmpty())
        w.hold(true)
        assertEquals(listOf("flag=true"), told)
    }

    @Test
    fun noPinNothingTold() {
        val w = shield()
        w.hide(false)
        w.hold(false)
        assertTrue(w.recentsPicture)
        assertTrue(told.isEmpty())
    }

    @Test
    fun dartsFlagStaysOverAPinTurnedOff() {
        val w = shield()
        w.hide(true)
        w.hold(true)
        w.hide(false)
        assertTrue(w.secure)
        assertEquals(listOf("picture=false", "flag=true"), told)
        w.hold(false)
        assertEquals(listOf("flag=false", "picture=true"), told.takeLast(2))
    }

    @Test
    fun theLastRunCoversTheFirstFrame() {
        val w = shield()
        w.start(held = true, hidden = true)
        assertEquals(listOf("flag=true", "picture=false"), told)
        told.clear()
        shield().start(held = false, hidden = false)
        assertTrue(told.isEmpty())
    }

    @Test
    fun aRefusedStepLeavesTheOtherAndIsTriedAgain() {
        for (f in listOf("flag", "picture")) {
            told.clear()
            refuse = f
            val w = shield()
            w.start(held = true, hidden = true)
            assertEquals(listOf("flag=true", "picture=false") - "$f=${f == "flag"}", told)
            refuse = null
            assertTrue(w.hide(true))
            assertEquals("$f=${f == "flag"}", told.last())
        }
    }

    @Test
    fun aLinkageErrorIsARefusedStep() {
        var odd = true
        val w = WindowShield(
            { if (odd) throw NoSuchMethodError("addFlags") else told.add("flag=$it") },
            { p -> if (odd) throw UnsatisfiedLinkError("odd rom") else told.add("picture=$p") },
        )
        assertFalse(w.hold(true))
        assertTrue(told.isEmpty())
        odd = false
        assertTrue(w.hold(true))
        assertEquals(listOf("flag=true", "picture=false"), told)
    }

    @Test
    fun aBlockThatWouldNotGoOnIsRefusedToDart() {
        assertTrue(WindowShield.refusedOn(true) { false })
        assertTrue(WindowShield.refusedOn(true) { throw LinkageError("odd rom") })
        assertFalse(WindowShield.refusedOn(true) { true })
        // a clear that fails leaves the window secure
        assertFalse(WindowShield.refusedOn(false) { false })
    }
}
