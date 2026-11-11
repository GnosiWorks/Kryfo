// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.os.StatFs
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.SecureRandom
import java.util.concurrent.atomic.AtomicBoolean

class ToolsBridge(private val activity: Activity) {
    companion object {
        const val CHANNEL = "halo/tools"
        const val REQ_PICK = 7321
        const val REQ_DELETE = 7322
        const val REQ_SAVE_AS = 7323
        const val REQ_CREATE = 7324
        const val IN_DIR = "tools_in"
        const val OUT_DIR = "tools_out"
        private const val MAX_AGE_MS = 15 * 60 * 1000L
        // dart cuts the words to a message's size. this only bounds what
        // crosses over
        const val TEXT_MOST = 2 * 4096

        // words shared from another app: in this process's memory only, so
        // a screen rebuilt keeps them and a process that went takes them
        // along. never in a saved state
        @Volatile
        private var sharedText: SharedWords? = null

        // photos, videos and files shared from another app: their uris
        // alone, in memory, until dart takes a way for them. nothing is
        // read or copied before that
        @Volatile
        private var sharedFiles: SharedFiles? = null

        // the most one share hands over, as the send preview holds
        const val FILES_MOST = 30
        // how long the providers of one share are given to name their files
        const val DESCRIBE_MS = 4000L

        // a type a chat or the photo checker takes. text has its own path
        fun isFileType(type: String): Boolean {
            val t = type.substringBefore(';').trim().lowercase()
            return t.startsWith("image/") || t.startsWith("video/") ||
                t.startsWith("application/") || t.startsWith("audio/") ||
                t.startsWith("text/") || t == "*/*"
        }

        // a concrete type, never a wildcard a mixed share carries
        fun concrete(type: String?): String? =
            type?.takeIf { !it.contains('*') }

        // [s] cut to [most] chars, never between the halves of a pair
        fun cut(s: String?, most: Int): String? {
            if (s == null || s.length <= most) return s
            var end = most
            if (Character.isHighSurrogate(s[end - 1])) end--
            return s.substring(0, end)
        }

        fun isText(type: String) =
            type.substringBefore(';').trim().lowercase() == "text/plain"

        // one of our own providers, also with the user id a content uri may
        // carry before its authority ("0@app.kryfo.open")
        fun ours(authority: String, pkg: String): Boolean {
            val host = authority.substringAfterLast('@').lowercase()
            val own = pkg.lowercase()
            return host == own || host.startsWith("$own.")
        }

        // [all] at start: no copy in is being read then. a result may have
        // been shared with another app that still reads it, so it waits out
        // its age either way
        fun sweep(cacheDir: File, all: Boolean) {
            val now = System.currentTimeMillis()
            for (name in listOf(IN_DIR, OUT_DIR)) {
                val dir = File(cacheDir, name)
                val kids = dir.listFiles() ?: continue
                for (f in kids) {
                    val old = Shred.old(f.lastModified(), now - MAX_AGE_MS, now)
                    if (old || (all && name == IN_DIR)) Shred.tree(f)
                }
            }
        }
    }

    private var channel: MethodChannel? = null
    private var pendingPick: MethodChannel.Result? = null
    private var pendingDelete: MethodChannel.Result? = null
    private var pendingSaveAs: MethodChannel.Result? = null
    private var pendingSaveAsPath: String? = null
    private var pendingCreate: MethodChannel.Result? = null
    private val created = HashSet<String>()
    private val cancel = AtomicBoolean(false)
    // the stream a copy in reads: closed by a cancel, so a provider that
    // hangs in a read lets go
    @Volatile
    private var reading: java.io.InputStream? = null

    fun attach(ch: MethodChannel) {
        channel = ch
        ch.setMethodCallHandler { call, result -> handle(call, result) }
        // words this process holds for a screen made again over it
        if (sharedText != null) ch.invokeMethod("sharedText", null)
        if (sharedFiles != null) ch.invokeMethod("sharedFiles", null)
    }

    fun offer(intent: Intent?) {
        val action = intent?.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return
        val type = intent.type ?: return
        if (action == Intent.ACTION_SEND && isText(type)) {
            offerText(intent)
            return
        }
        if (!isFileType(type)) return
        offerFiles(intent, type)
    }

