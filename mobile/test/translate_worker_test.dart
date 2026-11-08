// SPDX-License-Identifier: GPL-3.0-or-later
// the translation worker: one that dies, or a library it cannot use, ends
// the translations waiting on it with an error, never a wait that does not
// end

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/translate/bergamot_ffi.dart';

BergamotTranslator _with(String lib) => BergamotTranslator(
  lib: lib,
  probe: (_) => true,
  config: (_, _) => 'models: []',
  installed: (_, _) => true,
);

void main() {
  test('a library without the calls fails the translation', () async {
    // there on every linux host, and without kt_open
    final t = _with('libc.so.6');
    final out = t
        .translate('hello', from: 'en', to: 'zh')
        .timeout(const Duration(seconds: 20));
    await expectLater(out, throwsA(isA<StateError>()));
    // and the next one starts a new worker, which fails the same way
    await expectLater(
      t
          .translate('again', from: 'en', to: 'zh')
          .timeout(const Duration(seconds: 20)),
      throwsA(isA<StateError>()),
    );
    await t.close();
  });

  test('a library that is not there fails the translation', () async {
    final t = _with('libkryfo_none_here.so');
    await expectLater(
      t
          .translate('hello', from: 'en', to: 'zh')
          .timeout(const Duration(seconds: 20)),
      throwsA(isA<StateError>()),
    );
  });

  test('close with no worker, and twice, is fine', () async {
    final t = _with('libc.so.6');
    await t.close();
    await t.close();
  });

  test('the library is asked for once, by the probe', () async {
    var asked = 0;
    final t = BergamotTranslator(
      probe: (_) {
        asked++;
        return false;
      },
      config: (_, _) => null,
      installed: (_, _) => true,
    );
    expect(await t.hasLibrary(), isFalse);
    expect(await t.hasLibrary(), isFalse);
    expect(asked, 1);
    expect(BergamotTranslator.libraryOpens('libkryfo_none_here.so'), isFalse);
  });
}
