// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.util.concurrent.atomic.AtomicBoolean

// the backup's save dialog and the copy after it. the call waiting for the
// answer is kept for the process, not the screen: android can rebuild the
// screen while the dialog is up and hand the answer to the new one
object SaveDoc {
    const val SAVED = "saved"
    const val CANCELLED = "cancelled"
    const val FAILED = "failed"

    const val IDLE = "idle"
    const val PICKING = "picking"
    const val COPYING = "copying"

    class Pending(val path: String, private val send: (Map<String, Any?>) -> Unit) {
        private val sent = AtomicBoolean(false)

        // exactly once, whichever way it ends
        fun reply(state: String, where: String? = null) {
            if (!sent.compareAndSet(false, true)) return
            if (current === this) {
                current = null
                stage = IDLE
            }
            send(mapOf("state" to state, "where" to where))
        }
    }

    @Volatile private var current: Pending? = null
    @Volatile var stage = IDLE
        private set
    @Volatile var copied = 0L
        private set
    // the dialog covered this app since it was asked for
    @Volatile private var covered = false

    // null while a copy still runs. one still waiting for its dialog never
    // got an answer, and is ended for the new one
    fun begin(path: String, send: (Map<String, Any?>) -> Unit): Pending? {
        if (stage == COPYING) return null
        current?.reply(FAILED)
        val p = Pending(path, send)
        current = p
        stage = PICKING
        copied = 0L
        covered = false
        return p
    }

    // this app's screen stopped while the dialog was up
    fun coveredNow() {
        if (stage == PICKING) covered = true
    }

    // a no from a dialog that never covered this app is not the person
    // backing out: a picker that opened in a task of its own is answered at
    // once by android, and what is picked there never comes back
    fun backedOut(): String = if (covered) CANCELLED else FAILED

    // the dialog answered: the waiting call, if this process still has one
    fun take(): Pending? {
        val p = current ?: return null
        stage = COPYING
        return p
    }

    fun state(): Map<String, Any?> = mapOf("stage" to stage, "copied" to copied)

    fun progress(n: Long) {
        copied = n
    }

    // saved only once every byte went out and the far side, where it can
    // tell, holds as many. a provider that takes the bytes and keeps none
    // must not read as saved
    fun copy(
        src: File,
        open: () -> OutputStream?,
        sizeThere: () -> Long?,
        readBack: () -> InputStream?,
        onCopied: (Long) -> Unit = {},
    ): String {
        return try {
            val want = src.length()
            if (want <= 0L) return FAILED
            val out = open() ?: return FAILED
            var n = 0L
            out.use { o ->
                src.inputStream().use { i ->
                    val buf = ByteArray(256 * 1024)
                    while (true) {
                        val r = i.read(buf)
                        if (r < 0) break
                        o.write(buf, 0, r)
                        n += r
                        onCopied(n)
                    }
                }
                o.flush()
            }
            if (n != want) return FAILED
            val there = try { sizeThere() } catch (e: Exception) { null }
            if (there == null || there == want) return SAVED
            // the size can lag on some providers: what reads back decides
            val back = try {
                readBack()?.use { count(it) }
            } catch (e: Exception) {
                null
            }
            when {
                back == want -> SAVED
                back == null && there == 0L -> SAVED
                else -> FAILED
            }
        } catch (e: Throwable) {
            FAILED
        }
    }

    private fun count(i: InputStream): Long {
        val buf = ByteArray(256 * 1024)
        var n = 0L
        while (true) {
            val r = i.read(buf)
            if (r < 0) return n
            n += r
        }
    }

    // where it went, as the person would find it: the folder for a phone or
    // card folder, else the app that holds it. null when nothing says
    fun placeOf(authority: String?, docId: String?, label: String?): String? {
        val shown = label?.trim()?.takeIf { it.isNotEmpty() }
        return when (authority) {
            "com.android.externalstorage.documents" -> {
                val rel = docId?.substringAfter(':', "")?.trim('/') ?: ""
                rel.substringBeforeLast('/', "").takeIf { it.isNotEmpty() }
            }
            "com.android.providers.downloads.documents" -> {
                val raw = docId?.takeIf { it.startsWith("raw:") }?.removePrefix("raw:")
                val folder = raw?.substringBeforeLast('/', "")
                    ?.removePrefix("/storage/emulated/0")?.trim('/')
                if (folder.isNullOrEmpty()) "Download" else folder
            }
            null -> null
            else -> shown
        }
    }
}
