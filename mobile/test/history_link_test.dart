// SPDX-License-Identifier: GPL-3.0-or-later
// the history copy wired from the phone to a device it linked: the phone's
// copy made, served and checked, the device's asked for record by record,
// taken in, counted, the tally back. both sides killed along the way go on
// where they were. the door between them is in memory here, as the
// engine's (engine/history_serve.go, tested there over the real door)
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devices/device_state.dart' show linkedDevicesForTest;
import 'package:kryfo/devices/device_store.dart';
import 'package:kryfo/devices/history_export.dart';
import 'package:kryfo/devices/history_ffi.dart';
import 'package:kryfo/devices/history_link.dart';
import 'package:kryfo/devices/history_import.dart' show kHistoryTries;
import 'package:kryfo/devices/history_open.dart';
import 'package:kryfo/devices/own_device_store.dart';
import 'package:kryfo/devices/own_devices.dart' show DeviceKind;
import 'package:kryfo/main.dart'
    show
        addColumn,
        historyCopyShown,
        resumeHistoryCopies,
        searchTables,
        startDeviceHistoryCopy,
        startPhoneHistoryCopy;
import 'package:path/path.dart' as p;

import 'host_engine.dart';
import 'sqlite_ffi.dart';

const _identity =
    '058520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a';
const _anaKey =
    '05aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11';
const _ana = 'quiet-amber-harbor';
const _ben = 'tall-cedar-window';
const _hid = 'soft-violet-lantern';
const _group = 'g-0001';
const _uid = 'dev-1';

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List _rand(int n) {
  final r = Random.secure();
  return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
}

Future<SqliteMem> _schema() async {
  final db = SqliteMem.open()!;
  await appSchemaOn(db);
  await searchTables(db, fresh: true);
  await deviceTables(db, addColumn);
  return db;
}

class _Phone {
  _Phone(this.db, this.dir, this.media, this.now);
  final SqliteMem db;
  final String dir;
  final String media;
  final int now;
  final stream = _rand(32);
  final bind = _rand(32);
  final files = <String, Uint8List>{};
  int sent = 0;
}

int _n = 0;

Future<_Phone> _phone({String choice = 'all'}) async {
  final dir = Directory.systemTemp.createTempSync('hlink-phone').path;
  final media = p.join(dir, 'media');
  Directory(media).createSync();
  final now = DateTime.now().millisecondsSinceEpoch;
  final ph = _Phone(await _schema(), dir, media, now);
  final db = ph.db;
  Future<void> contact(String id, {String? ikey, String? nick}) =>
      db.insert('contacts', {
        'halo_id': id,
        'onion': '${id}onion',
        'xpub': '${id}xpub',
        'first_seen': now - 100000,
        'last_seen': now,
        'accepted': 1,
        'nickname': ?nick,
        'ikey': ?ikey,
      });
  Future<String> msg(
    String peer,
    String text, {
    String? group,
    int ago = 1000,
    String? media,
    String dir = 'in',
  }) async {
    final uid = 'u${_n++}';
    await db.insert('messages', {
      'peer_id': peer,
      'direction': dir,
      'plaintext': text,
      'sent_at': now - ago,
      'written_at': now - ago,
      'msg_uid': uid,
      'group_id': group,
      'media_path': media,
    });
    return uid;
  }

  String put(String name, int size, int seed) {
    final b = Uint8List.fromList(List.generate(size, (i) => (i * seed) & 255));
    final path = p.join(media, name);
    File(path).writeAsBytesSync(b);
    ph.files[name] = b;
    return path;
  }

  await contact(_ana, ikey: _anaKey, nick: 'Ana');
  await contact(_ben, nick: 'Ben');
  for (var i = 0; i < 40; i++) {
    await msg(_ana, 'ana says $i', ago: 90000 - i, dir: i.isOdd ? 'out' : 'in');
  }
  await msg(_ana, 'a photo', media: put('p1.jpg', 5000, 3), ago: 5000);
  await msg(_ben, 'ben here');
  await msg(_ben, 'a video', media: put('v1.mp4', 7000, 5), ago: 4000);
  await db.insert('groups', {
    'group_id': _group,
    'name': 'Climbing',
    'created_at': now,
  });
  await db.insert('group_members', {
    'group_id': _group,
    'halo_id': _ana,
    'joined_at': now,
  });
  await msg(_ana, 'group hello', group: _group);
  // a hidden chat stays on the phone
  await contact(_hid);
  await msg(_hid, 'hidden one to one');
  await db.insert('hidden_chats', {
    'chat_id': _hid,
    'kind': 'peer',
    'card': jsonEncode({'id': _hid}),
    'at': now,
  });
  // ana deleted a message on the phone lately: the device lets it go too
  await db.insert('gone_in', {'msg_uid': 'gone-1', 'peer_id': _ana, 'at': now});
  // the list the phone holds of ana's devices
  await db.insert('dev_lists', {
    'ident': 0,
    'owner': _anaKey,
    'version': 3,
    'wire': Uint8List.fromList(utf8.encode('ana list v3')),
  });
  // what its engine learnt of ana: a key her messages came under, and a
  // post-quantum session. a contact not in the copy keeps theirs here
  await db.insert('dev_proven', {
    'ident': 0,
    'peer': _anaKey,
    'key': '05${'ab' * 32}',
  });
  await db.insert('dev_pq', {'ident': 0, 'peer': _anaKey});
  await db.insert('dev_pq', {'ident': 0, 'peer': '05${'ee' * 32}'});
  ph.sent = 44;
  await addOwnDevice(
    db,
    uid: _uid,
    name: 'Computer',
    kind: DeviceKind.computer,
    linkedAt: DateTime.fromMillisecondsSinceEpoch(now),
    keys: [(ident: 0, dev: 2, key: '05${'cd' * 32}', reg: 7)],
    stream: ph.stream,
    hist: historyCopyHist(
      bind: ph.bind,
      identityHex: _identity,
      choice: choice,
    ),
  );
  return ph;
}

