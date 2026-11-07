// SPDX-License-Identifier: GPL-3.0-or-later
// the engine's opus: a placed note encoded as it goes out, and the wave of
// one that came. each call runs off the main isolate, one file at a time
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'dlog.dart';
import 'engine_strings.dart';
import 'shred.dart' show shredFile;
import 'voice_format.dart';
import 'desktop/desktop_mode.dart' show withNativeFiles;
import 'native_libs.dart';

typedef _TwoC = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _PeaksC = Pointer<Utf8> Function(Pointer<Utf8>, Int32);
typedef _PeaksD = Pointer<Utf8> Function(Pointer<Utf8>, int);

DynamicLibrary _lib() => haloLibrary();

String _two(String symbol, String a, String b) {
  final pa = a.toNativeUtf8(), pb = b.toNativeUtf8();
  try {
    return engineTake(_lib().lookupFunction<_TwoC, _TwoC>(symbol)(pa, pb));
  } finally {
    malloc.free(pa);
    malloc.free(pb);
  }
}

// windows has no file in memory to hand the engine by path: the bytes go
// over instead, read and written through the app's own seal
bool get _bytesOnly => Platform.isWindows;

typedef _BytesC =
    Pointer<Utf8> Function(
      Pointer<Uint8>,
      Int64,
      Pointer<Pointer<Uint8>>,
      Pointer<Int64>,
    );
typedef _OggBytesC =
    Pointer<Utf8> Function(
      Pointer<Utf8>,
      Pointer<Uint8>,
      Int64,
      Pointer<Pointer<Uint8>>,
      Pointer<Int64>,
    );
typedef _OggBytesD =
    Pointer<Utf8> Function(
      Pointer<Utf8>,
      Pointer<Uint8>,
      int,
      Pointer<Pointer<Uint8>>,
      Pointer<Int64>,
    );
typedef _BytesD =
    Pointer<Utf8> Function(
      Pointer<Uint8>,
      int,
      Pointer<Pointer<Uint8>>,
      Pointer<Int64>,
    );
typedef _PeaksBytesC = Pointer<Utf8> Function(Pointer<Uint8>, Int64, Int32);
typedef _PeaksBytesD = Pointer<Utf8> Function(Pointer<Uint8>, int, int);
typedef _FreeBytesC = Void Function(Pointer<Uint8>, Int64);
typedef _FreeBytesD = void Function(Pointer<Uint8>, int);

// [input] in C memory for [call], zeroed after
T _withIn<T>(Uint8List input, T Function(Pointer<Uint8>, int) call) {
  final n = input.length;
  final p = calloc<Uint8>(n == 0 ? 1 : n);
  try {
    p.asTypedList(n).setAll(0, input);
    return call(p, n);
  } finally {
    p.asTypedList(n).fillRange(0, n, 0);
    calloc.free(p);
  }
}

// out pointers for [call], and on "ok" the bytes the engine made there,
// copied, then zeroed and freed on its side
(String, Uint8List?) _withOut(
  String Function(Pointer<Pointer<Uint8>> out, Pointer<Int64> outLen) call,
) {
  final out = calloc<Pointer<Uint8>>();
  final outLen = calloc<Int64>();
  try {
    final said = call(out, outLen);
    if (out.value == nullptr) return (said, null);
    final len = outLen.value;
    // a length the engine never makes is said, never read
    if (len < 0 || len >= 1 << 31) throw StateError('voice: bad length');
    final b = Uint8List.fromList(out.value.asTypedList(len));
    _lib().lookupFunction<_FreeBytesC, _FreeBytesD>('HaloFreeBytes')(
      out.value,
      len,
    );
    if (said.startsWith('ok ')) return (said, b);
    b.fillRange(0, b.length, 0);
    return (said, null);
  } finally {
    calloc.free(out);
    calloc.free(outLen);
  }
}

(String, Uint8List?) _oggBytes(Uint8List input, String stopKey) =>
    _withOut((out, outLen) {
      final key = stopKey.toNativeUtf8();
      try {
        return _withIn(
          input,
          (p, n) => engineTake(
            _lib().lookupFunction<_OggBytesC, _OggBytesD>('HaloVoiceOggBytes')(
              key,
              p,
              n,
              out,
              outLen,
            ),
          ),
        );
      } finally {
        malloc.free(key);
      }
    });

