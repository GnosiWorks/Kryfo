// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.ApplicationExitInfo

// a short code for why our process last stopped. dart turns it into words.
// a force stop counts as asked for by the person, also when the phone sent
// it: the record's description names who did
object ExitWord {
    // where a person stops an app on stock android: its settings page
    private val own = setOf("com.android.settings")
    // xiaomi's security app holds manage apps, the recents clear all and
    // its own cleanup, so a stop from it may be the person's or the phone's
    private const val SECURITY = "com.miui.securitycenter"
    private val from = Regex("""from process:([A-Za-z][\w.]*)""")

    fun forceStopBy(description: String?): String {
        val d = description ?: return "by_you"
        // xiaomi's guard when the phone is under too much load
        if (d.contains("UserDefined")) return "by_phone"
        val who = from.find(d)?.groupValues?.get(1) ?: return "by_you"
        return when (who) {
            in own -> "by_you"
            SECURITY -> "by_security_app"
            else -> "by_phone"
        }
    }

    fun of(reason: Int, description: String?): String = when (reason) {
        ApplicationExitInfo.REASON_SIGNALED -> "killed"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "low_memory"
        ApplicationExitInfo.REASON_CRASH,
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "crashed"
        ApplicationExitInfo.REASON_ANR -> "not_responding"
        ApplicationExitInfo.REASON_USER_REQUESTED,
        ApplicationExitInfo.REASON_USER_STOPPED -> forceStopBy(description)
        ApplicationExitInfo.REASON_PACKAGE_UPDATED -> "updated"
        ApplicationExitInfo.REASON_OTHER -> "by_system"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "too_much"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "permission"
        ApplicationExitInfo.REASON_EXIT_SELF -> "closed_itself"
        else -> "stopped"
    }
}
