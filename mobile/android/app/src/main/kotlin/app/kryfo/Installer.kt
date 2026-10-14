// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import java.io.File
import java.util.zip.ZipFile

// an app installer is never handed to another app, to view or to share: the
// package installer answers a view of one. kryfo only saves it where the
// person picks. told by its name, by the type it would go out as, and by
// the manifest inside its zip, so a renamed one is caught too
object Installer {
    const val MIME = "application/vnd.android.package-archive"
    private val EXTS = setOf("apk", "apks", "apkm", "xapk")

    fun named(name: String?): Boolean =
        name != null && name.substringAfterLast('.', "").lowercase() in EXTS

    fun holds(names: Collection<String>): Boolean {
        if ("AndroidManifest.xml" in names) return true
        val apks = names.filter { it.lowercase().endsWith(".apk") }
        if (apks.isEmpty()) return false
        return "base.apk" in names || "toc.pb" in names ||
            "manifest.json" in names || "info.json" in names ||
            apks.any { it.startsWith("splits/") }
    }

    // a zip that cannot be read through counts as one: nothing vouches for it
    fun inside(f: File): Boolean {
        val head = ByteArray(4)
        val n = try {
            f.inputStream().use { it.read(head) }
        } catch (e: Exception) {
            return false
        }
        if (n < 4 || head[0] != 0x50.toByte() || head[1] != 0x4B.toByte()) return false
        val zip = (head[2] == 3.toByte() && head[3] == 4.toByte()) ||
            (head[2] == 5.toByte() && head[3] == 6.toByte())
        if (!zip) return false
        return try {
            ZipFile(f).use { z -> holds(z.entries().asSequence().map { it.name }.toList()) }
        } catch (e: Exception) {
            true
        }
    }

    fun refused(f: File, name: String?, mime: String?): Boolean =
        MIME.equals(mime, ignoreCase = true) || named(name) || named(f.name) || inside(f)
}
