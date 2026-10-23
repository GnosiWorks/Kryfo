// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import java.math.BigInteger
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.Provider
import java.security.Security
import java.security.interfaces.RSAPublicKey
import javax.crypto.Cipher
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BioSealTest {
    private val everyday = "00000000000000000000000000000001"
    private val decoy = "00000000000000000000000000000002"

    private fun pair(): KeyPair =
        KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()

    // every provider a unit test can open with: the jdk's, and the two that
    // robolectric puts in place for the whole test run. each throws its own
    // exception for a block another key sealed
    private val providers: List<Provider> = listOf(
        Security.getProvider("SunJCE"),
        provider("org.conscrypt.OpenSSLProvider"),
        provider("org.bouncycastle.jce.provider.BouncyCastleProvider"),
    )

    private fun provider(name: String): Provider =
        Class.forName(name).getDeclaredConstructor().newInstance() as Provider

    // the private half as the prompt hands it back
    private fun opener(p: KeyPair, by: Provider? = null): Cipher =
        (if (by == null) Cipher.getInstance(BioSeal.TRANSFORM) else Cipher.getInstance(BioSeal.TRANSFORM, by))
            .apply { init(Cipher.DECRYPT_MODE, p.private, BioSeal.OAEP) }

    // the smallest and the largest modulus of a few keys: a block the larger
    // one sealed lies above the smaller one's modulus often enough to draw
    private val keys = pool.first()
    private val larger = pool.last()
    private val n = (keys.public as RSAPublicKey).modulus

    companion object {
        private val pool: List<KeyPair> by lazy {
            List(6) {
                KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
            }.sortedBy { (it.public as RSAPublicKey).modulus }
        }
    }

    private fun hex(b: ByteArray) = b.joinToString("") { "%02x".format(it.toInt() and 0xff) }

    private fun unhex(s: String) = ByteArray(s.length / 2) { s.substring(2 * it, 2 * it + 2).toInt(16).toByte() }

    // a seal in the form from before tags: the version, then the block
    private fun v1(block: ByteArray) = "01" + hex(block)

    private fun block(seal: String) = BioSeal.parse(seal)!!.block

    // an rsa block that [other] sealed, above or below this key's modulus.
    // drawn until it is, so the case under test is the same every run
    private fun sealedBy(other: KeyPair, above: Boolean): ByteArray {
        val c = Cipher.getInstance(BioSeal.TRANSFORM)
        c.init(Cipher.ENCRYPT_MODE, other.public, BioSeal.OAEP)
        repeat(200_000) {
            val b = c.doFinal(decoy.toByteArray())
            if ((BigInteger(1, b) >= n) == above) return b
        }
        throw AssertionError("no block drawn")
    }

    @Test
    fun aSealOpensToWhatWasSealed() {
        for (by in providers) {
            for (opens in listOf(everyday, decoy)) {
                val seal = BioSeal.seal(BioSeal.plain(keys.public), opens)
                val sealed = BioSeal.parse(seal)
                assertNotNull(sealed)
                assertEquals(BioSeal.VERSION, sealed!!.version)
                assertEquals("ok" to opens, BioSeal.open(opener(keys, by), sealed, keys.public))
            }
        }
    }

    // a seal from before tags still opens, under every provider
    @Test
    fun anOldSealStillOpens() {
        for (by in providers) {
            val old = BioSeal.parse(v1(block(BioSeal.seal(keys.public, decoy))))!!
            assertEquals(1, old.version)
            assertTrue(BioSeal.fits(old, keys.public))
            assertEquals("ok" to decoy, BioSeal.open(opener(keys, by), old, keys.public))
        }
    }

    @Test
    fun theSealsOfEitherSideLookAlike() {
        val a = BioSeal.seal(keys.public, everyday)
        val b = BioSeal.seal(keys.public, decoy)
        assertEquals(a.length, b.length)
        assertEquals(2 * (1 + BioSeal.TAG + 256), a.length)
        // the version and the key's tag are the same whatever is sealed
        assertEquals(a.substring(0, 2 + 2 * BioSeal.TAG), b.substring(0, 2 + 2 * BioSeal.TAG))
        assertTrue(a.all { it in "0123456789abcdef" })
        // the same side sealed twice differs too: nothing to compare
        assertNotEquals(a, BioSeal.seal(keys.public, everyday))
        assertNotEquals(a.substring(2 + 2 * BioSeal.TAG), b.substring(2 + 2 * BioSeal.TAG))
        // a seal made again from an old one looks like any new one
        val again = BioSeal.seal(BioSeal.plain(keys.public), decoy)
        assertEquals(a.length, again.length)
        assertEquals(a.substring(0, 2 + 2 * BioSeal.TAG), again.substring(0, 2 + 2 * BioSeal.TAG))
    }

    // the tag is the key's, the same from the keystore's key or a plain copy,
    // and another key's differs
    @Test
    fun theTagIsTheKeys() {
        assertArrayEquals(BioSeal.tag(keys.public), BioSeal.tag(BioSeal.plain(keys.public)))
        assertEquals(BioSeal.TAG, BioSeal.tag(keys.public).size)
        assertFalse(BioSeal.tag(keys.public).contentEquals(BioSeal.tag(pair().public)))
        val sealed = BioSeal.parse(BioSeal.seal(keys.public, everyday))!!
        assertArrayEquals(BioSeal.tag(keys.public), sealed.tag)
    }

    // a tagged seal for another key is told apart before any decrypt, so no
    // provider's exception has a say, and nor does a cipher that cannot run
    @Test
    fun aTaggedSealForAnotherKeyOpensNothing() {
        val other = pair()
        val sealed = BioSeal.parse(BioSeal.seal(other.public, decoy))!!
        assertFalse(BioSeal.fits(sealed, keys.public))
        for (by in providers) {
            assertEquals("none" to null, BioSeal.open(opener(keys, by), sealed, keys.public))
        }
        assertEquals("none" to null, BioSeal.open(Cipher.getInstance(BioSeal.TRANSFORM), sealed, keys.public))
        // the block above or below this key's modulus, under this key's tag
        // all the same: still another key's, and this key refuses it
        val tag = hex(BioSeal.tag(keys.public))
        for (above in listOf(false, true)) {
            val forged = BioSeal.parse("02" + tag + hex(sealedBy(larger, above)))!!
            for (by in providers) {
                val r = BioSeal.open(opener(keys, by), forged, keys.public)
                assertEquals(if (above) "none" to null else "refused" to null, r)
            }
        }
    }

    // the case that came out "refused" in some runs: an old seal for another
    // key whose block lies above this key's modulus. conscrypt then throws
    // IllegalBlockSizeException and bouncy castle DataLengthException, not
    // BadPaddingException. drawn on purpose here, under each provider
    @Test
    fun anOldSealForAnotherKeyOpensNothingUnderEveryProvider() {
        for (above in listOf(false, true)) {
            val old = BioSeal.parse(v1(sealedBy(larger, above)))!!
            assertEquals(!above, BioSeal.fits(old, keys.public))
            for (by in providers) {
                assertEquals(
                    "${by.name} above=$above",
                    "none" to null,
                    BioSeal.open(opener(keys, by), old, keys.public),
                )
            }
        }
        // the largest block there is, and the modulus itself
        for (b in listOf(ByteArray(256) { -1 }, n.toByteArray().copyOfRange(1, 257))) {
            val old = BioSeal.parse(v1(b))!!
            assertFalse(BioSeal.fits(old, keys.public))
            for (by in providers) {
                assertEquals("none" to null, BioSeal.open(opener(keys, by), old, keys.public))
            }
        }
    }

    @Test
    fun anythingButASealIsRefused() {
        val good = BioSeal.seal(keys.public, everyday)
        assertNull(BioSeal.parse(""))
        assertNull(BioSeal.parse("01"))
        assertNull(BioSeal.parse("02"))
        assertNull(BioSeal.parse(good.substring(1)))
        assertNull(BioSeal.parse("zz" + good.substring(2)))
        assertNull(BioSeal.parse("03" + good.substring(2)))
        assertNull(BioSeal.parse("00" + good.substring(2)))
        // a tag and nothing after it
        assertNull(BioSeal.parse(good.substring(0, 2 + 2 * BioSeal.TAG)))
    }

    // cut short or run long, in either form: parsed, but opens nothing and
    // never reaches a decrypt
    @Test
    fun aCutSealOpensNothing() {
        val good = BioSeal.seal(keys.public, everyday)
        val old = v1(block(good))
        for (s in listOf(good, old)) {
            for (cut in listOf(s.dropLast(2), s.dropLast(4), s + "00", s.substring(0, s.length / 4 * 2))) {
                val sealed = BioSeal.parse(cut)!!
                assertFalse(BioSeal.fits(sealed, keys.public))
                for (by in providers) {
                    assertEquals("none" to null, BioSeal.open(opener(keys, by), sealed, keys.public))
                }
            }
        }
        // a tag cut by a byte moves the block: another key's to the reader
        val moved = BioSeal.parse(good.substring(0, 2) + good.substring(4))!!
        assertEquals("none" to null, BioSeal.open(opener(keys), moved, keys.public))
    }

    // a finger the keystore would not finish with is not a seal for another
    // key: the app says so rather than asking for the pin again and again
    @Test
    fun aKeystoreThatWillNotFinishIsToldApart() {
        for (s in listOf(BioSeal.seal(keys.public, everyday), v1(block(BioSeal.seal(keys.public, decoy))))) {
            val sealed = BioSeal.parse(s)!!
            // a cipher never started, as when the prompt's key went away
            val unstarted = Cipher.getInstance(BioSeal.TRANSFORM)
            assertEquals("refused" to null, BioSeal.open(unstarted, sealed, keys.public))
        }
        // a tagged seal that this key's cipher will not finish: a cipher on
        // another key stands in for the keystore saying no
        val sealed = BioSeal.parse(BioSeal.seal(keys.public, everyday))!!
        for (by in providers) {
            assertEquals("refused" to null, BioSeal.open(opener(pair(), by), sealed, keys.public))
        }
    }

    // another key's tagged seal whose block lies under this key's modulus,
    // so only the tag tells it apart. drawn below on purpose, every run
    @Test
    fun anotherKeysTagAloneOpensNothing() {
        val block = sealedBy(larger, above = false)
        val other = BioSeal.parse("02" + hex(BioSeal.tag(larger.public)) + hex(block))!!
        assertFalse(BioSeal.tag(larger.public).contentEquals(BioSeal.tag(keys.public)))
        // the same block would fit this key: only the tag says no
        assertTrue(BioSeal.fits(BioSeal.parse(v1(block))!!, keys.public))
        assertFalse(BioSeal.fits(other, keys.public))
        for (by in providers) {
            assertEquals("none" to null, BioSeal.open(opener(keys, by), other, keys.public))
        }
        // and not even a cipher that would throw anything is asked
        val loud = failingCipher(IllegalThreadStateException("asked"), keys.public)
        assertEquals("none" to null, BioSeal.open(loud, other, keys.public))
        // a real seal for the other key, drawn below too, reads the same
        val real = BioSeal.parse(BioSeal.seal(larger.public, decoy))!!
        assertFalse(BioSeal.fits(real, keys.public))
    }

    // the keystore busy with the operation is not a refusal: try again
    @Test
    fun aBusyFinishIsAnError() {
        for (s in listOf(BioSeal.seal(keys.public, everyday), v1(block(BioSeal.seal(keys.public, decoy))))) {
            val sealed = BioSeal.parse(s)!!
            val busy = failingCipher(IllegalThreadStateException("busy"), keys.public)
            assertEquals("error" to null, BioSeal.open(busy, sealed, keys.public))
            val wrapped = failingCipher(
                javax.crypto.IllegalBlockSizeException().apply { initCause(IllegalThreadStateException()) },
                keys.public,
            )
            assertEquals("error" to null, BioSeal.open(wrapped, sealed, keys.public))
            // anything else keeps its answer
            val no = failingCipher(javax.crypto.IllegalBlockSizeException(), keys.public)
            assertEquals(
                (if (sealed.version == 1) "none" else "refused") to null,
                BioSeal.open(no, sealed, keys.public),
            )
        }
    }

    // a public half no provider reads: an answer, never a throw
    @Test
    fun aPublicHalfThatWillNotReadIsAnError() {
        val sealed = BioSeal.parse(BioSeal.seal(keys.public, everyday))!!
        val odd = object : java.security.PublicKey {
            override fun getAlgorithm() = "none such"
            override fun getFormat() = "X.509"
            override fun getEncoded() = ByteArray(4)
        }
        assertEquals("error" to null, BioSeal.open(opener(keys), sealed, odd))
    }

    @Test
    fun aLockedSensorIsToldApartFromACancel() {
        assertEquals("lockout", BioSeal.closed(BioSeal.LOCKOUT))
        assertEquals("lockout", BioSeal.closed(BioSeal.LOCKOUT_PERMANENT))
        // user cancel, negative button, timeout
        for (code in listOf(10, 13, 3, 5)) {
            assertEquals("cancel", BioSeal.closed(code))
        }
    }

    @Test
    fun theLockoutCodesAreAndroids() {
        assertEquals(
            android.hardware.biometrics.BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT,
            BioSeal.LOCKOUT,
        )
        assertEquals(
            android.hardware.biometrics.BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT_PERMANENT,
            BioSeal.LOCKOUT_PERMANENT,
        )
    }

    // the hex helpers here agree with the seal's own
    @Test
    fun theTestsReadSealsAsTheAppDoes() {
        val s = BioSeal.seal(keys.public, everyday)
        assertEquals(s, hex(unhex(s)))
        assertArrayEquals(unhex(s).copyOfRange(1 + BioSeal.TAG, unhex(s).size), block(s))
    }
}
