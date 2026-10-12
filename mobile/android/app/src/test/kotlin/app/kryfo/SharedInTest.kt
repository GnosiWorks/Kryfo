// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SharedInTest {
    private val pkg = "app.kryfo"

    @Test
    fun ourOwnProvidersAreOursWithAUserIdToo() {
        assertTrue(ToolsBridge.ours("app.kryfo.open", pkg))
        assertTrue(ToolsBridge.ours("0@app.kryfo.open", pkg))
        assertTrue(ToolsBridge.ours("10@app.kryfo.open", pkg))
        assertTrue(ToolsBridge.ours("x@y@app.kryfo.open", pkg))
        assertTrue(ToolsBridge.ours("App.Kryfo.Open", pkg))
        assertTrue(ToolsBridge.ours("0@app.kryfo.bridgetest.open", "app.kryfo.bridgetest"))
    }

    @Test
    fun anotherAppsAreNot() {
        assertFalse(ToolsBridge.ours("com.android.providers.media.documents", pkg))
        assertFalse(ToolsBridge.ours("10@com.android.providers.media", pkg))
        assertFalse(ToolsBridge.ours("media", pkg))
        assertFalse(ToolsBridge.ours("app.kryfo@com.example", pkg))
    }

    @Test
    fun aLateReadNeverTakesTheNewerShare() {
        val turns = Turns()
        val stream = turns.next()
        val words = turns.next()
        assertTrue(turns.latest(words))
        assertFalse(turns.latest(stream))
        val again = turns.next()
        assertFalse(turns.latest(words))
        assertTrue(turns.latest(again))
    }
}
