// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.content.Context
import java.io.File

// whether there is anything here to keep running for.
//
// a panic wipe clears every byte of the app's data, and then, within a
// minute, the periodic job that survived it started the process again: the
// application booted the engine, the engine made a fresh identity and onion
// key and brought tor up, and the listener service put "kryfo is on" back in
// the notification shade. nobody had opened the app. a wipe that announces
// itself with a notification and tor traffic defeats the point of it.
//
// so nothing that starts kryfo without a person - the job, the boot receiver,
// the listener service - does so unless the database exists. the app creates
// it the first time it is opened, onboarding included, so opening it is what
// switches the background back on. after a wipe it does not exist.
object KryfoState {
    fun hasData(context: Context): Boolean = try {
        File(context.dataDir, "app_flutter/halo.db").exists()
    } catch (e: Exception) {
        // cannot tell: behave as before rather than break delivery
        true
    }
}
