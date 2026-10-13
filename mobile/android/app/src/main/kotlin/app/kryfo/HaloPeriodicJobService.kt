package app.kryfo

import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

// the floor under delivery. every fifteen minutes the system runs this,
// in a doze maintenance window if it has to. if the process was killed,
// the job restarts it and the application boots the engine on its own.
// if it was asleep, the job hands it a window: the dart side kicks every
// relay socket, drains what arrives, and reports back. then the job ends.
class HaloPeriodicJobService : JobService() {
    private val main = Handler(Looper.getMainLooper())
    // the same instance serves every firing in a warm process, the
    // come-back job's beside the periodic one's: each run has its own end
    private val runs = JobRuns()

    override fun onStartJob(params: JobParameters?): Boolean {
        // wiped: this job outlived the data it was for. end it for good
        // instead of booting a fresh identity nobody asked for.
        if (!KryfoState.hasData(this)) {
            Log.i("halo-engine", "periodic job: no data, cancelling")
            getSystemService(JobScheduler::class.java)?.cancelAll()
            return false
        }
        Log.i("halo-engine", "periodic job: start")
        // a check-in's budget runs from here, not from when dart answers.
        // the boot clock, which a change of the wall clock does not move
        val startedAt = SystemClock.elapsedRealtime()
        // bring the listener back if something took it. not allowed from
        // the background on newer androids, and that is fine: the engine
        // in this process does the actual work either way. one that is up
        // is left alone: starting it again only posts its notification anew
        val staysOn = DeliveryPrefs.staysOn(this)
        val up = staysOn && HaloListenerService.running
        if (staysOn && !up) {
            try {
                HaloListenerService.start(this)
            } catch (e: Exception) {
                Log.i("halo-engine", "periodic job: listener not restarted: ${e.javaClass.simpleName}")
            }
        }
        val engine = FlutterEngineCache.getInstance().get(HaloApplication.ENGINE_ID)
        if (engine == null) {
            Log.i("halo-engine", "periodic job: no engine")
            return false
        }
        val run = runs.start(params?.jobId ?: 0) { jobFinished(params, false) }
        // a hard stop of its own, so a wedged drain cannot hold the job
        // open. a check-in has to bring tor up, fetch and take it down again
        // inside its one window, so it gets longer than a knock on sockets
        // that are already there. android allows a job ten minutes.
        main.postDelayed(run.finish, if (staysOn) 60_000 else 170_000)
        ask(engine, run, if (staysOn) 0 else 15, up, startedAt)
        return true
    }

    // in a process the job itself just started, dart may not have its
    // handler up yet. always-on does not care: the boot that is under way
    // connects anyway. a check-in does, because nothing else will fetch.
    // [up] tells dart the listener was already running: if it has been
    // listening all along, there is nothing for the job to do
    private fun ask(
        engine: io.flutter.embedding.engine.FlutterEngine,
        run: JobRuns.Run,
        retries: Int,
        up: Boolean,
        startedAt: Long
    ) {
        // stopped while a retry waited: android has taken the job back
        if (run.finished) return
        val finish = run.finish
        try {
            MethodChannel(engine.dartExecutor.binaryMessenger, "halo/job")
                .invokeMethod("drain", mapOf("up" to up, "ago" to SystemClock.elapsedRealtime() - startedAt), object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        Log.i("halo-engine", "periodic job: drained $result")
                        main.removeCallbacks(finish)
                        finish.run()
                    }
                    override fun error(code: String, msg: String?, details: Any?) {
                        Log.i("halo-engine", "periodic job: drain error $code")
                        main.removeCallbacks(finish)
                        finish.run()
                    }
                    override fun notImplemented() {
                        if (retries > 0 && !run.finished) {
                            val again = Runnable { ask(engine, run, retries - 1, up, startedAt) }
                            run.retry = again
                            main.postDelayed(again, 2_000)
                            return
                        }
                        Log.i("halo-engine", "periodic job: dart not listening yet")
                        main.removeCallbacks(finish)
                        finish.run()
                    }
                })
        } catch (e: Exception) {
            Log.i("halo-engine", "periodic job: ${e.javaClass.simpleName}")
            main.removeCallbacks(finish)
            finish.run()
        }
    }

    // only the run of the job android stopped
    override fun onStopJob(params: JobParameters?): Boolean {
        runs.stop(params?.jobId ?: 0)?.let { run ->
            main.removeCallbacks(run.finish)
            run.retry?.let { main.removeCallbacks(it) }
        }
        return true
    }
}
