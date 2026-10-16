// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class KnockGateTest {
    private val t0 = 1_800_000_000_000L

    // knocks at [times]: how many went at once, and how many were put off
    private fun run(times: List<Long>): Pair<Int, Int> {
        var kept = emptyList<Long>()
        var went = 0
        var later = 0
        for (t in times) {
            val v = KnockGate.decide(kept, t)
            kept = v.kept
            if (v.go) went++ else if (v.waitMs > 0) later++
        }
        return went to later
    }

    @Test
    fun aStormOfKnocksIsBounded() {
        // ten a second for an hour
        val storm = (0 until 36_000).map { t0 + it * 100L }
        assertEquals(KnockGate.PER_HOUR, run(storm).first)
    }

    @Test
    fun aDayOfStormStaysAtThePerHourCap() {
        val storm = (0 until 24 * 3600).map { t0 + it * 1000L }
        assertTrue(run(storm).first <= 24 * KnockGate.PER_HOUR)
    }

    @Test
    fun theRelaysOwnPaceAlwaysGetsThrough() {
        val minutely = (0 until 30).map { t0 + it * 60_000L }
        assertEquals(30 to 0, run(minutely))
    }

    @Test
    fun aKnockInsideTheFloorWaitsForIt() {
        val first = KnockGate.decide(emptyList(), t0)
        assertTrue(first.go)
        val early = KnockGate.decide(first.kept, t0 + 10_000L)
        assertFalse(early.go)
        assertEquals(KnockGate.FLOOR_MS - 10_000L, early.waitMs)
        assertTrue(KnockGate.decide(first.kept, t0 + KnockGate.FLOOR_MS).go)
    }

    @Test
    fun pastTheHourlyCapNothingWaits() {
        var kept = emptyList<Long>()
        for (i in 0 until KnockGate.PER_HOUR) kept = KnockGate.decide(kept, t0 + i * 50_000L).kept
        val v = KnockGate.decide(kept, t0 + KnockGate.PER_HOUR * 50_000L)
        assertFalse(v.go)
        assertEquals(0L, v.waitMs)
    }

    @Test
    fun aClockSetBackDoesNotOpenTheGate() {
        val kept = KnockGate.decide(emptyList(), t0).kept
        assertFalse(KnockGate.decide(kept, t0 - 86_400_000L).go)
    }

    @Test
    fun anHourLaterTheBudgetIsBack() {
        var kept = emptyList<Long>()
        for (i in 0 until KnockGate.PER_HOUR) kept = KnockGate.decide(kept, t0 + i * 50_000L).kept
        val last = t0 + (KnockGate.PER_HOUR - 1) * 50_000L
        assertFalse(KnockGate.decide(kept, last + 60_000L).go)
        assertTrue(KnockGate.decide(kept, t0 + 3_600_000L + 50_000L).go)
    }
}
