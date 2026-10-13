// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import java.io.File
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicBoolean

// the backup's save dialog and the copy after it. the call waiting for the
// answer is kept for the process, not the screen: android can rebuild the
// screen while the dialog is up and hand the answer to the new one
object SaveDoc {
    const val SAVED = "saved"
    // every byte went out, but the place would not let it be read back
    const val UNCHECKED = "unchecked"
    const val CANCELLED = "cancelled"
    const val FAILED = "failed"

    const val IDLE = "idle"
    const val PICKING = "picking"
    const val COPYING = "copying"
    const val CHECKING = "checking"

    // each dialog asks with a code of its own, so an answer is only ever
    // matched to the dialog it belongs to
    const val FIRST_CODE = 7400
    private const val CODES = 100

    class Pending(
        val path: String,
        val code: Int,
        private val send: (Map<String, Any?>) -> Unit,
    ) {
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
    // bytes written, then bytes read back: a count that moves while it works
    @Volatile var moved = 0L
        private set
    // the dialog covered this app since it was asked for
    @Volatile private var covered = false
    // dart gave up on the copy: it stops at the next block
    @Volatile private var aborted = false
    private var seq = 0

    fun isCode(code: Int) = code >= FIRST_CODE && code < FIRST_CODE + CODES

    fun busy() = stage == COPYING || stage == CHECKING

    // null while a copy still runs. one still waiting for its dialog never
    // got an answer, and is ended for the new one
    fun begin(path: String, send: (Map<String, Any?>) -> Unit): Pending? {
        if (busy()) return null
        current?.reply(FAILED)
        seq = (seq + 1) % CODES
        val p = Pending(path, FIRST_CODE + seq, send)
        current = p
        stage = PICKING
        moved = 0L
        covered = false
        aborted = false
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

    // the dialog answered: its waiting call, only while that one dialog is up
    fun take(code: Int): Pending? {
        val p = current ?: return null
        if (stage != PICKING || p.code != code) return null
        stage = COPYING
        return p
    }

    fun state(): Map<String, Any?> = mapOf("stage" to stage, "copied" to moved)

    // dart stopped waiting. a dialog still up is answered now; a copy stops
    // at its next block and answers itself. what was running, if anything
    fun cancel(): String {
        val was = stage
        when (was) {
            PICKING -> current?.reply(FAILED)
            COPYING, CHECKING -> aborted = true
        }
        return was
    }

    fun progress(n: Long) {
        moved = n
    }

    private fun checking() {
        if (stage == COPYING) stage = CHECKING
        moved = 0L
    }

    // "wt" first. plain "w" only on a document that held nothing: on one the
    // person chose to write over, it could leave old bytes at the end
    fun openWith(before: Long?, open: (String) -> OutputStream?): OutputStream? = try {
        open("wt")
    } catch (e: Exception) {
        if (before == null || before == 0L) open("w") else throw e
    }

    // a document is only taken away when it held nothing before we wrote
    fun mayDrop(before: Long?) = before == 0L

    // saved only once every byte went out and reads back the same, byte for
    // byte. a provider that takes the bytes and keeps fewer, or other ones,
    // is not saved; one that will not be read back is unchecked
    fun copy(
        src: File,
        open: () -> OutputStream?,
        sizeThere: () -> Long?,
        readBack: () -> InputStream?,
        onCopied: (Long) -> Unit = SaveDoc::progress,
        stop: () -> Boolean = { aborted },
        onChecking: () -> Unit = SaveDoc::checking,
    ): String {
        return try {
            val want = src.length()
            if (want <= 0L) return FAILED
            val out = open() ?: return FAILED
            val wrote = MessageDigest.getInstance("SHA-256")
            var n = 0L
            out.use { o ->
                src.inputStream().use { i ->
                    val buf = ByteArray(256 * 1024)
                    while (true) {
                        if (stop()) throw IOException("stopped")
                        val r = i.read(buf)
                        if (r < 0) break
                        o.write(buf, 0, r)
                        wrote.update(buf, 0, r)
                        n += r
                        onCopied(n)
                    }
                }
                o.flush()
            }
            if (n != want) return FAILED
            val there = try { sizeThere() } catch (e: Exception) { null }
            onChecking()
            val back = try {
                readBack()?.use { digestOf(it, stop, onCopied) }
            } catch (e: Exception) {
                if (stop()) return FAILED
                null
            }
            when {
                back != null ->
                    if (back.first == want && back.second.contentEquals(wrote.digest())) SAVED
                    else FAILED
                there != null && there != want -> FAILED
                else -> UNCHECKED
            }
        } catch (e: Throwable) {
            FAILED
        }
    }

    private fun digestOf(
        i: InputStream,
        stop: () -> Boolean,
        onRead: (Long) -> Unit,
    ): Pair<Long, ByteArray> {
        val d = MessageDigest.getInstance("SHA-256")
        val buf = ByteArray(256 * 1024)
        var n = 0L
        while (true) {
            if (stop()) throw IOException("stopped")
            val r = i.read(buf)
            if (r < 0) return n to d.digest()
            d.update(buf, 0, r)
            n += r
            onRead(n)
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
                // only a raw path says the folder; an msf id can sit anywhere
                val raw = docId?.takeIf { it.startsWith("raw:") }?.removePrefix("raw:")
                raw?.substringBeforeLast('/', "")
                    ?.removePrefix("/storage/emulated/0")?.trim('/')
                    ?.takeIf { it.isNotEmpty() }
            }
            null -> null
            else -> shown
        }
    }
}
