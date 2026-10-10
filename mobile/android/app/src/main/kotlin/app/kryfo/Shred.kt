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
    val HANDED = listOf("open", "share", "share_plus")

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

    // the copies handed out from [cacheDir]; true while one is too young
    fun handed(cacheDir: File, now: Long = System.currentTimeMillis()): Boolean {
        var young = false
        for (name in HANDED) {
            if (aged(File(cacheDir, name), now - GRACE_MS, now)) young = true
        }
        return young
    }
}
