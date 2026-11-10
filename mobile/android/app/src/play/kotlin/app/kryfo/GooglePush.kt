// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.content.Context
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
    // since when, so a delete that can never go (play services removed) is
    // given up after a month instead of tried for ever
    private const val KEY_OWED_SINCE = "delete_owed_since"
    const val OWED_FOR_MS = 30L * 24 * 3600 * 1000

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

    // offered and picked only when play services work right now: one that
    // wants an update first could not hand out a token
    fun offerableFrom(code: Int): Boolean = code == ConnectionResult.SUCCESS

    private fun code(c: Context): Int? = try {
        GoogleApiAvailabilityLight.getInstance().isGooglePlayServicesAvailable(c)
    } catch (e: Exception) {
        null
    }

    fun available(c: Context): Boolean = code(c)?.let { availableFrom(it) } ?: false

    fun offerable(c: Context): Boolean = code(c)?.let { offerableFrom(it) } ?: false

    // whether an owed delete can go now, a stand-in in the tests
    var present: (Context) -> Boolean = { available(it) }

    // firebase from the play build's own values, made the first time it is
    // needed. null when the build carries none
    fun app(c: Context): FirebaseApp? {
        FirebaseApp.getApps(c).firstOrNull()?.let { return it }
        return try {
            FirebaseApp.initializeApp(c.applicationContext)
        } catch (e: Exception) {
            DebugLog.i("halo-engine", "google: firebase not started: ${e.javaClass.simpleName}")
            null
        }
    }

    // a delete running now, and what waits for it to end: a token asked for
    // meanwhile could be the one the delete then kills
    private var deleting = false
    // the token fetch, a stand-in in the tests
    var fetch: (Context, (String?) -> Unit) -> Unit = { c, done -> token(c, done) }
    private val afterDelete = mutableListOf<() -> Unit>()

    fun start(c: Context, done: (String?) -> Unit) {
        prefs(c).edit().putBoolean(KEY_ON, true).apply()
        if (deleting) afterDelete.add { fetch(c, done) } else fetch(c, done)
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
        owe(c)
        deleteAll(c) { ok ->
            if (ok) paid(c)
            done()
        }
    }

    private fun owe(c: Context) {
        val p = prefs(c)
        val e = p.edit().putBoolean(KEY_OWED, true)
        if (!p.getBoolean(KEY_OWED, false)) e.putLong(KEY_OWED_SINCE, System.currentTimeMillis())
        e.apply()
    }

    private fun paid(c: Context) {
        prefs(c).edit().putBoolean(KEY_OWED, false).remove(KEY_OWED_SINCE).apply()
    }

    fun deleteOwed(c: Context): Boolean = prefs(c).getBoolean(KEY_OWED, false)

    // a delete owed from before goes again, unless google push was picked
    // meanwhile, play services are not there to take it, or it has been owed
    // a month: firebase's own installation then lapses on google's side
    fun settle(c: Context, now: Long = System.currentTimeMillis(), done: () -> Unit = {}) {
        if (!deleteOwed(c) || isOn(c) || deleting) {
            done()
            return
        }
        val since = prefs(c).getLong(KEY_OWED_SINCE, now)
        if (now - since >= OWED_FOR_MS || now < since - OWED_FOR_MS) {
            paid(c)
            done()
            return
        }
        if (!present(c)) {
            done()
            return
        }
        deleteAll(c) { ok ->
            if (ok) paid(c)
            done()
        }
    }

    // the deletes, for the tests a stand-in that can fail or hang
    val firebaseDeleter: (Context, (Boolean) -> Unit) -> Unit = { c, done -> firebaseDelete(c, done) }
    var deleter: (Context, (Boolean) -> Unit) -> Unit = firebaseDeleter

    // one at a time. what waited for it goes once it ends; google push
    // picked again while it ran gets a fresh token, and dart seals it anew
    private fun deleteAll(c: Context, done: (Boolean) -> Unit) {
        deleting = true
        deleter(c) { ok ->
            deleting = false
            val waiting = afterDelete.toList()
            afterDelete.clear()
            done(ok)
            waiting.forEach { it() }
            if (waiting.isEmpty() && isOn(c)) tell("token")
        }
    }

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
            "available" -> result.success(offerable(c))
            "present" -> result.success(available(c))
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
            DebugLog.i("halo-engine", "google: dart not reachable: ${e.javaClass.simpleName}")
        }
    }
}
