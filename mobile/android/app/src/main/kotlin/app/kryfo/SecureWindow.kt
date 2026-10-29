// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.util.Log

// the screenshot block, step by step: a window or a system that refuses
// one step, a linkage error from an odd rom too, still gets the others
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
            } catch (e: Throwable) {
                all = false
                try {
                    Log.i("kryfo", "setSecure step refused: ${e.javaClass.simpleName}")
                } catch (_: Throwable) {
                }
            }
        }
        return all
    }

    // dart's call: true when the block was asked on and did not all go on,
    // so dart hears an error and asks again. never a quiet success
    fun refusedOn(on: Boolean, set: (Boolean) -> Boolean): Boolean {
        val ok = try {
            set(on)
        } catch (_: Throwable) {
            false
        }
        return on && !ok
    }
}
