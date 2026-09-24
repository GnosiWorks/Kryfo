// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

// the language kryfo was set to in its own settings, for the few words
// android shows itself (the service's notification and its channel). it is
// chosen in dart and kept in flutter's preferences; "system", or nothing,
// is the phone's language.
object AppLocale {
    private const val FILE = "FlutterSharedPreferences"
    private const val KEY = "flutter.app_locale"

    fun context(base: Context): Context {
        val tag = try {
            base.getSharedPreferences(FILE, Context.MODE_PRIVATE).getString(KEY, null)
        } catch (e: Exception) {
            null
        }
        if (tag == null || tag == "system") return base
        val config = Configuration(base.resources.configuration)
        config.setLocale(Locale.forLanguageTag(tag.replace('_', '-')))
        return base.createConfigurationContext(config)
    }
}
