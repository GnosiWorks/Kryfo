// SPDX-License-Identifier: GPL-3.0-or-later
// the safety number reads left to right in western digits on every phone:
// two people with Kryfo in english, arabic and persian hold the same number
// in the same order, on screen and read out
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloDb, useDatabasesForTest;
import 'package:kryfo/screens/key_verification_screen.dart';
import 'package:kryfo/session.dart';

import 'pin_flow_fakes.dart' show app, phone;

class _Db implements HaloDb {
  @override
  Future<bool> isVerified(String haloId) async => false;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

final _mine = 'ab' * 32;
final _theirs = 'cd' * 32;

void main() {
  final number = haloSafetyNumber(_mine, _theirs);
  final groups = number.split(' ');

  tearDown(() => setL10nLocale(const Locale('en')));

  test('twelve groups of five western digits, the same from both ends', () {
    expect(RegExp(r'^[0-9]{5}( [0-9]{5}){11}$').hasMatch(number), isTrue);
    expect(haloSafetyNumber(_theirs, _mine), number);
  });

  // the groups as an eye reads them: row by row, each row left to right
  List<String> read(WidgetTester t) {
    final at = {for (final g in groups) g: t.getCenter(find.text(g))};
    final order = [...groups]
      ..sort((a, b) {
        final row = at[a]!.dy.round().compareTo(at[b]!.dy.round());
        return row != 0 ? row : at[a]!.dx.compareTo(at[b]!.dx);
      });
    return order;
  }

  for (final code in ['en', 'ar', 'fa']) {
    testWidgets('in $code it reads left to right, first group first', (
      t,
    ) async {
      phone(t);
      final db = _Db();
      useDatabasesForTest(db, Session(db));
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(
        () => m.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final sem = t.ensureSemantics();
      setL10nLocale(Locale(code));
      await t.pumpWidget(
        app(
          KeyVerificationScreen(
            peerHaloId: 'thumb-behave-boring',
            peerName: 'Anna',
            myXpub: _mine,
            peerXpub: _theirs,
          ),
          locale: Locale(code),
          still: true,
        ),
      );
      await t.pumpAndSettle();

      // the page around it follows the language
      final title = find.text(l10n.keyVerificationSafetyNumber);
      expect(
        Directionality.of(t.element(title)),
        code == 'en' ? TextDirection.ltr : TextDirection.rtl,
      );

      // the number does not: the same order as in english
      expect(read(t), groups);
      for (final g in groups) {
        expect(Directionality.of(t.element(find.text(g))), TextDirection.ltr);
      }
      // and read out whole, in that order
      expect(find.bySemanticsLabel(number), findsOneWidget);

      sem.dispose();
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  }
}
