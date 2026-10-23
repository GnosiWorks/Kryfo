// SPDX-License-Identifier: GPL-3.0-or-later
// dart side of libkryfo_voice (engine/voice/native). a run has an isolate
// of its own: the model loads there, each segment comes back over a port as
// whisper decodes it, and a cancel is one native int both sides can see.
// the int is freed only once that isolate has exited, so a late cancel
// never writes to freed memory.

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// the abi these bindings were written for, as kryfo_voice.h numbers it
const kVoiceAbi = 1;

/// what a run failed with, as kryfo_voice.h numbers it
class VoiceError implements Exception {
  const VoiceError(this.code);
  final int code;

  static const args = 1;
  static const model = 2;
  static const audio = 3;
  static const run = 4;
  static const cancelled = 5;
  // the library did not load in the run's isolate, or the isolate died
  static const library = 90;

  @override
  String toString() => 'VoiceError($code)';
}

class VoiceSegment {
  const VoiceSegment(this.index, this.start, this.end, this.text);
  final int index;
  final Duration start;
  final Duration end;
  final String text;
}

class VoiceResult {
  const VoiceResult(this.lang, this.segments);
  // the whisper language code used, detected unless one was asked for
  final String lang;
  final List<VoiceSegment> segments;

  String get text => segments.map((s) => s.text).join().trim();
}

/// interleaved 16-bit pcm
class VoiceAudio {
  const VoiceAudio(this.pcm, this.rate, this.channels);
  final Int16List pcm;
  final int rate;
  final int channels;

  int get frames => channels < 1 ? 0 : pcm.length ~/ channels;
}

typedef _AbiC = Int32 Function();
typedef _AbiD = int Function();
typedef _OpenC = Int32 Function(Pointer<Utf8>, Pointer<Pointer<Void>>);
typedef _OpenD = int Function(Pointer<Utf8>, Pointer<Pointer<Void>>);
typedef _SegC =
    Void Function(Pointer<Void>, Int32, Int64, Int64, Pointer<Uint8>, Int32);
typedef _RunC =
    Int32 Function(
      Pointer<Void>,
      Pointer<Int16>,
      Int64,
      Int32,
      Int32,
      Pointer<Utf8>,
      Int32,
      Pointer<Int32>,
      Pointer<NativeFunction<_SegC>>,
      Pointer<Void>,
      Pointer<Uint8>,
    );
typedef _RunD =
    int Function(
      Pointer<Void>,
      Pointer<Int16>,
      int,
      int,
      int,
      Pointer<Utf8>,
      int,
      Pointer<Int32>,
      Pointer<NativeFunction<_SegC>>,
      Pointer<Void>,
      Pointer<Uint8>,
    );
typedef _CloseC = Void Function(Pointer<Void>);
typedef _CloseD = void Function(Pointer<Void>);

/// the library, by the path each run's isolate opens it by
class VoiceLibrary {
  const VoiceLibrary._(this.path);

  /// a library by path, unchecked, for a test of one that will not load
  @visibleForTesting
  const VoiceLibrary.unchecked(this.path);

  // null: the platform's own name for it
  final String? path;

  /// the env var the host tests name the library by
  static const envVar = 'KRYFO_VOICE_LIB';

  // where build-host.sh leaves it, from the app's directory
  static const hostBuilt =
      '../engine/voice/native/build/host/libkryfo_voice.so';

  static DynamicLibrary _load(String? path) =>
      DynamicLibrary.open(path ?? 'libkryfo_voice.so');

  /// the library at [path] or the platform's; null when it does not load
  /// or speaks another abi
  static VoiceLibrary? open([String? path]) {
    try {
      final lib = _load(path);
      final abi = lib.lookupFunction<_AbiC, _AbiD>('kv_abi')();
      return abi == kVoiceAbi ? VoiceLibrary._(path) : null;
    } on ArgumentError {
      return null;
    }
  }

  /// the library from the env var or where build-host.sh puts it; null
  /// when there is none
  static VoiceLibrary? forHostTests() {
    for (final c in [Platform.environment[envVar], hostBuilt]) {
      if (c == null || c.isEmpty || !File(c).existsSync()) continue;
      return open(File(c).absolute.path);
    }
    return null;
  }

  /// transcribes [audio] with the model at [model]. [lang] is a whisper
  /// language code, null to detect it
  VoiceRun transcribe({
    required String model,
    required VoiceAudio audio,
    String? lang,
    int threads = 4,
  }) => VoiceRun._start(path, model, audio, lang, threads);
}

class _Job {
  _Job(
    this.reply,
    this.lib,
    this.model,
    this.pcm,
    this.rate,
    this.channels,
    this.lang,
    this.threads,
    this.cancel,
  );
  final SendPort reply;
  final String? lib;
  final String model;
  final TransferableTypedData pcm;
  final int rate;
  final int channels;
  final String? lang;
  final int threads;
  // the address of the native cancel int
  final int cancel;
}

/// one transcription: segments as they come, then the result. [cancel]
/// stops it at the next point whisper checks, and no segment comes after
class VoiceRun {
  VoiceRun._start(
    String? lib,
    String model,
    VoiceAudio audio,
    String? lang,
    int threads,
  ) {
    _flag = calloc<Int32>();
    final pcm = TransferableTypedData.fromList([audio.pcm]);
    final job = _Job(
      _port.sendPort,
      lib,
      model,
      pcm,
      audio.rate,
      audio.channels,
      lang,
      threads,
      _flag!.address,
    );
    // one port for all of it: the result is in line before the exit
    _port.listen(_onMessage);
    Isolate.spawn(
      _work,
      job,
      onExit: _port.sendPort,
      onError: _port.sendPort,
      errorsAreFatal: true,
    ).catchError((Object _) {
      _end(const VoiceError(VoiceError.library));
      _exited();
      return Isolate.current;
    });
  }

