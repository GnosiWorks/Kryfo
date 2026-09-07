// SPDX-License-Identifier: GPL-3.0-or-later
//
// fast mode is the one place friction is the feature. it turns on only
// after the phrase is typed, and a reinstall turns it off again: the choice
// lives in a marker file that dies with the app's data, not in the backed-up
// preference.

const kFastGatePhrase = 'i understand';

bool fastGateAccepts(String typed) =>
    typed.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ==
    kFastGatePhrase;

// what the app should run in at boot. fast without its marker means the
// preference outlived an install; go back to onion.
String sendModeAtBoot(String stored, {required bool fastMarker}) =>
    stored == 'fast' && !fastMarker ? 'private' : stored;
