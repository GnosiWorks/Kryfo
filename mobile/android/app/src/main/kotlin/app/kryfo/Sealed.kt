// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.media.MediaDataSource
import java.io.Closeable
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import javax.crypto.Cipher
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

// a photo, voice note or file sealed at rest (lib/desktop/sealed_format.dart),
// read at any place one chunk at a time with the file's own key, which dart
// hands over. nothing of it is written anywhere in the clear
class SealedReader(path: String, fileKey: ByteArray) : Closeable {
    companion object {
        const val HEAD = 24
        const val PLAIN = 1 shl 16
        private const val NONCE = 16
        private const val TAG = 16
        const val STORED = NONCE + PLAIN + TAG
        private val MAGIC = byteArrayOf(0x4b, 0x52, 0x59, 0x4d)

        // the plaintext length [stored] bytes hold, or -1
        fun plainLength(stored: Long): Long {
            val body = stored - HEAD
            if (body < NONCE + TAG) return -1
            val full = (body - 1) / STORED
            val last = body - full * STORED
            if (last < NONCE + TAG) return -1
            return full * PLAIN + last - NONCE - TAG
        }

        fun isSealed(head: ByteArray): Boolean =
            head.size >= HEAD && (0 until 4).all { head[it] == MAGIC[it] } && head[4] == 1.toByte()
    }

    private val raf = RandomAccessFile(path, "r")
    private val key = fileKey.copyOf()
    val size: Long
    private val last: Long
    private var index = -1L
    private var chunk = ByteArray(0)

    init {
        try {
            val head = ByteArray(HEAD)
            raf.readFully(head)
            if (!isSealed(head)) throw IOException("not sealed")
            size = plainLength(raf.length())
            if (size < 0) throw IOException("cut off")
            last = if (size == 0L) 0 else (size - 1) / PLAIN
        } catch (e: Exception) {
            close()
            throw e
        }
    }

    private fun chunkKey(nonce: ByteArray, i: Long, isLast: Boolean): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(key, "HmacSHA256"))
        mac.update(nonce)
        mac.update(ByteBuffer.allocate(8).putLong(i).array())
        mac.update((if (isLast) 1 else 0).toByte())
        return mac.doFinal()
    }

    private fun load(i: Long) {
        if (i == index) return
        val isLast = i == last
        val n = if (isLast) (size - i * PLAIN).toInt() else PLAIN
        val stored = ByteArray(NONCE + n + TAG)
        raf.seek(HEAD + i * STORED)
        raf.readFully(stored)
        val k = chunkKey(stored.copyOfRange(0, NONCE), i, isLast)
        try {
            val c = Cipher.getInstance("AES/GCM/NoPadding")
            c.init(Cipher.DECRYPT_MODE, SecretKeySpec(k, "AES"), GCMParameterSpec(128, ByteArray(12)))
            c.updateAAD(byteArrayOf(0x4d))
            val plain = try {
                c.doFinal(stored, NONCE, n + TAG)
            } catch (e: Exception) {
                throw IOException("chunk $i does not open")
            }
            chunk.fill(0)
            chunk = plain
            index = i
        } finally {
            k.fill(0)
        }
    }

    // up to [len] bytes at [pos] into [buf], -1 past the end
    @Synchronized
    fun readAt(pos: Long, buf: ByteArray, off: Int, len: Int): Int {
        if (pos >= size) return -1
        var at = pos
        var got = 0
        while (got < len && at < size) {
            val i = at / PLAIN
            load(i)
            val inChunk = (at - i * PLAIN).toInt()
            val n = minOf(len - got, chunk.size - inChunk)
            System.arraycopy(chunk, inChunk, buf, off + got, n)
            got += n
            at += n
        }
        return got
    }

    @Synchronized
    override fun close() {
        chunk.fill(0)
        key.fill(0)
        try { raf.close() } catch (_: Exception) {}
    }

    fun stream(): InputStream = object : InputStream() {
        private var at = 0L
        override fun read(): Int {
            val one = ByteArray(1)
            return if (read(one, 0, 1) < 0) -1 else one[0].toInt() and 0xFF
        }
        override fun read(b: ByteArray, off: Int, len: Int): Int {
            if (len == 0) return 0
            val n = readAt(at, b, off, len)
            if (n > 0) at += n
            return n
        }
        override fun skip(n: Long): Long {
            val k = minOf(n, size - at).coerceAtLeast(0)
            at += k
            return k
        }
        override fun available(): Int = minOf(size - at, Int.MAX_VALUE.toLong()).toInt()
        override fun close() = this@SealedReader.close()
    }

    // for android's own players and frame readers, which ask for any place
    fun media(): MediaDataSource = object : MediaDataSource() {
        override fun readAt(position: Long, buffer: ByteArray, offset: Int, size: Int): Int {
            if (size == 0) return 0
            return this@SealedReader.readAt(position, buffer, offset, size)
        }
        override fun getSize(): Long = this@SealedReader.size
        override fun close() = this@SealedReader.close()
    }
}

object Sealed {
    // [path]'s bytes as they are, or through its key when dart gave one
    fun open(path: String, key: ByteArray?): InputStream =
        if (key == null) File(path).inputStream() else SealedReader(path, key).stream()

    // its plaintext length
    fun length(path: String, key: ByteArray?): Long =
        if (key == null) File(path).length() else SealedReader.plainLength(File(path).length())
}
