// SPDX-License-Identifier: GPL-3.0-or-later
//
// fast mode is the one mode that costs something, so it opens with a plain
// warning and a button. a reinstall turns it off again: the choice lives in
// a marker file that dies with the app's data, not in the backed-up
// preference.

// what the app should run in at boot. fast without its marker means the
// preference outlived an install; go back to onion.
String sendModeAtBoot(String stored, {required bool fastMarker}) =>
    stored == 'fast' && !fastMarker ? 'private' : stored;
