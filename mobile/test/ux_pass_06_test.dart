// SPDX-License-Identifier: GPL-3.0-or-later
// small screen and large text fixes: the new group head fits at 200% on a
// 320 px phone, home's room and new pills and the default chip hold 4.5:1 in
// light, and "Your Kryfo" stays on one line
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart' show onDesktop;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart' show AppStateRoute, appState;
import 'package:kryfo/screens/home_screen.dart';
import 'package:kryfo/screens/modes_screen.dart';
import 'package:kryfo/screens/new_group_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'settings_no_grey_test.dart' show groundOf, ratio;

const _small = Size(640, 1400);

void _quiet(WidgetTester t) {
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

double _contrast(WidgetTester t, String text) {
  final e = find.text(text).evaluate().single;
  final c = (e.widget as Text).style!.color!;
  final g = groundOf(e);
  return ratio(Color.alphaBlend(c, g), g);
}

void main() {
  setUp(() {
    onDesktop = false;
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    appState.sendModeForTest = 'balanced';
    lockState.openForTest();
  });
  tearDown(() => HaloColors.setLight(false));

  testWidgets('the new group head fits at 200% on 320 px', (t) async {
    _quiet(t);
    final was = appState.contacts;
    addTearDown(() => appState.contacts = was);
    appState.contacts = [
      ContactPreview(haloId: 'wren-velvet-march', avatarSeed: 'w'),
    ];
    await devOpen(t, const NewGroupScreen(), size: _small, scale: 2);
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
    final members = t.getRect(find.text(l10n.newGroupMembers));
    final pick = t.getRect(find.text(l10n.newGroupPickAtLeastOne));
    expect(pick.left, greaterThan(members.right));
    expect(pick.right, lessThanOrEqualTo(320));
  });

  testWidgets('home pills hold 4.5:1 and the label keeps one line', (t) async {
    _quiet(t);
    HaloColors.setLight(true);
    await t.runAsync(() => devWorld());
    await devOpen(
      t,
      devHome(
        groups: const [
          GroupSummary(groupId: 'g1', name: 'Hikers', memberCount: 3),
        ],
      ),
      size: _small,
      scale: 2,
      still: true,
    );
    await t.pump(const Duration(seconds: 1));
    expect(_contrast(t, l10n.homeRoom), greaterThanOrEqualTo(4.5));
    expect(_contrast(t, l10n.homeNew), greaterThanOrEqualTo(4.5));
    final label = t.widget<Text>(find.text(l10n.homeYourKryfo));
    expect(label.maxLines, 1);
    expect(
      find.ancestor(
        of: find.text(l10n.homeYourKryfo),
        matching: find.byType(FittedBox),
      ),
      findsOneWidget,
    );
    await devClose(t);
  });

  testWidgets('the default chip holds 4.5:1 in light', (t) async {
    _quiet(t);
    HaloColors.setLight(true);
    appState.sendModeForTest = 'private';
    await devOpen(t, const ModesScreen(), still: true);
    await t.pump(const Duration(seconds: 1));
    expect(_contrast(t, l10n.modesDefault), greaterThanOrEqualTo(4.5));
    await devClose(t);
  });
}
