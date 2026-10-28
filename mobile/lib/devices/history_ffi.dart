// SPDX-License-Identifier: GPL-3.0-or-later
// the history stream's engine side (engine/history_ffi.go): a sender on the
// phone and a receiver on the new device, each behind a handle. the
// engine seals, checks and orders every record; this side only moves bytes
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../engine_strings.dart' show engineTake, freeSecret;

/// the most one record takes on the wire: a chunk of a megabyte and its
/// framing
const kHistoryMaxRecord = (1 << 20) + 64 + 21;

typedef _SendNewC =
    Int64 Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Int32,
      Int32,
    );
typedef _SendNew =
    int Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      int,
      int,
    );
typedef _BufC = Int32 Function(Int64, Pointer<Uint8>, Int32);
typedef _Buf = int Function(int, Pointer<Uint8>, int);
typedef _MediaC = Int32 Function(Int64, Int32, Int64, Pointer<Utf8>);
typedef _Media = int Function(int, int, int, Pointer<Utf8>);
typedef _StrC = Pointer<Utf8> Function(Int64);
typedef _Str = Pointer<Utf8> Function(int);
typedef _RecordC = Int32 Function(Int64, Uint64, Pointer<Uint8>, Int32);
typedef _Record = int Function(int, int, Pointer<Uint8>, int);
typedef _BufStrC = Pointer<Utf8> Function(Int64, Pointer<Uint8>, Int32);
typedef _BufStr = Pointer<Utf8> Function(int, Pointer<Uint8>, int);
typedef _CloseC = Void Function(Int64);
typedef _Close = void Function(int);
typedef _RecvNewC = Int64 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef _RecvNew = int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef _ResumeC =
    Int64 Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Uint8>,
      Int32,
      Pointer<Uint8>,
      Int32,
    );
typedef _Resume =
    int Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
    );
typedef _TakeC = Int32 Function(Int64, Pointer<Uint8>, Int32);
typedef _Take = int Function(int, Pointer<Uint8>, int);
typedef _IntC = Int32 Function(Int64, Int32);
typedef _Int = int Function(int, int);
typedef _NextC = Int64 Function(Int64);
typedef _Next = int Function(int);
typedef _DoneC = Int32 Function(Int64);
typedef _CheckC = Pointer<Utf8> Function(Int64, Pointer<Utf8>);
typedef _Check = Pointer<Utf8> Function(int, Pointer<Utf8>);
typedef _TallyC = Int32 Function(Int64, Pointer<Utf8>, Pointer<Uint8>, Int32);
typedef _Tally = int Function(int, Pointer<Utf8>, Pointer<Uint8>, int);

DynamicLibrary _lib() => Platform.isAndroid
    ? DynamicLibrary.open('libhalo.so')
    : DynamicLibrary.process();

/// the engine refused a record. [forGood] when the stream cannot go on;
/// otherwise the same record may be sent again
class HistoryRefused implements Exception {
  const HistoryRefused(this.why, {this.forGood = false});
  final String why;
  final bool forGood;
  @override
  String toString() => 'HistoryRefused($why${forGood ? ', for good' : ''})';
}

/// one chat's share of a stream: messages, files and their bytes
class HistoryCount {
  const HistoryCount(this.messages, this.media, this.bytes);
  final int messages;
  final int media;
  final int bytes;

  factory HistoryCount.fromJson(Map<String, dynamic> j) => HistoryCount(
    (j['m'] as num).toInt(),
    (j['f'] as num).toInt(),
    (j['b'] as num).toInt(),
  );
  Map<String, int> toJson() => {'m': messages, 'f': media, 'b': bytes};

  @override
  bool operator ==(Object other) =>
      other is HistoryCount &&
      other.messages == messages &&
      other.media == media &&
      other.bytes == bytes;
  @override
  int get hashCode => Object.hash(messages, media, bytes);
  @override
  String toString() => '($messages, $media, $bytes)';
}

/// a chat whose count on the device is not what the phone sent
class HistoryGap {
  const HistoryGap(this.chat, this.want, this.got);
  final int chat;
  final HistoryCount want;
  final HistoryCount got;

