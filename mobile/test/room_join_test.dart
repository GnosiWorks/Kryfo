// SPDX-License-Identifier: GPL-3.0-or-later
// a room joined off a link waits until its creator's roster names this
// phone's key: no "joined" before that, and after kRoomJoinWait it is not
// answering. trying again sends the join as the first time did, leaving
// takes everything, and the wait outlives a restart. the creator runs here
// too, on its own stand-ins, so the roster that lets the joiner in is the
// one a creator really sends. the engine and the databases are stand-ins
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloDb,
        HaloEngine,
        roomJoiningColumn,
        sayRoomJoined,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/rooms.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'arrival_fakes.dart';
import 'mem_db.dart';
import 'real_sqlite.dart';

// the app's own database code over rows in maps, its tables as main.dart
// makes them
class _Rows extends HaloDb {
  _Rows(this.mem);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
}

const _room = 'room00000001';
final _creator = 'c1' * 32;
final _fc = 'f0' * 32;
final _mine = 'a1' * 32;
final _other = 'b2' * 32;

// what one phone's engine was asked to do for its rooms
class _Engine implements HaloEngine {
  final keys = <({String priv, String pub})>[];
  final listens = <String>[];
  final dropBoxes = <String>[];
  final unlistened = <String>[];
  final forgot = <String>[];
  final sent = <({String priv, String to, String msg})>[];
  final knocks = <({String priv, String to, String fc, String msg})>[];
  // the relays: what they answer a knock, and a hold on it or on a frame
  String answer = 'ok';
  Completer<void>? knockGate;
  Completer<void>? sendGate;

