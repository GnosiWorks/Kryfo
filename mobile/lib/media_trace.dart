// SPDX-License-Identifier: GPL-3.0-or-later
// the desktop trace's media lines (KRYFO_TRACE=1): steps, a picture's kind
// by its bytes, times and codes. never a name, a path or a key
import 'dart:io';

import 'desktop/desktop_trace.dart' show trace, tracing;
import 'image_strip.dart' show pictureHead, pictureKind;

// the steps said once per picture this run, held in memory only
final _said = <String>{};

/// a code fit for the trace: the engine's words without what could name
/// anything, at most 32 characters
String traceCode(String r) {
  final c = r
      .replaceFirst('error: ', '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .trim();
  return c.length > 32 ? c.substring(0, 32) : c;
}

/// 'media [line]', once for [path] and [step]
void mediaTraceOnce(String path, String step, String line) {
  if (!tracing) return;
  if (_said.length > 2000) _said.clear();
  if (!_said.add('$step $path')) return;
  trace('media $line');
}

/// a picture's kind by its first bytes: jpeg, png, gif, webp, heif, other
Future<String> mediaKindOf(String path) async {
  RandomAccessFile? f;
  try {
    f = await File(path).open();
    return pictureKind(await pictureHead(f)).name;
  } catch (e) {
    return 'unread ${e.runtimeType}';
  } finally {
    try {
      await f?.close();
    } catch (_) {}
  }
}

/// the picture at [path] drawn, or not: its kind, and the error's type
void traceDecode(String path, {Object? error}) {
  if (!tracing) return;
  final step = error == null ? 'decode ok' : 'decode failed';
  if (_said.length > 2000) _said.clear();
  if (!_said.add('$step $path')) return;
  mediaKindOf(path).then((kind) {
    trace(
      error == null
          ? 'media $step $kind'
          : 'media $step: $kind ${error.runtimeType}',
    );
  });
}
