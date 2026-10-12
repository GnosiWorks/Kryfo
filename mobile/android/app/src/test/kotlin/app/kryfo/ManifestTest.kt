// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class ManifestTest {
    @Test
    fun theNetworkStateWeReadIsDeclaredHere() {
        val manifest = File("src/main/AndroidManifest.xml").readText()
        assertTrue(
            manifest.contains(
                "<uses-permission android:name=\"android.permission.ACCESS_NETWORK_STATE\" />"
            )
        )
    }
}
