// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

// the play build's application: the one engine, and google push's channel
// beside the others, so a process with no screen answers too
class PlayApplication : HaloApplication() {
    override fun onCreate() {
        super.onCreate()
        if (ReopenActivity.inOwnProcess()) return
        // a process started by a push hands it over only with firebase up
        if (GooglePush.isOn(this)) GooglePush.app(this)
        // a delete owed since google push was left goes again
        GooglePush.settle(this)
        val engine = FlutterEngineCache.getInstance().get(HaloApplication.ENGINE_ID) ?: return
        MethodChannel(engine.dartExecutor.binaryMessenger, GooglePush.CHANNEL)
            .setMethodCallHandler { call, result -> GooglePush.handle(this, call, result) }
    }
}
