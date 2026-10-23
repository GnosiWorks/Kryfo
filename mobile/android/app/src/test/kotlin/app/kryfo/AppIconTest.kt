// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Application
import android.content.ComponentName
import android.content.pm.PackageManager
import android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
import android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED
import android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

// the plain application: the real one boots a flutter engine
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33], application = Application::class)
class AppIconTest {
    private val app: Application = RuntimeEnvironment.getApplication()
    private val pm: PackageManager = app.packageManager

    // package manager's answers, and every change in the order it came
    private class Seen : AppIcon.Switches {
        val states = mutableMapOf<ComponentName, Int>()
        val changes = mutableListOf<Pair<ComponentName, Int>>()
        var refuse = false

        override fun state(c: ComponentName) = states[c] ?: COMPONENT_ENABLED_STATE_DEFAULT

        override fun apply(changes: List<Pair<ComponentName, Int>>) {
            if (refuse) throw SecurityException("no")
            for ((c, s) in changes) {
                this.changes += c to s
                states[c] = s
            }
        }
    }

    private fun c(alias: String) = ComponentName(app.packageName, "app.kryfo.$alias")

    // what a launcher would list: the manifest's state where nothing was set
    private fun on(s: (ComponentName) -> Int): List<String> = AppIcon.faces.filter {
        when (s(AppIcon.component(app, it))) {
            COMPONENT_ENABLED_STATE_ENABLED -> true
            COMPONENT_ENABLED_STATE_DEFAULT -> it.onByDefault
            else -> false
        }
    }.map { it.name }

    @Test
    fun aFreshInstallIsKryfo() {
        assertEquals("kryfo", AppIcon.current(app).name)
        assertEquals(COMPONENT_ENABLED_STATE_DEFAULT, pm.getComponentEnabledSetting(c("MainActivity")))
    }

    @Test
    fun eachSwitchLeavesExactlyOneEntryOn() {
        for (name in listOf("notes", "weather", "tasks", "news", "kryfo", "news")) {
            assertTrue(AppIcon.set(app, name))
            assertEquals(listOf(name), on { pm.getComponentEnabledSetting(it) })
            assertEquals(name, AppIcon.current(app).name)
        }
    }

    @Test
    fun backToKryfoIsTheManifestsOwnState() {
        AppIcon.set(app, "weather")
        AppIcon.set(app, "kryfo")
        for (f in AppIcon.faces) {
            assertEquals(f.name, COMPONENT_ENABLED_STATE_DEFAULT, pm.getComponentEnabledSetting(AppIcon.component(app, f)))
        }
    }

    @Test
    @Config(sdk = [30])
    fun onOlderAndroidTheNewOneGoesOnBeforeTheOldGoesOff() {
        val s = Seen()
        assertTrue(AppIcon.set(app, "notes", s))
        assertEquals(c("IconNotes") to COMPONENT_ENABLED_STATE_ENABLED, s.changes.first())
        assertEquals(c("MainActivity") to COMPONENT_ENABLED_STATE_DISABLED, s.changes[1])
        s.changes.clear()
        assertTrue(AppIcon.set(app, "kryfo", s))
        assertEquals(c("MainActivity") to COMPONENT_ENABLED_STATE_DEFAULT, s.changes.first())
        assertEquals(c("IconNotes") to COMPONENT_ENABLED_STATE_DEFAULT, s.changes[1])
        // and on the phone's own package manager as well
        assertTrue(AppIcon.set(app, "tasks"))
        assertEquals(listOf("tasks"), on { pm.getComponentEnabledSetting(it) })
    }

    @Test
    fun theDefaultStateOnKryfosEntryReadsAsKryfo() {
        val s = Seen()
        assertEquals("kryfo", AppIcon.current(app, s).name)
        // nothing to put right
        assertTrue(s.changes.isEmpty())
    }

    @Test
    fun noEntryOnAtAllIsPutBackToKryfo() {
        val s = Seen()
        s.states[c("MainActivity")] = COMPONENT_ENABLED_STATE_DISABLED
        assertEquals("kryfo", AppIcon.current(app, s).name)
        assertEquals(listOf("kryfo"), on { s.state(it) })
    }

    @Test
    fun aSwitchCutShortSaysThePlainOneAndLeavesBoth() {
        // android 12 or older stopped between the two steps
        val s = Seen()
        s.states[c("IconWeather")] = COMPONENT_ENABLED_STATE_ENABLED
        assertEquals("weather", AppIcon.current(app, s).name)
        assertTrue(s.changes.isEmpty())
        // the next switch leaves one
        assertTrue(AppIcon.set(app, "kryfo", s))
        assertEquals(listOf("kryfo"), on { s.state(it) })
    }

    @Test
    fun anUnknownNameIsRefused() {
        val s = Seen()
        assertFalse(AppIcon.set(app, "calculator", s))
        assertFalse(AppIcon.set(app, null, s))
        assertFalse(AppIcon.set(app, "", s))
        assertTrue(s.changes.isEmpty())
        assertEquals("kryfo", AppIcon.current(app).name)
    }

    @Test
    fun aRefusalSaysSo() {
        val s = Seen()
        s.refuse = true
        assertFalse(AppIcon.set(app, "notes", s))
    }

    @Test
    fun thePlainNamesAreTheirOwnWords() {
        for (f in AppIcon.faces.drop(1)) {
            val label = app.getString(f.label)
            assertTrue(label, label.isNotBlank() && !label.contains("Kryfo"))
        }
        assertEquals("Notes", app.getString(R.string.icon_notes))
    }
}
