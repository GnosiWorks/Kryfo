// SPDX-License-Identifier: GPL-3.0-or-later
// a request card carries the shield's line only for a red flag: a clean
// check shows nothing, there is no "looks safe". with the shield off no
// card carries one, whatever it said while it ran; on again, they are back.
// the cross takes a line away for good. the database is a stand-in that
// keeps rows in memory
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloDb, useDatabasesForTest;
import 'package:kryfo/scam_prefs.dart';
import 'package:kryfo/scam_shield.dart';
import 'package:kryfo/screens/requests_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/shield_note.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _clean = 'amber-fox-river';
const _flagged = 'slow-kite-moss';
const _new = 'quiet-hill-reed';

final _hit = const ShieldHit('asks_secret').toJson();

class _Db implements HaloDb {
  // what the shield stored: a clean check an older build kept, and a flag
  final shield = <String, Map<String, Object?>>{
    _clean: {'headline': '', 'lines': '[]', 'dismissed': 0},
    _flagged: {
      'headline': jsonEncode(_hit),
      'lines': jsonEncode([_hit]),
      'dismissed': 0,
    },
  };
  final dismissed = <String>[];

  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<List<Map<String, Object?>>> requestsInbox() async => [
    for (final id in [_clean, _flagged, _new])
      {'halo_id': id, 'nickname': null, 'last_seen': 0, 'blocked': 0},
  ];
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async =>
      shield[haloId];
  @override
  Future<void> dismissShield(String haloId) async {
    dismissed.add(haloId);
    shield[haloId]?['dismissed'] = 1;
  }

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

final _line = l10n.scamShieldWarning(l10n.scamShieldAsksForSecret);

void main() {
  late _Db db;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    db = _Db();
    useDatabasesForTest(db, Session(db));
  });

  testWidgets('shield on: one line on the flagged card, none elsewhere', (
    t,
  ) async {
    await saveScamShieldOn(true);
    await _show(t);
    expect(find.text(_clean), findsOne);
    expect(find.text(_new), findsOne);
    expect(find.text(_line), findsOne);
    expect(find.byType(ShieldNote), findsOne);
    // nowhere a word of safety
    expect(find.textContaining('safe'), findsNothing);
    expect(find.textContaining('Safe'), findsNothing);
    await _drain(t);
  });

  testWidgets('shield off: no line on any card', (t) async {
    await saveScamShieldOn(false);
    await _show(t);
    expect(find.text(_flagged), findsOne);
    expect(find.byType(ShieldNote), findsNothing);
    expect(find.text(_line), findsNothing);
    await _drain(t);
  });

  testWidgets('the cross folds the line away and keeps it away', (t) async {
    await _show(t);
    await t.tap(find.byTooltip(l10n.scamShieldDismiss));
    await t.pump();
    await t.pump(const Duration(milliseconds: 150));
    // still folding
    expect(find.byType(ShieldNote), findsOne);
    await t.pump(const Duration(milliseconds: 400));
    expect(db.dismissed, [_flagged]);
    expect(find.byType(ShieldNote), findsNothing);
    // a fresh read of the screen does not bring it back
    await _drain(t);
    await _show(t);
    expect(find.byType(ShieldNote), findsNothing);
    await _drain(t);
  });
}
