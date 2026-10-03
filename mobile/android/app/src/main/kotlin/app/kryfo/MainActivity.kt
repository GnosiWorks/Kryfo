package app.kryfo

import android.Manifest
import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.ContentValues
import android.content.ClipData
import android.content.ClipboardManager
import android.os.PersistableBundle
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.ByteArrayOutputStream
import android.graphics.Matrix
import android.media.MediaMetadataRetriever
import android.webkit.MimeTypeMap
import java.io.File
import androidx.exifinterface.media.ExifInterface
import java.io.ByteArrayInputStream
import android.content.Context
import android.provider.MediaStore
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import android.content.ActivityNotFoundException
import android.net.Uri
import android.provider.Settings
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StringCodec

class MainActivity : FlutterFragmentActivity() {
    private val REQ_SAVE_DOCUMENT = 7311
    private val tools = ToolsBridge(this)
    private var videos: VideoPlayers? = null
    companion object {
        private const val NOTIF_PERM_REQUEST = 1001
        private const val PERM_PREFS = "halo_perm"
        private const val PERM_ASKED_KEY = "asked_post_notifications"
        // one ask for the life of the process, whatever the activity does
        private var notifPermAsked = false
        // the one engine we keep across activity teardown
        const val ENGINE_ID = "halo_engine"
        // when this app last opened a screen or a permission prompt itself
        private var openedAt = 0L
        private val promptSeen = object : ActivityCompat.PermissionCompatDelegate {
            override fun requestPermissions(activity: android.app.Activity, permissions: Array<String>, requestCode: Int): Boolean {
                openedAt = SystemClock.uptimeMillis()
                return false
            }
            @Suppress("OVERRIDE_DEPRECATION")
            override fun onActivityResult(activity: android.app.Activity, requestCode: Int, resultCode: Int, data: Intent?): Boolean = false
        }
    }

    // one engine per process, made by HaloApplication, and every activity
    // attaches to it. a fresh engine per reopen would run main() again with a
    // second set of relay subscriptions and never let the old one go.
    override fun getCachedEngineId(): String? {
        val cache = FlutterEngineCache.getInstance()
        return if (cache.get(ENGINE_ID) != null) ENGINE_ID else null
    }

