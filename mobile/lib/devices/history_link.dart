// SPDX-License-Identifier: GPL-3.0-or-later
// the history copy between the phone and a device it just linked, wired:
// the phone makes the stream and its door serves it (engine/history_serve.go),
// the device asks for each record over the phone's onion and takes it in.
// both ends keep their place, so a kill of either side goes on where it
// was: the device from its stored state, the phone with a stream made
// again under a key of its own generation. at the end the device counts
// every chat and sends the tally back, and both show what differs
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../engine_strings.dart' show engineTakeSecret;
import 'history_export.dart';
import 'history_ffi.dart';
import 'history_import.dart';
import 'own_device_store.dart' show historyCopyOf, keepHistoryCopy;
import 'own_devices.dart' show LinkHistory;

// ---- the engine's calls ----

/// the phone's door for the copies it serves
abstract class HistoryDoor {
  /// a copy of the link stream [keyHex] at generation [gen]: its tag, and
  /// the key its sender seals under
  ({String tag, String keyHex}) open(String keyHex, String bindHex, int gen);

  /// the copy's sender is made: its records go to whoever holds the link
  void serve(String tag, int handle, int gen);

  /// ended by a hide ('ended'), or done ('done')
  void end(String tag, String why);

  /// how far the device asked, and its tally once it came
  ({String why, int asked, Uint8List? tally}) state(String tag);

  void drop(String tag);
}

/// the device could not reach its phone: tried again later
class HistoryUnreached implements Exception {
  const HistoryUnreached();
}

/// the phone's first answer: the copy's generation, its sender and its key,
/// or why there is none to take
@immutable
class HistoryHello {
  const HistoryHello({this.why, this.gen = 0, this.id = '', this.keyHex = ''});
  final String? why;
  final int gen;
  final String id;
  final String keyHex;
}

/// the device's asks of its phone
abstract class HistoryWire {
  Future<HistoryHello> hello();

  /// record [i] of the copy of generation [gen], or why the phone has none
  /// (null record): 'other' when it made the copy again since
  Future<({Uint8List? rec, String? why})> record(int gen, int i);

  /// the tally back: null once the phone holds it, else its why
  Future<String?> tally(Uint8List tally);

  void close();
}

typedef _JsonC = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _Json = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

DynamicLibrary _halo() => Platform.isAndroid
    ? DynamicLibrary.open('libhalo.so')
    : DynamicLibrary.process();

Map<String, dynamic> _call(String fn, String op, Map<String, Object?> args) {
  final run = _halo().lookupFunction<_JsonC, _Json>(fn);
  final o = op.toNativeUtf8();
  final a = jsonEncode(args).toNativeUtf8();
  try {
    // answers carry keys: zeroed once read
    return jsonDecode(engineTakeSecret(run(o, a))) as Map<String, dynamic>;
  } finally {
    calloc.free(o);
    a.cast<Uint8>().asTypedList(a.length).fillRange(0, a.length, 0);
    calloc.free(a);
  }
}

class EngineHistoryDoor implements HistoryDoor {
  Map<String, dynamic> _do(String op, Map<String, Object?> args) {
    final j = _call('HaloHistServe', op, args);
    final err = j['err'] as String?;
    if (err != null) throw HistoryRefused(err);
    return j;
  }

  @override
  ({String tag, String keyHex}) open(String keyHex, String bindHex, int gen) {
    final j = _do('open', {'key': keyHex, 'bind': bindHex, 'gen': gen});
    return (tag: j['tag'] as String, keyHex: j['key'] as String);
  }

  @override
  void serve(String tag, int handle, int gen) =>
      _do('serve', {'tag': tag, 'send': handle, 'gen': gen});

  @override
  void end(String tag, String why) => _do('end', {'tag': tag, 'why': why});

  @override
  ({String why, int asked, Uint8List? tally}) state(String tag) {
    final j = _do('state', {'tag': tag});
    final t = j['tally'];
    return (
      why: j['why'] as String? ?? '',
      asked: (j['asked'] as num?)?.toInt() ?? 0,
      tally: t is String ? base64Decode(t) : null,
    );
  }

  @override
  void drop(String tag) => _do('drop', {'tag': tag});
}

