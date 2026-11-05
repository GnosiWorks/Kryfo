// SPDX-License-Identifier: GPL-3.0-or-later
// the record plugin's windows side, our own: the runner's wasapi mic in
// stream mode, written by dart as it comes. the take's path is in the
// temporary folder, which windows keeps sealed under the run's key, so the
// note is sealed from its first sample and no plain audio reaches the disk.
// the pcm passes through one buffer of ours, zeroed after every write. the
// mic's own plugin (record_windows) is never called
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:record_platform_interface/record_platform_interface.dart';

import '../dlog.dart';
import '../l10n/app_localizations.dart';
import '../shred.dart' show shredFile;
import 'win_audio.dart';

/// the mic said no: why
class MicRefused implements Exception {
  const MicRefused(this.word);
  final AudioWord word;
  @override
  String toString() => 'MicRefused: ${word.name}';
}

// a second of 16 khz mono a pull at most; the rest waits for the next
const _pullBytes = 32000;

class _Take {
  _Take(this.path, this.file, this.buf, this.rate, this.channels);
  final String path;
  final int rate, channels;
  final RandomAccessFile file;
  final Pointer<Uint8> buf;
  Timer? timer;
  int pcm = 0;
  bool paused = false;
  bool gone = false;
  double level = -160;
  double top = -160;
}

/// the record plugin on windows: wav only, by path, through dart's files
class WinRecord extends RecordPlatform {
  WinRecord(this._mic, {this.every = const Duration(milliseconds: 100)});

  final MicSource? _mic;

  /// how often the mic's samples are taken and written
  final Duration every;

  final _takes = <String, _Take>{};
  final _states = <String, StreamController<RecordState>>{};

  /// why the mic last said no, for the line the user sees
  AudioWord? lastRefusal;

  /// a test sees each buffer as it is let go
  @visibleForTesting
  static void Function(Uint8List buf)? onRelease;

  StreamController<RecordState> _state(String id) =>
      _states[id] ??= StreamController<RecordState>.broadcast();

  void _say(String id, RecordState s) {
    final c = _states[id];
    if (c != null && !c.isClosed) c.add(s);
  }

  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async {
    final mic = _mic;
    final word = mic == null ? AudioWord.failed : mic.probe();
    lastRefusal = word == AudioWord.ok ? null : word;
    return word == AudioWord.ok;
  }

  @override
  Future<void> start(
    String recorderId,
    RecordConfig config, {
    required String path,
  }) async {
    final mic = _mic;
    if (mic == null) throw const MicRefused(AudioWord.failed);
    if (config.encoder != AudioEncoder.wav) {
      throw UnsupportedError('wav only here');
    }
    // one mic, one take
    if (_takes.isNotEmpty) throw StateError('the mic is in use');
    final rate = config.sampleRate, channels = config.numChannels;
    final word = mic.open(rate, channels);
    if (word != AudioWord.ok) {
      lastRefusal = word;
      throw MicRefused(word);
    }
    RandomAccessFile? f;
    try {
      // through the seal: dart's own file, never the plugin's
      f = File(path).openSync(mode: FileMode.write);
      f.writeFromSync(wavHead(rate, channels, 0));
      f.flushSync();
    } catch (_) {
      mic.close();
      try {
        f?.closeSync();
      } catch (_) {}
      rethrow;
    }
    final t = _Take(
      path,
      f,
      calloc.allocate<Uint8>(_pullBytes),
      rate,
      channels,
    );
    _takes[recorderId] = t;
    t.timer = Timer.periodic(every, (_) => _pull(t));
    _say(recorderId, RecordState.record);
  }

  // what the mic has, written and then zeroed here
  void _pull(_Take t) {
    final mic = _mic;
    if (mic == null || t.gone) return;
    final view = t.buf.asTypedList(_pullBytes);
    for (var turns = 0; turns < 8; turns++) {
      final n = mic.take(t.buf, _pullBytes);
      if (n < 0) {
        // unplugged: the take keeps what came and stops here
        t.gone = true;
        t.timer?.cancel();
        dlog('voice: the mic went away');
        break;
      }
      if (n == 0) break;
      try {
        if (!t.paused) {
          t.file.writeFromSync(view, 0, n);
          t.pcm += n;
          _level(t, view, n);
        }
      } catch (e) {
        // a full disk most likely: the take ends where it got to
        t.gone = true;
        t.timer?.cancel();
        dlog('voice: the take could not grow (${e.runtimeType})');
      } finally {
        view.fillRange(0, n, 0);
      }
      if (t.gone || n < _pullBytes) break;
    }
    if (!t.gone) {
      try {
        // sealed as it stands, so the disguise made while recording reads it
        t.file.flushSync();
      } catch (_) {}
    }
  }

