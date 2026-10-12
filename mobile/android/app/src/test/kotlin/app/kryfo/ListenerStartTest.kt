// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.ActivityManager
import android.app.ActivityManager.RunningAppProcessInfo
import android.app.Application
import android.app.ForegroundServiceStartNotAllowedException
import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Process
import androidx.core.app.NotificationCompat
import java.io.File
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.android.controller.ServiceController
import org.robolectric.annotation.Config

// the plain application: the real one boots a flutter engine
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class ListenerStartTest {
    private val app: Application = RuntimeEnvironment.getApplication()
    private var controller: ServiceController<HaloListenerService>? = null

    @Before
    fun setUp() {
        inFront(false)
    }

    @After
    fun tearDown() {
        controller?.destroy()
        File(app.dataDir, "app_flutter/halo.db").delete()
    }

    private fun withData() {
        val db = File(app.dataDir, "app_flutter/halo.db")
        db.parentFile!!.mkdirs()
        db.writeText("")
    }

    private fun inFront(yes: Boolean) {
        val me = RunningAppProcessInfo().apply {
            pid = Process.myPid()
            importance = if (yes) {
                RunningAppProcessInfo.IMPORTANCE_FOREGROUND
            } else {
                RunningAppProcessInfo.IMPORTANCE_CACHED
            }
        }
        shadowOf(app.getSystemService(ActivityManager::class.java)).setProcesses(listOf(me))
    }

    private fun service(): ServiceController<HaloListenerService> =
        Robolectric.buildService(HaloListenerService::class.java).also { controller = it }

    private fun shown(c: ServiceController<HaloListenerService>): Notification? =
        shadowOf(c.get()).lastForegroundNotification

    private fun startedFront(intent: Intent): Boolean =
        intent.getBooleanExtra(HaloListenerService.EXTRA_FRONT, false)

    private fun frontStart() =
        Intent(app, HaloListenerService::class.java)
            .putExtra(HaloListenerService.EXTRA_FRONT, true)

    @Test
    fun inTheFrontBeforeOnStartCommand() {
        // onCreate is the first the service sees of the main thread
        val c = service().create()
        assertNotNull(shown(c))
        assertEquals(HaloListenerService.NOTIFICATION_ID, shadowOf(c.get()).lastForegroundNotificationId)
        assertEquals(
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            c.get().foregroundServiceType
        )
    }

    @Test
    fun theNotificationIsUnchanged() {
        val n = shown(service().create())!!
        assertEquals(HaloListenerService.CHANNEL_ID, n.channelId)
        assertEquals("Kryfo is on", n.extras.getCharSequence(Notification.EXTRA_TITLE).toString())
        assertEquals(
            "Your encrypted line stays open so messages arrive",
            n.extras.getCharSequence(Notification.EXTRA_TEXT).toString()
        )
        assertEquals(R.drawable.ic_halo_notification, n.smallIcon.resId)
        assertEquals(0xFFF59E0B.toInt(), n.color)
        assertTrue(n.flags and Notification.FLAG_ONGOING_EVENT != 0)
        @Suppress("DEPRECATION")
        assertEquals(NotificationCompat.PRIORITY_MIN, n.priority)
        assertEquals(Notification.CATEGORY_SERVICE, n.category)
        assertFalse(n.extras.getBoolean(Notification.EXTRA_SHOW_WHEN, true))
        assertNotNull(n.contentIntent)
    }

    @Test
    fun staysUpWithData() {
        withData()
        val c = service().create().withIntent(frontStart()).startCommand(0, 1)
        assertNotNull(shown(c))
        assertTrue(HaloListenerService.running)
        assertFalse(shadowOf(c.get()).isStoppedBySelf)
    }

    @Test
    fun leavesAfterTheFrontWithoutData() {
        val c = service().create()
        assertNotNull(shown(c))
        c.withIntent(frontStart()).startCommand(0, 1)
        assertTrue(shadowOf(c.get()).isForegroundStopped)
        assertTrue(shadowOf(c.get()).isStoppedBySelf)
        assertFalse(HaloListenerService.running)
    }

    @Test
    fun aLanguageSwitchRewordsIt() {
        withData()
        val c = service().create().withIntent(frontStart()).startCommand(0, 1)
        app.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit().putString("flutter.app_locale", "de").commit()
        c.startCommand(0, 2)
        assertEquals(
            "Kryfo ist an",
            shown(c)!!.extras.getCharSequence(Notification.EXTRA_TITLE).toString()
        )
        app.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit().clear().commit()
    }

    @Test
    fun aRefusedPlainStartLeavesQuietly() {
        withData()
        val c = service()
        shadowOf(c.get()).setThrowInStartForeground(
            ForegroundServiceStartNotAllowedException("refused")
        )
        c.create().withIntent(Intent(app, HaloListenerService::class.java)).startCommand(0, 1)
        assertTrue(shadowOf(c.get()).isStoppedBySelf)
        assertFalse(HaloListenerService.running)
    }

    @Test(expected = ForegroundServiceStartNotAllowedException::class)
    fun aRefusedForegroundStartStillThrows() {
        val c = service()
        shadowOf(c.get()).setThrowInStartForeground(
            ForegroundServiceStartNotAllowedException("refused")
        )
        c.create().withIntent(frontStart()).startCommand(0, 1)
    }

    @Test
    fun theBackgroundGetsAForegroundStart() {
        HaloListenerService.start(app)
        assertTrue(startedFront(shadowOf(app).nextStartedService))
    }

    @Test
    fun aScreenInFrontGetsAPlainStart() {
        inFront(true)
        HaloListenerService.start(app)
        assertFalse(startedFront(shadowOf(app).nextStartedService))
    }

    @Test
    fun aServiceThatIsUpGetsAPlainStart() {
        withData()
        service().create().withIntent(frontStart()).startCommand(0, 1)
        assertTrue(HaloListenerService.running)
        HaloListenerService.start(app)
        assertFalse(startedFront(shadowOf(app).nextStartedService))
    }

    @Test
    fun theBootReceiverStartsItInTheFront() {
        withData()
        BootReceiver().onReceive(app, Intent(Intent.ACTION_MY_PACKAGE_REPLACED))
        assertTrue(startedFront(shadowOf(app).nextStartedService))
    }

    @Test
    fun theBootReceiverTakesARefusalQuietly() {
        withData()
        val refusing = object : ContextWrapper(app) {
            override fun startForegroundService(service: Intent): ComponentName? =
                throw ForegroundServiceStartNotAllowedException("refused")
        }
        BootReceiver().onReceive(refusing, Intent(Intent.ACTION_MY_PACKAGE_REPLACED))
        assertNull(shadowOf(app).nextStartedService)
    }

    @Test
    fun theBootReceiverNeedsData() {
        BootReceiver().onReceive(app, Intent(Intent.ACTION_MY_PACKAGE_REPLACED))
        assertNull(shadowOf(app).nextStartedService)
    }
}
