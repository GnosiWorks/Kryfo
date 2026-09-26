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
// one registration per address, each with its own token, so the relay gets
// one endpoint per address and cannot tie a person's addresses together.
// a push is only a knock: its bytes are dropped unread and it starts the
// same check-in the fifteen-minute job runs, and only with a token this
// phone made. anyone can send this receiver a broadcast, so that check and
// the rate limit in dart guard the battery.
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

    fun instanceOf(c: Context, token: String?): String? {
        if (token.isNullOrEmpty()) return null
        for ((k, v) in prefs(c).all) {
            if (k.startsWith(TOKEN_PREFIX) && v == token) return k.removePrefix(TOKEN_PREFIX)
        }
        return null
    }

    fun forget(c: Context, instance: String) {
        prefs(c).edit().remove(TOKEN_PREFIX + instance).apply()
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
                if (!endpoint.startsWith("https://") || endpoint.length > 1024) return
                HelperPush.tell("endpoint", mapOf("instance" to instance, "endpoint" to endpoint))
            }
            HelperPush.ACTION_MESSAGE -> {
                // the body is never read
                Log.i("halo-engine", "helper: knock")
                HelperPush.tell("knock", mapOf("instance" to instance))
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
