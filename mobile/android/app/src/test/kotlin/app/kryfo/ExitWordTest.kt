// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.ApplicationExitInfo.REASON_LOW_MEMORY
import android.app.ApplicationExitInfo.REASON_USER_REQUESTED
import org.junit.Assert.assertEquals
import org.junit.Test

class ExitWordTest {
    private fun word(d: String?) = ExitWord.of(REASON_USER_REQUESTED, d)

    @Test
    fun thePhonesOwnForceStopsAreNotThePersons() {
        // as xiaomi's cleaner and its load guard write them
        assertEquals(
            "stopped by the phone",
            word("stop app.kryfo due to from process:com.miui.securitycenter")
        )
        assertEquals(
            "stopped by the phone",
            word("stop app.kryfo due to UserDefined:The system loading is too high and ANR is occurring.")
        )
    }

    @Test
    fun thePersonsOwnStaysTheirs() {
        assertEquals("stopped by you", word("stop app.kryfo due to from process:com.android.settings"))
        assertEquals("stopped by you", word("stop app.kryfo due to from process:14850"))
        assertEquals("stopped by you", word("stop app.kryfo due to clear data"))
        assertEquals("stopped by you", word(null))
    }

    @Test
    fun otherReasonsReadAsBefore() {
        assertEquals("low memory", ExitWord.of(REASON_LOW_MEMORY, "from process:com.miui.securitycenter"))
        assertEquals("stopped", ExitWord.of(-1, null))
    }
}