class _Device {
  _Device(this.db, this.media);
  final SqliteMem db;
  final String media;
  final lists = <({String identity, String wire})>[];
  int landed = 0;
}

Future<_Device> _device(_Phone ph) async {
  final dir = Directory.systemTemp.createTempSync('hlink-device').path;
  final media = p.join(dir, 'media');
  Directory(media).createSync();
  final db = await _schema();
  await db.insert('signal_meta', {
    'k': kLinkStreamMeta,
    'v': base64Encode(ph.stream),
  });
  return _Device(db, media);
}

// the phone's door, in memory, as the engine keeps it
class _Serve {
  _Serve(this.gen, this.key);
  final int gen;
  final String key;
  String why = 'making';
  int asked = 0;
  Uint8List? tally;
  bool goneAsked = false;
  Uint8List? gone;
}

class _Door implements HistoryDoor {
  final serves = <String, _Serve>{};
  PhoneHistoryCopy? phone;
  final gens = <int>[];
  final rests = <String>[];
  // a kill between the result kept and the door told
  bool endThrows = false;

  @override
  ({String tag, String askHex}) ask(String keyHex, String bindHex) =>
      (tag: 't', askHex: 'ask:$keyHex');

  @override
  String rest(String askHex, String why) {
    expect(askHex, startsWith('ask:'));
    rests.add(why);
    serves['t'] = _Serve(-1, '')..why = why;
    return 't';
  }

  @override
  void gone(String tag, Uint8List rows) {
    final s = serves[tag]!;
    if (s.gone != null) throw const HistoryRefused('sealed once');
    s.gone = rows;
  }

  @override
  ({String tag, String keyHex}) open(String keyHex, String bindHex, int gen) {
    // a key of its own per generation, as the engine's AgainKey gives
    final key = gen == 0
        ? keyHex
        : sha256.convert(utf8.encode('$keyHex/$bindHex/$gen')).toString();
    serves['t'] = _Serve(gen, key);
    gens.add(gen);
    return (tag: 't', keyHex: key);
  }

  @override
  void serve(String tag, int handle, int gen) => serves[tag]!.why = '';

  @override
  void end(String tag, String why) {
    if (endThrows) {
      endThrows = false;
      throw StateError('killed');
    }
    serves[tag]?.why = why;
  }

  @override
  ({String why, int asked, Uint8List? tally, bool gone}) state(String tag) {
    final s = serves[tag]!;
    return (why: s.why, asked: s.asked, tally: s.tally, gone: s.goneAsked);
  }

  @override
  void drop(String tag) => serves.remove(tag);
}

class _Wire implements HistoryWire {
  _Wire(this.door);
  final _Door door;
  bool up = true;
  // runs before record i goes: a kill, a change on the device
  FutureOr<void> Function(int i)? before;
  // an answer of its own for record i instead of the record
  String? Function(int i)? instead;
  // runs before the gone rows are asked for
  FutureOr<void> Function()? beforeGone;
  final asked = <int>[];
  int hellos = 0;

  _Serve _s() {
    final s = door.serves['t'];
    // no copy open: the door reads the ask as junk and shuts
    if (!up || s == null) throw const HistoryUnreached();
    return s;
  }

  @override
  Future<HistoryHello> hello() async {
    hellos++;
    final s = _s();
    if (s.why != '') return HistoryHello(why: s.why);
    return HistoryHello(
      gen: s.gen,
      id: door.phone!.outgoing!.id,
      keyHex: s.key,
    );
  }

  @override
  Future<({Uint8List? rec, String? why})> record(int gen, int i) async {
    var s = _s();
    if (s.why != '') return (rec: null, why: s.why);
    await before?.call(i);
    // what the step before did to the phone, as the door then answers
    s = _s();
    if (s.why != '') return (rec: null, why: s.why);
    if (gen != s.gen) return (rec: null, why: 'other');
    if (instead?.call(i) case final why?) return (rec: null, why: why);
    final out = door.phone?.outgoing;
    if (out == null) return (rec: null, why: 'ended');
    if (i + 1 > s.asked) s.asked = i + 1;
    asked.add(i);
    try {
      return (rec: out.record(i), why: null);
    } on HistoryRefused {
      return (rec: null, why: 'ended');
    }
  }

