// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Application
import java.io.File
import java.nio.file.Files
import java.security.KeyStore
import javax.crypto.spec.SecretKeySpec
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

// android refused its own clear: the keys and the whole data folder go by
// hand, not only the folders dart reaches
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class WipeFallbackTest {
    private fun keys(vararg names: String): KeyStore {
        val ks = KeyStore.getInstance("PKCS12").apply { load(null, null) }
        val pw = KeyStore.PasswordProtection(CharArray(0))
        for (n in names) {
            ks.setEntry(n, KeyStore.SecretKeyEntry(SecretKeySpec(ByteArray(32) { 7 }, "AES")), pw)
        }
        return ks
    }

    private fun put(root: File, path: String, text: String = "kept") {
        val f = File(root, path)
        f.parentFile!!.mkdirs()
        f.writeText(text)
    }

    @Test
    fun everyKeyAndEveryFolderGoes() {
        val data = Files.createTempDirectory("wipe").toFile()
        try {
            put(data, "shared_prefs/FlutterSecureStorage.xml", "<map><string name=\"k\">sealed</string></map>")
            put(data, "shared_prefs/kryfo_window.xml")
            put(data, "databases/plugin.db")
            put(data, "no_backup/state")
            put(data, "app_flutter/halo.db")
            put(data, "code_cache/x")
            put(data, "lib/libapp.so")
            val ks = keys("FlutterSecureStoragePluginKey", "kryfo_pin", "kryfo_bio")
            WipeFallback.erase(data, ks)
            assertEquals(0, ks.size())
            assertEquals(listOf("lib"), data.list()!!.sorted())
            assertTrue(File(data, "lib/libapp.so").exists())
            assertFalse(File(data, "shared_prefs").exists())
        } finally {
            data.deleteRecursively()
        }
    }

    @Test
    fun noKeystoreStillTakesTheFiles() {
        val data = Files.createTempDirectory("wipe").toFile()
        try {
            put(data, "shared_prefs/FlutterSecureStorage.xml")
            WipeFallback.erase(data, null)
            assertEquals(emptyList<String>(), data.list()!!.toList())
        } finally {
            data.deleteRecursively()
        }
    }
}
