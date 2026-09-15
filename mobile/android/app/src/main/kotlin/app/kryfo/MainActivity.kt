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
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val NOTIF_PERM_REQUEST = 1001
        private const val PERM_PREFS = "halo_perm"
        private const val PERM_ASKED_KEY = "asked_post_notifications"
        // one ask for the life of the process, whatever the activity does
        private var notifPermAsked = false
        // the one engine we keep across activity teardown
        const val ENGINE_ID = "halo_engine"
    }

    // one engine per process, made by HaloApplication when the process
    // starts, and every activity attaches to that one. the old rule here
    // built a fresh engine whenever the cached one was not drawing, which
    // is every reopen after a recents swipe: each reopen ran a second
    // main(), a second boot, a second set of relay subscriptions, and the
    // old engine was never let go. two reopens put the process past 400
    // mb, which is what xiaomi's killer picks. the detached-renderer crash
    // that rule worked around has not reproduced on this flutter.
    override fun getCachedEngineId(): String? {
        val cache = FlutterEngineCache.getInstance()
        return if (cache.get(ENGINE_ID) != null) ENGINE_ID else null
    }

    // keep the engine when this screen goes away, so the dart isolate and the
    // nostr poll timer keep running in the background
    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onResume() {
        super.onResume()
        askForNotificationsOnce()
        startListenerService()
        schedulePeriodicJob()
    }

    private fun startListenerService() {
        val intent = Intent(this, HaloListenerService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun schedulePeriodicJob() = JobSetup.schedule(this)

    // ask for the notification permission at most once, and never after a
    // refusal that android has made final.
    //
    // this used to run on every onResume with no guard. once someone has
    // denied twice, android stops showing a dialog and answers instantly
    // from its own record: the request activity opens, finishes, our
    // activity resumes, onResume asks again. forty milliseconds a turn,
    // forever. the window loses focus every turn, so the keyboard cannot
    // stay up, taps and the back key land on a screen that is already
    // going, and the phone burns battery until the app is killed. it
    // needs android 13 or newer and a refusal; nothing else.
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
    // into a surfaceview whose own secure bit was latched when the flag went
    // on, and one ui keeps it after the flag comes off. clearing meant the
    // whole app stayed unscreenshottable until a restart. so the surface is
    // told directly, and on the way off it is recreated, which is the one
    // thing that reliably drops the bit.
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

    private fun setSecureWindow(on: Boolean) {
        android.util.Log.i("kryfo", "setSecure on=$on was=$secureNow")
        if (on) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
        val surface = findSurface(window.decorView)
        surface?.setSecure(on)
        // no surface recreate on the way off any more: it flashed the
        // window on every toggle. one ui may keep the bit until the next
        // start, and the switch that drives this says "after the next
        // start" for that reason.
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // hold on to it so the next activity attaches to this same engine
        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "halo/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isMiui" -> result.success(isMiuiDevice())
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
                        // engine outlives the window now, so this can be
                        // called with nothing attached
                        try {
                            setSecureWindow(on)
                        } catch (e: Exception) {
                        }
                        result.success(null)
                    }
                    // the wipe. clearing our own data is what the settings
                    // "clear storage" button does: every file and preference
                    // gone in one synchronous call, the process force-stopped
                    // so the sticky service does not resurrect it, and the
                    // next launch is onboarding. dart-side deletes plus
                    // exit() lost a race: the preference clears were still
                    // queued for disk when the process died, so the pin and
                    // the onboarding flag came back.
                    "wipe" -> {
                        // the sticky listener goes first: if the clear is
                        // refused and dart exits, nothing brings the app back
                        try {
                            applicationContext.stopService(
                                Intent(applicationContext, HaloListenerService::class.java)
                            )
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
                    else -> result.notImplemented()
                }
            }
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

    // true when some settings page opened. the miui page first, the app's
    // own details page when that is missing, false when both fail
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
        val direct = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        }
        try {
            startActivity(direct)
            return true
        } catch (e: Exception) {
            // some builds do not carry that page; the app details page has
            // the same switch one tap deeper
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
