// SPDX-License-Identifier: GPL-3.0-or-later
// a room's maker resets its link: the old one knocks on a door nobody
// listens to, so it lets no one in and a knock on it goes unanswered as one
// on a phone that is off. the new one joins. the members stay, still talk,
// and their link follows. the reset outlives a restart and a restore, and a
// decoy's stays on the phone. only the maker is offered it, and taking
// someone out says the link lets them back unless it is reset. the engine,
// the relays and the databases are stand-ins
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart';
import 'package:kryfo/backup_stream.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart' show scrubDevAnon;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show
        AppState,
        GroupPreview,
        HaloDb,
        HaloEngine,
        appState,
        roomDoorColumns,
        sayRoomJoined,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/rooms.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/screens/group_info_screen.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';
import 'pin_flow_fakes.dart' show app, phone;
import 'real_sqlite.dart';

class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

const _room = 'room00000001';
// the maker's room key, the first door, and its address
final _creator = 'c1' * 32;
final _fc = 'f0' * 32;
// the door a reset makes, and its address
final _door = 'd0' * 32;
final _fc2 = 'f2' * 32;
// a member already in, and two people off the link
final _other = 'b2' * 32;
final _mine = 'a1' * 32;
final _late = 'e3' * 32;

// keys and the addresses their doors give, as the engine derives them
const _pubs = {
  'creatorpriv': 'c1',
  'doorpriv': 'd0',
  'door2priv': 'd2',
  'otherpriv': 'b2',
  'apriv': 'a1',
  'bpriv': 'e3',
};
String _pubOf(String priv) => _pubs[priv]! * 32;
const _fcs = {'creatorpriv': 'f0', 'doorpriv': 'f2', 'door2priv': 'f3'};

// one phone's engine: what it listens to, what it sent and knocked
class _Engine implements HaloEngine {
  final keys = <({String priv, String pub})>[];
  // room key > member key, listened to now
  final listening = <String>{};
  // the doors listened to now, by private key, and every one opened
  final doors = <String>{};
  final dropBoxes = <String>[];
  final unlistened = <String>[];
  final forgot = <String>[];
  final sent = <({String priv, String to, String msg})>[];
  final knocks = <({String priv, String to, String fc, String msg})>[];
  // a shut, or a forget of one key, that never ends: the app killed there
  Completer<void>? shutGate;
  String? forgetHangs;
  final forgetFails = <String>{};

  void _shut(String pub) {
    unlistened.add(pub);
    listening.removeWhere((l) => l.startsWith('$pub>'));
    doors.removeWhere((p) => _pubOf(p) == pub);
  }

  @override
  ({String priv, String pub})? roomKeygen() =>
      keys.isEmpty ? null : keys.removeAt(0);
  @override
  String roomFcPk(String priv) =>
      _fcs[priv] == null ? 'error: no key' : _fcs[priv]! * 32;
  @override
  void roomSubscribeBg(String priv, String peerPub) =>
      listening.add('${_pubOf(priv)}>$peerPub');
  @override
  void roomSubscribeFcBg(String priv) {
    doors.add(priv);
    dropBoxes.add(priv);
  }

  @override
  void roomUnsubscribeBg(String pub) => _shut(pub);
  @override
  void roomUnlistenBg(String priv, String peerPub) =>
      listening.remove('${_pubOf(priv)}>$peerPub');
  @override
  Future<String> roomUnsubscribe(String pub) async {
    await shutGate?.future;
    _shut(pub);
    return 'ok';
  }

  @override
  void roomForgetBg(String priv, List<String> members) => forgot.add(priv);
  @override
  Future<String> roomForget(String priv, List<String> members) async {
    if (priv == forgetHangs) await Completer<void>().future;
    if (forgetFails.contains(priv)) return 'error: busy';
    forgot.add(priv);
    return 'ok';
  }

  @override
  Future<String> roomSend(String priv, String peerPub, String msg) async {
    sent.add((priv: priv, to: peerPub, msg: msg));
    return 'ok';
  }

