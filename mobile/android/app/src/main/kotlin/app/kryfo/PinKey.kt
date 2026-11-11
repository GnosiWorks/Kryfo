// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.annotation.SuppressLint
import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.security.keystore.UserNotAuthenticatedException
import java.security.KeyStore
import java.security.SecureRandom
import java.util.concurrent.atomic.AtomicReference
import javax.crypto.KeyGenerator
import javax.crypto.Mac
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory

// the pin key: an hmac key the keystore keeps and never hands out. every pin
// check signs one value with it (engine/pin.go), so a copy of the pin table
// cannot be guessed at anywhere but on this phone. unlike the finger key it
// is never deleted on an error and never made over one that is there:
// entries sealed under it open with it only. the wipe and turning the lock
// off are its only deletes.
object PinKey {
    const val ALIAS = "kryfo_pin_mac"
    const val GEN = 1

    // what the check value signs: fixed, and never the 32 bytes of an x
    val KCV_INPUT: ByteArray = "kryfo pin kcv v3".toByteArray(Charsets.US_ASCII)

    // where the key lives, as the table's header keeps it
    const val SOFTWARE = 0
    const val TEE = 1
    const val STRONGBOX = 2

    // a strongbox slower than this per call makes the key in the tee instead
    const val SLOW_MS = 200L

    // how long one signing may take, retries included, before it is busy
    const val DEADLINE_MS = 10_000L

    // the keystore. unit tests stand in plain keys
    interface Keys {
        fun has(alias: String): Boolean
        // a 256-bit hmac-sha256 key. throws when the keystore will not
        fun make(alias: String, strongBox: Boolean, unlocked: Boolean)
        // throws Gone when there is no key under the alias
        fun mac(alias: String, input: ByteArray): ByteArray
        fun level(alias: String): Int?
        fun delete(alias: String)
    }

    class Gone : Exception("no pin key")

    // what making the key learned, beside it: the table's header has it too
    // once the table moves, this is for the time before
    interface Notes {
        fun read(): Pair<Int, Int>?
        fun write(unlocked: Int, level: Int)
        fun clear()
        // a make is under way, or stopped before its key passed its test
        fun making(): Boolean
        fun setMaking(on: Boolean)
        // the keystore here keeps keys in software only: no pin key is made,
        // the table stays as it was. holds for the build it was asked under
        fun soft(): Boolean = false
        fun setSoft() {}
    }

    object Store : Keys {
        private fun store(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

        override fun has(alias: String): Boolean = store().containsAlias(alias)

        override fun make(alias: String, strongBox: Boolean, unlocked: Boolean) {
            val b = KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN)
                .setKeySize(256)
            if (Build.VERSION.SDK_INT >= 28) {
                if (strongBox) b.setIsStrongBoxBacked(true)
                if (unlocked) b.setUnlockedDeviceRequired(true)
            }
            KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_HMAC_SHA256, "AndroidKeyStore")
                .apply { init(b.build()) }
                .generateKey()
        }

        override fun mac(alias: String, input: ByteArray): ByteArray {
            val key = store().getKey(alias, null) as? SecretKey ?: throw Gone()
            // one mac per call, finished or reset, so a failed one keeps no
            // keystore operation open
            val m = Mac.getInstance("HmacSHA256")
            m.init(key)
            try {
                return m.doFinal(input)
            } catch (e: Exception) {
                try {
                    m.reset()
                } catch (_: Exception) {
                }
                throw e
            }
        }

        override fun level(alias: String): Int? {
            val key = store().getKey(alias, null) as? SecretKey ?: return null
            val info = SecretKeyFactory.getInstance(key.algorithm, "AndroidKeyStore")
                .getKeySpec(key, KeyInfo::class.java) as KeyInfo
            if (Build.VERSION.SDK_INT >= 31) {
                return when (info.securityLevel) {
                    KeyProperties.SECURITY_LEVEL_STRONGBOX -> STRONGBOX
                    KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT,
                    KeyProperties.SECURITY_LEVEL_UNKNOWN_SECURE -> TEE
                    KeyProperties.SECURITY_LEVEL_SOFTWARE -> SOFTWARE
                    else -> null
                }
            }
            @Suppress("DEPRECATION")
            return if (info.isInsideSecureHardware) TEE else SOFTWARE
        }

