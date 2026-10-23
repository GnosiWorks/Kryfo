// SPDX-License-Identifier: GPL-3.0-or-later
// repro/shim-source.sh, the shim's source tarball for the release page, on a
// small made-up tree: it holds the crate and every listed crate, the same
// bytes every time, and it refuses a list or a vendor dir that does not fit
@TestOn('linux')
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

final _script = File('../repro/shim-source.sh').absolute.path;

const _crates = [
  ('libsignal-protocol', '0.1.0', 'AGPL-3.0-only'),
  ('zeroize', '1.9.1', 'Apache-2.0 OR MIT'),
];

late Directory _root;

Directory get _crate => Directory('${_root.path}/mobile/native/kryfo_signal');
String get _vendor => '${_crate.path}/target/vendor';

void _write(String path, String text) =>
    (File(path)..createSync(recursive: true)).writeAsStringSync(text);

void _tree({bool listUnvendored = false}) {
  _write(
    '${_root.path}/mobile/pubspec.yaml',
    'name: kryfo\nversion: 1.2.3+40\n',
  );
  _write('${_crate.path}/Cargo.lock', '# lock\n');
  _write('${_crate.path}/src/lib.rs', '// the shim\n');
  _write('${_crate.path}/target/junk', 'not source\n');
  Process.runSync('git', ['init', '-q'], workingDirectory: _crate.path);
  Process.runSync('git', [
    'add',
    'Cargo.lock',
    'src',
  ], workingDirectory: _crate.path);
  for (final (n, v, l) in _crates) {
    _write('$_vendor/$n-$v/Cargo.toml', 'name = "$n"\nlicense = "$l"\n');
    _write('$_vendor/$n-$v/src/lib.rs', '// $n\n');
  }
  _write('$_vendor/windows-sys-0.59.0/Cargo.toml', 'license = "MIT"\n');
  final lock = sha256.convert(
    File('${_crate.path}/Cargo.lock').readAsBytesSync(),
  );
  _write(
    '${_root.path}/mobile/assets/licences/rust.json',
    jsonEncode({
      'lock': '$lock',
      'libsignal': 'v0.99.4',
      'crates': [
        for (final (n, v, l) in _crates)
          {
            'name': n,
            'version': v,
            'licence': l,
            'texts': [0],
          },
        if (listUnvendored)
          {
            'name': 'missing',
            'version': '1.0.0',
            'licence': 'MIT',
            'texts': [0],
          },
      ],
      'licences': [
        {'id': 'MIT', 'text': 'MIT text'},
      ],
    }),
  );
}

ProcessResult _run(String out) {
  Directory(out).createSync(recursive: true);
  return Process.runSync('bash', [_script, _vendor, out]);
}

List<String> _entries(String tarball) =>
    (Process.runSync('tar', ['-tzf', tarball]).stdout as String).trim().split(
      '\n',
    );

void main() {
  setUp(() => _root = Directory.systemTemp.createTempSync('shimsrc'));
  tearDown(() => _root.deleteSync(recursive: true));

  test('holds the crate and the listed crates, the same bytes twice', () {
    _tree();
    final a = _run('${_root.path}/a');
    expect(a.exitCode, 0, reason: '${a.stderr}');
    final b = _run('${_root.path}/b');
    expect(b.exitCode, 0, reason: '${b.stderr}');
    const name = 'libkryfo_signal-1.2.3-source';
    final ta = File('${_root.path}/a/$name.tar.gz');
    expect(
      ta.readAsBytesSync(),
      File('${_root.path}/b/$name.tar.gz').readAsBytesSync(),
    );
    final e = _entries(ta.path);
    expect(e, contains('$name/kryfo_signal/src/lib.rs'));
    expect(e, contains('$name/kryfo_signal/Cargo.lock'));
    expect(e, contains('$name/vendor/zeroize-1.9.1/src/lib.rs'));
    expect(e, contains('$name/vendor/libsignal-protocol-0.1.0/Cargo.toml'));
    expect(e, contains('$name/LICENCES'));
    // not source, and not linked
    expect(
      e.where((p) => p.contains('target/') || p.contains('junk')),
      isEmpty,
    );
    expect(e.where((p) => p.contains('windows-sys')), isEmpty);
    final readme =
        Process.runSync('tar', ['-xzOf', ta.path, '$name/README']).stdout
            as String;
    expect(readme, contains('complete source of libkryfo_signal.so'));
    expect(readme, contains('2 of them'));
    expect(readme, contains('libsignal-protocol-0.1.0'));
    expect(readme, isNot(contains('the rest of the source')));
  });

  test('refuses a list made from another Cargo.lock', () {
    _tree();
    _write('${_crate.path}/Cargo.lock', '# another lock\n');
    final r = _run('${_root.path}/a');
    expect(r.exitCode, isNot(0));
    expect('${r.stderr}', contains('Cargo.lock'));
  });

  test('refuses a listed crate the vendor dir lacks', () {
    _tree(listUnvendored: true);
    final r = _run('${_root.path}/a');
    expect(r.exitCode, isNot(0));
    expect('${r.stderr}', contains('missing-1.0.0'));
  });
}
