package com.halo.halo_app

import android.app.job.JobParameters
import android.app.job.JobService
import android.util.Log

class HaloPeriodicJobService : JobService() {
    override fun onStartJob(params: JobParameters?): Boolean {
        Log.i("halo-engine", "periodic check fired at ${System.currentTimeMillis()}")
        // sprint 9.1: drain engine.nostrPoll() + post per-message notifications here
        return false  // synchronous, nothing async pending
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        return false
    }
}