  final _port = ReceivePort();
  final _segments = StreamController<VoiceSegment>();
  final _done = Completer<VoiceResult>();
  final _got = <VoiceSegment>[];
  final _finished = Completer<void>();
  Pointer<Int32>? _flag;
  bool _cancelled = false;

  Stream<VoiceSegment> get segments => _segments.stream;
  Future<VoiceResult> get done => _done.future;

  /// when the run's isolate is gone and the cpu free again, which after a
  /// cancel is a little later than [done]
  Future<void> get finished => _finished.future;

  void cancel() {
    _cancelled = true;
    final f = _flag;
    if (f != null) f.value = 1;
    _end(const VoiceError(VoiceError.cancelled));
  }

  void _onMessage(Object? m) {
    // the isolate's exit
    if (m == null) return _exited();
    if (m is! List || _done.isCompleted) return;
    if (m.length == 5 && m[0] == 0) {
      final s = VoiceSegment(
        m[1] as int,
        Duration(milliseconds: m[2] as int),
        Duration(milliseconds: m[3] as int),
        m[4] as String,
      );
      _got.add(s);
      _segments.add(s);
    } else if (m.length == 3 && m[0] == 1) {
      final rc = m[1] as int;
      _end(rc == 0 ? null : VoiceError(rc), lang: m[2] as String);
    } else {
      // an error from the isolate: [message, stack]
      _end(const VoiceError(VoiceError.library));
    }
  }

  void _end(VoiceError? err, {String lang = ''}) {
    if (_done.isCompleted) return;
    if (_cancelled) err = const VoiceError(VoiceError.cancelled);
    if (err == null) {
      _done.complete(VoiceResult(lang, List.unmodifiable(_got)));
    } else {
      _done.completeError(err);
      // nobody has to listen to the result to learn it failed
      _done.future.ignore();
    }
    _segments.close();
  }

  void _exited() {
    _end(const VoiceError(VoiceError.library));
    _port.close();
    final f = _flag;
    _flag = null;
    if (f != null) calloc.free(f);
    if (!_finished.isCompleted) _finished.complete();
  }
}

/// a run's segment bytes as text. whisper's tokens are bytes, so a segment
/// can end inside a character the next one finishes: the cut bytes wait for
/// it instead of turning into two replacement marks
@visibleForTesting
class VoiceSegmentText {
  final _out = StringBuffer();
  late final _sink = const Utf8Decoder(
    allowMalformed: true,
  ).startChunkedConversion(StringConversionSink.fromStringSink(_out));

  String add(List<int> bytes) {
    _sink.add(bytes);
    final s = _out.toString();
    _out.clear();
    return s;
  }
}

// the run's isolate: open, run, close, and say how it went
void _work(_Job j) {
  final DynamicLibrary lib;
  try {
    lib = VoiceLibrary._load(j.lib);
  } on ArgumentError {
    j.reply.send([1, VoiceError.library, '']);
    return;
  }
  final open = lib.lookupFunction<_OpenC, _OpenD>('kv_open');
  final run = lib.lookupFunction<_RunC, _RunD>('kv_run');
  final close = lib.lookupFunction<_CloseC, _CloseD>('kv_close');

  final pcm = j.pcm.materialize().asInt16List();
  final text = VoiceSegmentText();
  final onSegment = NativeCallable<_SegC>.isolateLocal((
    Pointer<Void> _,
    int index,
    int t0,
    int t1,
    Pointer<Uint8> bytes,
    int len,
  ) {
    // exactly len bytes, copied: no scan for the nul, and whisper reuses
    // the buffer
    final s = text.add(Uint8List.fromList(bytes.asTypedList(len)));
    j.reply.send([0, index, t0, t1, s]);
  });
  final arena = Arena();
  try {
    final model = j.model.toNativeUtf8(allocator: arena);
    final out = arena<Pointer<Void>>();
    final rc = open(model, out);
    if (rc != 0) {
      j.reply.send([1, rc, '']);
      return;
    }
    final m = out.value;
    try {
      final native = arena<Int16>(pcm.isEmpty ? 1 : pcm.length);
      native.asTypedList(pcm.length).setAll(0, pcm);
      final lang = j.lang == null
          ? nullptr
          : j.lang!.toNativeUtf8(allocator: arena);
      final langOut = arena<Uint8>(8);
      final rc = run(
        m,
        native,
        j.channels < 1 ? 0 : pcm.length ~/ j.channels,
        j.rate,
        j.channels,
        lang,
        j.threads,
        Pointer<Int32>.fromAddress(j.cancel),
        onSegment.nativeFunction,
        nullptr,
        langOut,
      );
      j.reply.send([1, rc, _shortString(langOut, 8)]);
    } finally {
      close(m);
    }
  } finally {
    onSegment.close();
    arena.releaseAll();
  }
}

// a nul-terminated string in a buffer of n bytes, read no further than n
String _shortString(Pointer<Uint8> p, int n) {
  final b = p.asTypedList(n);
  final end = b.indexOf(0);
  return ascii.decode(b.sublist(0, end < 0 ? n : end), allowInvalid: true);
}
