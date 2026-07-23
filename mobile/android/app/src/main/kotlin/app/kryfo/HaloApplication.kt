package app.kryfo

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

// one flutter engine for the life of the process, not the life of a screen.
//
// with the engine owned by the activity, leaving the app froze the dart
// isolate and the nostr poll loop stopped, so nothing arrived until you
// opened halo again. owning it here means tor and the poll timer keep
// running in the background, which is the whole point of a messenger.
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
    }
}
