// SPDX-License-Identifier: GPL-3.0-or-later
// with KRYFO_TRACE=1 in the environment the desktop start writes its steps,
// and the type and code places of a failure, caught or not, to
// <data folder>/trace.txt.
// never a message, a path or a key: those can carry what the vault holds
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

String? _file;

/// on when the environment asks for it
void startTrace(String root) {
  if (Platform.environment['KRYFO_TRACE'] != '1') return;
  traceTo(p.join(root, 'trace.txt'));
  // the runner's crash line names a thread by its id: this one is dart's
  if (Platform.isWindows) {
    try {
      final id = DynamicLibrary.open('kernel32.dll')
          .lookupFunction<Uint32 Function(), int Function()>(
            'GetCurrentThreadId',
          )();
      trace('dart thread $id');
    } catch (_) {}
  }
}

/// the trace into [file], as the environment's switch turns it on
@visibleForTesting
void traceTo(String? file) {
  _file = file;
  if (file == null) return;
  trace('start ${Platform.operatingSystem}');
  _traceUncaught();
}

// what nothing caught lands in the trace too, as its type and code places,
// and goes on where it went before
void _traceUncaught() {
  final flutter = FlutterError.onError;
  FlutterError.onError = (d) {
    traceError('uncaught', d.exception, d.stack ?? StackTrace.empty);
    flutter?.call(d);
  };
  final before = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (e, st) {
    traceError('uncaught', e, st);
    return before?.call(e, st) ?? false;
  };
}

/// whether lines are written
bool get tracing => _file != null;

/// the folder the trace is in, null while it is off
String? get traceDir => _file == null ? null : p.dirname(_file!);

void trace(String line) {
  final f = _file;
  if (f == null) return;
  try {
    File(f).writeAsStringSync(
      '${DateTime.now().toIso8601String()} $line\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {}
}

/// one job's steps, each line with the ms since it began: "[name]: [what]
/// +12ms". nothing is timed while the trace is off
class TraceSteps {
  TraceSteps(this.name) : _w = tracing ? (Stopwatch()..start()) : null;
  final String name;
  final Stopwatch? _w;

  void step(String what) {
    final w = _w;
    if (w != null) trace('$name: $what +${w.elapsedMilliseconds}ms');
  }
}

/// a message filed here, as the trace says it: its kind, whose chat it is
/// in and where it showed. never its words or who sent it
String arrivalTraceLine({
  required bool sticker,
  required bool poll,
  required bool media,
  required bool file,
  required bool words,
  required bool group,
  required bool accepted,
  required bool reading,
  required bool quiet,
}) {
  final kind = sticker
      ? 'sticker'
      : poll
      ? 'poll'
      : media
      ? 'media'
      : file
      ? 'file'
      : words
      ? 'text'
      : 'empty';
  final chat = group
      ? 'group'
      : accepted
      ? 'accepted'
      : 'request';
  final where = reading
      ? 'chat on screen'
      : quiet
      ? 'no toast'
      : 'toast';
  return 'message in: $kind, $chat, $where';
}

/// a failure as its type and the app's own code places in [st]
void traceError(String step, Object e, StackTrace st) {
  if (_file == null) return;
  final places = st
      .toString()
      .split('\n')
      .where((l) => l.contains('package:kryfo/'))
      .take(6)
      .map((l) => l.replaceAll(RegExp(r'^#\d+\s+'), '').trim())
      .join(' | ');
  trace('$step failed: ${e.runtimeType} at $places');
}
