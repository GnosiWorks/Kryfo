// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.content.Context

// how kryfo gets its messages is chosen in dart and kept in flutter's
// preferences. this side only has to know one thing about it: whether the
// foreground service should be up. always-on wants it. check-ins and the
// helper app are the modes whose whole point is that nothing stays running.
object DeliveryPrefs {
    private const val FILE = "FlutterSharedPreferences"
    private const val KEY = "flutter.delivery_mode"

    fun mode(context: Context): String = try {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getString(KEY, null) ?: "always"
    } catch (e: Exception) {
        "always"
    }

    fun staysOn(context: Context): Boolean {
        val m = mode(context)
        return m != "checkins" && m != "helper"
    }
}
