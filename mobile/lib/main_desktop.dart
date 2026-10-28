// SPDX-License-Identifier: GPL-3.0-or-later
// the linux and windows app: flutter build linux -t lib/main_desktop.dart.
// the phone's build starts at main.dart and never reaches lib/desktop
import 'desktop/desktop_start.dart';
import 'main.dart' as app;

void main() => startDesktop(() async => app.main());