    // keep the engine when this screen goes away, so the dart isolate and the
    // nostr poll timer keep running in the background
    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        tools.offer(intent)
    }

    // the window and the user leaving lock too, not only the lifecycle
    private var awayChannel: BasicMessageChannel<String>? = null
    private fun tellAway() {
        awayChannel?.send("away")
    }

    private var windowSeen: WindowWatch? = null

    // a prompt or a screen this app opened itself is not the user leaving.
    // a permission prompt keeps the window on screen, so a real trip away
    // still reaches dart through the window or onStop
    @Suppress("OVERRIDE_DEPRECATION", "DEPRECATION")
    override fun startActivityForResult(intent: Intent, requestCode: Int, options: Bundle?) {
        openedAt = SystemClock.uptimeMillis()
        try {
            super.startActivityForResult(intent, requestCode, options)
        } catch (e: Throwable) {
            openedAt = 0L
            throw e
        }
    }

    // a request android answers without a prompt never pauses this screen
    @Suppress("OVERRIDE_DEPRECATION", "DEPRECATION")
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        openedAt = 0L
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (SystemClock.uptimeMillis() - openedAt > 3000) tellAway()
    }

    override fun onPause() {
        super.onPause()
        openedAt = 0L
    }

    override fun onDestroy() {
        windowSeen?.let {
            it.gone = null
            (it.parent as? ViewGroup)?.removeView(it)
        }
        windowSeen = null
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        // a file opened or shared with another app is a decrypted copy in
        // cache/open or cache/share_plus. coming back here is the only sign
        // that app is done with it, and a resume also follows every start.
        // an app that still holds it open keeps its descriptor; the name is
        // gone. a shared copy is given a while longer, see clearShareCopies.
        clearOpenCopies()
        // dart asks for notifications (askNotifications) once the lock is
        // down, so android's dialog never opens over the pin pad. one that
        // is up is left alone: starting it again only posts its
        // notification anew. a mode or language change still restarts it
        if (!HaloListenerService.running) startListenerService()
        schedulePeriodicJob()
    }

    private fun startListenerService() {
        if (!DeliveryPrefs.staysOn(this)) return
        if (!KryfoState.hasData(this)) return
        val intent = Intent(this, HaloListenerService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun schedulePeriodicJob() = JobSetup.schedule(this)

    // ask for the notification permission at most once, and never after a
    // refusal that android has made final. android answers a final refusal
    // at once, so asking on every resume would loop: the request activity
    // closes, this one resumes and asks again.
    private fun askForNotificationsOnce() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (notifPermAsked) return
        val granted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) return
        // asked before and android will not show a dialog again: the answer
        // is no and it is final. the only way back is android's settings.
        val prefs = getSharedPreferences(PERM_PREFS, Context.MODE_PRIVATE)
        val askedBefore = prefs.getBoolean(PERM_ASKED_KEY, false)
        if (askedBefore &&
            !ActivityCompat.shouldShowRequestPermissionRationale(
                this, Manifest.permission.POST_NOTIFICATIONS
            )
        ) {
            notifPermAsked = true
            return
        }
        notifPermAsked = true
        prefs.edit().putBoolean(PERM_ASKED_KEY, true).apply()
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIF_PERM_REQUEST
        )
    }

    // flag_secure on the window is not enough on every phone: flutter draws
    // into a surfaceview with its own secure bit, so the surface is told
    // directly.
    private var secureNow = false
    private fun shrinkJpeg(bytes: ByteArray, maxEdge: Int, quality: Int): ByteArray? {
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            var sample = 1
            while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxEdge) sample *= 2
            val opts = BitmapFactory.Options().apply { inSampleSize = sample }
            val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts) ?: return null
            // the sensor writes its pixels sideways and an orientation tag
            // to say so. the tag is stripped later, so the pixels are turned
            // upright here, while it is still there to read.
            val orientation = try {
                ExifInterface(ByteArrayInputStream(bytes))
                    .getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            } catch (e: Exception) {
                ExifInterface.ORIENTATION_NORMAL
            }
            val m = Matrix()
            when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90 -> m.postRotate(90f)
                ExifInterface.ORIENTATION_ROTATE_180 -> m.postRotate(180f)
                ExifInterface.ORIENTATION_ROTATE_270 -> m.postRotate(270f)
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> m.postScale(-1f, 1f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> m.postScale(1f, -1f)
                ExifInterface.ORIENTATION_TRANSPOSE -> { m.postRotate(90f); m.postScale(-1f, 1f) }
                ExifInterface.ORIENTATION_TRANSVERSE -> { m.postRotate(270f); m.postScale(-1f, 1f) }
            }
            val bm = if (m.isIdentity) decoded
                else Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, m, true)
            val scale = maxEdge.toFloat() / maxOf(bm.width, bm.height)
            val out = if (scale < 1f) {
                Bitmap.createScaledBitmap(bm, (bm.width * scale).toInt(), (bm.height * scale).toInt(), true)
            } else bm
            val bos = ByteArrayOutputStream()
            out.compress(Bitmap.CompressFormat.JPEG, quality, bos)
            if (out !== bm) out.recycle()
            if (bm !== decoded) bm.recycle()
            decoded.recycle()
            bos.toByteArray()
        } catch (e: Throwable) {
            // an out-of-memory on a big frame is a Throwable, not an
            // Exception; the caller gets null and keeps the original
            null
        }
    }

    // dart's last screenshot setting, kept so the next start's first frame is
    // covered before dart runs
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        if (getSharedPreferences("kryfo_window", MODE_PRIVATE).getBoolean("secure", false)) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            if (android.os.Build.VERSION.SDK_INT >= 33) setRecentsScreenshotEnabled(false)
            secureNow = true
        }
        super.onCreate(savedInstanceState)
        windowSeen = WindowWatch(this).also {
            it.gone = { tellAway() }
            addContentView(it, ViewGroup.LayoutParams(0, 0))
        }
        ActivityCompat.setPermissionCompatDelegate(promptSeen)
    }

    private fun setSecureWindow(on: Boolean) {
        android.util.Log.i("kryfo", "setSecure on=$on was=$secureNow")
        if (on) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
        // android 13 and later keep their own picture for recents
        if (android.os.Build.VERSION.SDK_INT >= 33) setRecentsScreenshotEnabled(!on)
        getSharedPreferences("kryfo_window", MODE_PRIVATE).edit().putBoolean("secure", on).apply()
        val surface = findSurface(window.decorView)
        surface?.setSecure(on)
        // no surface recreate on the way off, it flashes the window. one ui
        // may keep the bit until the next start, and the switch says so.
        secureNow = on
    }

    private fun findSurface(v: View): SurfaceView? {
        if (v is SurfaceView) return v
        if (v is ViewGroup) {
            for (i in 0 until v.childCount) {
                val hit = findSurface(v.getChildAt(i))
                if (hit != null) return hit
            }
        }
        return null
    }

    // a player belongs to the screen that showed it
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        videos?.releaseAll()
        videos = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // hold on to it so the next activity attaches to this same engine
        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
        awayChannel = BasicMessageChannel(flutterEngine.dartExecutor.binaryMessenger, "kryfo/window", StringCodec.INSTANCE)
        tools.attach(MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ToolsBridge.CHANNEL))
        tools.offer(intent)
        videos = VideoPlayers(flutterEngine.renderer).also { v ->
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kryfo/video")
                .setMethodCallHandler { call, result -> v.handle(call, result) }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "halo/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isMiui" -> result.success(isMiuiDevice())
                    "askNotifications" -> {
                        askForNotificationsOnce()
                        result.success(null)
                    }
                    // the three facts the transport screen shows so a
                    // person can tell asleep from killed without adb
                    "isBatteryExempt" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "processUptimeMs" -> {
                        result.success(
                            SystemClock.elapsedRealtime() - Process.getStartElapsedRealtime()
                        )
                    }
                    "lastExit" -> result.success(lastExit())
                    "helperApps" -> result.success(HelperPush.distributors(this))
                    "helperChosen" -> result.success(HelperPush.distributor(this))
                    "helperRegister" -> {
                        val pkg = call.argument<String>("package")
                        val instance = call.argument<String>("instance")
                        result.success(
                            if (pkg == null || instance.isNullOrEmpty()) false
                            else HelperPush.register(this, pkg, instance)
                        )
                    }
                    "helperUnregister" -> {
                        HelperPush.unregisterAll(this)
                        result.success(true)
                    }
                    // wall-clock time this phone was switched on. a gap in
                    // the app's heartbeat that spans it was the phone being
                    // off, not the app being killed.
                    "bootedAtMs" -> result.success(
                        System.currentTimeMillis() - android.os.SystemClock.elapsedRealtime()
                    )
                    // fingerprint unlock on a key a new finger invalidates
                    "bioReady" -> result.success(BioKey.ready())
                    "bioState" -> result.success(BioKey.state())
                    "bioEnable" -> result.success(BioKey.create())
                    "bioDisable" -> {
                        BioKey.delete()
                        result.success(true)
                    }
                    "bioUnlock" -> {
                        val title = call.argument<String>("title") ?: "kryfo"
                        val cancel = call.argument<String>("cancel") ?: "Cancel"
                        BioKey.unlock(this, title, cancel) { result.success(it) }
                    }
                    // the pin hold runs on these: time since boot, which a
                    // change of date does not move, and which boot this is
                    "uptimeMs" -> result.success(SystemClock.elapsedRealtime())
                    "bootCount" -> result.success(
                        try {
                            android.provider.Settings.Global.getInt(
                                contentResolver,
                                android.provider.Settings.Global.BOOT_COUNT,
                            )
                        } catch (e: Exception) {
                            -1
                        }
                    )
                    // the delivery mode changed. dart has written the new
                    // mode before calling, so this only has to act on it.
                    "applyDeliveryMode" -> {
                        try {
                            // also how a language switch reaches android
                            HaloListenerService.nameChannel(this, onlyIfThere = true)
                            if (DeliveryPrefs.staysOn(this)) {
                                startListenerService()
                            } else {
                                applicationContext.stopService(
                                    Intent(applicationContext, HaloListenerService::class.java)
                                )
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "notificationsEnabled" -> {
                        result.success(
                            NotificationManagerCompat.from(this).areNotificationsEnabled()
                        )
                    }
                    "openNotificationSettings" -> {
                        result.success(openNotificationSettings())
                    }
                    "openAutostartSettings" -> {
                        result.success(openAutostartSettings())
                    }
                    "setSecure" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        // the engine outlives the window, so this can be
                        // called with nothing attached
                        try {
                            setSecureWindow(on)
                        } catch (e: Exception) {
                        }
                        result.success(null)
                    }
                    // the wipe: what the settings "clear storage" button does,
                    // every file and preference gone in one synchronous call
                    // and the process force-stopped. deletes from dart race
                    // the preference writes still queued for disk.
                    "wipe" -> {
                        // the sticky listener goes first: if the clear is
                        // refused and dart exits, nothing brings the app back
                        try {
                            applicationContext.stopService(
                                Intent(applicationContext, HaloListenerService::class.java)
                            )
                        } catch (e: Exception) {
                        }
                        // and the periodic job, which survives the clear and
                        // would start the process with a fresh identity
                        try {
                            applicationContext.getSystemService(JobScheduler::class.java)?.cancelAll()
                        } catch (e: Exception) {
                        }
                        val am = applicationContext
                            .getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val ok = try { am.clearApplicationUserData() } catch (e: Exception) { false }
                        result.success(ok)
                    }
                    // a copy the keyboard's history and the android 13 preview
                    // treat as sensitive: ids, codes, addresses
                    "copySensitive" -> {
                        val text = call.argument<String>("text") ?: ""
                        val cm = applicationContext
                            .getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        val clip = ClipData.newPlainText("", text)
                        clip.description.extras = PersistableBundle().apply {
                            putBoolean("android.content.extra.IS_SENSITIVE", true)
                        }
                        cm.setPrimaryClip(clip)
                        result.success(true)
                    }
                    // a camera shot at the sensor's own size and quality,
                    // brought to what a gallery pick gets: 1280 on the long
                    // edge, jpeg 70. decoded pixels carry no metadata.
                    "shrinkJpeg" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val maxEdge = call.argument<Int>("maxEdge") ?: 1280
                        val quality = call.argument<Int>("quality") ?: 70
                        result.success(if (bytes == null) null else shrinkJpeg(bytes, maxEdge, quality))
                    }
                    "saveToPictures" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val name = call.argument<String>("name") ?: "kryfo.jpg"
                        val mime = call.argument<String>("mime") ?: "image/jpeg"
                        result.success(bytes != null && saveToPictures(bytes, name, mime))
                    }
                    "openFile" -> {
                        val path = call.argument<String>("path")
                        val name = call.argument<String>("name")
                        if (path == null) result.success(false) else openFile(path, name, result)
                    }
                    "videoInfo" -> {
                        val path = call.argument<String>("path")
                        val maxEdge = call.argument<Int>("maxEdge") ?: 640
                        if (path == null) result.success(null) else videoInfo(path, maxEdge, result)
                    }
                    "saveDocument" -> {
                        val path = call.argument<String>("path")
                        val name = call.argument<String>("name") ?: "kryfo-backup.kryfo"
                        if (path == null || pendingSave != null) {
                            result.success(false)
                        } else {
                            saveDocument(path, name, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // "open with". another app cannot read our files, and must not be able
    // to: the file is copied to cache/open/, the only folder the provider
    // serves, and the uri is granted to the one app that gets the intent.
    // the folder holds one file; the last one goes before the next arrives.
    private fun clearOpenCopies() {
        Thread { File(cacheDir, "open").deleteRecursively() }.start()
        clearShareCopies()
    }

    // the share sheet's copies sit in share_plus/ until the next share. some
    // targets read theirs only after their dialog has closed and this app is
    // back, so a copy is given a while first, and whatever is left goes at
    // the next start.
    private val shareGraceMs = 10 * 60 * 1000L
    private val shareTimer = android.os.Handler(android.os.Looper.getMainLooper())
    private val shareSweep = Runnable { clearShareCopies() }

    private fun clearShareCopies() {
        Thread {
            if (clearAgedShareCopies()) {
                shareTimer.removeCallbacks(shareSweep)
                shareTimer.postDelayed(shareSweep, shareGraceMs)
            }
        }.start()
    }

    // true while a copy is still too young to go
    private fun clearAgedShareCopies(): Boolean {
        val dir = File(cacheDir, "share_plus")
        if (!dir.exists()) return false
        val cutoff = System.currentTimeMillis() - shareGraceMs
        var young = false
        for (f in dir.walkBottomUp()) {
            if (f.isFile) {
                if (f.lastModified() < cutoff) {
                    f.delete()
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

    private fun openFile(path: String, name: String?, result: MethodChannel.Result) {
        Thread {
            var ok = false
            try {
                val src = File(path)
                val dir = File(cacheDir, "open")
                dir.deleteRecursively()
                dir.mkdirs()
                val safe = (name ?: src.name).replace(Regex("[^A-Za-z0-9._ -]"), "_").takeLast(80)
                val dst = File(dir, if (safe.isBlank()) "file" else safe)
                src.inputStream().use { i -> dst.outputStream().use { o -> i.copyTo(o) } }
                val uri = androidx.core.content.FileProvider.getUriForFile(
                    this, "$packageName.open", dst
                )
                val ext = dst.extension.lowercase()
                val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
                    ?: when (ext) {
                        "mov" -> "video/quicktime"
                        "mkv" -> "video/x-matroska"
                        "m4v" -> "video/mp4"
                        "3g2" -> "video/3gpp2"
                        "opus" -> "audio/ogg"
                        else -> "application/octet-stream"
                    }
                val view = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, mime)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                runOnUiThread {
                    try {
                        startActivity(view)
                        result.success(true)
                    } catch (e: ActivityNotFoundException) {
                        // nothing on this phone opens that kind of file
                        result.success(false)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                ok = true
            } catch (e: Exception) {
                // fall through
            }
            if (!ok) runOnUiThread { result.success(false) }
        }.start()
    }

    // one frame and the length of a video, for its bubble. the frame goes
    // back as bytes and is never written anywhere: a thumbnail on disk
    // would outlive a message that burned.
    private fun videoInfo(path: String, maxEdge: Int, result: MethodChannel.Result) {
        Thread {
            var out: Map<String, Any?>? = null
            val r = MediaMetadataRetriever()
            try {
                r.setDataSource(path)
                val ms = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                    ?.toLongOrNull() ?: 0L
                val frame = r.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                if (frame != null) {
                    val scale = maxEdge.toFloat() / maxOf(frame.width, frame.height)
                    val bmp = if (scale < 1f) {
                        Bitmap.createScaledBitmap(
                            frame,
                            (frame.width * scale).toInt().coerceAtLeast(1),
                            (frame.height * scale).toInt().coerceAtLeast(1),
                            true
                        )
                    } else frame
                    val bos = ByteArrayOutputStream()
                    bmp.compress(Bitmap.CompressFormat.JPEG, 80, bos)
                    out = mapOf(
                        "jpeg" to bos.toByteArray(),
                        "ms" to ms,
                        "w" to bmp.width,
                        "h" to bmp.height
                    )
                    if (bmp !== frame) bmp.recycle()
                    frame.recycle()
                } else if (ms > 0) {
                    out = mapOf("jpeg" to null, "ms" to ms, "w" to 16, "h" to 9)
                }
            } catch (e: Exception) {
                // not a video the phone can read; the bubble says so
            } finally {
                try { r.release() } catch (e: Exception) {}
            }
            runOnUiThread { result.success(out) }
        }.start()
    }

    // the system's own save dialog, then a stream copy from the file into
    // whatever the person chose. the file never goes through memory or the
    // channel: a backup can be a year of photos. false when they backed out.
    private var pendingSave: MethodChannel.Result? = null
    private var pendingSavePath: String? = null

    private fun saveDocument(path: String, name: String, result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, name)
        }
        try {
            pendingSave = result
            pendingSavePath = path
            startActivityForResult(intent, REQ_SAVE_DOCUMENT)
        } catch (e: ActivityNotFoundException) {
            pendingSave = null
            pendingSavePath = null
            result.success(false)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (tools.onActivityResult(requestCode, resultCode, data)) return
        if (requestCode != REQ_SAVE_DOCUMENT) return
        val result = pendingSave ?: return
        val path = pendingSavePath
        pendingSave = null
        pendingSavePath = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null || path == null) {
            result.success(false)
            return
        }
        Thread {
            val ok = try {
                contentResolver.openOutputStream(uri, "wt")?.use { out ->
                    java.io.FileInputStream(path).use { it.copyTo(out) }
                    true
                } ?: false
            } catch (e: Exception) {
                false
            }
            runOnUiThread { result.success(ok) }
        }.start()
    }

    // a copy into the phone's photos, through the media store, only when the
    // person asked for it. android 10 and up: older releases would need the
    // storage permission, and we would rather say no than ask for that.
    private fun saveToPictures(bytes: ByteArray, name: String, mime: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        return try {
            val video = mime.startsWith("video/")
            val collection = if (video)
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            else
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    if (video) "Movies/Kryfo" else "Pictures/Kryfo"
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(collection, values) ?: return false
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) } ?: return false
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun isMiuiDevice(): Boolean {
        val mfr = Build.MANUFACTURER.lowercase()
        return mfr == "xiaomi" || mfr == "redmi" || mfr == "poco"
    }

    // why our process last stopped, from the system's own record. the
    // reason is what tells a kill from a crash from an update.
    private fun lastExit(): Map<String, Any?>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        return try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val list = am.getHistoricalProcessExitReasons(packageName, 0, 1)
            if (list.isEmpty()) return null
            val e = list[0]
            val word = when (e.reason) {
                ApplicationExitInfo.REASON_SIGNALED -> "killed by the system"
                ApplicationExitInfo.REASON_LOW_MEMORY -> "low memory"
                ApplicationExitInfo.REASON_CRASH,
                ApplicationExitInfo.REASON_CRASH_NATIVE -> "crashed"
                ApplicationExitInfo.REASON_ANR -> "not responding"
                ApplicationExitInfo.REASON_USER_REQUESTED -> "stopped by you"
                ApplicationExitInfo.REASON_USER_STOPPED -> "stopped by you"
                ApplicationExitInfo.REASON_PACKAGE_UPDATED -> "updated"
                ApplicationExitInfo.REASON_OTHER -> "stopped by the system"
                ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "used too much"
                ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "permission changed"
                ApplicationExitInfo.REASON_EXIT_SELF -> "closed itself"
                else -> "stopped"
            }
            mapOf(
                "at" to e.timestamp,
                "reason" to e.reason,
                "word" to word,
                "pssKb" to e.pss,
            )
        } catch (e: Exception) {
            null
        }
    }

    // android's own notification page for kryfo. the permission dialog is
    // gone for good once the answer is final, so this is the only way back.
    private fun openNotificationSettings(): Boolean {
        // the per-app notification page arrives in api 26. below that, and
        // on a build that does not carry it, the app details page has the
        // same switch one tap deeper.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val direct = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
            try {
                startActivity(direct)
                return true
            } catch (e: Exception) {
                // fall through to the app details page
            }
        }
        return try {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", packageName, null)
                }
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    // true when some settings page opened. the miui page first, the app's
    // own details page when that is missing, false when both fail
    private fun openAutostartSettings(): Boolean {
        val miui = Intent().apply {
            setClassName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity"
            )
        }
        try {
            startActivity(miui)
            return true
        } catch (e: Exception) {
            // fall through to the generic page
        }
        return try {
            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(fallback)
            true
        } catch (e: Exception) {
            false
        }
    }
}

// a view of no size that hears when its window leaves the screen
private class WindowWatch(context: Context) : View(context) {
    var gone: (() -> Unit)? = null

    init {
        isFocusable = false
        isClickable = false
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
    }

    override fun onWindowVisibilityChanged(visibility: Int) {
        super.onWindowVisibilityChanged(visibility)
        if (visibility != VISIBLE) gone?.invoke()
    }
}
