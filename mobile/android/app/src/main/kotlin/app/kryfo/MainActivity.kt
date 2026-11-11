package app.kryfo

import android.Manifest
import android.app.ActivityManager
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.ClipData
import android.content.ClipboardManager
import android.os.PersistableBundle
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
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
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
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
import androidx.activity.BackEventCompat
import androidx.activity.OnBackPressedCallback
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StringCodec

// open for KryfoActivity, the name the manifest gives the screen
open class MainActivity : FlutterFragmentActivity() {
    private val tools = ToolsBridge(this)
    // predictive back: the fragment's own callback only says "back" at the
    // end. this one hands dart the swipe as it goes, as FlutterActivity does,
    // and is on only while dart says it wants back (LockBack in
    // lock_layer.dart, which keeps it while locked)
    private var engine: FlutterEngine? = null
    private var backStarted = false
    private val backSwipe = object : OnBackPressedCallback(false) {
        override fun handleOnBackStarted(backEvent: BackEventCompat) {
            if (Build.VERSION.SDK_INT < 34) return
            val ch = engine?.backGestureChannel ?: return
            backStarted = true
            ch.startBackGesture(backEvent.toBackEvent())
        }

        override fun handleOnBackProgressed(backEvent: BackEventCompat) {
            if (!backStarted || Build.VERSION.SDK_INT < 34) return
            engine?.backGestureChannel?.updateBackGestureProgress(backEvent.toBackEvent())
        }

        override fun handleOnBackCancelled() {
            if (!backStarted) return
            backStarted = false
            engine?.backGestureChannel?.cancelBackGesture()
        }

        override fun handleOnBackPressed() {
            if (backStarted) {
                backStarted = false
                engine?.backGestureChannel?.commitBackGesture()
            } else {
                // a button, or an android without the swipe: plain back
                engine?.navigationChannel?.popRoute()
            }
        }
    }
    private var videos: VideoPlayers? = null
    private var pdfs: PdfPages? = null
    companion object {
        private const val NOTIF_PERM_REQUEST = 1001
        private const val PERM_PREFS = "halo_perm"
        private const val PERM_ASKED_KEY = "asked_post_notifications"
        // the label our copies carry: says nothing, and a later run knows it
        const val OUR_CLIP = "k1"
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

        // heard for the whole process, so it still hears while a picker,
        // the camera or a share sheet covers this screen
        private var leftWatch: LeftWatch? = null

        // home, recents or the screen going off. dart acts on it only while
        // a picker hold is open; the lifecycle covers the rest
        fun tellLeft() {
            val engine = FlutterEngineCache.getInstance().get(ENGINE_ID) ?: return
            BasicMessageChannel(engine.dartExecutor.binaryMessenger, "kryfo/window", StringCodec.INSTANCE)
                .send("left")
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

    // stopped and not shown since. android 10 and later start this screen
    // again before a new intent reaches it, so the lifecycle cannot say
    private var stoppedSinceResume = false

    override fun onNewIntent(intent: Intent) {
        // an intent from outside while something else covered this screen:
        // the person went somewhere first. dart hears it before the intent
        if (stoppedSinceResume) tellLeft()
        super.onNewIntent(intent)
        setIntent(intent)
        tools.offer(intent)
    }

    // the window and the user leaving lock too, not only the lifecycle
    private var awayChannel: BasicMessageChannel<String>? = null
    // screenshots and recordings of this window, as android tells them
    private val captures = CaptureWatch(this)
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
        SharePick.wait.paused()
    }

    override fun onStart() {
        super.onStart()
        captures.start()
    }

    override fun onStop() {
        super.onStop()
        captures.stop()
        stoppedSinceResume = true
        SaveDoc.coveredNow()
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
        stoppedSinceResume = false
        SharePick.wait.resumed()
        // a file opened or shared with another app is a decrypted copy in
        // cache/open or cache/share_plus. coming back here is the first sign
        // that app may be done with it, and a resume also follows every
        // start. each copy is given a while first, see clearOpenCopies.
        clearOpenCopies()
        // dart asks for notifications (askNotifications) once the lock is
        // down, so android's dialog never opens over the pin pad. one that
        // is up is left alone: starting it again only posts its
        // notification anew. a mode or language change still restarts it
        if (!HaloListenerService.running) resumeListener()
        schedulePeriodicJob()
    }

    // a refusal here is quiet: the next resume tries again
    private fun resumeListener() {
        try {
            startListenerService(plainFirst = true)
        } catch (e: Exception) {
            DebugLog.i(
                "halo-engine",
                "resume: listener not started: ${e.javaClass.simpleName}"
            )
        }
    }

    // from a screen in front a plain start, which has no deadline to miss
    // while dart holds the main thread
    private fun startListenerService(
        plainFirst: Boolean = QuietRestart.onScreen(QuietRestart.importance())
    ) {
        if (!DeliveryPrefs.staysOn(this)) return
        if (!KryfoState.hasData(this)) return
        HaloListenerService.start(this, plainFirst)
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

    // the window's flag and its recents picture, each step on its own
    private val shield = WindowShield(
        { secure ->
            if (secure) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        },
        if (Build.VERSION.SDK_INT >= 33) { picture -> setRecentsScreenshotEnabled(picture) } else null,
    )

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

    // a profile photo: the square at left, top, side of an upright jpeg,
    // drawn at edge x edge and written as a jpeg, quality stepping down
    // until it fits in most bytes. decoded pixels carry no metadata.
    private fun squareJpeg(
        bytes: ByteArray, left: Int, top: Int, side: Int, edge: Int, most: Int,
    ): ByteArray? {
        return try {
            val src = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
            val s = minOf(side, src.width - left, src.height - top)
            if (left < 0 || top < 0 || s <= 0) {
                src.recycle()
                return null
            }
            val out = Bitmap.createBitmap(edge, edge, Bitmap.Config.ARGB_8888)
            val canvas = android.graphics.Canvas(out)
            canvas.drawColor(android.graphics.Color.BLACK)
            val paint = android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG)
            canvas.drawBitmap(
                src,
                android.graphics.Rect(left, top, left + s, top + s),
                android.graphics.Rect(0, 0, edge, edge),
                paint,
            )
            src.recycle()
            var q = 82
            var made: ByteArray
            while (true) {
                val bos = ByteArrayOutputStream()
                out.compress(Bitmap.CompressFormat.JPEG, q, bos)
                made = bos.toByteArray()
                if (made.size <= most || q <= 50) break
                q -= 8
            }
            out.recycle()
            if (made.size <= most) made else null
        } catch (e: Throwable) {
            null
        }
    }

    // this screen was rebuilt from a saved state
    private var restored = false

    // dart's last screenshot and recents settings, kept so the next start's
    // first frame is covered before dart runs
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        restored = savedInstanceState != null
        // never throws: a start that cannot read them starts covered
        val kept = try {
            val k = getSharedPreferences("kryfo_window", MODE_PRIVATE)
            k.getBoolean("secure", false) to k.getBoolean("recents", false)
        } catch (_: Throwable) {
            true to true
        }
        shield.start(kept.first, kept.second)
        super.onCreate(savedInstanceState)
        // added after the fragment's, so it is asked first while it is on
        onBackPressedDispatcher.addCallback(this, backSwipe)
        underBars()
        AppIcon.describeTask(this)
        windowSeen = WindowWatch(this).also {
            it.gone = { tellAway() }
            addContentView(it, ViewGroup.LayoutParams(0, 0))
        }
        ActivityCompat.setPermissionCompatDelegate(promptSeen)
        if (leftWatch == null) {
            val filter = IntentFilter().apply {
                @Suppress("DEPRECATION")
                addAction(Intent.ACTION_CLOSE_SYSTEM_DIALOGS)
                addAction(Intent.ACTION_SCREEN_OFF)
                // a process android parks gets only the last of off and on
                addAction(Intent.ACTION_SCREEN_ON)
            }
            // exported: some launchers send the home broadcast as themselves,
            // and one from anywhere else can only bring the lock up
            leftWatch = LeftWatch().also {
                ContextCompat.registerReceiver(applicationContext, it, filter, ContextCompat.RECEIVER_EXPORTED)
            }
        }
    }

