// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Application
import android.app.ForegroundServiceStartNotAllowedException
import android.app.Notification
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
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
import org.robolectric.annotation.Config

// the file transfer notification and its foreground service: asked for
// only on screen and only once, never stopped before it could go to the
// front, and with plain notifications one neutral word and no line
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class FileTransfersTest {
    private val app: Application = RuntimeEnvironment.getApplication()
    private var screen = true

    // a context whose foreground starts android refuses, counting the asks
    private inner class Refusing : ContextWrapper(app) {
        var asks = 0
        override fun startForegroundService(service: Intent): ComponentName? {
            asks++
            throw ForegroundServiceStartNotAllowedException("refused")
        }
    }

    @Before
    fun setUp() {
        screen = true
        FileTransfers.onScreen = { screen }
        FileTransfers.end(app)
        FileTransfers.starting = false
        shadowOf(app).clearStartedServices()
        while (shadowOf(app).nextStoppedService != null) Unit
    }

    @After
    fun tearDown() {
        FileTransfers.end(app)
        FileTransfers.starting = false
        app.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit().clear().commit()
    }

    private fun show(context: Context = app, plain: Boolean = false, hold: Boolean = true) =
        FileTransfers.show(
            context,
            channelName = "File transfers",
            channelLine = "line",
            title = "File transfer",
            text = "Sending · 1.0 MB of 4.0 MB",
            done = 1024,
            total = 4096,
            plain = plain,
            hold = hold,
        )

    private fun posted(): Notification? =
        shadowOf(app.getSystemService(NotificationManager::class.java))
            .getNotification(FileTransfers.NOTE_ID)

    @Test
    fun anEndBeforeOnStartCommandStopsNothing() {
        show()
        assertNotNull(shadowOf(app).nextStartedService)
        FileTransfers.end(app)
        // a stop now would come before startForeground: android ends the app
        assertNull(shadowOf(app).nextStoppedService)
        // the service fronts a placeholder, then takes itself down
        val c = Robolectric.buildService(FileTransferService::class.java).create().startCommand(0, 1)
        assertTrue(shadowOf(c.get()).isForegroundStopped)
        assertTrue(shadowOf(c.get()).isStoppedBySelf)
        assertFalse(FileTransfers.starting)
        c.destroy()
    }

    @Test
    fun aPlaceholderAndroidRefusesIsNotStopped() {
        show()
        FileTransfers.end(app)
        val c = Robolectric.buildService(FileTransferService::class.java)
        shadowOf(c.get()).setThrowInStartForeground(
            ForegroundServiceStartNotAllowedException("refused")
        )
        c.create().startCommand(0, 1)
        assertFalse(shadowOf(c.get()).isStoppedBySelf)
        assertTrue(FileTransfers.refused)
        c.destroy()
    }

    @Test
    fun aServiceInFrontIsStoppedAtTheEnd() {
        show()
        val c = Robolectric.buildService(FileTransferService::class.java).create().startCommand(0, 1)
        assertTrue(FileTransferService.running)
        assertFalse(shadowOf(c.get()).isStoppedBySelf)
        FileTransfers.end(app)
        assertNotNull(shadowOf(app).nextStoppedService)
        c.destroy()
    }

    @Test
    fun offScreenNoForegroundStartIsAskedFor() {
        screen = false
        show()
        assertNull(shadowOf(app).nextStartedService)
        assertNotNull(posted())
    }

    @Test
    fun aRefusalIsKeptUntilTheEnd() {
        val c = Refusing()
        show(c)
        show(c)
        show(c)
        assertEquals(1, c.asks)
        assertNotNull(posted())
        FileTransfers.end(app)
        show(c)
        assertEquals(2, c.asks)
    }

    @Test
    fun aRefusalInsideStartForegroundIsNotStoppedNorAskedAgain() {
        show()
        shadowOf(app).clearStartedServices()
        val c = Robolectric.buildService(FileTransferService::class.java)
        shadowOf(c.get()).setThrowInStartForeground(
            ForegroundServiceStartNotAllowedException("time limit")
        )
        c.create().startCommand(0, 1)
        assertFalse(FileTransferService.running)
        assertFalse(shadowOf(c.get()).isStoppedBySelf)
        show()
        assertNull(shadowOf(app).nextStartedService)
        c.destroy()
    }

    @Test
    fun theDaysTimeSpentIsNotAskedAgain() {
        show()
        val c = Robolectric.buildService(FileTransferService::class.java).create().startCommand(0, 1)
        shadowOf(app).clearStartedServices()
        c.get().onTimeout(1, 0)
        assertFalse(FileTransferService.running)
        show()
        assertNull(shadowOf(app).nextStartedService)
        c.destroy()
    }

    @Test
    fun plainSaysOneNeutralWordAndNoLine() {
        show(plain = true, hold = false)
        val n = posted()!!
        assertEquals("Active", n.extras.getCharSequence(Notification.EXTRA_TITLE).toString())
        assertNull(n.extras.getCharSequence(Notification.EXTRA_TEXT))
        assertEquals(Notification.COLOR_DEFAULT, n.color)
    }

    @Test
    fun plainSpeaksTheAppsLanguage() {
        app.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit().putString("flutter.app_locale", "de").commit()
        show(plain = true, hold = false)
        assertEquals("Aktiv", posted()!!.extras.getCharSequence(Notification.EXTRA_TITLE).toString())
    }

    @Test
    fun withoutPlainItSaysHowFar() {
        show(hold = false)
        val n = posted()!!
        assertEquals("File transfer", n.extras.getCharSequence(Notification.EXTRA_TITLE).toString())
        assertEquals("Sending · 1.0 MB of 4.0 MB", n.extras.getCharSequence(Notification.EXTRA_TEXT).toString())
    }
}