  void _level(_Take t, Uint8List b, int n) {
    final s = Int16List.view(b.buffer, b.offsetInBytes, n ~/ 2);
    var peak = 0;
    for (final v in s) {
      final a = v.abs();
      if (a > peak) peak = a;
    }
    t.level = peak == 0 ? -160 : 20 * math.log(peak / 32768) / math.ln10;
    if (t.level > t.top) t.top = t.level;
  }

  // the take let go: its sizes written, the file closed, the buffer zeroed
  Future<String?> _end(String id, {bool keep = true}) async {
    final t = _takes.remove(id);
    if (t == null) return null;
    t.timer?.cancel();
    _pull(t);
    _mic?.close();
    try {
      if (keep) {
        final head = wavHead(t.rate, t.channels, t.pcm);
        t.file.setPositionSync(0);
        t.file.writeFromSync(head);
      }
      t.file.closeSync();
    } catch (e) {
      dlog('voice: the take did not close (${e.runtimeType})');
    } finally {
      final view = t.buf.asTypedList(_pullBytes);
      view.fillRange(0, _pullBytes, 0);
      onRelease?.call(view);
      calloc.free(t.buf);
    }
    _say(id, RecordState.stop);
    return t.path;
  }

  @override
  Future<String?> stop(String recorderId) => _end(recorderId);

  @override
  Future<void> cancel(String recorderId) async {
    final path = await _end(recorderId, keep: false);
    if (path != null) await shredFile(path);
  }

  @override
  Future<void> pause(String recorderId) async {
    final t = _takes[recorderId];
    if (t == null) return;
    t.paused = true;
    _say(recorderId, RecordState.pause);
  }

  @override
  Future<void> resume(String recorderId) async {
    final t = _takes[recorderId];
    if (t == null) return;
    t.paused = false;
    _say(recorderId, RecordState.record);
  }

  @override
  Future<bool> isRecording(String recorderId) async =>
      _takes.containsKey(recorderId);

  @override
  Future<bool> isPaused(String recorderId) async =>
      _takes[recorderId]?.paused ?? false;

  @override
  Future<void> dispose(String recorderId) async {
    await _end(recorderId);
    await _states.remove(recorderId)?.close();
  }

  @override
  Future<Amplitude> getAmplitude(String recorderId) async {
    final t = _takes[recorderId];
    return Amplitude(current: t?.level ?? -160, max: t?.top ?? -160);
  }

  @override
  Future<bool> isEncoderSupported(
    String recorderId,
    AudioEncoder encoder,
  ) async => encoder == AudioEncoder.wav;

  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async => [];

  // a stream of samples would leave the file's seal to every caller
  @override
  Future<Stream<Uint8List>> startStream(
    String recorderId,
    RecordConfig config,
  ) => throw UnsupportedError('recordings go to a file here');

  @override
  Stream<RecordState> onStateChanged(String recorderId) =>
      _state(recorderId).stream;
}

/// a 16-bit pcm wav head for [pcm] bytes of samples; 0 while it records
Uint8List wavHead(int rate, int channels, int pcm) {
  final b = ByteData(44);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, pcm == 0 ? 0 : 36 + pcm, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, channels, Endian.little);
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * channels * 2, Endian.little);
  b.setUint16(32, channels * 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, pcm, Endian.little);
  return b.buffer.asUint8List();
}

/// the line for a mic that did not open: windows names what to do, the
/// phone asks for its permission
String micRefusedLine(AppLocalizations l10n) {
  final r = RecordPlatform.instance;
  if (r is! WinRecord) return l10n.chatMicPermissionNeeded;
  return switch (r.lastRefusal) {
    AudioWord.blocked => l10n.desktopMicBlocked,
    AudioWord.none => l10n.desktopMicNone,
    _ => l10n.chatTheMicWouldNot,
  };
}
