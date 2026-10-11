package app.kryfo

import org.junit.Assert.assertEquals
import org.junit.Test

class NetTrackerTest {
    private val caps = mutableMapOf("wifi" to "wifi-up", "cell" to "cell-up")
    private val seen = mutableListOf<String>()
    private val t = NetTracker<String>(
        describe = { n -> if (n == null) "off" else caps[n] ?: "off" },
        report = { seen.add(it) },
    )

    // android 7: onAvailable and nothing after it
    @Test
    fun availableAloneReportsTheNetwork() {
        t.available("wifi")
        assertEquals(listOf("wifi-up"), seen)
    }

    // the new default comes up before the old one is lost
    @Test
    fun lossOfAnOldNetworkChangesNothing() {
        t.available("wifi")
        t.available("cell")
        t.lost("wifi")
        assertEquals(listOf("wifi-up", "cell-up"), seen)
        t.lost("cell")
        assertEquals("off", seen.last())
    }

    @Test
    fun capabilitiesFollowTheCurrentNetwork() {
        t.available("wifi")
        t.changed("wifi", "wifi-validated")
        t.lost("cell")
        assertEquals(listOf("wifi-up", "wifi-validated"), seen)
    }
}
