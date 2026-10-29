// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

// the window's secure flag and its picture in recents. dart holds the flag
// for the lock screen, pin screens and the chats that block. a pin set
// keeps the app out of recents: android 13 and later have a switch for
// that, older ones take the picture as the app leaves, so the flag goes on
// first and comes off again on the way back
internal class WindowShield(
    private val sdk: Int,
    private val apply: (secure: Boolean, recentsPicture: Boolean) -> Unit,
) {
    // dart's flag
    var held = false
        private set
    // a pin is set
    var hidden = false
        private set
    // the flag a pin put on for the way out, below android 13
    var covered = false
        private set

    // a fresh window: no flag, recents takes its picture
    private var sent = false to true

    val secure get() = held || covered
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
        if (!on) covered = false
        push()
    }

    // home, recents or anything else in front: before android takes the
    // picture
    fun leaving() {
        if (sdk >= 33 || !hidden) return
        covered = true
        push()
    }

    fun back() {
        covered = false
        push()
    }

    private fun push() {
        val now = secure to recentsPicture
        if (now == sent) return
        sent = now
        apply(now.first, now.second)
    }
}