/// the device's asks through the engine, each on an isolate of its own: an
/// answer over tor takes seconds, and the screen goes on meanwhile
class EngineHistoryWire implements HistoryWire {
  EngineHistoryWire({
    required this.onion,
    required this.keyHex,
    required this.bindHex,
  });
  final String onion;
  final String keyHex;
  final String bindHex;

  Future<Map<String, dynamic>> _ask(String op, Map<String, Object?> extra) {
    final args = {'onion': onion, 'key': keyHex, 'bind': bindHex, ...extra};
    return Isolate.run(() => _call('HaloHistFetch', op, args));
  }

  static void _check(Map<String, dynamic> j) {
    final err = j['err'] as String?;
    if (err == 'unreached') throw const HistoryUnreached();
    if (err != null) throw HistoryRefused(err);
  }

  @override
  Future<HistoryHello> hello() async {
    final j = await _ask('hello', const {});
    _check(j);
    final why = j['why'] as String?;
    if (why != null) return HistoryHello(why: why);
    return HistoryHello(
      gen: (j['gen'] as num?)?.toInt() ?? 0,
      id: j['id'] as String,
      keyHex: j['key'] as String,
    );
  }

  @override
  Future<({Uint8List? rec, String? why})> record(int gen, int i) async {
    final j = await _ask('rec', {'i': i, 'gen': gen});
    _check(j);
    final r = j['rec'];
    return (
      rec: r is String ? base64Decode(r) : null,
      why: j['why'] as String?,
    );
  }

  @override
  Future<String?> tally(Uint8List tally) async {
    final j = await _ask('tally', {'tally': base64Encode(tally)});
    _check(j);
    return j['ok'] == true ? null : (j['why'] as String? ?? 'none');
  }

  @override
  void close() => _call('HaloHistFetch', 'close', const {});
}

// ---- what the screens show ----

enum HistoryCopyStep {
  /// the phone gathers what goes
  making,

  /// the other side is not reachable now; it goes on when it is
  waiting,
  copying,

  /// it tries again in a while
  paused,

  /// every message and file came over
  whole,

  /// some chats came with less than the phone holds
  gaps,

  /// stopped on the phone: nothing more comes
  ended,

  /// the copy could not finish; nothing of it stays
  failed,
}

bool historyCopyOver(HistoryCopyStep s) =>
    s == HistoryCopyStep.whole ||
    s == HistoryCopyStep.gaps ||
    s == HistoryCopyStep.ended ||
    s == HistoryCopyStep.failed;

@immutable
class HistoryCopyStage {
  const HistoryCopyStage(
    this.step, {
    this.bytes = 0,
    this.records = 0,
    this.at = 0,
    this.rowsOnly = false,
    this.gaps = const [],
    this.left = const [],
    this.leftChats = 0,
    this.stays = const [],
  });
  final HistoryCopyStep step;

  /// the whole copy on the wire, shown before it goes
  final int bytes;
  final int records;
  final int at;

  /// "no history": chats and contacts alone
  final bool rowsOnly;
  final List<HistoryChatGap> gaps;
  final List<HistoryChatLeft> left;
  final int leftChats;
  final List<HistoryStay> stays;

  /// how far, 0 to 1
  double get share => records <= 0 ? 0 : (at / records).clamp(0, 1);

  HistoryCopyStage moved(HistoryCopyStep step, {int? at}) => HistoryCopyStage(
    step,
    bytes: bytes,
    records: records,
    at: at ?? this.at,
    rowsOnly: rowsOnly,
  );

  static List<Object?> _ref(HistoryChatRef c) => [c.group ? 1 : 0, c.id];
  static HistoryChatRef _refOf(Object? v) {
    final l = v as List;
    return HistoryChatRef(l[0] == 1, l[1] as String);
  }

  static List<int> _count(HistoryCount c) => [c.messages, c.media, c.bytes];
  static HistoryCount _countOf(Object? v) {
    final l = (v as List).cast<num>();
    return HistoryCount(l[0].toInt(), l[1].toInt(), l[2].toInt());
  }

