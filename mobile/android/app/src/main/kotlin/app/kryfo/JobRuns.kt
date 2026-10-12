// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

// the runs of one job service. the periodic job and the come-back one can
// run side by side on the same instance: each ends once, by its own flag,
// and a stop reaches only its own
class JobRuns {
    class Run internal constructor(private val end: () -> Unit) {
        private val done = AtomicBoolean(false)
        val finished: Boolean get() = done.get()

        // the first call ends the run, any later one does nothing
        val finish = Runnable { if (done.compareAndSet(false, true)) end() }

        internal fun stop() = done.set(true)
    }

    private val live = ConcurrentHashMap<Int, Run>()

    fun start(id: Int, end: () -> Unit): Run {
        lateinit var run: Run
        run = Run {
            live.remove(id, run)
            end()
        }
        live[id] = run
        return run
    }

    // android stopped job [id]: its run never ends by itself after this
    fun stop(id: Int): Run? = live.remove(id)?.also { it.stop() }
}