  @override
  Future<({Uint8List? rows, String? why})> gone(int gen, String id) async {
    await beforeGone?.call();
    final s = _s();
    if (s.why != '') return (rows: null, why: s.why);
    if (gen != s.gen) return (rows: null, why: 'other');
    final g = s.gone;
    if (g == null) {
      s.goneAsked = true;
      return (rows: null, why: 'making');
    }
    return (rows: g, why: null);
  }

  @override
  Future<String?> tally(Uint8List tally) async {
    final s = _s();
    if (s.why != '') return s.why;
    try {
      door.phone!.outgoing!.checkTally(tally);
    } catch (_) {
      return 'other';
    }
    s.tally = tally;
    return null;
  }

  @override
  void close() {}
}

class _World {
  _World(this.ph, this.d);
  final _Phone ph;
  final _Device d;
  final door = _Door();
  late final wire = _Wire(door);
  PhoneHistoryCopy? phone;
  DeviceHistoryCopy? device;
  Future<void>? phoneRun;
  Future<void>? deviceRun;
  HaloContainer container = HaloContainer.everyday;
  DateTime Function()? clock;
  final takenBack = <String>[];
  HistoryWire? wireOver;

  void startPhone() {
    final c = phone = PhoneHistoryCopy(
      db: ph.db,
      uid: _uid,
      door: door,
      clock: clock,
      poll: const Duration(milliseconds: 5),
      make:
          ({
            required keyHex,
            required bindHex,
            required identityHex,
            required skipMedia,
            required rowsOnly,
          }) => exportHistory(
            db: ph.db,
            container: container,
            mediaDir: ph.media,
            spoolDir: ph.dir,
            keyHex: keyHex,
            bindHex: bindHex,
            identityHex: identityHex,
            skipMedia: skipMedia,
            rowsOnly: rowsOnly,
            now: DateTime.fromMillisecondsSinceEpoch(ph.now),
            chunk: 1024,
          ),
    );
    door.phone = c;
    phoneRun = c.run();
  }

  void startDevice() {
    final c = device = DeviceHistoryCopy(
      db: d.db,
      mediaDir: d.media,
      wire: wireOver ?? wire,
      identityHex: _identity,
      bindHex: _hex(ph.bind),
      retry: const Duration(milliseconds: 5),
      pause: const Duration(milliseconds: 5),
      landed: (lists) async {
        d.lists
          ..clear()
          ..addAll(lists);
        d.landed++;
      },
      unlanded: (ids) async => takenBack.addAll(ids),
      forgetKey: () => forgetLinkStream(d.db),
      clock: clock,
    );
    deviceRun = c.run();
  }

