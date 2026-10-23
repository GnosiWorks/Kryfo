// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.content.ContentValues
import android.content.Context
import android.provider.MediaStore

// where a new save lands in the phone's gallery. under kryfo's own icon its
// album, as always. under a plain icon Pictures and Movies, like any app's,
// and no kryfo album is made. not DCIM/Camera: photo apps send that folder
// to their cloud by default. files saved before are never moved
object SavePlace {
    fun folder(plain: Boolean, video: Boolean): String = when {
        !plain -> if (video) "Movies/Kryfo" else "Pictures/Kryfo"
        video -> "Movies"
        else -> "Pictures"
    }

    fun folder(context: Context, video: Boolean): String {
        val plain = try {
            AppIcon.current(context) !== AppIcon.kryfo
        } catch (e: Exception) {
            // unread: the plain folder gives nothing away either way
            true
        }
        return folder(plain, video)
    }

    // the row a new save starts as: its name, its type, its folder, and
    // pending until its bytes are in
    fun newRow(context: Context, name: String, mime: String): ContentValues =
        ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, folder(context, mime.startsWith("video/")))
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

    // all a row is ever changed by afterwards: it is done. nothing moves or
    // renames a saved file
    fun doneRow(): ContentValues = ContentValues().apply {
        put(MediaStore.MediaColumns.IS_PENDING, 0)
    }
}
