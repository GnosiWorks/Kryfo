// SPDX-License-Identifier: GPL-3.0-or-later
// repro/shim-source.sh, the shim's source tarball for the release page, on a
// small made-up tree: it holds the crate, every crate its Cargo.lock names
// (build-only ones too) and the source config that builds it offline, the
// same bytes every time, and it refuses a vendor dir that does not fit
@TestOn('linux')
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

final _script = File('../repro/shim-source.sh').absolute.path;

// name, version, licence, linked into the library
const _crates = [
  ('cc', '1.2.0', 'MIT OR Apache-2.0', false),
  ('libsignal-protocol', '0.1.0', 'AGPL-3.0-only', true),
  ('wasip2', '1.0.1', 'Apache-2.0 OR MIT', false),
  ('zeroize', '1.9.1', 'Apache-2.0 OR MIT', true),
];
const _name = 'libkryfo_signal-1.2.3-source';

late Directory _root;

Directory get _crate => Directory('${_root.path}/mobile/native/kryfo_signal');
String get _vendor => '${_crate.path}/target/vendor';

void _write(String path, String text) =>
    (File(path)..createSync(recursive: true)).writeAsStringSync(text);

String _lockText() => [
  '[[package]]\nname = "kryfo_signal"\nversion = "0.1.0"\n',
  for (final (n, v, _, _) in _crates)
    '[[package]]\nname = "$n"\nversion = "$v"\nsource = '
        '"${n.startsWith('libsignal') ? 'git+https://github.com/signalapp/libsignal?tag=v0.99.4#abc' : 'registry+https://github.com/rust-lang/crates.io-index'}"\n',
].join('\n');

void _tree() {
  _write(
    '${_root.path}/mobile/pubspec.yaml',
    'name: kryfo\nversion: 1.2.3+40\n',
  );
  _write('${_crate.path}/Cargo.lock', _lockText());
  _write(
    '${_crate.path}/rust-toolchain.toml',
    '[toolchain]\nchannel = "1.97.0"\n',
  );
  _write('${_crate.path}/src/lib.rs', '// the shim\n');
  _write('${_crate.path}/target/junk', 'not source\n');
  Process.runSync('git', ['init', '-q'], workingDirectory: _crate.path);
  Process.runSync('git', [
    'add',
    'Cargo.lock',
    'rust-toolchain.toml',
    'src',
  ], workingDirectory: _crate.path);
  for (final (n, v, l, _) in _crates) {
    _write('$_vendor/$n-$v/Cargo.toml', 'name = "$n"\nlicense = "$l"\n');
    _write('$_vendor/$n-$v/src/lib.rs', '// $n\n');
    _write('$_vendor/$n-$v/.cargo-checksum.json', '{"files":{}}');
  }
  // a build-only crate with its own licence file; wasip2 ships none
  _write('$_vendor/cc-1.2.0/LICENSE-MIT', 'cc own MIT text\n');
  _write(
    '${_crate.path}/target/vendor.toml',
    '[source.crates-io]\nreplace-with = "vendored-sources"\n\n'
        '[source.vendored-sources]\ndirectory = "${_crate.path}/target/vendor"\n',
  );
  final lock = sha256.convert(
    File('${_crate.path}/Cargo.lock').readAsBytesSync(),
  );
  _write(
    '${_root.path}/mobile/assets/licences/rust.json',
    jsonEncode({
      'lock': '$lock',
      'libsignal': 'v0.99.4',
      'crates': [
        for (final (n, v, l, linked) in _crates)
          if (linked)
            {
              'name': n,
              'version': v,
              'licence': l,
              'texts': [n == 'zeroize' ? 0 : 1],
            },
      ],
      'licences': [
        {'id': 'MIT', 'text': 'MIT text'},
        {'id': 'AGPL-3.0-only', 'text': 'AGPL text'},
      ],
    }),
  );
}

ProcessResult _run(String out) {
  Directory(out).createSync(recursive: true);
  return Process.runSync('bash', [_script, _vendor, out]);
}

String _tarball(String out) => '$out/$_name.tar.gz';

List<String> _entries(String tarball) =>
    (Process.runSync('tar', ['-tzf', tarball]).stdout as String).trim().split(
      '\n',
    );

