// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.security.SecureRandom

// the helper app mode: unifiedpush spoken by hand, a handful of broadcasts
// to a distributor such as ntfy. no connector library, from 3.0 it pulls in
// google's tink for web push decryption and a knock has nothing to decrypt.
// sixteen registrations, each with its own token, whatever the contact
// count (helper_slots.dart). a push is only a knock: its bytes are dropped
// unread and it schedules the same check-in the fifteen-minute job runs,
// and only with a token this phone made. anyone can send this receiver a
// broadcast, so that check and KnockGate guard the battery.
object HelperPush {
    const val ACTION_REGISTER = "org.unifiedpush.android.distributor.REGISTER"
    const val ACTION_UNREGISTER = "org.unifiedpush.android.distributor.UNREGISTER"
    const val ACTION_NEW_ENDPOINT = "org.unifiedpush.android.connector.NEW_ENDPOINT"
    const val ACTION_FAILED = "org.unifiedpush.android.connector.REGISTRATION_FAILED"
    const val ACTION_UNREGISTERED = "org.unifiedpush.android.connector.UNREGISTERED"
    const val ACTION_MESSAGE = "org.unifiedpush.android.connector.MESSAGE"
    const val CHANNEL = "halo/helper"

    private const val PREFS = "helper_push"
    private const val KEY_DISTRIBUTOR = "distributor"
    private const val TOKEN_PREFIX = "token."
    private const val ENDPOINT_PREFIX = "endpoint."

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // every app on the phone that answers the register broadcast
    fun distributors(c: Context): List<Map<String, String>> {
        val pm = c.packageManager
        val found = pm.queryBroadcastReceivers(Intent(ACTION_REGISTER), 0)
        return found.mapNotNull { it.activityInfo?.packageName }
            .distinct()
            .filter { it != c.packageName }
            .map { pkg ->
                val label = try {
                    pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
                } catch (e: Exception) {
                    pkg
                }
                mapOf("package" to pkg, "name" to label)
            }
    }

    fun distributor(c: Context): String? = prefs(c).getString(KEY_DISTRIBUTOR, null)

    fun installed(c: Context, pkg: String): Boolean = try {
        c.packageManager.getApplicationInfo(pkg, 0)
        true
    } catch (e: Exception) {
        false
    }

    private fun newToken(): String {
        val b = ByteArray(24)
        SecureRandom().nextBytes(b)
        return b.joinToString("") { "%02x".format(it) }
    }

