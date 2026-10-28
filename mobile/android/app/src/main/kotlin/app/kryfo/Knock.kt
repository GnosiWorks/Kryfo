// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.content.Context
import android.util.Log

// a knock, from the helper app or from google push: its bytes are never
// read, and it asks for the same check-in the fifteen-minute job runs. a
// job, not a call into dart: a process the knock started has no dart
// listening yet, and the job keeps it alive for the check-in. KnockGate
// paces it, since anything on the phone can send a knock
object Knock {
    fun arrived(c: Context, from: String) {
        val v = KnockGate.allow(c)
        when {
            v.go -> {
                Log.i("halo-engine", "$from: knock")
                JobSetup.scheduleKnock(c)
            }
            v.waitMs > 0 -> {
                Log.i("halo-engine", "$from: knock waits for the floor")
                JobSetup.scheduleKnockLater(c, v.waitMs)
            }
            else -> Log.i("halo-engine", "$from: knock dropped, too many this hour")
        }
    }
}
