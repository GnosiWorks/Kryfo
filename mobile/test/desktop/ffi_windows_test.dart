// SPDX-License-Identifier: GPL-3.0-or-later
// what dart's ffi does differently on windows: its malloc is com's
// CoTaskMemAlloc, so an engine string is never freed by it; long is 32 bits
// there, so no binding names it; a lookup in the process opens kryfo.exe,
// which its dacl refuses, so only a few guarded files make one. and a
// pointer no real call returns is said, never read
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/engine_strings.dart';
import 'package:kryfo/signal_ffi/kryfo_signal.dart';

import '../engine_take_scan.dart';

DynamicLibrary _noEngine() => throw ArgumentError('no halo');

List<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  group('the engine free', () {
    test('off windows, no engine falls back to the same libc free', () {
      final free = lookupEngineFree(_noEngine, windows: false);
      // libc's free takes what libc's malloc made
      free('x'.toNativeUtf8());
    });

    test('on windows, no engine is an error, never com\'s free', () {
      expect(
        () => lookupEngineFree(_noEngine, windows: true),
        throwsArgumentError,
      );
    });
  });

  group('a bad address', () {
    late List<int> freed;
    setUp(() {
      freed = [];
      engineFreeForTest = (p) => freed.add(p.address);
    });
    tearDown(() => engineFreeForTest = null);

    test('is said, never read or freed', () {
      final p = Pointer<Utf8>.fromAddress(0x40);
      expect(() => engineTake(p), throwsStateError);
      expect(() => engineTakeSecret(p), throwsStateError);
      expect(() => engineTakeSecretKey(p), throwsStateError);
      expect(freed, isEmpty);
    });

    test('a real one still goes', () {
      final p = 'ok'.toNativeUtf8();
      expect(engineTake(p), 'ok');
      expect(freed, [p.address]);
      malloc.free(p);
    });

    test('a signal output is read only where something can be', () {
      expect(lsOutputSound(1, 0), isTrue, reason: 'rust\'s empty box');
      expect(lsOutputSound(0, 0), isTrue);
      expect(lsOutputSound(0, 4), isFalse);
      expect(lsOutputSound(0x20, 4), isFalse);
      expect(lsOutputSound(0x7ff612340000, 4), isTrue);
      expect(lsOutputSound(0x7ff612340000, -1), isFalse);
      expect(lsOutputSound(0x7ff612340000, 1 << 30), isFalse);
    });

    // android tags heap pointers in the top byte (0xb4...), which dart's
    // signed int reads below zero: those are real, never bad
    const tagged = -0x4bffff882237f400; // 0xb4000077ddc80c00
    test('an android tagged pointer is a real address', () {
      expect(lowAddress(tagged), isFalse);
      expect(lowAddress(0x40), isTrue);
      expect(lowAddress(0xffff), isTrue);
      expect(lowAddress(0x10000), isFalse);
      expect(lsOutputSound(tagged, 4), isTrue);
      expect(lsOutputSound(tagged, -1), isFalse);
    });
  });

  group('windows x64 layout', () {
    test('the sizes the bindings take', () {
      // what dart's abi says for the build the pc runs
      expect(
        sizeOf<Size>(),
        8,
        reason: 'size_t, the signal shim\'s lengths',
        skip: sizeOf<IntPtr>() != 8,
      );
      expect(sizeOf<Pointer>(), sizeOf<IntPtr>());
    });

    test('no binding names long, unsigned long or wchar_t', () {
      // linux and android only: phone_seal's syscall
      const linuxOnly = {'lib/phone_seal.dart'};
      final bad = <String>[];
      final word = RegExp(r'\b(Long|UnsignedLong|WChar)\b');
      for (final f in _dartFiles()) {
        final path = f.path.replaceAll(r'\', '/');
        if (linuxOnly.contains(path)) continue;
        final src = uncomment(f.readAsStringSync());
        if (!src.contains('dart:ffi')) continue;
        for (final m in word.allMatches(src)) {
          bad.add('$path: ${m.group(0)}');
        }
      }
      expect(bad, isEmpty);
    });

    test('a lookup in the process only in the files that guard it', () {
      // each returns early off linux or android, or is ios's
      const guarded = {
        'lib/native_libs.dart',
        'lib/phone_seal.dart',
        'lib/desktop/desktop_posix.dart',
        'lib/desktop/desktop_paths.dart',
        'lib/desktop/desktop_audio.dart',
        'lib/desktop/sealed_native.dart',
        'lib/tools/age_ffi.dart',
        'lib/signal_ffi/kryfo_signal.dart',
      };
      final found = <String>{};
      for (final f in _dartFiles()) {
        final src = uncomment(f.readAsStringSync());
        if (src.contains('DynamicLibrary.process()')) {
          found.add(f.path.replaceAll(r'\', '/'));
        }
      }
      expect(found.difference(guarded), isEmpty);
    });

    test('the engine is opened by its full path on windows', () {
      final src = sourceCode('lib/native_libs.dart');
      expect(
        src,
        contains("if (Platform.isWindows) return besideExe('halo.dll')"),
      );
    });
  });
}
