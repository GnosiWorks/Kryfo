// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.content.Context
import java.io.File

// whether there is anything here to keep running for.
// after a panic wipe, anything that starts kryfo without a person (the job,
// the boot receiver, the listener service) would make a fresh identity, bring
// tor up and post a notification. so none of them run unless the database
// exists, which the app creates the first time it is opened.
object KryfoState {
    fun hasData(context: Context): Boolean = try {
        File(context.dataDir, "app_flutter/halo.db").exists()
    } catch (e: Exception) {
        // cannot tell: keep delivery running rather than break it
        true
    }
}
