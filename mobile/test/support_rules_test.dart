// SPDX-License-Identifier: GPL-3.0-or-later
// the developer's own phone. developer mode takes his pinned private key,
// read once as the identity loads, and never holds in a decoy. a chat
// started from the Marios row lands in support by its marker; without one
// a stranger stays a request, and a blocked sender is dropped before
// anything is filed. requests, their count and the contacts leave support
// chats out, while the receive side still tries them. a support chat never
// brings in a group, a room or an introduction, and takes five messages
// before he answers, its proof of work still owed. his first reply takes
// it on and it stays in support. a waiting chat rings as a count, once a
// gap, never with its words; an answered one rings per message. the reset
// link is off on his phone. each guard, broken once, is caught. the
// databases are kept in maps; signal, the engine and android are stand-ins
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show Locale;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devModeOf;
import 'package:kryfo/devchat/dev_frame.dart' show kDevSupport;
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/devchat/support.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show AppIo, AppState, HaloDb, claimChat, releaseChat, useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/stranger_gate.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show CiphertextMessage, Curve;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart'
    show ConflictAlgorithm, Database;

import 'mem_db.dart';

const _me = 'marios-own-words';
const _words = 'scare-raven-rare';
// people writing to him, and one of his own contacts
const _s = 'slow-amber-fox';
const _t = 'tall-quiet-pine';
const _r = 'plain-rust-door';
const _c = 'close-old-friend';
// an opener and the proof of work ground for it at 20 bits
const _opener = 'Hi Marios, the app crashes when I send a photo';
const _openerPow = 191480;

String _hex(List<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();

// the public half the engine gives for a private x25519 key
String _pubOf(List<int> priv) => _hex(
  Curve.generateKeyPairFromPrivate(
    Uint8List.fromList(priv),
  ).publicKey.serialize().sublist(1),
);

// his private key, and the key the app pins from his card
late List<int> _hisPriv;
late DevKey _m1;

DevKey _key(String xPub, {DevKeyStatus status = DevKeyStatus.current}) =>
    DevKey(
      keyId: 'm1',
      threeWords: _words,
      xPub: xPub,
      bundle: 'unused',
      fc: 'ab' * 32,
      status: status,
    );

// the one count the requests pin asks in sql
class _Mem extends MemDb {
  static const _count =
      'SELECT COUNT(*) c FROM contacts WHERE accepted = 0 AND blocked = 0 '
      'AND IFNULL(archived, 0) = 0';

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    if (sql == _count) {
      return [
        {
          'c': rows('contacts')
              .where(
                (r) =>
                    r['accepted'] == 0 &&
                    r['blocked'] == 0 &&
                    (r['archived'] ?? 0) == 0,
              )
              .length,
        },
      ];
    }
    return super.rawQuery(sql, arguments);
  }
}

// a phone's database: the app's own code over tables kept in maps. what it
// asks in sql the maps do not speak is answered here the same way
class _Phone extends HaloDb {
  _Phone([super.container]);

  final mem = _Mem();

  @override
  Future<Database> open() async => mem;

  Future<void> person(
    String id, {
    int accepted = 1,
    int blocked = 0,
    int archived = 0,
  }) => mem.insert('contacts', {
    'halo_id': id,
    'onion': '',
    'xpub': 'x-$id',
    'first_seen': 1,
    'last_seen': 1,
    'accepted': accepted,
    'blocked': blocked,
    'archived': archived,
    'back_paired': 1,
  });

  Map<String, Object?>? row(String id) {
    for (final r in mem.rows('contacts')) {
      if (r['halo_id'] == id) return r;
    }
    return null;
  }

  List<Map<String, Object?>> msgs(String peer) => [
    for (final m in mem.rows('messages'))
      if (m['peer_id'] == peer) m,
  ];

  Set<String> get filed => {
    for (final r in mem.rows('support_chats')) r['halo_id'] as String,
  };

  List<Map<String, Object?>> _people(bool Function(Map<String, Object?>) ok) =>
      [
        for (final r in mem.rows('contacts'))
          if (ok(r)) r,
      ];

  @override
  Future<List<Map<String, Object?>>> contacts() async =>
      _people((r) => r['accepted'] == 1);
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async => _people(
    (r) => r['accepted'] == 0 && r['blocked'] == 0 && (r['archived'] ?? 0) == 0,
  );
  @override
  Future<List<Map<String, Object?>>> parkedRequests() async => _people(
    (r) => r['accepted'] == 0 && r['blocked'] == 0 && r['archived'] == 1,
  );
  @override
  Future<List<Map<String, Object?>>> vouchedPending() async => const [];
  @override
  Future<bool> isVouched(String haloId) async => false;
  @override
  Future<int> countMessagesFrom(String peerId) async =>
      msgs(peerId).where((m) => m['direction'] == 'in').length;
  @override
  Future<int> countMessagesTo(String peerId) async =>
      msgs(peerId).where((m) => m['direction'] == 'out').length;
  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async => {
    for (final m in mem.rows('messages'))
      if (m['group_id'] == null) m['peer_id'] as String: m,
  };
  @override
  Future<void> bumpUnread(String peerId) async {
    final r = row(peerId);
    if (r == null) return;
    await mem.update(
      'contacts',
      {'unread': (r['unread'] as int? ?? 0) + 1},
      where: 'halo_id = ?',
      whereArgs: [peerId],
    );
  }

