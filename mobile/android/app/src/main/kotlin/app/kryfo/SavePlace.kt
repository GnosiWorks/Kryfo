// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.content.Context

// where a new save lands in the phone's gallery. under kryfo's own icon its
// album, as always. under a plain icon the folders any phone's apps use,
// and no kryfo album is made: the camera's shots beside the camera's, the
// rest in Pictures and Movies. files saved before are never moved
object SavePlace {
    fun folder(plain: Boolean, video: Boolean, camera: Boolean): String = when {
        !plain -> if (video) "Movies/Kryfo" else "Pictures/Kryfo"
        camera -> "DCIM/Camera"
        video -> "Movies"
        else -> "Pictures"
    }

    fun folder(context: Context, video: Boolean, camera: Boolean): String {
        val plain = try {
            AppIcon.current(context) !== AppIcon.kryfo
        } catch (e: Exception) {
            // unread: the plain folder gives nothing away either way
            true
        }
        return folder(plain, video, camera)
    }
}
