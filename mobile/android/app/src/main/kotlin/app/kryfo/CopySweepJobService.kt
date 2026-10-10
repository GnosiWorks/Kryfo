// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.job.JobParameters
import android.app.job.JobService

// shreds the handed-out copies whose grace is over, off the main thread,
// and comes back while one is still too young
class CopySweepJobService : JobService() {
    override fun onStartJob(params: JobParameters?): Boolean {
        Thread {
            val young = Shred.handed(cacheDir)
            Shred.dropBackups(cacheDir, false)
            jobFinished(params, false)
            if (young) JobSetup.scheduleCopySweep(this)
        }.start()
        return true
    }

    // stopped part way: what is left is looked at again
    override fun onStopJob(params: JobParameters?): Boolean = true
}