  static List<HistoryGap> listOf(String json) => [
    for (final m in jsonDecode(json) as List)
      HistoryGap(
        (m['chat'] as num).toInt(),
        HistoryCount.fromJson(m['want'] as Map<String, dynamic>),
        HistoryCount.fromJson(m['got'] as Map<String, dynamic>),
      ),
  ];
}

/// what a stream holds, from its head
class HistoryHead {
  const HistoryHead({
    required this.records,
    required this.bytes,
    required this.text,
    required this.files,
    required this.skipMedia,
    required this.chats,
    this.skipped = 0,
    this.body,
    this.sig,
  });
  final int records;
  // the whole stream on the wire, to show before it starts
  final int bytes;
  final int text;
  final int files;
  final bool skipMedia;
  final List<HistoryCount> chats;
  // files the phone could not read while planning
  final int skipped;
  // the signed body and its signature, on the device's side
  final Uint8List? body;
  final Uint8List? sig;

  factory HistoryHead.fromJson(Map<String, dynamic> j) => HistoryHead(
    records: (j['records'] as num).toInt(),
    bytes: (j['bytes'] as num).toInt(),
    text: (j['text'] as num).toInt(),
    files: (j['files'] as num).toInt(),
    skipMedia: j['skip'] == true,
    chats: [
      for (final c in j['chats'] as List)
        HistoryCount.fromJson(c as Map<String, dynamic>),
    ],
    skipped: (j['skipped'] as num?)?.toInt() ?? 0,
    body: j['body'] is String ? _unhex(j['body'] as String) : null,
    sig: j['sig'] is String ? _unhex(j['sig'] as String) : null,
  );
}

