// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Application
import android.security.keystore.UserNotAuthenticatedException
import java.security.ProviderException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

// the pin key's life on keystores that refuse, stall, answer oddly or lose
// the key: it is never made over one that is there, never deleted on an
// error, and every failure says which kind it is
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class PinKeyTest {
    private class Plain : PinKey.Keys {
        val made = mutableMapOf<String, ByteArray>()
        val makes = mutableListOf<Pair<Boolean, Boolean>>()
        var deletes = 0
        var calls = 0
        var refuseStrongBox = false
        var refuseAll = false
        // ms a strongbox call takes on the fake clock
        var strongMs = 60L
        var strong = false
        // answers this instead of an hmac
        var fixed: ByteArray? = null
        var echo = false
        // calls that fail with these first, one per call
        val failing = ArrayDeque<Exception>()
        // calls hang until this opens
        var hang: CountDownLatch? = null
        var clock = 0L

        override fun has(alias: String) = made.containsKey(alias)

        override fun make(alias: String, strongBox: Boolean, unlocked: Boolean) {
            makes.add(strongBox to unlocked)
            if (refuseAll || (strongBox && refuseStrongBox)) throw ProviderException("refused")
            made[alias] = ByteArray(32) { (it * 7 + makes.size).toByte() }
            strong = strongBox
        }

        override fun mac(alias: String, input: ByteArray): ByteArray {
            calls++
            hang?.await(5, TimeUnit.SECONDS)
            failing.removeFirstOrNull()?.let { throw it }
            val k = made[alias] ?: throw PinKey.Gone()
            if (strong) clock += strongMs * 1_000_000
            fixed?.let { return it.copyOf() }
            if (echo) return input.copyOf()
            return Mac.getInstance("HmacSHA256").apply { init(SecretKeySpec(k, "HmacSHA256")) }.doFinal(input)
        }

        override fun level(alias: String): Int? =
            if (!made.containsKey(alias)) null else if (strong) PinKey.STRONGBOX else PinKey.TEE

        override fun delete(alias: String) {
            deletes++
            made.remove(alias)
        }
    }

    private class Kept : PinKey.Notes {
        var v: Pair<Int, Int>? = null
        override fun read() = v
        override fun write(unlocked: Int, level: Int) {
            v = unlocked to level
        }
        override fun clear() {
            v = null
        }
    }

    private val keys = Plain()
    private val notes = Kept()
    private val paused = mutableListOf<Long>()

    @Before
    fun stand() {
        PinKey.keys = keys
        PinKey.notes = notes
        PinKey.sdk = 34
        PinKey.nanos = { keys.clock }
        PinKey.pause = { paused.add(it) }
    }

    @After
    fun back() {
        PinKey.keys = PinKey.Store
        PinKey.notes = null
        PinKey.sdk = android.os.Build.VERSION.SDK_INT
        PinKey.nanos = System::nanoTime
        PinKey.pause = { Thread.sleep(it) }
    }

    private val x = ByteArray(32) { it.toByte() }
    private val xHex = PinKey.hex(x)

    @Test
    fun strongBoxFirstAndTheFlagOnlyFrom15() {
        val r = PinKey.make()
        assertEquals(true, r["k"])
        assertEquals(PinKey.STRONGBOX, r["l"])
        assertEquals(0, r["u"])
        assertEquals(listOf(true to false), keys.makes)
        assertEquals(64, (r["kc"] as String).length)
        PinKey.drop()
        PinKey.sdk = 35
        keys.makes.clear()
        assertEquals(1, PinKey.make()["u"])
        assertEquals(listOf(true to true), keys.makes)
        assertEquals(1 to PinKey.STRONGBOX, notes.v)
    }

    @Test
    fun aRefusedOrSlowStrongBoxMakesItInTheTee() {
        keys.refuseStrongBox = true
        assertEquals(PinKey.TEE, PinKey.make()["l"])
        assertEquals(listOf(true to false, false to false), keys.makes)
        PinKey.drop()
        keys.refuseStrongBox = false
        keys.strongMs = 400
        keys.makes.clear()
        assertEquals(PinKey.TEE, PinKey.make()["l"])
        assertEquals(listOf(true to false, false to false), keys.makes)
        // android 8 has no strongbox to ask
        PinKey.drop()
        PinKey.sdk = 27
        keys.makes.clear()
        PinKey.make()
        assertEquals(listOf(false to false), keys.makes)
    }

    @Test
    fun aKeyThatFailsItsTestIsNotKept() {
        keys.fixed = ByteArray(32) { 1 }
        assertEquals("refused", PinKey.make()["e"])
        assertFalse(keys.has(PinKey.ALIAS))
        keys.fixed = null
        keys.refuseAll = true
        assertEquals("refused", PinKey.make()["e"])
        assertEquals(null, notes.v)
    }

    @Test
    fun neverMadeOverOneThatIsThere() {
        val first = PinKey.make()
        val key = keys.made[PinKey.ALIAS]!!.copyOf()
        keys.makes.clear()
        val again = PinKey.make()
        assertTrue(keys.makes.isEmpty())
        assertTrue(key.contentEquals(keys.made[PinKey.ALIAS]))
        assertEquals(first["kc"], again["kc"])
    }

    @Test
    fun theSameInputSignsTheSame() {
        PinKey.make()
        val a = PinKey.mac(xHex)["m"] as String
        assertEquals(a, PinKey.mac(xHex)["m"])
        assertNotEquals(a, PinKey.mac(PinKey.hex(ByteArray(32) { 9 }))["m"])
        assertNotEquals(a, PinKey.kcv()["m"])
        assertEquals("bad", PinKey.mac("abc")["e"])
        assertEquals("bad", PinKey.mac(PinKey.hex(ByteArray(16)))["e"])
    }

    @Test
    fun aBusyKeystoreIsTriedAgainAndNeverDropsTheKey() {
        PinKey.make()
        keys.failing.add(ProviderException("busy"))
        keys.failing.add(ProviderException("busy"))
        assertTrue(PinKey.mac(xHex).containsKey("m"))
        assertEquals(listOf(150L, 300L), paused)
        repeat(3) { keys.failing.add(ProviderException("busy")) }
        assertEquals("busy", PinKey.mac(xHex)["e"])
        assertEquals(0, keys.deletes)
        assertTrue(keys.has(PinKey.ALIAS))
    }

    @Test
    fun lockedIsTriedOnceMoreFrom15() {
        PinKey.make()
        PinKey.sdk = 35
        keys.failing.add(UserNotAuthenticatedException())
        assertTrue(PinKey.mac(xHex).containsKey("m"))
        assertEquals(listOf(300L), paused)
        keys.failing.add(UserNotAuthenticatedException())
        keys.failing.add(UserNotAuthenticatedException())
        assertEquals("locked", PinKey.mac(xHex)["e"])
        PinKey.sdk = 34
        keys.failing.add(UserNotAuthenticatedException())
        assertEquals("locked", PinKey.mac(xHex)["e"])
        assertEquals(0, keys.deletes)
    }

    @Test
    fun goneOnlyWhenTheKeystoreHasNoKey() {
        assertEquals("gone", PinKey.mac(xHex)["e"])
        assertEquals("gone", PinKey.kcv()["e"])
        PinKey.make()
        // a failure with the key there is busy, never gone
        keys.failing.add(IllegalStateException("odd"))
        keys.failing.add(IllegalStateException("odd"))
        keys.failing.add(IllegalStateException("odd"))
        assertEquals("busy", PinKey.mac(xHex)["e"])
        assertEquals(0, keys.deletes)
    }

    @Test
    fun oddAnswersAreNotTaken() {
        PinKey.make()
        keys.fixed = ByteArray(32)
        assertEquals("bad", PinKey.mac(xHex)["e"])
        keys.fixed = ByteArray(16) { 3 }
        assertEquals("bad", PinKey.mac(xHex)["e"])
        keys.fixed = null
        keys.echo = true
        assertEquals("bad", PinKey.mac(xHex)["e"])
        assertEquals(0, keys.deletes)
    }

    @Test
    fun aHungCallIsLeftBehindAtTheDeadline() {
        PinKey.make()
        PinKey.nanos = System::nanoTime
        val gate = CountDownLatch(1)
        keys.hang = gate
        val t0 = System.nanoTime()
        val (m, why) = PinKey.sign(x, deadlineMs = 200)
        val took = (System.nanoTime() - t0) / 1_000_000
        gate.countDown()
        assertEquals(null, m)
        assertEquals("busy", why)
        assertTrue("waited $took ms", took < 2000)
        assertTrue(keys.has(PinKey.ALIAS))
    }

    @Test
    fun infoSaysWhatIsThere() {
        assertEquals(false, PinKey.info()["k"])
        PinKey.make()
        val i = PinKey.info()
        assertEquals(true, i["k"])
        assertEquals(PinKey.STRONGBOX, i["l"])
        assertEquals(34, i["v"])
        PinKey.drop()
        assertEquals(false, PinKey.info()["k"])
        assertEquals(null, notes.v)
    }
}
