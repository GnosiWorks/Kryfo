// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Activity
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

// the play build's application: the one engine, and google push's and the
// tip jar's channels beside the others, so a process with no screen answers
// too
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
        MethodChannel(engine.dartExecutor.binaryMessenger, PlayTips.CHANNEL)
            .setMethodCallHandler { call, result -> PlayTips.handle(this, call, result) }
        // the payment sheet opens over the screen in front
        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityResumed(a: Activity) {
                PlayTips.shown = WeakReference(a)
            }

            override fun onActivityPaused(a: Activity) {}
            override fun onActivityCreated(a: Activity, b: Bundle?) {}
            override fun onActivityStarted(a: Activity) {}
            override fun onActivityStopped(a: Activity) {}
            override fun onActivitySaveInstanceState(a: Activity, b: Bundle) {}
            override fun onActivityDestroyed(a: Activity) {
                if (PlayTips.shown?.get() === a) PlayTips.shown = null
            }
        })
    }
}
