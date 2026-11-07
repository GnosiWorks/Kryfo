// SPDX-License-Identifier: GPL-3.0-or-later
// the linux and windows app: flutter build linux -t lib/main_desktop.dart.
// the phone's build starts at main.dart and never reaches lib/desktop
import 'dart:io';

import 'desktop/desktop_mode.dart' show deskLaunchLink, launchLinkOf;
import 'desktop/desktop_start.dart';
import 'main.dart' as app;

void main(List<String> args) {
  // windows' app_links reads its own command line
  if (Platform.isLinux) deskLaunchLink = launchLinkOf(args);
  startDesktop(() async => app.main());
}
