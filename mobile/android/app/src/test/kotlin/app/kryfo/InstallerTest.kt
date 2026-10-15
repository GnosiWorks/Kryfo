// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import org.junit.After
import org.junit.Assert.assertEquals
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
    fun aZipCutShortGoesByItsFirstEntry() {
        // no end record: nothing installs it, unless its first entry is an app's
        val f = bytes("x.zip", byteArrayOf(0x50, 0x4B, 3, 4, 9, 9, 9, 9))
        assertFalse(Installer.refused(f, "x.zip", "application/zip"))
        val app = zip("a.zip", "AndroidManifest.xml", "classes.dex").readBytes()
        val cut = bytes("y.zip", app.copyOfRange(0, 80))
        assertTrue(Installer.refused(cut, "y.zip", "application/zip"))
    }

    @Test
    fun everythingElseOpens() {
        assertFalse(Installer.refused(zip("a.zip", "a.txt", "b/c.png"), "a.zip", "application/zip"))
        assertFalse(Installer.refused(zip("d.docx", "word/document.xml"), "d.docx", null))
        assertFalse(Installer.refused(bytes("x.pdf", "%PDF-1.7\n".toByteArray()), "x.pdf", "application/pdf"))
        assertFalse(Installer.refused(bytes("t.txt", "PK is a text".toByteArray()), "t.txt", "text/plain"))
        assertFalse(Installer.refused(File("/nonexistent/x.pdf"), "x.pdf", "application/pdf"))
    }

    private fun end(count: Int, size: Int, comment: Int = 0): ByteArray {
        val b = java.nio.ByteBuffer.allocate(22).order(java.nio.ByteOrder.LITTLE_ENDIAN)
        b.putInt(0x06054b50).putShort(0).putShort(0)
        b.putShort(count.toShort()).putShort(count.toShort())
        b.putInt(size).putInt(0).putShort(comment.toShort())
        return b.array()
    }

    @Test
    fun anAppBehindOtherBytesIsRefused() {
        val app = zip("a.zip", "AndroidManifest.xml", "classes.dex").readBytes()
        val jpeg = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0xE0.toByte()) +
            ByteArray(500) { 1 }
        val f = bytes("holiday.jpg", jpeg + app)
        assertTrue(Installer.refused(f, "holiday.jpg", "image/jpeg"))
    }

    @Test
    fun anEndThatCannotBeReadIsRefused() {
        val f = bytes("notes.txt", ByteArray(100) { 7 } + end(1, 4000))
        assertTrue(Installer.refused(f, "notes.txt", "text/plain"))
    }

    @Test
    fun aSignatureWhoseCommentMissesTheEndIsNoZip() {
        val f = bytes("notes.txt", "just text ".toByteArray() + end(1, 46, comment = 9))
        assertFalse(Installer.refused(f, "notes.txt", "text/plain"))
    }

    @Test
    fun anAppAtAnyDepthIsRefused() {
        for (inner in listOf("tools/old/Game.APK", "x.apks", "a/b/c.xapk", "m.apkm", "b/app.aab")) {
            assertTrue(inner, Installer.refused(zip("s.zip", "readme.txt", inner), "s.zip", null))
        }
        assertFalse(Installer.refused(zip("s.zip", "a/b.txt", "apk-notes.md"), "s.zip", null))
    }

    @Test
    fun moreEntriesThanAnyAppIsRefused() {
        val f = File.createTempFile("in_", "_many.zip")
        made.add(f)
        ZipOutputStream(f.outputStream().buffered()).use { z ->
            for (i in 0..Installer.MAX_ENTRIES) {
                z.putNextEntry(ZipEntry("e$i"))
                z.closeEntry()
            }
        }
        assertTrue(Installer.refused(f, "many.zip", "application/zip"))
    }

    @Test
    fun aNameIsReadAsItIsSaved() {
        for (n in listOf("x.apk.", "x.apk ", "x.apk\u200B", "x.ap\u200Dk", "x.ap\u0336k", "x.APK\uFE0F", "x.aab")) {
            assertTrue(n, Installer.named(n))
        }
        assertFalse(Installer.named("x.pdf"))
        assertFalse(Installer.named("x.apk.pdf"))
        // one composed form either way
        assertEquals(Installer.extOf("cafe\u0301.pdf"), Installer.extOf("caf\u00e9.pdf"))
    }
}
