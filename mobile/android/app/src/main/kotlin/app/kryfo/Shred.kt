// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import java.io.File
import java.io.RandomAccessFile

// a copy that held plaintext is zeroed before it is unlinked, as shredFile
// does on the dart side. best effort: flash wear levelling can keep an old
// block, but the easy read is gone.
object Shred {
    // a copy handed to another app to open or share: that app may read it
    // only once this one is back, so it is given this long first
    const val GRACE_MS = 10 * 60 * 1000L
    val HANDED = listOf("open", "share_plus")

    fun file(f: File) {
        try {
            if (f.isFile) {
                RandomAccessFile(f, "rw").use { raf ->
                    val zeros = ByteArray(64 * 1024)
                    var left = raf.length()
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
        }
        f.delete()
    }

    fun tree(f: File) {
        if (!f.exists()) return
        for (e in f.walkBottomUp()) {
            if (e.isFile) file(e) else e.delete()
        }
    }

    // every file under [dir] last written before [cutoff] goes, and every
    // folder left empty. true while a younger one stays
    fun aged(dir: File, cutoff: Long): Boolean {
        if (!dir.exists()) return false
        var young = false
        for (f in dir.walkBottomUp()) {
            if (f.isFile) {
                if (f.lastModified() < cutoff) {
                    file(f)
                } else {
                    young = true
                }
            } else if (f != dir) {
                // only an emptied folder goes
                f.delete()
            }
        }
        return young
    }

    // the copies handed out from [cacheDir]; true while one is too young
    fun handed(cacheDir: File, now: Long = System.currentTimeMillis()): Boolean {
        var young = false
        for (name in HANDED) {
            if (aged(File(cacheDir, name), now - GRACE_MS)) young = true
        }
        return young
    }
}