    // drawn under transparent bars, as android 15 and later do by
    // themselves. after super, which tints the status bar. android 9 and
    // older keep the app above a navigation bar that shows the window behind
    private fun underBars() {
        if (Build.VERSION.SDK_INT >= 35) return
        val clear = SystemBarStyle.auto(Color.TRANSPARENT, Color.TRANSPARENT)
        val nav = if (Build.VERSION.SDK_INT >= 29) clear else SystemBarStyle.dark(Color.TRANSPARENT)
        enableEdgeToEdge(clear, nav)
    }

    // flag_secure on the window is not enough on every phone: flutter draws
    // into a surfaceview with its own secure bit, so the surface is told
    // directly
    // each step on its own: one refused never stops the others. true when
    // every step went through
    private fun setSecureWindow(on: Boolean): Boolean {
        val held = shield.hold(on)
        quietly { DebugLog.i("kryfo", "setSecure on=$on") }
        val kept = quietly { getSharedPreferences("kryfo_window", MODE_PRIVATE).edit().putBoolean("secure", on).apply() }
        val surface = quietly { findSurface(window.decorView)?.setSecure(on) }
        // no surface recreate on the way off, it flashes the window. one ui
        // may keep the bit until the next start
        return held && kept && surface
    }

    private fun setRecentsHidden(on: Boolean): Boolean {
        val hidden = shield.hide(on)
        val kept = quietly { getSharedPreferences("kryfo_window", MODE_PRIVATE).edit().putBoolean("recents", on).apply() }
        return hidden && kept
    }

