// SPDX-License-Identifier: GPL-3.0-or-later
// with KRYFO_TRACE=1 in the environment the desktop start writes its steps,
// and the type and code places of a failure, caught or not, to
// <data folder>/trace.txt.
// never a message, a path or a key: those can carry what the vault holds
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

String? _file;

/// on when the environment asks for it
void startTrace(String root) {
  if (Platform.environment['KRYFO_TRACE'] != '1') return;
  traceTo(p.join(root, 'trace.txt'));
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
