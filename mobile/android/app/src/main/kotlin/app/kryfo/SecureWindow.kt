// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.util.Log

// the screenshot block, step by step: a window or a system that refuses
// one step still gets the others, and nothing of it reaches the caller
object SecureWindow {
    class Steps(
        val flag: (Boolean) -> Unit,
        // android 13 and later keep their own picture for recents
        val recents: ((Boolean) -> Unit)?,
        val keep: (Boolean) -> Unit,
        val surface: (Boolean) -> Unit,
    )

    // true when every step went through
    fun apply(on: Boolean, s: Steps): Boolean {
        var all = true
        for (step in listOfNotNull(s.flag, s.recents, s.keep, s.surface)) {
            try {
                step(on)
            } catch (e: Exception) {
                all = false
                try {
                    Log.i("kryfo", "setSecure step refused: ${e.javaClass.simpleName}")
                } catch (_: Throwable) {
                }
            }
        }
        return all
    }
}
