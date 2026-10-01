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
        val engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        JobSetup.schedule(this)
        // a file handed to another app to open is a copy in cache/open/,
        // one shared a copy in cache/share_plus/. nothing needs either past
        // the session that made it.
        Thread {
            java.io.File(cacheDir, "open").deleteRecursively()
            java.io.File(cacheDir, "share_plus").deleteRecursively()
            ToolsBridge.sweep(cacheDir, true)
        }.start()
    }
}
