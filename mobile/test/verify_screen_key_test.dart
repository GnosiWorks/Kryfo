// SPDX-License-Identifier: GPL-3.0-or-later
// the safety number page reads the key held for them when it opens, not the
// one the page under it was opened with, and follows a change while open:
// the number assembles again and a line says so. a tap marks the number on
// screen only: a key that moved under it is refused, and the page shows the
// new number. the rows are the app's own tables, kept in maps

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show appState, heldKeyHex, markVerified, useDatabasesForTest, verifiedNow;
import 'package:kryfo/screens/key_verification_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';

const _peer = 'calm-orbit-lantern';
String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
final _mine = _hex(List<int>.generate(32, (i) => 90 + i));
final _keyA = List<int>.generate(32, (i) => i + 1);
final _keyB = List<int>.generate(32, (i) => 200 - i);
final _keyC = List<int>.generate(32, (i) => 7 * i % 251);

class _Db extends DevTestDb {
  _Db(super.mem);

  @override
  Future<String?> heldKey(String haloId) => heldKeyHex(mem, haloId);

  @override
  Future<bool> isVerified(String haloId) async =>
      (await verifiedNow(mem, mem.rows('contacts'))).first['verified'] == 1;

  @override
  Future<bool> setVerified(String haloId, bool verified, {String? key}) =>
      markVerified(mem, haloId, verified, key: key);

  @override
  Future<bool> keyChanged(String haloId) async => false;
}

Future<void> _identity(MemDb mem, List<int> key) async {
  await mem.delete('peer_identities');
  await mem.insert('peer_identities', {
    'address': _peer,
    'identity_key': Uint8List.fromList([5, ...key]),
  });
}

Widget _page() => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: KeyVerificationScreen(
    peerHaloId: _peer,
    peerName: 'Lena',
    myXpub: _mine,
    // the key the chat under it was opened with, gone since
    peerXpub: _hex(_keyB),
  ),
);

String _first(List<int> peer) =>
    haloSafetyNumber(_mine, _hex(peer)).split(' ').first;

void main() {
  late MemDb mem;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mem = MemDb();
    await mem.insert('contacts', {
      'halo_id': _peer,
      'onion': 'o',
      'xpub': '',
      'first_seen': 1,
      'last_seen': 1,
    });
    await _identity(mem, _keyA);
    final db = _Db(mem);
    useDatabasesForTest(db, Session(db));
  });

  testWidgets('the number is the held key\'s, and a change while open shows '
      'the new one with a line', (t) async {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    await t.pumpWidget(_page());
    await t.pumpAndSettle();
    expect(find.text(_first(_keyA)), findsOneWidget);
    expect(find.text(_first(_keyB)), findsNothing);
    expect(find.text(l10n.keyVerificationNewNumber), findsNothing);

    await _identity(mem, _keyC);
    appState.keyChanged();
    await t.pumpAndSettle();
    expect(find.text(_first(_keyC)), findsOneWidget);
    expect(find.text(l10n.keyVerificationNewNumber), findsOneWidget);
  });

  testWidgets('a tap marks the number on screen; a key that moved under it '
      'is refused and the new number shows', (t) async {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    await t.pumpWidget(_page());
    await t.pumpAndSettle();
    // their key moves on, and nothing has told the page yet
    await _identity(mem, _keyC);
    await t.tap(find.text(l10n.keyVerificationMarkAsVerified));
    await t.pumpAndSettle();
    expect(find.text(l10n.keyVerificationKeyMoved), findsOneWidget);
    expect(mem.rows('contacts').first['verified'], 0);
    expect(find.text(_first(_keyC)), findsOneWidget);
    await t.pump(const Duration(seconds: 4));

    await t.tap(find.text(l10n.keyVerificationMarkAsVerified));
    await t.pumpAndSettle();
    expect(mem.rows('contacts').first['verified'], 1);
    expect(mem.rows('contacts').first['verified_key'], _hex(_keyC));
  });
}