String _file(String tarball, String path) =>
    Process.runSync('tar', ['-xzOf', tarball, '$_name/$path']).stdout as String;

void main() {
  setUp(() => _root = Directory.systemTemp.createTempSync('shimsrc'));
  tearDown(() => _root.deleteSync(recursive: true));

  test('holds the crate and every crate the lock names, the same bytes '
      'twice', () {
    _tree();
    final a = _run('${_root.path}/a');
    expect(a.exitCode, 0, reason: '${a.stderr}');
    final b = _run('${_root.path}/b');
    expect(b.exitCode, 0, reason: '${b.stderr}');
    final ta = _tarball('${_root.path}/a');
    expect(
      File(ta).readAsBytesSync(),
      File(_tarball('${_root.path}/b')).readAsBytesSync(),
    );
    final e = _entries(ta);
    expect(e, contains('$_name/kryfo_signal/src/lib.rs'));
    expect(e, contains('$_name/kryfo_signal/Cargo.lock'));
    for (final (n, v, _, _) in _crates) {
      expect(e, contains('$_name/vendor/$n-$v/.cargo-checksum.json'));
    }
    expect(e, contains('$_name/LICENCES'));
    // not source
    expect(
      e.where((p) => p.contains('target/') || p.contains('junk')),
      isEmpty,
    );
  });

  test('points cargo at its vendor dir and says how to build offline', () {
    _tree();
    expect(_run('${_root.path}/a').exitCode, 0);
    final ta = _tarball('${_root.path}/a');
    final config = _file(ta, '.cargo/config.toml');
    expect(config, contains('directory = "vendor"\n'));
    expect(config, contains('replace-with = "vendored-sources"'));
    expect(config, isNot(contains(_root.path)));
    final readme = _file(ta, 'README');
    expect(readme, contains('complete source of libkryfo_signal.so'));
    expect(readme, contains('4 of them'));
    expect(readme, contains('the 2 the library links'));
    expect(readme, contains('cargo build --offline --release'));
    expect(readme, contains('rust 1.97.0'));
    expect(readme, contains('libsignal-protocol-0.1.0'));
  });

  test('names the licence of every crate, the build-only ones too', () {
    _tree();
    expect(_run('${_root.path}/a').exitCode, 0);
    final l = _file(_tarball('${_root.path}/a'), 'LICENCES');
    for (final (n, v, lic, _) in _crates) {
      expect(l, contains('$n-$v  $lic'));
    }
    // the list's texts for the linked ones, the crate's own file for cc, and
    // for wasip2, which ships none, a text its expression allows
    expect(l, contains('AGPL text'));
    expect(l, contains('cc own MIT text'));
    expect(l, contains('wasip2-1.0.1, zeroize-1.9.1\n\nMIT text'));
  });

  test('refuses a list made from another Cargo.lock', () {
    _tree();
    _write('${_crate.path}/Cargo.lock', '${_lockText()}\n# changed\n');
    final r = _run('${_root.path}/a');
    expect(r.exitCode, isNot(0));
    expect('${r.stderr}', contains('Cargo.lock'));
  });

  test('refuses a vendor dir without a crate the lock names', () {
    _tree();
    Directory('$_vendor/cc-1.2.0').deleteSync(recursive: true);
    final r = _run('${_root.path}/a');
    expect(r.exitCode, isNot(0));
    expect('${r.stderr}', contains('cc-1.2.0'));
  });

  test('refuses a crate without its checksums', () {
    _tree();
    File('$_vendor/zeroize-1.9.1/.cargo-checksum.json').deleteSync();
    final r = _run('${_root.path}/a');
    expect(r.exitCode, isNot(0));
    expect('${r.stderr}', contains('zeroize-1.9.1'));
  });

  test('refuses a crate the lock does not name', () {
    _tree();
    _write('$_vendor/windows-sys-0.59.0/Cargo.toml', 'license = "MIT"\n');
    final r = _run('${_root.path}/a');
    expect(r.exitCode, isNot(0));
    expect('${r.stderr}', contains('windows-sys-0.59.0'));
  });
}
