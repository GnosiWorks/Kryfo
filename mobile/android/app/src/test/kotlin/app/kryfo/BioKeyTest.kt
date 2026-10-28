// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Application
import android.security.keystore.KeyPermanentlyInvalidatedException
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.PrivateKey
import java.security.ProviderException
import java.security.PublicKey
import javax.crypto.Cipher
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

// the fingerprint key's life on a phone whose keystore makes a key but will
// not start a decrypt with it, or will not make one at all
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class BioKeyTest {
    private val everyday = "00000000000000000000000000000001"

    private class Plain : BioKey.Keys {
        val made = mutableMapOf<String, KeyPair>()
        val at = mutableMapOf<String, Long>()
        private var clock = 0L
        var refuseMake = false
        var refuseStart = false
        var invalidated = false
        // starts that fail with this, one per start, as a busy keystore does
        val busy = ArrayDeque<Exception>()
        var publicFails = false

        // a private key the rsa cipher will not start with
        private val wrongKind: PrivateKey =
            KeyPairGenerator.getInstance("EC").apply { initialize(256) }.generateKeyPair().private

        override fun make(alias: String) {
            if (refuseMake) throw ProviderException("keystore refused")
            made[alias] =
                KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
            at[alias] = ++clock
        }

        override fun public(alias: String): PublicKey? {
            if (publicFails) throw ProviderException("keystore not answering")
            return made[alias]?.public
        }

        override fun private(alias: String): PrivateKey? {
            if (invalidated && made.containsKey(alias)) {
                throw KeyPermanentlyInvalidatedException()
            }
            busy.removeFirstOrNull()?.let { throw it }
            val p = made[alias]?.private ?: return null
            return if (refuseStart) wrongKind else p
        }

        override fun madeAt(alias: String): Long? = at[alias]

        override fun delete(alias: String) {
            made.remove(alias)
            at.remove(alias)
        }
    }

    private val keys = Plain().also { BioKey.keys = it }

    // the key work queued so far has run
    private fun settled() = BioKey.work.submit {}.get()

    // the pauses cipher() asked for, without waiting them out
    private val paused = mutableListOf<Long>().also { p -> BioKey.pause = { p.add(it) } }

    @After
    fun back() {
        BioKey.keys = BioKey.Store
        BioKey.pause = { Thread.sleep(it) }
    }

    // a keystore code as android hands it over, inside the cipher's own
    // exception
    private fun keystore(code: Int): Exception {
        val k = android.security.KeyStoreException::class.java
            .getDeclaredConstructor(Int::class.javaPrimitiveType, String::class.java)
            .apply { isAccessible = true }
            .newInstance(code, "keystore")
        return javax.crypto.IllegalBlockSizeException().apply { initCause(k) }
    }

    // a busy keystore at the start is not a dead key: "error", the key
    // stays, and the second try comes after a pause
    @Test
    fun aBusyKeystoreKeepsTheKey() {
        assertNotNull(BioKey.seal(everyday))
        for (busy in listOf(
            android.security.keystore.BackendBusyException(50),
            ProviderException("keystore busy"),
            keystore(-28),
        )) {
            keys.busy.addAll(listOf(busy, busy))
            assertEquals(null to "error", BioKey.cipher())
            settled()
            assertEquals(1, keys.made.size)
        }
        assertEquals(List(3) { BioKey.RETRY_MS }, paused)
        // busy once only: the second try starts
        keys.busy.add(ProviderException("keystore busy"))
        assertEquals("ok", BioKey.cipher().second)
        assertEquals("ok", BioKey.state())
        // a key that is really gone or will not start still goes
        keys.busy.addAll(List(2) { java.security.InvalidKeyException("not this key") })
        assertEquals(null to "invalidated", BioKey.cipher())
        settled()
        assertTrue(keys.made.isEmpty())
    }

    @Test
    fun aBusyKeystoreAsksForNoPin() {
        val sealed = BioSeal.parse(BioKey.seal(everyday)!!)!!
        keys.busy.addAll(List(2) { ProviderException("keystore busy") })
        assertEquals("error", BioKey.ask(sealed).why)
        // a public half that will not read is no reason for a new key
        keys.publicFails = true
        assertEquals("error", BioKey.ask(sealed).why)
        settled()
        assertEquals(1, keys.made.size)
        keys.publicFails = false
        assertEquals("ok", BioKey.ask(sealed).why)
    }

    // after the finger, a passing failure on a tagged seal is "error", so
    // the finger stays on. a real refusal is still "refused"
    @Test
    fun aPassingFailureAfterTheFingerKeepsTheFinger() {
        val sealed = BioSeal.parse(BioKey.seal(everyday)!!)!!
        val pub = keys.made.values.single().public
        val ask = BioKey.ask(sealed)
        for (e in listOf(
            // the same operation twice (OPERATION_BUSY)
            IllegalThreadStateException("busy"),
            // the operation lost, as when the keystore restarts
            keystore(-28),
            // the secure hardware busy
            keystore(-48),
        )) {
            assertEquals(e.toString(), Triple("error", null, null), BioKey.opened(ask, sealed, failingCipher(e, pub)))
        }
        for (e in listOf(
            // user not authenticated
            keystore(-26),
            // what a seal this key will not open gives
            keystore(-1000),
            javax.crypto.BadPaddingException(),
            java.security.ProviderException("keystore said no"),
        )) {
            assertEquals(e.toString(), Triple("refused", null, null), BioKey.opened(ask, sealed, failingCipher(e, pub)))
        }
    }

    // nothing thrown while the seal is opened reaches the thread
    @Test
    fun aPublicHalfThatWillNotReadThrowsNothing() {
        val sealed = BioSeal.parse(BioKey.seal(everyday)!!)!!
        val ask = BioKey.ask(sealed)
        val odd = object : PublicKey {
            override fun getAlgorithm() = "none such"
            override fun getFormat() = "X.509"
            override fun getEncoded() = ByteArray(4)
        }
        val broken = BioKey.Ask("ok", ask.cipher, odd, ask.made)
        assertEquals(Triple("error", null, null), BioKey.opened(broken, sealed, ask.cipher))
    }

    private val decoy = "00000000000000000000000000000002"

    // the cipher the prompt hands back once a finger was taken
    private fun finger(ask: BioKey.Ask): Cipher? = ask.cipher

    private fun opener(p: KeyPair): Cipher =
        Cipher.getInstance(BioSeal.TRANSFORM).apply {
            init(Cipher.DECRYPT_MODE, p.private, BioSeal.OAEP)
        }

    // a seal in the form from before tags, for the key there now or another
    private fun v1(pub: PublicKey, opens: String): String {
        val c = Cipher.getInstance(BioSeal.TRANSFORM)
        c.init(Cipher.ENCRYPT_MODE, pub, BioSeal.OAEP)
        return "01" + c.doFinal(opens.toByteArray()).joinToString("") { "%02x".format(it) }
    }

    private fun rsa(): KeyPair =
        KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()

    @Test
    fun aGoodKeySealsAndOpens() {
        val seal = BioKey.seal(everyday)
        assertNotNull(seal)
        val (c, why) = BioKey.cipher()
        assertEquals("ok", why)
        val sealed = BioSeal.parse(seal!!)!!
        assertEquals(BioSeal.VERSION, sealed.version)
        assertEquals("ok" to everyday, BioSeal.open(c!!, sealed, keys.made.values.single().public))
        val ask = BioKey.ask(sealed)
        assertEquals("ok", ask.why)
        assertEquals(Triple("ok", everyday, null), BioKey.opened(ask, sealed, finger(ask)))
    }

    // a seal the key there now was not made for: no prompt, and the pin
    // makes a new one. the key stays for that seal to replace
    @Test
    fun aSealForAnotherKeyAsksForNoFinger() {
        val old = BioSeal.parse(BioKey.seal(decoy)!!)!!
        assertNotNull(BioKey.seal(everyday))
        val ask = BioKey.ask(old)
        assertEquals("none", ask.why)
        assertNull(ask.cipher)
        settled()
        assertEquals(1, keys.made.size)
        // and a key that is gone as well
        BioKey.delete()
        assertEquals("none", BioKey.ask(old).why)
    }

    // a seal from before tags opens as it did, and comes back made again
    // with the tag, for the same key and the same side
    @Test
    fun anOldSealOpensAndComesBackTagged() {
        assertNotNull(BioKey.seal(everyday))
        val pub = keys.made.values.single().public
        for (opens in listOf(everyday, decoy)) {
            val old = BioSeal.parse(v1(pub, opens))!!
            assertEquals(1, old.version)
            val ask = BioKey.ask(old)
            assertEquals("ok", ask.why)
            val (r, got, again) = BioKey.opened(ask, old, finger(ask))
            assertEquals("ok" to opens, r to got)
            val tagged = BioSeal.parse(again!!)!!
            assertEquals(BioSeal.VERSION, tagged.version)
            assertTrue(BioSeal.fits(tagged, pub))
            val ask2 = BioKey.ask(tagged)
            assertEquals(Triple("ok", opens, null), BioKey.opened(ask2, tagged, finger(ask2)))
        }
    }

    // an old seal for another key cannot be told from the public half when
    // its block fits under the modulus: the finger is asked, and whatever
    // the decrypt throws it is "none", so the pin makes a new seal
    @Test
    fun anOldSealForAnotherKeyIsNoneAfterTheFinger() {
        assertNotNull(BioKey.seal(everyday))
        val n = (keys.made.values.single().public as java.security.interfaces.RSAPublicKey).modulus
        val other = rsa()
        var s: String
        do {
            s = v1(other.public, decoy)
        } while (java.math.BigInteger(1, BioSeal.parse(s)!!.block) >= n)
        val old = BioSeal.parse(s)!!
        val ask = BioKey.ask(old)
        assertEquals("ok", ask.why)
        assertEquals(Triple("none", null, null), BioKey.opened(ask, old, finger(ask)))
    }

    // a tagged seal for this key that the keystore will not finish is the
    // phone refusing, unless the key changed under the prompt: then the
    // seal was the old key's
    @Test
    fun aRefusalIsToldFromAKeyThatMoved() {
        val sealed = BioSeal.parse(BioKey.seal(everyday)!!)!!
        val ask = BioKey.ask(sealed)
        assertEquals("ok", ask.why)
        // a cipher on another key stands in for the keystore saying no
        assertEquals(Triple("refused", null, null), BioKey.opened(ask, sealed, opener(rsa())))
        assertEquals(Triple("refused", null, null), BioKey.opened(ask, sealed, null))
        assertEquals(
            Triple("refused", null, null),
            BioKey.opened(ask, sealed, Cipher.getInstance(BioSeal.TRANSFORM)),
        )
        assertNotNull(BioKey.seal(everyday))
        assertEquals(Triple("none", null, null), BioKey.opened(ask, sealed, opener(rsa())))
    }

    // an old seal opened just as a new key came: opens, but is not made
    // again for a key it was never opened with
    @Test
    fun anOldSealIsNotRemadeForANewKey() {
        assertNotNull(BioKey.seal(everyday))
        val old = BioSeal.parse(v1(keys.made.values.single().public, everyday))!!
        val ask = BioKey.ask(old)
        val c = finger(ask)
        assertNotNull(BioKey.seal(everyday))
        assertEquals(Triple("ok", everyday, null), BioKey.opened(ask, old, c))
    }

    @Test
    fun anInvalidatedKeyStillSaysSo() {
        val sealed = BioSeal.parse(BioKey.seal(everyday)!!)!!
        keys.invalidated = true
        assertEquals("invalidated", BioKey.ask(sealed).why)
    }

    // a key that would never open its seal is not handed out: the switch
    // can say the phone refused instead of turning on a finger that fails
    @Test
    fun aKeyThatWillNotStartGivesNoSeal() {
        keys.refuseStart = true
        assertNull(BioKey.seal(everyday))
        assertTrue(keys.made.isEmpty())
    }

    @Test
    fun aKeyThePhoneWillNotMakeGivesNoSeal() {
        keys.refuseMake = true
        assertNull(BioKey.seal(everyday))
        assertTrue(keys.made.isEmpty())
    }

    // a key that stopped starting after an update goes, so the pin makes a
    // new one rather than waking the same dead key at every start
    @Test
    fun aKeyThatStoppedStartingGoesAndWantsThePin() {
        assertNotNull(BioKey.seal(everyday))
        keys.refuseStart = true
        assertEquals(null to "invalidated", BioKey.cipher())
        settled()
        assertTrue(keys.made.isEmpty())
        assertEquals("none", BioKey.state())
    }

    @Test
    fun aNewFingerStillInvalidates() {
        assertNotNull(BioKey.seal(everyday))
        keys.invalidated = true
        assertEquals(null to "invalidated", BioKey.cipher())
        settled()
        assertTrue(keys.made.isEmpty())
    }

    // the drop runs in order with the seals, and only on the key that
    // failed: a seal that ran in between made a new one, and that one stays
    @Test
    fun aDropNeverTakesANewerKey() {
        assertNotNull(BioKey.seal(everyday))
        val gate = java.util.concurrent.CountDownLatch(1)
        BioKey.work.execute { gate.await() }
        // a seal asked for first, still waiting its turn
        val sealed = BioKey.work.submit<String?> {
            keys.refuseStart = false
            BioKey.seal(everyday)
        }
        keys.refuseStart = true
        assertEquals(null to "invalidated", BioKey.cipher())
        gate.countDown()
        assertNotNull(sealed.get())
        settled()
        assertEquals(1, keys.made.size)
        assertEquals("ok", BioKey.state())
    }

    @Test
    fun noKeyIsNone() {
        assertEquals(null to "none", BioKey.cipher())
    }

    // turning on again replaces whatever key was there
    @Test
    fun aNewSealReplacesTheOldKey() {
        assertNotNull(BioKey.seal(everyday))
        val first = keys.made.values.single()
        assertNotNull(BioKey.seal(everyday))
        assertTrue(keys.made.values.single() !== first)
    }
}
