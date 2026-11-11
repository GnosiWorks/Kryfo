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

    // dart's own folder and the one it shreds behind: dart is still on them
    val DARTS = setOf("app_flutter", "wipe_held")
    // what dart never reaches, first: dart exits a few seconds from now
    val FIRST = listOf("databases", "shared_prefs", "no_backup")

    // the keys first: with them gone nothing here opens, so the files are
    // unlinked, not zeroed, and all go before dart exits. the native
    // libraries' link stays, it is the system's
    fun erase(data: File, ks: KeyStore?) {
        if (ks != null) dropKeys(ks)
        val all = data.listFiles()?.toList() ?: return
        val order = all.sortedBy { f -> FIRST.indexOf(f.name).let { if (it < 0) FIRST.size else it } }
        for (f in order) {
            if (f.name == "lib" || f.name in DARTS) continue
            unlink(f)
        }
    }

    // children before their folder. a link is unlinked, never followed
    private fun unlink(f: File) {
        if (!Shred.isLink(f) && f.isDirectory) f.listFiles()?.forEach { unlink(it) }
        f.delete()
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
