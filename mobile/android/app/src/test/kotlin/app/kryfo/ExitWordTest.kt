// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.ApplicationExitInfo.REASON_LOW_MEMORY
import android.app.ApplicationExitInfo.REASON_USER_REQUESTED
import org.junit.Assert.assertEquals
import org.junit.Test

class ExitWordTest {
    private fun code(d: String?) = ExitWord.of(REASON_USER_REQUESTED, d)

    @Test
    fun theLoadGuardAndOtherSystemProcessesAreThePhone() {
        // as xiaomi's load guard writes it
        assertEquals(
            "by_phone",
            code("stop app.kryfo due to UserDefined:The system loading is too high and ANR is occurring.")
        )
        assertEquals("by_phone", code("stop app.kryfo due to from process:com.miui.powerkeeper"))
    }

    @Test
    fun xiaomisSecurityAppIsNamedAsItself() {
        // manage apps, clear all and its cleanup all come from it
        assertEquals(
            "by_security_app",
            code("stop app.kryfo due to from process:com.miui.securitycenter")
        )
    }

    @Test
    fun thePersonsOwnStaysTheirs() {
        assertEquals("by_you", code("stop app.kryfo due to from process:com.android.settings"))
        assertEquals("by_you", code("stop app.kryfo due to from process:14850"))
        assertEquals("by_you", code("stop app.kryfo due to clear data"))
        assertEquals("by_you", code(null))
    }

    @Test
    fun otherReasonsKeepTheirOwnCode() {
        assertEquals("low_memory", ExitWord.of(REASON_LOW_MEMORY, "from process:com.miui.securitycenter"))
        assertEquals("stopped", ExitWord.of(-1, null))
    }
}
