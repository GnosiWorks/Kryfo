// SPDX-License-Identifier: GPL-3.0-or-later
// which store a build is for. --dart-define=KRYFO_STORE=play makes the google
// play build: no donations and no payment screens. android/app/build.gradle.kts
// reads the same define for its version code and manifest
const bool kPlayBuild = String.fromEnvironment('KRYFO_STORE') == 'play';
