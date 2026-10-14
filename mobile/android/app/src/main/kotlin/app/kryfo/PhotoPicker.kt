// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.content.Context
import androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia

// android's photo picker: built in from 13, a system update on 11 and 12,
// google play's copy on older phones. the gallery mixes photos and videos
// only where it is, as a mixed pick elsewhere is the file browser
object PhotoPicker {
    fun ready(context: Context): Boolean = PickVisualMedia.isPhotoPickerAvailable(context)
}
