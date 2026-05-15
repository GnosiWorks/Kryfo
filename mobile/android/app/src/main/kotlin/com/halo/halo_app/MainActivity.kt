package com.halo.halo_app

import android.Manifest
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.content.ActivityNotFoundException
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val NOTIF_PERM_REQUEST = 1001
        private const val PERIODIC_JOB_ID = 2001
    }

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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "halo/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isMiui" -> result.success(isMiuiDevice())
                    "openAutostartSettings" -> {
                        openAutostartSettings()
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
