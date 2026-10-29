// SPDX-License-Identifier: GPL-3.0-or-later
// android's own word that this window was screenshotted (14 and later) or
// shows in a screen recording (15 and later). told to dart on this phone
// alone: nothing about it is sent anywhere
package app.kryfo

import android.app.Activity
import android.os.Build
import android.view.WindowManager
import io.flutter.plugin.common.BasicMessageChannel
import java.util.function.Consumer

class CaptureWatch(private val activity: Activity) {
    var channel: BasicMessageChannel<String>? = null
    private var shot: Activity.ScreenCaptureCallback? = null
    private var rec: Consumer<Int>? = null
    private var recording = false

    // while the window is shown: android takes them only then
    fun start() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE && shot == null) {
            val cb = Activity.ScreenCaptureCallback { channel?.send("shot") }
            try {
                activity.registerScreenCaptureCallback(activity.mainExecutor, cb)
                shot = cb
            } catch (e: Exception) {
                android.util.Log.i("kryfo", "capture watch: no screenshot callback")
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM && rec == null) {
            val cb = Consumer<Int> { state -> recorded(state) }
            try {
                val now = activity.windowManager.addScreenRecordingCallback(activity.mainExecutor, cb)
                rec = cb
                recorded(now)
            } catch (e: Exception) {
                android.util.Log.i("kryfo", "capture watch: no recording callback")
            }
        }
    }

    fun stop() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            shot?.let {
                try {
                    activity.unregisterScreenCaptureCallback(it)
                } catch (_: Exception) {}
            }
        }
        shot = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            rec?.let {
                try {
                    activity.windowManager.removeScreenRecordingCallback(it)
                } catch (_: Exception) {}
            }
        }
        rec = null
        if (recording) {
            recording = false
            channel?.send("rec:0")
        }
    }

    private fun recorded(state: Int) {
        val on = Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM &&
            state == WindowManager.SCREEN_RECORDING_STATE_VISIBLE
        if (on == recording) return
        recording = on
        channel?.send(if (on) "rec:1" else "rec:0")
    }
}
