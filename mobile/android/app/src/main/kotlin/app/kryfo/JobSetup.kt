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
    private const val EVERY_MS = 15 * 60 * 1000L
    // a window of the last five minutes of each period, the least android
    // allows. with the whole period as its window two runs could land back
    // to back; with this one they stay ten minutes or more apart
    private const val FLEX_MS = 5 * 60 * 1000L

    fun schedule(context: Context) {
        // nothing to check in for, and the job would bring a wiped app back
        // to life. see KryfoState.
        if (!KryfoState.hasData(context)) return
        val scheduler = context.getSystemService(JobScheduler::class.java) ?: return
        // one scheduled with the whole period as its window is replaced once
        val pending = scheduler.getPendingJob(PERIODIC_JOB_ID)
        if (pending != null && pending.flexMillis < pending.intervalMillis) return
        val component = ComponentName(context, HaloPeriodicJobService::class.java)
        val jobInfo = JobInfo.Builder(PERIODIC_JOB_ID, component)
            .setPeriodic(EVERY_MS, FLEX_MS)
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            .setPersisted(true)
            .build()
        scheduler.schedule(jobInfo)
    }
}
