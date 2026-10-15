// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import java.lang.ref.WeakReference

// whether a share sheet ended with an app picked. the sheet says so with a
// broadcast; backing out of it says nothing, so coming back here with no
// pick heard means nothing went
class PickWait(private val later: (Long, () -> Unit) -> Unit) {
    private class Open(val gen: Int, val done: (Boolean) -> Unit) {
        var away = false
    }

    private var open: Open? = null
    private var gen = 0

    // one still open when the next starts is taken as not picked
    fun begin(done: (Boolean) -> Unit): Int {
        open?.let { end(it, false) }
        val o = Open(++gen, done)
        open = o
        // a sheet that never covered this screen never comes back either
        later(NO_SHEET_MS) { if (open === o && !o.away) end(o, false) }
        return o.gen
    }

    // the sheet did not start: the caller answers itself
    fun drop(g: Int) {
        if (open?.gen == g) open = null
    }

    fun picked(g: Int) {
        val o = open ?: return
        if (o.gen == g) end(o, true)
    }

    fun paused() {
        open?.away = true
    }

    fun resumed() {
        val o = open ?: return
        if (!o.away) return
        // the pick's broadcast can trail the sheet closing
        later(GRACE_MS) { if (open === o) end(o, false) }
    }

    private fun end(o: Open, picked: Boolean) {
        open = null
        o.done(picked)
    }

    companion object {
        const val GRACE_MS = 600L
        const val NO_SHEET_MS = 10_000L
    }
}

object SharePick {
    const val PICKED = "picked"
    const val CLOSED = "closed"
    const val FAILED = "failed"
    private const val GEN = "gen"

    val wait = PickWait { ms, f -> Handler(Looper.getMainLooper()).postDelayed(f, ms) }
    private var heardIn: WeakReference<Context>? = null

    private fun action(c: Context) = "${c.packageName}.SHARE_PICKED"

    // registered for the whole process: the pick arrives while this screen
    // is covered, and a screen made anew meanwhile still gets it
    private fun listen(app: Context) {
        if (heardIn?.get() === app) return
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context, i: Intent) {
                wait.picked(i.getIntExtra(GEN, -1))
            }
        }
        ContextCompat.registerReceiver(
            app, r, IntentFilter(action(app)), ContextCompat.RECEIVER_NOT_EXPORTED
        )
        heardIn = WeakReference(app)
    }

    // the chooser for [send], told to report a pick back here
    fun chooser(c: Context, send: Intent, gen: Int): Intent {
        val app = c.applicationContext
        listen(app)
        val back = Intent(action(app)).setPackage(app.packageName).putExtra(GEN, gen)
        // which app was picked is not needed, only that one was
        val pi = PendingIntent.getBroadcast(
            app, gen, back,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return Intent.createChooser(send, null, pi.intentSender)
    }

    // opens the sheet and answers [done] with PICKED or CLOSED once it is
    // over. false when it did not open, and [done] is never called
    fun start(a: Activity, send: Intent, done: (String) -> Unit): Boolean {
        val gen = wait.begin { done(if (it) PICKED else CLOSED) }
        return try {
            a.startActivity(chooser(a, send, gen))
            true
        } catch (e: Exception) {
            wait.drop(gen)
            false
        }
    }
}
