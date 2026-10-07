package app.kryfo

import android.app.Activity
import android.app.Application
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Process
import java.io.File

// the app's first screen again, in a new process. this screen runs in a
// process of its own, so it outlives the one it ends: the app's process is
// killed, its first screen started in a fresh one, and this process goes too
class ReopenActivity : Activity() {
    companion object {
        private const val PID = "pid"
        private const val PROCESS = ":reopen"

        // from the app's screen while it is in front: android lets a
        // screen in front start another
        fun start(from: Activity) {
            val me = Process.myPid()
            try {
                from.startActivity(
                    Intent(from, ReopenActivity::class.java)
                        .putExtra(PID, me)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            } catch (e: Exception) {
                Process.killProcess(me)
            }
            // closed even if the new process never comes up
            Handler(Looper.getMainLooper()).postDelayed({ Process.killProcess(me) }, 3000)
        }

        // the application skips its own start in this process
        fun inOwnProcess(): Boolean {
            val name = if (Build.VERSION.SDK_INT >= 28) {
                Application.getProcessName()
            } else {
                try {
                    File("/proc/self/cmdline").readText().substringBefore('\u0000')
                } catch (e: Exception) {
                    ""
                }
            }
            return name.endsWith(PROCESS)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val pid = intent.getIntExtra(PID, -1)
        if (pid > 0 && pid != Process.myPid()) Process.killProcess(pid)
        // a launch into a process that is still dying fails over to a new one
        try {
            startActivity(
                Intent.makeRestartActivityTask(ComponentName(this, MainActivity::class.java))
            )
        } catch (e: Exception) {
        }
        finish()
        Runtime.getRuntime().exit(0)
    }
}
