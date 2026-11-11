// SPDX-License-Identifier: GPL-3.0-or-later
// a release writes nothing to logcat: kotlin's lines go through DebugLog,
// which a debuggable build alone opens, and dart's uncaught errors are
// dropped
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/dlog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('no kotlin line reaches logcat but through DebugLog', () {
    final plain = RegExp(r'(^|[^\w.])Log\.[a-z]+\(');
    final found = <String>[];
    for (final set in ['main', 'play', 'foss']) {
      final d = Directory('android/app/src/$set');
      if (!d.existsSync()) continue;
      for (final f in d.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.kt') || f.path.endsWith('DebugLog.kt')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (plain.hasMatch(lines[i]) || lines[i].contains('util.Log.')) {
            found.add('${f.path}:${i + 1}');
          }
        }
      }
    }
    expect(found, isEmpty);
    final app = File(
      'android/app/src/main/kotlin/app/kryfo/HaloApplication.kt',
    ).readAsStringSync();
    expect(
      app,
      contains(
        'DebugLog.on = applicationInfo.flags and '
        'ApplicationInfo.FLAG_DEBUGGABLE != 0',
      ),
    );
  });

  test('a release drops what nothing caught', () {
    final flutter = FlutterError.onError;
    final engine = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = flutter;
      PlatformDispatcher.instance.onError = engine;
    });
    quietUncaught(release: false);
    expect(FlutterError.onError, same(flutter));
    quietUncaught(release: true);
    expect(FlutterError.onError, isNot(same(flutter)));
    expect(
      PlatformDispatcher.instance.onError!(StateError('x'), StackTrace.empty),
      isTrue,
    );
  });
}