        override fun delete(alias: String) = store().deleteEntry(alias)
    }

    // on disk before the keystore is touched: a process death mid-make
    // must still find the flag
    @SuppressLint("ApplySharedPref")
    private class Prefs(context: Context) : Notes {
        private val p = context.getSharedPreferences("kryfo_pin_key", Context.MODE_PRIVATE)
        override fun read(): Pair<Int, Int>? =
            if (!p.contains("l")) null else p.getInt("u", 0) to p.getInt("l", SOFTWARE)

        override fun write(unlocked: Int, level: Int) {
            p.edit().putInt("u", unlocked).putInt("l", level).commit()
        }

        override fun clear() {
            p.edit().clear().commit()
        }

        override fun making(): Boolean = p.getBoolean("m", false)

        override fun setMaking(on: Boolean) {
            p.edit().putBoolean("m", on).commit()
        }

        // an os update may bring a keystore with hardware: asked again then
        override fun soft(): Boolean = p.getBoolean("s", false) && p.getString("f", null) == build()

        override fun setSoft() {
            p.edit().putBoolean("s", true).putString("f", build()).commit()
        }

        private fun build(): String = Build.FINGERPRINT ?: ""
    }

    @Volatile
    var keys: Keys = Store

    @Volatile
    var notes: Notes? = null

    // whether the phone has a secure screen lock
    @Volatile
    var secure: () -> Boolean = { false }

    // tests stand in another android version, a clock and pauses that do
    // not wait
    @Volatile
    var sdk: Int = Build.VERSION.SDK_INT

    @Volatile
    var nanos: () -> Long = System::nanoTime

    @Volatile
    var pause: (Long) -> Unit = { Thread.sleep(it) }

    fun attach(context: Context) {
        val app = context.applicationContext
        notes = Prefs(app)
        secure = {
            try {
                (app.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isDeviceSecure
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun hasKey(): Boolean? = try {
        keys.has(ALIAS)
    } catch (_: Exception) {
        null
    }

    // how long apart the two lookups of goneSure are
    const val GONE_GAP_MS = 1000L

    // a keystore that is busy or restarting can answer "no such alias" for a
    // moment, so gone needs the lookup to say so twice, a second apart, with
    // the key itself not found in between. anything else is busy
    fun goneSure(): Boolean {
        if (hasKey() != false) return false
        pause(GONE_GAP_MS)
        val level = try {
            keys.level(ALIAS)
        } catch (_: Exception) {
            return false
        }
        if (level != null) return false
        return hasKey() == false
    }

    // {"k": a key is there, "u": it works only while the phone is unlocked,
    // "l": where it lives, "s": the phone has a screen lock, "v": android's
    // version, "n": no key, and none is made on this keystore}, or {"e": "busy"}
    fun info(): Map<String, Any> {
        // a key whose make has not finished its test is no key yet: dart then
        // asks for a make, which drops it and makes a tested one
        if (untested()) return mapOf("k" to false, "u" to 0, "l" to SOFTWARE, "s" to secure(), "v" to sdk)
        var has = hasKey() ?: return mapOf("e" to "busy")
        // the software note and a key never live together: no pause for it
        if (!has && isSoft()) {
            return mapOf("k" to false, "u" to 0, "l" to SOFTWARE, "s" to secure(), "v" to sdk, "n" to true)
        }
        // no key only when it holds a second later as well
        if (!has && !goneSure()) {
            has = hasKey() ?: return mapOf("e" to "busy")
            if (!has) return mapOf("e" to "busy")
        }
        val noted = notes?.read()
        val level = if (!has) {
            SOFTWARE
        } else {
            noted?.second ?: try {
                keys.level(ALIAS) ?: SOFTWARE
            } catch (_: Exception) {
                SOFTWARE
            }
        }
        return mapOf(
            "k" to has,
            "u" to (if (has) noted?.first ?: 0 else 0),
            "l" to level,
            "s" to secure(),
            "v" to sdk,
        )
    }

    // a new key, tested before it is used: strongbox when it is there, works
    // and is quick, else the tee. a key the keystore says it keeps in
    // software is not kept: no chip guards it, and a container's keystore
    // can lose it, so the table stays as it was. never over a key that is
    // there: that one is kept and described. {"k", "u", "l", "kc", "ms"},
    // or {"e": "refused" | "software"}
    // one at a time, from any engine: a second make never runs over the key
    // a first one just made and described
    @Synchronized
    fun make(): Map<String, Any> {
        var has = hasKey() ?: return mapOf("e" to "busy")
        // a key a make left behind untested (its delete failed, or the process
        // stopped) is never handed out: it goes first, or nothing is made
        if (has && notes?.making() == true) {
            dropQuietly()
            has = hasKey() ?: return mapOf("e" to "busy")
            if (has) return mapOf("e" to "busy")
        }
        if (!has && isSoft()) return mapOf("e" to "software")
        if (has) {
            val (kc, why) = sign(KCV_INPUT)
            if (kc == null) return mapOf("e" to why)
            val i = info()
            return mapOf("k" to true, "u" to (i["u"] ?: 0), "l" to (i["l"] ?: SOFTWARE), "kc" to hex(kc), "ms" to 0L)
        }
        // the flag is broken before 15: a removed screen lock deletes the key
        // there, and a face unlock does not open it
        val unlocked = sdk >= 35
        val tries = if (sdk >= 28) listOf(true, false) else listOf(false)
        notes?.setMaking(true)
        var soft = false
        for (strong in tries) {
            // generating over an alias replaces it: asked again right before
            if (hasKey() != false) return mapOf("e" to "busy")
            // only the last attempt's read counts: one that fails after a
            // software read claims nothing
            soft = false
            try {
                keys.make(ALIAS, strong, unlocked)
            } catch (e: Exception) {
                told("not made", e)
                dropQuietly()
                continue
            }
            val slowest = selfTest()
            if (slowest == null || (strong && slowest > SLOW_MS)) {
                told(if (slowest == null) "failed its test" else "slow", null)
                dropQuietly()
                continue
            }
            val (kc, _) = sign(KCV_INPUT)
            if (kc == null) {
                dropQuietly()
                continue
            }
            // a level that will not read claims nothing, except a strongbox
            // key, which the keystore makes nowhere else. before 12 the key
            // only tells secure hardware from software
            val read = try {
                keys.level(ALIAS)
            } catch (_: Exception) {
                null
            }
            if (read == SOFTWARE) {
                told("in software", null)
                dropQuietly()
                soft = true
                continue
            }
            val level = when {
                strong -> if (sdk >= 31) read ?: STRONGBOX else STRONGBOX
                else -> read ?: SOFTWARE
            }
            val u = if (unlocked) 1 else 0
            notes?.write(u, level)
            notes?.setMaking(false)
            return mapOf("k" to true, "u" to u, "l" to level, "kc" to hex(kc), "ms" to slowest)
        }
        // a failed key that would not go stays marked, so the next make
        // deletes it before anything else
        if (hasKey() == false) {
            notes?.setMaking(false)
            if (soft) {
                notes?.setSoft()
                return mapOf("e" to "software")
            }
        }
        return mapOf("e" to "refused")
    }

    // the same input twice signs the same, two inputs sign differently, and
    // no answer is the input or zeros. the slowest call, or null
    private fun selfTest(): Long? {
        val rnd = SecureRandom()
        fun random() = ByteArray(32).also { rnd.nextBytes(it) }
        var slowest = 0L
        fun timed(x: ByteArray): ByteArray? {
            val t0 = nanos()
            val (m, _) = sign(x)
            slowest = maxOf(slowest, (nanos() - t0) / 1_000_000)
            return m
        }
        val a = random()
        val ma = timed(a) ?: return null
        val again = timed(a) ?: return null
        val mb = timed(random()) ?: return null
        if (!ma.contentEquals(again) || ma.contentEquals(mb)) return null
        repeat(3) { timed(random()) ?: return null }
        return slowest
    }

    // x signed: {"m": hex} or {"e": "busy" | "locked" | "gone" | "bad"}
    fun mac(xHex: String?): Map<String, Any> {
        // never signs with a key that has not passed its test
        if (untested()) return mapOf("e" to "busy")
        val x = unhex(xHex)
        if (x == null || x.size != 32) return mapOf("e" to "bad")
        val (m, why) = sign(x)
        return if (m == null) mapOf("e" to why) else mapOf("m" to hex(m))
    }

    // the check value: says only whether this is the key the table was made with
    fun kcv(): Map<String, Any> {
        if (untested()) return mapOf("e" to "busy")
        val (m, why) = sign(KCV_INPUT)
        return if (m == null) mapOf("e" to why) else mapOf("m" to hex(m))
    }

    private fun isSoft(): Boolean = try {
        notes?.soft() == true
    } catch (_: Exception) {
        false
    }

    private fun untested(): Boolean = try {
        notes?.making() == true
    } catch (_: Exception) {
        false
    }

    // the wipe and the lock turned off only. never beside a make
    @Synchronized
    fun drop() {
        dropQuietly()
        try {
            notes?.clear()
        } catch (_: Exception) {
        }
    }

    // drop() for the native wipe: a keystore that hangs gets ms, and the
    // wipe goes on without it. true when the drop finished
    fun dropWithin(ms: Long): Boolean {
        val t = Thread { drop() }.apply {
            isDaemon = true
            start()
        }
        try {
            t.join(ms)
        } catch (_: InterruptedException) {
        }
        return !t.isAlive
    }

    private fun dropQuietly() {
        try {
            keys.delete(ALIAS)
        } catch (_: Exception) {
        }
    }

    // one signing, tried again on a busy keystore and, from 15 on, once more
    // a beat after a "locked" (the keystore hears of an unlock late). each
    // try runs on a fresh thread: a call that hangs is left behind, never
    // waited for past the deadline
    fun sign(input: ByteArray, deadlineMs: Long = DEADLINE_MS): Pair<ByteArray?, String> {
        val end = nanos() / 1_000_000 + deadlineMs
        var busy = 0
        var lockedAgain = false
        while (true) {
            val left = end - nanos() / 1_000_000
            if (left <= 0) return null to "busy"
            val (m, why) = once(input, left)
            when (why) {
                "ok", "gone", "bad" -> return m to why
                "locked" -> {
                    if (sdk < 35 || lockedAgain) return null to "locked"
                    lockedAgain = true
                    pause(300)
                }
                "late" -> return null to "busy"
                else -> {
                    if (++busy >= 3) return null to "busy"
                    pause(150L shl (busy - 1))
                }
            }
        }
    }

    private fun once(input: ByteArray, waitMs: Long): Pair<ByteArray?, String> {
        val box = AtomicReference<Pair<ByteArray?, String>?>(null)
        val t = Thread {
            box.set(
                try {
                    attempt(input)
                } catch (e: Throwable) {
                    null to "busy"
                },
            )
        }
        t.isDaemon = true
        t.start()
        try {
            t.join(waitMs)
        } catch (_: InterruptedException) {
        }
        return box.get() ?: (null to "late")
    }

    private fun attempt(input: ByteArray): Pair<ByteArray?, String> = try {
        val m = keys.mac(ALIAS, input)
        if (m.size != 32 || m.all { it == 0.toByte() } || m.contentEquals(input)) {
            told("odd answer", null)
            null to "bad"
        } else {
            m to "ok"
        }
    } catch (e: Exception) {
        // gone only when the keystore says it has no such key: a busy one
        // may fail a lookup too
        val why = when {
            locked(e) -> "locked"
            goneSure() -> "gone"
            else -> "busy"
        }
        told(why, e)
        null to why
    }

    // the phone counts as locked to the keystore: a key made to work only
    // while it is unlocked, asked too early after an unlock
    fun locked(e: Throwable?): Boolean {
        var c = e
        var depth = 0
        while (c != null && depth++ < 8) {
            if (c is UserNotAuthenticatedException) return true
            if (Build.VERSION.SDK_INT >= 33 && c is android.security.KeyStoreException &&
                c.numericErrorCode == android.security.KeyStoreException.ERROR_USER_AUTHENTICATION_REQUIRED
            ) {
                return true
            }
            c = c.cause
        }
        return false
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
            DebugLog.i("kryfo", "pin key $what$name$code")
        } catch (_: Throwable) {
        }
    }

    fun hex(b: ByteArray): String {
        val d = "0123456789abcdef"
        val sb = StringBuilder(b.size * 2)
        for (x in b) {
            val v = x.toInt() and 0xff
            sb.append(d[v shr 4]).append(d[v and 0xf])
        }
        return sb.toString()
    }

    fun unhex(s: String?): ByteArray? {
        if (s == null || s.length % 2 != 0) return null
        val b = ByteArray(s.length / 2)
        for (i in b.indices) {
            val hi = Character.digit(s[2 * i], 16)
            val lo = Character.digit(s[2 * i + 1], 16)
            if (hi < 0 || lo < 0) return null
            b[i] = ((hi shl 4) or lo).toByte()
        }
        return b
    }
}
