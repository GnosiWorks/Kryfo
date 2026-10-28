// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.content.Context
import android.util.Log
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailabilityLight
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// google push, the play build only. firebase stays off until the person
// picks google push: no firebase app, no token, nothing said to google
// before that (the play manifest drops firebase's own start-up provider
// and turns auto init, analytics and delivery metrics off). picking it
// starts firebase and asks for the one token; leaving it deletes the token.
// dart seals the token once per slot for our gateway (google_push.dart),
// and a push is only a knock (KryfoMessagingService)
object GooglePush {
    const val CHANNEL = "halo/gpush"
    private const val PREFS = "google_push"
    private const val KEY_ON = "on"
    // pushes come, and how many android delivered below the high priority
    // they were sent with: the sign that it deprioritises kryfo
    private const val KEY_GOT = "got"
    private const val KEY_LOW = "low"

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isOn(c: Context): Boolean = prefs(c).getBoolean(KEY_ON, false)

    // play services there and working: without them there is no fcm
    fun available(c: Context): Boolean = try {
        GoogleApiAvailabilityLight.getInstance().isGooglePlayServicesAvailable(c) ==
            ConnectionResult.SUCCESS
    } catch (e: Exception) {
        false
    }

    // firebase from the play build's own values, made the first time it is
    // needed. null when the build carries none
    fun app(c: Context): FirebaseApp? {
        FirebaseApp.getApps(c).firstOrNull()?.let { return it }
        return try {
            FirebaseApp.initializeApp(c.applicationContext)
        } catch (e: Exception) {
            Log.i("halo-engine", "google: firebase not started: ${e.javaClass.simpleName}")
            null
        }
    }

    fun start(c: Context, done: (String?) -> Unit) {
        prefs(c).edit().putBoolean(KEY_ON, true).apply()
        token(c, done)
    }

    fun token(c: Context, done: (String?) -> Unit) {
        if (!isOn(c) || app(c) == null) {
            done(null)
            return
        }
        try {
            val m = FirebaseMessaging.getInstance()
            // keeps the token fresh while google push is on
            m.isAutoInitEnabled = true
            m.token.addOnCompleteListener { t ->
                done(if (t.isSuccessful) t.result else null)
            }
        } catch (e: Exception) {
            done(null)
        }
    }

    // the token deleted, so google can wake nothing of this install, and
    // no new one made until google push is picked again
    fun stop(c: Context, done: () -> Unit) {
        val wasOn = isOn(c)
        prefs(c).edit().putBoolean(KEY_ON, false).apply()
        if (!wasOn && FirebaseApp.getApps(c).isEmpty()) {
            done()
            return
        }
        if (app(c) == null) {
            done()
            return
        }
        try {
            val m = FirebaseMessaging.getInstance()
            m.isAutoInitEnabled = false
            m.deleteToken().addOnCompleteListener { done() }
        } catch (e: Exception) {
            done()
        }
    }

    fun received(c: Context, lowered: Boolean) {
        val p = prefs(c)
        val e = p.edit().putInt(KEY_GOT, p.getInt(KEY_GOT, 0) + 1)
        if (lowered) e.putInt(KEY_LOW, p.getInt(KEY_LOW, 0) + 1)
        e.apply()
    }

    fun stats(c: Context): Map<String, Int> =
        mapOf("got" to prefs(c).getInt(KEY_GOT, 0), "low" to prefs(c).getInt(KEY_LOW, 0))

    fun handle(c: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "available" -> result.success(available(c))
            "on" -> start(c) { result.success(it) }
            "token" -> token(c) { result.success(it) }
            "off" -> stop(c) { result.success(true) }
            "stats" -> result.success(stats(c))
            else -> result.notImplemented()
        }
    }

    // a new token: dart seals it again for every slot
    fun tell(method: String) {
        val engine = FlutterEngineCache.getInstance().get(HaloApplication.ENGINE_ID) ?: return
        try {
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod(method, null)
        } catch (e: Exception) {
            Log.i("halo-engine", "google: dart not reachable: ${e.javaClass.simpleName}")
        }
    }
}
