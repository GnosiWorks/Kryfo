// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Application
import android.security.keystore.KeyPermanentlyInvalidatedException
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.PrivateKey
import java.security.ProviderException
import java.security.PublicKey
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

        // a private key the rsa cipher will not start with
        private val wrongKind: PrivateKey =
            KeyPairGenerator.getInstance("EC").apply { initialize(256) }.generateKeyPair().private

        override fun make(alias: String) {
            if (refuseMake) throw ProviderException("keystore refused")
            made[alias] =
                KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
            at[alias] = ++clock
        }

        override fun public(alias: String): PublicKey? = made[alias]?.public

        override fun private(alias: String): PrivateKey? {
            if (invalidated && made.containsKey(alias)) {
                throw KeyPermanentlyInvalidatedException()
            }
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

    @After
    fun back() {
        BioKey.keys = BioKey.Store
    }

    @Test
    fun aGoodKeySealsAndOpens() {
        val seal = BioKey.seal(everyday)
        assertNotNull(seal)
        val (c, why) = BioKey.cipher()
        assertEquals("ok", why)
        assertEquals("ok" to everyday, BioSeal.open(c!!, BioSeal.parse(seal!!)!!))
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
