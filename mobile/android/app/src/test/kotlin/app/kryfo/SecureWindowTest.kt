// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// a window or a system that refuses a step of the screenshot block never
// throws to the caller and never stops the steps after it
class SecureWindowTest {
    private val done = mutableListOf<String>()

    private fun steps(failing: String?, recents: Boolean = true) = SecureWindow.Steps(
        flag = { step("flag", failing) },
        recents = if (recents) { _ -> step("recents", failing) } else null,
        keep = { step("keep", failing) },
        surface = { step("surface", failing) },
    )

    private fun step(name: String, failing: String?) {
        if (name == failing) throw IllegalStateException("refused")
        done.add(name)
    }

    @Test
    fun everyStepGoesWhenNoneFails() {
        assertTrue(SecureWindow.apply(true, steps(null)))
        assertEquals(listOf("flag", "recents", "keep", "surface"), done)
    }

    @Test
    fun aRefusedStepLeavesTheOthers() {
        for (f in listOf("flag", "recents", "keep", "surface")) {
            done.clear()
            assertFalse(SecureWindow.apply(true, steps(f)))
            assertEquals(listOf("flag", "recents", "keep", "surface") - f, done)
        }
    }

    @Test
    fun aLinkageErrorIsARefusedStep() {
        val s = SecureWindow.Steps(
            flag = { throw NoSuchMethodError("setRecentsScreenshotEnabled") },
            recents = { throw UnsatisfiedLinkError("odd rom") },
            keep = { done.add("keep") },
            surface = { done.add("surface") },
        )
        assertFalse(SecureWindow.apply(true, s))
        assertEquals(listOf("keep", "surface"), done)
    }

    @Test
    fun aBlockThatWouldNotGoOnIsRefusedToDart() {
        assertTrue(SecureWindow.refusedOn(true) { false })
        assertTrue(SecureWindow.refusedOn(true) { throw LinkageError("odd rom") })
        assertFalse(SecureWindow.refusedOn(true) { true })
        // a clear that fails leaves the window secure
        assertFalse(SecureWindow.refusedOn(false) { false })
    }

    @Test
    fun beforeThirteenThereIsNoRecentsStep() {
        assertTrue(SecureWindow.apply(false, steps(null, recents = false)))
        assertEquals(listOf("flag", "keep", "surface"), done)
    }
}
