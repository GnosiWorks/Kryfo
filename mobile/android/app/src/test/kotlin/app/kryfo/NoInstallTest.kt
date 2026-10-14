// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Application
import android.content.pm.PackageManager
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
    private fun asked(): List<String> {
        val app = RuntimeEnvironment.getApplication()
        val info = app.packageManager.getPackageInfo(app.packageName, PackageManager.GET_PERMISSIONS)
        return info.requestedPermissions?.toList() ?: emptyList()
    }

    @Test
    fun theMergedManifestNeverAsksToInstallApps() {
        val all = asked()
        assertTrue(all.toString(), "android.permission.INTERNET" in all)
        assertFalse(all.toString(), "android.permission.REQUEST_INSTALL_PACKAGES" in all)
        assertFalse(all.toString(), "android.permission.INSTALL_PACKAGES" in all)
    }
}
