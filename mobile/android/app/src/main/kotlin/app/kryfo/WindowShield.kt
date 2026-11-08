// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

// the window's secure flag and its picture in recents. dart holds the flag
// for the lock screen, pin screens, the chats that block and, below android
// 13, the whole time a pin is set. a pin set keeps the app out of recents:
// android 13 and later have a switch for that ([picture] is null before).
// each step goes on its own and never throws to the caller: a step
// refused is tried again on the next change, and hold and hide say false
internal class WindowShield(
    private val flag: (secure: Boolean) -> Unit,
    private val picture: ((recentsPicture: Boolean) -> Unit)?,
) {
    // dart's flag
    var held = false
        private set
    // a pin is set
    var hidden = false
        private set

    // a fresh window: no flag, recents takes its picture. null: refused,
    // so unknown
    private var flagSent: Boolean? = false
    private var pictureSent: Boolean? = true

    val secure get() = held
    val recentsPicture get() = !(held || hidden)

    // what the last run left, before dart says anything
    fun start(held: Boolean, hidden: Boolean) {
        this.held = held
        this.hidden = hidden
        push()
    }

    // true when the window is as asked
    fun hold(on: Boolean): Boolean {
        held = on
        return push()
    }

    fun hide(on: Boolean): Boolean {
        hidden = on
        return push()
    }

    private fun push(): Boolean {
        val s = secure
        if (s != flagSent) flagSent = if (step { flag(s) }) s else null
        val p = recentsPicture
        val pic = picture ?: return flagSent == s
        if (p != pictureSent) pictureSent = if (step { pic(p) }) p else null
        return flagSent == s && pictureSent == p
    }

    private inline fun step(body: () -> Unit): Boolean = try {
        body()
        true
    } catch (_: Throwable) {
        false
    }

    companion object {
        // a new screen on the engine. its window and surface hold nothing
        // of what dart sent before, and a step refused at start left dart
        // believing it, so dart sends both again as they are
        const val ATTACHED = "attached"

        // true when it went out. never throws: this runs inside onCreate
        fun tellAttached(send: (String) -> Unit): Boolean = try {
            send(ATTACHED)
            true
        } catch (_: Throwable) {
            false
        }

        // dart's call: true when the block was asked on and did not all go
        // on, so dart hears an error and asks again. never a quiet success
        fun refusedOn(on: Boolean, set: (Boolean) -> Boolean): Boolean {
            val ok = try {
                set(on)
            } catch (_: Throwable) {
                false
            }
            return on && !ok
        }
    }
}
