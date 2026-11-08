// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import java.security.PublicKey
import javax.crypto.Cipher

// a cipher whose finish throws [e], as the keystore's does once the
// finger was taken
fun failingCipher(e: Exception, pub: PublicKey): Cipher {
    val spi = object : javax.crypto.CipherSpi() {
        override fun engineSetMode(mode: String?) {}
        override fun engineSetPadding(padding: String?) {}
        override fun engineGetBlockSize() = 0
        override fun engineGetOutputSize(inputLen: Int) = 256
        override fun engineGetIV(): ByteArray? = null
        override fun engineGetParameters(): java.security.AlgorithmParameters? = null
        override fun engineInit(opmode: Int, key: java.security.Key?, random: java.security.SecureRandom?) {}
        override fun engineInit(
            opmode: Int,
            key: java.security.Key?,
            params: java.security.spec.AlgorithmParameterSpec?,
            random: java.security.SecureRandom?,
        ) {}
        override fun engineInit(
            opmode: Int,
            key: java.security.Key?,
            params: java.security.AlgorithmParameters?,
            random: java.security.SecureRandom?,
        ) {}
        override fun engineUpdate(input: ByteArray?, inputOffset: Int, inputLen: Int): ByteArray? = null
        override fun engineUpdate(
            input: ByteArray?,
            inputOffset: Int,
            inputLen: Int,
            output: ByteArray?,
            outputOffset: Int,
        ) = 0
        override fun engineDoFinal(input: ByteArray?, inputOffset: Int, inputLen: Int): ByteArray =
            throw e
        override fun engineDoFinal(
            input: ByteArray?,
            inputOffset: Int,
            inputLen: Int,
            output: ByteArray?,
            outputOffset: Int,
        ): Int = throw e
    }
    val by = object : java.security.Provider("stand-in", 1.0, "a keystore that fails") {}
    return object : Cipher(spi, by, BioSeal.TRANSFORM) {}.apply {
        init(Cipher.DECRYPT_MODE, pub)
    }
}
