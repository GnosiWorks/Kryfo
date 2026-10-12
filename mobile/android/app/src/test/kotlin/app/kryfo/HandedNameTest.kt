// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import org.junit.Assert.assertEquals
import org.junit.Test

class HandedNameTest {
    @Test
    fun dotsAloneNeverNameAFolder() {
        for (n in listOf("..", ".", "...", ". .", "", "  ")) {
            assertEquals(n, "file", Shred.leaf(n))
        }
    }

    @Test
    fun aPlainNameStays() {
        assertEquals("photo 1.jpg", Shred.leaf("photo 1.jpg"))
        assertEquals(".profile", Shred.leaf(".profile"))
        assertEquals("a..b.pdf", Shred.leaf("a..b.pdf"))
    }

    @Test
    fun noSeparatorAndNoMoreThanEighty() {
        assertEquals(".._.._etc_passwd", Shred.leaf("../../etc/passwd"))
        assertEquals("__", Shred.leaf("/\u0000"))
        val long = "x".repeat(100) + ".jpg"
        assertEquals(80, Shred.leaf(long).length)
        assertEquals(true, Shred.leaf(long).endsWith(".jpg"))
    }

    @Test
    fun aShareFromAHiddenChatOrTheDecoyGoesWithTheLock() {
        assertEquals("share", Shred.shareInto(backup = false, quiet = false))
        assertEquals("share_q", Shred.shareInto(backup = false, quiet = true))
        assertEquals(Shred.BACKUP_OUT, Shred.shareInto(backup = true, quiet = true))
        assertEquals(true, Shred.HANDED.contains("share_q"))
    }
}