  // both ends run until both copies are over
  Future<void> settle() async {
    for (var i = 0; i < 4000; i++) {
      final a = phone?.stage.value.step, b = device?.stage.value.step;
      if (a != null && b != null && historyCopyOver(a) && historyCopyOver(b)) {
        await phoneRun;
        await deviceRun;
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    fail(
      'never settled: ${phone?.stage.value.step} ${device?.stage.value.step}',
    );
  }
}

Future<int> _count(
  SqliteMem db,
  String sql, [
  List<Object?> args = const [],
]) async => (await db.rawQuery(sql, args)).first.values.first as int;

void main() {
  final engine = loadHostEngine();
  final sqlite = SqliteMem.open() != null;
  final skip = !engine
      ? 'engine not built for this computer (tool/host_engine.sh)'
      : !sqlite
      ? 'no sqlite on this host'
      : null;

  setUp(() => linkedDevicesForTest = true);
  tearDown(() => linkedDevicesForTest = false);

  test('a copy goes over the link and both sides count the same', () async {
    final ph = await _phone();
    final d = await _device(ph);
    // a message the phone deleted lately came here live: it goes here too
    await d.db.insert('contacts', {
      'halo_id': _ana,
      'onion': '',
      'xpub': '',
      'first_seen': 0,
      'last_seen': 0,
      'accepted': 0,
    });
    await d.db.insert('messages', {
      'peer_id': _ana,
      'direction': 'in',
      'plaintext': 'deleted on the phone',
      'sent_at': ph.now,
      'msg_uid': 'gone-1',
    });
    final w = _World(ph, d)..startPhone();
    final sizes = <int>[];
    w.phone!.stage.addListener(() => sizes.add(w.phone!.stage.value.bytes));
    w.startDevice();
    await w.settle();
    expect(w.phone!.stage.value.step, HistoryCopyStep.whole);
    expect(w.device!.stage.value.step, HistoryCopyStep.whole);
    // the size was there before a record went
    expect(sizes.first, greaterThan(0));
    expect(await _count(d.db, 'SELECT COUNT(*) FROM messages'), ph.sent);
    for (final f in ph.files.entries) {
      expect(File(p.join(d.media, f.key)).readAsBytesSync(), f.value);
    }
    // the hidden chat stayed on the phone
    expect(
      await _count(d.db, 'SELECT COUNT(*) FROM messages WHERE peer_id = ?', [
        _hid,
      ]),
      0,
    );
    expect(
      await _count(d.db, 'SELECT COUNT(*) FROM contacts WHERE halo_id = ?', [
        _hid,
      ]),
      0,
    );
    // v4 material: ana's identity key, the list the phone held, and what it
    // deleted, live copy and all
    expect(
      (await d.db.query(
        'contacts',
        where: 'halo_id = ?',
        whereArgs: [_ana],
      )).first['ikey'],
      _anaKey,
    );
    expect(d.lists, [
      (identity: _anaKey, wire: base64Encode(utf8.encode('ana list v3'))),
    ]);
    expect(await d.db.query('dev_proven', columns: ['peer', 'key']), [
      {'peer': _anaKey, 'key': '05${'ab' * 32}'},
    ]);
    expect(await d.db.query('dev_pq', columns: ['peer']), [
      {'peer': _anaKey},
    ]);
    expect(
      await _count(
        d.db,
        "SELECT COUNT(*) FROM messages WHERE msg_uid = 'gone-1'",
      ),
      0,
    );
    expect(
      await _count(
        d.db,
        "SELECT COUNT(*) FROM gone_in WHERE msg_uid = 'gone-1'",
      ),
      1,
    );
    // over on both sides: the stream key is gone from both
    expect(
      (await d.db.query(
        'signal_meta',
        where: 'k = ?',
        whereArgs: [kLinkStreamMeta],
      )),
      isEmpty,
    );
    final row = await historyCopyOf(ph.db, _uid);
    expect(row!.stream, isNull);
    // the bookkeeping went once the phone held the tally
    expect(
      await d.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE name LIKE 'history_%'",
      ),
      isEmpty,
    );
    // a start after shows how it ended and makes nothing again
    final again = _World(ph, d)..startPhone();
    await again.phoneRun;
    expect(again.phone!.stage.value.step, HistoryCopyStep.whole);
    expect(again.door.gens, isEmpty);
    // its door answers "done" from the kept ask key alone
    expect(again.door.rests, ['done']);
    expect(row.hist['q'], startsWith('ask:'));
  }, skip: skip);

  test('the device killed at every few records goes on where it was', () async {
    final ph = await _phone();
    final d = await _device(ph);
    final w = _World(ph, d)..startPhone();
    final cuts = <int>{1, 2, 5, 9, 14, 20, 27, 33, 40};
    var kills = 0;
    w.wire.before = (i) {
      if (cuts.remove(i)) {
        kills++;
        // killed with the record on its way: nothing of it was taken
        w.device!.stop();
      }
    };
    w.startDevice();
    while (true) {
      await w.deviceRun;
      if (historyCopyOver(w.device!.stage.value.step)) break;
      // the app comes back and the copy goes on from its stored place
      w.startDevice();
    }
    await w.settle();
    expect(kills, greaterThan(5));
    expect(w.device!.stage.value.step, HistoryCopyStep.whole);
    expect(w.phone!.stage.value.step, HistoryCopyStep.whole);
    expect(await _count(d.db, 'SELECT COUNT(*) FROM messages'), ph.sent);
    // after each kill it asked again from its place, never from the start
    expect(w.wire.asked.where((i) => i == 0).length, 1);
    expect(w.door.gens, [0]);
  }, skip: skip);

  test(
    'the phone killed mid copy makes it again, and it lands whole',
    () async {
      final ph = await _phone();
      final d = await _device(ph);
      final w = _World(ph, d)..startPhone();
      var killed = false;
      w.wire.before = (i) {
        if (i == 12 && !killed) {
          killed = true;
          w.phone!.stop();
        }
      };
      w.startDevice();
      while (!killed) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      await w.phoneRun;
      // the phone's app comes back: the copy is made again, a generation on
      w.startPhone();
      await w.settle();
      expect(w.door.gens, [0, 1]);
      expect(w.device!.stage.value.step, HistoryCopyStep.whole);
      expect(w.phone!.stage.value.step, HistoryCopyStep.whole);
      // what the first copy took went before the second came: nothing twice
      expect(await _count(d.db, 'SELECT COUNT(*) FROM messages'), ph.sent);
      expect(
        await _count(
          d.db,
          'SELECT COUNT(*) FROM (SELECT msg_uid FROM messages GROUP BY msg_uid '
          'HAVING COUNT(*) > 1)',
        ),
        0,
      );
    },
    skip: skip,
  );

  test('the phone killed while the tally was on its way ends whole', () async {
    final ph = await _phone();
    final d = await _device(ph);
    final w = _World(ph, d)..startPhone();
    final was = w.wire;
    var cut = false;
    // the device's tally never reaches this phone: it goes before it lands
    final wire = _CutTally(was, () {
      if (cut) return;
      cut = true;
      w.phone!.stop();
    });
    w.device = DeviceHistoryCopy(
      db: d.db,
      mediaDir: d.media,
      wire: wire,
      identityHex: _identity,
      bindHex: _hex(ph.bind),
      retry: const Duration(milliseconds: 5),
      landed: (_) async {},
      forgetKey: () => forgetLinkStream(d.db),
    );
    w.deviceRun = w.device!.run();
    while (!cut) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    await w.phoneRun;
    w.startPhone();
    await w.settle();
    expect(w.door.gens, [0, 1]);
    expect(w.phone!.stage.value.step, HistoryCopyStep.whole);
    expect(w.device!.stage.value.step, HistoryCopyStep.whole);
    expect(await _count(d.db, 'SELECT COUNT(*) FROM messages'), ph.sent);
  }, skip: skip);

  test('a chat with less on the device shows on both sides', () async {
    final ph = await _phone();
    final d = await _device(ph);
    final w = _World(ph, d)..startPhone();
    var spoilt = false;
    // a copied row lost on the device before the count
    w.wire.before = (i) async {
      final out = w.phone!.outgoing!;
      if (!spoilt && i == out.head.records - 1) {
        spoilt = true;
        await d.db.execute(
          "DELETE FROM messages WHERE plaintext = 'ana says 3'",
        );
      }
    };
    w.startDevice();
    await w.settle();
    for (final s in [w.device!.stage.value, w.phone!.stage.value]) {
      expect(s.step, HistoryCopyStep.gaps);
      expect(s.gaps.single.chat.id, _ana);
      expect(s.gaps.single.got.messages, s.gaps.single.want.messages - 1);
    }
    // kept as it ended, for the page, after a restart too
    final kept = await DeviceHistoryCopy.kept(d.db);
    expect(kept!.gaps.single.chat.id, _ana);
    final row = await historyCopyOf(ph.db, _uid);
    expect(
      HistoryCopyStage.fromJson(row!.hist['r'])!.gaps.single.want.messages,
      greaterThan(0),
    );
  }, skip: skip);

  test(
    'a hide ends the copy calmly on both sides, nothing of it stays',
    () async {
      final ph = await _phone();
      final d = await _device(ph);
      final w = _World(ph, d)..startPhone();
      var hidden = false;
      w.wire.before = (i) {
        if (i == 20 && !hidden) {
          hidden = true;
          // as hideChats does once a chat moved
          endHistoryCopies();
        }
      };
      w.startDevice();
      await w.settle();
      expect(w.phone!.stage.value.step, HistoryCopyStep.ended);
      expect(w.device!.stage.value.step, HistoryCopyStep.ended);
      expect(await _count(d.db, 'SELECT COUNT(*) FROM messages'), 0);
      // every row the copy made went with it: the contacts and the group
      // that had come, their members, none of it is left
      expect(w.takenBack, isNotEmpty);
      for (final t in ['contacts', 'groups', 'group_members', 'gone_in']) {
        expect(await _count(d.db, 'SELECT COUNT(*) FROM $t'), 0, reason: t);
      }
      expect(
        (await d.db.query(
          'signal_meta',
          where: 'k = ?',
          whereArgs: [kLinkStreamMeta],
        )),
        isEmpty,
      );
      expect((await historyCopyOf(ph.db, _uid))!.stream, isNull);
      expect(historyCopiesOpen, 0);
    },
    skip: skip,
  );

  test('no history brings the chats and contacts alone', () async {
    final ph = await _phone(choice: 'none');
    final d = await _device(ph);
    // ana's message the phone deleted came here live: it goes here too
    await d.db.insert('messages', {
      'peer_id': _ana,
      'direction': 'in',
      'plaintext': 'deleted on the phone',
      'sent_at': ph.now,
      'msg_uid': 'gone-1',
    });
    final w = _World(ph, d)
      ..startPhone()
      ..startDevice();
    await w.settle();
    expect(
      await _count(
        d.db,
        "SELECT COUNT(*) FROM gone_in WHERE msg_uid = 'gone-1'",
      ),
      1,
    );
    expect(w.device!.stage.value.step, HistoryCopyStep.whole);
    expect(w.device!.stage.value.rowsOnly, isTrue);
    expect(await _count(d.db, 'SELECT COUNT(*) FROM messages'), 0);
    expect(
      await _count(d.db, 'SELECT COUNT(*) FROM contacts WHERE accepted = 1'),
      2,
    );
    expect(await _count(d.db, 'SELECT COUNT(*) FROM groups'), 1);
    // the lists the phone holds come all the same
    expect(d.lists.single.identity, _anaKey);
    expect(
      Directory(d.media).listSync(recursive: true).whereType<File>(),
      isEmpty,
    );
  }, skip: skip);

  test('photos, videos and files skipped stay on the phone', () async {
    final ph = await _phone(choice: 'text');
    final d = await _device(ph);
    final w = _World(ph, d)
      ..startPhone()
      ..startDevice();
    await w.settle();
    expect(w.device!.stage.value.step, HistoryCopyStep.whole);
    expect(await _count(d.db, 'SELECT COUNT(*) FROM messages'), ph.sent);
    expect(
      Directory(d.media).listSync(recursive: true).whereType<File>(),
      isEmpty,
    );
  }, skip: skip);

  test('a phone out of reach: the device waits, then goes on', () async {
    final ph = await _phone();
    final d = await _device(ph);
    final w = _World(ph, d)..startPhone();
    final steps = <HistoryCopyStep>[];
    var downs = 0;
    w.wire.before = (i) {
      if (i == 7 && downs++ == 0) {
        w.wire.up = false;
        Timer(const Duration(milliseconds: 60), () => w.wire.up = true);
      }
    };
    w.startDevice();
    w.device!.stage.addListener(() => steps.add(w.device!.stage.value.step));
    await w.settle();
    expect(steps, contains(HistoryCopyStep.waiting));
    expect(w.device!.stage.value.step, HistoryCopyStep.whole);
    expect(await _count(d.db, 'SELECT COUNT(*) FROM messages'), ph.sent);
  }, skip: skip);

  test('the decoy never serves a copy', () async {
    final ph = await _phone();
    final d = await _device(ph);
    final w = _World(ph, d)..container = HaloContainer.decoy;
    w.startPhone();
    await w.phoneRun;
    expect(w.phone!.stage.value.step, HistoryCopyStep.failed);
    expect(w.door.serves['t']!.why, 'ended');
    w.startDevice();
    await w.deviceRun;
    expect(w.device!.stage.value.step, HistoryCopyStep.ended);
    expect(await _count(d.db, 'SELECT COUNT(*) FROM messages'), 0);
  }, skip: skip);

  test(
    'a device that never comes for its copy is let go after two weeks',
    () async {
      final ph = await _phone();
      final door = _Door();
      var now = DateTime.fromMillisecondsSinceEpoch(ph.now);
      var made = 0;
      PhoneHistoryCopy copy() => PhoneHistoryCopy(
        db: ph.db,
        uid: _uid,
        door: door,
        clock: () => now,
        make:
            ({
              required keyHex,
              required bindHex,
              required identityHex,
              required skipMedia,
              required rowsOnly,
            }) async {
              made++;
              throw const HistoryNotHere('test');
            },
      );
      await copy().run();
      expect(made, 1);
      // a later start, inside the two weeks: made again
      final row = await historyCopyOf(ph.db, _uid);
      await keepHistoryCopy(ph.db, _uid, {...row!.hist}..remove('r'));
      await ph.db.update('own_devices', {'stream': ph.stream});
      now = now.add(const Duration(days: 15));
      final late = copy();
      await late.run();
      expect(made, 1);
      expect(late.stage.value.step, HistoryCopyStep.failed);
      expect((await historyCopyOf(ph.db, _uid))!.stream, isNull);
      // no door was open: the device hears "ended" from the kept ask key
      expect(door.rests, ['ended']);
      expect(door.serves['t']!.why, 'ended');
    },
    skip: skip,
  );

  test('a copy the phone ended while the device was away ends there too, '
      'after the phone app came back', () async {
    final ph = await _phone();
    final d = await _device(ph);
    var now = DateTime.fromMillisecondsSinceEpoch(ph.now);
    final w = _World(ph, d)..clock = (() => now);
    w.startPhone();
    var away = false;
    w.wire.before = (i) {
      if (i == 10 && !away) {
        away = true;
        // the laptop shuts, then a chat is hidden on the phone
        w.wire.up = false;
        endHistoryCopies();
      }
    };
    w.startDevice();
    while (w.phone!.stage.value.step != HistoryCopyStep.ended) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    await w.phoneRun;
    // the phone's app goes and comes back: its door held nothing then
    w.phone!.stop();
    w.door.serves.clear();
    await PhoneHistoryCopy.restAll(ph.db, w.door, clock: () => now);
    expect(w.door.rests, ['ended']);
    w.wire.up = true;
    await w.deviceRun;
    expect(w.device!.stage.value.step, HistoryCopyStep.ended);
    expect(await _count(d.db, 'SELECT COUNT(*) FROM messages'), 0);
    expect(await _count(d.db, 'SELECT COUNT(*) FROM contacts'), 0);
    expect(await linkStreamOf(d.db), isNull);
    // a month on, the phone lets the ask key go
    now = now.add(const Duration(days: 31));
    await PhoneHistoryCopy.restAll(ph.db, w.door, clock: () => now);
    expect(w.door.rests, ['ended']);
    expect((await historyCopyOf(ph.db, _uid))!.hist.containsKey('q'), isFalse);
  }, skip: skip);

  test('a device whose phone never answers again lets its copy go after '
      'two weeks', () async {
    final ph = await _phone();
    final d = await _device(ph);
    var now = DateTime.fromMillisecondsSinceEpoch(ph.now);
    final w = _World(ph, d)..clock = (() => now);
    w.startPhone();
    w.wire.before = (i) {
      if (i == 8) {
        // the phone is gone for good
        w.wire.up = false;
        now = now.add(const Duration(days: 15));
      }
    };
    w.startDevice();
    await w.deviceRun!.timeout(const Duration(seconds: 20));
    expect(w.device!.stage.value.step, HistoryCopyStep.failed);
    expect(await _count(d.db, 'SELECT COUNT(*) FROM messages'), 0);
    expect(await _count(d.db, 'SELECT COUNT(*) FROM contacts'), 0);
    expect(await linkStreamOf(d.db), isNull);
    expect(
      await d.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE name LIKE 'history_%'",
      ),
      isEmpty,
    );
    w.phone!.stop();
    await w.phoneRun;
  }, skip: skip);

