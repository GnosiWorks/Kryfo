// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

// the app's one screen under a name of its own. the launcher entries are
// aliases of it (AppIcon), and the default one keeps the old name
// .MainActivity, so home screen icons and scripts from before still open it
class KryfoActivity : MainActivity()
