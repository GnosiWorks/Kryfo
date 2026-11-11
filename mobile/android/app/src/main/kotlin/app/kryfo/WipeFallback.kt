// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.content.Context
import java.io.File
import java.security.KeyStore

// the wipe when android refuses its own clear: every key the app keeps in
// the keystore, then everything under its data folder, not only the three
// folders dart reaches. secure storage's key goes with the rest, so what a
// stale block of its file keeps opens nowhere
object WipeFallback {
    fun run(ctx: Context) {
        val ks = try {
            KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        } catch (e: Exception) {
            null
        }
        erase(File(ctx.applicationInfo.dataDir), ks)
    }

    // the keys first: a stop part way leaves only files nothing opens.
    // the native libraries' link stays, it is the system's
    fun erase(data: File, ks: KeyStore?) {
        if (ks != null) dropKeys(ks)
        data.listFiles()?.forEach { if (it.name != "lib") Shred.tree(it) }
    }

    fun dropKeys(ks: KeyStore) {
        val names = try {
            ks.aliases().toList()
        } catch (e: Exception) {
            emptyList()
        }
        for (a in names) {
            try {
                ks.deleteEntry(a)
            } catch (e: Exception) {
                // the next one all the same
            }
        }
    }
}
