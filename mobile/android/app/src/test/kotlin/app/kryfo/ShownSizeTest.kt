// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import org.junit.Assert.assertEquals
import org.junit.Test

class ShownSizeTest {
    @Test
    fun aQuarterTurnShowsTheClipUpright() {
        // the samsung corpus clip: 1920x1080 with a turn of 90
        assertEquals(1080 to 1920, shownSize(1920, 1080, 90))
        assertEquals(1080 to 1920, shownSize(1920, 1080, 270))
        assertEquals(1080 to 1920, shownSize(1920, 1080, -90))
    }

    @Test
    fun noTurnOrAHalfTurnKeepsTheShape() {
        assertEquals(1920 to 1080, shownSize(1920, 1080, 0))
        assertEquals(1920 to 1080, shownSize(1920, 1080, 180))
    }

    @Test
    fun noSizeFallsBackToWide() {
        assertEquals(16 to 9, shownSize(0, 0, 90))
    }
}
