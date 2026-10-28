// SPDX-License-Identifier: GPL-3.0-or-later
// share_plus on linux turns text into a mailto link for the mail client.
// no call to it may be reachable on desktop: each sits under canShareOut,
// and the two file shares stop at their top
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/desktop/desktop_mode.dart';
import 'package:kryfo/open_file.dart';
import 'package:kryfo/tools/tools_bridge.dart';

List<File> _dart() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// the lines of [src] that call share_plus without canShareOut in the
/// twelve lines before them
List<int> unguardedShares(String src) {
  final lines = src.split('\n');
  final out = <int>[];
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (!RegExp(r'\bSharePlus\.instance\b|\bShare\.share').hasMatch(l)) {
      continue;
    }
    final from = i < 12 ? 0 : i - 12;
    final before = lines.sublist(from, i + 1).join('\n');
    if (!before.contains('canShareOut')) out.add(i + 1);
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every share_plus call is behind canShareOut', () {
    var calls = 0;
    final bad = <String>[];
    for (final f in _dart()) {
      final src = f.readAsStringSync();
      calls += RegExp(r'\bSharePlus\.instance\b').allMatches(src).length;
      for (final n in unguardedShares(src)) {
        bad.add('${f.path}:$n');
      }
    }
    expect(calls, greaterThanOrEqualTo(2));
    expect(bad, isEmpty);
  });

  test('the scan finds a call left open', () {
    const src = '''
void a() {
  SharePlus.instance.share(ShareParams(text: uri));
}
''';
    expect(unguardedShares(src), [2]);
    expect(
      unguardedShares('if (canShareOut)\n  SharePlus.instance.share(x);'),
      isEmpty,
    );
  });

  test('the file shares stop at once on desktop', () async {
    onDesktop = true;
    addTearDown(() => onDesktop = false);
    expect(await shareFileOut('/nonexistent/x.txt'), ShareEnd.failed);
    expect(
      await ToolsBridge.instance.shareOut('/nonexistent/x.png', 'image/png'),
      ShareEnd.failed,
    );
    expect(canShareOut, isFalse);
  });

  test('the phone keeps its share sheet', () {
    expect(onDesktop, isFalse);
    expect(canShareOut, isTrue);
  });
}
