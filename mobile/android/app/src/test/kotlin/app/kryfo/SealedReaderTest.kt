// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test

// sealed_two_chunks.bin was sealed by a separate go program from the format
// in lib/desktop/sealed_format.dart: area key 0..31, two chunks, 65546
// bytes of (i * 31 + 7) & 255. dart opens the same file in its own test
class SealedReaderTest {
    private lateinit var file: File
    private val plain = ByteArray(65546) { (it * 31 + 7).toByte() }

    private fun fileKey(bytes: ByteArray): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(ByteArray(32) { it.toByte() }, "HmacSHA256"))
        mac.update(bytes, 8, 16)
        return mac.doFinal()
    }

    @Before
    fun made() {
        file = File.createTempFile("sealed", ".bin")
        javaClass.classLoader!!.getResourceAsStream("sealed_two_chunks.bin").use { i ->
            file.outputStream().use { o -> i!!.copyTo(o) }
        }
    }

    @After
    fun gone() {
        file.delete()
    }

    @Test
    fun opensWhatTheFormatSealed() {
        val key = fileKey(file.readBytes())
        SealedReader(file.path, key).use { r ->
            assertEquals(65546L, r.size)
            val all = ByteArray(65546)
            assertEquals(65546, r.readAt(0, all, 0, all.size))
            assertArrayEquals(plain, all)
            // across the edge of the chunks, and past the end
            val mid = ByteArray(20)
            assertEquals(20, r.readAt(65530, mid, 0, 20))
            assertArrayEquals(plain.copyOfRange(65530, 65550), mid)
            assertEquals(-1, r.readAt(65546, mid, 0, 20))
        }
        assertEquals(65546L, Sealed.length(file.path, key))
        val out = ByteArrayOutputStream()
        Sealed.open(file.path, key).use { it.copyTo(out, 1000) }
        assertArrayEquals(plain, out.toByteArray())
    }

    @Test
    fun aStreamSkipsAndReads() {
        val s = SealedReader(file.path, fileKey(file.readBytes())).stream()
        s.use {
            assertEquals(65000L, it.skip(65000))
            val b = ByteArray(100)
            var got = 0
            while (got < 100) got += it.read(b, got, 100 - got)
            assertArrayEquals(plain.copyOfRange(65000, 65100), b)
        }
    }

    @Test
    fun aChangedByteNeverReads() {
        val b = file.readBytes()
        val key = fileKey(b)
        b[24 + SealedReader.STORED + 40] = (b[24 + SealedReader.STORED + 40] + 1).toByte()
        file.writeBytes(b)
        SealedReader(file.path, key).use { r ->
            val first = ByteArray(100)
            // the first chunk still reads, the changed one does not
            assertEquals(100, r.readAt(0, first, 0, 100))
            try {
                r.readAt(65536, first, 0, 10)
                fail("a changed chunk opened")
            } catch (e: IOException) {
                assertTrue(e.message!!.contains("does not open"))
            }
        }
    }

    @Test
    fun aFileCutAtAChunkEdgeNeverReads() {
        val b = file.readBytes()
        val key = fileKey(b)
        file.writeBytes(b.copyOfRange(0, 24 + SealedReader.STORED))
        SealedReader(file.path, key).use { r ->
            // its first chunk was not sealed as the last
            try {
                r.readAt(0, ByteArray(10), 0, 10)
                fail("a cut file opened")
            } catch (e: IOException) {
            }
        }
    }

    @Test
    fun aWrongKeyOrAPlainFileNeverReads() {
        SealedReader(file.path, ByteArray(32)).use { r ->
            try {
                r.readAt(0, ByteArray(10), 0, 10)
                fail("a wrong key opened")
            } catch (e: IOException) {
            }
        }
        val plainFile = File.createTempFile("plain", ".jpg")
        try {
            plainFile.writeBytes(ByteArray(5000) { 1 })
            try {
                SealedReader(plainFile.path, ByteArray(32)).close()
                fail("a plain file read as sealed")
            } catch (e: IOException) {
            }
            // without a key a file is read as it is
            assertEquals(5000L, Sealed.length(plainFile.path, null))
        } finally {
            plainFile.delete()
        }
    }
}
