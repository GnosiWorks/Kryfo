// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Application
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

// where a new save lands: kryfo's album under kryfo's icon, the phone's own
// folders under a plain one, and no folder that names kryfo then
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class SavePlaceTest {
    private val app: Application = RuntimeEnvironment.getApplication()

    @After
    fun tearDown() {
        AppIcon.set(app, "kryfo")
    }

    @Test
    fun underKryfosIconTheAlbumAsAlways() {
        assertEquals("Pictures/Kryfo", SavePlace.folder(app, video = false, camera = false))
        assertEquals("Movies/Kryfo", SavePlace.folder(app, video = true, camera = false))
        assertEquals("Pictures/Kryfo", SavePlace.folder(app, video = false, camera = true))
        assertEquals("Movies/Kryfo", SavePlace.folder(app, video = true, camera = true))
    }

    @Test
    fun underAPlainIconThePhonesOwnFolders() {
        for (name in listOf("notes", "weather", "tasks", "news")) {
            AppIcon.set(app, name)
            assertEquals("Pictures", SavePlace.folder(app, video = false, camera = false))
            assertEquals("Movies", SavePlace.folder(app, video = true, camera = false))
            assertEquals("DCIM/Camera", SavePlace.folder(app, video = false, camera = true))
            assertEquals("DCIM/Camera", SavePlace.folder(app, video = true, camera = true))
            for (v in listOf(false, true)) for (cam in listOf(false, true)) {
                assertFalse(SavePlace.folder(app, v, cam).contains("ryfo"))
            }
        }
    }
}
