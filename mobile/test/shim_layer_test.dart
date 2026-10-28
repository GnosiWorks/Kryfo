// SPDX-License-Identifier: GPL-3.0-or-later
// the app runs its signal sessions on the libsignal shim, and only the
// signal layer opens the library: anything else that wants a key or a
// session goes through it, so there is one place that holds the rules
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart';
import 'package:kryfo/signal_session.dart';

// the files that may open the library or hold it
bool _inLayer(String path) =>
    path.startsWith('lib/signal_ffi/') || path == 'lib/signal_session.dart';

// without comments, so a mention in one does not count
String _noComments(String src) => src
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

Iterable<File> _files(String dir, List<String> ends) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => ends.any(f.path.endsWith));

final _opens = RegExp(
  r'KryfoSignal\.(shared|open|forHostTests)\b|kryfo_signal\.(so|dylib)',
);

void main() {
  test('the everyday store runs on the platform library', () {
    expect(signalSession.lib, same(KryfoSignal.shared));
  });

  test('only the signal layer opens the library', () {
    final found = <String>[];
    for (final f in _files('lib', ['.dart'])) {
      final path = f.path.replaceAll(r'\', '/');
      if (_inLayer(path)) continue;
      if (_opens.hasMatch(_noComments(f.readAsStringSync()))) {
        found.add(path);
      }
    }
    expect(found, isEmpty);
  });

  test('the scan sees an open', () {
    expect(_opens.hasMatch('final k = KryfoSignal.shared;'), isTrue);
    expect(
      _opens.hasMatch("DynamicLibrary.open('libkryfo_signal.so')"),
      isTrue,
    );
    expect(_opens.hasMatch(_noComments('// KryfoSignal.open()')), isFalse);
  });

  test('the android side never loads the shim', () {
    final found = <String>[
      for (final f in _files('android/app/src', ['.kt', '.java']))
        if (_noComments(f.readAsStringSync()).contains('kryfo_signal')) f.path,
    ];
    expect(found, isEmpty);
  });

  test('a library built from other sources is not opened', () {
    expect(
      () => lsCheckBuild((libsignal: '$kLsLibsignal ', spqr: kLsSpqr)),
      throwsA(isA<LsBuildRefused>()),
    );
    expect(
      () => lsCheckBuild((
        libsignal: kLsLibsignal,
        spqr: kLsSpqr.replaceAll('fd32', 'fd33'),
      )),
      throwsA(isA<LsBuildRefused>()),
    );
    lsCheckBuild((libsignal: kLsLibsignal, spqr: kLsSpqr));
    // the one that is open here passed it
    final info = KryfoSignal.shared.buildInfo();
    expect(info.libsignal, kLsLibsignal);
    expect(info.spqr, kLsSpqr);
  });

  test('the release check takes the library built here and refuses '
      'one built from anything else', () {
    const lib = 'native/kryfo_signal/target/release/libkryfo_signal.so';
    if (!File(lib).existsSync()) {
      markTestSkipped('libkryfo_signal not built');
      return;
    }
    final good = Process.runSync('bash', ['../repro/shim-check.sh', lib]);
    expect(good.exitCode, 0, reason: '${good.stderr}');
    final dir = Directory.systemTemp.createTempSync('shim_check');
    addTearDown(() => dir.deleteSync(recursive: true));
    // the same library with one byte of the spqr commit changed
    final bytes = File(lib).readAsBytesSync();
    final at = String.fromCharCodes(bytes).indexOf(kLsSpqr);
    expect(at, greaterThan(0));
    bytes[at + kLsSpqr.length - 1] ^= 1;
    final bad = File('${dir.path}/libkryfo_signal.so')..writeAsBytesSync(bytes);
    final refused = Process.runSync('bash', [
      '../repro/shim-check.sh',
      bad.path,
    ]);
    expect(refused.exitCode, isNot(0));
    expect('${refused.stderr}', contains('was not built from'));
  });

  test('the release check reads the pins of the commit it is told to', () {
    const lib = 'native/kryfo_signal/target/release/libkryfo_signal.so';
    if (!File(lib).existsSync()) {
      markTestSkipped('libkryfo_signal not built');
      return;
    }
    final here = Process.runSync('bash', [
      '../repro/shim-check.sh',
      '--ref',
      'HEAD',
      lib,
    ]);
    expect(here.exitCode, 0, reason: '${here.stderr}');
    // the base of this branch named no build sources in the app yet
    final before = Process.runSync('bash', [
      '../repro/shim-check.sh',
      '--ref',
      '5f3fac55c',
      lib,
    ]);
    expect(before.exitCode, isNot(0));
    expect('${before.stderr}', contains('the app does not name'));
  });
}