  @override
  Future<String> roomSendFirstContact(
    String priv,
    String peerPub,
    String fcPk,
    String msg,
  ) async {
    knocks.add((priv: priv, to: peerPub, fc: fcPk, msg: msg));
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Phone {
  _Phone(this.rows, this.engine, this.app);
  final ArrivalRows rows;
  final _Engine engine;
  final AppState app;

  void use() {
    useDatabasesForTest(rows, Session(rows));
    useEngineForTest(engine);
  }

  Map<String, Object?>? get room => rows.groupRows[_room];

  static Future<_Phone> make({
    ArrivalRows? rows,
    List<({String priv, String pub})> keys = const [],
  }) async {
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    final p = _Phone(
      rows ?? ArrivalRows(HaloContainer.everyday),
      _Engine()..keys.addAll(keys),
      AppState(io: ArrivalIo(), router: router)..myId = 'me',
    );
    p.use();
    return p;
  }
}

final _expires = DateTime.now().millisecondsSinceEpoch + 3600000;

// the maker's rows: the room open with [_other] in it
ArrivalRows _makerRows({HaloContainer box = HaloContainer.everyday}) =>
    _asMaker(ArrivalRows(box));

T _asMaker<T extends ArrivalRows>(T rows) => rows
  ..group(_room, [_creator, _other], admin: _creator)
  ..groupRows[_room]!.addAll({
    'name': 'Friday',
    'is_admin': 1,
    'room_priv': 'creatorpriv',
    'room_pub': _creator,
    'expires_at': _expires,
    'creator_pub': _creator,
    'fc_pk': _fc,
    'member_cap': 5,
  });

// the maker's phone, listening as a start leaves it, a door key ready
Future<_Phone> _maker({ArrivalRows? rows}) async {
  final p = await _Phone.make(
    rows: rows ?? _makerRows(),
    keys: [(priv: 'doorpriv', pub: _door)],
  );
  await p.app.subscribeRoomsAtBoot();
  return p;
}

// [_other]'s phone, in the room already
Future<_Phone> _member() => _Phone.make(
  rows: ArrivalRows(HaloContainer.everyday)
    ..group(_room, [_creator, _other], admin: _creator)
    ..groupRows[_room]!.addAll({
      'name': 'Friday',
      'is_admin': 0,
      'room_priv': 'otherpriv',
      'room_pub': _other,
      'expires_at': _expires,
      'creator_pub': _creator,
      'fc_pk': _fc,
      'member_cap': 5,
    }),
);

Future<_Phone> _joiner(String priv) =>
    _Phone.make(keys: [(priv: priv, pub: _pubOf(priv))]);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

// a knock reaching the maker under [tag], and what the maker sent back to
// the key that knocked
Future<List<String>> _takes(
  _Phone maker,
  String tag,
  ({String priv, String to, String fc, String msg}) knock,
) async {
  final who = _pubOf(knock.priv);
  maker.use();
  final before = maker.engine.sent.length;
  await maker.app.receiveRelay([(peer: tag, cipher: knock.msg)]);
  await _settle();
  await maker.app.ctlPassForTest;
  return [
    for (final s in maker.engine.sent.skip(before))
      if (s.to == who) s.msg,
  ];
}

// the relays: a knock lands on the maker's door listening at its address,
// tagged with that door's key. null when no door listens there
Future<List<String>?> _relay(
  _Phone maker,
  ({String priv, String to, String fc, String msg}) knock,
) async {
  for (final d in maker.engine.doors) {
    if (_fcs[d] != null && _fcs[d]! * 32 == knock.fc) {
      return _takes(maker, 'roomfc:${_pubOf(d)}', knock);
    }
  }
  return null;
}

// a frame off [p]'s room lane, from the room key [from]
Future<void> _fromRoom(_Phone p, String from, String frame) async {
  p.use();
  final mine = p.room!['room_pub'] as String;
  await p.app.receiveRelay([(peer: 'room:$mine:$from', cipher: frame)]);
  await _settle();
}

RoomJoin _stateOf(_Phone p) => roomJoinState(
  p.room?['joining_at'] as int?,
  DateTime.now().millisecondsSinceEpoch,
);

GroupControl? _gc(String frame) => unwrapMessage(frame).groupControl;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late List<String> said;
  final wasSay = sayRoomJoined;

  setUpAll(() {
    docs = Directory.systemTemp.createTempSync('room_reset');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    said = [];
    sayRoomJoined = said.add;
  });

  tearDown(() => sayRoomJoined = wasSay);

  test('after a reset the old link lets no one in and the new one '
      'joins', () async {
    final maker = await _maker();
    expect(maker.engine.doors, {'creatorpriv'});
    final old = (await maker.app.roomLinkFor(_room))!;
    expect(old.fcPk, _fc);

    final link = (await maker.app.resetRoomLink(_room))!;
    await _settle();
    // the same room, its end time and its cap; only the door is new
    expect(link.fcPk, _fc2);
    expect(
      (link.roomId, link.name, link.creatorPub, link.expiresAt, link.cap),
      (_room, 'Friday', _creator, _expires, 5),
    );
    expect(RoomLink.parse(link.encode())!.fcPk, _fc2);
    // the old door is shut and its files gone, the new one listens
    expect(maker.engine.doors, {'doorpriv'});
    expect(maker.engine.forgot, ['creatorpriv']);

    // off the old link: no door listens there
    final a = await _joiner('apriv');
    await a.app.joinRoom(old);
    await _settle();
    final knock = a.engine.knocks.single;
    expect(knock.fc, _fc);
    expect(await _relay(maker, knock), isNull);
    // and one already on its way when the reset came is not let in
    expect(await _takes(maker, 'roomfc:$_creator', knock), isEmpty);
    expect(await maker.rows.getGroupMembers(_room), [_creator, _other]);

    // off the new link: let in
    final b = await _joiner('bpriv');
    await b.app.joinRoom(link);
    await _settle();
    final k = b.engine.knocks.single;
    expect(k.fc, _fc2);
    final back = (await _relay(maker, k))!;
    expect(back, hasLength(1));
    expect(_gc(back.single)?.members, [_creator, _other, _late]);
    await _fromRoom(b, _creator, back.single);
    expect(_stateOf(b), RoomJoin.live);
    expect(said, [l10n.appJoined('Friday')]);
  });

  test('the members stay, still talk, and their link follows', () async {
    final maker = await _maker();
    final m = await _member();
    maker.use();
    expect(maker.engine.listening, {'$_creator>$_other'});
    final link = (await maker.app.resetRoomLink(_room))!;
    await _settle();
    await maker.app.ctlPassForTest;
    expect(await maker.rows.getGroupMembers(_room), [_creator, _other]);
    // the first door shared the members' lane: they are listened to again
    expect(maker.engine.unlistened, [_creator]);
    expect(maker.engine.listening, {'$_creator>$_other'});

    // the roster carries the new address to the members
    final roster = [
      for (final s in maker.engine.sent)
        if (s.to == _other && _gc(s.msg)?.type == 'create') s.msg,
    ];
    expect(roster, hasLength(1));
    expect(_gc(roster.single)?.fc, _fc2);
    expect(_gc(roster.single)?.members, [_creator, _other]);
    await _fromRoom(m, _creator, roster.single);
    expect(m.room!['fc_pk'], _fc2);
    expect((await m.app.roomLinkFor(_room))!.encode(), link.encode());
    expect(await m.rows.getGroupMembers(_room), [_creator, _other]);

    // a member's message reaches the maker
    final hi = roomFrame(
      await wrapMessage(
        'still here',
        groupId: _room,
        msgUid: 'hi1',
        sender: SenderInfo(haloId: _other, edPub: '', onion: '', xPub: ''),
      ),
      _other,
    )!;
    await _fromRoom(maker, _other, hi);
    expect(maker.rows.msgs.map((r) => r['plaintext']), ['still here']);
    // and the maker's reaches the member
    maker.use();
    final before = maker.engine.sent.length;
    expect(await maker.app.sendToGroup(_room, 'good'), isTrue);
    final out = maker.engine.sent.skip(before).single;
    expect(out.to, _other);
    await _fromRoom(m, _creator, out.msg);
    expect(m.rows.msgs.map((r) => r['plaintext']), ['good']);
  });

  test('a roster from anyone but the maker moves no link', () async {
    final m = await _member();
    Future<String> rosterFrom(String key, String fc) async => roomFrame(
      await wrapMessage(
        '',
        groupId: _room,
        groupControl: GroupControl(
          type: 'create',
          name: 'Friday',
          members: [_creator, _other],
          stamp: 9,
          fc: fc,
        ),
        sender: SenderInfo(haloId: key, edPub: '', onion: '', xPub: ''),
      ),
      key,
    )!;
    await m.rows.addGroupMember(_room, _mine);
    await _fromRoom(m, _mine, await rosterFrom(_mine, _fc2));
    expect(m.room!['fc_pk'], _fc);
    await _fromRoom(m, _creator, await rosterFrom(_creator, 'not an address'));
    expect(m.room!['fc_pk'], _fc);
  });

  test('a reset outlives a restart', () async {
    final maker = await _maker();
    await maker.app.resetRoomLink(_room);
    await _settle();
    // the app again, over the same rows
    final again = await _Phone.make(rows: maker.rows);
    await again.app.subscribeRoomsAtBoot();
    expect(again.engine.dropBoxes, ['doorpriv']);
    expect((await again.app.roomLinkFor(_room))!.fcPk, _fc2);
    final a = await _joiner('apriv');
    await a.app.joinRoom(
      RoomLink(
        roomId: _room,
        name: 'Friday',
        expiresAt: _expires,
        creatorPub: _creator,
        fcPk: _fc,
        cap: 5,
      ),
    );
    await _settle();
    expect(await _relay(again, a.engine.knocks.single), isNull);
    expect(
      await _takes(again, 'roomfc:$_creator', a.engine.knocks.single),
      isEmpty,
    );
    again.use();
    final link = (await again.app.roomLinkFor(_room))!;
    final b = await _joiner('bpriv');
    await b.app.joinRoom(link);
    await _settle();
    expect(await _relay(again, b.engine.knocks.single), hasLength(1));
    expect(await again.rows.getGroupMembers(_room), [_creator, _other, _late]);
  });

  test('a reset outlives a backup and its restore: the file carries the '
      'new door and the roster owed, and the phone it lands on listens '
      'there and sends it', () async {
    final mem = MemDb();
    final db = _Rows(mem);
    await db.createRoom(
      groupId: _room,
      name: 'Friday',
      priv: 'creatorpriv',
      pub: _creator,
      expiresAt: _expires,
      creatorPub: _creator,
      fcPk: _fc,
      cap: 5,
      members: [_creator, _other],
    );
    // before a reset, the room's own key is its door
    expect((await db.roomByDoor(_creator))?['group_id'], _room);
    expect(
      await db.resetRoomDoor(
        _room,
        priv: 'doorpriv',
        pub: _door,
        fcPk: _fc2,
        roster: true,
        now: 1,
      ),
      isTrue,
    );

    // the phone's files, and the backup made of them as the app makes one
    final stage = Directory('${docs.path}/stage')..createSync();
    final other = Directory('${docs.path}/phone2')..createSync();
    addTearDown(() {
      for (final d in [stage, other]) {
        d.deleteSync(recursive: true);
      }
      for (final f in ['halo.db', 'onion.key']) {
        File('${docs.path}/$f').deleteSync();
      }
    });
    File('${docs.path}/halo.db').writeAsStringSync(mem.dump());
    File('${docs.path}/onion.key').writeAsBytesSync([1, 2, 3, 4]);
    FlutterSecureStorage.setMockInitialValues({'halo.db.passphrase': 'pw'});
    final draft = await draftBackup(stage.path, side: _Side(docs.path));
    final out = '${stage.path}/x.kryfo';
    await writeBackup(
      outPath: out,
      salt: Uint8List(16),
      cipher: _Cipher(),
      manifest: draft.manifest,
      root: '',
      source: (n) => draft.sources[n]!,
    );
    await unpackBackup(out, _Cipher(), root: other.path);

    final back = _Rows(
      MemDb.load(File('${other.path}/halo.db').readAsStringSync()),
    );
    expect((await back.roomByDoor(_door))?['group_id'], _room);
    expect(await back.roomByDoor(_creator), isNull);
    // members' frames still find it by its own key
    expect((await back.roomByPub(_creator))?['group_id'], _room);
    final g = (await back.getGroup(_room))!;
    expect(
      (g['door_priv'], g['fc_pk'], g['expires_at'], g['member_cap']),
      ('doorpriv', _fc2, _expires, 5),
    );
    expect(await back.getGroupMembers(_room), [_creator, _other]);

    // the phone it lands on: those rows, started
    final rows = ArrivalRows(HaloContainer.everyday)
      ..group(_room, await back.getGroupMembers(_room), admin: _creator)
      ..groupRows[_room]!.addAll(g);
    rows.ctlOut.addAll(back.mem.rows('group_ctl_out'));
    final restored = await _Phone.make(rows: rows);
    await restored.app.subscribeRoomsAtBoot();
    expect(restored.engine.dropBoxes, ['doorpriv']);
    expect((await restored.app.roomLinkFor(_room))!.fcPk, _fc2);
    await restored.app.owedDueForTest(_other);
    await restored.app.ctlPassForTest;
    final sent = [
      for (final s in restored.engine.sent)
        if (s.to == _other) _gc(s.msg),
    ];
    expect(sent.single?.fc, _fc2);
    expect(sent.single?.members, [_creator, _other]);
  });

  final sql = RealSqlite.open();
  test('a phone from 67 gets the door columns and keeps its rooms on their '
      'first door', () async {
    final db = sql!;
    final src = File('lib/main.dart').readAsStringSync();
    final made = src.substring(
      src.indexOf('onCreate: (db, _) async {'),
      src.indexOf('onUpgrade: (db, oldV, newV) async {'),
    );
    final table = RegExp(
      r"'''\s*(CREATE TABLE groups \(.*?\))\s*'''",
      dotAll: true,
    ).firstMatch(made)!.group(1)!;
    expect(table, contains('door_priv TEXT'));
    expect(table, contains('door_pub TEXT'));
    final v67 = table.replaceFirst(
      RegExp(r',\s*door_priv TEXT,\s*door_pub TEXT,\s*door_was TEXT'),
      '',
    );
    expect(v67, isNot(contains('door_')));
    db.run(v67);
    db.run(
      "INSERT INTO groups (group_id, name, created_at, is_admin, "
      "room_priv, room_pub, fc_pk) VALUES ('$_room', 'Friday', 1, 1, "
      "'creatorpriv', '$_creator', '$_fc')",
    );
    await roomDoorColumns(RealExecutor(db));
    // a second run finds them there
    await roomDoorColumns(RealExecutor(db));
    final cols = db.run('PRAGMA table_info(groups)').map((c) => c['name']);
    expect(cols.where((c) => c == 'door_priv'), hasLength(1));
    expect(cols.where((c) => c == 'door_pub'), hasLength(1));
    expect(cols.where((c) => c == 'door_was'), hasLength(1));
    final row = db.run('SELECT * FROM groups').single;
    expect(row['room_pub'], _creator);
    expect(row['fc_pk'], _fc);
    // never reset: its link knocks on the room's own key
    expect(row['door_priv'], isNull);
    expect(row['door_pub'], isNull);
    expect(row['door_was'], isNull);
    // after every older step
    final version = RegExp(r'version: (\d+),').firstMatch(src)!.group(1)!;
    expect(int.parse(version), greaterThanOrEqualTo(68));
    final upgrade = src.indexOf('onUpgrade: (db, oldV, newV) async {');
    final steps = src.substring(upgrade, src.indexOf('\n    );', upgrade));
    expect(
      RegExp(
        r'if \(oldV < 68\) \{[^}]*await roomDoorColumns\(db\);',
      ).hasMatch(steps),
      isTrue,
    );
    final at68 = steps.indexOf('if (oldV < 68) {');
    for (final m in RegExp(r'if \(oldV < (\d+)\) \{').allMatches(steps)) {
      if (int.parse(m.group(1)!) < 68) expect(m.start, lessThan(at68));
    }
  }, skip: sql == null ? 'no sqlite library here' : null);

  test('a joiner waiting on the old link hears nothing, as from a phone '
      'that is off, and the new link lets it in', () async {
    final maker = await _maker();
    final old = (await maker.app.roomLinkFor(_room))!;
    final a = await _joiner('apriv');
    await a.app.joinRoom(old);
    await _settle();
    final first = a.engine.knocks.single;
    // the reset lands while the knock is on its way
    maker.use();
    final link = (await maker.app.resetRoomLink(_room))!;
    await _settle();
    expect(await _relay(maker, first), isNull);
    expect(await _takes(maker, 'roomfc:$_creator', first), isEmpty);
    // nothing at all went to the key that knocked: no roster, no full
    expect(maker.engine.sent.where((s) => s.to == _mine), isEmpty);

    // the wait runs out as any unanswered one does
    a.use();
    expect(_stateOf(a), RoomJoin.waiting);
    final wait = kRoomJoinWait.inMilliseconds;
    a.room!['joining_at'] = DateTime.now().millisecondsSinceEpoch - wait - 1;
    expect(_stateOf(a), RoomJoin.silent);
    expect(a.app.roomFull(_room), isFalse);
    // try again knocks on the old door again, unanswered again
    await a.app.retryRoomJoin(_room);
    await _settle();
    expect(a.engine.knocks.last.fc, _fc);
    expect(await _relay(maker, a.engine.knocks.last), isNull);
    expect(said, isEmpty);

    // the new link, while still waiting, knocks on the new door
    a.use();
    expect(await a.app.joinRoom(link), '');
    await _settle();
    expect(a.engine.knocks.last.fc, _fc2);
    expect(a.room!['fc_pk'], _fc2);
    final back = (await _relay(maker, a.engine.knocks.last))!;
    await _fromRoom(a, _creator, back.single);
    expect(_stateOf(a), RoomJoin.live);
    expect(said, [l10n.appJoined('Friday')]);
  });

  test('only the maker can reset, and a decoy\'s reset stays on the '
      'phone', () async {
    // a member
    final m = await _member();
    m.engine.keys.add((priv: 'doorpriv', pub: _door));
    expect(await m.app.resetRoomLink(_room), isNull);
    expect(m.room!['fc_pk'], _fc);
    expect(m.room!['door_pub'], isNull);
    expect(m.engine.keys, hasLength(1));

    // the decoy: a new link, and nothing listened to or sent
    final decoy = await _Phone.make(
      rows: _makerRows(box: HaloContainer.decoy),
      keys: [(priv: 'doorpriv', pub: _door)],
    );
    final link = (await decoy.app.resetRoomLink(_room))!;
    await _settle();
    expect(link.fcPk, _fc2);
    expect(decoy.room!['door_pub'], _door);
    expect(decoy.engine.dropBoxes, isEmpty);
    expect(decoy.engine.unlistened, isEmpty);
    expect(decoy.engine.forgot, isEmpty);
    expect(decoy.engine.listening, isEmpty);
    expect(decoy.engine.sent, isEmpty);
    expect(decoy.rows.ctlOut, isEmpty);
  });

  test('a room that ended takes its door with it', () async {
    final maker = await _maker();
    await maker.app.resetRoomLink(_room);
    await _settle();
    maker.room!['expires_at'] = DateTime.now().millisecondsSinceEpoch - 1;
    await maker.app.sweepRooms();
    expect(maker.rows.groupRows, isEmpty);
    expect(maker.engine.doors, isEmpty);
    expect(maker.engine.unlistened, containsAll([_creator, _door]));
    expect(maker.engine.forgot, containsAll(['creatorpriv', 'doorpriv']));
  });

  group('a knock being let in when the reset comes', () {
    // the knock of [_late] off the first door, under way on the maker's
    // phone and held where it reads who left
    Future<(_Phone, _Gated, Future<void>)> held() async {
      final rows = _asMaker(_Gated());
      final maker = await _maker(rows: rows);
      final link = (await _linkOf(maker))!;
      final b = await _joiner('bpriv');
      await b.app.joinRoom(link);
      await _settle();
      maker.use();
      final gate = rows.gate = Completer<void>();
      final taking = maker.app.receiveRelay([
        (peer: 'roomfc:$_creator', cipher: b.engine.knocks.single.msg),
      ]);
      await _settle();
      expect(gate.isCompleted, isFalse);
      return (maker, rows, taking);
    }

    List<GroupControl> rostersTo(_Phone p, String who) => [
      for (final s in p.engine.sent)
        if (s.to == who && _gc(s.msg)?.type == 'create') _gc(s.msg)!,
    ];

    test('the reset waits its turn: the knock is let in first, and the '
        'roster after carries the new link to everyone', () async {
      final (maker, rows, taking) = await held();
      final resetting = maker.app.resetRoomLink(_room);
      await _settle();
      // nothing of the reset happened while the knock is under way
      expect(maker.room!['door_pub'], isNull);
      expect(maker.engine.doors, {'creatorpriv'});
      rows.gate!.complete();
      await taking;
      expect((await resetting)!.fcPk, _fc2);
      await _settle();
      await maker.app.ctlPassForTest;
      expect(await maker.rows.getGroupMembers(_room), [
        _creator,
        _other,
        _late,
      ]);
      for (final who in [_other, _late]) {
        final rs = rostersTo(maker, who)
          ..sort((a, b) => a.stamp!.compareTo(b.stamp!));
        expect(rs.last.fc, _fc2, reason: who);
        expect(rs.last.members, [_creator, _other, _late], reason: who);
      }
    });

    test('a door shut under it lets it in no more', () async {
      final (maker, rows, taking) = await held();
      // the door changes while it reads, by whatever way
      rows.groupRows[_room]!['door_pub'] = _door;
      rows.gate!.complete();
      await taking;
      await _settle();
      await maker.app.ctlPassForTest;
      expect(await maker.rows.getGroupMembers(_room), [_creator, _other]);
      expect(maker.engine.sent.where((s) => s.to == _late), isEmpty);
      expect(maker.rows.ctlOut, isEmpty);
    });

    test('its roster carries the link as it is when it goes', () async {
      final (maker, rows, taking) = await held();
      // a new row, as a write and a read again give: the one read stays
      rows.groupRows[_room] = {...rows.groupRows[_room]!, 'fc_pk': _fc2};
      rows.gate!.complete();
      await taking;
      await _settle();
      await maker.app.ctlPassForTest;
      expect(rostersTo(maker, _late).single.fc, _fc2);
      expect(rostersTo(maker, _other).single.fc, _fc2);
    });
  });

  test('two asks at once are one reset, and both get its link', () async {
    final maker = await _maker();
    maker.engine.keys.add((priv: 'door2priv', pub: _pubOf('door2priv')));
    final both = await Future.wait([
      maker.app.resetRoomLink(_room),
      maker.app.resetRoomLink(_room),
    ]);
    expect(both.map((l) => l?.fcPk), [_fc2, _fc2]);
    expect(maker.engine.keys, hasLength(1));
  });

  test('a room the sweep takes while it is reset is left alone', () async {
    final rows = _asMaker(_Swept());
    final maker = await _maker(rows: rows);
    final before = {...maker.engine.listening};
    rows.sweepOnRead = true;
    expect(await maker.app.resetRoomLink(_room), isNull);
    await _settle();
    expect(rows.groupRows, isEmpty);
    expect(maker.engine.doors, {'creatorpriv'});
    expect(maker.engine.listening, before);
    expect(maker.engine.unlistened, isEmpty);
    expect(maker.engine.dropBoxes, ['creatorpriv']);
    expect(maker.rows.ctlOut, isEmpty);

    // on disk too: nothing changes and nothing is queued
    final mem = MemDb();
    expect(
      await _Rows(mem).resetRoomDoor(
        _room,
        priv: 'doorpriv',
        pub: _door,
        fcPk: _fc2,
        roster: true,
        now: 1,
      ),
      isFalse,
    );
    expect(mem.rows('group_ctl_out'), isEmpty);
  });

  test('killed mid-reset: the roster with the new link was queued with it, '
      'and the next start forgets the old door', () async {
    final maker = await _maker();
    // the app dies while the old door shuts
    maker.engine.shutGate = Completer<void>();
    unawaited(maker.app.resetRoomLink(_room));
    await _settle();
    expect(maker.room!['door_pub'], _door);
    expect(maker.room!['door_was'], 'creatorpriv');
    expect(maker.engine.sent, isEmpty);
    expect(maker.engine.forgot, isEmpty);

    final again = await _Phone.make(rows: maker.rows);
    await again.app.subscribeRoomsAtBoot();
    expect(again.engine.dropBoxes, ['doorpriv']);
    expect(again.engine.forgot, ['creatorpriv']);
    expect(again.room!['door_was'], isNull);
    await again.app.owedDueForTest(_other);
    await again.app.ctlPassForTest;
    final roster = [
      for (final s in again.engine.sent)
        if (s.to == _other) _gc(s.msg),
    ];
    expect(roster.single?.fc, _fc2);
  });

  test('killed before a later reset forgets the door it replaced: the next '
      'start does', () async {
    final maker = await _maker();
    maker.engine.keys.add((priv: 'door2priv', pub: _pubOf('door2priv')));
    await maker.app.resetRoomLink(_room);
    await _settle();
    expect(maker.room!['door_was'], isNull);
    maker.engine.forgetHangs = 'doorpriv';
    unawaited(maker.app.resetRoomLink(_room));
    await _settle();
    expect(maker.room!['door_priv'], 'door2priv');
    expect(maker.room!['door_was'], 'doorpriv');
    expect(maker.engine.forgot, ['creatorpriv']);

    final again = await _Phone.make(rows: maker.rows);
    await again.app.subscribeRoomsAtBoot();
    expect(again.engine.dropBoxes, ['door2priv']);
    expect(again.engine.forgot, ['doorpriv']);
    expect(again.room!['door_was'], isNull);
  });

  test('a door a reset could not forget is forgotten by the next', () async {
    final maker = await _maker();
    maker.engine.keys.add((priv: 'door2priv', pub: _pubOf('door2priv')));
    maker.engine.forgetFails.add('creatorpriv');
    await maker.app.resetRoomLink(_room);
    expect(maker.room!['door_was'], 'creatorpriv');
    expect(maker.engine.forgot, isEmpty);
    maker.engine.forgetFails.clear();
    await maker.app.resetRoomLink(_room);
    expect(maker.engine.forgot, ['creatorpriv', 'doorpriv']);
    expect(maker.room!['door_was'], isNull);
  });

  test('a knock behind a stuck reset holds nothing else in the inbox, and '
      'is taken once the reset is done', () async {
    final maker = await _maker();
    final old = (await _linkOf(maker))!;
    final b = await _joiner('bpriv');
    await b.app.joinRoom(old);
    await _settle();
    final knock = b.engine.knocks.single;
    maker.use();
    final gate = maker.engine.shutGate = Completer<void>();
    final resetting = maker.app.resetRoomLink(_room);
    await _settle();
    final hi = roomFrame(
      await wrapMessage(
        'still here',
        groupId: _room,
        msgUid: 'hi1',
        sender: SenderInfo(haloId: _other, edPub: '', onion: '', xPub: ''),
      ),
      _other,
    )!;
    final failed = await maker.app
        .receiveRelay([
          (peer: 'roomfc:$_creator', cipher: knock.msg),
          (peer: 'room:$_creator:$_other', cipher: hi),
        ])
        .timeout(const Duration(seconds: 2));
    // the knock is offered again; the message behind it is in
    expect(failed, {0});
    expect(maker.rows.msgs.map((r) => r['plaintext']), ['still here']);
    gate.complete();
    await resetting;
    await _settle();
    // it came to the door the reset shut, and is seen
    expect(await maker.rows.getGroupMembers(_room), [_creator, _other]);
    expect(
      await maker.app.receiveRelay([
        (peer: 'roomfc:$_creator', cipher: knock.msg),
      ]),
      isEmpty,
    );
  });

  test('a reset whose engine never answers goes on after its wait', () async {
    final maker = await _maker();
    maker.app.roomEngineWait = const Duration(milliseconds: 200);
    maker.engine.shutGate = Completer<void>();
    maker.engine.forgetHangs = 'creatorpriv';
    final link = await maker.app
        .resetRoomLink(_room)
        .timeout(const Duration(seconds: 3));
    expect(link!.fcPk, _fc2);
    expect(maker.engine.doors, contains('doorpriv'));
    // its files are still owed: noted for the next start
    expect(maker.room!['door_was'], 'creatorpriv');
  });

  test('a reset stops when the door before cannot be forgotten, and can '
      'be tried again', () async {
    final maker = await _maker();
    // a door a reset cut short left
    maker.room!['door_was'] = 'oldpriv';
    maker.engine.forgetFails.add('oldpriv');
    expect(await maker.app.resetRoomLink(_room), isNull);
    expect(maker.room!['door_was'], 'oldpriv');
    expect(maker.room!['door_pub'], isNull);
    expect(maker.room!['fc_pk'], _fc);
    expect(maker.engine.keys, hasLength(1));
    expect(maker.engine.doors, {'creatorpriv'});
    expect(maker.engine.unlistened, isEmpty);
    expect(maker.rows.ctlOut, isEmpty);
    maker.engine.forgetFails.clear();
    expect((await maker.app.resetRoomLink(_room))!.fcPk, _fc2);
    expect(maker.engine.forgot, ['oldpriv', 'creatorpriv']);
    expect(maker.room!['door_was'], isNull);
  });

  test('listening again while a reset runs takes the door it leaves', () async {
    final rows = _asMaker(_Gated());
    final p = await _Phone.make(
      rows: rows,
      keys: [(priv: 'doorpriv', pub: _door)],
    );
    final hold = rows.roomsGate = Completer<void>();
    final listening = p.app.subscribeRoomsAtBoot();
    await _settle();
    // the rooms are read as they were; the reset lands before they listen
    expect((await p.app.resetRoomLink(_room))!.fcPk, _fc2);
    hold.complete();
    await listening;
    await _settle();
    expect(p.engine.doors, {'doorpriv'});
  });

  test('a room that ends while it is reset leaves nothing listening', () async {
    final maker = await _maker();
    final gate = maker.engine.shutGate = Completer<void>();
    final resetting = maker.app.resetRoomLink(_room);
    await _settle();
    maker.room!['expires_at'] = DateTime.now().millisecondsSinceEpoch - 1;
    final sweeping = maker.app.sweepRooms();
    await _settle();
    gate.complete();
    await resetting;
    await sweeping;
    await _settle();
    expect(maker.rows.groupRows, isEmpty);
    expect(maker.engine.doors, isEmpty);
    expect(maker.engine.listening, isEmpty);
  });

  group('on screen', () {
    // the room's rows as the info page reads them
    ArrivalRows screenRows({bool maker = true, bool room = true}) {
      final r = _ScreenRows()
        ..group(_room, [_creator, _other], admin: maker ? _creator : _other);
      r.groupRows[_room]!.addAll({
        'name': 'Friday',
        'is_admin': maker ? 1 : 0,
        if (room) ...{
          'room_priv': 'creatorpriv',
          'room_pub': maker ? _creator : _other,
          'expires_at': _expires,
          'creator_pub': _creator,
          'fc_pk': _fc,
          'member_cap': 5,
        },
      });
      return r;
    }

    Future<_Engine> open(
      WidgetTester t,
      ArrivalRows rows, {
      bool maker = true,
      bool room = true,
    }) async {
      phone(t);
      final engine = _Engine()..keys.add((priv: 'doorpriv', pub: _door));
      useDatabasesForTest(rows, Session(rows));
      useEngineForTest(engine);
      lockState.openForTest();
      appState.groups = [
        GroupPreview(
          groupId: _room,
          name: 'Friday',
          memberCount: 2,
          isAdmin: maker,
          createdAt: DateTime(2026),
          expiresAt: room ? _expires : null,
        ),
      ];
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(() {
        m.setMockMethodCallHandler(SystemChannels.platform, null);
        appState.groups = [];
      });
      await t.pumpWidget(app(const GroupInfoScreen(groupId: _room)));
      await t.pump(const Duration(seconds: 1));
      return engine;
    }

    Future<void> close(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
    }

    testWidgets('only the maker sees Reset link', (t) async {
      await open(t, screenRows());
      expect(find.text(l10n.groupInfoResetLink), findsOneWidget);
      await close(t);

      await open(t, screenRows(maker: false), maker: false);
      expect(find.text(l10n.groupInfoInvite), findsOneWidget);
      expect(find.text(l10n.groupInfoResetLink), findsNothing);
      await close(t);

      // a plain group's admin has no link to reset
      await open(t, screenRows(room: false), room: false);
      expect(find.text(l10n.groupInfoResetLink), findsNothing);
      await close(t);
    });

    testWidgets('Reset link asks first, then hands over the new link', (
      t,
    ) async {
      final rows = screenRows();
      await open(t, rows);
      final reset = find.text(l10n.groupInfoResetLink);
      await t.ensureVisible(reset);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(reset);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.groupInfoResetTheRoomLink), findsOneWidget);
      expect(find.text(l10n.groupInfoResetLinkLine), findsOneWidget);
      // kept: nothing changes
      await t.tap(find.text(l10n.confirmSheetKeep));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.groupInfoResetTheRoomLink), findsNothing);
      expect(rows.groupRows[_room]!['fc_pk'], _fc);

      await t.tap(reset);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text(l10n.groupInfoResetLink).last);
      await t.runAsync(_settle);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(rows.groupRows[_room]!['fc_pk'], _fc2);
      expect(find.text(l10n.roomLinkNewLinkTheOld), findsOneWidget);
      expect(find.text(l10n.roomLinkCopyRoomLink), findsOneWidget);
      await close(t);
    });

    testWidgets('a reset under way shows on its row, a second tap waits '
        'for it, and no failure is said', (t) async {
      final rows = screenRows();
      final engine = await open(t, rows);
      final gate = engine.shutGate = Completer<void>();
      final reset = find.text(l10n.groupInfoResetLink);
      await t.ensureVisible(reset);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      await t.tap(reset);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text(l10n.groupInfoResetLink).last);
      await t.runAsync(_settle);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('resetting')), findsOneWidget);
      // a second tap asks nothing and says nothing while it runs
      await t.tap(reset);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.groupInfoResetTheRoomLink), findsNothing);
      expect(find.text(l10n.groupInfoCouldNotResetLink), findsNothing);
      gate.complete();
      await t.runAsync(_settle);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.groupInfoCouldNotResetLink), findsNothing);
      expect(find.text(l10n.roomLinkNewLinkTheOld), findsOneWidget);
      expect(find.byKey(const ValueKey('resetting')), findsNothing);
      expect(engine.keys, isEmpty);
      await close(t);
    });

    testWidgets('remove in a room says the link lets them back unless it '
        'is reset, and can reset it too', (t) async {
      final rows = screenRows();
      final engine = await open(t, rows);
      final remove = find.byTooltip(l10n.groupInfoRemoveFromGroup);
      await t.ensureVisible(remove);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(remove);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(
        find.text(
          'They can join again with the room link. Reset the link to keep '
          'them out. People still in the room get the new one.',
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.groupInfoTheyWillStopReceiving), findsNothing);
      expect(find.text(l10n.commonRemove), findsOneWidget);
      expect(find.text(l10n.groupInfoRemoveAndResetLink), findsOneWidget);

      await t.tap(find.text(l10n.groupInfoRemoveAndResetLink));
      await t.runAsync(_settle);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      // out first, then the new door: the roster with it skips them
      expect(rows.members[_room], [_creator]);
      expect(await rows.rosterGone(_room), {_other});
      expect(rows.groupRows[_room]!['door_pub'], _door);
      expect(engine.doors, {'doorpriv'});
      final rosters = [
        for (final r in rows.ctlOut)
          if (r['member'] == _other) r['ctl'] as String,
      ];
      expect(rosters.where((c) => c.contains(_fc2)), isEmpty);
      expect(find.text(l10n.roomLinkNewLinkTheOld), findsOneWidget);
      await close(t);
    });

    testWidgets('remove in a plain group keeps its own words', (t) async {
      final rows = screenRows(room: false)
        ..person(_other, onion: 'o', xpub: 'x');
      await open(t, rows, room: false);
      final remove = find.byTooltip(l10n.groupInfoRemoveFromGroup).last;
      await t.ensureVisible(remove);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(remove);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.groupInfoTheyWillStopReceiving), findsOneWidget);
      expect(find.text(l10n.groupInfoRemoveRoomLine), findsNothing);
      expect(find.text(l10n.groupInfoRemoveAndResetLink), findsNothing);
      await t.tap(find.text(l10n.confirmSheetKeep));
      await t.pump(const Duration(seconds: 1));
      await close(t);
    });
  });
}

