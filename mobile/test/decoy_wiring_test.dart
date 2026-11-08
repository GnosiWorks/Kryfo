// SPDX-License-Identifier: GPL-3.0-or-later
// the decoy as the app opens it: its identity read off
// its own rows makes a v4 invite on its own store, link and qr the size of
// the everyday ones, born once at a point between this phone's setup and
// its own, its identity rows and set-up prekeys carrying that time. the
// next start keeps both. in the session its qr is the v4 one, and a reset
// makes the invite again now. its @name lookups go out on the decoy's own
// lane, and only once tor carries. nothing is written on the everyday side
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/invites.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        AppStateProfile,
        AppStateRoute,
        AppStateSession,
        HaloDb,
        HaloEngine,
        QuietIdentity,
        handleHaloUriAdded,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';
import 'pq_restart_kit.dart' show PqIo, needsShim;
import 'signal_kit.dart';

const _hour = 3600 * 1000;
const _day = 24 * _hour;
const _b32 = 'abcdefghijklmnopqrstuvwxyz234567';

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List _unhex(String h) => Uint8List.fromList([
  for (var i = 0; i + 1 < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
]);

String _onionOf(List<int> key) {
  final b = [...key, 0, 0, 3];
  var acc = 0, bits = 0;
  final out = StringBuffer();
  for (final x in b) {
    acc = (acc << 8) | x;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out.write(_b32[(acc >> bits) & 31]);
    }
  }
  return '$out.onion';
}

final _p = BigInt.parse(
  'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f',
  radix: 16,
);

String _fcPkOf(List<int> sk) {
  final x = sha256.convert(sk).bytes;
  final v = BigInt.parse(_hex(x), radix: 16);
  if (v >= _p) return 'error: not a key';
  final a = (v.modPow(BigInt.from(3), _p) + BigInt.from(7)) % _p;
  final y = a.modPow((_p + BigInt.one) >> 2, _p);
  return y.modPow(BigInt.two, _p) == a ? _hex(x) : 'error: not a key';
}

// the decoy's keys, as its rows keep them
final _face = ed.newKeyFromSeed(Uint8List.fromList(List.filled(32, 21)));
final _onionKey = ed.newKeyFromSeed(Uint8List.fromList(List.filled(32, 23)));
final _x = testKeyPair();

class _Engine implements HaloEngine {
  final lookups = <String>[];
  @override
  Map<String, dynamic>? quietDescribe(String e, String x, String o) => {
    'id': 'decoy-own-words',
    'ed_pub': _hex(ed.public(_face).bytes),
    'x_pub': _hex(_x.xPub),
    'onion': _onionOf(ed.public(_onionKey).bytes),
  };
  @override
  String onionOfKey(String keyHex) => _onionOf(_unhex(keyHex));
  @override
  String fcKeyPk(String skHex) => _fcPkOf(_unhex(skHex));
  @override
  String quietFirstContactPk(String xPriv, int counter) => 'error: none';
  @override
  Future<String> decoyTorGetJson(String url) async {
    lookups.add(url);
    return 'error: status 404';
  }

  @override
  String idFromEdPub(String hexPub) => 'no-such-id';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

class _Rows extends HaloDb {
  _Rows(this.mem, super.container);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemDb everydayMem;
  late MemDb decoyMem;
  late _Rows decoy;
  late _Rows live;
  late _Engine engine;
  late AppState app;
  final now = DateTime.now().millisecondsSinceEpoch;
  final setUpAt = now - 400 * _day;
  final v4At = now - 30 * _day;
  final decoyMade = now - 2 * _day;

