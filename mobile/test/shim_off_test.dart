// SPDX-License-Identifier: GPL-3.0-or-later
// the libsignal shim stays off: no app code outside its own layer imports
// that layer or opens the library, so a later change cannot start using it
// by accident while kUseLibsignalShim is false
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/signal_session_ls.dart';

bool _inLayer(String path) =>
    path.startsWith('lib/signal_ffi/') ||
    path == 'lib/signal_session_ls.dart' ||
    path == 'lib/signal_stores_ls.dart';

bool _namesLayer(String uri) =>
    uri.contains('signal_ffi/') ||
    uri.endsWith('signal_session_ls.dart') ||
    uri.endsWith('signal_stores_ls.dart');

final _directive = RegExp(
  r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

// without comments, so a mention in one does not count
String _noComments(String src) => src
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

Iterable<File> _files(String dir, List<String> ends) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => ends.any(f.path.endsWith));

void main() {
  test('the switch is off', () {
    expect(kUseLibsignalShim, isFalse);
  });

  test('nothing outside the shim layer imports it or names the library', () {
    final found = <String>[];
    for (final f in _files('lib', ['.dart'])) {
      final path = f.path.replaceAll(r'\', '/');
      if (_inLayer(path)) continue;
      final code = _noComments(f.readAsStringSync());
      for (final m in _directive.allMatches(code)) {
        if (_namesLayer(m[1]!)) found.add('$path imports ${m[1]}');
      }
      if (RegExp(r'\bKryfoSignal\b|kryfo_signal').hasMatch(code)) {
        found.add('$path names the shim');
      }
    }
    expect(found, isEmpty);
  });

  test('the android side never loads the shim', () {
    final found = <String>[
      for (final f in _files('android/app/src', ['.kt', '.java']))
        if (_noComments(f.readAsStringSync()).contains('kryfo_signal')) f.path,
    ];
    expect(found, isEmpty);
  });
}
