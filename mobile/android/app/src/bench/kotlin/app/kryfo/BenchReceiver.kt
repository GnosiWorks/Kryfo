package app.kryfo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

// debug and profile builds only (src/bench is no source of a release): the
// reliability harness sends a numbered text from here. its manifest entry
// asks for DUMP, which adb's shell holds and no installed app can.
//   am broadcast --user 10 -n app.kryfo/.BenchReceiver --es to <name> --ei n <count>
class BenchReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val to = intent?.getStringExtra("to") ?: return
        val n = intent.getIntExtra("n", 0)
        // the screen may be off: the cpu stays up until dart answers, a minute at most
        val lock = (context.getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "kryfo:bench")
        lock.acquire(60_000L)
        val main = Handler(Looper.getMainLooper())
        var tries = 0
        fun done(what: String) {
            Log.i(TAG, "bench: asked n=$n $what")
            if (lock.isHeld) lock.release()
        }
        fun ask() {
            val engine = FlutterEngineCache.getInstance().get(HaloApplication.ENGINE_ID)
            if (engine == null) {
                done("no engine")
                return
            }
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod(
                "send",
                mapOf("to" to to, "n" to n),
                object : MethodChannel.Result {
                    override fun success(result: Any?) = done("ok=$result")
                    override fun error(code: String, message: String?, details: Any?) = done("error")
                    // a process the broadcast started: dart is still booting
                    override fun notImplemented() {
                        if (++tries < 15) main.postDelayed({ ask() }, 2_000L) else done("no answer")
                    }
                },
            )
        }
        ask()
    }

    companion object {
        const val CHANNEL = "kryfo/bench"
        const val TAG = "halo-engine"
    }
}
