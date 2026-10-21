// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import java.security.KeyPair
import java.security.KeyPairGenerator
import javax.crypto.Cipher
import org.junit.Assert.assertEquals
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

    // the private half as the prompt hands it back
    private fun opener(p: KeyPair): Cipher =
        Cipher.getInstance(BioSeal.TRANSFORM).apply {
            init(Cipher.DECRYPT_MODE, p.private, BioSeal.OAEP)
        }

    private val keys = pair()

    @Test
    fun aSealOpensToWhatWasSealed() {
        for (opens in listOf(everyday, decoy)) {
            val seal = BioSeal.seal(BioSeal.plain(keys.public), opens)
            val sealed = BioSeal.parse(seal)
            assertNotNull(sealed)
            assertEquals("ok" to opens, BioSeal.open(opener(keys), sealed!!))
        }
    }

    @Test
    fun theSealsOfEitherSideLookAlike() {
        val a = BioSeal.seal(keys.public, everyday)
        val b = BioSeal.seal(keys.public, decoy)
        assertEquals(a.length, b.length)
        assertEquals(a.substring(0, 2), b.substring(0, 2))
        assertTrue(a.all { it in "0123456789abcdef" })
        // the same side sealed twice differs too: nothing to compare
        assertNotEquals(a, BioSeal.seal(keys.public, everyday))
    }

    @Test
    fun aSealForAnotherKeyOpensNothing() {
        val other = pair()
        val sealed = BioSeal.parse(BioSeal.seal(other.public, decoy))!!
        assertEquals("none" to null, BioSeal.open(opener(keys), sealed))
    }

    @Test
    fun anythingButASealIsRefused() {
        val good = BioSeal.seal(keys.public, everyday)
        assertNull(BioSeal.parse(""))
        assertNull(BioSeal.parse("01"))
        assertNull(BioSeal.parse(good.substring(1)))
        assertNull(BioSeal.parse("zz" + good.substring(2)))
        assertNull(BioSeal.parse("02" + good.substring(2)))
        // cut short: parsed, but opens nothing
        val short = BioSeal.parse(good.substring(0, good.length - 2))!!
        assertEquals("none" to null, BioSeal.open(opener(keys), short))
    }

    // a finger the keystore would not finish with is not a seal for another
    // key: the app says so rather than asking for the pin again and again
    @Test
    fun aKeystoreThatWillNotFinishIsToldApart() {
        val sealed = BioSeal.parse(BioSeal.seal(keys.public, everyday))!!
        // a cipher never started, as when the prompt's key went away
        val unstarted = Cipher.getInstance(BioSeal.TRANSFORM)
        assertEquals("refused" to null, BioSeal.open(unstarted, sealed))
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
}
