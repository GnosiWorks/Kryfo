package app.kryfo

import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context

// the fifteen-minute floor is scheduled from every way into the process
// (activity, boot receiver, application), so a job the system cleared comes
// back without the app being opened.
object JobSetup {
    const val PERIODIC_JOB_ID = 2001

    fun schedule(context: Context) {
        // nothing to check in for, and the job would bring a wiped app back
        // to life. see KryfoState.
        if (!KryfoState.hasData(context)) return
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