  Map<String, Object?> toJson() => {
    'st': step.name,
    'b': bytes,
    'n': records,
    'o': rowsOnly,
    'g': [
      for (final g in gaps) [_ref(g.chat), _count(g.want), _count(g.got)],
    ],
    'l': [
      for (final l in left) [_ref(l.chat), l.rows, l.files],
    ],
    'lc': leftChats,
    's': [
      for (final s in stays) [_ref(s.chat), s.why],
    ],
  };

  static HistoryCopyStage? fromJson(Object? raw) {
    try {
      final j = (raw is String ? jsonDecode(raw) : raw) as Map;
      final step = HistoryCopyStep.values.byName(j['st'] as String);
      return HistoryCopyStage(
        step,
        bytes: (j['b'] as num?)?.toInt() ?? 0,
        records: (j['n'] as num?)?.toInt() ?? 0,
        at: (j['n'] as num?)?.toInt() ?? 0,
        rowsOnly: j['o'] == true,
        gaps: [
          for (final g in (j['g'] as List? ?? const []))
            HistoryChatGap(
              _refOf((g as List)[0]),
              _countOf(g[1]),
              _countOf(g[2]),
            ),
        ],
        left: [
          for (final l in (j['l'] as List? ?? const []))
            HistoryChatLeft(
              _refOf((l as List)[0]),
              (l[1] as num).toInt(),
              (l[2] as num).toInt(),
            ),
        ],
        leftChats: (j['lc'] as num?)?.toInt() ?? 0,
        stays: [
          for (final s in (j['s'] as List? ?? const []))
            HistoryStay(_refOf((s as List)[0]), s[1] as String),
        ],
      );
    } catch (_) {
      return null;
    }
  }
}

// a wait a stop cuts short
class _Sleep {
  Completer<void>? _c;
  Timer? _t;

  Future<void> wait(Duration d) {
    final c = _c = Completer<void>();
    _t = Timer(d, () {
      if (!c.isCompleted) c.complete();
    });
    return c.future;
  }

  void wake() {
    _t?.cancel();
    final c = _c;
    if (c != null && !c.isCompleted) c.complete();
  }
}

// ---- the phone ----

/// how the phone makes the stream: exportHistory on the everyday database
/// with the app's folders and the vault's hold
typedef HistoryMake =
    Future<HistoryOutgoing> Function({
      required String keyHex,
      required String bindHex,
      required String identityHex,
      required bool skipMedia,
      required bool rowsOnly,
    });

String _choiceName(LinkHistory h) => switch (h) {
  LinkHistory.all => 'all',
  LinkHistory.textOnly => 'text',
  LinkHistory.none => 'none',
};

/// what the phone keeps of a device's copy, beside the link's stream key
/// (own_devices.stream): written with the device, in that transaction
String historyCopyHist({
  required Uint8List bind,
  required String identityHex,
  required LinkHistory choice,
}) => jsonEncode({
  'b': historyHex(bind),
  'i': identityHex,
  'c': _choiceName(choice),
});

/// how long the phone keeps a copy for a device that has not taken it
const kHistoryCopyFor = Duration(days: 14);

/// one device's copy on the phone: made, served, and checked against the
/// device's tally. the stream key goes once the copy is over
class PhoneHistoryCopy {
  PhoneHistoryCopy({
    required this.db,
    required this.uid,
    required this.door,
    required this.make,
    Duration? poll,
    DateTime Function()? clock,
  }) : poll = poll ?? const Duration(seconds: 1),
       clock = clock ?? DateTime.now;

  final Database db;

  /// the device's own_devices row
  final String uid;
  final HistoryDoor door;
  final HistoryMake make;
  final Duration poll;
  final DateTime Function() clock;

  final stage = ValueNotifier(const HistoryCopyStage(HistoryCopyStep.making));
  final _sleep = _Sleep();
  bool _stopped = false;
  HistoryOutgoing? _out;
  String? _tag;

  /// the stream the door serves now, for tests
  @visibleForTesting
  HistoryOutgoing? get outgoing => _out;

  Future<void> _keep(Map<String, Object?> hist, {bool forget = false}) =>
      keepHistoryCopy(db, uid, hist, forget: forget);

