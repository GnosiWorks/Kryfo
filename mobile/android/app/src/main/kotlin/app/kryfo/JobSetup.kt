package app.kryfo

import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.PersistableBundle

// the fifteen-minute floor is scheduled from every way into the process
// (activity, boot receiver, application), so a job the system cleared comes
// back without the app being opened.
object JobSetup {
    const val PERIODIC_JOB_ID = 2001
    const val COPY_SWEEP_JOB_ID = 2002
    const val COME_BACK_JOB_ID = 2003
    const val KNOCK_JOB_ID = 2004
    const val KNOCK_LATER_JOB_ID = 2005
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

    // a knock from the helper app: one check-in, now. expedited where
    // android has it, so it is not held for a maintenance window. one
    // waiting or running is enough, it fetches for every address
    fun scheduleKnock(context: Context) {
        if (!KryfoState.hasData(context)) return
        val scheduler = context.getSystemService(JobScheduler::class.java) ?: return
        if (scheduler.getPendingJob(KNOCK_JOB_ID) != null) return
        val component = ComponentName(context, HaloPeriodicJobService::class.java)
        val extras = PersistableBundle().apply { putString("why", "push") }
        fun builder() = JobInfo.Builder(KNOCK_JOB_ID, component)
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            .setExtras(extras)
        if (Build.VERSION.SDK_INT >= 31) {
            try {
                if (scheduler.schedule(builder().setExpedited(true).build()) == JobScheduler.RESULT_SUCCESS) return
            } catch (e: Exception) {
            }
        }
        try {
            scheduler.schedule(builder().build())
        } catch (e: Exception) {
        }
    }

    // a knock owed: one that came inside the floor, or while a check-in
    // ran. one waiting at a time, it fetches for every address
    fun scheduleKnockLater(context: Context, waitMs: Long) {
        if (!KryfoState.hasData(context)) return
        val scheduler = context.getSystemService(JobScheduler::class.java) ?: return
        if (scheduler.getPendingJob(KNOCK_LATER_JOB_ID) != null) return
        val component = ComponentName(context, HaloPeriodicJobService::class.java)
        val extras = PersistableBundle().apply { putString("why", "push") }
        try {
            scheduler.schedule(
                JobInfo.Builder(KNOCK_LATER_JOB_ID, component)
                    .setMinimumLatency(waitMs.coerceIn(1_000L, KnockGate.FLOOR_MS))
                    .setOverrideDeadline(waitMs.coerceIn(1_000L, KnockGate.FLOOR_MS) + 60_000L)
                    .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                    .setExtras(extras)
                    .build()
            )
        } catch (e: Exception) {
        }
    }
}
