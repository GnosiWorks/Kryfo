// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import androidx.core.content.FileProvider

// hands one file at a time to whichever app the person picks to open it.
// its own class so its manifest entry can never collide with a plugin's.
// it serves cache/open/ and nothing else, see res/xml/open_paths.xml.
class OpenFileProvider : FileProvider()
