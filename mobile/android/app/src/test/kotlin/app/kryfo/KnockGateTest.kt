// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class KnockGateTest {
    private val t0 = 1_800_000_000_000L

    // knocks at [times], what got through
    private fun run(times: List<Long>): Int {
        var kept = emptyList<Long>()
        var through = 0
        for (t in times) {
            val (ok, next) = KnockGate.decide(kept, t)
            kept = next
            if (ok) through++
        }
        return through
    }

    @Test
    fun aStormOfKnocksIsBounded() {
        // ten a second for an hour
        val storm = (0 until 36_000).map { t0 + it * 100L }
        assertEquals(KnockGate.PER_HOUR, run(storm))
    }

    @Test
    fun aDayOfStormStaysAtThePerHourCap() {
        val storm = (0 until 24 * 3600).map { t0 + it * 1000L }
        assertTrue(run(storm) <= 24 * KnockGate.PER_HOUR)
    }

    @Test
    fun theRelaysOwnPaceAlwaysGetsThrough() {
        // the relay knocks one endpoint at most once a minute; sixteen
        // endpoints with decoys come nowhere near thirty an hour
        val minutely = (0 until 30).map { t0 + it * 60_000L }
        assertEquals(30, run(minutely))
    }

    @Test
    fun aKnockInsideTheFloorIsDropped() {
        val (first, kept) = KnockGate.decide(emptyList(), t0)
        assertTrue(first)
        assertFalse(KnockGate.decide(kept, t0 + KnockGate.FLOOR_MS - 1).first)
        assertTrue(KnockGate.decide(kept, t0 + KnockGate.FLOOR_MS).first)
    }

    @Test
    fun aClockSetBackDoesNotOpenTheGate() {
        val (_, kept) = KnockGate.decide(emptyList(), t0)
        // the clock now reads a day earlier: the stored time counts as now
        assertFalse(KnockGate.decide(kept, t0 - 86_400_000L).first)
    }

    @Test
    fun anHourLaterTheBudgetIsBack() {
        var kept = emptyList<Long>()
        for (i in 0 until KnockGate.PER_HOUR) kept = KnockGate.decide(kept, t0 + i * 50_000L).second
        val last = t0 + (KnockGate.PER_HOUR - 1) * 50_000L
        assertFalse(KnockGate.decide(kept, last + 60_000L).first)
        assertTrue(KnockGate.decide(kept, t0 + 3_600_000L + 50_000L).first)
    }
}
