// SPDX-License-Identifier: GPL-3.0-or-later
// before they add us back, a send's relay copy goes to their first-contact
// address only, or to the pair address when there is none, never both: the
// same words at both would let a relay tie the pair address to the invite.
// a peer reads the first-contact lane whether or not it has added us, so
// one copy there still reaches it
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloDb, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';

const _amy = 'amy-who-waits';

class _Rows extends HaloDb {
  _Rows(this.mem, [super.container]);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  // its or-clause is past what the map rows read
  @override
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async => const [];
  @override
  Future<void> bumpUnread(String peerId) async {}
  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async => {};
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async => const [];
}

class _Io extends ArrivalIo {
  var firstDown = false;
  var onionDown = false;

  @override
  Future<String> firstContactSend(String xPub, String fc, String cipher) async {
    sent.add(('fc $xPub', cipher));
    return firstDown ? 'error: no relays accepted' : 'ok';
  }

  @override
  Future<String> onionSend(String onion, String cipher) async {
    sent.add(('onion $onion', cipher));
    return onionDown ? 'error: timeout' : 'ok';
  }
}

class _Engine implements HaloEngine {
  @override
  void nostrSubscribeBg(String peerXPubHex) {}
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late MemDb mem;
  late _Rows db;
  late _Io io;
  late AppState app;

  setUpAll(() {
    docs = Directory.systemTemp.createTempSync('one_relay_copy');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    useEngineForTest(_Engine());
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    mem = MemDb();
    db = _Rows(mem, HaloContainer.everyday);
    io = _Io();
    await mem.insert('contacts', {
      'halo_id': _amy,
      'onion': 'o-$_amy',
      'xpub': 'x-$_amy',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 0,
    });
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    app = AppState(io: io, router: router)
      ..myId = 'me'
      ..sendModeForTest = 'fast';
    useDatabasesForTest(db, Session(db));
    await app.rememberPeerFc(_amy, 'fc-$_amy');
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  Future<void> contact(Map<String, Object?> v) =>
      mem.update('contacts', v, where: 'halo_id = ?', whereArgs: [_amy]);

  // the routes a send went by, in order
  List<String> went() => [for (final (to, _) in io.sent) to.split(' ').first];

  group('not added back yet', () {
    test('onion and the first-contact address, never the pair address '
        'beside them', () async {
      await app.sendAcceptAck(_amy);
      await settle();
      expect(went(), unorderedEquals(['onion', 'fc']));
    });

    test(
      'a dead onion leaves the first-contact copy as the only one',
      () async {
        io.onionDown = true;
        await app.sendAcceptAck(_amy);
        await settle();
        expect(went(), unorderedEquals(['onion', 'fc']));
      },
    );

    test('a first-contact address that does not take it is not followed '
        'by the pair address', () async {
      await contact({'onion': ''});
      io.firstDown = true;
      await app.sendAcceptAck(_amy);
      await settle();
      expect(went(), ['fc']);
    });

    test('with no first-contact address the pair address is the relay '
        'copy', () async {
      await app.forgetPeerFc(_amy);
      await app.sendAcceptAck(_amy);
      await settle();
      expect(went(), unorderedEquals(['onion', 'relay']));
    });
  });

  test('once they added us back, the pair address only', () async {
    await contact({'back_paired': 1});
    await app.sendAcceptAck(_amy);
    await settle();
    expect(went(), ['relay']);
  });

  test('one that came by the first-contact lane from someone added is '
      'filed as theirs', () async {
    io.opens['c1'] = (
      _amy,
      await wrapMessage('hi', msgUid: 'a1', sender: asSender(_amy)),
    );
    await app.receiveRelay([(peer: 'firstcontact', cipher: 'c1')]);
    await settle();
    expect(
      [
        for (final r in mem.rows('messages'))
          if (r['peer_id'] == _amy && r['direction'] == 'in') r['msg_uid'],
      ],
      ['a1'],
    );
  });
}
