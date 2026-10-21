// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Activity
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Log
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.PublicKey
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import javax.crypto.Cipher

// fingerprint unlock: what a finger opens is sealed (BioSeal) to a key pair
// whose private half only a finger unlocks, and which the phone drops when
// a finger is added. only fingers enrolled before the seal open it, and
// what it opens is known only once one has. android 9 and later.
object BioKey {
    private const val ALIAS = "kryfo_bio_seal"
    // the key from before seals: nothing opens with it any more
    private const val OLD_ALIAS = "kryfo_bio_unlock"

    fun ready(): Boolean = Build.VERSION.SDK_INT >= 28

    // every key change in the order asked for, off the main thread: a
    // delete never lands between another seal's delete and its new key
    val work: ExecutorService = Executors.newSingleThreadExecutor()

    // the keystore. unit tests stand in plain keys
    interface Keys {
        fun make(alias: String)
        fun public(alias: String): PublicKey?
        fun private(alias: String): PrivateKey?
        // when the key was made, which tells one key from the next
        fun madeAt(alias: String): Long?
        fun delete(alias: String)
    }

    object Store : Keys {
        private fun store(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

        override fun make(alias: String) {
            // sealing uses the public half outside the keystore
            val b = KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_DECRYPT)
                .setKeySize(2048)
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
                .setUserAuthenticationRequired(true)
                .setInvalidatedByBiometricEnrollment(true)
            if (Build.VERSION.SDK_INT >= 30) {
                b.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
            }
            // the mgf1 digest the opener asks for, named on the key: some
            // keystores take none that the key does not name
            if (Build.VERSION.SDK_INT >= 35) {
                try {
                    b.setMgf1Digests(KeyProperties.DIGEST_SHA1)
                } catch (_: Exception) {
                }
            }
            KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, "AndroidKeyStore")
                .apply { initialize(b.build()) }
                .generateKeyPair()
        }

        override fun public(alias: String): PublicKey? = store().getCertificate(alias)?.publicKey

        override fun private(alias: String): PrivateKey? = store().getKey(alias, null) as? PrivateKey

        override fun madeAt(alias: String): Long? = store().getCreationDate(alias)?.time

        override fun delete(alias: String) = store().deleteEntry(alias)
    }

    @Volatile
    var keys: Keys = Store

    // a cipher the prompt can unlock: the keystore starts the decrypt here
    private fun opener(key: PrivateKey): Cipher =
        Cipher.getInstance(BioSeal.TRANSFORM).apply {
            init(Cipher.DECRYPT_MODE, key, BioSeal.OAEP)
        }

    // a new key, and [opens] sealed to it. the seal, or null when the phone
    // would not make a key that opens it. the key takes a moment to make,
    // so never on the main thread
    fun seal(opens: String): String? {
        if (!ready()) return null
        return try {
            delete()
            keys.make(ALIAS)
            val pub = keys.public(ALIAS) ?: throw IllegalStateException("no public key")
            // a key the keystore will not start a decrypt with never opens
            // its seal: refused now, while the switch can still say so
            opener(keys.private(ALIAS) ?: throw IllegalStateException("no private key"))
            BioSeal.seal(BioSeal.plain(pub), opens)
        } catch (e: Exception) {
            told("not made", e)
            delete()
            null
        }
    }

    fun delete() {
        for (a in listOf(ALIAS, OLD_ALIAS)) {
            try {
                keys.delete(a)
            } catch (_: Exception) {
            }
        }
    }

    // a cipher ready for the prompt, or why there is none: "none" (never
    // made, or gone), "invalidated" (a finger was added since, or the key
    // will not start any more), "error"
    fun cipher(): Pair<Cipher?, String> {
        if (!ready()) return null to "none"
        val made = try {
            keys.madeAt(ALIAS)
        } catch (_: Exception) {
            null
        }
        var last: Exception? = null
        repeat(2) {
            try {
                val key = keys.private(ALIAS) ?: return null to "none"
                return opener(key) to "ok"
            } catch (e: KeyPermanentlyInvalidatedException) {
                dropLater(made)
                return null to "invalidated"
            } catch (e: Exception) {
                last = e
            }
        }
        // a key that will not start twice opens nothing again: it goes, and
        // the pin makes a new one
        told("not started", last)
        dropLater(made)
        return null to "invalidated"
    }

    // the key that failed goes, in order with the seals, and only if it is
    // still that key: a seal that ran meanwhile made one that stays
    private fun dropLater(made: Long?) {
        work.execute {
            val now = try {
                keys.madeAt(ALIAS)
            } catch (_: Exception) {
                null
            }
            if (now == made) delete()
        }
    }

    // the class and the keystore's code only, for a person's own logcat
    private fun told(what: String, e: Throwable?) {
        try {
            var code = ""
            var c = e
            var depth = 0
            while (c != null && depth++ < 8) {
                if (Build.VERSION.SDK_INT >= 33 && c is android.security.KeyStoreException) {
                    code = " ${c.numericErrorCode}"
                }
                c = c.cause
            }
            val name = e?.javaClass?.simpleName?.let { " $it" } ?: ""
            Log.i("kryfo", "finger key $what$name$code")
        } catch (_: Throwable) {
        }
    }

    fun state(): String = cipher().second

    // the prompt, then the seal opened: "ok" with what it opens, or
    // "cancel", "lockout", "invalidated", "none", "refused", "error"
    fun unlock(
        activity: Activity,
        title: String,
        cancel: String,
        seal: String,
        done: (String, String?) -> Unit,
    ) {
        if (Build.VERSION.SDK_INT < 28) {
            done("none", null)
            return
        }
        val sealed = BioSeal.parse(seal)
        if (sealed == null) {
            done("none", null)
            return
        }
        val (c, why) = cipher()
        if (c == null) {
            done(why, null)
            return
        }
        var answered = false
        fun once(s: String, opens: String?) {
            if (answered) return
            answered = true
            done(s, opens)
        }
        val exec = activity.mainExecutor
        val prompt = BiometricPrompt.Builder(activity)
            .setTitle(title)
            .setNegativeButton(cancel, exec) { _, _ -> once("cancel", null) }
            .build()
        prompt.authenticate(
            BiometricPrompt.CryptoObject(c),
            CancellationSignal(),
            exec,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(r: BiometricPrompt.AuthenticationResult) {
                    // the key opens only right after a finger it was made for.
                    // a seal it cannot open was made for another key. rsa
                    // takes a moment, so not on the main thread
                    val cipher = r.cryptoObject?.cipher
                    Thread {
                        val (s, opens) =
                            if (cipher == null) "refused" to null else BioSeal.open(cipher, sealed)
                        if (s == "refused") told("refused", null)
                        exec.execute { once(s, opens) }
                    }.start()
                }

                override fun onAuthenticationError(code: Int, msg: CharSequence?) {
                    once(BioSeal.closed(code), null)
                }
            },
        )
    }
}
