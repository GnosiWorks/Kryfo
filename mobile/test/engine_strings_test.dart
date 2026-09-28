// SPDX-License-Identifier: GPL-3.0-or-later
// every string the engine returns goes back through its free once it is
// copied, and one that can hold a key or plaintext is zeroed first. the
// bindings are read off the source: none makes a dart string of an engine
// string on its own.
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/engine_strings.dart';

// the source without its comments
String _code(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .map((l) => l.replaceFirst(RegExp(r'//.*'), ''))
    .join('\n');

void main() {
  // what came back, and whether its bytes were zero when it did
  late List<int> freed;
  late Map<int, int> sizes;
  late Map<int, bool> zeroed;

  setUp(() {
    freed = [];
    sizes = {};
    zeroed = {};
    engineFreeForTest = (p) {
      final n = sizes[p.address];
      if (n != null) {
        zeroed[p.address] = p.cast<Uint8>().asTypedList(n).every((b) => b == 0);
      }
      freed.add(p.address);
      malloc.free(p);
    };
  });
  tearDown(() => engineFreeForTest = null);

  Pointer<Utf8> native(String s) {
    final p = s.toNativeUtf8();
    sizes[p.address] = p.length;
    return p;
  }

  test('a string is copied, then freed once', () {
    final p = native('hello');
    expect(engineTake(p), 'hello');
    expect(freed, [p.address]);
    expect(zeroed[p.address], isFalse);
  });

  test('a secret is zeroed before it is freed', () {
    final p = native('0123456789abcdef');
    expect(engineTakeSecret(p), '0123456789abcdef');
    expect(freed, [p.address]);
    expect(zeroed[p.address], isTrue);
  });

  test('nothing back, nothing freed', () {
    expect(engineTake(nullptr), '');
    expect(engineTakeSecret(nullptr), '');
    expect(freed, isEmpty);
  });

  test('a string that cannot be read is freed all the same', () {
    final p = malloc<Uint8>(3);
    p.asTypedList(3).setAll(0, [0xff, 0xfe, 0]);
    sizes[p.address] = 2;
    expect(() => engineTakeSecret(p.cast<Utf8>()), throwsFormatException);
    expect(freed, [p.address]);
    expect(zeroed[p.address], isTrue);
  });

  test('every binding hands its string to the take helpers', () {
    final bindings = [
      'lib/main.dart',
      'lib/lock_state.dart',
      'lib/backup.dart',
      'lib/tools/age_ffi.dart',
    ];
    for (final f in bindings) {
      expect(_code(f), isNot(contains('.toDartString(')), reason: f);
      expect(_code(f), contains('engineTake'), reason: f);
    }
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('engine_strings.dart')) continue;
      expect(_code(f.path), isNot(contains('.toDartString(')), reason: f.path);
    }
  });

  test('what can hold a key or plaintext is zeroed', () {
    final secret = {
      'lib/main.dart': [
        'myEdPrivkey() => engineTakeSecret(',
        'myXPrivkey() => engineTakeSecret(',
        'engineTakeSecret(_decryptBackup(',
        'parseRelayPoll(engineTakeSecret(_nostrPoll()))',
        'engineTakeSecret(_vaultKeys())',
        'engineTakeSecret(_vaultOpenMany(',
        'engineTakeSecret(_decryptFrom(',
        "engineTakeSecret(\n      _lib.lookupFunction<CStrFn, CStrFnDart>('HaloRoomKeygen')",
        'final s = engineTakeSecret(p);',
      ],
      'lib/lock_state.dart': ['_take(Pointer<Utf8> p) => engineTakeSecret(p)'],
      'lib/backup.dart': [
        'return engineTakeSecret(fn(p1, p2));',
        'final r = engineTakeSecret(fn(p1, ps));',
      ],
      'lib/tools/age_ffi.dart': ["engineTakeSecret(\n  _lib().lookupFunction"],
    };
    for (final e in secret.entries) {
      final src = _code(e.key);
      for (final need in e.value) {
        expect(src, contains(need), reason: '${e.key}: $need');
      }
    }
  });
}
