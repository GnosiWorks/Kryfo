// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Application
import android.app.Notification
import android.content.Context
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RuntimeEnvironment
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.android.controller.ServiceController
import org.robolectric.annotation.Config

// the staying-connected notification with plain notifications on: one plain
// word, nothing under it, no colour of kryfo's and the glyph of the home
// screen's icon. its tap names the screen itself, whatever entry is on
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class ListenerPlainTest {
    private val app: Application = RuntimeEnvironment.getApplication()
    private var controller: ServiceController<HaloListenerService>? = null

    @After
    fun tearDown() {
        controller?.destroy()
        prefs().edit().clear().commit()
        AppIcon.set(app, "kryfo")
    }

    private fun prefs() = app.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    private fun shown(): Notification {
        val c = Robolectric.buildService(HaloListenerService::class.java).also { controller = it }
        return shadowOf(c.create().get()).lastForegroundNotification!!
    }

    private fun tapsTo(n: Notification): String? =
        shadowOf(n.contentIntent).savedIntent.component?.className

    @Test
    fun plainSaysOneWordAndNoMore() {
        prefs().edit().putBoolean("flutter.notif_plain", true).commit()
        val n = shown()
        assertEquals("Active", n.extras.getCharSequence(Notification.EXTRA_TITLE).toString())
        assertNull(n.extras.getCharSequence(Notification.EXTRA_TEXT))
        assertEquals(Notification.COLOR_DEFAULT, n.color)
        assertEquals(R.drawable.ic_plain_dot, n.smallIcon.resId)
        assertEquals("app.kryfo.KryfoActivity", tapsTo(n))
    }

    @Test
    fun plainWearsTheGlyphOfTheHomeScreensIcon() {
        prefs().edit().putBoolean("flutter.notif_plain", true).commit()
        AppIcon.set(app, "weather")
        assertEquals(R.drawable.ic_plain_weather, shown().smallIcon.resId)
    }

    @Test
    fun offItIsKryfosOwnAndStillTapsToTheScreen() {
        val n = shown()
        assertEquals("Kryfo is on", n.extras.getCharSequence(Notification.EXTRA_TITLE).toString())
        assertEquals(R.drawable.ic_halo_notification, n.smallIcon.resId)
        assertEquals("app.kryfo.KryfoActivity", tapsTo(n))
    }
}
