// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import java.math.BigInteger
import java.security.KeyFactory
import java.security.MessageDigest
import java.security.PublicKey
import java.security.interfaces.RSAPublicKey
import java.security.spec.MGF1ParameterSpec
import java.security.spec.X509EncodedKeySpec
import javax.crypto.Cipher
import javax.crypto.spec.OAEPParameterSpec
import javax.crypto.spec.PSource

// what a finger opens, sealed to the public half of the fingerprint key.
// anyone may seal, only a finger opens. every seal has the same length,
// whatever it holds. no android here, so it runs in unit tests
object BioSeal {
    // 1: the rsa block alone. 2: the key's tag, then the block
    const val VERSION = 2
    private const val V1 = 1
    // bytes of the key's tag at the head of a seal
    const val TAG = 8
    const val TRANSFORM = "RSA/ECB/OAEPWithSHA-256AndMGF1Padding"

    // the keystore takes sha-1 only for mgf1
    val OAEP = OAEPParameterSpec(
        "SHA-256",
        "MGF1",
        MGF1ParameterSpec.SHA1,
        PSource.PSpecified.DEFAULT,
    )

    // a seal as read: its form, the key's tag (empty in form 1), the rsa block
    class Sealed(val version: Int, val tag: ByteArray, val block: ByteArray)

    // the keystore's public key, as a plain one any provider encrypts with
    fun plain(pub: PublicKey): PublicKey =
        KeyFactory.getInstance(pub.algorithm).generatePublic(X509EncodedKeySpec(pub.encoded))

    // the same for every seal made to one key, whatever it opens. from the
    // numbers alone, so no provider's encoding moves it
    fun tag(pub: PublicKey): ByteArray {
        val r = plain(pub) as RSAPublicKey
        val d = MessageDigest.getInstance("SHA-256")
        d.update("kryfo seal key".toByteArray(Charsets.US_ASCII))
        for (x in listOf(r.modulus, r.publicExponent)) {
            val b = x.toByteArray()
            d.update(byteArrayOf((b.size shr 8).toByte(), b.size.toByte()))
            d.update(b)
        }
        return d.digest().copyOf(TAG)
    }

    fun seal(pub: PublicKey, opens: String): String {
        val c = Cipher.getInstance(TRANSFORM)
        c.init(Cipher.ENCRYPT_MODE, pub, OAEP)
        val block = c.doFinal(opens.toByteArray(Charsets.UTF_8))
        return hex(byteArrayOf(VERSION.toByte()) + tag(pub) + block)
    }

    // the seal, or null for anything that is not one
    fun parse(seal: String): Sealed? {
        if (seal.length < 4 || seal.length % 2 != 0) return null
        val b = ByteArray(seal.length / 2)
        for (i in b.indices) {
            val hi = Character.digit(seal[2 * i], 16)
            val lo = Character.digit(seal[2 * i + 1], 16)
            if (hi < 0 || lo < 0) return null
            b[i] = ((hi shl 4) or lo).toByte()
        }
        return when (b[0].toInt()) {
            V1 -> Sealed(V1, ByteArray(0), b.copyOfRange(1, b.size))
            VERSION ->
                if (b.size <= 1 + TAG) {
                    null
                } else {
                    Sealed(VERSION, b.copyOfRange(1, 1 + TAG), b.copyOfRange(1 + TAG, b.size))
                }
            else -> null
        }
    }

    // whether the seal can be [pub]'s, told from the public half alone: a
    // seal for another key opens nothing and needs no finger and no decrypt
    fun fits(s: Sealed, pub: PublicKey): Boolean {
        val n = (plain(pub) as? RSAPublicKey ?: return false).modulus
        if (s.block.size != (n.bitLength() + 7) / 8) return false
        if (BigInteger(1, s.block) >= n) return false
        return s.version == V1 || MessageDigest.isEqual(s.tag, tag(pub))
    }

    // a cipher the finger has unlocked opens it: "ok" with what it holds,
    // "none" when it was sealed to another key, "refused" when the keystore
    // would not finish what the finger began. never by the exception's
    // type, which differs from one provider and one keystore to the next
    fun open(c: Cipher, s: Sealed, pub: PublicKey): Pair<String, String?> {
        if (!fits(s, pub)) return "none" to null
        return try {
            "ok" to String(c.doFinal(s.block), Charsets.UTF_8)
        } catch (e: IllegalStateException) {
            // a cipher never started: the seal was not even tried
            "refused" to null
        } catch (e: Exception) {
            // a tagged seal is this key's, so this key refused it. one from
            // before tags may be any key's of the same size
            (if (s.version == V1) "none" else "refused") to null
        }
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
