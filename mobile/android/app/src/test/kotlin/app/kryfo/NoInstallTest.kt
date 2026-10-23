// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Application
import android.content.pm.PackageManager
import java.io.File
import java.util.Properties
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

// robolectric reads the merged manifest, plugins' permissions and all
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class NoInstallTest {
    private val banned = setOf(
        "android.permission.REQUEST_INSTALL_PACKAGES",
        "android.permission.INSTALL_PACKAGES",
    )

    private fun asked(): List<String> {
        val app = RuntimeEnvironment.getApplication()
        val info = app.packageManager.getPackageInfo(app.packageName, PackageManager.GET_PERMISSIONS)
        return info.requestedPermissions?.toList() ?: emptyList()
    }

    // the merged manifest gradle wrote for the flavor and build type under test
    private fun merged(): File {
        val props = Properties()
        javaClass.classLoader!!.getResourceAsStream("com/android/tools/test_config.properties")
            .use { props.load(it) }
        return File(props.getProperty("android_merged_manifest"))
    }

    @Test
    fun theMergedManifestNeverAsksToInstallApps() {
        val all = asked()
        assertTrue(all.toString(), "android.permission.INTERNET" in all)
        for (p in banned) assertFalse(all.toString(), p in all)
    }

    @Test
    fun noPermissionElementOfTheMergedManifestAsksToInstallApps() {
        val file = merged()
        val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(file)
        // sdk-m is the old name of sdk-23. android still reads it and the
        // merger never removes it, so only this check stops it
        val names = mutableListOf<String>()
        val hits = mutableListOf<String>()
        for (tag in listOf("uses-permission", "uses-permission-sdk-23", "uses-permission-sdk-m")) {
            val asks = doc.getElementsByTagName(tag)
            for (i in 0 until asks.length) {
                val p = (asks.item(i) as org.w3c.dom.Element).getAttribute("android:name")
                names += p
                if (p in banned) hits += "$tag $p"
            }
        }
        assertTrue(file.path, "android.permission.INTERNET" in names)
        assertEquals(file.path, emptyList<String>(), hits)
    }
}
