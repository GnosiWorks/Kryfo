package app.kryfo

import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context

// the fifteen-minute floor is scheduled from every way into the process:
// the activity, the boot receiver and the application itself. it used to
// be the activity alone, so a phone whose system cleared the job stayed
// without one until the person happened to open the app.
object JobSetup {
    const val PERIODIC_JOB_ID = 2001

    fun schedule(context: Context) {
        val scheduler = context.getSystemService(JobScheduler::class.java) ?: return
        if (scheduler.getPendingJob(PERIODIC_JOB_ID) != null) return
        val component = ComponentName(context, HaloPeriodicJobService::class.java)
        val jobInfo = JobInfo.Builder(PERIODIC_JOB_ID, component)
            .setPeriodic(15 * 60 * 1000L)
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            .setPersisted(true)
            .build()
        scheduler.schedule(jobInfo)
    }
}
