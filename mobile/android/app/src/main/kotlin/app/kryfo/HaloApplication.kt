package app.kryfo

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

// one flutter engine for the life of the process, not the life of a screen,
// so tor and the poll timer keep running while the app is in the background.
class HaloApplication : Application() {
    companion object {
        const val ENGINE_ID = "halo_engine"
    }

    override fun onCreate() {
        super.onCreate()
        // the reopen screen's process runs nothing of the app
        if (ReopenActivity.inOwnProcess()) return
        val engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        JobSetup.schedule(this)
        // a file handed to another app to open is a copy in cache/open/,
        // one shared a copy in cache/share_plus/. the app it went to may
        // still be reading it after this process was restarted, so one is
        // shredded only once past the grace, as on resume
        Thread {
            Shred.handed(cacheDir)
            ToolsBridge.sweep(cacheDir, true)
        }.start()
    }
}
