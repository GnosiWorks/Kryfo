// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.content.Context

// a knock costs a check-in over tor, and anything on the phone can send the
// receiver a broadcast. so one every 45 s at most and thirty an hour, kept
// across process restarts: a knock to a stopped process starts a new one.
// a knock inside the floor is not dropped but waits for it to pass, one at
// a time; past the hourly cap it is dropped and the fifteen-minute job
// still fetches. the relay knocks one endpoint at most once a minute.
object KnockGate {
    const val FLOOR_MS = 45_000L
    const val PER_HOUR = 30
    private const val HOUR_MS = 3_600_000L
    private const val PREFS = "helper_push"
    private const val KEY = "knocks"

    // go now, later (wait ms), or not at all
    data class Verdict(val go: Boolean, val waitMs: Long, val kept: List<Long>)

    fun decide(kept: List<Long>, now: Long): Verdict {
        // a time ahead of now, from a clock set back, counts as now
        val recent = kept.map { minOf(it, now) }.filter { now - it < HOUR_MS }
        if (recent.size >= PER_HOUR) return Verdict(false, 0, recent)
        val last = recent.maxOrNull()
        if (last != null && now - last < FLOOR_MS) {
            return Verdict(false, last + FLOOR_MS - now, recent)
        }
        return Verdict(true, 0, recent + now)
    }

    @Synchronized
    fun allow(c: Context, now: Long = System.currentTimeMillis()): Verdict {
        val p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val kept = (p.getString(KEY, null) ?: "").split(',').mapNotNull { it.toLongOrNull() }
        val v = decide(kept, now)
        p.edit().putString(KEY, v.kept.joinToString(",")).apply()
        return v
    }
}
