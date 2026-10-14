// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Application
import android.content.ComponentName
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class PhotoPickerTest {
    private val app: Application = RuntimeEnvironment.getApplication()

    @Test
    @Config(sdk = [33])
    fun thirteenHasItBuiltIn() {
        assertTrue(PhotoPicker.ready(app))
    }

    @Test
    @Config(sdk = [29])
    fun anOldPhoneWithoutPlayHasNone() {
        assertFalse(PhotoPicker.ready(app))
    }

    // google play's copy answers the fallback action as a system app
    @Test
    @Config(sdk = [29])
    fun anOldPhoneWithPlaysCopyHasOne() {
        val pm = shadowOf(app.packageManager)
        val picker = ComponentName("com.google.android.gms", "com.google.android.gms.PickImages")
        val info = pm.addActivityIfNotPresent(picker)
        info.applicationInfo.flags = info.applicationInfo.flags or ApplicationInfo.FLAG_SYSTEM
        pm.addIntentFilterForActivity(
            picker,
            IntentFilter("androidx.activity.result.contract.action.PICK_IMAGES").apply {
                addCategory(Intent.CATEGORY_DEFAULT)
            },
        )
        assertTrue(PhotoPicker.ready(app))
    }
}
