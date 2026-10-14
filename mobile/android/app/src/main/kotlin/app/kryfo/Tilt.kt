package app.kryfo

import android.content.Context
import android.view.OrientationEventListener
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

// the angle the phone is held at, from the accelerometer, whatever the
// screen's own orientation: clockwise from upright, -1 lying flat. only
// listened to while the camera is open
object Tilt {
    const val CHANNEL = "kryfo/tilt"

    private var listener: OrientationEventListener? = null

    fun start(context: Context, engine: FlutterEngine) {
        EventChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    stop()
                    var last = Int.MIN_VALUE
                    val l = object : OrientationEventListener(context) {
                        // called on the main thread. a few degrees of wobble
                        // are not worth a message
                        override fun onOrientationChanged(angle: Int) {
                            val small = angle >= 0 && last >= 0 &&
                                Math.floorMod(angle - last + 180, 360) - 180 in -4..4
                            if (angle == last || small) return
                            last = angle
                            sink.success(angle)
                        }
                    }
                    if (!l.canDetectOrientation()) return
                    listener = l
                    l.enable()
                }

                override fun onCancel(arguments: Any?) = stop()
            })
    }

    private fun stop() {
        listener?.disable()
        listener = null
    }
}
