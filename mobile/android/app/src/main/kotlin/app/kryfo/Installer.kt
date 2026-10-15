// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import java.io.File
import java.io.RandomAccessFile
import java.text.Normalizer
import java.util.zip.ZipFile

// an app installer is never handed to another app, to view or to share: the
// package installer answers a view of one. kryfo only saves it where the
// person picks. told by its name, by the type it would go out as, and by
// what its zip directory holds, wherever that directory is found: a renamed
// one, one behind other bytes, and one carried inside an archive count
object Installer {
    const val MIME = "application/vnd.android.package-archive"
    const val MAX_ENTRIES = 100_000
    private val EXTS = setOf("apk", "apks", "apkm", "xapk", "aab")
    private val INNER = listOf(".apk", ".apks", ".xapk", ".apkm", ".aab")
    private val FILLERS = setOf(0x034F, 0x115F, 0x1160, 0x2800, 0x3164, 0xFFA0)

    private fun hidden(cp: Int): Boolean {
        val t = Character.getType(cp)
        return t == Character.FORMAT.toInt() || t == Character.CONTROL.toInt() ||
            t == Character.LINE_SEPARATOR.toInt() ||
            t == Character.PARAGRAPH_SEPARATOR.toInt() ||
            cp in FILLERS || cp in 0xFE00..0xFE0F || cp in 0xE0100..0xE01EF
    }

    private fun mark(cp: Int): Boolean {
        val t = Character.getType(cp)
        return t == Character.NON_SPACING_MARK.toInt() || t == Character.ENCLOSING_MARK.toInt()
    }

    private fun keep(s: String, drop: (Int) -> Boolean): String {
        val sb = StringBuilder()
        var i = 0
        while (i < s.length) {
            val cp = s.codePointAt(i)
            if (!drop(cp)) sb.appendCodePoint(cp)
            i += Character.charCount(cp)
        }
        return sb.toString()
    }

    // the extension of the name as it is saved: nothing hidden, composed,
    // no trailing dot or space, no mark on it
    fun extOf(name: String): String {
        val shown = keep(Normalizer.normalize(name, Normalizer.Form.NFC), ::hidden)
            .trimEnd { it == '.' || it.isWhitespace() }
        return keep(shown.substringAfterLast('.', ""), ::mark).lowercase()
    }

    fun named(name: String?): Boolean = name != null && extOf(name) in EXTS

    fun holds(names: Collection<String>): Boolean = names.any { n ->
        val l = n.lowercase()
        n == "AndroidManifest.xml" || INNER.any { l.endsWith(it) }
    }

    // where a zip's end record starts: the signature, with a comment that
    // runs exactly to the end of the file. [loose] takes one with bytes after
    // its comment too, which java's zip reader accepts
    fun endRecord(f: File, loose: Boolean = false): Long? {
        val len = f.length()
        val n = minOf(len, 22L + 0xFFFF).toInt()
        if (n < 22) return null
        val tail = ByteArray(n)
        RandomAccessFile(f, "r").use {
            it.seek(len - n)
            it.readFully(tail)
        }
        for (i in n - 22 downTo 0) {
            if (tail[i] != 0x50.toByte() || tail[i + 1] != 0x4B.toByte() ||
                tail[i + 2] != 5.toByte() || tail[i + 3] != 6.toByte()
            ) continue
            val comment = (tail[i + 20].toInt() and 0xFF) or
                ((tail[i + 21].toInt() and 0xFF) shl 8)
            val stop = len - n + i + 22 + comment
            if (stop == len || loose && stop < len) return len - n + i
        }
        return null
    }

    // a zip with no end record still names its first entry up front
    private fun firstEntry(f: File): String? {
        val head = ByteArray(30 + 0xFFFF)
        var got = 0
        f.inputStream().use { s ->
            while (got < head.size) {
                val r = s.read(head, got, head.size - got)
                if (r < 0) break
                got += r
            }
        }
        if (got < 30 || head[0] != 0x50.toByte() || head[1] != 0x4B.toByte() ||
            head[2] != 3.toByte() || head[3] != 4.toByte()
        ) return null
        val n = (head[26].toInt() and 0xFF) or ((head[27].toInt() and 0xFF) shl 8)
        if (30 + n > got) return null
        return String(head, 30, n, Charsets.UTF_8)
    }

    // a directory that is there and cannot be read through counts as one:
    // nothing vouches for it
    fun inside(f: File): Boolean {
        val end = try {
            endRecord(f)
        } catch (e: Exception) {
            return false
        }
        if (end == null) {
            val first = try {
                firstEntry(f)
            } catch (e: Exception) {
                null
            }
            if (first != null && holds(listOf(first))) return true
            // a loose record is only looked into: bytes that merely look like
            // one say nothing
            val loose = try {
                endRecord(f, loose = true)
            } catch (e: Exception) {
                null
            }
            if (loose == null) return false
            return try {
                ZipFile(f).use { z ->
                    z.size() > MAX_ENTRIES ||
                        holds(z.entries().asSequence().map { it.name }.toList())
                }
            } catch (e: Exception) {
                false
            }
        }
        return try {
            ZipFile(f).use { z ->
                z.size() > MAX_ENTRIES ||
                    holds(z.entries().asSequence().map { it.name }.toList())
            }
        } catch (e: Exception) {
            true
        }
    }

    fun refused(f: File, name: String?, mime: String?): Boolean =
        MIME.equals(mime, ignoreCase = true) || named(name) || named(f.name) || inside(f)
}
