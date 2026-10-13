// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.io.OutputStream
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

class SaveDocTest {
    private lateinit var src: File

    @Before
    fun made() {
        src = File.createTempFile("kryfo-backup-", ".kryfo")
        src.writeBytes(ByteArray(600_000) { (it % 251).toByte() })
    }

    @After
    fun gone() {
        src.delete()
        SaveDoc.take()?.reply(SaveDoc.FAILED)
    }

    @Test
    fun everyByteThereIsSaved() {
        val out = ByteArrayOutputStream()
        val state = SaveDoc.copy(src, { out }, { src.length() }, { null })
        assertEquals(SaveDoc.SAVED, state)
        assertEquals(src.length(), out.size().toLong())
    }

    @Test
    fun aWriteThatThrowsIsNotSaved() {
        val broken = object : OutputStream() {
            var n = 0
            override fun write(b: Int) {
                if (++n > 1000) throw IOException("no space")
            }
        }
        assertEquals(SaveDoc.FAILED, SaveDoc.copy(src, { broken }, { null }, { null }))
    }

    @Test
    fun noStreamIsNotSaved() {
        assertEquals(SaveDoc.FAILED, SaveDoc.copy(src, { null }, { null }, { null }))
        assertEquals(
            SaveDoc.FAILED,
            SaveDoc.copy(src, { throw SecurityException("refused") }, { null }, { null }),
        )
    }

    @Test
    fun aProviderThatKeepsLessIsNotSaved() {
        // takes every byte, keeps the first half
        val half = ByteArrayOutputStream()
        val state = SaveDoc.copy(
            src,
            { half },
            { src.length() / 2 },
            { ByteArrayInputStream(half.toByteArray().copyOf(half.size() / 2)) },
        )
        assertEquals(SaveDoc.FAILED, state)
    }

    @Test
    fun aProviderThatKeepsNothingIsNotSaved() {
        val state = SaveDoc.copy(
            src,
            { ByteArrayOutputStream() },
            { 0L },
            { ByteArrayInputStream(ByteArray(0)) },
        )
        assertEquals(SaveDoc.FAILED, state)
    }

    @Test
    fun aSizeThatLagsButReadsBackWholeIsSaved() {
        val out = ByteArrayOutputStream()
        val state = SaveDoc.copy(
            src,
            { out },
            { 0L },
            { ByteArrayInputStream(out.toByteArray()) },
        )
        assertEquals(SaveDoc.SAVED, state)
    }

    @Test
    fun anEmptySourceIsNotSaved() {
        src.writeBytes(ByteArray(0))
        assertEquals(
            SaveDoc.FAILED,
            SaveDoc.copy(src, { ByteArrayOutputStream() }, { 0L }, { null }),
        )
    }

    @Test
    fun theAnswerReachesTheCallEvenFromAnotherScreen() {
        // begun by one screen, answered by the one android built after it
        val got = mutableListOf<Map<String, Any?>>()
        assertNotNull(SaveDoc.begin(src.path) { got.add(it) })
        assertEquals(SaveDoc.PICKING, SaveDoc.state()["stage"])
        val p = SaveDoc.take()
        assertNotNull(p)
        assertEquals(src.path, p!!.path)
        assertEquals(SaveDoc.COPYING, SaveDoc.state()["stage"])
        p.reply(SaveDoc.SAVED, "Download")
        p.reply(SaveDoc.FAILED)
        assertEquals(listOf(mapOf("state" to SaveDoc.SAVED, "where" to "Download")), got)
        assertEquals(SaveDoc.IDLE, SaveDoc.state()["stage"])
        assertNull(SaveDoc.take())
    }

    @Test
    fun aDialogThatNeverAnsweredEndsWhenANewOneOpens() {
        val first = mutableListOf<Map<String, Any?>>()
        val second = mutableListOf<Map<String, Any?>>()
        SaveDoc.begin(src.path) { first.add(it) }
        SaveDoc.begin(src.path) { second.add(it) }
        assertEquals(listOf(SaveDoc.FAILED), first.map { it["state"] })
        assertEquals(emptyList<Map<String, Any?>>(), second)
        SaveDoc.take()!!.reply(SaveDoc.CANCELLED)
        assertEquals(listOf(SaveDoc.CANCELLED), second.map { it["state"] })
    }

    @Test
    fun aNoBeforeTheDialogCoveredTheAppIsNotABackOut() {
        SaveDoc.begin(src.path) {}
        // answered by android at once: the picker went to a task of its own
        assertEquals(SaveDoc.FAILED, SaveDoc.backedOut())
        SaveDoc.coveredNow()
        assertEquals(SaveDoc.CANCELLED, SaveDoc.backedOut())
        SaveDoc.take()!!.reply(SaveDoc.CANCELLED)
        // a stop with no dialog up counts for nothing
        SaveDoc.coveredNow()
        SaveDoc.begin(src.path) {}
        assertEquals(SaveDoc.FAILED, SaveDoc.backedOut())
    }

    @Test
    fun noSecondDialogWhileACopyRuns() {
        val first = mutableListOf<Map<String, Any?>>()
        SaveDoc.begin(src.path) { first.add(it) }
        val p = SaveDoc.take()!!
        assertNull(SaveDoc.begin(src.path) {})
        p.reply(SaveDoc.SAVED)
        assertEquals(listOf(SaveDoc.SAVED), first.map { it["state"] })
    }

    @Test
    fun theFolderItWentTo() {
        val ext = "com.android.externalstorage.documents"
        val dl = "com.android.providers.downloads.documents"
        assertEquals("Download/Kryfo", SaveDoc.placeOf(ext, "primary:Download/Kryfo/b.kryfo", null))
        assertEquals("Backups", SaveDoc.placeOf(ext, "1A2B-3C4D:Backups/b.kryfo", null))
        assertNull(SaveDoc.placeOf(ext, "primary:b.kryfo", null))
        assertEquals("Download", SaveDoc.placeOf(dl, "msf:31", "Downloads"))
        assertEquals(
            "Download/keep",
            SaveDoc.placeOf(dl, "raw:/storage/emulated/0/Download/keep/b.kryfo", null),
        )
        assertEquals("Drive", SaveDoc.placeOf("com.google.android.apps.docs.storage", "x", "Drive"))
        assertNull(SaveDoc.placeOf("some.provider", "x", " "))
        assertNull(SaveDoc.placeOf(null, null, null))
    }
}
