// SPDX-License-Identifier: GPL-3.0-or-later
// which store a build is for. --flavor play makes the google play build: no
// donations and no payment screens. flutter passes the same flavor to gradle
// (android/app/build.gradle.kts) for its version code and manifest
const bool kPlayBuild = String.fromEnvironment('FLUTTER_APP_FLAVOR') == 'play';
