// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Application
import android.provider.MediaStore
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

// the gallery row a new save starts as: kryfo's album under kryfo's icon,
// Pictures and Movies under a plain one (never DCIM/Camera, which photo
// apps send to their cloud), nothing that names kryfo then. a row is only
// ever finished afterwards, never moved or renamed
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class SavePlaceTest {
    private val app: Application = RuntimeEnvironment.getApplication()

    @After
    fun tearDown() {
        AppIcon.set(app, "kryfo")
    }

    private fun folderOf(name: String, mime: String) =
        SavePlace.newRow(app, name, mime).getAsString(MediaStore.MediaColumns.RELATIVE_PATH)

    @Test
    fun underKryfosIconTheAlbumAsAlways() {
        assertEquals("Pictures/Kryfo", folderOf("kryfo_1.jpg", "image/jpeg"))
        assertEquals("Movies/Kryfo", folderOf("kryfo_1.mp4", "video/mp4"))
    }

    @Test
    fun underAPlainIconThePhonesOwnFolders() {
        for (name in listOf("notes", "weather", "tasks", "news")) {
            AppIcon.set(app, name)
            val photo = SavePlace.newRow(app, "IMG_20261024_090507.jpg", "image/jpeg")
            assertEquals("Pictures", photo.getAsString(MediaStore.MediaColumns.RELATIVE_PATH))
            assertEquals("IMG_20261024_090507.jpg", photo.getAsString(MediaStore.MediaColumns.DISPLAY_NAME))
            assertEquals(1, photo.getAsInteger(MediaStore.MediaColumns.IS_PENDING))
            assertEquals("Movies", folderOf("VID_20261024_090507.mp4", "video/mp4"))
            for (mime in listOf("image/jpeg", "image/png", "video/mp4")) {
                val f = folderOf("x", mime)
                assertFalse(f, f.contains("ryfo") || f.startsWith("DCIM"))
            }
        }
    }

    @Test
    fun aRowIsOnlyEverFinished() {
        val done = SavePlace.doneRow()
        assertEquals(setOf(MediaStore.MediaColumns.IS_PENDING), done.keySet())
        assertEquals(0, done.getAsInteger(MediaStore.MediaColumns.IS_PENDING))
    }
}
