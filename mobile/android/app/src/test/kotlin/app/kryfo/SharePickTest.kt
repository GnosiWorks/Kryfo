// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Activity
import android.app.Application
import android.content.ComponentName
import android.content.Intent
import android.content.IntentSender
import android.os.Looper
import java.time.Duration
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

class PickWaitTest {
    // timers run only when the test says
    private val timers = mutableListOf<Pair<Long, () -> Unit>>()
    private val wait = PickWait { ms, f -> timers.add(ms to f) }
    private val answers = mutableListOf<Boolean>()

    private fun run(ms: Long) {
        val due = timers.filter { it.first == ms }
        timers.removeAll(due)
        due.forEach { it.second() }
    }

    @Test
    fun aPickIsShared() {
        val g = wait.begin { answers.add(it) }
        wait.paused()
        wait.picked(g)
        wait.resumed()
        run(PickWait.GRACE_MS)
        run(PickWait.NO_SHEET_MS)
        assertEquals(listOf(true), answers)
    }

    @Test
    fun aSheetClosedWithNoPickIsNot() {
        wait.begin { answers.add(it) }
        wait.paused()
        wait.resumed()
        assertEquals(emptyList<Boolean>(), answers)
        run(PickWait.GRACE_MS)
        assertEquals(listOf(false), answers)
    }

    @Test
    fun aPickThatTrailsTheCloseStillCounts() {
        val g = wait.begin { answers.add(it) }
        wait.paused()
        wait.resumed()
        wait.picked(g)
        run(PickWait.GRACE_MS)
        assertEquals(listOf(true), answers)
    }

    @Test
    fun aResumeBeforeTheSheetCoveredUsSaysNothing() {
        wait.begin { answers.add(it) }
        wait.resumed()
        run(PickWait.GRACE_MS)
        assertEquals(emptyList<Boolean>(), answers)
        // and a sheet that never showed does not wait forever
        run(PickWait.NO_SHEET_MS)
        assertEquals(listOf(false), answers)
    }

    @Test
    fun anOldPickIsNotTheNewSheets() {
        val first = mutableListOf<Boolean>()
        val g1 = wait.begin { first.add(it) }
        wait.begin { answers.add(it) }
        assertEquals(listOf(false), first)
        wait.paused()
        wait.picked(g1)
        wait.resumed()
        run(PickWait.GRACE_MS)
        assertEquals(listOf(false), answers)
        assertEquals(listOf(false), first)
    }

    @Test
    fun aSheetThatNeverStartedIsNeverAnswered() {
        val g = wait.begin { answers.add(it) }
        wait.drop(g)
        wait.paused()
        wait.resumed()
        run(PickWait.GRACE_MS)
        run(PickWait.NO_SHEET_MS)
        assertEquals(emptyList<Boolean>(), answers)
    }
}

@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [34])
class SharePickTest {
    private val app: Application = RuntimeEnvironment.getApplication()

    private fun send() = Intent(Intent.ACTION_SEND).apply { type = "text/plain" }

    private fun idle(ms: Long = 0) {
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(ms))
    }

    @Test
    fun theSheetReportsAPickBackHere() {
        val a = Robolectric.buildActivity(Activity::class.java).setup().get()
        val got = mutableListOf<String>()
        assertTrue(SharePick.start(a, send()) { got.add(it) })
        val chooser = shadowOf(a).nextStartedActivity
        assertEquals(Intent.ACTION_CHOOSER, chooser.action)
        @Suppress("DEPRECATION")
        val sender = chooser.getParcelableExtra<IntentSender>(
            Intent.EXTRA_CHOSEN_COMPONENT_INTENT_SENDER
        )
        assertNotNull(sender)
        SharePick.wait.paused()
        // what the sheet does once an app is tapped
        sender!!.sendIntent(
            app, 0,
            Intent().putExtra(Intent.EXTRA_CHOSEN_COMPONENT, ComponentName("x.y", "x.y.Z")),
            null, null
        )
        idle()
        SharePick.wait.resumed()
        idle(PickWait.GRACE_MS)
        assertEquals(listOf(SharePick.PICKED), got)
    }

    @Test
    fun aSheetBackedOutOfIsClosed() {
        val a = Robolectric.buildActivity(Activity::class.java).setup().get()
        val got = mutableListOf<String>()
        assertTrue(SharePick.start(a, send()) { got.add(it) })
        SharePick.wait.paused()
        SharePick.wait.resumed()
        idle(PickWait.GRACE_MS - 100)
        assertEquals(emptyList<String>(), got)
        idle(200)
        assertEquals(listOf(SharePick.CLOSED), got)
    }

    @Test
    fun aBroadcastFromNoSheetIsNotAPick() {
        val a = Robolectric.buildActivity(Activity::class.java).setup().get()
        val got = mutableListOf<String>()
        assertTrue(SharePick.start(a, send()) { got.add(it) })
        SharePick.wait.paused()
        // the right action without the sheet's number
        app.sendBroadcast(Intent("${app.packageName}.SHARE_PICKED").setPackage(app.packageName))
        idle()
        SharePick.wait.resumed()
        idle(PickWait.GRACE_MS)
        assertEquals(listOf(SharePick.CLOSED), got)
    }
}
