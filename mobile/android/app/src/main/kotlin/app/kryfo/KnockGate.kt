// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.content.Context

// a knock costs a check-in over tor, and anything on the phone can send the
// receiver a broadcast. so one every 45 s at most and thirty an hour, kept
// across process restarts: a knock to a stopped process starts a new one.
// past that the fifteen-minute job still fetches. the relay knocks one
// endpoint at most once a minute, so its own knocks always get through.
object KnockGate {
    const val FLOOR_MS = 45_000L
    const val PER_HOUR = 30
    private const val HOUR_MS = 3_600_000L
    private const val PREFS = "helper_push"
    private const val KEY = "knocks"

    // whether a knock at [now] may go, and the times to keep after it. a
    // time ahead of now, from a clock set back, counts as now
    fun decide(kept: List<Long>, now: Long): Pair<Boolean, List<Long>> {
        val recent = kept.map { minOf(it, now) }.filter { now - it < HOUR_MS }
        val last = recent.maxOrNull()
        if (last != null && now - last < FLOOR_MS) return false to recent
        if (recent.size >= PER_HOUR) return false to recent
        return true to (recent + now)
    }

    @Synchronized
    fun allow(c: Context, now: Long = System.currentTimeMillis()): Boolean {
        val p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val kept = (p.getString(KEY, null) ?: "").split(',').mapNotNull { it.toLongOrNull() }
        val (ok, next) = decide(kept, now)
        p.edit().putString(KEY, next.joinToString(",")).apply()
        return ok
    }
}
