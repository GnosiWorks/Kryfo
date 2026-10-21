// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import java.security.KeyFactory
import java.security.PublicKey
import java.security.spec.MGF1ParameterSpec
import java.security.spec.X509EncodedKeySpec
import javax.crypto.BadPaddingException
import javax.crypto.Cipher
import javax.crypto.spec.OAEPParameterSpec
import javax.crypto.spec.PSource

// what a finger opens, sealed to the public half of the fingerprint key.
// anyone may seal, only a finger opens. every seal has the same length,
// whatever it holds. no android here, so it runs in unit tests
object BioSeal {
    private const val VERSION = 1
    const val TRANSFORM = "RSA/ECB/OAEPWithSHA-256AndMGF1Padding"

    // the keystore takes sha-1 only for mgf1
    val OAEP = OAEPParameterSpec(
        "SHA-256",
        "MGF1",
        MGF1ParameterSpec.SHA1,
        PSource.PSpecified.DEFAULT,
    )

    // the keystore's public key, as a plain one any provider encrypts with
    fun plain(pub: PublicKey): PublicKey =
        KeyFactory.getInstance(pub.algorithm).generatePublic(X509EncodedKeySpec(pub.encoded))

    fun seal(pub: PublicKey, opens: String): String {
        val c = Cipher.getInstance(TRANSFORM)
        c.init(Cipher.ENCRYPT_MODE, pub, OAEP)
        return hex(byteArrayOf(VERSION.toByte()) + c.doFinal(opens.toByteArray(Charsets.UTF_8)))
    }

    // the sealed bytes, or null for anything that is not a seal
    fun parse(seal: String): ByteArray? {
        if (seal.length < 4 || seal.length % 2 != 0) return null
        val b = ByteArray(seal.length / 2)
        for (i in b.indices) {
            val hi = Character.digit(seal[2 * i], 16)
            val lo = Character.digit(seal[2 * i + 1], 16)
            if (hi < 0 || lo < 0) return null
            b[i] = ((hi shl 4) or lo).toByte()
        }
        if (b[0].toInt() != VERSION) return null
        return b.copyOfRange(1, b.size)
    }

    // a cipher the finger has unlocked opens it: "ok" with what it holds,
    // "none" when it was sealed to another key, "refused" when the keystore
    // would not finish what the finger began
    fun open(c: Cipher, sealed: ByteArray): Pair<String, String?> = try {
        "ok" to String(c.doFinal(sealed), Charsets.UTF_8)
    } catch (e: BadPaddingException) {
        "none" to null
    } catch (e: Exception) {
        "refused" to null
    }

    // why the prompt closed. too many wrong fingers lock the sensor for a
    // while: the pin is the way in, and the app counts nothing for it
    fun closed(code: Int): String = when (code) {
        LOCKOUT, LOCKOUT_PERMANENT -> "lockout"
        else -> "cancel"
    }

    // BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT and _LOCKOUT_PERMANENT
    const val LOCKOUT = 7
    const val LOCKOUT_PERMANENT = 9

    private fun hex(b: ByteArray): String {
        val d = "0123456789abcdef"
        val sb = StringBuilder(b.size * 2)
        for (x in b) {
            val v = x.toInt() and 0xff
            sb.append(d[v shr 4]).append(d[v and 0xf])
        }
        return sb.toString()
    }
}