  test('a copy ended after it landed takes back every row it made', () async {
    final ph = await _phone();
    final d = await _device(ph);
    final w = _World(ph, d)..startPhone();
    // a chat is hidden on the phone while the tally is on its way
    w.wireOver = _CutTally(w.wire, endHistoryCopies);
    w.startDevice();
    await w.settle();
    expect(d.landed, 1);
    expect(w.phone!.stage.value.step, HistoryCopyStep.ended);
    expect(w.device!.stage.value.step, HistoryCopyStep.ended);
    expect(w.takenBack, containsAll([_ana, _ben]));
    for (final t in [
      'messages',
      'contacts',
      'groups',
      'group_members',
      'gone_in',
      'dev_proven',
      'dev_pq',
    ]) {
      expect(await _count(d.db, 'SELECT COUNT(*) FROM $t'), 0, reason: t);
    }
    expect(
      Directory(d.media).listSync(recursive: true).whereType<File>(),
      isEmpty,
    );
  }, skip: skip);

  test('a contact known here by key alone is put back as it was when the '
      'copy is taken back', () async {
    final ph = await _phone();
    final d = await _device(ph);
    await d.db.insert('contacts', {
      'halo_id': _ana,
      'onion': '',
      'xpub': '',
      'first_seen': 0,
      'last_seen': 0,
      'accepted': 0,
    });
    final before = (await d.db.query(
      'contacts',
      where: 'halo_id = ?',
      whereArgs: [_ana],
    )).single;
    final w = _World(ph, d)..startPhone();
    w.wireOver = _CutTally(w.wire, endHistoryCopies);
    w.startDevice();
    await w.settle();
    expect(d.landed, 1);
    expect(w.device!.stage.value.step, HistoryCopyStep.ended);
    expect(w.takenBack, contains(_ana));
    // the key-only row stays, with nothing the copy brought in it
    final after = await d.db.query('contacts');
    expect(after, [before]);
  }, skip: skip);