(String, Uint8List?) _wavBytes(Uint8List input) => _withOut(
  (out, outLen) => _withIn(
    input,
    (p, n) => engineTake(
      _lib().lookupFunction<_BytesC, _BytesD>('HaloVoiceWavBytes')(
        p,
        n,
        out,
        outLen,
      ),
    ),
  ),
);

// [from] read through the seal, the engine's bytes written through it to
// [to]. the plain copies are zeroed once used
Future<String> _bytesTwo(
  (String, Uint8List?) Function(Uint8List input) call,
  String from,
  String to,
) async {
  final input = await File(from).readAsBytes();
  final (said, b) = await Isolate.run(() {
    final r = call(input);
    input.fillRange(0, input.length, 0);
    return r;
  });
  input.fillRange(0, input.length, 0);
  if (b == null) return said;
  try {
    await File(to).writeAsBytes(b, flush: true);
  } finally {
    b.fillRange(0, b.length, 0);
  }
  return said;
}

// only strings cross to the isolate. the engine reads and writes by path:
// on desktop a sealed note reaches it through memory
Future<String> _engineOgg(
  String wav,
  String ogg, [
  void Function(String engineOut)? out,
]) => _bytesOnly
    ? (() {
        out?.call(ogg);
        return _bytesTwo((b) => _oggBytes(b, ogg), wav, ogg);
      })()
    : withNativeFiles([wav], [ogg], (i, o) {
        out?.call(o[0]);
        return Isolate.run(() => _two('HaloVoiceOgg', i[0], o[0]));
      }, ok: (r) => r.startsWith('ok '));

Future<String> _engineWav(String ogg, String wav) => _bytesOnly
    ? _bytesTwo(_wavBytes, ogg, wav)
    : withNativeFiles(
        [ogg],
        [wav],
        (i, o) => Isolate.run(() => _two('HaloVoiceWav', i[0], o[0])),
        ok: (r) => r.startsWith('ok '),
      );

/// stands in for the engine in tests: what HaloVoiceOgg would answer
@visibleForTesting
Future<String> Function(String wav, String ogg)? voiceOggForTest;

/// stands in for the engine in tests: what HaloVoicePeaks would answer
@visibleForTesting
String Function(String ogg, int bars)? voicePeaksForTest;

// one encode at a time: two long notes never take two cores at once
Future<void> _turn = Future.value();

/// a test stands in for the engine's wave on this isolate
bool get oggPeaksStandIn => voicePeaksForTest != null;

/// stands in for the engine's stop in tests: the ogg paths asked to stop
@visibleForTesting
void Function(String ogg)? voiceStopForTest;

typedef _StopC = Void Function(Pointer<Utf8>);
typedef _StopD = void Function(Pointer<Utf8>);

void _engineStop(String ogg) {
  final hook = voiceStopForTest;
  if (hook != null) return hook(ogg);
  final p = ogg.toNativeUtf8();
  try {
    _lib().lookupFunction<_StopC, _StopD>('HaloVoiceStop')(p);
  } catch (e) {
    dlog('voice: no stop (${e.runtimeType})');
  } finally {
    malloc.free(p);
  }
}

/// the wav at [wav] as ogg opus at [ogg]: how long it plays, or null with
/// nothing at [ogg]. once [stop] says so, one waiting its turn never
/// starts and one under way stops where it is
Future<int?> encodeVoiceOgg(String wav, String ogg, {bool Function()? stop}) =>
    Zone.root.run(() => _encodeInTurn(wav, ogg, stop));