  setUpAll(() async {
    if (needsShim != false) return;
    final docs = Directory.systemTemp.createTempSync('decoy_wiring');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    engine = _Engine();
    useEngineForTest(engine);
    everydayMem = MemDb();
    await everydayMem.insert('identity', {
      'id': 'my-own-words',
      'ed_priv': 'e',
      'x_priv': 'x',
      'created_at': setUpAt,
    });
    await everydayMem.insert('signal_meta', {'k': kMainMadeMeta, 'v': '$v4At'});
    live = _Rows(everydayMem, HaloContainer.everyday);
    decoyMem = MemDb();
    decoy = _Rows(decoyMem, HaloContainer.decoy);
    await decoy.saveIdentity(
      'decoy-own-words',
      _hex(_face.bytes),
      _hex(_x.privateKey.serialize()),
    );
    await decoyMem.update('identity', {'created_at': decoyMade});
    await decoyMem.insert('signal_meta', {
      'k': 'onion_key',
      'v': _hex(_onionKey.bytes),
    });
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    app = AppState(io: PqIo(), router: router);
    useDatabasesForTest(live, Session(live));
  });

  late QuietIdentity q;

  test('a start makes the decoy\'s v4 invite on its own store, born once '
      'between the phone\'s setup and its own', () async {
    q = (await app.quietOfForTest(decoy))!;
    expect(q.invite, startsWith(kInviteLinkPrefix));
    expect(q.qr, startsWith(kInviteLinkPrefix));
    // the sizes the everyday main invite has (invites_test: 2032 and 288)
    expect(inviteOfLink(q.invite)!.length, 2032);
    expect(inviteOfLink(q.qr!)!.length, 288);
    final born = int.parse(
      decoyMem
              .rows('signal_meta')
              .firstWhere((r) => r['k'] == kDecoyBornMeta)['v']
          as String,
    );
    expect(born, inInclusiveRange(setUpAt, decoyMade));
    expect(decoyMem.rows('identity').single['created_at'], born);
    expect(decoyMem.rows('identities').single['created_at'], born);
    for (final t in ['signed_prekeys', 'kyber_prekeys']) {
      for (final r in decoyMem.rows(t)) {
        if (r['invite_id'] == '') expect(r['created_at'], born, reason: t);
      }
    }
    final inv = decoyMem.rows('invites').single;
    expect(inv['issued'] as int, greaterThanOrEqualTo(v4At ~/ _hour));
    expect(inv['issued'] as int, greaterThanOrEqualTo(born ~/ _hour));
    expect(inv['issued'] as int, lessThanOrEqualTo(now ~/ _hour + 1));
    // the next start keeps both
    final again = (await app.quietOfForTest(decoy))!;
    expect(again.invite, q.invite);
    expect(
      decoyMem.rows('signal_meta').where((r) => r['k'] == kDecoyBornMeta),
      hasLength(1),
    );
    // nothing of it on the everyday side
    expect(everydayMem.rows('invites'), isEmpty);
    expect(everydayMem.rows('fc_keys'), isEmpty);
  }, skip: needsShim);

  test('in the session its qr is the v4 one, and a reset makes the invite '
      'again now', () async {
    useDatabasesForTest(live, Session(decoy));
    app.decoyOpenForTest(decoy, q);
    expect(await app.sessionInviteQr(), q.qr);
    expect(await app.sessionInvite(), q.invite);
    final before = decoyMem.rows('invites').single['id'];
    await app.resetInviteAddress();
    final after = decoyMem.rows('invites').single;
    expect(after['id'], isNot(before));
    expect(
      after['issued'] as int,
      closeTo(DateTime.now().millisecondsSinceEpoch ~/ _hour, 1),
    );
    final link = await app.sessionInvite();
    expect(link, startsWith(kInviteLinkPrefix));
    expect(link, isNot(q.invite));
    expect(await app.sessionInviteQr(), isNot(q.qr));
    expect(everydayMem.rows('invites'), isEmpty);
  }, skip: needsShim);

  test('its @name lookup goes on the decoy\'s own lane once tor carries, and '
      'says so when it does not', () async {
    app.sendModeForTest = 'balanced';
    app.setTorStatusForTest(TorStatus.off);
    expect(await handleHaloUriAdded('@wren', app: app), (
      l10n.handleSearchNeedsTor,
      false,
    ));
    expect(engine.lookups, isEmpty);
    app.setTorStatusForTest(TorStatus.bootstrapped);
    expect(await handleHaloUriAdded('@wren', app: app), (
      l10n.handleNobodyHasClaimed('@wren'),
      false,
    ));
    expect(engine.lookups.single, contains('wren'));
  }, skip: needsShim);
}
