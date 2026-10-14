// SPDX-License-Identifier: GPL-3.0-or-later
// the scam shield on the receive side: it reads a stranger's request and
// nothing else. a contact's message, a group's, and anything at all while
// the switch is off never reach it, and the switch is the one of the
// session the message lands in. a clean request leaves no row, and the
// check sends nothing anywhere. signal and the database are stand-ins
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show AppState, useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/scam_prefs.dart';
import 'package:kryfo/scam_shield.dart' show ShieldFlag;
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _f = 'plain-friend-here'; // a contact
const _s = 'guitar-present-kid'; // a stranger, a request
const _m = 'quiet-member-one'; // in a group with me, never added
const _a = 'admin-of-group';
const _g = 'grp000000001';

const _scam =
    'Hi, this is the Kryfo support team. Send me the 6-digit '
    'code you just got so we can keep your account.';

class _World {
  _World(HaloContainer c) : live = ArrivalRows(c);
  final ArrivalRows live;
  final io = ArrivalIo();
  late AppState app;
  var _n = 0;

  static Future<_World> make([HaloContainer c = HaloContainer.everyday]) async {
    final w = _World(c);
    w.live.person(_f, onion: 'o-$_f', xpub: 'x-$_f');
    w.live.person(_s, onion: 'o-$_s', xpub: 'x-$_s', accepted: 0);
    w.live.person(_a, onion: 'o-$_a', xpub: 'x-$_a');
    w.live.person(_m, onion: 'o-$_m', xpub: 'x-$_m', accepted: 0);
    w.live.group(_g, ['me', _a, _m], admin: _a);
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    w.app = AppState(io: w.io, router: router)..myId = 'me';
    useDatabasesForTest(w.live, Session(w.live));
    return w;
  }

  Future<void> from(String who, String text, {String? group}) async {
    final c = 'c${_n++}';
    io.opens[c] = (
      who,
      await wrapMessage(
        text,
        msgUid: 'u$_n',
        groupId: group,
        sender: asSender(who),
      ),
    );
    await app.receiveOnion([c]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }

  List<String> get shieldCalls => [
    for (final c in live.calls)
      if (c.startsWith('shieldFor') || c.startsWith('setShield')) c,
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('a stranger\'s scam request is flagged, with its reason', () async {
    final w = await _World.make();
    await w.from(_s, _scam);
    final flag = ShieldFlag.fromRow(w.live.shields[_s]);
    expect(flag, isNotNull);
    expect(flag!.lead.code, 'fake_support');
  });

  test('a contact is never checked, whatever they write', () async {
    final w = await _World.make();
    await w.from(_f, _scam);
    expect(w.live.msgs.where((m) => m['peer_id'] == _f), hasLength(1));
    expect(w.shieldCalls, isEmpty);
    expect(w.live.shields, isEmpty);
  });

  test('a group is never checked, not even a member never added', () async {
    final w = await _World.make();
    await w.from(_m, _scam, group: _g);
    expect(w.live.msgs.where((m) => m['peer_id'] == _m), hasLength(1));
    expect(w.shieldCalls, isEmpty);
    expect(w.live.shields, isEmpty);
  });

  test('a clean request leaves nothing behind', () async {
    final w = await _World.make();
    await w.from(_s, 'hey, sam gave me your words. climbing thursday?');
    expect(w.live.shields, isEmpty);
    expect(w.live.calls, isNot(contains('setShield:$_s')));
  });

  test('the second message of a request is read too', () async {
    final w = await _World.make();
    await w.from(_s, 'hi, how are you?');
    expect(w.live.shields, isEmpty);
    await w.from(_s, 'quick favour: what is the verification code you got?');
    expect(ShieldFlag.fromRow(w.live.shields[_s])?.lead.code, 'asks_secret');
  });

  test('switched off, nothing runs at all', () async {
    await saveScamShieldOn(false);
    final w = await _World.make();
    await w.from(_s, _scam);
    expect(w.live.msgs.where((m) => m['peer_id'] == _s), hasLength(1));
    expect(w.shieldCalls, isEmpty);
    expect(w.live.shields, isEmpty);
  });

  test('the switch is the one of the session it lands in', () async {
    // off in the decoy, on everywhere else
    await saveScamShieldOn(false, HaloContainer.decoy);
    final decoy = await _World.make(HaloContainer.decoy);
    await decoy.from(_s, _scam);
    expect(decoy.shieldCalls, isEmpty);
    // and the other way round
    SharedPreferences.setMockInitialValues({});
    await saveScamShieldOn(false);
    final open = await _World.make(HaloContainer.decoy);
    await open.from(_s, _scam);
    expect(open.live.shields.keys, [_s]);
  });

  test('a dismissed flag stays dismissed and is not checked again', () async {
    final w = await _World.make();
    await w.from(_s, _scam);
    w.live.shields[_s]!['dismissed'] = 1;
    final before = Map.of(w.live.shields[_s]!);
    await w.from(_s, 'send me your seed phrase right now');
    expect(w.live.shields[_s], before);
    expect(ShieldFlag.fromRow(w.live.shields[_s]), isNull);
  });

  test('the check sends nothing: on or off, the same goes out', () async {
    Future<List<(String, String)>> run(bool on) async {
      SharedPreferences.setMockInitialValues({});
      await saveScamShieldOn(on);
      final w = await _World.make();
      await w.from(_s, _scam);
      expect(w.live.shields.isNotEmpty, on);
      // the stamp of when a frame was written is the one thing that differs
      return [
        for (final (to, c) in w.io.sent)
          (to, c.replaceAll(RegExp(r'"w":\d+'), '')),
      ];
    }

    expect(await run(true), await run(false));
  });
}
