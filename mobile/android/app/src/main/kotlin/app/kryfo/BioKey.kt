// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Activity
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
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

    private fun store(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    // a new key, and [opens] sealed to it. the seal, or null. the key takes
    // a moment to make, so never on the main thread
    fun seal(opens: String): String? {
        if (!ready()) return null
        return try {
            delete()
            val b = KeyGenParameterSpec.Builder(
                ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setKeySize(2048)
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
                .setUserAuthenticationRequired(true)
                .setInvalidatedByBiometricEnrollment(true)
            if (Build.VERSION.SDK_INT >= 30) {
                b.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
            }
            KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, "AndroidKeyStore")
                .apply { initialize(b.build()) }
                .generateKeyPair()
            val pub = store().getCertificate(ALIAS)?.publicKey
                ?: throw IllegalStateException("no public key")
            BioSeal.seal(BioSeal.plain(pub), opens)
        } catch (e: Exception) {
            delete()
            null
        }
    }

    fun delete() {
        for (a in listOf(ALIAS, OLD_ALIAS)) {
            try {
                store().deleteEntry(a)
            } catch (_: Exception) {
            }
        }
    }

    // a cipher ready for the prompt, or why there is none: "none" (never
    // made, or gone), "invalidated" (a finger was added since), "error"
    fun cipher(): Pair<Cipher?, String> {
        if (!ready()) return null to "none"
        return try {
            val key = store().getKey(ALIAS, null) as? PrivateKey ?: return null to "none"
            val c = Cipher.getInstance(BioSeal.TRANSFORM)
            c.init(Cipher.DECRYPT_MODE, key, BioSeal.OAEP)
            c to "ok"
        } catch (e: KeyPermanentlyInvalidatedException) {
            delete()
            null to "invalidated"
        } catch (e: Exception) {
            null to "error"
        }
    }

    fun state(): String = cipher().second

    // the prompt, then the seal opened: "ok" with what it opens, or
    // "cancel", "lockout", "invalidated", "none", "error"
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
                    // a seal it cannot open was made for another key
                    val cipher = r.cryptoObject?.cipher
                    val opens = if (cipher == null) null else BioSeal.open(cipher, sealed)
                    if (opens == null) once("none", null) else once("ok", opens)
                }

                override fun onAuthenticationError(code: Int, msg: CharSequence?) {
                    once(BioSeal.closed(code), null)
                }
            },
        )
    }
}