    // instance is kryfo's own name for one address. the token is what the
    // distributor knows it by, and what comes back on every broadcast.
    fun register(c: Context, pkg: String, instance: String): Boolean {
        if (!installed(c, pkg)) return false
        val p = prefs(c)
        val key = TOKEN_PREFIX + instance
        val token = p.getString(key, null) ?: newToken().also {
            p.edit().putString(key, it).apply()
        }
        p.edit().putString(KEY_DISTRIBUTOR, pkg).apply()
        val intent = Intent(ACTION_REGISTER).apply {
            setPackage(pkg)
            putExtra("token", token)
            // the older form names the app, the newer one proves it
            putExtra("application", c.packageName)
            putExtra(
                "pi",
                PendingIntent.getBroadcast(
                    c, 0, Intent().setPackage(c.packageName),
                    PendingIntent.FLAG_IMMUTABLE
                )
            )
        }
        return try {
            c.sendBroadcast(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    fun unregisterAll(c: Context) {
        val p = prefs(c)
        val pkg = p.getString(KEY_DISTRIBUTOR, null)
        val edit = p.edit()
        for ((k, v) in p.all) {
            if (k.startsWith(ENDPOINT_PREFIX)) {
                edit.remove(k)
                continue
            }
            if (!k.startsWith(TOKEN_PREFIX) || v !is String) continue
            if (pkg != null) {
                try {
                    c.sendBroadcast(Intent(ACTION_UNREGISTER).apply {
                        setPackage(pkg)
                        putExtra("token", v)
                    })
                } catch (e: Exception) {
                }
            }
            edit.remove(k)
        }
        edit.remove(KEY_DISTRIBUTOR).apply()
    }

    // one registration let go, for a slot that gets a new endpoint
    fun unregister(c: Context, instance: String) {
        val p = prefs(c)
        val token = p.getString(TOKEN_PREFIX + instance, null) ?: return
        val pkg = p.getString(KEY_DISTRIBUTOR, null)
        if (pkg != null) {
            try {
                c.sendBroadcast(Intent(ACTION_UNREGISTER).apply {
                    setPackage(pkg)
                    putExtra("token", token)
                })
            } catch (e: Exception) {
            }
        }
        p.edit().remove(TOKEN_PREFIX + instance).remove(ENDPOINT_PREFIX + instance).apply()
    }

    // https, or plain http to an onion: an ntfy of one's own behind tor
    fun endpointOK(e: String): Boolean {
        if (e.length > 512) return false
        if (e.startsWith("https://")) return true
        if (!e.startsWith("http://")) return false
        val host = e.removePrefix("http://").substringBefore('/').substringBefore('?').substringBefore(':')
        return host.endsWith(".onion")
    }

    fun instanceOf(c: Context, token: String?): String? {
        if (token.isNullOrEmpty()) return null
        for ((k, v) in prefs(c).all) {
            if (k.startsWith(TOKEN_PREFIX) && v == token) return k.removePrefix(TOKEN_PREFIX)
        }
        return null
    }

    fun forget(c: Context, instance: String) {
        prefs(c).edit().remove(TOKEN_PREFIX + instance).remove(ENDPOINT_PREFIX + instance).apply()
    }

    // an endpoint that came while dart was not listening is read from here
    fun keepEndpoint(c: Context, instance: String, endpoint: String) {
        prefs(c).edit().putString(ENDPOINT_PREFIX + instance, endpoint).apply()
    }

    // instance -> endpoint, for the registrations this phone still holds
    fun endpoints(c: Context): Map<String, String> {
        val all = prefs(c).all
        val out = mutableMapOf<String, String>()
        for ((k, v) in all) {
            if (!k.startsWith(ENDPOINT_PREFIX) || v !is String) continue
            val instance = k.removePrefix(ENDPOINT_PREFIX)
            if (all.containsKey(TOKEN_PREFIX + instance)) out[instance] = v
        }
        return out
    }

    fun tell(method: String, args: Map<String, Any?>) {
        val engine = FlutterEngineCache.getInstance().get(HaloApplication.ENGINE_ID) ?: return
        try {
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod(method, args)
        } catch (e: Exception) {
            Log.i("halo-engine", "helper: dart not reachable: ${e.javaClass.simpleName}")
        }
    }
}

class HelperPushReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        val instance = HelperPush.instanceOf(context, intent.getStringExtra("token")) ?: return
        when (action) {
            HelperPush.ACTION_NEW_ENDPOINT -> {
                val endpoint = intent.getStringExtra("endpoint") ?: return
                if (!HelperPush.endpointOK(endpoint)) return
                HelperPush.keepEndpoint(context, instance, endpoint)
                HelperPush.tell("endpoint", mapOf("instance" to instance, "endpoint" to endpoint))
            }
            HelperPush.ACTION_MESSAGE -> {
                // the body is never read. a job, not a call into dart: a
                // process this broadcast started has no dart listening yet,
                // and the job keeps it alive for the check-in
                val v = KnockGate.allow(context)
                when {
                    v.go -> {
                        Log.i("halo-engine", "helper: knock")
                        JobSetup.scheduleKnock(context)
                    }
                    v.waitMs > 0 -> {
                        Log.i("halo-engine", "helper: knock waits for the floor")
                        JobSetup.scheduleKnockLater(context, v.waitMs)
                    }
                    else -> Log.i("halo-engine", "helper: knock dropped, too many this hour")
                }
            }
            HelperPush.ACTION_UNREGISTERED -> {
                HelperPush.forget(context, instance)
                HelperPush.tell("unregistered", mapOf("instance" to instance))
            }
            HelperPush.ACTION_FAILED -> {
                HelperPush.tell(
                    "failed",
                    mapOf("instance" to instance, "reason" to intent.getStringExtra("reason"))
                )
            }
        }
    }
}
