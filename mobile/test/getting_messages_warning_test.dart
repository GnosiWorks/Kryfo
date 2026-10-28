// SPDX-License-Identifier: GPL-3.0-or-later
// with a pin on and the message shown, the row into the notification
// choices says what that gives away, under it, in the warning's own rose.
// hidden, or no pin, it says nothing
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show HaloEngine, appState, useEngineForTest, AppStateRoute;
import 'package:kryfo/notifications.dart' show forgetNotifPlain;
import 'package:kryfo/screens/notifications_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart' show devApp, devWorld;

class _Engine implements HaloEngine {
  @override
  String setBridgeMode(String mode, String opts) => 'ok';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

Future<void> _open(
  WidgetTester t, {
  required bool pin,
  required bool shown,
}) async {
  SharedPreferences.setMockInitialValues({
    'notif_hide_content': !shown,
    'battery_opt_prompt_seen': true,
    'miui_autostart_prompt_seen': true,
  });
  FlutterSecureStorage.setMockInitialValues({});
  forgetNotifPlain();
  appState.sendModeForTest = 'balanced';
  useEngineForTest(_Engine());
  await devWorld();
  lockState.openForTest(enabled: pin);
  addTearDown(lockState.openForTest);
  t.view.physicalSize = const Size(400, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(devApp(const NotificationsScreen()));
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(seconds: 1));
  }
}

Finder get _warning => find.text(l10n.gettingMessagesShowsMessageTextIn);

void main() {
  testWidgets('a pin with the message shown: the warning, in rose', (t) async {
    await _open(t, pin: true, shown: true);
    expect(_warning, findsOneWidget);
    final style = t.widget<Text>(_warning).style!;
    expect(style.color, HaloColors.rose);
    // under the row, not inside it
    expect(
      t.getTopLeft(_warning).dy,
      greaterThan(t.getBottomLeft(find.text(l10n.gettingMessagesWhatShows)).dy),
    );
    await t.pumpWidget(const SizedBox());
  });

  for (final (pin, shown) in [(false, true), (true, false)]) {
    testWidgets('pin $pin, message shown $shown: no warning', (t) async {
      await _open(t, pin: pin, shown: shown);
      expect(_warning, findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  }
}