Uint8List _unhex(String h) => Uint8List.fromList([
  for (var i = 0; i + 1 < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
]);

String historyHex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

/// one record's contents on the device
class HistoryEvent {
  const HistoryEvent(this.j, this.bytes);
  final Map<String, dynamic> j;
  final Uint8List bytes;

  String get kind => j['k'] as String;
  int get index => (j['i'] as num).toInt();
  int get chat => (j['chat'] as num? ?? 0).toInt();
  Map<String, dynamic>? get meta => j['meta'] as Map<String, dynamic>?;
  List<Map<String, dynamic>> get rows => [
    for (final r in (j['rows'] as List? ?? const [])) r as Map<String, dynamic>,
  ];
  List<Map<String, dynamic>> get media => [
    for (final m in (j['media'] as List? ?? const []))
      m as Map<String, dynamic>,
  ];
  int get first => (j['first'] as num? ?? 0).toInt();
  int get file => (j['file'] as num? ?? 0).toInt();
  int get offset => (j['off'] as num? ?? 0).toInt();
  bool get last => j['last'] == true;
  bool get ok => j['ok'] == true;
  bool get textDone => j['text'] == true;
  bool get planChanged => j['plan'] == true;
  HistoryHead? get head => j['head'] is Map<String, dynamic>
      ? HistoryHead.fromJson(j['head'] as Map<String, dynamic>)
      : null;
}

Pointer<Uint8> _copyIn(List<int> b) {
  final p = calloc<Uint8>(b.isEmpty ? 1 : b.length);
  p.asTypedList(b.isEmpty ? 1 : b.length).setAll(0, b);
  return p;
}

// a buffer call, grown once when the engine says how much it needs
Uint8List _readBuf(int Function(Pointer<Uint8>, int) fn, [int start = 4096]) {
  var cap = start;
  for (var round = 0; round < 2; round++) {
    final out = calloc<Uint8>(cap);
    try {
      final n = fn(out, cap);
      if (n >= 0) return Uint8List.fromList(out.asTypedList(n));
      if (n == -1) throw const HistoryRefused('engine');
      cap = -n - 1;
    } finally {
      calloc.free(out);
    }
  }
  throw const HistoryRefused('buffer');
}

String _text(Pointer<Utf8> p) {
  final s = engineTake(p);
  if (s.startsWith('error:')) throw HistoryRefused(s.substring(7));
  return s;
}

/// the phone's side: chats and messages in, then files, then the plan
class HistorySender {
  HistorySender._(this._h);
  final int _h;
  static DynamicLibrary get _l => _lib();

  /// [spool] is a new file for the sealed text, [root] the folder file
  /// names are read under
  static HistorySender open({
    required String keyHex,
    required String bindHex,
    required String identityHex,
    required String spool,
    required String root,
    bool skipMedia = false,
    int chunk = 0,
  }) {
    final fn = _l.lookupFunction<_SendNewC, _SendNew>('HaloHistSendNew');
    final k = keyHex.toNativeUtf8();
    final b = bindHex.toNativeUtf8();
    final i = identityHex.toNativeUtf8();
    final s = spool.toNativeUtf8();
    final r = root.toNativeUtf8();
    try {
      final h = fn(k, b, i, s, r, skipMedia ? 1 : 0, chunk);
      if (h <= 0) throw const HistoryRefused('sender');
      return HistorySender._(h);
    } finally {
      freeSecret(k);
      for (final x in [b, i, s, r]) {
        malloc.free(x);
      }
    }
  }

  int _bytes(_Take fn, List<int> b) {
    final p = _copyIn(b);
    try {
      return fn(_h, p, b.length);
    } finally {
      p
          .asTypedList(b.isEmpty ? 1 : b.length)
          .fillRange(0, b.isEmpty ? 1 : b.length, 0);
      calloc.free(p);
    }
  }

  /// starts a chat; its number in the stream
  int chat(Map<String, Object?> meta) {
    final n = _bytes(
      _l.lookupFunction<_TakeC, _Take>('HaloHistSendChat'),
      utf8.encode(jsonEncode(meta)),
    );
    if (n < 0) throw const HistoryRefused('chat');
    return n;
  }

  /// a message of the chat started last
  void message(Map<String, Object?> row) {
    if (_bytes(
          _l.lookupFunction<_TakeC, _Take>('HaloHistSendMessage'),
          utf8.encode(jsonEncode(row)),
        ) !=
        0) {
      throw const HistoryRefused('message');
    }
  }

  /// a file under root for [chat], [at] its time in ms
  void media(int chat, int at, String name) {
    final fn = _l.lookupFunction<_MediaC, _Media>('HaloHistSendMedia');
    final n = name.toNativeUtf8();
    try {
      if (fn(_h, chat, at, n) != 0) throw const HistoryRefused('media');
    } finally {
      malloc.free(n);
    }
  }

  /// closes the text and reads every file once, off the screen's isolate:
  /// the head's body for the identity to sign
  Future<Uint8List> plan() async {
    final h = _h;
    final hex = await Isolate.run(() {
      final fn = _lib().lookupFunction<_StrC, _Str>('HaloHistSendPlan');
      return _text(fn(h));
    });
    return _unhex(hex);
  }

  void signed(Uint8List sig) {
    if (_bytes(_l.lookupFunction<_TakeC, _Take>('HaloHistSendSigned'), sig) !=
        0) {
      throw const HistoryRefused('signature');
    }
  }

  HistoryHead head() {
    final fn = _l.lookupFunction<_StrC, _Str>('HaloHistSendHead');
    return HistoryHead.fromJson(
      jsonDecode(_text(fn(_h))) as Map<String, dynamic>,
    );
  }

  /// record [index], as often as a cut transfer asks for it
  Uint8List record(int index) {
    final fn = _l.lookupFunction<_RecordC, _Record>('HaloHistSendRecord');
    return _readBuf((out, cap) => fn(_h, index, out, cap), kHistoryMaxRecord);
  }

  /// the device's tally against what this phone sent: the chats that differ
  List<HistoryGap> checkTally(Uint8List tally) {
    final fn = _l.lookupFunction<_BufStrC, _BufStr>('HaloHistSendTally');
    final p = _copyIn(tally);
    try {
      return HistoryGap.listOf(_text(fn(_h, p, tally.length)));
    } finally {
      calloc.free(p);
    }
  }

  /// the keys forgotten, the spool removed
  void close() => _l.lookupFunction<_CloseC, _Close>('HaloHistSendClose')(_h);
}

/// the new device's side: records in, events out, its place kept with them
class HistoryReceiver {
  HistoryReceiver._(this._h);
  final int _h;
  static DynamicLibrary get _l => _lib();

  static HistoryReceiver open({
    required String keyHex,
    required String bindHex,
    required String identityHex,
  }) {
    final fn = _l.lookupFunction<_RecvNewC, _RecvNew>('HaloHistRecvNew');
    final k = keyHex.toNativeUtf8();
    final b = bindHex.toNativeUtf8();
    final i = identityHex.toNativeUtf8();
    try {
      final h = fn(k, b, i);
      if (h <= 0) throw const HistoryRefused('receiver');
      return HistoryReceiver._(h);
    } finally {
      freeSecret(k);
      malloc.free(b);
      malloc.free(i);
    }
  }

  /// taken up from a stored plan and state; null when either does not hold
  static HistoryReceiver? resume({
    required String keyHex,
    required String bindHex,
    required String identityHex,
    required Uint8List plan,
    required Uint8List state,
  }) {
    final fn = _l.lookupFunction<_ResumeC, _Resume>('HaloHistRecvResume');
    final k = keyHex.toNativeUtf8();
    final b = bindHex.toNativeUtf8();
    final i = identityHex.toNativeUtf8();
    final p = _copyIn(plan);
    final s = _copyIn(state);
    try {
      final h = fn(k, b, i, p, plan.length, s, state.length);
      return h <= 0 ? null : HistoryReceiver._(h);
    } finally {
      freeSecret(k);
      malloc.free(b);
      malloc.free(i);
      calloc.free(p);
      calloc.free(s);
    }
  }

  /// the next record, checked: what it holds. HistoryRefused when it is not
  /// the record due
  HistoryEvent take(Uint8List rec) {
    final fn = _l.lookupFunction<_TakeC, _Take>('HaloHistRecvTake');
    final p = _copyIn(rec);
    final int n;
    try {
      n = fn(_h, p, rec.length);
    } finally {
      calloc.free(p);
    }
    if (n == -1) throw const HistoryRefused('record');
    if (n < 0) throw const HistoryRefused('stream', forGood: true);
    final ev = _l.lookupFunction<_BufC, _Buf>('HaloHistRecvEvent');
    final b = _readBuf((out, cap) => ev(_h, out, cap), n);
    final jl = ByteData.sublistView(b).getUint32(0);
    final j = jsonDecode(utf8.decode(b.sublist(4, 4 + jl)));
    return HistoryEvent(j as Map<String, dynamic>, b.sublist(4 + jl));
  }

  /// the shim's verdict on the head's signature
  void trust(bool ok) {
    final fn = _l.lookupFunction<_IntC, _Int>('HaloHistRecvTrust');
    if (fn(_h, ok ? 1 : 0) != 0) {
      throw const HistoryRefused('head', forGood: true);
    }
  }

  Uint8List state() {
    final fn = _l.lookupFunction<_BufC, _Buf>('HaloHistRecvState');
    return _readBuf((out, cap) => fn(_h, out, cap), 256);
  }

  Uint8List plan() {
    final fn = _l.lookupFunction<_BufC, _Buf>('HaloHistRecvPlan');
    return _readBuf((out, cap) => fn(_h, out, cap), 1 << 16);
  }

  int get next => _l.lookupFunction<_NextC, _Next>('HaloHistRecvNext')(_h);

  /// the end record came
  bool get done =>
      _l.lookupFunction<_DoneC, _Next>('HaloHistRecvDone')(_h) == 1;

  /// what the app counted against the head: the chats that differ
  List<HistoryGap> check(List<HistoryCount> got) {
    final fn = _l.lookupFunction<_CheckC, _Check>('HaloHistRecvCheck');
    final c = jsonEncode([for (final x in got) x.toJson()]).toNativeUtf8();
    try {
      return HistoryGap.listOf(_text(fn(_h, c)));
    } finally {
      malloc.free(c);
    }
  }

  /// the same counts sealed for the phone
  Uint8List tally(List<HistoryCount> got) {
    final fn = _l.lookupFunction<_TallyC, _Tally>('HaloHistRecvTally');
    final c = jsonEncode([for (final x in got) x.toJson()]).toNativeUtf8();
    try {
      return _readBuf((out, cap) => fn(_h, c, out, cap));
    } finally {
      malloc.free(c);
    }
  }

  void close() => _l.lookupFunction<_CloseC, _Close>('HaloHistRecvClose')(_h);
}