// what the info page reads besides the rows the arrival tests keep
class _ScreenRows extends ArrivalRows {
  _ScreenRows() : super(HaloContainer.everyday);
  @override
  Future<List<Map<String, Object?>>> loadGroupMessages(String groupId) async =>
      [];
  @override
  Future<String?> getGroupAtmosphere(String groupId) async => null;
}

// rows that hold a knock where it reads who left, until [gate] opens
class _Gated extends ArrivalRows {
  _Gated() : super(HaloContainer.everyday);
  Completer<void>? gate;
  // holds the list of rooms once read, as it was then
  Completer<void>? roomsGate;
  @override
  Future<List<Map<String, Object?>>> rooms() async {
    final read = [
      for (final g in await super.rooms()) {...g},
    ];
    await roomsGate?.future;
    return read;
  }

  @override
  Future<Set<String>> rosterGone(String groupId) async {
    await gate?.future;
    return super.rosterGone(groupId);
  }
}

// rows whose room the expiry sweep takes right after it is read
class _Swept extends ArrivalRows {
  _Swept() : super(HaloContainer.everyday);
  bool sweepOnRead = false;
  @override
  Future<Map<String, Object?>?> getGroup(String groupId) async {
    final g = await super.getGroup(groupId);
    if (!sweepOnRead || g == null) return g;
    sweepOnRead = false;
    final read = {...g};
    groupRows.remove(groupId);
    return read;
  }
}