  @override
  Future<void> markSeen(String hash) async {
    await mem.insert('seen_msgs', {
      'hash': hash,
      'ts': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<List<Map<String, Object?>>> loadGroups() async => mem.rows('groups');
  @override
  Future<List<Map<String, Object?>>> unsentOutbox() async => const [];
  @override
  Future<void> holdCipher(String peerId, String cipher) async {
    await mem.insert('held_onion', {
      'peer_id': peerId,
      'cipher': cipher,
      'at': 1,
    });
  }

  @override
  Future<void> createGroup(
    String groupId,
    String name,
    List<String> members, {
    required bool isAdmin,
    String? adminId,
  }) async {
    await mem.insert('groups', {
      'group_id': groupId,
      'name': name,
      'created_at': 1,
      'is_admin': isAdmin ? 1 : 0,
      'admin_id': adminId,
    });
    for (final m in members) {
      await mem.insert('group_members', {
        'group_id': groupId,
        'halo_id': m,
        'joined_at': 1,
      });
    }
  }

  @override
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async =>
      (
        people: {
          for (final r in mem.rows('contacts'))
            r['halo_id'] as String: r['accepted'] == 1,
        },
        groups: {for (final g in mem.rows('groups')) g['group_id'] as String},
      );
}

// signal and the engine as the receive side reaches them
class _Io implements AppIo {
  final opens = <String, (String, String)>{};
  ({String haloId, String plain, UnwrappedMessage env})? firstContact;
  final listened = <String>[];
  final sent = <(String, String)>[];
  final rang = <String>[];

  @override
  Future<String?> decrypt(
    String peer,
    String cipher, {
    bool flagKeyChange = false,
  }) async {
    final o = opens[cipher];
    return o != null && o.$1 == peer ? o.$2 : null;
  }

  @override
  Future<List<String>> sessionAddresses() async => const [];
  @override
  Future<({String haloId, String plain, UnwrappedMessage env})?>
  openFirstContact(String cipher) async => firstContact;
  @override
  Future<bool> hasSession(String peer) async => true;
  @override
  Future<String> encrypt(String peer, String plain) async => 'to $peer $plain';
  @override
  void listen(String xPub) => listened.add(xPub);
  @override
  String edPub() => 'ed-me';
  @override
  String xPub() => 'x-me';
  @override
  Future<String> relaySend(String xPub, String cipher) async {
    sent.add(('relay $xPub', cipher));
    return 'ok';
  }

  @override
  Future<String> onionSend(String onion, String cipher) async {
    sent.add(('onion $onion', cipher));
    return 'ok';
  }

  @override
  Future<String> firstContactSend(String xPub, String fc, String cipher) async {
    sent.add(('fc $xPub', cipher));
    return 'ok';
  }

  @override
  Future<void> notify({
    required String title,
    required String body,
    String? payload,
  }) async => rang.add('$title|$body|$payload');

  @override
  Future<void> unnotify(String payload) async {}
}

// android as support rings through it: every call, as it came
class _Bell implements SupportBell {
  final calls = <String>[];

  List<String> get summaries => [
    for (final c in calls)
      if (c.startsWith('summary')) c,
  ];

  @override
  Future<void> summary({
    required int chats,
    required int messages,
    required bool alert,
  }) async => calls.add(
    'summary ${alert ? 'ring' : 'quiet'} $chats/$messages '
    '${supportSummaryLine(chats, messages)}',
  );

  @override
  Future<void> chat({
    required String chatId,
    required String title,
    required String body,
  }) async => calls.add('chat $chatId $title: $body');

  @override
  Future<void> clear() async => calls.add('clear');
}

// the router with nothing hidden
class _NoStore implements RouterStore {
  @override
  Future<List<Map<String, Object?>>> hidden() async => const [];
  @override
  Future<String?> meta(String k) async => null;
  @override
  Future<int> inboxCount() async => 0;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the router was asked for ${i.memberName}');
}

class _NoSeal implements VaultSeal {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the seal was asked for ${i.memberName}');
}

// what was sent without being waited for gets there
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

// his phone, or with [dev] false anyone's, with his own contact C
class _World {
  final phone = _Phone();
  final io = _Io();
  final bell = _Bell();
  late AppState app;
  var _n = 0;

  static Future<_World> make({bool dev = true}) async {
    final w = _World();
    await w.phone.person(_c);
    final router = VaultRouter(_NoStore(), _NoSeal());
    await router.load();
    w.app = AppState(io: w.io, router: router, bell: w.bell)
      ..myId = _me
      ..myXPub = dev
          ? _pubOf(_hisPriv)
          : _pubOf(Curve.generateKeyPair().privateKey.serialize());
    useDatabasesForTest(w.phone, Session(w.phone));
    return w;
  }

  // a frame as the person's app wraps it: from the Marios row it carries
  // the marker
  Future<String> frame(
    String text, {
    bool marked = true,
    String? uid,
    GroupControl? groupControl,
    String? groupId,
    IntroFrame? intro,
    String? from,
    int? pow,
  }) => wrapMessage(
    text,
    msgUid: uid ?? 'u${_n++}',
    supportMarker: marked ? kDevSupport : null,
    groupControl: groupControl,
    groupId: groupId,
    intro: intro,
    powNonce: pow,
    powBitsUsed: pow == null ? null : powBits,
    sender: from == null
        ? null
        : SenderInfo(
            haloId: from,
            edPub: 'ed-$from',
            onion: '',
            xPub: 'x-$from',
          ),
  );

  // a frame on the onion lane from someone with a row here
  Future<void> onion(String from, String plain) async {
    final c = 'c${_n++}';
    io.opens[c] = (from, plain);
    await app.receiveOnion([c]);
    await _settle();
  }

  // someone's very first message, with no session yet
  Future<void> firstContact(String id, String plain) async {
    io.firstContact = (haloId: id, plain: plain, env: unwrapMessage(plain));
    await app.receiveOnion([
      base64Encode([CiphertextMessage.prekeyType, _n++, 7, 7]),
    ]);
    await _settle();
  }

  // a stranger whose opener made their row, as back-pair leaves it
  Future<void> stranger(String id) => phone.person(id, accepted: 0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUpAll(() {
    docs = Directory.systemTemp.createTempSync('support_rules_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    _hisPriv = Curve.generateKeyPair().privateKey.serialize();
    _m1 = _key(_pubOf(_hisPriv));
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    useDevKeysForTest([_m1]);
    setL10nLocale(const Locale('en'));
  });

  tearDown(() => useDevKeysForTest(null));

  group('the table', () {
    test('made on create and on upgrade, wrapped so the app always opens', () {
      final src = File('lib/main.dart').readAsStringSync();
      final create = src.indexOf('onCreate: (db, _) async {');
      final upgrade = src.indexOf('onUpgrade: (db, oldV, newV) async {');
      expect(
        src.substring(create, upgrade),
        contains('await _supportTables(db);'),
      );
      expect(
        RegExp(
          r'if \(oldV < 56\) \{[^}]*await _supportTables\(db\);',
        ).hasMatch(src.substring(upgrade)),
        isTrue,
      );
      final wrap = src.indexOf('Future<void> _supportTables(Database db)');
      final body = src.substring(wrap, src.indexOf('\n}\n', wrap));
      expect(body, contains('try {'));
      expect(body, contains('catch (e)'));
    });

    test('made twice, it keeps what it holds', () async {
      final mem = MemDb(except: {'support_chats'});
      await supportTables(mem);
      await SupportChats(() async => mem).file(_s);
      await supportTables(mem);
      expect(await SupportChats(() async => mem).ids(), {_s});
    });

    test(
      'every way a reply leaves the chat screen takes the chat on first',
      () {
        final src = File('lib/screens/chat_screen.dart').readAsStringSync();
        final saves = RegExp(
          r"session\.saveMessage\(\s*widget\.peerHaloId,\s*'out',",
        ).allMatches(src).toList();
        expect(saves, isNotEmpty);
        for (final m in saves) {
          final before = src.substring(m.start - 120, m.start);
          expect(before, contains('await _answerSupport();'), reason: before);
        }
      },
    );
  });

  group('developer mode', () {
    test('only the pinned private key turns it on', () async {
      final w = await _World.make(dev: false);
      expect(w.app.devMode, isFalse);
      // the key his private key makes is the pinned one
      w.app.myXPub = _pubOf(_hisPriv);
      expect(w.app.devMode, isTrue);
      // another key is not, whatever three words the identity has
      final other = Curve.generateKeyPair().privateKey.serialize();
      w.app
        ..myId = _words
        ..myXPub = _pubOf(other);
      expect(w.app.devMode, isFalse);
      expect(devModeOf(_pubOf(other)), isFalse);
    });

    test('a retired key is no developer, a previous one still is', () {
      final x = _pubOf(_hisPriv);
      useDevKeysForTest([_key(x, status: DevKeyStatus.retired)]);
      expect(devModeOf(x), isFalse);
      useDevKeysForTest([_key(x, status: DevKeyStatus.previous)]);
      expect(devModeOf(x), isTrue);
      useDevKeysForTest(const []);
      expect(devModeOf(x), isFalse);
    });

    test('never in a decoy session, back with the everyday one', () async {
      final w = await _World.make();
      expect(w.app.devMode, isTrue);
      final decoy = _Phone(HaloContainer.decoy);
      useDatabasesForTest(w.phone, Session(decoy));
      expect(w.app.devMode, isFalse);
      // nothing of the inbox is read or counted there
      await w.app.refreshContacts();
      expect(w.app.supportWaiting, 0);
      useDatabasesForTest(w.phone, Session(w.phone));
      expect(w.app.devMode, isTrue);
    });

    test('read once, as the identity loads', () async {
      final w = await _World.make();
      expect(w.app.devMode, isTrue);
      // a key list that changes under a running app changes nothing
      useDevKeysForTest(const []);
      expect(w.app.devMode, isTrue);
      w.app.myXPub = w.app.myXPub;
      expect(w.app.devMode, isFalse);
    });
  });

  group('routing', () {
    test(
      'a marked opener from a stranger lands in support, not requests',
      () async {
        final w = await _World.make();
        await w.firstContact(
          _s,
          await w.frame(_opener, from: _s, pow: _openerPow),
        );
        expect(w.phone.filed, {_s});
        expect(w.phone.msgs(_s).single['plaintext'], _opener);
        expect(w.app.pendingCount, 0);
        expect(w.app.supportWaiting, 1);
        expect([for (final c in w.app.contacts) c.haloId], [_c]);
        expect(await w.phone.requestsInbox(), isEmpty);
        // no request notification: the support summary instead
        expect(w.io.rang, isEmpty);
        expect(w.bell.summaries, hasLength(1));
        expect(w.bell.summaries.single, startsWith('summary ring 1/1'));
      },
    );

    test('without the marker a stranger stays a request', () async {
      final w = await _World.make();
      await w.firstContact(
        _s,
        await w.frame(_opener, from: _s, pow: _openerPow, marked: false),
      );
      expect(w.phone.filed, isEmpty);
      expect(w.phone.msgs(_s), hasLength(1));
      expect(w.app.pendingCount, 1);
      expect(w.app.supportWaiting, 0);
      expect(w.io.rang.single, startsWith(l10n.appNewRequest));
      expect(w.bell.calls, isEmpty);
    });

    test('a blocked sender is dropped before anything is filed', () async {
      final w = await _World.make();
      await w.phone.person(_s, accepted: 0, blocked: 1);
      await w.onion(_s, await w.frame('let me in'));
      expect(w.phone.filed, isEmpty);
      expect(w.phone.msgs(_s), isEmpty);
      expect(w.bell.calls, isEmpty);
      expect(w.io.rang, isEmpty);
    });

    test('a contact he already has stays a contact, marker or not', () async {
      final w = await _World.make();
      await w.onion(_c, await w.frame('hi from the row'));
      expect(w.phone.filed, isEmpty);
      expect([for (final c in w.app.contacts) c.haloId], [_c]);
    });

    test('the dev chat is never filed', () async {
      final chats = SupportChats(() async => MemDb());
      final f = await fileSupport(
        chats,
        'dev:m1',
        unwrapMessage(await wrapMessage('hi', supportMarker: kDevSupport)),
        accepted: () async => false,
      );
      expect(f.on, isFalse);
      expect(await chats.ids(), isEmpty);
    });

    test('once filed, a chat stays in support without the marker', () async {
      final w = await _World.make();
      await w.stranger(_s);
      await w.onion(_s, await w.frame('one'));
      await w.onion(_s, await w.frame('two', marked: false));
      expect(w.phone.filed, {_s});
      expect(w.phone.msgs(_s), hasLength(2));
      expect(w.app.pendingCount, 0);
    });

    test('on anyone else\'s phone the marker files nothing', () async {
      final w = await _World.make(dev: false);
      await w.stranger(_s);
      await w.onion(_s, await w.frame('hi'));
      expect(w.phone.filed, isEmpty);
      expect(w.app.pendingCount, 1);
      expect(w.bell.calls, isEmpty);
    });

    test('while a decoy is on screen it still files where it arrives, in '
        'the everyday container', () async {
      final w = await _World.make();
      await w.stranger(_s);
      final decoy = _Phone(HaloContainer.decoy);
      useDatabasesForTest(w.phone, Session(decoy));
      await w.onion(_s, await w.frame('hi'));
      expect(w.phone.filed, {_s});
      expect(decoy.filed, isEmpty);
    });

    test('the marker lifts nothing: an opener without its proof of work is '
        'not kept', () async {
      final w = await _World.make();
      await w.firstContact(_s, await w.frame(_opener, from: _s));
      expect(w.phone.msgs(_s), isEmpty);
      expect(w.bell.summaries, isEmpty);
      // the one that pays rings as a new chat
      await w.firstContact(
        _s,
        await w.frame(_opener, from: _s, pow: _openerPow),
      );
      expect(w.phone.msgs(_s), hasLength(1));
      expect(w.bell.summaries, [startsWith('summary ring 1/1')]);
    });

    test('five before he answers, and a plain stranger two', () async {
      final w = await _World.make();
      await w.stranger(_s);
      await w.stranger(_r);
      for (var i = 0; i < 7; i++) {
        await w.onion(_s, await w.frame('support $i'));
        await w.onion(_r, await w.frame('request $i', marked: false));
      }
      expect(w.phone.msgs(_s), hasLength(kSupportCap));
      expect(w.phone.msgs(_r), hasLength(2));
      // the rest wait, sealed, for the answer
      final held = [
        for (final h in w.phone.mem.rows('held_onion')) h['peer_id'],
      ];
      expect(held.where((p) => p == _s), hasLength(2));
      expect(held.where((p) => p == _r), hasLength(5));
    });

    test('a message brings a done chat back', () async {
      final w = await _World.make();
      await w.stranger(_s);
      await w.onion(_s, await w.frame('one'));
      await w.phone.support.setDone(_s, true);
      expect(
        (await w.phone.support.list()).single.section,
        SupportSection.done,
      );
      await w.onion(_s, await w.frame('two'));
      expect(
        (await w.phone.support.list()).single.section,
        SupportSection.waiting,
      );
    });
  });

  group('the lists', () {
    test(
      'requests, their count and the contacts leave support chats out',
      () async {
        final w = await _World.make();
        // S waits for an answer, T was answered, R is a plain request
        for (final id in [_s, _t]) {
          await w.stranger(id);
          await w.onion(id, await w.frame('from the row'));
        }
        await w.stranger(_r);
        await w.onion(_r, await w.frame('hello', marked: false));
        expect(await w.app.answerSupport(_t), isTrue);
        await w.app.refreshContacts();
        expect(w.phone.filed, {_s, _t});
        expect(
          [for (final r in await w.phone.requestsInbox()) r['halo_id']],
          [_r],
        );
        expect(await w.phone.pendingRequestCount(), 1);
        expect(w.app.pendingCount, 1);
        expect([for (final c in w.app.contacts) c.haloId], [_c]);
        expect(w.app.supportWaiting, 1);
        // the receive side still tries them as requests
        expect([
          for (final r in await w.phone.pendingRequests()) r['halo_id'],
        ], containsAll([_s, _r]));
        // and with a vault open, the same
        final vault = _Phone(HaloContainer.vault);
        final s = await Session.withVault(w.phone, vault);
        expect([for (final r in await s.requestsInbox()) r['halo_id']], [_r]);
        expect(await s.pendingRequestCount(), 1);
      },
    );

    test('the support list: waiting, answered, done, newest first', () async {
      final w = await _World.make();
      for (final id in [_s, _t, _r]) {
        await w.stranger(id);
        await w.onion(id, await w.frame('hi $id'));
      }
      await w.app.answerSupport(_t);
      await w.phone.support.setDone(_r, true);
      final all = await w.phone.support.list();
      expect(
        {for (final c in all) c.haloId: c.section},
        {
          _s: SupportSection.waiting,
          _t: SupportSection.answered,
          _r: SupportSection.done,
        },
      );
      expect(all.firstWhere((c) => c.haloId == _s).unread, 1);
      expect(
        all.firstWhere((c) => c.haloId == _s).last?['plaintext'],
        'hi $_s',
      );
      expect(await w.phone.support.waiting(), 1);
      expect(await w.phone.support.markWaitingDone(), [_s]);
      expect(await w.phone.support.waiting(), 0);
    });

    test('a table that could not be made reads as none', () async {
      final chats = SupportChats(() async => MemDb(except: {'support_chats'}));
      expect(await chats.ids(), isEmpty);
      expect(await chats.has(_s), isFalse);
      expect(await chats.lastAlert(), isNull);
      expect(await chats.list(), isEmpty);
      expect(await chats.waiting(), 0);
    });
  });

  group('what a support chat never brings in', () {
    test('a group, a room or an introduction, even once answered', () async {
      final w = await _World.make();
      await w.stranger(_s);
      await w.onion(_s, await w.frame('hi'));
      await w.app.answerSupport(_s);
      // a group to put him in
      await w.onion(
        _s,
        await w.frame(
          '',
          groupId: 'g1',
          groupControl: const GroupControl(
            type: 'create',
            name: 'join us',
            members: [_s, _me],
          ),
        ),
      );
      // a room's knock
      await w.onion(
        _s,
        await w.frame(
          '',
          groupId: 'r1',
          groupControl: const GroupControl(type: 'join'),
        ),
      );
      // someone handed on
      await w.onion(
        _s,
        await w.frame(
          '',
          intro: const IntroFrame(haloId: _r, onion: '', xPub: 'x-r'),
        ),
      );
      expect(w.phone.mem.rows('groups'), isEmpty);
      expect(w.phone.mem.rows('vouches'), isEmpty);
      expect(w.phone.row(_r), isNull);
      // the same from his own contact is taken as ever
      await w.onion(
        _c,
        await w.frame(
          '',
          marked: false,
          groupId: 'g2',
          groupControl: const GroupControl(
            type: 'create',
            name: 'friends',
            members: [_c, _me],
          ),
        ),
      );
      expect(
        [for (final g in w.phone.mem.rows('groups')) g['group_id']],
        ['g2'],
      );
    });
  });

  group('the first reply', () {
    test('takes the chat on, and it stays in support', () async {
      final w = await _World.make();
      await w.stranger(_s);
      await w.onion(_s, await w.frame('hi'));
      expect(await w.app.answerSupport(_s), isTrue);
      await _settle();
      expect(w.phone.row(_s)!['accepted'], 1);
      // listened for, and told they are in
      expect(w.io.listened, contains('x-$_s'));
      expect(w.io.sent.where((s) => s.$1 == 'relay x-$_s'), isNotEmpty);
      expect(w.phone.filed, {_s});
      expect(
        (await w.phone.support.list()).single.section,
        SupportSection.answered,
      );
      expect([for (final c in w.app.contacts) c.haloId], [_c]);
      // a second reply changes nothing
      expect(await w.app.answerSupport(_s), isFalse);
    });

    test('what the cap held opens with it', () async {
      final w = await _World.make();
      await w.stranger(_s);
      for (var i = 0; i < 6; i++) {
        await w.onion(_s, await w.frame('m$i'));
      }
      expect(w.phone.msgs(_s), hasLength(kSupportCap));
      await w.app.answerSupport(_s);
      await _settle();
      expect(w.phone.msgs(_s), hasLength(6));
    });

    test('nothing for a plain request, a contact or another phone', () async {
      final w = await _World.make();
      await w.stranger(_r);
      await w.onion(_r, await w.frame('hi', marked: false));
      expect(await w.app.answerSupport(_r), isFalse);
      expect(await w.app.answerSupport(_c), isFalse);
      expect(w.phone.row(_r)!['accepted'], 0);
      await w.stranger(_s);
      await w.onion(_s, await w.frame('hi'));
      w.app.myXPub = _pubOf(Curve.generateKeyPair().privateKey.serialize());
      expect(await w.app.answerSupport(_s), isFalse);
      expect(w.phone.row(_s)!['accepted'], 0);
    });
  });

  group('notifications', () {
    test('a burst of new chats rings once, then updates quietly', () async {
      final w = await _World.make();
      for (final id in [_s, _t, _r]) {
        await w.stranger(id);
        await w.onion(id, await w.frame('help'));
      }
      await w.onion(_s, await w.frame('more'));
      expect(w.bell.summaries, [
        startsWith('summary ring 1/1'),
        startsWith('summary quiet 2/2'),
        startsWith('summary quiet 3/3'),
        startsWith('summary quiet 3/4'),
      ]);
      expect(w.bell.summaries.last, endsWith('3 new chats · 4 new messages'));
    });

    test('a new chat after the gap rings again', () async {
      final w = await _World.make();
      await w.stranger(_s);
      await w.onion(_s, await w.frame('help'));
      // the last ring, a gap and a minute ago
      final ago =
          DateTime.now().millisecondsSinceEpoch -
          kSupportGap.inMilliseconds -
          60000;
      await w.phone.support.alerted(_s, ago);
      await w.onion(_s, await w.frame('still here'));
      expect(w.bell.summaries.last, startsWith('summary quiet'));
      await w.stranger(_t);
      await w.onion(_t, await w.frame('me too'));
      expect(w.bell.summaries.last, startsWith('summary ring 2/3'));
      // and takes the ring for itself
      expect(await w.phone.support.lastAlert(), greaterThan(ago));
    });

    test('a stranger\'s words are never in the shade', () async {
      final w = await _World.make();
      await w.stranger(_s);
      const secret = 'my address is 12 hidden lane';
      await w.onion(_s, await w.frame(secret));
      await w.onion(_s, await w.frame('$secret again'));
      expect(w.bell.calls, isNotEmpty);
      for (final c in w.bell.calls) {
        expect(c, isNot(contains('hidden lane')));
        expect(c, isNot(contains(_s)));
      }
      expect(supportSummaryLine(1, 2), '1 new chat · 2 new messages');
    });

    test('an answered chat rings per message', () async {
      final w = await _World.make();
      await w.stranger(_s);
      await w.onion(_s, await w.frame('hi'));
      await w.app.answerSupport(_s);
      await w.onion(_s, await w.frame('thanks'));
      await w.onion(_s, await w.frame('it works now'));
      expect(
        [
          for (final c in w.bell.calls)
            if (c.startsWith('chat')) c,
        ],
        ['chat $_s $_s: thanks', 'chat $_s $_s: it works now'],
      );
      expect(w.io.rang, isEmpty);
    });

    test(
      'under the lock the inbox on screen is not being read: it rings',
      () async {
        final w = await _World.make();
        claimChat(kSupportPayload);
        addTearDown(() => releaseChat(kSupportPayload));
        await w.stranger(_s);
        await w.onion(_s, await w.frame('hi'));
        expect(w.bell.summaries, [startsWith('summary ring 1/1')]);
      },
    );

    test('nothing unread left takes the summary down', () async {
      final w = await _World.make();
      await w.stranger(_s);
      await w.onion(_s, await w.frame('hi'));
      await w.phone.clearUnread(_s);
      await ringSupport(w.phone.support, w.bell, chat: _s, fresh: false);
      expect(w.bell.calls.last, 'clear');
    });
  });

  group('the reset link', () {
    test('is refused on his phone', () async {
      final w = await _World.make();
      await w.app.resetInviteAddress();
      // anywhere else it goes on to the invite key, which needs a signal
      // store this test does not have
      final other = await _World.make(dev: false);
      await expectLater(other.app.resetInviteAddress(), throwsA(anything));
    });
  });

  // the checks above would catch each guard gone
  group('each guard, broken once, is caught', () {
    // the filing rules, run against [file]: what they get wrong
    Future<List<String>> filing(
      Future<({bool on, bool fresh})> Function(
        SupportChats,
        String,
        UnwrappedMessage, {
        required Future<bool> Function() accepted,
      })
      file,
    ) async {
      final bad = <String>[];
      final mem = MemDb();
      final chats = SupportChats(() async => mem);
      Future<({bool on, bool fresh})> go(
        String id,
        String wire, {
        bool accepted = false,
      }) =>
          file(chats, id, unwrapMessage(wire), accepted: () async => accepted);
      final marked = await wrapMessage('hi', supportMarker: kDevSupport);
      final plain = await wrapMessage('hi');
      final group = await wrapMessage(
        'hi',
        supportMarker: kDevSupport,
        groupId: 'g',
      );
      if ((await go('a', plain)).on) bad.add('files without the marker');
      if ((await go('b', marked, accepted: true)).on) {
        bad.add('files an accepted contact');
      }
      if ((await go('c', group)).on) bad.add('files a group frame');
      final first = await go('d', marked);
      if (!first.on || !first.fresh) bad.add('misses a marked opener');
      final again = await go('d', plain);
      if (!again.on) bad.add('lets a filed chat go without the marker');
      if (again.fresh) bad.add('opens a filed chat twice');
      await chats.setDone('d', true);
      await go('d', plain);
      if (mem.rows('support_chats').any((r) => r['state'] == 'done')) {
        bad.add('keeps a done chat done when written to');
      }
      return bad;
    }

    test('the filing', () async {
      expect(await filing(fileSupport), isEmpty);
      expect(
        await filing((c, s, e, {required accepted}) async {
          if (e.groupId == null && !await accepted()) {
            return (on: true, fresh: await c.file(s));
          }
          return (on: await c.has(s), fresh: false);
        }),
        contains('files without the marker'),
      );
      expect(
        await filing((c, s, e, {required accepted}) async {
          if (e.groupId == null && e.supportMarker != null) {
            return (on: true, fresh: await c.file(s));
          }
          return (on: await c.has(s), fresh: false);
        }),
        contains('files an accepted contact'),
      );
      expect(
        await filing((c, s, e, {required accepted}) async {
          if (e.supportMarker != null && !await accepted()) {
            return (on: true, fresh: await c.file(s));
          }
          return (on: await c.has(s), fresh: false);
        }),
        contains('files a group frame'),
      );
      expect(
        await filing((c, s, e, {required accepted}) async {
          if (e.groupId == null &&
              e.supportMarker != null &&
              !await accepted()) {
            return (on: true, fresh: await c.file(s));
          }
          return (on: false, fresh: false);
        }),
        contains('lets a filed chat go without the marker'),
      );
      expect(
        await filing((c, s, e, {required accepted}) async {
          if (e.groupId == null &&
              e.supportMarker != null &&
              !await accepted()) {
            return (on: true, fresh: await c.file(s, reopen: false));
          }
          return (on: await c.has(s), fresh: false);
        }),
        contains('keeps a done chat done when written to'),
      );
    });

    List<String> refusing(bool Function(UnwrappedMessage) refuses) {
      final bad = <String>[];
      UnwrappedMessage env(Map<String, dynamic> j) =>
          unwrapMessage('halo/1:${jsonEncode(j)}');
      if (!refuses(
        env({
          'm': '',
          'g': 'g',
          'gc': {'t': 'create', 'n': 'x'},
        }),
      )) {
        bad.add('takes a group');
      }
      if (!refuses(
        env({
          'm': '',
          'g': 'r',
          'gc': {'t': 'join'},
        }),
      )) {
        bad.add('takes a room join');
      }
      if (!refuses(
        env({
          'm': '',
          'in': {'h': 'a-b-c', 'o': '', 'x': 'x'},
        }),
      )) {
        bad.add('takes an introduction');
      }
      if (refuses(env({'m': 'hi', 'u': 'u1'}))) bad.add('drops a message');
      return bad;
    }

    test('what a support chat never brings in', () {
      expect(refusing(supportRefuses), isEmpty);
      expect(
        refusing((e) => e.groupControl != null),
        contains('takes an introduction'),
      );
      expect(refusing((e) => e.intro != null), contains('takes a group'));
      expect(
        refusing((e) => e.groupControl?.type == 'create' || e.intro != null),
        contains('takes a room join'),
      );
    });

    List<String> capping(
      bool Function({required int have, required bool support}) holds,
    ) {
      final bad = <String>[];
      if (holds(have: 4, support: true)) bad.add('support held before five');
      if (!holds(have: 5, support: true)) bad.add('support past five');
      if (!holds(have: 2, support: false)) bad.add('a stranger past two');
      if (holds(have: 1, support: false)) bad.add('a stranger held at one');
      return bad;
    }

    test('the cap', () {
      bool real({required int have, required bool support}) => strangerCapHolds(
        accepted: false,
        vouched: false,
        have: have,
        cap: support ? kSupportCap : 2,
      );
      expect(capping(real), isEmpty);
      expect(
        capping(
          ({required have, required support}) =>
              strangerCapHolds(accepted: false, vouched: false, have: have),
        ),
        contains('support held before five'),
      );
      expect(
        capping(
          ({required have, required support}) => strangerCapHolds(
            accepted: false,
            vouched: false,
            have: have,
            cap: kSupportCap,
          ),
        ),
        contains('a stranger past two'),
      );
    });

    List<String> ringing(
      bool Function({required int? lastAlert, required int now}) rings,
    ) {
      final bad = <String>[];
      const gap = 30 * 60000;
      const now = 100 * gap;
      if (!rings(lastAlert: null, now: now)) bad.add('the first stays quiet');
      if (rings(lastAlert: now - 1000, now: now)) bad.add('a burst rings');
      if (rings(lastAlert: now - gap + 1, now: now)) {
        bad.add('rings inside the gap');
      }
      if (!rings(lastAlert: now - gap, now: now)) {
        bad.add('quiet after the gap');
      }
      if (!rings(lastAlert: now + gap, now: now)) {
        bad.add('a clock set back goes quiet');
      }
      return bad;
    }

    test('the gap', () {
      expect(
        ringing(
          ({required lastAlert, required now}) =>
              supportRings(lastAlert: lastAlert, now: now),
        ),
        isEmpty,
      );
      expect(
        ringing(({required lastAlert, required now}) => true),
        contains('a burst rings'),
      );
      expect(
        ringing(
          ({required lastAlert, required now}) =>
              lastAlert == null || now - lastAlert > 30 * 60000,
        ),
        contains('quiet after the gap'),
      );
      expect(
        ringing(
          ({required lastAlert, required now}) =>
              lastAlert == null || now - lastAlert >= 30 * 60000,
        ),
        contains('a clock set back goes quiet'),
      );
    });

    test('the ring that takes the gap', () async {
      // a summary that never notes its ring rings for every new chat
      Future<List<String>> burst(
        Future<void> Function(SupportChats, _Bell, String) ring,
      ) async {
        final phone = _Phone();
        final bell = _Bell();
        for (final id in [_s, _t]) {
          await phone.person(id, accepted: 0);
          await phone.mem.update(
            'contacts',
            {'unread': 1},
            where: 'halo_id = ?',
            whereArgs: [id],
          );
          await phone.support.file(id);
          await ring(phone.support, bell, id);
        }
        return bell.summaries;
      }

      expect(
        await burst((c, b, id) => ringSupport(c, b, chat: id, fresh: true)),
        [startsWith('summary ring'), startsWith('summary quiet')],
      );
      expect(
        await burst((c, b, id) async {
          final n = await c.news();
          final alert = supportRings(lastAlert: await c.lastAlert(), now: 1);
          await b.summary(chats: n.chats, messages: n.messages, alert: alert);
        }),
        [startsWith('summary ring'), startsWith('summary ring')],
      );
    });

    List<String> listing(
      List<Map<String, Object?>> Function(
        List<Map<String, Object?>>,
        Set<String>,
      )
      inbox,
    ) {
      final bad = <String>[];
      final ids = [
        for (final r in inbox(
          [
            {'halo_id': _s},
            {'halo_id': _r},
          ],
          {_s, _t},
        ))
          r['halo_id'],
      ];
      if (ids.contains(_s)) bad.add('keeps a support chat');
      if (!ids.contains(_r)) bad.add('drops a request');
      return bad;
    }

    test('the lists', () {
      expect(listing(withoutSupport), isEmpty);
      expect(listing((r, _) => r), contains('keeps a support chat'));
      expect(listing((r, _) => const []), contains('drops a request'));
    });

    test('the summary line', () {
      String words(int chats, int messages) =>
          '${supportSummaryLine(chats, messages)} $_opener';
      bool clean(String Function(int, int) line) =>
          !line(2, 3).contains(_opener) && line(2, 3).contains('2 new chats');
      expect(clean(supportSummaryLine), isTrue);
      expect(clean(words), isFalse);
    });

    // [mode] asked for identities with a key and three words
    List<String> moding(bool Function(String xPub, String words) mode) {
      final bad = <String>[];
      final his = _pubOf(_hisPriv);
      final other = _pubOf(Curve.generateKeyPair().privateKey.serialize());
      if (!mode(his, _me)) bad.add('his own key refused');
      // anyone can grind his three words: they make no developer
      if (mode(other, _words)) bad.add('his words on another key');
      useDevKeysForTest([_key(his, status: DevKeyStatus.retired)]);
      if (mode(his, _me)) bad.add('a retired key');
      useDevKeysForTest([_m1]);
      return bad;
    }

    test('developer mode', () {
      expect(moding((x, _) => devModeOf(x)), isEmpty);
      expect(
        moding((_, w) => devKeys.any((k) => k.threeWords == w)),
        contains('his words on another key'),
      );
      expect(
        moding((x, _) => devKeyByXPub(x) != null),
        contains('a retired key'),
      );
    });

    // [mode] asked of the app in the everyday session and in a decoy
    Future<List<String>> sessioning(bool Function(AppState) mode) async {
      final bad = <String>[];
      final w = await _World.make();
      if (!mode(w.app)) bad.add('off on his phone');
      useDatabasesForTest(w.phone, Session(_Phone(HaloContainer.decoy)));
      if (mode(w.app)) bad.add('on in a decoy');
      return bad;
    }

    test('never in a decoy', () async {
      expect(await sessioning((a) => a.devMode), isEmpty);
      expect(
        await sessioning((a) => devModeOf(a.myXPub)),
        contains('on in a decoy'),
      );
    });
  });
}