  test('what the phone deleted while the copy ran goes on the device too, '
      'and the copy stays whole', () async {
    final ph = await _phone();
    final d = await _device(ph);
    final w = _World(ph, d)..startPhone();
    Future<String> uidOf(String text) async =>
        (await ph.db.query(
              'messages',
              columns: ['msg_uid'],
              where: 'plaintext = ?',
              whereArgs: [text],
            )).first['msg_uid']
            as String;
    final gone = {
      await uidOf('ana says 4'): _ana,
      await uidOf('a photo'): _ana,
      await uidOf('group hello'): 'group:$_group:$_ana',
      await uidOf('hidden one to one'): _hid,
    };
    var deleted = false;
    w.wire.before = (i) async {
      if (i != 5 || deleted) return;
      deleted = true;
      // the copy is made: ana unsends on the phone alone
      for (final e in gone.entries) {
        await ph.db.insert('gone_in', {
          'msg_uid': e.key,
          'peer_id': e.value,
          'at': ph.now + 1,
        });
        await ph.db.delete(
          'messages',
          where: 'msg_uid = ?',
          whereArgs: [e.key],
        );
      }
    };
    w.startDevice();
    await w.settle();
    expect(w.phone!.stage.value.step, HistoryCopyStep.whole);
    expect(w.device!.stage.value.step, HistoryCopyStep.whole);
    expect(await _count(d.db, 'SELECT COUNT(*) FROM messages'), ph.sent - 3);
    for (final u in gone.keys) {
      expect(
        await _count(d.db, 'SELECT COUNT(*) FROM messages WHERE msg_uid = ?', [
          u,
        ]),
        0,
      );
    }
    // noted gone for the chats that came, never for the hidden one
    expect(
      await _count(
        d.db,
        'SELECT COUNT(*) FROM gone_in WHERE msg_uid IN (?, ?, ?, ?)',
        gone.keys.toList(),
      ),
      3,
    );
    expect(File(p.join(d.media, 'p1.jpg')).existsSync(), isFalse);
    expect(File(p.join(d.media, 'v1.mp4')).existsSync(), isTrue);
  }, skip: skip);

