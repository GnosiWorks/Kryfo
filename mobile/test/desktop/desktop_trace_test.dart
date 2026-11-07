// SPDX-License-Identifier: GPL-3.0-or-later
// with the trace on, an error nothing caught lands in trace.txt as its type
// and the app's code places, never its message, and still goes where it
// went before
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_trace.dart';

void main() {
  test('an uncaught error is traced by its type and places', () {
    final dir = Directory.systemTemp.createTempSync('trace');
    addTearDown(() => dir.deleteSync(recursive: true));
    final flutter = FlutterError.onError;
    final platform = PlatformDispatcher.instance.onError;
    final seen = <Object>[];
    FlutterError.onError = (d) => seen.add(d.exception);
    addTearDown(() {
      traceTo(null);
      FlutterError.onError = flutter;
      PlatformDispatcher.instance.onError = platform;
    });
    final file = '${dir.path}/trace.txt';
    traceTo(file);
    FlutterError.onError!(
      FlutterErrorDetails(
        exception: StateError('the words of 12 secret things'),
        stack: StackTrace.current,
      ),
    );
    PlatformDispatcher.instance.onError!(
      const FormatException('more words'),
      StackTrace.current,
    );
    final lines = File(file).readAsLinesSync();
    expect(lines.first, endsWith('start ${Platform.operatingSystem}'));
    expect(lines[1], contains('uncaught failed: StateError at'));
    expect(lines[2], contains('uncaught failed: FormatException at'));
    expect(File(file).readAsStringSync(), isNot(contains('secret')));
    expect(File(file).readAsStringSync(), isNot(contains('more words')));
    expect(seen, hasLength(1));
  });

  test('the engine log: debug, or a computer with KRYFO_TRACE=1', () {
    const on = {'KRYFO_TRACE': '1'};
    expect(engineLogWanted(debug: true, desktop: false, env: {}), isTrue);
    expect(engineLogWanted(debug: false, desktop: true, env: on), isTrue);
    expect(engineLogWanted(debug: false, desktop: true, env: {}), isFalse);
    expect(
      engineLogWanted(debug: false, desktop: true, env: {'KRYFO_TRACE': '0'}),
      isFalse,
    );
    // a phone's release never, whatever its environment says
    expect(engineLogWanted(debug: false, desktop: false, env: on), isFalse);
  });
}
