// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.content.Context
import android.util.Log
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailabilityLight
import com.google.android.gms.tasks.Task
import com.google.firebase.FirebaseApp
import com.google.firebase.installations.FirebaseInstallations
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
    // google push was left and google still holds this install's token or
    // installation: deleted again on each start and each return to the app
    private const val KEY_OWED = "delete_owed"

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isOn(c: Context): Boolean = prefs(c).getBoolean(KEY_ON, false)

    // play services on the phone: without them there is no fcm. one that is
    // updating itself, or wants an update, is still there and pushes again
    // once it is done; only missing, disabled or broken ones are not
    fun availableFrom(code: Int): Boolean = when (code) {
        ConnectionResult.SERVICE_MISSING,
        ConnectionResult.SERVICE_DISABLED,
        ConnectionResult.SERVICE_INVALID -> false
        else -> true
    }

    fun available(c: Context): Boolean = try {
        availableFrom(GoogleApiAvailabilityLight.getInstance().isGooglePlayServicesAvailable(c))
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

    // the token and the firebase installation deleted, so google can wake
    // nothing of this install and keeps no id of it, and no new one made
    // until google push is picked again. a delete that fails is owed, and
    // tried again on each start and each return to the app until it goes
    fun stop(c: Context, done: () -> Unit) {
        val wasOn = isOn(c)
        val owed = prefs(c).getBoolean(KEY_OWED, false)
        prefs(c).edit().putBoolean(KEY_ON, false).apply()
        if (!wasOn && !owed && FirebaseApp.getApps(c).isEmpty()) {
            done()
            return
        }
        prefs(c).edit().putBoolean(KEY_OWED, true).apply()
        deleteAll(c) { ok ->
            if (ok && !isOn(c)) prefs(c).edit().putBoolean(KEY_OWED, false).apply()
            done()
        }
    }

    fun deleteOwed(c: Context): Boolean = prefs(c).getBoolean(KEY_OWED, false)

    // a delete owed from before goes again, unless google push was picked
    // meanwhile
    fun settle(c: Context, done: () -> Unit = {}) {
        if (!deleteOwed(c) || isOn(c)) {
            done()
            return
        }
        deleteAll(c) { ok ->
            if (ok && !isOn(c)) prefs(c).edit().putBoolean(KEY_OWED, false).apply()
            done()
        }
    }

    // the deletes, for the tests a stand-in that can fail
    var deleter: (Context, (Boolean) -> Unit) -> Unit = { c, done -> firebaseDelete(c, done) }

    private fun deleteAll(c: Context, done: (Boolean) -> Unit) = deleter(c, done)

    private fun firebaseDelete(c: Context, done: (Boolean) -> Unit) {
        if (app(c) == null) {
            done(false)
            return
        }
        try {
            val m = FirebaseMessaging.getInstance()
            m.isAutoInitEnabled = false
            m.deleteToken().addOnCompleteListener { _: Task<Void> ->
                // the installation's delete takes its tokens with it too, so
                // it is the one that has to go through
                FirebaseInstallations.getInstance().delete().addOnCompleteListener { i: Task<Void> ->
                    done(i.isSuccessful)
                }
            }
        } catch (e: Exception) {
            done(false)
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
            "settle" -> settle(c) { result.success(true) }
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
