// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Activity
import android.app.ActivityManager
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

// the icon and name on the home screen: one launcher entry per face in the
// manifest, kryfo's on and the rest off. what package manager says is the
// truth, never a copy kept here
object AppIcon {
    // the namespace the classes are in, whatever the application id
    private const val CLASSES = "app.kryfo"

    class Face(
        val name: String,
        val alias: String,
        // 0: the application's own label
        val label: Int,
        val icon: Int,
        // what a plain notification wears
        val glyph: Int,
        // the manifest's enabled
        val onByDefault: Boolean,
    )

    val kryfo = Face(
        "kryfo", "MainActivity", 0,
        R.mipmap.ic_launcher, R.drawable.ic_plain_dot, true
    )

    val faces = listOf(
        kryfo,
        Face(
            "notes", "IconNotes", R.string.icon_notes,
            R.mipmap.ic_icon_notes, R.drawable.ic_plain_notes, false
        ),
        Face(
            "weather", "IconWeather", R.string.icon_weather,
            R.mipmap.ic_icon_weather, R.drawable.ic_plain_weather, false
        ),
        Face(
            "tasks", "IconTasks", R.string.icon_tasks,
            R.mipmap.ic_icon_tasks, R.drawable.ic_plain_tasks, false
        ),
        Face(
            "news", "IconNews", R.string.icon_news,
            R.mipmap.ic_icon_news, R.drawable.ic_plain_news, false
        ),
    )

    // package manager, behind a seam so a test can see the order
    interface Switches {
        fun state(c: ComponentName): Int
        fun apply(changes: List<Pair<ComponentName, Int>>)
    }

    class Pm(private val context: Context) : Switches {
        private val pm: PackageManager = context.packageManager

        override fun state(c: ComponentName): Int = pm.getComponentEnabledSetting(c)

        // the open screen stays: the app closes and opens again itself
        override fun apply(changes: List<Pair<ComponentName, Int>>) {
            if (Build.VERSION.SDK_INT >= 33) {
                val flags = PackageManager.DONT_KILL_APP or PackageManager.SYNCHRONOUS
                pm.setComponentEnabledSettings(
                    changes.map { PackageManager.ComponentEnabledSetting(it.first, it.second, flags) }
                )
                return
            }
            val flags = if (Build.VERSION.SDK_INT >= 30) {
                PackageManager.DONT_KILL_APP or PackageManager.SYNCHRONOUS
            } else {
                PackageManager.DONT_KILL_APP
            }
            for ((c, s) in changes) pm.setComponentEnabledSetting(c, s, flags)
        }
    }

    fun component(context: Context, f: Face) =
        ComponentName(context.packageName, "$CLASSES.${f.alias}")

    fun byName(name: String?): Face? = faces.firstOrNull { it.name == name }

    private fun on(context: Context, s: Switches, f: Face): Boolean =
        when (s.state(component(context, f))) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> f.onByDefault
            else -> false
        }

    // the steps to [f]: it goes on first, then the rest off, so the phone
    // never has none and at most two for a moment. kryfo on is the
    // manifest's own state, and so is a plain one off
    fun steps(context: Context, f: Face): List<Pair<ComponentName, Int>> {
        fun want(x: Face, on: Boolean) = when {
            on == x.onByDefault -> PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
            on -> PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else -> PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        }
        return listOf(component(context, f) to want(f, true)) +
            faces.filter { it !== f }.map { component(context, it) to want(it, false) }
    }

    fun current(context: Context, s: Switches = Pm(context)): Face {
        val up = faces.filter { on(context, s, it) }
        // none at all is put back to kryfo. two, from a switch cut short on
        // android 12 or older, say the plain one and stay as they are: which
        // was meant cannot be told, and the next switch puts them right
        if (up.isEmpty()) {
            try {
                s.apply(steps(context, kryfo))
            } catch (e: Exception) {
            }
            return kryfo
        }
        return up.firstOrNull { !it.onByDefault } ?: up.first()
    }

    // false for a name it does not know, and when android refused
    fun set(context: Context, name: String?, s: Switches = Pm(context)): Boolean {
        val f = byName(name) ?: return false
        return try {
            s.apply(steps(context, f))
            true
        } catch (e: Exception) {
            false
        }
    }

    // the app switcher card: a start from a notification or a restart names
    // the screen itself, whose label and icon are kryfo's. in the phone's
    // language, as the launcher shows it
    @Suppress("DEPRECATION")
    fun describeTask(activity: Activity) {
        try {
            val f = current(activity)
            if (f === kryfo) return
            val label = activity.getString(f.label)
            val task = when {
                Build.VERSION.SDK_INT >= 33 -> ActivityManager.TaskDescription.Builder()
                    .setLabel(label)
                    .setIcon(f.icon)
                    .build()
                Build.VERSION.SDK_INT >= 28 -> ActivityManager.TaskDescription(label, f.icon)
                else -> ActivityManager.TaskDescription(label)
            }
            activity.setTaskDescription(task)
        } catch (e: Exception) {
        }
    }
}
