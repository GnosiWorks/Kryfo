// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

// a clip's size as shown: [w] and [h] as decoded, swapped by a quarter turn
// in the track header. 16:9 when the header gives no size
internal fun shownSize(w: Int, h: Int, deg: Int): Pair<Int, Int> {
    if (w <= 0 || h <= 0) return 16 to 9
    return if (Math.floorMod(deg / 90, 2) == 1) h to w else w to h
}
