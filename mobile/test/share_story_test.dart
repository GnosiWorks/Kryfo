// SPDX-License-Identifier: GPL-3.0-or-later
// share your story: one tap from settings opens the chat with Marios with
// the template waiting, unsent, and the row says stories go nowhere without
// consent, and that the chat can still be anonymous before its first send
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show appState, AppStateRoute, AppStateDevchat;
import 'package:kryfo/screens/dev_about_sheet.dart';
import 'package:kryfo/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';

Future<Finder> _row(WidgetTester t) async {
  final row = find.text(l10n.storyRow);
  await t.scrollUntilVisible(
    row,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(t.element(row), alignment: 0.5);
  await t.pump(const Duration(milliseconds: 500));
  return row;
}

void main() {
  String? opened;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    appState.sendModeForTest = 'balanced';
    useDevKeysForTest([devCard('m1')]);
    opened = null;
    devChatPageForTest = (id, text) {
      opened = text;
      return Scaffold(body: Center(child: Text('the chat $id')));
    };
  });

  tearDown(() {
    useDevKeysForTest(null);
    devChatPageForTest = null;
    setL10nLocale(const Locale('en'));
  });

  test('the template asks the three things, the region optional', () {
    final t = l10n.storyTemplate;
    expect(t, contains('Why I use Kryfo'));
    expect(t, contains('What is blocked where I live'));
    expect(t, contains('Region (optional)'));
  });

  testWidgets('one tap opens his chat with the template, nothing sent', (
    t,
  ) async {
    await devWorld();
    await devOpen(t, const SettingsScreen());
    final row = await _row(t);
    // before a first send: the line says it can still be anonymous
    expect(find.text(l10n.storyHintAnon), findsOneWidget);
    expect(l10n.storyHintAnon, contains('consent'));
    await t.tap(row);
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('the chat dev:m1'), findsOneWidget);
    expect(opened, l10n.storyTemplate);
    // the chat is made, not started: the anonymous choice is still open
    final row2 = (await devTestChat.load())!;
    expect(row2.state, DevState.fresh);
    expect(appState.devRow!.started, isFalse);
    await devClose(t);
  });

  test('a started chat drops the anonymous line, keeps consent', () {
    expect(storyHint(true), l10n.storyHint);
    expect(storyHint(false), l10n.storyHintAnon);
    expect(l10n.storyHint, contains('consent'));
    expect(l10n.storyHint, isNot(contains('anonymous')));
  });

  testWidgets('no row where there is no chat with him', (t) async {
    useDevKeysForTest(const []);
    await devWorld();
    await devOpen(t, const SettingsScreen());
    final report = find.text(l10n.settingsReportAnIssue);
    await t.scrollUntilVisible(
      report,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(l10n.storyRow), findsNothing);
    await devClose(t);
  });

  testWidgets('every language has the template with its three lines', (
    t,
  ) async {
    for (final l in AppLocalizations.supportedLocales) {
      setL10nLocale(l);
      final lines = l10n.storyTemplate.trimRight().split('\n');
      expect(lines.where((x) => x.trim().isNotEmpty).length, 3, reason: '$l');
    }
  });
}