  /// the copy from where the rows say it is. a copy over shows how it
  /// ended; one under way is made again, under the next generation's key
  Future<void> run() async {
    final row = await historyCopyOf(db, uid);
    if (row == null) return;
    final hist = Map.of(row.hist);
    final done = HistoryCopyStage.fromJson(hist['r']);
    if (done != null && historyCopyOver(done.step)) {
      stage.value = done;
      return;
    }
    final stream = row.stream;
    if (stream == null || stream.length != 32) return;
    final bind = hist['b'] as String, identity = hist['i'] as String;
    final choice = hist['c'] as String? ?? 'all';
    // a device that never comes back for its copy: the phone stops making
    // it again at every start
    final now = clock().millisecondsSinceEpoch;
    final since = (hist['at'] as num?)?.toInt() ?? now;
    hist['at'] = since;
    if (now - since > kHistoryCopyFor.inMilliseconds) {
      return _over(hist, const HistoryCopyStage(HistoryCopyStep.failed));
    }
    // a generation is spent once its sender may have been made: written
    // before, so a kill after never reuses it
    final was = (hist['g'] as num?)?.toInt();
    final gen = was == null ? 0 : was + 1;
    hist['g'] = gen;
    await _keep(hist);
    final key = historyHex(stream);
    final o = door.open(key, bind, gen);
    _tag = o.tag;
    if (_stopped) return;
    final HistoryOutgoing out;
    try {
      out = _out = await make(
        keyHex: o.keyHex,
        bindHex: bind,
        identityHex: identity,
        skipMedia: choice == 'text',
        rowsOnly: choice == 'none',
      );
    } on HistoryHiddenMeanwhile {
      return _over(hist, const HistoryCopyStage(HistoryCopyStep.ended));
    } catch (_) {
      if (_stopped) return;
      return _over(hist, const HistoryCopyStage(HistoryCopyStep.failed));
    }
    if (_stopped) {
      out.close();
      return;
    }
    door.serve(o.tag, out.handle, gen);
    stage.value = HistoryCopyStage(
      HistoryCopyStep.copying,
      bytes: out.head.bytes,
      records: out.head.records,
      rowsOnly: choice == 'none',
    );
    while (!_stopped) {
      if (out.ended) {
        return _over(hist, const HistoryCopyStage(HistoryCopyStep.ended));
      }
      final s = door.state(o.tag);
      final t = s.tally;
      if (t != null) {
        final List<HistoryChatGap> gaps;
        try {
          gaps = out.checkTally(t);
        } on HistoryRefused {
          // not this copy's: the device makes it again
          await _sleep.wait(poll);
          continue;
        }
        final v = stage.value;
        return _over(
          hist,
          HistoryCopyStage(
            gaps.isEmpty && out.left.isEmpty && out.leftChats == 0
                ? HistoryCopyStep.whole
                : HistoryCopyStep.gaps,
            bytes: v.bytes,
            records: v.records,
            at: v.records,
            rowsOnly: v.rowsOnly,
            gaps: [
              for (final g in gaps)
                if (g.chat.id.isNotEmpty) g,
            ],
            left: [
              for (final l in out.left)
                if (l.chat.id.isNotEmpty) l,
            ],
            leftChats: out.leftChats,
          ),
          why: 'done',
        );
      }
      if (s.asked != stage.value.at) {
        stage.value = stage.value.moved(HistoryCopyStep.copying, at: s.asked);
      }
      await _sleep.wait(poll);
    }
  }

  // the copy is over: said, kept, and the stream key forgotten
  Future<void> _over(
    Map<String, Object?> hist,
    HistoryCopyStage end, {
    String why = 'ended',
  }) async {
    // a stop is a kill: nothing written, the next run makes it again
    if (_stopped) return;
    final tag = _tag;
    if (tag != null) door.end(tag, why);
    _out?.close();
    _out = null;
    hist['r'] = end.toJson();
    await _keep(hist, forget: true);
    stage.value = end;
  }

  /// the app goes (or a test kills it): nothing more is served, nothing is
  /// written, and the next run makes the copy again
  void stop() {
    _stopped = true;
    _sleep.wake();
    _out?.close();
    _out = null;
    final tag = _tag;
    if (tag != null) door.drop(tag);
  }
}

// ---- the device ----

/// where a linked device keeps how its copy ended, for its screens
const kHistoryCopyMeta = 'history_copy';

