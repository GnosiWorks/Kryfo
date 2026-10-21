package app.kryfo

import android.app.ApplicationExitInfo

// what a stop of our process reads as. a force stop counts as asked for by
// the person, also when the phone's own cleaner or load guard sent it: the
// record's description names who did
object ExitWord {
    // the person's own ways to stop an app: its settings page, the recents
    // list, a shell
    private val own = setOf("com.android.settings", "com.miui.home", "com.android.systemui")
    private val from = Regex("""from process:([A-Za-z][\w.]*)""")

    fun byPhone(description: String?): Boolean {
        val d = description ?: return false
        if (d.contains("UserDefined")) return true
        val who = from.find(d)?.groupValues?.get(1) ?: return false
        return who !in own
    }

    fun of(reason: Int, description: String?): String = when (reason) {
        ApplicationExitInfo.REASON_SIGNALED -> "killed by the system"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "low memory"
        ApplicationExitInfo.REASON_CRASH,
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "crashed"
        ApplicationExitInfo.REASON_ANR -> "not responding"
        ApplicationExitInfo.REASON_USER_REQUESTED,
        ApplicationExitInfo.REASON_USER_STOPPED ->
            if (byPhone(description)) "stopped by the phone" else "stopped by you"
        ApplicationExitInfo.REASON_PACKAGE_UPDATED -> "updated"
        ApplicationExitInfo.REASON_OTHER -> "stopped by the system"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "used too much"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "permission changed"
        ApplicationExitInfo.REASON_EXIT_SELF -> "closed itself"
        else -> "stopped"
    }
}
