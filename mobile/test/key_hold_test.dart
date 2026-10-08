// SPDX-License-Identifier: GPL-3.0-or-later
// a contact verified under one key who holds another now: nothing is sealed
// for them until the new number is checked (a new mark) or the new key is
// accepted. a contact never verified, one whose mark was taken off, one
// verified under the key they hold and the dev chat are never held. the
// rows are the app's own tables, kept in maps
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show
        HaloDb,
        acceptNewKeyIn,
        keyHeldIn,
        markVerified,
        signalEncrypt,
        useDatabasesForTest;
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart' show KeyHeld;
import 'package:shared_preferences/shared_preferences.dart';

import 'mem_db.dart';

const _peer = 'calm-orbit-lantern';
final _keyA = List<int>.generate(32, (i) => i + 1);
final _keyB = List<int>.generate(32, (i) => 200 - i);
String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Future<MemDb> _db(List<int> identity) async {
  final db = MemDb();
  await db.insert('contacts', {
    'halo_id': _peer,
    'onion': 'o',
    'xpub': '',
    'first_seen': 1,
    'last_seen': 1,
  });
  await _identity(db, identity);
  return db;
}

Future<void> _identity(MemDb db, List<int> key) async {
  await db.delete('peer_identities');
  await db.insert('peer_identities', {
    'address': _peer,
    'identity_key': Uint8List.fromList([5, ...key]),
  });
}

// a database whose every contact is held: what the seal asks
class _Held implements HaloDb {
  @override
  Future<bool> keyHeld(String haloId) async => true;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
  });

  test('never verified, or verified under the key held: not held', () async {
    final db = await _db(_keyA);
    expect(await keyHeldIn(db, _peer), isFalse);
    await markVerified(db, _peer, true, key: _hex(_keyA));
    expect(await keyHeldIn(db, _peer), isFalse);
  });

  test('verified, then their key moved: held until the new number is '
      'checked', () async {
    final db = await _db(_keyA);
    await markVerified(db, _peer, true, key: _hex(_keyA));
    await _identity(db, _keyB);
    expect(await keyHeldIn(db, _peer), isTrue);
    // a mark for the new number lifts it
    await markVerified(db, _peer, true, key: _hex(_keyB));
    expect(await keyHeldIn(db, _peer), isFalse);
  });

  test('or until the new key is accepted: no mark, no banner', () async {
    final db = await _db(_keyA);
    await markVerified(db, _peer, true, key: _hex(_keyA));
    await _identity(db, _keyB);
    await db.update('contacts', {'key_changed': 1});
    await acceptNewKeyIn(db, _peer);
    expect(await keyHeldIn(db, _peer), isFalse);
    final row = db.rows('contacts').first;
    expect(row['verified'], 0);
    expect(row['verified_key'], isNull);
    expect(row['key_changed'], 0);
  });

  test('a mark taken off by hand holds nothing', () async {
    final db = await _db(_keyA);
    await markVerified(db, _peer, true, key: _hex(_keyA));
    await markVerified(db, _peer, false);
    await _identity(db, _keyB);
    expect(await keyHeldIn(db, _peer), isFalse);
  });

  test('the dev chat is never held', () async {
    final db = await _db(_keyA);
    expect(await keyHeldIn(db, 'dev:abc'), isFalse);
  });

  test('nothing is sealed for a held contact', () async {
    final db = _Held();
    useDatabasesForTest(db, Session(db));
    await expectLater(signalEncrypt(_peer, 'hi'), throwsA(isA<KeyHeld>()));
  });
}