/// the device's copy: asked for record by record over the phone's onion,
/// taken in, counted, and the tally sent back. [landed] runs once every
/// record is in, with the lists the phone held, before the tally goes
class DeviceHistoryCopy {
  DeviceHistoryCopy({
    required this.db,
    required this.mediaDir,
    required this.wire,
    required this.identityHex,
    required this.bindHex,
    required this.landed,
    required this.forgetKey,
    Duration? retry,
    Duration? pause,
  }) : retry = retry ?? const Duration(seconds: 5),
       pause = pause ?? const Duration(minutes: 1);

  final Database db;
  final String mediaDir;
  final HistoryWire wire;
  final String identityHex;
  final String bindHex;
  final Future<void> Function(List<({String identity, String wire})> lists)
  landed;

  /// the link's stream key goes: the copy is over
  final Future<void> Function() forgetKey;
  final Duration retry;
  final Duration pause;

  final stage = ValueNotifier(const HistoryCopyStage(HistoryCopyStep.making));
  final _sleep = _Sleep();
  bool _stopped = false;
  HistoryImport? _imp;

  // tries in a row the phone could not be reached: further apart, to a minute
  int _misses = 0;
  Future<void> _waitPhone({bool show = true}) {
    _misses++;
    if (show) stage.value = stage.value.moved(HistoryCopyStep.waiting);
    final s = retry * (1 << (_misses - 1).clamp(0, 4));
    const most = Duration(minutes: 1);
    return _sleep.wait(s > most ? most : s);
  }

