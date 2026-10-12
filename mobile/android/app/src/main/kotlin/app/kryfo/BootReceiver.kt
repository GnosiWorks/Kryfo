package app.kryfo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        // after a restart, and after an update, which stops the service too
        val action = intent?.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) return
        if (!KryfoState.hasData(context)) return
        JobSetup.schedule(context)
        if (!DeliveryPrefs.staysOn(context)) return
        // a refusal is quiet: opening the app starts it again
        try {
            HaloListenerService.start(context)
        } catch (e: Exception) {
            Log.i("halo-engine", "boot: listener not started: ${e.javaClass.simpleName}")
        }
    }
}