  @override
  ({String priv, String pub})? roomKeygen() =>
      keys.isEmpty ? null : keys.removeAt(0);
  @override
  void roomSubscribeBg(String priv, String peerPub) => listens.add(peerPub);
  @override
  void roomSubscribeFcBg(String priv) => dropBoxes.add(priv);
  @override
  void roomUnsubscribeBg(String pub) => unlistened.add(pub);
  @override
  void roomForgetBg(String priv, List<String> members) => forgot.add(priv);
  @override
  Future<String> roomSend(String priv, String peerPub, String msg) async {
    await sendGate?.future;
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
    await knockGate?.future;
    knocks.add((priv: priv, to: peerPub, fc: fcPk, msg: msg));
    return answer;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// rows where a let-in lands right after the room is read, and where the
// next number can be held
class _Racing extends ArrivalRows {
  _Racing() : super(HaloContainer.everyday);
  bool letInAfterRead = false;
  Completer<void>? seqGate;

  @override
  Future<Map<String, Object?>?> getGroup(String groupId) async {
    final g = await super.getGroup(groupId);
    if (!letInAfterRead || g == null) return g;
    letInAfterRead = false;
    final read = {...g};
    groupRows[groupId]!['joining_at'] = null;
    return read;
  }

  @override
  Future<int> nextRoomSeq(String groupId) async {
    // the next number only, the join's
    final g = seqGate;
    seqGate = null;
    await g?.future;
    return super.nextRoomSeq(groupId);
  }
}

// one phone: its database, its engine and its app. [use] puts it on
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

  static Future<_Phone> make({ArrivalRows? rows}) async {
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    final p = _Phone(
      rows ?? ArrivalRows(HaloContainer.everyday),
      _Engine()..keys.add((priv: 'mypriv', pub: _mine)),
      AppState(io: ArrivalIo(), router: router)..myId = 'me',
    );
    p.use();
    return p;
  }
}

// the creator's phone, its room open with [others] in it already
Future<_Phone> _creatorPhone({int cap = 5, List<String> others = const []}) =>
    _Phone.make(
      rows: ArrivalRows(HaloContainer.everyday)
        ..group(_room, [_creator, ...others], admin: _creator)
        ..groupRows[_room]!.addAll({
          'name': 'Friday',
          'is_admin': 1,
          'room_priv': 'creatorpriv',
          'room_pub': _creator,
          'expires_at': DateTime.now().millisecondsSinceEpoch + 3600000,
          'creator_pub': _creator,
          'fc_pk': _fc,
          'member_cap': cap,
        }),
    );

RoomLink _link({int inMs = 3600000}) => RoomLink(
  roomId: _room,
  name: 'Friday',
  expiresAt: DateTime.now().millisecondsSinceEpoch + inMs,
  creatorPub: _creator,
  fcPk: _fc,
  cap: 5,
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

// a frame off this phone's room lane, from the room key [from]
Future<void> _fromRoom(_Phone p, String from, String frame) async {
  p.use();
  await p.app.receiveRelay([(peer: 'room:$_mine:$from', cipher: frame)]);
  await _settle();
}

// a roster as the creator's key sends it, numbered or as 0.4.2 sent it
Future<String> _roster(List<String> keys, {int? stamp, String? from}) async =>
    roomFrame(
      await wrapMessage(
        '',
        groupId: _room,
        groupControl: GroupControl(
          type: 'create',
          name: 'Friday',
          members: keys,
          stamp: stamp,
        ),
        sender: SenderInfo(
          haloId: from ?? _creator,
          edPub: '',
          onion: '',
          xPub: '',
        ),
      ),
      from ?? _creator,
    )!;

// the joiner's knock, through the creator's drop box, and what the creator
// sent back to the joiner's key
Future<List<String>> _creatorTakes(_Phone creator, String knock) async {
  creator.use();
  await creator.app.receiveRelay([(peer: 'roomfc:$_creator', cipher: knock)]);
  await _settle();
  await creator.app.ctlPassForTest;
  return [
    for (final s in creator.engine.sent)
      if (s.to == _mine) s.msg,
  ];
}

RoomJoin _stateOf(_Phone p) => roomJoinState(
  p.room?['joining_at'] as int?,
  DateTime.now().millisecondsSinceEpoch,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late List<String> said;
  final wasSay = sayRoomJoined;

  setUpAll(() {
    docs = Directory.systemTemp.createTempSync('room_join');
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

  test('a join waits, and says nothing until the creator lets it in', () async {
    final me = await _Phone.make();
    final before = DateTime.now().millisecondsSinceEpoch;
    expect(await me.app.joinRoom(_link()), '');
    await _settle();
    expect(me.room!['joining_at'] as int, greaterThanOrEqualTo(before));
    expect(_stateOf(me), RoomJoin.waiting);
    expect(me.app.groups.single.joiningAt, me.room!['joining_at']);
    // the knock went to the creator's drop box from this room's key alone
    final knock = me.engine.knocks.single;
    expect((knock.priv, knock.to, knock.fc), ('mypriv', _creator, _fc));
    final env = unwrapMessage(knock.msg);
    expect(env.groupControl?.type, 'join');
    expect(env.senderHaloId, _mine);
    expect(me.engine.listens, [_creator]);

    // a roster from another key, or the creator's without this key, lets
    // no one in
    await _fromRoom(me, _creator, await _roster([_creator, _other]));
    await _fromRoom(
      me,
      _other,
      await _roster([_creator, _mine, _other], from: _other),
    );
    expect(_stateOf(me), RoomJoin.waiting);
    expect(said, isEmpty);
  });

  test(
    'the creator\'s roster lets it in, and only then is it joined',
    () async {
      final me = await _Phone.make();
      final creator = await _creatorPhone(others: [_other]);
      me.use();
      await me.app.joinRoom(_link());
      await _settle();
      final back = await _creatorTakes(creator, me.engine.knocks.single.msg);
      expect(back, hasLength(1));
      expect(_stateOf(me), RoomJoin.waiting);
      await _fromRoom(me, _creator, back.single);
      expect(_stateOf(me), RoomJoin.live);
      expect(me.room!['joining_at'], isNull);
      expect(said, [l10n.appJoined('Friday')]);
      expect(me.app.groups.single.joiningAt, isNull);
      // and the rest of the room is listened to now
      expect(me.engine.listens, containsAll([_creator, _other]));
      // the same roster again says nothing more
      await _fromRoom(me, _creator, back.single);
      expect(said, hasLength(1));
    },
  );

  test('a creator on 0.4.2 lets it in too: its roster has no stamp', () async {
    final me = await _Phone.make();
    await me.app.joinRoom(_link());
    await _settle();
    await _fromRoom(me, _creator, await _roster([_creator, _mine]));
    expect(_stateOf(me), RoomJoin.live);
    expect(said, [l10n.appJoined('Friday')]);
  });

  test('a roster riding the creator\'s message lets it in', () async {
    final me = await _Phone.make();
    await me.app.joinRoom(_link());
    await _settle();
    final hi = roomFrame(
      await wrapMessage(
        'hello all',
        groupId: _room,
        msgUid: 'hi1',
        roster: [_creator, _mine],
        sender: SenderInfo(haloId: _creator, edPub: '', onion: '', xPub: ''),
      ),
      _creator,
    )!;
    await _fromRoom(me, _creator, hi);
    expect(_stateOf(me), RoomJoin.live);
    expect(said, hasLength(1));
  });

  test('a full room, or a creator gone, never lets it in', () async {
    final me = await _Phone.make();
    final full = await _creatorPhone(cap: 2, others: [_other]);
    me.use();
    await me.app.joinRoom(_link());
    await _settle();
    expect(await _creatorTakes(full, me.engine.knocks.single.msg), isEmpty);
    me.use();
    expect(_stateOf(me), RoomJoin.waiting);
    expect(said, isEmpty);
  });

  test('no roster within the wait: the room is not answering, and a late '
      'one still lets it in', () async {
    const at = 1000000;
    final wait = kRoomJoinWait.inMilliseconds;
    expect(roomJoinState(at, at), RoomJoin.waiting);
    expect(roomJoinState(at, at + wait - 1), RoomJoin.waiting);
    expect(roomJoinState(at, at + wait), RoomJoin.silent);
    // a clock set back is no reason to wait forever
    expect(roomJoinState(at, at - 1), RoomJoin.silent);
    expect(roomJoinState(null, at), RoomJoin.live);
    expect(kRoomJoinWait, const Duration(minutes: 2));

    final me = await _Phone.make();
    await me.app.joinRoom(_link());
    await _settle();
    me.room!['joining_at'] = DateTime.now().millisecondsSinceEpoch - wait - 1;
    expect(_stateOf(me), RoomJoin.silent);
    await _fromRoom(me, _creator, await _roster([_creator, _mine], stamp: 5));
    expect(_stateOf(me), RoomJoin.live);
    expect(said, hasLength(1));
  });

  test('try again sends the join as the first time, and the wait starts '
      'over', () async {
    final me = await _Phone.make();
    await me.app.joinRoom(_link());
    await _settle();
    final long = DateTime.now().millisecondsSinceEpoch - 600000;
    me.room!['joining_at'] = long;
    expect(_stateOf(me), RoomJoin.silent);
    await me.app.retryRoomJoin(_room);
    expect(_stateOf(me), RoomJoin.waiting);
    expect(me.room!['joining_at'] as int, greaterThan(long));
    await _settle();
    expect(me.engine.knocks, hasLength(2));
    final (a, b) = (me.engine.knocks.first, me.engine.knocks.last);
    expect((b.priv, b.to, b.fc), (a.priv, a.to, a.fc));
    final (ea, eb) = (unwrapMessage(a.msg), unwrapMessage(b.msg));
    expect(eb.groupControl?.type, ea.groupControl?.type);
    expect(eb.groupId, ea.groupId);
    expect(eb.senderHaloId, ea.senderHaloId);
    // numbered, so the creator does not drop it as one it already saw
    expect(b.msg, isNot(a.msg));
    expect(roomFramePlace(b.msg).number, roomFramePlace(a.msg).number! + 1);

    // the link again knocks again too, and does not say "already in"
    expect(await me.app.joinRoom(_link()), '');
    await _settle();
    expect(me.engine.knocks, hasLength(3));

    // and a creator who took the first knock answers the next one
    final creator = await _creatorPhone();
    final back = await _creatorTakes(creator, a.msg);
    expect(await _creatorTakes(creator, b.msg), hasLength(2));
    await _fromRoom(me, _creator, back.first);
    expect(_stateOf(me), RoomJoin.live);
    // let in, the link is a room it is already in
    expect(await me.app.joinRoom(_link()), l10n.appYouAreAlreadyIn);
  });

  test('leaving a waiting room leaves nothing behind', () async {
    final me = await _Phone.make();
    await me.app.joinRoom(_link());
    await _settle();
    await me.app.leaveRoom(_room);
    expect(me.rows.groupRows, isEmpty);
    expect(me.rows.members, isEmpty);
    expect(me.rows.ctlOut, isEmpty);
    expect(me.engine.unlistened, [_mine]);
    expect(me.engine.forgot, ['mypriv']);
    expect(me.app.groups, isEmpty);
    expect(said, isEmpty);
    // the link later is a new join with a new key, on the list again
    me.engine.keys.add((priv: 'mypriv2', pub: _other));
    expect(await me.app.joinRoom(_link()), '');
    expect(me.app.groups.single.joiningAt, isNotNull);
    expect(me.room!['room_pub'], _other);
  });

  test('a waiting room is still waiting after a restart, its clock from the '
      'first join', () async {
    final me = await _Phone.make();
    await me.app.joinRoom(_link());
    await _settle();
    final first = me.room!['joining_at'] as int;
    // the app again, over the same rows
    final again = await _Phone.make(rows: me.rows);
    await again.app.subscribeRoomsAtBoot();
    await again.app.refreshGroups();
    expect(again.engine.listens, [_creator]);
    expect(again.app.groups.single.joiningAt, first);
    expect(_stateOf(again), RoomJoin.waiting);
    expect(again.engine.knocks, isEmpty);
  });

  test('the wait is kept in the room\'s row, read back by a new start, and '
      'gone once let in', () async {
    final mem = MemDb();
    final at = DateTime.now().millisecondsSinceEpoch - 90000;
    await _Rows(mem).createRoom(
      groupId: _room,
      name: 'Friday',
      priv: 'mypriv',
      pub: _mine,
      expiresAt: at + 3600000,
      creatorPub: _creator,
      fcPk: _fc,
      members: [_creator, _mine],
      joiningAt: at,
    );
    // a new start opens the same file
    final again = _Rows(mem);
    expect((await again.getGroup(_room))!['joining_at'], at);
    expect((await again.loadGroups()).single['joining_at'], at);
    await again.setRoomJoining(_room, null);
    expect((await _Rows(mem).getGroup(_room))!['joining_at'], isNull);
  });

  test('on disk, try again restarts only a wait, and a failed join ends only '
      'its own', () async {
    final mem = MemDb();
    final db = _Rows(mem);
    final at = DateTime.now().millisecondsSinceEpoch - 600000;
    await db.createRoom(
      groupId: _room,
      name: 'Friday',
      priv: 'mypriv',
      pub: _mine,
      expiresAt: at + 3600000,
      creatorPub: _creator,
      fcPk: _fc,
      members: [_creator, _mine],
      joiningAt: at,
    );
    Future<Object?> joining() async =>
        (await db.getGroup(_room))!['joining_at'];
    expect(await db.restartRoomJoining(_room, at + 1), isTrue);
    expect(await joining(), at + 1);
    // an older join failing leaves the newer wait alone
    expect(await db.failRoomJoining(_room, at), isFalse);
    expect(await joining(), at + 1);
    expect(await db.failRoomJoining(_room, at + 1), isTrue);
    expect(await joining(), at + 1 - kRoomJoinWait.inMilliseconds);
    // let in: neither brings the wait back
    await db.setRoomJoining(_room, null);
    expect(await db.restartRoomJoining(_room, at + 2), isFalse);
    expect(await db.failRoomJoining(_room, at + 2), isFalse);
    expect(await joining(), isNull);
    expect(await db.restartRoomJoining('nothere0001', at), isFalse);
  });

  final sql = RealSqlite.open();
  test(
    'a phone from 62 gets the column, and keeps its rooms',
    () async {
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
      expect(table, contains('joining_at INTEGER'));
      final v62 = table.replaceFirst(RegExp(r',\s*joining_at INTEGER'), '');
      expect(v62, isNot(contains('joining_at')));
      db.run(v62);
      db.run(
        "INSERT INTO groups (group_id, name, created_at, room_pub) "
        "VALUES ('$_room', 'Friday', 1, '$_mine')",
      );
      await roomJoiningColumn(RealExecutor(db));
      // a second run finds it there
      await roomJoiningColumn(RealExecutor(db));
      expect(
        db
            .run('PRAGMA table_info(groups)')
            .where((c) => c['name'] == 'joining_at'),
        hasLength(1),
      );
      final row = db.run('SELECT * FROM groups').single;
      expect(row['room_pub'], _mine);
      // a room from before was let in long ago
      expect(row['joining_at'], isNull);
    },
    skip: sql == null ? 'no sqlite library here' : null,
  );

  test('the link again does not wait for the relays', () async {
    final me = await _Phone.make();
    await me.app.joinRoom(_link());
    await _settle();
    me.room!['joining_at'] = DateTime.now().millisecondsSinceEpoch - 600000;
    // a publish that takes its time, as a slow relay's does
    final gate = me.engine.knockGate = Completer<void>();
    expect(
      await me.app.joinRoom(_link()).timeout(const Duration(seconds: 2)),
      '',
    );
    expect(_stateOf(me), RoomJoin.waiting);
    await me.app.retryRoomJoin(_room).timeout(const Duration(seconds: 2));
    expect(me.engine.knocks, hasLength(1));
    gate.complete();
    await _settle();
    expect(me.engine.knocks, hasLength(3));
    expect(_stateOf(me), RoomJoin.waiting);
  });

  test('a roster for a room on its way out says nothing', () async {
    final me = await _Phone.make();
    await me.app.joinRoom(_link());
    await _settle();
    // the leave is still going out when the creator's roster comes
    final gate = me.engine.sendGate = Completer<void>();
    final leaving = me.app.leaveRoom(_room);
    await _settle();
    expect(me.rows.groupRows, isNotEmpty);
    await _fromRoom(me, _creator, await _roster([_creator, _mine], stamp: 5));
    expect(said, isEmpty);
    expect(me.room!['joining_at'], isNotNull);
    gate.complete();
    await leaving;
    expect(me.rows.groupRows, isEmpty);
    expect(said, isEmpty);
  });

  test('try again keeps a let-in that lands while it reads the room', () async {
    final rows = _Racing();
    final me = await _Phone.make(rows: rows);
    await me.app.joinRoom(_link());
    await _settle();
    me.room!['joining_at'] = DateTime.now().millisecondsSinceEpoch - 600000;
    rows.letInAfterRead = true;
    await me.app.retryRoomJoin(_room);
    await _settle();
    expect(me.room!['joining_at'], isNull);
    expect(_stateOf(me), RoomJoin.live);
    // and nothing knocked for a room it is in
    expect(me.engine.knocks, hasLength(1));
  });

  test('a join still being made when the room is left is never sent', () async {
    final rows = _Racing();
    final me = await _Phone.make(rows: rows);
    final gate = rows.seqGate = Completer<void>();
    await me.app.joinRoom(_link());
    await me.app.leaveRoom(_room);
    expect(me.rows.groupRows, isEmpty);
    gate.complete();
    await _settle();
    // no knock for a key nobody holds, and no number kept for the room
    expect(me.engine.knocks, isEmpty);
    expect(rows.roomSeqs, isEmpty);
    expect(me.rows.groupRows, isEmpty);
  });

  test('a join that does not go leaves the room not answering at once, and '
      'a roster later still lets it in', () async {
    final me = await _Phone.make();
    me.engine.answer = 'error: no relay';
    await me.app.joinRoom(_link());
    await _settle();
    expect(me.engine.knocks, hasLength(1));
    expect(_stateOf(me), RoomJoin.silent);
    expect(me.app.groups.single.joiningAt, me.room!['joining_at']);
    // try again, and it fails again: not answering again at once
    await me.app.retryRoomJoin(_room);
    expect(_stateOf(me), RoomJoin.waiting);
    await _settle();
    expect(_stateOf(me), RoomJoin.silent);
    // the relays back: try again waits as it should
    me.engine.answer = 'ok';
    await me.app.retryRoomJoin(_room);
    await _settle();
    expect(_stateOf(me), RoomJoin.waiting);
    await _fromRoom(me, _creator, await _roster([_creator, _mine], stamp: 5));
    expect(_stateOf(me), RoomJoin.live);
    expect(said, hasLength(1));
  });

  test('the same link twice at once is one join', () async {
    final me = await _Phone.make();
    me.engine.keys.add((priv: 'mypriv2', pub: _other));
    final both = await Future.wait([
      me.app.joinRoom(_link()),
      me.app.joinRoom(_link()),
    ]);
    await _settle();
    expect(both, ['', '']);
    expect(me.room!['room_pub'], _mine);
    expect(me.engine.keys, hasLength(1));
    expect(me.engine.knocks, hasLength(1));
    // and once the first is done, the link knocks again as before
    me.room!['joining_at'] = DateTime.now().millisecondsSinceEpoch - 600000;
    expect(await me.app.joinRoom(_link()), '');
    await _settle();
    expect(me.engine.knocks, hasLength(2));
  });

  test('nothing goes into a room not let in yet', () async {
    final me = await _Phone.make();
    await me.app.joinRoom(_link());
    await _settle();
    expect(await me.app.sendToGroup(_room, 'anyone here?'), isFalse);
    final file = File('${docs.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
    expect(
      await me.app.sendMediaToGroup(_room, file.path, msgUid: 'ph1'),
      'error: waiting',
    );
    expect(me.rows.msgs, isEmpty);
    expect(me.engine.sent, isEmpty);
  });

  test('a room frame carries no face, and a member\'s message lands without '
      'one', () async {
    final wrapped = await wrapMessage(
      'hello all',
      msgUid: 'av1',
      groupId: _room,
      supporterBadge: 'gold',
      sender: SenderInfo(
        haloId: 'me',
        edPub: 'ed',
        onion: 'me.onion',
        xPub: 'xme',
        avatar: 7,
      ),
    );
    Map<String, Object?> body(String w) =>
        jsonDecode(w.substring('halo/1:'.length)) as Map<String, Object?>;
    expect(body(wrapped)['av'], 7);
    final out = roomFrame(wrapped, _creator)!;
    for (final k in ['o', 'e', 'p', 'bg', 'av', 'rp']) {
      expect(body(out).containsKey(k), isFalse, reason: k);
    }
    expect(unwrapMessage(out).senderAvatar, isNull);

    // let in, the frame lands: no face kept for the room key
    final me = await _Phone.make();
    await me.app.joinRoom(_link());
    await _settle();
    await _fromRoom(me, _creator, await _roster([_creator, _mine], stamp: 5));
    expect(_stateOf(me), RoomJoin.live);
    await _fromRoom(me, _creator, out);
    expect(me.rows.msgs.map((m) => m['plaintext']), ['hello all']);
    expect(
      me.rows.calls.where((c) => c.startsWith('setContactAvatar')),
      isEmpty,
    );
  });

  test('a waiting room ends on time like any room', () async {
    final me = await _Phone.make();
    await me.app.joinRoom(_link());
    await _settle();
    me.room!['expires_at'] = DateTime.now().millisecondsSinceEpoch - 1;
    await me.app.sweepRooms();
    expect(me.rows.groupRows, isEmpty);
    expect(me.app.groups, isEmpty);
  });
}
