// SPDX-License-Identifier: GPL-3.0-or-later
// with the scam shield off a request card carries no verdict, safe or not,
// whatever the shield said while it ran; on again, the verdicts are back.
// the database is a stand-in that keeps rows in memory
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloDb, useDatabasesForTest;
import 'package:kryfo/scam_prefs.dart';
import 'package:kryfo/screens/requests_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _safe = 'amber-fox-river';
const _flagged = 'slow-kite-moss';
const _new = 'quiet-hill-reed';

class _Db implements HaloDb {
  // what the shield stored while it ran: one clean, one flagged
  final shield = <String, Map<String, Object?>>{
    _safe: {'headline': '', 'lines': '[]', 'dismissed': 0},
    _flagged: {
      'headline': 'Asks for money in a first message',
      'lines': '["Asks for money"]',
      'dismissed': 0,
    },
  };

  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<List<Map<String, Object?>>> requestsInbox() async => [
    for (final id in [_safe, _flagged, _new])
      {'halo_id': id, 'nickname': null, 'last_seen': 0, 'blocked': 0},
  ];
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async =>
      shield[haloId];
  @override
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async => [];
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async => [];

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

Widget _framed() => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const RequestsScreen(),
);

Future<void> _show(WidgetTester t) async {
  t.view.physicalSize = const Size(1000, 2400);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (_) async => null,
  );
  await t.pumpWidget(_framed());
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 500));
  }
}

Future<void> _drain(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final db = _Db();
    useDatabasesForTest(db, Session(db));
  });

  testWidgets('shield off: no verdict on any card', (t) async {
    await saveScamShieldOn(false);
    await _show(t);
    expect(find.text(_safe), findsOne);
    expect(find.text(_flagged), findsOne);
    expect(find.text(_new), findsOne);
    expect(find.text(l10n.requestsLooksSafeNothingSuspicious), findsNothing);
    expect(find.text('Asks for money in a first message'), findsNothing);
    await _drain(t);
  });

  testWidgets('shield on: the verdicts show as they were', (t) async {
    await saveScamShieldOn(true);
    await _show(t);
    expect(find.text(l10n.requestsLooksSafeNothingSuspicious), findsOne);
    expect(find.text('Asks for money in a first message'), findsOne);
    await _drain(t);
  });
}
