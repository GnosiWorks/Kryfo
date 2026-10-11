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

  testWidgets('the moat note is honest about the address, and calm', (t) async {
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
}
