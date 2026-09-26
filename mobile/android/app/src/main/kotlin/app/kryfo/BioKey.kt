// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Activity
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

// fingerprint unlock tied to a key the phone drops when a finger is added,
// so only fingers enrolled before it was turned on open kryfo. the key
// guards nothing, using it is the proof. android 9 and later.
object BioKey {
    private const val ALIAS = "kryfo_bio_unlock"

    fun ready(): Boolean = Build.VERSION.SDK_INT >= 28

    private fun store(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    fun create(): Boolean {
        if (!ready()) return false
        return try {
            delete()
            val b = KeyGenParameterSpec.Builder(
                ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setUserAuthenticationRequired(true)
                .setInvalidatedByBiometricEnrollment(true)
            if (Build.VERSION.SDK_INT >= 30) {
                b.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
            }
            KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
                .apply { init(b.build()) }
                .generateKey()
            true
        } catch (e: Exception) {
            false
        }
    }

    fun delete() {
        try {
            store().deleteEntry(ALIAS)
        } catch (_: Exception) {
        }
    }

    // a cipher ready for the prompt, or why there is none: "none" (never
    // made, or gone), "invalidated" (a finger was added since), "error"
    fun cipher(): Pair<Cipher?, String> {
        if (!ready()) return null to "none"
        return try {
            val key = store().getKey(ALIAS, null) as? SecretKey ?: return null to "none"
            val c = Cipher.getInstance("AES/GCM/NoPadding")
            c.init(Cipher.ENCRYPT_MODE, key)
            c to "ok"
        } catch (e: KeyPermanentlyInvalidatedException) {
            delete()
            null to "invalidated"
        } catch (e: Exception) {
            null to "error"
        }
    }

    fun state(): String = cipher().second

    // the prompt, with the key: "ok", "cancel", "invalidated", "none", "error"
    fun unlock(activity: Activity, title: String, cancel: String, done: (String) -> Unit) {
        val (c, why) = cipher()
        if (c == null) {
            done(why)
            return
        }
        var answered = false
        fun once(s: String) {
            if (answered) return
            answered = true
            done(s)
        }
        val exec = activity.mainExecutor
        val prompt = BiometricPrompt.Builder(activity)
            .setTitle(title)
            .setNegativeButton(cancel, exec) { _, _ -> once("cancel") }
            .build()
        prompt.authenticate(
            BiometricPrompt.CryptoObject(c),
            CancellationSignal(),
            exec,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(r: BiometricPrompt.AuthenticationResult) {
                    // using the key is the proof: it only works right after
                    // a finger the key was made for
                    val ok = try {
                        r.cryptoObject?.cipher?.doFinal(ByteArray(16)) != null
                    } catch (e: Exception) {
                        false
                    }
                    once(if (ok) "ok" else "error")
                }

                override fun onAuthenticationError(code: Int, msg: CharSequence?) {
                    once("cancel")
                }
            },
        )
    }
}