// the turn is kept in the root zone, so a caller's zone that goes away
// never holds the next one
Future<int?> _encodeInTurn(String wav, String ogg, bool Function()? stop) {
  final before = _turn;
  final run = before.then((_) async {
    if (stop?.call() ?? false) return null;
    var stopped = false;
    // the path the engine writes to, which a stop names: in memory on desktop
    var engineOut = ogg;
    final watch = stop == null
        ? null
        : Timer.periodic(const Duration(milliseconds: 50), (_) {
            if (stopped || !stop()) return;
            stopped = true;
            _engineStop(engineOut);
          });
    try {
      final hook = voiceOggForTest;
      final said = hook != null
          ? await hook(wav, ogg)
          : await _engineOgg(wav, ogg, (o) => engineOut = o);
      final m = RegExp(r'^ok (\d+) (\d+)$').firstMatch(said);
      if (m != null) return int.parse(m.group(1)!);
      dlog('voice: not opus ($said)');
    } catch (e) {
      dlog('voice: not opus (${e.runtimeType})');
    } finally {
      watch?.cancel();
    }
    await shredFile(ogg);
    return null;
  });
  _turn = run.then((_) {}, onError: (_) {});
  return run;
}

/// the ogg opus bytes [ogg] as a 16 khz wav in memory, by the engine's own
/// decoder off the main isolate; null when they are not one. the copy the
/// isolate gets is zeroed there, the caller's stays the caller's to zero
Future<Uint8List?> wavBytesOfOgg(Uint8List ogg) async {
  try {
    final (said, b) = await Isolate.run(() {
      final r = _wavBytes(ogg);
      ogg.fillRange(0, ogg.length, 0);
      return r;
    });
    if (b == null) dlog('voice: not decoded ($said)');
    return b;
  } catch (e) {
    dlog('voice: not decoded (${e.runtimeType})');
    return null;
  }
}

/// the ogg opus at [ogg] as a 16 khz wav at [wav], for what reads wav
/// only. false with nothing at [wav]
Future<bool> decodeVoiceWav(String ogg, String wav) async {
  try {
    final said = await _engineWav(ogg, wav);
    if (said.startsWith('ok ')) return true;
    dlog('voice: not decoded ($said)');
  } catch (e) {
    dlog('voice: not decoded (${e.runtimeType})');
  }
  await shredFile(wav);
  return false;
}

/// the engine's answer to a wave, read
List<double>? peaksOfAnswer(String said, int bars) {
  if (!said.startsWith('{')) return null;
  try {
    final j = jsonDecode(said);
    final p = j is Map ? j['p'] : null;
    if (p is! List || p.length != bars) return null;
    return [
      for (final v in p)
        if (v is num && v.isFinite) v.toDouble().clamp(0.0, 1.0) else 0.0,
    ];
  } catch (_) {
    return null;
  }
}

/// an ogg opus note's wave in [bars] steps, on the isolate it is called
/// on: the caller keeps it off the main one
List<double>? oggPeaks(String path, int bars) {
  final hook = voicePeaksForTest;
  if (hook != null) return peaksOfAnswer(hook(path, bars), bars);
  if (_bytesOnly) {
    try {
      final input = File(path).readAsBytesSync();
      final said = _withIn(
        input,
        (p, n) => engineTake(
          _lib().lookupFunction<_PeaksBytesC, _PeaksBytesD>(
            'HaloVoicePeaksBytes',
          )(p, n, bars),
        ),
      );
      input.fillRange(0, input.length, 0);
      return peaksOfAnswer(said, bars);
    } catch (_) {
      return null;
    }
  }
  final p = path.toNativeUtf8();
  try {
    final f = _lib().lookupFunction<_PeaksC, _PeaksD>('HaloVoicePeaks');
    return peaksOfAnswer(engineTake(f(p, bars)), bars);
  } catch (_) {
    return null;
  } finally {
    malloc.free(p);
  }
}

/// a voice note as it goes: (path, name on the wire). opus when [opus]
/// and the encode works, else the wav as it is. the wav stays where it
/// is either way: the caller lets it go once nothing plays it
/// [stop]: the lock came, see [encodeVoiceOgg]
Future<(String, String)> voiceForWire(
  String wav, {
  required bool opus,
  bool Function()? stop,
}) async {
  if (!opus) return (wav, kVoiceWav);
  final ogg = oggPathOf(wav);
  if (ogg == wav) return (wav, kVoiceWav);
  final ms = await encodeVoiceOgg(wav, ogg, stop: stop);
  return ms == null ? (wav, kVoiceWav) : (ogg, kVoiceOgg);
}
