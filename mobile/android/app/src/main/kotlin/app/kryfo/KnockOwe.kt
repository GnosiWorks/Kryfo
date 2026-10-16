// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.content.Context

// a knock that comes while its job is already waiting or running is owed,
// not dropped: once that job has ended, it is asked for again. kept across
// a process restart. the hourly cap in KnockGate still bounds the battery
class KnockOwe(
    private val pending: () -> Boolean,
    private val schedule: () -> Unit,
    private val store: Store,
) {
    interface Store {
        var owed: Boolean
    }

    fun knock() {
        if (pending()) store.owed = true else schedule()
    }

    // a job of this service ended: one owed knock goes now
    fun ended() {
        if (store.owed && !pending()) {
            store.owed = false
            schedule()
        }
    }

    class Prefs(private val c: Context, private val id: Int) : Store {
        private fun p() = c.getSharedPreferences("helper_push", Context.MODE_PRIVATE)
        override var owed: Boolean
            get() = p().getBoolean("owed.$id", false)
            set(v) {
                p().edit().putBoolean("owed.$id", v).apply()
            }
    }
}