    // true when the step ran
    private inline fun quietly(step: () -> Unit): Boolean = try {
        step()
        true
    } catch (_: Throwable) {
        false
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
        pdfs?.releaseAll()
        pdfs = null
        videos = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // hold on to it so the next activity attaches to this same engine
        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
        engine = flutterEngine
        // dart says when it wants back, with every setFrameworkHandlesBack
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kryfo/back")
            .setMethodCallHandler { call, result ->
                if (call.method == "wants") {
                    val on = call.arguments as? Boolean ?: false
                    backSwipe.isEnabled = on
                    if (!on) backStarted = false
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        awayChannel = BasicMessageChannel(flutterEngine.dartExecutor.binaryMessenger, "kryfo/window", StringCodec.INSTANCE)
        captures.channel = BasicMessageChannel(flutterEngine.dartExecutor.binaryMessenger, "kryfo/capture", StringCodec.INSTANCE)
        tools.attach(MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ToolsBridge.CHANNEL))
        // a share is offered once. a screen rebuilt after the process went,
        // or opened again from recents, still carries the old one
        if (!restored && (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) == 0) {
            tools.offer(intent)
        }
        videos = VideoPlayers(flutterEngine.renderer).also { v ->
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kryfo/video")
                .setMethodCallHandler { call, result -> v.handle(call, result) }
        }
        pdfs = PdfPages().also { d ->
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kryfo/pdf")
                .setMethodCallHandler { call, result -> d.handle(call, result) }
        }
        PinKey.attach(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "halo/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isMiui" -> result.success(isMiuiDevice())
                    // the android version too, for the line about its own
                    // way to hide apps (private space, 15 and later)
                    "phoneMaker" -> result.success(
                        mapOf(
                            "manufacturer" to Build.MANUFACTURER,
                            "brand" to Build.BRAND,
                            "sdk" to Build.VERSION.SDK_INT.toString(),
                        )
                    )
                    "photoPickerReady" -> result.success(PhotoPicker.ready(this))
                    "installSource" -> result.success(installSource())
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
                    // wall-clock time this phone was switched on. a gap in
                    // the app's heartbeat that spans it was the phone being
                    // off, not the app being killed.
                    "bootedAtMs" -> result.success(
                        System.currentTimeMillis() - android.os.SystemClock.elapsedRealtime()
                    )
                    // the pin key (PinKey.kt). each call waits on its own
                    // thread, never behind the finger key's work
                    "pinKeyInfo" -> Thread {
                        val r = PinKey.info()
                        runOnUiThread { result.success(r) }
                    }.start()
                    "pinKeyMake" -> Thread {
                        val r = PinKey.make()
                        runOnUiThread { result.success(r) }
                    }.start()
                    "pinKeyMac" -> {
                        val x = call.argument<String>("x")
                        Thread {
                            val r = PinKey.mac(x)
                            runOnUiThread { result.success(r) }
                        }.start()
                    }
                    "pinKeyKcv" -> Thread {
                        val r = PinKey.kcv()
                        runOnUiThread { result.success(r) }
                    }.start()
                    "pinKeyDrop" -> Thread {
                        PinKey.drop()
                        runOnUiThread { result.success(true) }
                    }.start()
                    // fingerprint unlock on a key a new finger invalidates
                    "bioReady" -> result.success(BioKey.ready())
                    // the keystore may pause between tries: off the main thread
                    "bioState" -> Thread {
                        val s = BioKey.state()
                        runOnUiThread { result.success(s) }
                    }.start()
                    "bioSeal" -> {
                        val opens = call.argument<String>("opens")
                        if (opens.isNullOrEmpty()) {
                            result.success(null)
                        } else {
                            BioKey.work.execute {
                                val s = BioKey.seal(opens)
                                runOnUiThread { result.success(s) }
                            }
                        }
                    }
                    "bioDisable" -> {
                        BioKey.work.execute {
                            BioKey.delete()
                            runOnUiThread { result.success(true) }
                        }
                    }
                    "bioUnlock" -> {
                        val title = call.argument<String>("title") ?: "kryfo"
                        val cancel = call.argument<String>("cancel") ?: "Cancel"
                        val seal = call.argument<String>("seal") ?: ""
                        BioKey.unlock(this, title, cancel, seal) { r, opens, again ->
                            result.success(mapOf("r" to r, "p" to opens, "s" to again))
                        }
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
                                HaloListenerService.stop(applicationContext)
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
                        result.success(openNotificationSettings(call.argument<String>("channel")))
                    }
                    "openWifiSettings" -> {
                        result.success(openWifiSettings())
                    }
                    "openAutostartSettings" -> {
                        result.success(openAutostartSettings(call.argument<String>("brand")))
                    }
                    "setSecure" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        // the engine outlives the window, so this can be
                        // called with nothing attached
                        if (WindowShield.refusedOn(on) { setSecureWindow(it) }) {
                            result.error("refused", null, null)
                        } else {
                            result.success(null)
                        }
                    }
                    "setRecentsHidden" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        if (WindowShield.refusedOn(on) { setRecentsHidden(it) }) {
                            result.error("refused", null, null)
                        } else {
                            result.success(null)
                        }
                    }
                    // the wipe: what the settings "clear storage" button does,
                    // every file and preference gone in one synchronous call
                    // and the process force-stopped. deletes from dart race
                    // the preference writes still queued for disk.
                    "wipe" -> {
                        // the share menu's chats go first: the system keeps them
                        ShareTargets.clear(this)
                        // the pin key before anything: what it sealed never
                        // opens again, whatever the clear leaves. a keystore
                        // that hangs gets half a second, never the clear
                        // itself, which takes the key with the rest
                        PinKey.dropWithin(500)
                        // then the sticky listener: if the clear is
                        // refused and dart exits, nothing brings the app back
                        try {
                            HaloListenerService.stop(applicationContext)
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
                        if (ok) {
                            result.success(true)
                        } else {
                            // refused: the keystore and the data folder by
                            // hand, off the main thread
                            Thread {
                                try {
                                    WipeFallback.run(applicationContext)
                                } catch (e: Exception) {
                                }
                                runOnUiThread { result.success(false) }
                            }.start()
                        }
                    }
                    // the home screen's icon and name. android leaves the
                    // open screen up (DONT_KILL_APP), so kryfo closes and
                    // opens again itself, through the entry now on: what
                    // the shade and recents held named the old one
                    "appIconSet" -> {
                        val ok = AppIcon.set(this, call.argument<String>("icon"))
                        result.success(ok)
                        if (ok) ReopenActivity.start(this)
                    }
                    // a new process: a call stuck in a plugin's thread holds
                    // every call after it until this one is gone
                    "reopen" -> {
                        result.success(null)
                        ReopenActivity.start(this)
                    }
                    // a copy the keyboard's history and the android 13 preview
                    // treat as sensitive: ids, codes, addresses
                    "copySensitive" -> {
                        val text = call.argument<String>("text") ?: ""
                        val cm = applicationContext
                            .getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        val clip = ClipData.newPlainText(OUR_CLIP, text)
                        clip.description.extras = PersistableBundle().apply {
                            putBoolean("android.content.extra.IS_SENSITIVE", true)
                        }
                        cm.setPrimaryClip(clip)
                        result.success(true)
                    }
                    // our copy taken off the clipboard while it is still
                    // ours. from the background android hides the clipboard:
                    // [force] takes it off then too, [any] whatever it holds
                    "clearClip" -> {
                        val text = call.argument<String>("text") ?: ""
                        val force = call.argument<Boolean>("force") == true
                        val any = call.argument<Boolean>("any") == true
                        val cm = applicationContext
                            .getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        val now = try { cm.primaryClip } catch (_: Exception) { null }
                        val mine = now != null && now.itemCount > 0 &&
                            now.getItemAt(0).text?.toString() == text
                        val drop = any || mine || (now == null && force)
                        if (drop) {
                            try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                    cm.clearPrimaryClip()
                                } else {
                                    cm.setPrimaryClip(ClipData.newPlainText("", ""))
                                }
                            } catch (_: Exception) {}
                        }
                        result.success(drop)
                    }
                    // a clip of ours from an earlier run, known by its
                    // label: the app is in front, so it reads
                    "clearOurClip" -> {
                        val cm = applicationContext
                            .getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        val label = try {
                            cm.primaryClipDescription?.label?.toString()
                        } catch (_: Exception) { null }
                        val ours = label == OUR_CLIP
                        if (ours) {
                            try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                    cm.clearPrimaryClip()
                                } else {
                                    cm.setPrimaryClip(ClipData.newPlainText("", ""))
                                }
                            } catch (_: Exception) {}
                        }
                        result.success(ours)
                    }
                    // a camera shot at the sensor's own size and quality,
                    // brought to what a gallery pick gets: 1280 on the long
                    // edge, jpeg 70. decoded pixels carry no metadata.
                    "shrinkJpeg" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val maxEdge = call.argument<Int>("maxEdge") ?: 1280
                        val quality = call.argument<Int>("quality") ?: 70
                        // a decode of a big frame takes long enough to freeze the ui
                        Thread {
                            val out = if (bytes == null) null else shrinkJpeg(bytes, maxEdge, quality)
                            runOnUiThread { result.success(out) }
                        }.start()
                    }
                    "squareJpeg" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val left = call.argument<Int>("left") ?: 0
                        val top = call.argument<Int>("top") ?: 0
                        val side = call.argument<Int>("side") ?: 0
                        val edge = call.argument<Int>("edge") ?: 512
                        val most = call.argument<Int>("most") ?: (96 * 1024)
                        Thread {
                            val out = if (bytes == null) null
                                else squareJpeg(bytes, left, top, side, edge, most)
                            runOnUiThread { result.success(out) }
                        }.start()
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
                        val mime = call.argument<String>("mime")
                        val key = call.argument<ByteArray>("key")
                        if (path == null) result.success(false) else openFile(path, name, mime, key, result)
                    }
                    "shareFile" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.success(SharePick.FAILED)
                        } else {
                            shareFile(
                                path,
                                call.argument<String>("name"),
                                call.argument<String>("text"),
                                call.argument<String>("subject"),
                                call.argument<Boolean>("backup") == true,
                                call.argument<Boolean>("quiet") == true,
                                call.argument<ByteArray>("key"),
                                result
                            )
                        }
                    }
                    "videoInfo" -> {
                        val path = call.argument<String>("path")
                        val maxEdge = call.argument<Int>("maxEdge") ?: 640
                        val key = call.argument<ByteArray>("key")
                        if (path == null) result.success(null) else videoInfo(path, maxEdge, key, result)
                    }
                    "saveDocument" -> {
                        val path = call.argument<String>("path")
                        val name = call.argument<String>("name") ?: "kryfo-backup.kryfo"
                        if (path == null) {
                            result.success(mapOf("state" to SaveDoc.FAILED))
                        } else {
                            saveDocument(
                                path,
                                name,
                                call.argument<Boolean>("backup") == true,
                                call.argument<ByteArray>("key"),
                                result,
                            )
                        }
                    }
                    "saveDocumentState" -> result.success(SaveDoc.state())
                    "saveDocumentCancel" ->
                        result.success(SaveDoc.cancel(call.argument<Boolean>("drop") == true))
                    else -> result.notImplemented()
                }
            }
        // last, once halo/platform answers for this screen
        WindowShield.tellAttached { awayChannel?.send(it) }
    }

    // "open with" and share. another app cannot read our files, and must
    // not be able to: the file is copied to cache/open/, cache/share/ or
    // cache/share_q/, folders the provider serves, and the uri is granted to the one app
    // that gets the intent. some apps read theirs only after this one is
    // back, or keep reading in the background, so a copy is given a while
    // first and shredded once it is older, by a job that comes back while
    // one is young. a lock unlinks an open copy, and one shared from a
    // hidden chat or the decoy (dart's lockingUp).
    private fun clearOpenCopies() {
        Thread {
            if (Shred.handed(cacheDir)) JobSetup.scheduleCopySweep(this)
        }.start()
    }

    private fun mimeOf(f: File): String {
        val ext = f.extension.lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
            ?: when (ext) {
                "mov" -> "video/quicktime"
                "mkv" -> "video/x-matroska"
                "m4v" -> "video/mp4"
                "3g2" -> "video/3gpp2"
                "opus" -> "audio/ogg"
                else -> "application/octet-stream"
            }
    }

    // [src] copied into a folder of its own under cache/[into], so a
    // younger copy of the same name that an app may still be reading is
    // never written over. a copy cut short is shredded, and null comes back.
    // a backup is ciphertext with a rule of its own (Shred.BACKUP_OUT): the
    // last one goes when the next goes out
    // [key]: [src] is sealed at rest, and the copy is its plaintext
    private fun handOut(src: File, name: String?, into: String, key: ByteArray? = null): File? {
        val top = File(cacheDir, into)
        val backup = into == Shred.BACKUP_OUT
        if (backup) {
            Shred.dropBackups(cacheDir, true)
        } else {
            Shred.aged(top, System.currentTimeMillis() - Shred.GRACE_MS)
        }
        val rnd = ByteArray(8).also { java.security.SecureRandom().nextBytes(it) }
            .joinToString("") { "%02x".format(it) }
        val dir = File(top, rnd)
        val dst = File(dir, Shred.leaf(name ?: src.name))
        return try {
            dir.mkdirs()
            Sealed.open(src.path, key).use { i -> dst.outputStream().use { o -> i.copyTo(o) } }
            if (!backup) JobSetup.scheduleCopySweep(this)
            dst
        } catch (e: Exception) {
            Shred.tree(dir)
            null
        }
    }

    // "refused" for an app installer: dart offers a save instead
    private fun openFile(
        path: String,
        name: String?,
        mime: String?,
        key: ByteArray?,
        result: MethodChannel.Result
    ) {
        Thread {
            val type = mime ?: mimeOf(File(name ?: path))
            if (key == null && Installer.refused(File(path), name, type)) {
                runOnUiThread { result.success("refused") }
                return@Thread
            }
            val dst = handOut(File(path), name, "open", key)
            key?.fill(0)
            if (dst == null) {
                runOnUiThread { result.success(false) }
                return@Thread
            }
            // a sealed one is looked into as its copy
            if (key != null && Installer.refused(dst, name, type)) {
                Shred.tree(dst.parentFile!!)
                runOnUiThread { result.success("refused") }
                return@Thread
            }
            var started = false
            try {
                val uri = androidx.core.content.FileProvider.getUriForFile(
                    this, "$packageName.open", dst
                )
                val view = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, type)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                runOnUiThread {
                    try {
                        startActivity(view)
                        result.success(true)
                    } catch (e: ActivityNotFoundException) {
                        // nothing on this phone opens that kind of file: no
                        // app was handed the copy
                        Thread { Shred.tree(dst.parentFile!!) }.start()
                        result.success(false)
                    } catch (e: Exception) {
                        Thread { Shred.tree(dst.parentFile!!) }.start()
                        result.success(false)
                    }
                }
                started = true
            } catch (e: Exception) {
                // fall through
            }
            if (!started) {
                Shred.tree(dst.parentFile!!)
                runOnUiThread { result.success(false) }
            }
        }.start()
    }

    // the share sheet with a copy of ours, not the share plugin's: that one
    // drops its folder whole, unzeroed, at every next share, also while an
    // app may still be reading it
    private fun shareFile(
        path: String,
        name: String?,
        text: String?,
        subject: String?,
        backup: Boolean,
        quiet: Boolean,
        key: ByteArray?,
        result: MethodChannel.Result
    ) {
        Thread {
            val kind = mimeOf(File(name ?: path))
            if (!backup && key == null && Installer.refused(File(path), name, kind)) {
                runOnUiThread { result.success(SharePick.FAILED) }
                return@Thread
            }
            val dst = handOut(File(path), name, Shred.shareInto(backup, quiet), key)
            key?.fill(0)
            if (dst == null) {
                runOnUiThread { result.success(SharePick.FAILED) }
                return@Thread
            }
            if (!backup && key != null && Installer.refused(dst, name, kind)) {
                Shred.tree(dst.parentFile!!)
                runOnUiThread { result.success(SharePick.FAILED) }
                return@Thread
            }
            var started = false
            try {
                val uri = androidx.core.content.FileProvider.getUriForFile(
                    this, "$packageName.open", dst
                )
                val send = Intent(Intent.ACTION_SEND).apply {
                    type = mimeOf(dst)
                    putExtra(Intent.EXTRA_STREAM, uri)
                    if (!text.isNullOrBlank()) putExtra(Intent.EXTRA_TEXT, text)
                    if (!subject.isNullOrBlank()) putExtra(Intent.EXTRA_SUBJECT, subject)
                    clipData = android.content.ClipData.newRawUri("", uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                runOnUiThread {
                    // a closed sheet leaves its copy to the sweep: a phone
                    // that never reports picks would lose a real share
                    if (!SharePick.start(this, send) { result.success(it) }) {
                        Thread { Shred.tree(dst.parentFile!!) }.start()
                        result.success(SharePick.FAILED)
                    }
                }
                started = true
            } catch (e: Exception) {
                // fall through
            }
            if (!started) {
                Shred.tree(dst.parentFile!!)
                runOnUiThread { result.success(SharePick.FAILED) }
            }
        }.start()
    }

    // one frame and the length of a video, for its bubble. the frame goes
    // back as bytes and is never written anywhere: a thumbnail on disk
    // would outlive a message that burned.
    private fun videoInfo(path: String, maxEdge: Int, key: ByteArray?, result: MethodChannel.Result) {
        Thread {
            var out: Map<String, Any?>? = null
            val r = MediaMetadataRetriever()
            try {
                if (key == null) r.setDataSource(path) else r.setDataSource(SealedReader(path, key).media())
                key?.fill(0)
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
                    // no frame: the shape still comes from the track header,
                    // so an upright clip is not drawn wide
                    val (w, h) = shownSize(
                        r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0,
                        r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0,
                        r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0,
                    )
                    out = mapOf("jpeg" to null, "ms" to ms, "w" to w, "h" to h)
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
    // channel: a backup can be a year of photos. the waiting call lives in
    // SaveDoc, so a screen rebuilt meanwhile still answers it
    private fun saveDocument(
        path: String,
        name: String,
        backup: Boolean,
        key: ByteArray?,
        result: MethodChannel.Result,
    ) {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, name)
            // a backup starts in the phone's own Download folder: a file made
            // from the dialog's Downloads view can list there as 0 B. the
            // extra is api 26, and startIn is null below it too
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                SaveDoc.startIn(backup)?.let {
                    putExtra(android.provider.DocumentsContract.EXTRA_INITIAL_URI, Uri.parse(it))
                }
            }
        }
        val p = SaveDoc.begin(path, key) { result.success(it) }
        if (p == null) {
            result.success(mapOf("state" to SaveDoc.FAILED))
            return
        }
        try {
            startActivityForResult(intent, p.code)
        } catch (e: Exception) {
            // no save dialog on this phone: the share sheet instead
            p.reply(SaveDoc.CANCELLED)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (tools.onActivityResult(requestCode, resultCode, data)) return
        if (!SaveDoc.isCode(requestCode)) return
        val uri = data?.data
        val p = SaveDoc.take(requestCode)
        if (p == null) {
            // nobody waits for this dialog any more: an empty file it made
            // would only puzzle someone
            if (resultCode == RESULT_OK && uri != null) {
                Thread {
                    val size = try { sizeOf(uri) } catch (e: Exception) { null }
                    if (SaveDoc.mayDrop(size, opened = false)) dropDocument(uri)
                }.start()
            }
            return
        }
        if (resultCode != RESULT_OK || uri == null) {
            p.reply(SaveDoc.backedOut())
            return
        }
        Thread {
            val before = try { sizeOf(uri) } catch (e: Exception) { null }
            val state = SaveDoc.copyInto(
                File(p.path),
                before,
                key = p.key,
                open = { contentResolver.openOutputStream(uri, it) },
                sizeThere = { sizeOf(uri) },
                readBack = { contentResolver.openInputStream(uri) },
                drop = { dropDocument(uri) },
            )
            p.key?.fill(0)
            val kept = state == SaveDoc.SAVED || state == SaveDoc.UNCHECKED
            val where = if (kept) placeOf(uri) else null
            runOnUiThread { p.reply(state, where) }
        }.start()
    }

    private fun sizeOf(uri: Uri): Long? =
        contentResolver.query(uri, arrayOf(android.provider.OpenableColumns.SIZE), null, null, null)
            ?.use { c ->
                if (c.moveToFirst() && !c.isNull(0)) c.getLong(0) else null
            }

    private fun dropDocument(uri: Uri) {
        try {
            android.provider.DocumentsContract.deleteDocument(contentResolver, uri)
        } catch (e: Exception) {
            // the provider would not delete it: it stays where it is
        }
    }

    private fun placeOf(uri: Uri): String? = try {
        val authority = uri.authority
        val id = try {
            android.provider.DocumentsContract.getDocumentId(uri)
        } catch (e: Exception) {
            null
        }
        val label = authority?.let {
            packageManager.resolveContentProvider(it, 0)
                ?.applicationInfo?.loadLabel(packageManager)?.toString()
        }
        SaveDoc.placeOf(authority, id, label)
    } catch (e: Exception) {
        null
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
            val uri = contentResolver.insert(collection, SavePlace.newRow(this, name, mime))
                ?: return false
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) } ?: return false
            contentResolver.update(uri, SavePlace.doneRow(), null, null)
            true
        } catch (e: Exception) {
            false
        }
    }

    // who installed us and who keeps us updated, for the update notice: an
    // f-droid copy is the same bytes as ours, so only the installer tells
    private fun installSource(): Map<String, String?> {
        var installer: String? = null
        var initiator: String? = null
        var owner: String? = null
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val s = packageManager.getInstallSourceInfo(packageName)
                installer = s.installingPackageName
                initiator = s.initiatingPackageName
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    owner = s.updateOwnerPackageName
                }
            } else {
                // known gap: below android 11, a client's legacy install
                // (droid-ify's, say) names the system installer, so that
                // copy gets the notice too
                @Suppress("DEPRECATION")
                installer = packageManager.getInstallerPackageName(packageName)
            }
        } catch (e: Exception) {
            // unknown: the notice decides as for a sideloaded copy
        }
        val version = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName, PackageManager.PackageInfoFlags.of(0)
                ).versionName
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0).versionName
            }
        } catch (e: Exception) {
            null
        }
        return mapOf(
            "installer" to installer,
            "initiator" to initiator,
            "owner" to owner,
            "version" to version,
        )
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
            val code = ExitWord.of(e.reason, e.description)
            mapOf(
                "at" to e.timestamp,
                "reason" to e.reason,
                "code" to code,
                "pssKb" to e.pss,
            )
        } catch (e: Exception) {
            null
        }
    }

    // android's wi-fi page, where a network that wants a sign-in offers it
    private fun openWifiSettings(): Boolean {
        return try {
            startActivity(Intent(Settings.ACTION_WIFI_SETTINGS))
            true
        } catch (e: Exception) {
            false
        }
    }

    // android's own notification page for kryfo. the permission dialog is
    // gone for good once the answer is final, so this is the only way back.
    // with [channel], that channel's page: its sound and vibration are
    // android's to change once it is made, not the app's
    private fun openNotificationSettings(channel: String? = null): Boolean {
        if (channel != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(android.app.NotificationManager::class.java)
            if (nm?.getNotificationChannel(channel) != null) {
                try {
                    startActivity(
                        Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            putExtra(Settings.EXTRA_CHANNEL_ID, channel)
                        }
                    )
                    return true
                } catch (e: Exception) {
                    // the app's page below has every channel on it
                }
            }
        }
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

    // true when some settings page opened: the maker's page, else the app's
    // own details page, false when both fail
    private fun openAutostartSettings(brand: String?): Boolean {
        // on xiaomi the app's details page is apps > manage apps > Kryfo, with
        // autostart and battery saver on it: both of the guide's first steps
        if (brand == "xiaomi" && openAppDetails()) return true
        // each maker's own page, newest first; only the phone's own maker
        // has any of them. the list is dontkillmyapp.com's
        val pages = listOf(
            "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.hihonor.systemmanager" to "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
            "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
            "com.oneplus.security" to "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
            "com.samsung.android.lool" to "com.samsung.android.sm.battery.ui.BatteryActivity",
        )
        for ((pkg, cls) in pages) {
            try {
                startActivity(Intent().apply { setClassName(pkg, cls) })
                return true
            } catch (e: Exception) {
                // not this phone's, or not exported: the next
            }
        }
        return openAppDetails()
    }

    private fun openAppDetails(): Boolean = try {
        startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
        )
        true
    } catch (e: Exception) {
        false
    }
}

// the person left the app outright, wherever they were in it
private class LeftWatch : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        @Suppress("DEPRECATION")
        if (intent.action == Intent.ACTION_CLOSE_SYSTEM_DIALOGS) {
            // a screenshot or the power menu keep the person where they are.
            // an extra that will not unpack counts as a leave
            val reason = try {
                intent.getStringExtra("reason")
            } catch (e: Exception) {
                null
            }
            when (reason) {
                "screenshot", "globalactions" -> return
            }
        }
        MainActivity.tellLeft()
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
