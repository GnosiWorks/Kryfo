// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class KnockOweTest {
    private class Mem : KnockOwe.Store {
        override var owed = false
    }

    @Test
    fun aKnockWhileItsJobRunsIsAskedForOnceTheJobEnds() {
        var running = true
        var scheduled = 0
        val store = Mem()
        val owe = KnockOwe({ running }, { scheduled++ }, store)
        owe.knock()
        assertEquals(0, scheduled)
        assertTrue(store.owed)
        // a second one while it still runs is the same one owed
        owe.knock()
        running = false
        owe.ended()
        assertEquals(1, scheduled)
        assertFalse(store.owed)
        owe.ended()
        assertEquals(1, scheduled)
    }

    @Test
    fun aJobThatHasNotLetGoYetKeepsTheDebtForTheNextEnd() {
        var running = true
        var scheduled = 0
        val store = Mem()
        val owe = KnockOwe({ running }, { scheduled++ }, store)
        owe.knock()
        owe.ended()
        assertEquals(0, scheduled)
        running = false
        owe.ended()
        assertEquals(1, scheduled)
    }

    @Test
    fun withNothingWaitingAKnockGoesAtOnce() {
        var scheduled = 0
        val store = Mem()
        KnockOwe({ false }, { scheduled++ }, store).knock()
        assertEquals(1, scheduled)
        assertFalse(store.owed)
    }
}