  test('a record the phone cannot give now is asked again later, with no '
      'new hello, and pauses after many', () async {
    final ph = await _phone();
    final d = await _device(ph);
    final w = _World(ph, d)..startPhone();
    var nones = 0;
    w.wire.instead = (i) =>
        i == 6 && nones++ < kHistoryTries + 2 ? 'none' : null;
    final steps = <HistoryCopyStep>[];
    while (w.phone!.stage.value.step == HistoryCopyStep.making) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    w.startDevice();
    w.device!.stage.addListener(() => steps.add(w.device!.stage.value.step));
    await w.settle();
    expect(w.device!.stage.value.step, HistoryCopyStep.whole);
    expect(w.wire.hellos, 1);
    expect(steps, contains(HistoryCopyStep.paused));
    expect(await _count(d.db, 'SELECT COUNT(*) FROM messages'), ph.sent);
  }, skip: skip);

  test('the phone keeps how a copy ended before its door says it', () async {
    final ph = await _phone();
    final d = await _device(ph);
    final w = _World(ph, d)..startPhone();
    // killed between the two: the door never heard
    w.door.endThrows = true;
    final ran = w.phoneRun!.then<Object?>(
      (_) => null,
      onError: (Object e) => e,
    );
    w.startDevice();
    final err = await ran;
    expect(err, isA<StateError>());
    final row = await historyCopyOf(ph.db, _uid);
    expect(
      HistoryCopyStage.fromJson(row!.hist['r'])!.step,
      HistoryCopyStep.whole,
    );
    expect(row.stream, isNull);
    // the next start makes nothing and answers "done"
    final again = _World(ph, d)..startPhone();
    await again.phoneRun;
    expect(again.door.gens, isEmpty);
    expect(again.door.rests, ['done']);
    await w.deviceRun;
  }, skip: skip);

