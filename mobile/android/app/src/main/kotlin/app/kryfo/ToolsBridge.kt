// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ClipData
import android.content.ContentValues
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

        fun sweep(cacheDir: File, all: Boolean) {
            val now = System.currentTimeMillis()
            for (name in listOf(IN_DIR, OUT_DIR)) {
                val dir = File(cacheDir, name)
                val kids = dir.listFiles() ?: continue
                for (f in kids) {
                    if (all || now - f.lastModified() > MAX_AGE_MS) f.deleteRecursively()
                }
            }
        }
    }

    private var channel: MethodChannel? = null
    private var shared: Uri? = null
    private var sharedMime: String? = null
    private var pendingPick: MethodChannel.Result? = null
    private var pendingDelete: MethodChannel.Result? = null
    private var pendingSaveAs: MethodChannel.Result? = null
    private var pendingSaveAsPath: String? = null
    private var pendingCreate: MethodChannel.Result? = null
    private val created = HashSet<String>()
    private val cancel = AtomicBoolean(false)

    fun attach(ch: MethodChannel) {
        channel = ch
        ch.setMethodCallHandler { call, result -> handle(call, result) }
    }

    fun offer(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND) return
        val type = intent.type ?: return
        if (!type.startsWith("image/") && !type.startsWith("video/")) return
        val uri: Uri? = if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
        if (uri == null || !acceptable(uri)) return
        shared = uri
        sharedMime = type
        activity.runOnUiThread { channel?.invokeMethod("shared", null) }
    }

    private fun acceptable(uri: Uri): Boolean {
        if (uri.scheme != "content") return false
        val auth = uri.authority ?: return false
        return !auth.startsWith(activity.packageName)
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
            "takeShared" -> {
                val u = shared
                val m = sharedMime
                shared = null
                sharedMime = null
                result.success(if (u == null) null else describe(u, m))
            }
            "pick" -> pick(call.argument<String>("kind") ?: "image", result)
            "copyIn" -> copyIn(call.argument<String>("uri"), result)
            "cancelCopy" -> {
                cancel.set(true)
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
                sweep(activity.cacheDir, call.argument<Boolean>("all") ?: false)
                result.success(true)
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

    private fun copyIn(uriText: String?, result: MethodChannel.Result) {
        val uri = uriText?.let { Uri.parse(it) }
        if (uri == null || !acceptable(uri)) {
            result.error("refused", "not a file kryfo may read", null)
            return
        }
        cancel.set(false)
        Thread {
            var out: File? = null
            try {
                val info = describe(uri, null)
                val total = info["size"] as Long
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
                input.use { i ->
                    out.outputStream().use { o ->
                        val buf = ByteArray(256 * 1024)
                        while (true) {
                            if (cancel.get()) throw InterruptedException()
                            val n = i.read(buf)
                            if (n < 0) break
                            o.write(buf, 0, n)
                            done += n
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
                out?.parentFile?.deleteRecursively()
                activity.runOnUiThread { result.error("cancelled", "stopped", null) }
            } catch (e: Exception) {
                out?.parentFile?.deleteRecursively()
                val code = if (e.message == "full") "full" else "read"
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

    private fun shareOut(path: String?, mime: String?, result: MethodChannel.Result) {
        val uri = path?.let { outUri(it) }
        if (uri == null) {
            result.success(false)
            return
        }
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mime ?: "application/octet-stream"
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newRawUri("", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            activity.startActivity(Intent.createChooser(send, null))
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
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
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, shown)
                    put(MediaStore.MediaColumns.MIME_TYPE, type)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, if (video) "Movies/Kryfo" else "Pictures/Kryfo")
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val uri = activity.contentResolver.insert(collection, values)
                    ?: throw IllegalStateException("no row")
                try {
                    activity.contentResolver.openOutputStream(uri)!!.use { o ->
                        src.inputStream().use { it.copyTo(o, 256 * 1024) }
                    }
                    values.clear()
                    values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    activity.contentResolver.update(uri, values, null, null)
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