    // a newer share takes the place of one not used yet. only what kryfo
    // may read is kept, never one of its own files
    private fun offerFiles(intent: Intent, type: String) {
        val uris = try {
            streams(intent).filter { acceptable(it) }.distinct().take(FILES_MOST)
        } catch (e: Exception) {
            return
        }
        if (uris.isEmpty()) return
        sharedFiles = SharedFiles(newId(), uris.map { Pair(it, concrete(type)) }, chat = picked(intent))
        activity.runOnUiThread { channel?.invokeMethod("sharedFiles", null) }
    }

    private fun streams(intent: Intent): List<Uri> {
        val out = ArrayList<Uri>()
        if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            // below 13 the list is not checked: anything else in it is dropped
            val list: List<Any?>? = if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra<android.os.Parcelable>(Intent.EXTRA_STREAM)
            }
            list?.let { out.addAll(it.filterIsInstance<Uri>()) }
        } else {
            val one: Any? = if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra<android.os.Parcelable>(Intent.EXTRA_STREAM)
            }
            (one as? Uri)?.let { out.add(it) }
        }
        // some apps put them only in the clip the grant rides on
        if (out.isEmpty()) {
            val clip = intent.clipData
            if (clip != null) {
                for (i in 0 until clip.itemCount) clip.getItemAt(i).uri?.let { out.add(it) }
            }
        }
        return out
    }

    private fun newId(): String = ByteArray(8).also { SecureRandom().nextBytes(it) }
        .joinToString("") { "%02x".format(it) }

    // a newer share takes the place of one not used yet. words come from
    // the extras alone; a text file is a file
    private fun offerText(intent: Intent) {
        val (text, subject) = try {
            Pair(
                intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString(),
                intent.getCharSequenceExtra(Intent.EXTRA_SUBJECT)?.toString()
            )
        } catch (e: Exception) {
            return
        }
        if (!text.isNullOrBlank() || !subject.isNullOrBlank()) {
            keepText(text, subject, picked(intent))
            return
        }
        // a text file sent alone goes as a file, to a chat picked for it
        offerFiles(intent, "text/plain")
    }

    // the chat picked in the share menu (ShareTargets.kt), if one was: dart
    // checks it is still one it may go to
    private fun picked(intent: Intent): String? = try {
        intent.getStringExtra(Intent.EXTRA_SHORTCUT_ID)?.takeIf { it.length in 1..64 }
    } catch (e: Exception) {
        null
    }

    private fun keepText(text: String?, subject: String?, chat: String? = null) {
        val id = newId()
        sharedText = SharedWords(id, cut(text, TEXT_MOST), cut(subject, TEXT_MOST), chat = chat)
        activity.runOnUiThread { channel?.invokeMethod("sharedText", null) }
    }

    private fun acceptable(uri: Uri): Boolean {
        if (uri.scheme != "content") return false
        val auth = uri.authority ?: return false
        return !ours(auth, activity.packageName)
    }

    private fun isMediaStore(uri: Uri) =
        uri.authority == MediaStore.AUTHORITY && uri.pathSegments.firstOrNull() != "picker"

    private fun deletable(uri: Uri): Uri? {
        if (Build.VERSION.SDK_INT < 29) return null
        if (isMediaStore(uri)) return uri
        if (uri.authority != "com.android.providers.media.documents") return null
        return try {
            MediaStore.getMediaUri(activity, uri)?.takeIf { isMediaStore(it) }
        } catch (e: Exception) {
            null
        }
    }

    private fun describe(uri: Uri, mime: String?): Map<String, Any?> {
        var name: String? = null
        var size = -1L
        try {
            activity.contentResolver.query(uri, null, null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val n = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val s = c.getColumnIndex(OpenableColumns.SIZE)
                    if (n >= 0) name = c.getString(n)
                    if (s >= 0 && !c.isNull(s)) size = c.getLong(s)
                }
            }
        } catch (e: Exception) {
        }
        return mapOf(
            "uri" to uri.toString(),
            "mime" to (mime ?: activity.contentResolver.getType(uri)),
            "name" to name,
            "size" to size,
            "deleteUri" to deletable(uri)?.toString()
        )
    }

    private fun safeName(name: String?): String {
        val n = (name ?: "file").replace(Regex("[\\\\/:*?\"<>|\\x00-\\x1F]"), "_").trim('.', ' ')
        return if (n.isEmpty()) "file" else n.takeLast(120)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "takeSharedFiles" -> {
                val f = sharedFiles
                if (f == null) {
                    result.success(null)
                } else {
                    // a provider can be slow to answer: off the ui thread
                    Thread {
                        // a provider that does not answer leaves the item
                        // unnamed and of no known size, never the share stuck
                        val ex = java.util.concurrent.Executors.newSingleThreadExecutor()
                        val until = System.currentTimeMillis() + DESCRIBE_MS
                        val items = f.items.map { (u, m) ->
                            val left = until - System.currentTimeMillis()
                            val d = try {
                                if (left <= 0) throw java.util.concurrent.TimeoutException()
                                ex.submit<Map<String, Any?>> { describe(u, null) }
                                    .get(left, java.util.concurrent.TimeUnit.MILLISECONDS)
                            } catch (e: Exception) {
                                mapOf("uri" to u.toString(), "mime" to null, "name" to null, "size" to -1L)
                            }
                            if (d["mime"] == null) d + ("mime" to m) else d
                        }
                        ex.shutdownNow()
                        val out = mapOf("id" to f.id, "seen" to f.seen, "items" to items, "chat" to f.chat)
                        activity.runOnUiThread { result.success(out) }
                    }.start()
                }
            }
            "seenSharedFiles" -> {
                val f = sharedFiles
                if (f != null && f.id == call.argument<String>("id")) {
                    sharedFiles = f.copy(seen = call.argument<String>("where"))
                }
                result.success(true)
            }
            "dropSharedFiles" -> {
                if (sharedFiles?.id == call.argument<String>("id")) sharedFiles = null
                result.success(true)
            }
            "takeSharedText" -> result.success(sharedText?.let {
                mapOf("id" to it.id, "text" to it.text, "subject" to it.subject, "seen" to it.seen, "chat" to it.chat)
            })
            "seenSharedText" -> {
                val w = sharedText
                if (w != null && w.id == call.argument<String>("id")) {
                    sharedText = w.copy(seen = call.argument<String>("where"))
                }
                result.success(true)
            }
            "dropSharedText" -> {
                if (sharedText?.id == call.argument<String>("id")) sharedText = null
                result.success(true)
            }
            "pick" -> pick(call.argument<String>("kind") ?: "image", result)
            "copyIn" -> copyIn(
                call.argument<String>("uri"),
                call.argument<Number>("most")?.toLong(),
                result
            )
            "cancelCopy" -> {
                cancel.set(true)
                val r = reading
                if (r != null) Thread { try { r.close() } catch (e: Exception) {} }.start()
                result.success(true)
            }
            "freeBytes" -> result.success(free())
            "shareOut" -> shareOut(call.argument<String>("path"), call.argument<String>("mime"), result)
            "saveToGallery" -> saveToGallery(
                call.argument<String>("path"),
                call.argument<String>("name"),
                call.argument<String>("mime"),
                result
            )
            "deleteOriginal" -> deleteOriginal(call.argument<String>("uri"), result)
            "saveToFiles" -> saveAs(
                call.argument<String>("path"),
                call.argument<String>("name"),
                call.argument<String>("mime"),
                result
            )
            "openForRead" -> openForRead(call.argument<String>("uri"), result)
            "createDocument" -> createDocument(
                call.argument<String>("name"),
                call.argument<String>("mime"),
                result
            )
            "openCreated" -> openCreated(call.argument<String>("uri"), result)
            "dropCreated" -> dropCreated(call.argument<String>("uri"), result)
            "openCacheOut" -> openCacheOut(call.argument<String>("name"), result)
            "sweep" -> {
                // a shred of a big video takes a while: never on the ui thread
                val all = call.argument<Boolean>("all") ?: false
                Thread {
                    sweep(activity.cacheDir, all)
                    activity.runOnUiThread { result.success(true) }
                }.start()
            }
            "sdk" -> result.success(Build.VERSION.SDK_INT)
            else -> result.notImplemented()
        }
    }

    private fun free(): Long = try {
        StatFs(activity.cacheDir.path).availableBytes
    } catch (e: Exception) {
        -1L
    }

    private fun pick(kind: String, result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.success(null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            when (kind) {
                "video" -> type = "video/*"
                "any" -> type = "*/*"
                "media" -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/*"))
                }
                else -> type = "image/*"
            }
        }
        try {
            pendingPick = result
            activity.startActivityForResult(intent, REQ_PICK)
        } catch (e: Exception) {
            pendingPick = null
            result.success(null)
        }
    }

    // [most], when given, is the most it copies: one over it stops as "big"
    private fun copyIn(uriText: String?, most: Long?, result: MethodChannel.Result) {
        val uri = uriText?.let { Uri.parse(it) }
        if (uri == null || !acceptable(uri)) {
            result.error("refused", "not a file kryfo may read", null)
            return
        }
        cancel.set(false)
        Thread {
            var out: File? = null
            try {
                // a provider that never answers the look leaves the copy
                // unnamed and of no known size, not this thread stuck
                val ex = java.util.concurrent.Executors.newSingleThreadExecutor()
                val info = try {
                    ex.submit<Map<String, Any?>> { describe(uri, null) }
                        .get(DESCRIBE_MS, java.util.concurrent.TimeUnit.MILLISECONDS)
                } catch (e: java.util.concurrent.TimeoutException) {
                    mapOf("uri" to uri.toString(), "mime" to null, "name" to null, "size" to -1L)
                } finally {
                    ex.shutdownNow()
                }
                if (cancel.get()) throw InterruptedException()
                val total = info["size"] as Long
                if (most != null && total > most) {
                    activity.runOnUiThread { result.error("big", "over the limit", null) }
                    return@Thread
                }
                val room = free()
                if (total > 0 && room >= 0 && room < total * 2 + (32L shl 20)) {
                    activity.runOnUiThread { result.error("full", "not enough room on the phone", null) }
                    return@Thread
                }
                val rnd = ByteArray(8).also { SecureRandom().nextBytes(it) }
                    .joinToString("") { "%02x".format(it) }
                val dir = File(File(activity.cacheDir, IN_DIR), rnd)
                dir.mkdirs()
                out = File(dir, safeName(info["name"] as String?))
                var done = 0L
                var lastTold = 0L
                val input = activity.contentResolver.openInputStream(uri)
                    ?: throw IllegalStateException("cannot open")
                reading = input
                input.use { i ->
                    if (cancel.get()) throw InterruptedException()
                    out.outputStream().use { o ->
                        val buf = ByteArray(256 * 1024)
                        while (true) {
                            if (cancel.get()) throw InterruptedException()
                            val n = i.read(buf)
                            if (n < 0) break
                            o.write(buf, 0, n)
                            done += n
                            // a provider can lie about the size here too
                            if (most != null && done > most) throw java.io.IOException("big")
                            if (done - lastTold >= (1L shl 20)) {
                                lastTold = done
                                // a provider can lie about the size. the disk cannot
                                val left = free()
                                if (left in 0 until (64L shl 20)) throw java.io.IOException("full")
                                val d = done
                                activity.runOnUiThread {
                                    channel?.invokeMethod("copyProgress", mapOf("done" to d, "total" to total))
                                }
                            }
                        }
                    }
                }
                val path = out.absolutePath
                activity.runOnUiThread { result.success(path) }
            } catch (e: InterruptedException) {
                out?.parentFile?.let { Shred.tree(it) }
                activity.runOnUiThread { result.error("cancelled", "stopped", null) }
            } catch (e: Exception) {
                out?.parentFile?.let { Shred.tree(it) }
                // a read a cancel closed under it
                val code = if (cancel.get()) "cancelled" else when (e.message) {
                    "full" -> "full"
                    "big" -> "big"
                    else -> "read"
                }
                activity.runOnUiThread { result.error(code, "could not read that file", null) }
            }
        }.start()
    }

    private fun outUri(path: String): Uri? {
        val f = File(path)
        val root = File(activity.cacheDir, OUT_DIR).canonicalPath + File.separator
        if (!f.canonicalPath.startsWith(root) || !f.isFile) return null
        return FileProvider.getUriForFile(activity, "${activity.packageName}.open", f)
    }

    // the installer check reads the file's end, so it runs off the ui
    // thread. anything that goes wrong on the way shares nothing
    private fun shareOut(path: String?, mime: String?, result: MethodChannel.Result) {
        Thread {
            val send = try {
                val uri = path?.let { outUri(it) }
                if (uri == null || Installer.refused(File(path), null, mime)) {
                    null
                } else {
                    Intent(Intent.ACTION_SEND).apply {
                        type = mime ?: "application/octet-stream"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        clipData = ClipData.newRawUri("", uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                }
            } catch (e: Exception) {
                null
            }
            activity.runOnUiThread {
                if (send == null) {
                    result.success(SharePick.FAILED)
                    return@runOnUiThread
                }
                if (!SharePick.start(activity, send) { result.success(it) }) {
                    result.success(SharePick.FAILED)
                }
            }
        }.start()
    }

    private fun saveToGallery(path: String?, name: String?, mime: String?, result: MethodChannel.Result) {
        val src = path?.let { File(it) }
        if (src == null || !src.isFile || outUri(src.path) == null) {
            result.success("failed")
            return
        }
        val type = mime ?: "application/octet-stream"
        val shown = safeName(name ?: src.name)
        if (Build.VERSION.SDK_INT < 29) {
            saveAs(path, name, mime, result)
            return
        }
        Thread {
            val ok = try {
                val video = type.startsWith("video/")
                val collection = if (video)
                    MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                else
                    MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                val uri = activity.contentResolver.insert(collection, SavePlace.newRow(activity, shown, type))
                    ?: throw IllegalStateException("no row")
                try {
                    activity.contentResolver.openOutputStream(uri)!!.use { o ->
                        src.inputStream().use { it.copyTo(o, 256 * 1024) }
                    }
                    activity.contentResolver.update(uri, SavePlace.doneRow(), null, null)
                } catch (e: Exception) {
                    activity.contentResolver.delete(uri, null, null)
                    throw e
                }
                true
            } catch (e: Exception) {
                false
            }
            activity.runOnUiThread { result.success(if (ok) "saved" else "failed") }
        }.start()
    }

    private fun saveAs(path: String?, name: String?, mime: String?, result: MethodChannel.Result) {
        val src = path?.let { File(it) }
        if (src == null || !src.isFile || outUri(src.path) == null || pendingSaveAs != null) {
            result.success("failed")
            return
        }
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mime ?: "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, safeName(name ?: src.name))
        }
        try {
            pendingSaveAs = result
            pendingSaveAsPath = src.path
            activity.startActivityForResult(intent, REQ_SAVE_AS)
        } catch (e: Exception) {
            pendingSaveAs = null
            pendingSaveAsPath = null
            result.success("failed")
        }
    }

    // the descriptor is detached: whoever is handed the number owns it and
    // closes it. the engine does, at the end of the one call it is given to.
    private fun openForRead(uriText: String?, result: MethodChannel.Result) {
        val uri = uriText?.let { Uri.parse(it) }
        if (uri == null || !acceptable(uri)) {
            result.success(-1)
            return
        }
        try {
            val pfd = activity.contentResolver.openFileDescriptor(uri, "r")
            result.success(pfd?.detachFd() ?: -1)
        } catch (e: Exception) {
            result.success(-1)
        }
    }

    private fun createDocument(name: String?, mime: String?, result: MethodChannel.Result) {
        if (pendingCreate != null) {
            result.success(null)
            return
        }
        // with the file's own type android numbers a second copy as
        // "name (1).pdf". with octet-stream it becomes "name.pdf (1)"
        val shown = safeName(name)
        val byName = android.webkit.MimeTypeMap.getSingleton()
            .getMimeTypeFromExtension(shown.substringAfterLast('.', "").lowercase())
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = byName ?: mime ?: "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, shown)
        }
        try {
            pendingCreate = result
            activity.startActivityForResult(intent, REQ_CREATE)
        } catch (e: Exception) {
            pendingCreate = null
            result.success(null)
        }
    }

    private fun openCreated(uriText: String?, result: MethodChannel.Result) {
        if (uriText == null || !created.contains(uriText)) {
            result.success(-1)
            return
        }
        try {
            val pfd = activity.contentResolver.openFileDescriptor(Uri.parse(uriText), "wt")
            result.success(pfd?.detachFd() ?: -1)
        } catch (e: Exception) {
            result.success(-1)
        }
    }

    // a file this session made and then could not finish is taken away again
    private fun dropCreated(uriText: String?, result: MethodChannel.Result) {
        if (uriText == null || !created.remove(uriText)) {
            result.success(false)
            return
        }
        val ok = try {
            DocumentsContract.deleteDocument(activity.contentResolver, Uri.parse(uriText))
        } catch (e: Exception) {
            false
        }
        result.success(ok)
    }

    private fun openCacheOut(name: String?, result: MethodChannel.Result) {
        try {
            val rnd = ByteArray(8).also { SecureRandom().nextBytes(it) }
                .joinToString("") { "%02x".format(it) }
            val dir = File(File(activity.cacheDir, OUT_DIR), rnd)
            dir.mkdirs()
            val f = File(dir, safeName(name))
            val pfd = ParcelFileDescriptor.open(
                f,
                ParcelFileDescriptor.MODE_CREATE or
                    ParcelFileDescriptor.MODE_WRITE_ONLY or
                    ParcelFileDescriptor.MODE_TRUNCATE
            )
            result.success(mapOf("path" to f.absolutePath, "fd" to pfd.detachFd()))
        } catch (e: Exception) {
            result.success(null)
        }
    }

    private fun deleteOriginal(uriText: String?, result: MethodChannel.Result) {
        val uri = uriText?.let { Uri.parse(it) }
        if (uri == null || !isMediaStore(uri) || Build.VERSION.SDK_INT < 29 || pendingDelete != null) {
            result.success("unavailable")
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= 30) {
                val pi = MediaStore.createDeleteRequest(activity.contentResolver, listOf(uri))
                pendingDelete = result
                activity.startIntentSenderForResult(pi.intentSender, REQ_DELETE, null, 0, 0, 0)
                return
            }
            try {
                val n = activity.contentResolver.delete(uri, null, null)
                result.success(if (n > 0) "deleted" else "failed")
            } catch (e: SecurityException) {
                val r = e as? RecoverableSecurityException ?: throw e
                pendingDelete = result
                activity.startIntentSenderForResult(
                    r.userAction.actionIntent.intentSender, REQ_DELETE, null, 0, 0, 0
                )
            }
        } catch (e: Exception) {
            pendingDelete = null
            result.success("failed")
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            REQ_PICK -> {
                val r = pendingPick ?: return true
                pendingPick = null
                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null || !acceptable(uri)) {
                    r.success(null)
                } else {
                    r.success(describe(uri, null))
                }
                return true
            }
            REQ_DELETE -> {
                val r = pendingDelete ?: return true
                pendingDelete = null
                r.success(if (resultCode == Activity.RESULT_OK) "deleted" else "kept")
                return true
            }
            REQ_CREATE -> {
                val r = pendingCreate ?: return true
                pendingCreate = null
                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null) {
                    r.success(null)
                } else {
                    created.add(uri.toString())
                    r.success(uri.toString())
                }
                return true
            }
            REQ_SAVE_AS -> {
                val r = pendingSaveAs ?: return true
                val path = pendingSaveAsPath
                pendingSaveAs = null
                pendingSaveAsPath = null
                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null || path == null) {
                    r.success("kept")
                    return true
                }
                Thread {
                    val ok = try {
                        activity.contentResolver.openOutputStream(uri)!!.use { o ->
                            File(path).inputStream().use { it.copyTo(o, 256 * 1024) }
                        }
                        true
                    } catch (e: Exception) {
                        false
                    }
                    activity.runOnUiThread { r.success(if (ok) "saved" else "failed") }
                }.start()
                return true
            }
        }
        return false
    }
}

data class SharedFiles(
    val id: String,
    // each uri with the type the share said, when it named one
    val items: List<Pair<Uri, String?>>,
    val seen: String? = null,
    val chat: String? = null
)

data class SharedWords(
    val id: String,
    val text: String?,
    val subject: String?,
    val seen: String? = null,
    val chat: String? = null
)
