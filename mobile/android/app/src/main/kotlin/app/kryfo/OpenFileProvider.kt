// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import androidx.core.content.FileProvider

// hands a file to whichever app the person picks to open it.
// its own class so its manifest entry can never collide with a plugin's.
// it serves the cache folders res/xml/open_paths.xml names: open/, share/,
// share_q/, backup_out/ and tools_out/.
class OpenFileProvider : FileProvider()
