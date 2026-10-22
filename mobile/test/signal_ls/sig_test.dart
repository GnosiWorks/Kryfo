// SPDX-License-Identifier: GPL-3.0-or-later
// kryfo signatures through the bindings, against the vectors the shim's
// own tests hold to (native/kryfo_signal/testdata/sig_v1.txt), and what the
// library says it was built from
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart';

import 'shim_lib.dart';

const _crate = 'native/kryfo_signal';

const _libsignal =
    'git+https://github.com/signalapp/libsignal?tag=v0.99.4'
    '#387da3e29ac87c821aedc697aee77646a1c72fff';
const _spqr =
    'git+https://github.com/signalapp/SparsePostQuantumRatchet.git?tag=v1.5.3'
    '#fd320484dcec89004021e6fdc7481825f5f261fa';

Uint8List _hex(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
]);

LsSigContext? _context(String wire) {
  for (final c in LsSigContext.values) {
    if (c.wire == wire) return c;
  }
  return null;
}

void main() {
  final lines = File('$_crate/testdata/sig_v1.txt')
      .readAsLinesSync()
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .map((l) => l.split(' '))
      .toList();
  final keys = {
    for (final f in lines)
      if (f[0] == 'key') f[1]: _hex(f[3]),
  };

  test('the bindings and the shim share one context list', () {
    final rust = File('$_crate/src/sig.rs').readAsStringSync();
    final listed = RegExp(
      r'\("([a-z-]+)", (?:Some|None)',
    ).allMatches(rust).map((m) => m[1]).toList();
    expect(listed, [for (final c in LsSigContext.values) c.wire]);
  });

  test('every good vector holds, under its own context only', () {
    final s = shim!;
    var n = 0;
    for (final f in lines.where((f) => f[0] == 'good')) {
      final key = keys[f[2]]!;
      final c = _context(f[3])!;
      final m = _hex(f[4]);
      final sig = _hex(f[6]);
      expect(s.verifyCtx(key, c, m, sig), isTrue, reason: f[1]);
      for (final other in LsSigContext.values.where((o) => o != c)) {
        expect(s.verifyCtx(key, other, m, sig), isFalse, reason: f[1]);
      }
      n++;
    }
    expect(n, greaterThanOrEqualTo(LsSigContext.values.length));
  }, skip: needsShim);

  test('every bad vector is refused', () {
    final s = shim!;
    var n = 0;
    for (final f in lines.where((f) => f[0] == 'bad')) {
      final c = _context(f[5]);
      final key = _hex(f[4]);
      final m = _hex(f[6]);
      final sig = _hex(f[7]);
      if (c == null) {
        // a context off the list has no name in the bindings at all
        expect(f[2], 'args', reason: f[1]);
        continue;
      }
      expect(s.verifyCtx(key, c, m, sig), isFalse, reason: f[1]);
      n++;
    }
    expect(n, greaterThan(10));
  }, skip: needsShim);

  test('prekey signatures and kryfo signatures never cross', () {
    final s = shim!;
    for (final f in lines.where((f) => f[0] == 'prekey')) {
      final key = keys[f[1]]!;
      final pub = _hex(f[2]);
      final sig = _hex(f[3]);
      expect(s.verify(key, pub, sig), isTrue);
      for (final c in LsSigContext.values) {
        expect(s.verifyCtx(key, c, pub, sig), isFalse);
      }
    }
    final me = s.identityGenerate();
    final spk = s.signedPreKey(me, 1, 1000);
    final sig = s.sign(me, LsSigContext.linkProof, spk.public);
    expect(
      s.verifyCtx(me.public, LsSigContext.linkProof, spk.public, sig),
      isTrue,
    );
    expect(s.verify(me.public, spk.public, sig), isFalse);
  }, skip: needsShim);

  test(
    'sign makes what verifyCtx takes, and refuses a body out of place',
    () {
      final s = shim!;
      final me = s.identityGenerate();
      final other = s.identityGenerate();
      final body = Uint8List.fromList([...'KIN4'.codeUnits, 1, 2, 3]);
      final sig = s.sign(me, LsSigContext.invite, body);
      expect(sig, hasLength(64));
      expect(s.verifyCtx(me.public, LsSigContext.invite, body, sig), isTrue);
      expect(
        s.verifyCtx(other.public, LsSigContext.invite, body, sig),
        isFalse,
      );
      expect(s.verifyCtx(me.public, LsSigContext.hello, body, sig), isFalse);
      // an invite signature only over something that opens as an invite
      expect(
        () => s.sign(me, LsSigContext.invite, [1, 2, 3]),
        throwsA(isA<LsError>().having((e) => e.code, 'code', LsError.args)),
      );
      // the identity key in one encoding only
      final long = Uint8List.fromList([...me.public, 0]);
      expect(s.verifyCtx(long, LsSigContext.invite, body, sig), isFalse);
    },
    skip: needsShim,
  );

  test('the library names the reviewed libsignal and spqr', () {
    final info = shim!.buildInfo();
    expect(info.libsignal, _libsignal);
    expect(info.spqr, _spqr);
    final lock = File('$_crate/Cargo.lock').readAsStringSync();
    expect(lock, contains('source = "$_libsignal"'));
    expect(lock, contains('source = "$_spqr"'));
  }, skip: needsShim);
}
