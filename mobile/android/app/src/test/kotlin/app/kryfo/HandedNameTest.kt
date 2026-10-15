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
    fun noSeparatorAndNoMoreThanTheCap() {
        assertEquals(".._.._etc_passwd", Shred.leaf("../../etc/passwd"))
        assertEquals("__", Shred.leaf("/\u0000"))
        assertEquals("a_b_c.txt", Shred.leaf("a\\b:c.txt"))
        val long = "x".repeat(300) + ".jpg"
        assertEquals(Shred.LEAF_BYTES, Shred.leaf(long).length)
        assertEquals(true, Shred.leaf(long).endsWith(".jpg"))
        val wide = "ж".repeat(300) + ".pdf"
        val cut = Shred.leaf(wide)
        assertEquals(true, cut.toByteArray(Charsets.UTF_8).size <= Shred.LEAF_BYTES)
        assertEquals(true, cut.endsWith("ж.pdf"))
    }

    @Test
    fun aNameInAnyLettersStaysTheSame() {
        assertEquals("фото отпуска.jpg", Shred.leaf("фото отпуска.jpg"))
        assertEquals("گزارش\u200Cها.pdf", Shred.leaf("گزارش\u200Cها.pdf"))
        assertEquals("报告.pdf", Shred.leaf("报告.pdf"))
    }

    @Test
    fun aHiddenMarkGoes() {
        assertEquals("invoicefdp.apk", Shred.leaf("invoice\u202Efdp.apk"))
        assertEquals("ab.pdf", Shred.leaf("a\u200Bb.pdf"))
    }

    @Test
    fun aShareFromAHiddenChatOrTheDecoyGoesWithTheLock() {
        assertEquals("share", Shred.shareInto(backup = false, quiet = false))
        assertEquals("share_q", Shred.shareInto(backup = false, quiet = true))
        assertEquals(Shred.BACKUP_OUT, Shred.shareInto(backup = true, quiet = true))
        assertEquals(true, Shred.HANDED.contains("share_q"))
    }
}