  test('two starts for one device run one copy', () async {
    final runs = HistoryCopyRuns();
    var n = 0;
    final go = Completer<void>();
    Future<void> run() async {
      n++;
      await go.future;
    }

    final a = runs.start(_uid, run);
    final b = runs.start(_uid, run);
    expect(runs.running(_uid), isTrue);
    go.complete();
    await Future.wait([a, b]);
    expect(n, 1);
    expect(runs.running(_uid), isFalse);
    await runs.start(_uid, run);
    expect(n, 2);
  });

  test('a stage keeps what it showed across a restart', () {
    final s = HistoryCopyStage(
      HistoryCopyStep.gaps,
      bytes: 12000,
      records: 40,
      at: 40,
      gaps: [
        HistoryChatGap(
          const HistoryChatRef(true, _group),
          const HistoryCount(5, 2, 900),
          const HistoryCount(4, 2, 900),
        ),
      ],
      left: [HistoryChatLeft(const HistoryChatRef(false, _ben), 1, 2)],
      leftChats: 1,
    );
    final back = HistoryCopyStage.fromJson(jsonEncode(s.toJson()))!;
    expect(back.step, s.step);
    expect(back.bytes, 12000);
    expect(back.gaps.single.chat.group, isTrue);
    expect(back.gaps.single.got, const HistoryCount(4, 2, 900));
    expect(back.left.single.files, 2);
    expect(back.leftChats, 1);
    expect(HistoryCopyStage.fromJson('{"st":"nope"}'), isNull);
  });

  test('with the switch off no copy starts on either side', () async {
    linkedDevicesForTest = false;
    resumeHistoryCopies();
    startPhoneHistoryCopy(_uid);
    startDeviceHistoryCopy();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(historyCopyShown.value, isNull);
  });

  test(
    'the engine door and wire are bound',
    () {
      final door = EngineHistoryDoor();
      final k = _hex(_rand(32)), b = _hex(_rand(32));
      final o = door.open(k, b, 0);
      expect(o.keyHex, k);
      expect(o.tag, hasLength(32));
      expect(door.state(o.tag).why, 'making');
      final o2 = door.open(k, b, 2);
      expect(o2.tag, o.tag);
      expect(o2.keyHex, isNot(k));
      door.end(o.tag, 'ended');
      expect(door.state(o.tag).why, 'ended');
      door.drop(o.tag);
      expect(() => door.state(o.tag), throwsA(isA<HistoryRefused>()));
      // the device asks only an onion
      final wire = EngineHistoryWire(
        onion: 'example.com',
        keyHex: k,
        bindHex: b,
      );
      expect(wire.hello(), throwsA(isA<HistoryRefused>()));
    },
    skip: !engine ? 'engine not built for this computer' : null,
  );
}

// a wire whose first tally is cut short as the phone goes
class _CutTally implements HistoryWire {
  _CutTally(this.w, this.cut);
  final _Wire w;
  final void Function() cut;
  bool once = false;

  @override
  Future<HistoryHello> hello() => w.hello();
  @override
  Future<({Uint8List? rec, String? why})> record(int gen, int i) =>
      w.record(gen, i);
  @override
  Future<({Uint8List? rows, String? why})> gone(int gen, String id) =>
      w.gone(gen, id);
  @override
  Future<String?> tally(Uint8List t) async {
    if (!once) {
      once = true;
      cut();
      throw const HistoryUnreached();
    }
    return w.tally(t);
  }

  @override
  void close() {}
}
