// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

// the window's secure flag and its picture in recents. dart holds the flag
// for the lock screen, pin screens, the chats that block and, below android
// 13, the whole time a pin is set. a pin set keeps the app out of recents:
// android 13 and later have a switch for that ([picture] is null before).
// each step goes on its own and nothing of it reaches the caller: a step
// refused is tried again on the next change
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

    fun hold(on: Boolean) {
        held = on
        push()
    }

    fun hide(on: Boolean) {
        hidden = on
        push()
    }

    private fun push() {
        val s = secure
        if (s != flagSent) flagSent = if (step { flag(s) }) s else null
        val p = recentsPicture
        val pic = picture ?: return
        if (p != pictureSent) pictureSent = if (step { pic(p) }) p else null
    }

    private inline fun step(body: () -> Unit): Boolean = try {
        body()
        true
    } catch (_: Throwable) {
        false
    }
}
