package app.kryfo

import android.app.job.JobParameters
import android.app.job.JobService
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
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
    private var done = false

    override fun onStartJob(params: JobParameters?): Boolean {
        Log.i("halo-engine", "periodic job: start")
        // bring the listener back if something took it. not allowed from
        // the background on newer androids, and that is fine: the engine
        // in this process does the actual work either way.
        try {
            val intent = Intent(this, HaloListenerService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
            else startService(intent)
        } catch (e: Exception) {
            Log.i("halo-engine", "periodic job: listener not restarted: ${e.javaClass.simpleName}")
        }
        val engine = FlutterEngineCache.getInstance().get(HaloApplication.ENGINE_ID)
        if (engine == null) {
            Log.i("halo-engine", "periodic job: no engine")
            return false
        }
        val finish = Runnable {
            if (!done) {
                done = true
                jobFinished(params, false)
            }
        }
        // a hard stop so a wedged drain cannot hold the job open
        main.postDelayed(finish, 60_000)
        try {
            MethodChannel(engine.dartExecutor.binaryMessenger, "halo/job")
                .invokeMethod("drain", null, object : MethodChannel.Result {
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
                        Log.i("halo-engine", "periodic job: dart not listening yet")
                        main.removeCallbacks(finish)
                        finish.run()
                    }
                })
        } catch (e: Exception) {
            Log.i("halo-engine", "periodic job: ${e.javaClass.simpleName}")
            return false
        }
        return true
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        done = true
        return true
    }
}
