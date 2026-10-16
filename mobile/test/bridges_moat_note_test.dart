// SPDX-License-Identifier: GPL-3.0-or-later
// the note on the sheets that ask the tor project says what it sees,
// plainly and not as a warning. the request goes over meek, so it no longer
// says the request leaves without tor.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart' show HaloEngine, appState, useEngineForTest;
import 'package:kryfo/screens/bridge_sheets.dart';
import 'package:kryfo/screens/bridges_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show app;

class _Engine implements HaloEngine {
  @override
  String setBridgeMode(String mode, String opts) => 'ok';

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => appState.setTorStatusForTest(TorStatus.off));

  testWidgets('the moat note says what the tor project sees, never in red', (
    t,
  ) async {
    t.view.physicalSize = const Size(1800, 9000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    useEngineForTest(_Engine());
    appState.setTorStatusForTest(TorStatus.starting);
    lockState.openForTest();
    await t.pumpWidget(app(const BridgesScreen()));
    await t.pump(const Duration(seconds: 1));
    showTorBlockedSheet(t.element(find.byType(BridgesScreen)));
    await t.pump();
    await t.pump(const Duration(seconds: 1));

    final note = find.text(l10n.bridgesWhenYouAskFor);
    expect(note, findsOneWidget);
    expect(l10n.bridgesWhenYouAskFor, contains('the Tor Project sees your'));
    expect(find.textContaining('not go through tor'), findsNothing);
    expect(find.textContaining('without tor'), findsNothing);

    final icon = t.widget<Icon>(
      find.descendant(
        of: find.ancestor(of: note, matching: find.byType(Row)).first,
        matching: find.byIcon(Icons.visibility_outlined),
      ),
    );
    expect(icon.color, isNot(HaloColors.rose));
  });

  // tor and the tor project are names: capitalised in every language
  test('the bridges screen writes Tor with a capital', () {
    final keys = {
      for (final f in [
        'lib/screens/bridges_screen.dart',
        'lib/screens/bridge_sheets.dart',
        'lib/bridge_mode.dart',
      ])
        ...RegExp(
          r'l10n\.(\w+)',
        ).allMatches(File(f).readAsStringSync()).map((m) => m.group(1)!),
    };
    final lower = RegExp(r'(?<![A-Za-z])tor(?![A-Za-z])');
    final bad = <String>[];
    for (final f in Directory('lib/l10n').listSync()) {
      if (!f.path.endsWith('.arb')) continue;
      final arb = jsonDecode((f as File).readAsStringSync()) as Map;
      for (final k in keys) {
        final v = arb[k];
        if (v is String && lower.hasMatch(v)) bad.add('${f.path} $k');
      }
    }
    expect(keys, contains('bridgesAskTorProject'));
    expect(bad, isEmpty);
  });

  // one name for the tor project in each language, the site follows it
  test('the Tor Project has one name per language', () {
    final name = {
      'ar': RegExp('مشروع Tor'),
      'de': RegExp(r'Tor-Projekts?\b'),
      'en': RegExp('the Tor Project|The Tor Project'),
      'es': RegExp('Proyecto Tor'),
      'fa': RegExp('پروژه‌ی Tor'),
      'fr': RegExp('Projet Tor'),
      'id': RegExp('Tor Project'),
      'it': RegExp('Progetto Tor'),
      'pt': RegExp('Projeto Tor'),
      'ru': RegExp(r'[Пп]роект[а-я]* Tor'),
      'tr': RegExp(r"Tor Projesi(nin|nden|ne)?(?!['’])\b"),
      'uk': RegExp(r'[Пп]роєкт[а-яієї]* Tor'),
      'vi': RegExp('Dự án Tor'),
      'zh': RegExp('Tor 项目'),
      'zh_Hant': RegExp('Tor 專案'),
    };
    final en =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    final keys = [
      for (final e in en.entries)
        if (!(e.key as String).startsWith('@') &&
            (e.value as String).contains('Tor Project'))
          e.key as String,
    ];
    expect(keys.length, greaterThan(10));
    final bad = <String>[];
    for (final e in name.entries) {
      final arb =
          jsonDecode(File('lib/l10n/app_${e.key}.arb').readAsStringSync())
              as Map;
      for (final k in keys) {
        if (!e.value.hasMatch(arb[k] as String)) bad.add('${e.key} $k');
      }
    }
    expect(bad, isEmpty);
    final it = File('lib/l10n/app_it.arb').readAsStringSync();
    final fr = File('lib/l10n/app_fr.arb').readAsStringSync();
    expect(it, isNot(contains('progetto Tor')));
    expect(fr, isNot(contains('projet Tor')));
    expect(
      File('lib/l10n/app_tr.arb').readAsStringSync(),
      isNot(contains("Projesi'")),
    );
  });
}
