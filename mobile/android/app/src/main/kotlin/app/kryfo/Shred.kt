// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.system.Os
import android.system.OsConstants
import java.io.File
import java.io.RandomAccessFile

// a copy that held plaintext is zeroed before it is unlinked, as shredFile
// does on the dart side. best effort: flash wear levelling can keep an old
// block, but the easy read is gone.
object Shred {
    // a copy handed to another app to open or share: that app may read it
    // only once this one is back, so it is given this long first
    const val GRACE_MS = 10 * 60 * 1000L
    // a time this far ahead is a clock that moved, not a young copy
    const val SKEW_MS = 60 * 1000L
    val HANDED = listOf("open", "share", "share_plus", SHARE_QUIET)

    // what a hidden chat or the decoy shares: dart drops it at the next lock
    const val SHARE_QUIET = "share_q"

    // the folder a shared copy goes into
    fun shareInto(backup: Boolean, quiet: Boolean): String = when {
        backup -> BACKUP_OUT
        quiet -> SHARE_QUIET
        else -> "share"
    }

    // the name a handed copy is given: the person's own, in whatever
    // letters, so the app it goes to shows it. no folder in it, nothing
    // hidden, at most LEAF_BYTES of utf-8 with the end kept for the
    // extension, and never one of dots alone, which names the folder or
    // the one above
    const val LEAF_BYTES = 200

    fun leaf(name: String): String {
        val sb = StringBuilder()
        var i = 0
        while (i < name.length) {
            val cp = name.codePointAt(i)
            i += Character.charCount(cp)
            val type = Character.getType(cp)
            when {
                cp == 0x200C || cp == 0x200D -> sb.appendCodePoint(cp)
                type == Character.FORMAT.toInt() -> {}
                type == Character.CONTROL.toInt() ||
                    type == Character.SURROGATE.toInt() ||
                    cp < 0x80 && "/\\:*?\"<>|".indexOf(cp.toChar()) >= 0 -> sb.append('_')
                else -> sb.appendCodePoint(cp)
            }
        }
        var safe = sb.toString()
        while (safe.toByteArray(Charsets.UTF_8).size > LEAF_BYTES) {
            safe = safe.substring(safe.offsetByCodePoints(0, 1))
        }
        return if (safe.all { it == '.' || it == ' ' }) "file" else safe
    }

    fun isLink(f: File): Boolean = try {
        OsConstants.S_ISLNK(Os.lstat(f.path).st_mode)
    } catch (e: Exception) {
        false
    }

    // "rw" keeps the length and the blocks: the zeros go where the bytes
    // are. the name goes whatever the write did
    fun file(f: File) {
        try {
            if (!isLink(f) && f.isFile) {
                RandomAccessFile(f, "rw").use { raf ->
                    val zeros = ByteArray(64 * 1024)
                    val len = raf.length()
                    var left = len
                    while (left > 0) {
                        val n = minOf(left, zeros.size.toLong()).toInt()
                        raf.write(zeros, 0, n)
                        left -= n
                    }
                    raf.fd.sync()
                }
            }
        } catch (e: Exception) {
            // unlinked all the same
        } finally {
            f.delete()
        }
    }

    // children before their folder. a link is never followed, only listed
    private fun bottomUp(top: File): List<File> {
        val out = ArrayList<File>()
        fun go(f: File) {
            if (!isLink(f) && f.isDirectory) f.listFiles()?.forEach { go(it) }
            out.add(f)
        }
        go(top)
        return out
    }

    fun tree(top: File) {
        if (!top.exists() && !isLink(top)) return
        for (e in bottomUp(top)) {
            if (!isLink(e) && e.isDirectory) e.delete() else file(e)
        }
    }

    // written before [cutoff], or so far ahead of [now] the clock moved
    fun old(at: Long, cutoff: Long, now: Long): Boolean = at < cutoff || at > now + SKEW_MS

    // every old file under [dir] goes, and every emptied folder that was old
    // itself before its files went: one another call just made for its copy
    // stays. true while something younger stays
    fun aged(dir: File, cutoff: Long, now: Long = System.currentTimeMillis()): Boolean {
        if (!dir.exists()) return false
        val all = bottomUp(dir)
        // a folder's time moves as its files go, so it is read first
        val made = all.associateWith { it.lastModified() }
        var young = false
        for (f in all) {
            if (f == dir) continue
            val at = made[f] ?: 0L
            if (isLink(f) || !f.isDirectory) {
                if (isLink(f) || old(at, cutoff, now)) file(f) else young = true
            } else if (old(at, cutoff, now)) {
                // only an emptied folder goes
                if (!f.delete() && f.exists()) young = true
            } else {
                young = true
            }
        }
        return young
    }

    // a backup handed out is ciphertext: it is kept until the next one goes
    // out or a day has passed, and a plain delete does
    const val BACKUP_OUT = "backup_out"
    const val BACKUP_KEEP_MS = 24 * 60 * 60 * 1000L

    fun dropBackups(cacheDir: File, all: Boolean, now: Long = System.currentTimeMillis()) {
        val kids = File(cacheDir, BACKUP_OUT).listFiles() ?: return
        for (f in kids) {
            if (all || old(f.lastModified(), now - BACKUP_KEEP_MS, now)) {
                for (e in bottomUp(f)) e.delete()
            }
        }
    }

    // the copies handed out from [cacheDir]; true while one is too young
    fun handed(cacheDir: File, now: Long = System.currentTimeMillis()): Boolean {
        var young = false
        for (name in HANDED) {
            if (aged(File(cacheDir, name), now - GRACE_MS, now)) young = true
        }
        return young
    }
}
