// SPDX-License-Identifier: GPL-3.0-or-later
// the mic on linux for WinRecord: raw pcm from parecord (pulseaudio's or
// pipewire-pulse's), else pw-record. record_linux pipes it through ffmpeg,
// which a desktop install does not have, and lets the failure go unseen.
// each chunk is copied out and zeroed as it is taken
import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;

import '../dlog.dart';
import 'win_audio.dart';

/// a recorder program and the arguments for raw 16-bit pcm on its stdout
typedef MicCommand = (String, List<String>);

/// the recorder found on [path] (a PATH value), null when there is none
@visibleForTesting
MicCommand? micCommand(
  int rate,
  int channels, {
  String? path,
  bool Function(String file)? exists,
}) {
  final has = exists ?? (f) => File(f).existsSync();
  String? find(String name) {
    for (final dir in (path ?? Platform.environment['PATH'] ?? '').split(':')) {
      if (dir.isEmpty || !p.isAbsolute(dir)) continue;
      final f = p.join(dir, name);
      if (has(f)) return f;
    }
    return null;
  }

  final pa = find('parecord');
  if (pa != null) {
    return (
      pa,
      [
        '--raw',
        '--format=s16le',
        '--rate=$rate',
        '--channels=$channels',
        '--latency-msec=100',
      ],
    );
  }
  final pw = find('pw-record');
  if (pw != null) {
    return (
      pw,
      ['--raw', '--format=s16', '--rate=$rate', '--channels=$channels', '-'],
    );
  }
  return null;
}

/// starts a recorder program, a seam for the tests
typedef MicSpawn = Future<Process> Function(String exe, List<String> args);

Future<Process> _startRecorder(String exe, List<String> args) =>
    Process.start(exe, args);

class ProcessMic implements MicSource {
  ProcessMic({MicSpawn? spawn, MicCommand? Function(int, int)? command})
    : _spawn = spawn ?? _startRecorder,
      _command = command ?? ((r, c) => micCommand(r, c));

  /// a mic when this computer has a recorder program, else null
  static ProcessMic? here() =>
      micCommand(16000, 1) == null ? null : ProcessMic();

  final MicSpawn _spawn;
  final MicCommand? Function(int, int) _command;
  final _chunks = Queue<Uint8List>();
  int _at = 0;
  Process? _proc;
  StreamSubscription<List<int>>? _out;
  bool _open = false;
  bool _gone = false;

  @override
  AudioWord open(int rate, int channels) {
    if (_open) return AudioWord.failed;
    final cmd = _command(rate, channels);
    if (cmd == null) return AudioWord.failed;
    _open = true;
    _gone = false;
    unawaited(_start(cmd));
    return AudioWord.ok;
  }

  Future<void> _start(MicCommand cmd) async {
    final Process proc;
    try {
      proc = await _spawn(cmd.$1, cmd.$2);
    } catch (e) {
      dlog('voice: no recorder (${e.runtimeType})');
      _gone = true;
      return;
    }
    if (!_open) {
      proc.kill();
      return;
    }
    _proc = proc;
    proc.stderr.listen((_) {}, onError: (_) {});
    _out = proc.stdout.listen(
      (data) {
        final b = Uint8List.fromList(data);
        if (data is Uint8List) data.fillRange(0, data.length, 0);
        if (_open) {
          _chunks.add(b);
        } else {
          b.fillRange(0, b.length, 0);
        }
      },
      onDone: () => _gone = true,
      onError: (_) => _gone = true,
    );
  }

  @override
  int take(Pointer<Uint8> into, int cap) {
    var have = -_at;
    for (final c in _chunks) {
      have += c.length;
    }
    // whole samples only: a byte of one waits for the rest of it
    final want = (have < cap ? have : cap) & ~1;
    if (want <= 0) return _gone ? -1 : 0;
    final to = into.asTypedList(cap);
    var n = 0;
    while (n < want) {
      final c = _chunks.first;
      final left = c.length - _at;
      final k = left < want - n ? left : want - n;
      to.setRange(n, n + k, c, _at);
      c.fillRange(_at, _at + k, 0);
      n += k;
      _at += k;
      if (_at == c.length) {
        _chunks.removeFirst();
        _at = 0;
      }
    }
    return n;
  }

  @override
  void close() {
    _open = false;
    unawaited(_out?.cancel());
    _out = null;
    _proc?.kill();
    _proc = null;
    for (final c in _chunks) {
      c.fillRange(0, c.length, 0);
    }
    _chunks.clear();
    _at = 0;
  }
}
