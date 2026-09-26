// SPDX-License-Identifier: GPL-3.0-or-later
// a reinstall turns fast mode off: the choice lives in a marker file that
// dies with the app's data, not in the backed-up preference.

// fast without its marker means the preference outlived an install
String sendModeAtBoot(String stored, {required bool fastMarker}) =>
    stored == 'fast' && !fastMarker ? 'private' : stored;