Future<RoomLink?> _linkOf(_Phone p) {
  p.use();
  return p.app.roomLinkFor(_room);
}

// the backup's view of the phone: its identity, and its database copied
// and scrubbed as a file of json, with the app's own scrubs
class _Side extends BackupSide {
  const _Side(this.docs);
  final String docs;

  // the stand-in files are no databases: nothing to rebuild
  @override
  Future<void> compact(String copy, String key) async {}

  @override
  ({String ed, String x, String id}) identity() =>
      (ed: 'everyday-ed', x: 'everyday-x', id: 'me-me-me');

  @override
  Future<void> copyEveryday(String to) => File('$docs/halo.db').copy(to);

  Future<MemDb> _open(String copy) async =>
      MemDb.load(await File(copy).readAsString());

  @override
  Future<Set<String>> scrub(String copy, String key) async {
    final db = await _open(copy);
    final people = await scrubHidden(db);
    await File(copy).writeAsString(db.dump());
    return people;
  }

  @override
  Future<void> scrubDev(String copy, String key) async {
    final db = await _open(copy);
    await db.transaction(scrubDevAnon);
    await File(copy).writeAsString(db.dump());
  }

  @override
  Future<void> settleBurns(String copy, String key, int at) async {
    final db = await _open(copy);
    await db.transaction((t) => settleWaitingBurns(t, at));
    await File(copy).writeAsString(db.dump());
  }
}

// the engine's cipher bound to each record's place
class _Cipher implements ChunkCipher {
  @override
  Uint8List seal(int index, int type, Uint8List plain) =>
      Uint8List.fromList([index & 255, type, ...plain.map((b) => b ^ 7)]);
  @override
  Uint8List? open(int index, int type, Uint8List sealed) {
    if (sealed.length < 2 || sealed[0] != (index & 255) || sealed[1] != type) {
      return null;
    }
    return Uint8List.fromList(sealed.sublist(2).map((b) => b ^ 7).toList());
  }
}
