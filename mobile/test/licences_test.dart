// SPDX-License-Identifier: GPL-3.0-or-later
// the licences screen: the rust list is made from the Cargo.lock in the
// tree, names libsignal's AGPL crates, and the screen opens every list and
// text, with and without motion
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/licences.dart';
import 'package:kryfo/screens/licences_screen.dart';

const _lock = 'native/kryfo_signal/Cargo.lock';
final _asset = File(kRustLicencesAsset);

const _agplCrates = [
  'libsignal-core',
  'libsignal-protocol',
  'signal-crypto',
  'libsignal-debug',
  'spqr',
];

Widget _host(Widget child, {bool still = false, bool rtl = false}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 720),
          disableAnimations: still,
        ),
        child: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: child,
        ),
      ),
    );

RustLicences _fakeRust() => const RustLicences('v0.99.4', [
  LicencedPart(
    'libsignal-protocol',
    ['GNU AFFERO GENERAL PUBLIC LICENSE\n\nVersion 3'],
    version: '0.1.0',
    licence: 'AGPL-3.0-only',
  ),
  LicencedPart(
    'zeroize',
    ['MIT text'],
    version: '1.9.1',
    licence: 'Apache-2.0 OR MIT',
  ),
], 'GNU AFFERO GENERAL PUBLIC LICENSE\n\nVersion 3, 19 November 2007');

List<LicencedPart> _fakeDart() => const [
  LicencedPart('ffi', ['BSD text']),
  LicencedPart('flutter', ['flutter text one', 'flutter text two']),
];

void main() {
  group('the rust list', () {
    test('was made from the Cargo.lock in this tree', () {
      final j = jsonDecode(_asset.readAsStringSync()) as Map<String, dynamic>;
      final lock = sha256.convert(File(_lock).readAsBytesSync()).toString();
      expect(
        j['lock'],
        lock,
        reason:
            'Cargo.lock changed: run native/kryfo_signal/acknowledgments.sh',
      );
      final tag = RegExp(
        r'signalapp/libsignal\?tag=(v[0-9.]+)#',
      ).firstMatch(File(_lock).readAsStringSync())![1];
      expect(j['libsignal'], tag);
    });

    test('names the AGPL crates and a text for every crate', () {
      final r = parseRustLicences(_asset.readAsStringSync());
      final byName = {for (final c in r.crates) c.name: c};
      for (final n in _agplCrates) {
        expect(byName[n]?.licence, contains('AGPL-3.0'), reason: n);
      }
      for (final c in r.crates) {
        expect(c.texts, isNotEmpty, reason: c.name);
        expect(c.version, isNotEmpty, reason: c.name);
      }
      expect(r.agpl, contains('GNU AFFERO GENERAL PUBLIC LICENSE'));
      // the shim itself is ours, under the GPL, and not listed
      expect(byName.containsKey('kryfo_signal'), isFalse);
    });
  });

  test('dart licences come one entry per package, sorted', () async {
    final parts = await loadDartLicences(
      Stream.fromIterable([
        const LicenseEntryWithLineBreaks(['zeta', 'alpha'], 'shared text'),
        const LicenseEntryWithLineBreaks(['Beta'], 'beta text'),
        const LicenseEntryWithLineBreaks(['alpha'], 'alpha own text'),
      ]),
    );
    expect(parts.map((p) => p.name), ['alpha', 'Beta', 'zeta']);
    expect(parts.first.texts, ['shared text', 'alpha own text']);
  });

  for (final still in [false, true]) {
    testWidgets('the screen opens each list and text, still: $still', (
      t,
    ) async {
      await t.pumpWidget(
        _host(
          LicencesScreen(
            rust: Future.value(_fakeRust()),
            dart: Future.value(_fakeDart()),
          ),
          still: still,
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('GNU General Public License'), findsOneWidget);
      expect(find.textContaining('libsignal v0.99.4'), findsOneWidget);
      expect(find.text('2 parts'), findsNWidgets(2));

      await t.ensureVisible(find.text('In the Signal library'));
      await t.ensureVisible(find.text('In the Signal library'));
    await t.tap(find.text('In the Signal library'));
      await t.pumpAndSettle();
      expect(find.text('libsignal-protocol'), findsOneWidget);
      expect(find.text('0.1.0 · AGPL-3.0-only'), findsOneWidget);
      await t.tap(find.text('libsignal-protocol'));
      await t.pumpAndSettle();
      expect(find.text('libsignal-protocol 0.1.0'), findsOneWidget);
      expect(find.text('GNU AFFERO GENERAL PUBLIC LICENSE'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('In the app'));
      await t.ensureVisible(find.text('In the app'));
    await t.tap(find.text('In the app'));
      await t.pumpAndSettle();
      await t.tap(find.text('flutter'));
      await t.pumpAndSettle();
      expect(find.text('flutter text one'), findsOneWidget);
      expect(find.text('flutter text two'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('GNU AGPL 3.0, full text'));
      await t.ensureVisible(find.text('GNU AGPL 3.0, full text'));
    await t.tap(find.text('GNU AGPL 3.0, full text'));
      await t.pumpAndSettle();
      expect(find.text('Version 3, 19 November 2007'), findsOneWidget);
    });
  }

  testWidgets('a licence text stays left to right in an rtl app', (t) async {
    await t.pumpWidget(
      _host(
        LicencesScreen(
          rust: Future.value(_fakeRust()),
          dart: Future.value(_fakeDart()),
        ),
        rtl: true,
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('GNU AGPL 3.0, full text'));
    await t.tap(find.text('GNU AGPL 3.0, full text'));
    await t.pumpAndSettle();
    final text = t.widget<Text>(find.text('Version 3, 19 November 2007'));
    expect(text.textDirection, TextDirection.ltr);
  });

  testWidgets('rows wait for the lists and do not open early', (t) async {
    await t.pumpWidget(
      _host(
        LicencesScreen(
          rust: Future<RustLicences>.delayed(
            const Duration(seconds: 1),
            _fakeRust,
          ),
          dart: Future.value(_fakeDart()),
        ),
      ),
    );
    await t.pump();
    await t.ensureVisible(find.text('In the Signal library'));
    await t.tap(find.text('In the Signal library'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('libsignal-protocol'), findsNothing);
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('2 parts'), findsNWidgets(2));
  });
}
