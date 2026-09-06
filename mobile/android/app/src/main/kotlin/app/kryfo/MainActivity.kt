package app.kryfo

import android.Manifest
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
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
        private const val PERIODIC_JOB_ID = 2001
        // the one engine we keep across activity teardown
        const val ENGINE_ID = "halo_engine"
    }

    // reuse the cached engine if we already have one. returning null on the
    // very first launch is deliberate: the activity then builds an engine the
    // normal way (attached to native properly), and configureFlutterEngine
    // below puts it in the cache for next time. this is the hook a
    // FlutterFragmentActivity actually honours.
    override fun getCachedEngineId(): String? {
        val cache = FlutterEngineCache.getInstance()
        val eng = cache.get(ENGINE_ID) ?: return null
        // the crash was FlutterView.onSizeChanged pushing viewport metrics into
        // an engine whose renderer had detached (window surface torn down on a
        // recents swipe, activity recreated before reattach). reusing that
        // engine here is what blew up. only claim the cached engine when its
        // renderer is actually displaying; otherwise return null so the
        // framework builds and cleanly attaches a fresh one for this window.
        // the background isolate + tor keep running on the cached engine
        // regardless - this only governs which engine drives THIS activity.
        return if (eng.renderer.isDisplayingFlutterUi) ENGINE_ID else null
    }

    // keep the engine when this screen goes away, so the dart isolate and the
    // nostr poll timer keep running in the background
    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onResume() {
        super.onResume()
        requestNotificationPermissionIfNeeded()
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

    private fun schedulePeriodicJob() {
        val scheduler = getSystemService(JobScheduler::class.java)
        if (scheduler.getPendingJob(PERIODIC_JOB_ID) != null) return
        val component = ComponentName(this, HaloPeriodicJobService::class.java)
        val jobInfo = JobInfo.Builder(PERIODIC_JOB_ID, component)
            .setPeriodic(15 * 60 * 1000L)
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            .setPersisted(true)
            .build()
        scheduler.schedule(jobInfo)
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                this, Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIF_PERM_REQUEST
                )
            }
        }
    }

    // flag_secure on the window is not enough on every phone: flutter draws
    // into a surfaceview whose own secure bit was latched when the flag went
    // on, and one ui keeps it after the flag comes off. clearing meant the
    // whole app stayed unscreenshottable until a restart. so the surface is
    // told directly, and on the way off it is recreated, which is the one
    // thing that reliably drops the bit.
    private var secureNow = false
    private fun setSecureWindow(on: Boolean) {
        android.util.Log.i("kryfo", "setSecure on=$on was=$secureNow")
        if (on) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
        val surface = findSurface(window.decorView)
        surface?.setSecure(on)
        if (!on && secureNow && surface != null) {
            surface.visibility = View.GONE
            surface.post { surface.visibility = View.VISIBLE }
        }
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
                    "openAutostartSettings" -> {
                        openAutostartSettings()
                        result.success(null)
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
                    else -> result.notImplemented()
                }
            }
    }

    private fun isMiuiDevice(): Boolean {
        val mfr = Build.MANUFACTURER.lowercase()
        return mfr == "xiaomi" || mfr == "redmi" || mfr == "poco"
    }

    private fun openAutostartSettings() {
        val miui = Intent().apply {
            setClassName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity"
            )
        }
        try {
            startActivity(miui)
        } catch (e: ActivityNotFoundException) {
            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(fallback)
        }
    }
}
