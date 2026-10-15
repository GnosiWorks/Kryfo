package app.kryfo

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

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
        // here, not on a screen: a process the service started has none
        MethodChannel(engine.dartExecutor.binaryMessenger, "halo/restart")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "clock" -> result.success(QuietRestart.clock(this))
                    "arm" -> result.success(QuietRestart.arm(this))
                    "end" -> result.success(QuietRestart.end())
                    else -> result.notImplemented()
                }
            }
        // the helper app mode, here so a process with no screen answers too
        MethodChannel(engine.dartExecutor.binaryMessenger, HelperPush.CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "helperApps" -> result.success(HelperPush.distributors(this))
                    "helperChosen" -> result.success(HelperPush.distributor(this))
                    "helperEndpoints" -> result.success(HelperPush.endpoints(this))
                    "helperKnocked" -> result.success(HelperPush.knockedOnes(this))
                    "helperRegister" -> {
                        val pkg = call.argument<String>("package")
                        val instance = call.argument<String>("instance")
                        result.success(
                            if (pkg == null || instance.isNullOrEmpty()) false
                            else HelperPush.register(this, pkg, instance)
                        )
                    }
                    "helperUnregisterOne" -> {
                        val instance = call.argument<String>("instance")
                        if (!instance.isNullOrEmpty()) HelperPush.unregister(this, instance)
                        result.success(true)
                    }
                    "helperKnockAgain" -> {
                        JobSetup.scheduleKnockLater(this, 10_000L)
                        result.success(true)
                    }
                    "helperUnregister" -> {
                        HelperPush.unregisterAll(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        // on the engine of the process, so a check-in without a screen hears it too
        NetWatch.start(this, engine)
        JobSetup.schedule(this)
        // a file handed to another app to open is a copy in cache/open/,
        // one shared a copy in cache/share_plus/. the app it went to may
        // still be reading it after this process was restarted, so one is
        // shredded only once past the grace, as on resume
        Thread {
            if (Shred.handed(cacheDir)) JobSetup.scheduleCopySweep(this)
            Shred.dropBackups(cacheDir, false)
            ToolsBridge.sweep(cacheDir, true)
        }.start()
    }
}
