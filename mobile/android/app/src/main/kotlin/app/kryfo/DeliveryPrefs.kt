// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.content.Context

// the delivery mode is chosen in dart and kept in flutter's preferences.
// this side only needs to know whether the foreground service should be up:
// check-ins and the helper app mean nothing stays running.
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
