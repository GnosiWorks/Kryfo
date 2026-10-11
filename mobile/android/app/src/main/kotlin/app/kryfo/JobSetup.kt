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
    const val COPY_SWEEP_JOB_ID = 2002
    const val COME_BACK_JOB_ID = 2003
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

    // a copy handed to another app is looked at again once its grace is
    // over. a job, not a timer: it runs even when the process was frozen or
    // killed meanwhile
    fun scheduleCopySweep(context: Context) {
        if (!KryfoState.hasData(context)) return
        val scheduler = context.getSystemService(JobScheduler::class.java) ?: return
        val component = ComponentName(context, CopySweepJobService::class.java)
        val jobInfo = JobInfo.Builder(COPY_SWEEP_JOB_ID, component)
            .setMinimumLatency(Shred.GRACE_MS + 30_000L)
            .setOverrideDeadline(Shred.GRACE_MS + 5 * 60_000L)
            .build()
        scheduler.schedule(jobInfo)
    }

    // after a restart out of sight: the process back within minutes, should
    // android not start the sticky service again
    fun scheduleComeBack(context: Context) {
        val scheduler = context.getSystemService(JobScheduler::class.java) ?: return
        val component = ComponentName(context, HaloPeriodicJobService::class.java)
        val jobInfo = JobInfo.Builder(COME_BACK_JOB_ID, component)
            .setMinimumLatency(60_000L)
            .setOverrideDeadline(5 * 60_000L)
            .build()
        scheduler.schedule(jobInfo)
    }
}
