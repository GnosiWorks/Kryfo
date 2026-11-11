package app.kryfo

import android.util.Log

// logcat only in a debuggable build: in a release a line would date the
// vault, a protected screen or a knock for anyone with adb or a bug report
object DebugLog {
    @Volatile
    var on = false

    fun i(tag: String, line: String) {
        if (on) Log.i(tag, line)
    }
}
