// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BioKeyWorkTest {
    // seals and deletes run one at a time, in the order they were asked for
    @Test
    fun keyWorkRunsInOrderOnOneThread() {
        val seen = Collections.synchronizedList(mutableListOf<Int>())
        val threads = Collections.synchronizedSet(mutableSetOf<Long>())
        val done = CountDownLatch(50)
        for (i in 0 until 50) {
            BioKey.work.execute {
                threads.add(Thread.currentThread().id)
                // a slow one first must still finish before the next starts
                if (i % 7 == 0) Thread.sleep(3)
                seen.add(i)
                done.countDown()
            }
        }
        assertTrue(done.await(10, TimeUnit.SECONDS))
        assertEquals((0 until 50).toList(), seen.toList())
        assertEquals(1, threads.size)
    }
}
