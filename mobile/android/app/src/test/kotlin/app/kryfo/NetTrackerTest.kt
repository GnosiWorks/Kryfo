package app.kryfo

import org.junit.Assert.assertEquals
import org.junit.Test

class NetTrackerTest {
    private val caps = mutableMapOf("wifi" to "wifi-up", "cell" to "cell-up")
    private val seen = mutableListOf<String>()
    private fun tracker(capsFollow: Boolean) = NetTracker<String>(
        describe = { n -> if (n == null) "off" else caps[n] ?: "off" },
        report = { seen.add(it) },
        capsFollow = capsFollow,
    )
    private val t = tracker(false)

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

    // android 8 and later: no read of our own, the capabilities come
    @Test
    fun laterAndroidsWaitForCapabilities() {
        val n = tracker(true)
        n.available("wifi")
        assertEquals(emptyList<String>(), seen)
        n.changed("wifi", "wifi-validated")
        n.available("cell")
        n.lost("wifi")
        assertEquals(listOf("wifi-validated"), seen)
    }

    @Test
    fun capabilitiesFollowTheCurrentNetwork() {
        t.available("wifi")
        t.changed("wifi", "wifi-validated")
        t.lost("cell")
        assertEquals(listOf("wifi-up", "wifi-validated"), seen)
    }
}
