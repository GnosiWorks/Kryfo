// SPDX-License-Identifier: GPL-3.0-or-later
// a room's maker resets its link: the old one knocks on a door nobody
// listens to, so it lets no one in and a knock on it goes unanswered as one
// on a phone that is off. the new one joins. the members stay, still talk,
// and their link follows. the reset outlives a restart and a restore, and a
// decoy's stays on the phone. only the maker is offered it, and taking
// someone out says the link lets them back unless it is reset. the engine,
// the relays and the databases are stand-ins
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
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
  'otherpriv': 'b2',
  'apriv': 'a1',
  'bpriv': 'e3',
};
String _pubOf(String priv) => _pubs[priv]! * 32;
const _fcs = {'creatorpriv': 'f0', 'doorpriv': 'f2'};

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
  Future<String> roomUnsubscribe(String pub) async {
    _shut(pub);
    return 'ok';
  }

  @override
  void roomForgetBg(String priv, List<String> members) => forgot.add(priv);
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
    ArrivalRows(box)
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

  test('a reset outlives a backup restore: the copy keeps the new door, '
      'and the phone it lands on listens there', () async {
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
    await db.setRoomDoor(_room, priv: 'doorpriv', pub: _door, fcPk: _fc2);

    // the backup carries the database whole
    final back = _Rows(mem.copy());
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

    final restored = await _Phone.make(
      rows: ArrivalRows(HaloContainer.everyday)
        ..group(_room, await back.getGroupMembers(_room), admin: _creator)
        ..groupRows[_room]!.addAll(g),
    );
    await restored.app.subscribeRoomsAtBoot();
    expect(restored.engine.dropBoxes, ['doorpriv']);
    expect((await restored.app.roomLinkFor(_room))!.fcPk, _fc2);
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
      RegExp(r',\s*door_priv TEXT,\s*door_pub TEXT'),
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
    final row = db.run('SELECT * FROM groups').single;
    expect(row['room_pub'], _creator);
    expect(row['fc_pk'], _fc);
    // never reset: its link knocks on the room's own key
    expect(row['door_priv'], isNull);
    expect(row['door_pub'], isNull);
    // the last step, after every older one
    expect(src, contains('version: 68,'));
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
          'them out.',
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
