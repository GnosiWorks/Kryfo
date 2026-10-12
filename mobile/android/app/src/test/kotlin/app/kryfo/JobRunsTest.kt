// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class JobRunsTest {
    private val periodic = 2001
    private val comeBack = 2003

    @Test
    fun twoJobsSideBySideEachEnd() {
        val runs = JobRuns()
        val ended = mutableListOf<Int>()
        val a = runs.start(periodic) { ended.add(periodic) }
        val b = runs.start(comeBack) { ended.add(comeBack) }
        a.finish.run()
        b.finish.run()
        assertEquals(listOf(periodic, comeBack), ended)
    }

    @Test
    fun theLaterStartLeavesTheEarlierRunOpen() {
        val runs = JobRuns()
        val ended = mutableListOf<Int>()
        val a = runs.start(periodic) { ended.add(periodic) }
        runs.start(comeBack) { ended.add(comeBack) }
        assertFalse(a.finished)
        a.finish.run()
        assertEquals(listOf(periodic), ended)
    }

    @Test
    fun aRunEndsOnce() {
        val runs = JobRuns()
        var ended = 0
        val a = runs.start(periodic) { ended++ }
        a.finish.run()
        a.finish.run()
        assertEquals(1, ended)
        assertTrue(a.finished)
    }

    @Test
    fun aStopReachesOnlyItsOwnRun() {
        val runs = JobRuns()
        val ended = mutableListOf<Int>()
        val a = runs.start(periodic) { ended.add(periodic) }
        val b = runs.start(comeBack) { ended.add(comeBack) }
        assertTrue(runs.stop(periodic) === a)
        assertTrue(a.finished)
        assertFalse(b.finished)
        a.finish.run()
        b.finish.run()
        assertEquals(listOf(comeBack), ended)
        // nothing left to stop
        assertEquals(null, runs.stop(periodic))
        assertEquals(null, runs.stop(comeBack))
    }

    @Test
    fun aStopHandsBackTheRetryStillWaiting() {
        val runs = JobRuns()
        val a = runs.start(periodic) {}
        val again = Runnable {}
        a.retry = again
        val stopped = runs.stop(periodic)
        assertTrue(stopped?.retry === again)
        assertTrue(stopped!!.finished)
    }
}