  Future<void> _keep(HistoryCopyStage s) async {
    await db.insert('signal_meta', {
      'k': kHistoryCopyMeta,
      'v': jsonEncode(s.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    stage.value = s;
  }

  /// how the copy ended, when it did
  static Future<HistoryCopyStage?> kept(DatabaseExecutor db) async {
    final r = await db.query(
      'signal_meta',
      columns: ['v'],
      where: 'k = ?',
      whereArgs: [kHistoryCopyMeta],
    );
    return r.isEmpty ? null : HistoryCopyStage.fromJson(r.first['v']);
  }

  Future<void> _end(HistoryCopyStage s) async {
    final imp = _imp;
    _imp = null;
    if (imp != null) {
      await imp.discard();
    } else {
      // a copy a kill left: what it put here goes too
      final held = await HistoryImport.reopen(db: db, mediaDir: mediaDir);
      await held?.discard();
    }
    await _keep(s);
    await forgetKey();
  }

  // the tally owed to the phone, kept until it holds it
  static const _kOwed = 'history_tally';

  Future<Uint8List?> _owed() async {
    final r = await db.query(
      'signal_meta',
      columns: ['v'],
      where: 'k = ?',
      whereArgs: [_kOwed],
    );
    if (r.isEmpty) return null;
    try {
      return base64Decode(r.first['v'] as String);
    } on FormatException {
      return null;
    }
  }

  Future<void> run() async {
    while (!_stopped) {
      final was = await kept(db);
      final owed = await _owed();
      if (was != null && historyCopyOver(was.step)) {
        stage.value = was;
        if (owed == null) return;
        // every record is in: the tally goes before the bookkeeping does,
        // so a copy the phone ended still goes from here
        if (!await _deliver(owed)) return;
        continue;
      }
      final HistoryHello h;
      try {
        h = await wire.hello();
      } on HistoryUnreached {
        await _waitPhone();
        continue;
      } on HistoryRefused {
        await _waitPhone();
        continue;
      }
      if (_stopped) return;
      _misses = 0;
      switch (h.why) {
        case 'making':
          stage.value = stage.value.moved(HistoryCopyStep.making);
          await _sleep.wait(retry);
          continue;
        case 'ended' || 'none' || 'done':
          // stopped there, or over there and lost here: nothing comes
          return _end(const HistoryCopyStage(HistoryCopyStep.ended));
      }
      if (await _take(h)) return;
    }
  }

  // the tally to the phone. false when the copy is over here (held, or
  // ended), true when the phone made the copy again and it is taken again
  Future<bool> _deliver(Uint8List tally) async {
    while (!_stopped) {
      final String? why;
      try {
        why = await wire.tally(tally);
      } on HistoryUnreached {
        await _waitPhone(show: false);
        continue;
      } on HistoryRefused {
        await _waitPhone(show: false);
        continue;
      }
      _misses = 0;
      final imp = await HistoryImport.reopen(db: db, mediaDir: mediaDir);
      switch (why) {
        case null || 'done':
          await imp?.clear();
          await db.delete('signal_meta', where: 'k = ?', whereArgs: [_kOwed]);
          await forgetKey();
          return false;
        case 'ended':
          imp?.close();
          await db.delete('signal_meta', where: 'k = ?', whereArgs: [_kOwed]);
          await _end(const HistoryCopyStage(HistoryCopyStep.ended));
          return false;
      }
      // the phone's app went and came back with a new stream: this tally is
      // of no use to it. the copy goes again, and what is here is merged
      imp?.close();
      await db.delete(
        'signal_meta',
        where: 'k IN (?, ?)',
        whereArgs: [_kOwed, kHistoryCopyMeta],
      );
      stage.value = const HistoryCopyStage(HistoryCopyStep.making);
      return true;
    }
    return false;
  }

  // one generation's copy. true when this run is over, false when the phone
  // made it again and the hello comes first
  Future<bool> _take(HistoryHello h) async {
    final HistoryImport imp;
    try {
      imp = _imp = await HistoryImport.open(
        db: db,
        mediaDir: mediaDir,
        keyHex: h.keyHex,
        bindHex: bindHex,
        idHex: h.id,
        identityHex: identityHex,
      );
    } on HistoryRefused {
      await _end(const HistoryCopyStage(HistoryCopyStep.failed));
      return true;
    }
    void show(HistoryCopyStep step) {
      final head = imp.head;
      stage.value = HistoryCopyStage(
        step,
        bytes: head?.bytes ?? 0,
        records: head?.records ?? 0,
        at: imp.next,
      );
    }

    show(HistoryCopyStep.copying);
    while (!imp.done) {
      if (_stopped) return true;
      final ({Uint8List? rec, String? why}) a;
      try {
        a = await wire.record(h.gen, imp.next);
      } on HistoryUnreached {
        await _waitPhone();
        continue;
      } on HistoryRefused {
        await _waitPhone();
        continue;
      }
      if (_stopped) return true;
      _misses = 0;
      final rec = a.rec;
      if (rec == null) {
        if (a.why == 'ended') {
          await _end(const HistoryCopyStage(HistoryCopyStep.ended));
          return true;
        }
        // the phone's app went and came back: a new copy, a new hello
        imp.close();
        _imp = null;
        return false;
      }
      try {
        await imp.take(rec);
      } on HistoryRefused catch (e) {
        if (e.forGood) {
          await _end(const HistoryCopyStage(HistoryCopyStep.failed));
          return true;
        }
        if (e.paused) {
          show(HistoryCopyStep.paused);
          await _sleep.wait(pause);
          imp.resume();
        }
        continue;
      }
      show(HistoryCopyStep.copying);
    }
    final res = await imp.finish();
    await landed(await imp.lists());
    final head = imp.head;
    imp.close();
    _imp = null;
    // the result is kept to be seen, and the tally owed: the bookkeeping
    // stays until the phone holds it
    await db.insert('signal_meta', {
      'k': _kOwed,
      'v': base64Encode(res.tally),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _keep(
      HistoryCopyStage(
        res.whole ? HistoryCopyStep.whole : HistoryCopyStep.gaps,
        bytes: head?.bytes ?? 0,
        records: head?.records ?? 0,
        at: head?.records ?? 0,
        // "no history": chats came, no message or file in any
        rowsOnly:
            head != null &&
            head.chats.isNotEmpty &&
            head.chats.every((c) => c.messages == 0 && c.media == 0),
        gaps: [
          for (final g in res.gaps)
            if (g.chat.id.isNotEmpty) g,
        ],
        left: [
          for (final l in res.left)
            if (l.chat.id.isNotEmpty) l,
        ],
        leftChats: res.leftChats,
        stays: res.stays,
      ),
    );
    return false;
  }

  /// the app goes (or a test kills it): the place stays as stored
  void stop() {
    _stopped = true;
    _sleep.wake();
    _imp?.close();
    _imp = null;
  }
}
