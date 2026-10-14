// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class InstallerTest {
    private val made = mutableListOf<File>()

    @After
    fun gone() {
        made.forEach { it.delete() }
    }

    private fun zip(name: String, vararg entries: String): File {
        val f = File.createTempFile("in_", "_$name")
        made.add(f)
        ZipOutputStream(f.outputStream()).use { z ->
            for (e in entries) {
                z.putNextEntry(ZipEntry(e))
                z.write(byteArrayOf(1, 2, 3))
                z.closeEntry()
            }
        }
        return f
    }

    private fun bytes(name: String, b: ByteArray): File {
        val f = File.createTempFile("in_", "_$name")
        made.add(f)
        f.writeBytes(b)
        return f
    }

    @Test
    fun anAppIsRefusedWhateverItIsCalled() {
        for (n in listOf("photo.jpg", "notes.pdf", "song.mp3", "file")) {
            val f = zip(n, "AndroidManifest.xml", "classes.dex", "resources.arsc")
            assertTrue(n, Installer.refused(f, n, "application/octet-stream"))
        }
    }

    @Test
    fun aBundleOfAppsIsRefused() {
        assertTrue(Installer.refused(zip("a.zip", "base.apk", "split_config.en.apk"), "a.zip", null))
        assertTrue(Installer.refused(zip("a.zip", "toc.pb", "splits/base-master.apk"), "a.zip", null))
        assertTrue(Installer.refused(zip("a.zip", "manifest.json", "app.apk"), "a.zip", null))
    }

    @Test
    fun anInstallerNameOrTypeIsRefused() {
        val pdf = bytes("x.pdf", "%PDF-1.7\n".toByteArray())
        for (n in listOf("x.apk", "x.APK", "photo.jpg.apk", "x.xapk", "x.apks", "x.apkm")) {
            assertTrue(n, Installer.refused(pdf, n, "application/pdf"))
        }
        assertTrue(Installer.refused(pdf, "x.pdf", Installer.MIME))
    }

    @Test
    fun aZipThatCannotBeReadIsRefused() {
        val f = bytes("x.zip", byteArrayOf(0x50, 0x4B, 3, 4, 9, 9, 9, 9))
        assertTrue(Installer.refused(f, "x.zip", "application/zip"))
    }

    @Test
    fun everythingElseOpens() {
        assertFalse(Installer.refused(zip("a.zip", "a.txt", "b/c.png"), "a.zip", "application/zip"))
        assertFalse(Installer.refused(zip("d.docx", "word/document.xml"), "d.docx", null))
        assertFalse(Installer.refused(bytes("x.pdf", "%PDF-1.7\n".toByteArray()), "x.pdf", "application/pdf"))
        assertFalse(Installer.refused(bytes("t.txt", "PK is a text".toByteArray()), "t.txt", "text/plain"))
        assertFalse(Installer.refused(File("/nonexistent/x.pdf"), "x.pdf", "application/pdf"))
    }
}
