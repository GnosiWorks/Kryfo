// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.io.OutputStream
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
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
        SaveDoc.cancel()
        SaveDoc.begin(src.path) {}
        SaveDoc.cancel()
    }

    // a copy with nothing in the way, read back from what was written
    private fun copyBack(
        out: ByteArrayOutputStream = ByteArrayOutputStream(),
        there: Long? = null,
        back: (ByteArray) -> ByteArray? = { it },
    ) = SaveDoc.copy(
        src,
        { out },
        { there },
        { back(out.toByteArray())?.let { ByteArrayInputStream(it) } },
        onCopied = {},
        stop = { false },
        onChecking = {},
    )

    @Test
    fun everyByteReadBackIsSaved() {
        val out = ByteArrayOutputStream()
        assertEquals(SaveDoc.SAVED, copyBack(out))
        assertEquals(src.length(), out.size().toLong())
        assertEquals(SaveDoc.SAVED, copyBack(there = src.length()))
        // the size can lag on some providers: the read-back decides
        assertEquals(SaveDoc.SAVED, copyBack(there = 0L))
    }

    @Test
    fun aRightSizeIsNotEnough() {
        // no read-back: never "saved", at most unchecked
        assertEquals(SaveDoc.UNCHECKED, copyBack(there = src.length()) { null })
        assertEquals(SaveDoc.UNCHECKED, copyBack(there = null) { null })
    }

    @Test
    fun noSizeStillReadsBack() {
        // the provider says nothing about the size and kept half
        assertEquals(
            SaveDoc.FAILED,
            copyBack(there = null) { it.copyOf(it.size / 2) },
        )
    }

    @Test
    fun aProviderThatSaysItKeptNothingIsNotSaved() {
        assertEquals(SaveDoc.FAILED, copyBack(there = 0L) { null })
        assertEquals(SaveDoc.FAILED, copyBack(there = 0L) { ByteArray(0) })
    }

    @Test
    fun aProviderThatKeepsLessIsNotSaved() {
        assertEquals(
            SaveDoc.FAILED,
            copyBack(there = src.length() / 2) { it.copyOf(it.size / 2) },
        )
    }

    @Test
    fun otherBytesOfTheSameLengthAreNotSaved() {
        assertEquals(
            SaveDoc.FAILED,
            copyBack(there = src.length()) { it.copyOf().also { b -> b[b.size - 1] = 0 } },
        )
    }

    @Test
    fun aReadBackThatThrowsIsUnchecked() {
        val state = SaveDoc.copy(
            src, { ByteArrayOutputStream() }, { null },
            { throw SecurityException("write only") },
            onCopied = {}, stop = { false }, onChecking = {},
        )
        assertEquals(SaveDoc.UNCHECKED, state)
    }

    // a place with no room says so, so the screen can say why, and the
    // half written there goes
    @Test
    fun aPlaceWithNoRoomIsFull() {
        fun full(e: IOException) = object : OutputStream() {
            var n = 0
            override fun write(b: Int) {
                if (++n > 1000) throw e
            }
        }
        val plain = IOException("write failed: ENOSPC (No space left on device)")
        assertEquals(SaveDoc.FULL, SaveDoc.copy(src, { full(plain) }, { null }, { null }))
        val wrapped = IOException("copy", IOException("No space left on device"))
        assertEquals(SaveDoc.FULL, SaveDoc.copy(src, { full(wrapped) }, { null }, { null }))
        var dropped = false
        val state = SaveDoc.copyInto(
            src,
            before = 0L,
            open = { full(plain) },
            sizeThere = { null },
            readBack = { null },
            drop = { dropped = true },
        )
        assertEquals(SaveDoc.FULL, state)
        assertTrue(dropped)
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
    fun anEmptySourceIsNotSaved() {
        src.writeBytes(ByteArray(0))
        assertEquals(SaveDoc.FAILED, copyBack())
    }

    @Test
    fun aCancelStopsTheCopyAndItAnswersFailed() {
        val got = mutableListOf<Map<String, Any?>>()
        val p = SaveDoc.begin(src.path) { got.add(it) }!!
        assertNotNull(SaveDoc.take(p.code))
        var blocks = 0
        val out = object : OutputStream() {
            override fun write(b: Int) {}
            override fun write(b: ByteArray, off: Int, len: Int) {
                // dart gives up after the first block
                if (++blocks == 1) assertEquals(SaveDoc.COPYING, SaveDoc.cancel())
            }
        }
        val state = SaveDoc.copy(src, { out }, { null }, { null })
        assertEquals(SaveDoc.FAILED, state)
        assertEquals(1, blocks)
        p.reply(state)
        assertEquals(listOf(SaveDoc.FAILED), got.map { it["state"] })
        assertEquals(SaveDoc.IDLE, SaveDoc.state()["stage"])
    }

    @Test
    fun theCheckIsAStageOfItsOwnAndAStoppedOneKeepsTheFile() {
        val p = SaveDoc.begin(src.path) {}!!
        SaveDoc.take(p.code)
        val out = ByteArrayOutputStream()
        val state = SaveDoc.copy(src, { out }, {
            // the size query is part of the check: a slow one is no stall
            assertEquals(SaveDoc.CHECKING, SaveDoc.state()["stage"])
            null
        }, {
            // checking, not copying: its own bytes move
            assertEquals(SaveDoc.CHECKING, SaveDoc.state()["stage"])
            assertEquals(0L, SaveDoc.state()["copied"])
            assertEquals(SaveDoc.CHECKING, SaveDoc.cancel())
            ByteArrayInputStream(out.toByteArray())
        })
        // every byte went out: a check given up on is unchecked, not failed
        assertEquals(SaveDoc.UNCHECKED, state)
        p.reply(state)
    }

    @Test
    fun aStoppedCheckOfAShortFileIsStillNotSaved() {
        val p = SaveDoc.begin(src.path) {}!!
        SaveDoc.take(p.code)
        val out = ByteArrayOutputStream()
        val state = SaveDoc.copy(src, { out }, { src.length() / 2 }, {
            SaveDoc.cancel()
            ByteArrayInputStream(out.toByteArray())
        })
        assertEquals(SaveDoc.FAILED, state)
        p.reply(state)
    }

    @Test
    fun aLockMidCopyFailsAndTakesWhatItWroteAway() {
        val p = SaveDoc.begin(src.path) {}!!
        SaveDoc.take(p.code)
        var blocks = 0
        val out = object : OutputStream() {
            override fun write(b: Int) {}
            override fun write(b: ByteArray, off: Int, len: Int) {
                if (++blocks == 1) {
                    assertEquals(SaveDoc.COPYING, SaveDoc.cancel(drop = true))
                    // the drop zeroes the file under the copy
                    src.writeBytes(ByteArray(src.length().toInt()))
                }
            }
        }
        var dropped = 0
        val state = SaveDoc.copyInto(
            src, 0L, { out }, { src.length() },
            { throw SecurityException("write only") },
        ) { dropped++ }
        assertEquals(SaveDoc.FAILED, state)
        assertEquals(1, blocks)
        assertEquals(1, dropped)
        p.reply(state)
    }

    @Test
    fun aLockInTheCheckFailsAndTakesTheFileAway() {
        val p = SaveDoc.begin(src.path) {}!!
        SaveDoc.take(p.code)
        val out = ByteArrayOutputStream()
        var dropped = 0
        val state = SaveDoc.copyInto(src, 0L, { out }, { null }, {
            assertEquals(SaveDoc.CHECKING, SaveDoc.cancel(drop = true))
            ByteArrayInputStream(out.toByteArray())
        }) { dropped++ }
        assertEquals(SaveDoc.FAILED, state)
        assertEquals(1, dropped)
        p.reply(state)
        // the next save starts clean
        val q = SaveDoc.begin(src.path) {}!!
        SaveDoc.take(q.code)
        val again = SaveDoc.copyInto(
            src, 0L, { ByteArrayOutputStream() }, { null }, { null },
        ) { dropped++ }
        assertEquals(SaveDoc.UNCHECKED, again)
        assertEquals(1, dropped)
        q.reply(again)
    }

    @Test
    fun aDocumentThatHeldSomethingIsNeverTakenAway() {
        val p = SaveDoc.begin(src.path) {}!!
        SaveDoc.take(p.code)
        val out = object : OutputStream() {
            override fun write(b: Int) {}
            override fun write(b: ByteArray, off: Int, len: Int) {
                SaveDoc.cancel(drop = true)
            }
        }
        var dropped = 0
        val state = SaveDoc.copyInto(src, 5000L, { out }, { null }, { null }) {
            dropped++
        }
        assertEquals(SaveDoc.FAILED, state)
        assertEquals(0, dropped)
        p.reply(state)
    }

    @Test
    fun aCancelAnswersADialogStillUp() {
        val got = mutableListOf<Map<String, Any?>>()
        val p = SaveDoc.begin(src.path) { got.add(it) }!!
        assertEquals(SaveDoc.PICKING, SaveDoc.cancel())
        assertEquals(listOf(SaveDoc.FAILED), got.map { it["state"] })
        // its late answer finds nobody
        assertNull(SaveDoc.take(p.code))
        assertEquals(SaveDoc.IDLE, SaveDoc.cancel())
    }

    @Test
    fun theAnswerReachesTheCallEvenFromAnotherScreen() {
        // begun by one screen, answered by the one android built after it
        val got = mutableListOf<Map<String, Any?>>()
        val p0 = SaveDoc.begin(src.path) { got.add(it) }!!
        assertEquals(SaveDoc.PICKING, SaveDoc.state()["stage"])
        val p = SaveDoc.take(p0.code)
        assertNotNull(p)
        assertEquals(src.path, p!!.path)
        assertEquals(SaveDoc.COPYING, SaveDoc.state()["stage"])
        p.reply(SaveDoc.SAVED, "Download")
        p.reply(SaveDoc.FAILED)
        assertEquals(listOf(mapOf("state" to SaveDoc.SAVED, "where" to "Download")), got)
        assertEquals(SaveDoc.IDLE, SaveDoc.state()["stage"])
        assertNull(SaveDoc.take(p0.code))
    }

    @Test
    fun anAnswerOnlyFitsItsOwnDialog() {
        val first = SaveDoc.begin(src.path) {}!!
        val second = SaveDoc.begin(src.path) {}!!
        assertTrue(first.code != second.code)
        assertTrue(SaveDoc.isCode(first.code) && SaveDoc.isCode(second.code))
        // the first dialog's late answer is not the second one's
        assertNull(SaveDoc.take(first.code))
        assertEquals(SaveDoc.PICKING, SaveDoc.state()["stage"])
        val p = SaveDoc.take(second.code)!!
        // and a second answer to the same dialog finds nothing
        assertNull(SaveDoc.take(second.code))
        p.reply(SaveDoc.CANCELLED)
    }

    @Test
    fun aDialogThatNeverAnsweredEndsWhenANewOneOpens() {
        val first = mutableListOf<Map<String, Any?>>()
        val second = mutableListOf<Map<String, Any?>>()
        SaveDoc.begin(src.path) { first.add(it) }
        val p = SaveDoc.begin(src.path) { second.add(it) }!!
        assertEquals(listOf(SaveDoc.FAILED), first.map { it["state"] })
        assertEquals(emptyList<Map<String, Any?>>(), second)
        SaveDoc.take(p.code)!!.reply(SaveDoc.CANCELLED)
        assertEquals(listOf(SaveDoc.CANCELLED), second.map { it["state"] })
    }

    @Test
    fun aNoBeforeTheDialogCoveredTheAppIsNotABackOut() {
        val p = SaveDoc.begin(src.path) {}!!
        // answered by android at once: the picker went to a task of its own
        assertEquals(SaveDoc.FAILED, SaveDoc.backedOut())
        SaveDoc.coveredNow()
        assertEquals(SaveDoc.CANCELLED, SaveDoc.backedOut())
        SaveDoc.take(p.code)!!.reply(SaveDoc.CANCELLED)
        SaveDoc.begin(src.path) {}
        assertEquals(SaveDoc.FAILED, SaveDoc.backedOut())
    }

    @Test
    fun noSecondDialogWhileACopyRuns() {
        val first = mutableListOf<Map<String, Any?>>()
        val p0 = SaveDoc.begin(src.path) { first.add(it) }!!
        val p = SaveDoc.take(p0.code)!!
        assertNull(SaveDoc.begin(src.path) {})
        p.reply(SaveDoc.SAVED)
        assertEquals(listOf(SaveDoc.SAVED), first.map { it["state"] })
    }

    @Test
    fun plainWriteOnlyOnADocumentThatHeldNothing() {
        val modes = mutableListOf<String>()
        val refuseWt: (String) -> OutputStream? = { mode ->
            modes.add(mode)
            if (mode == "wt") throw FileNotFoundException("no wt") else ByteArrayOutputStream()
        }
        assertNotNull(SaveDoc.openWith(0L, refuseWt))
        assertNotNull(SaveDoc.openWith(null, refuseWt))
        assertEquals(listOf("wt", "w", "wt", "w"), modes)
        modes.clear()
        // one the person chose to write over: no "w", that could leave its
        // old tail behind
        var threw = false
        try {
            SaveDoc.openWith(5000L, refuseWt)
        } catch (e: FileNotFoundException) {
            threw = true
        }
        assertTrue(threw)
        assertEquals(listOf("wt"), modes)
    }

    @Test
    fun onlyADocumentThatHeldNothingIsTakenAway() {
        assertTrue(SaveDoc.mayDrop(0L, opened = false))
        assertTrue(SaveDoc.mayDrop(0L, opened = true))
        // unknown before: ours to take only once we wrote into it
        assertTrue(SaveDoc.mayDrop(null, opened = true))
        assertFalse(SaveDoc.mayDrop(null, opened = false))
        assertFalse(SaveDoc.mayDrop(5000L, opened = true))
        assertFalse(SaveDoc.mayDrop(5000L, opened = false))
    }

    @Test
    fun theFolderItWentTo() {
        val ext = "com.android.externalstorage.documents"
        val dl = "com.android.providers.downloads.documents"
        assertEquals("Download/Kryfo", SaveDoc.placeOf(ext, "primary:Download/Kryfo/b.kryfo", null))
        assertEquals("Backups", SaveDoc.placeOf(ext, "1A2B-3C4D:Backups/b.kryfo", null))
        assertNull(SaveDoc.placeOf(ext, "primary:b.kryfo", null))
        // an msf id says nothing of the folder
        assertNull(SaveDoc.placeOf(dl, "msf:31", "Downloads"))
        assertEquals(
            "Download/keep",
            SaveDoc.placeOf(dl, "raw:/storage/emulated/0/Download/keep/b.kryfo", null),
        )
        assertEquals("Drive", SaveDoc.placeOf("com.google.android.apps.docs.storage", "x", "Drive"))
        assertNull(SaveDoc.placeOf("some.provider", "x", " "))
        assertNull(SaveDoc.placeOf(null, null, null))
    }

    // the dialog starts in the phone's own Download folder, the one a saved
    // file is then said to be in
    @Test
    fun theDialogStartsInDownload() {
        assertNull(SaveDoc.startIn(25))
        val uri = SaveDoc.startIn(34)!!
        val ext = "com.android.externalstorage.documents"
        assertEquals("content://$ext/document/primary%3ADownload", uri)
        val id = java.net.URLDecoder.decode(uri.substringAfterLast('/'), "UTF-8")
        assertEquals("primary:Download", id)
        assertEquals("Download", SaveDoc.placeOf(ext, "$id/kryfo-backup-1.kryfo", null))
    }
}
