// SPDX-License-Identifier: GPL-3.0-or-later
// the translation worker: one that dies, or a library it cannot use, ends
// the translations waiting on it with an error, never a wait that does not
// end. its open models: the least recently used close past the cap, never
// one a translation holds, both legs of a pivot kept together

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/translate/bergamot_ffi.dart';
import 'package:kryfo/translate/foreign.dart';
import 'package:kryfo/translate/model_cache.dart';

import 'translate_fakes.dart';

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

  group('open models', () {
    // a handle is its key and the time it opened, so a reopen is a new one
    late List<String> closed;
    late ModelCache<String> c;
    var opens = 0;
    setUp(() {
      closed = [];
      opens = 0;
      c = ModelCache<String>(3, closed.add);
    });

    // the worker's steps for one ask
    String ask(String key, [List<String> held = const []]) {
      final h = c.use(key);
      if (h != null) return h;
      c.makeRoom(key, held);
      final made = '$key#${opens++}';
      c.add(key, made);
      return made;
    }

    test('the least recently used closes past three', () {
      ask('de-en');
      ask('ru-en');
      ask('en-ar');
      expect(closed, isEmpty);
      // used again, so no longer the oldest
      ask('de-en');
      ask('fr-en');
      expect(closed, ['ru-en#1']);
      expect(c.keys, ['en-ar', 'de-en', 'fr-en']);
      ask('es-en');
      expect(closed, ['ru-en#1', 'en-ar#2']);
      expect(c.length, 3);
    });

    test('one closes before the next opens, so three is the peak', () {
      final peaks = <int>[];
      final d = ModelCache<String>(3, (_) {});
      for (final k in ['a-en', 'b-en', 'c-en', 'd-en', 'e-en']) {
        if (d.use(k) == null) {
          d.makeRoom(k, const []);
          peaks.add(d.length);
          d.add(k, k);
        }
      }
      expect(peaks, [0, 1, 2, 2, 2]);
    });

    test('a held model is never closed, even past the cap', () {
      ask('de-en');
      ask('ru-en');
      ask('en-ar');
      // all three held: the fourth opens beside them
      const held = ['de-en', 'ru-en', 'en-ar'];
      ask('fr-en', held);
      expect(closed, isEmpty);
      expect(c.length, 4);
      // the asked one is never closed for its own room either
      ask('fr-en', held);
      expect(c.keys.last, 'fr-en');
      // let go: back to three, oldest first, the held one stays
      c.trim(['de-en']);
      expect(closed, ['ru-en#1']);
      expect(c.keys, ['de-en', 'en-ar', 'fr-en']);
    });

    test('both legs of a pivot under way stay open', () {
      ask('ru-en', ['ru-en', 'en-ar']);
      ask('de-en');
      ask('en-ar', ['ru-en', 'en-ar']);
      // a pivot is held as a whole: other directions go first
      const pivot = ['ru-en', 'en-ar'];
      ask('fr-en', pivot);
      ask('es-en', pivot);
      expect(closed, ['de-en#1', 'fr-en#3']);
      expect(c.keys, ['ru-en', 'en-ar', 'es-en']);
    });

    test('a closed model opens again when next asked', () {
      final first = ask('ru-en');
      ask('de-en');
      ask('fr-en');
      ask('es-en');
      expect(closed, [first]);
      expect(c.use('ru-en'), isNull);
      final again = ask('ru-en');
      expect(again, isNot(first));
      expect(c.use('ru-en'), again);
      // the old handle was closed once, never twice
      expect(closed.where((h) => h == first).length, 1);
    });

    test('a cap of two still takes a whole pivot', () {
      final d = ModelCache<String>(2, closed.add);
      const pivot = ['ru-en', 'en-ar'];
      for (final k in pivot) {
        d.makeRoom(k, pivot);
        d.add(k, k);
      }
      expect(closed, isEmpty);
      expect(d.length, 2);
      d.makeRoom('de-en', const []);
      d.add('de-en', 'de-en');
      expect(closed, ['ru-en']);
      expect(d.keys, ['en-ar', 'de-en']);
    });

    test('all close at once, each once', () {
      ask('de-en');
      ask('ru-en');
      c.closeAll();
      expect(closed, ['de-en#0', 'ru-en#1']);
      expect(c.length, 0);
      c.closeAll();
      expect(closed.length, 2);
    });

    test('the cap is two on a 32-bit build and three on 64', () {
      expect(kMaxOpenModels, anyOf(2, 3));
      final t = BergamotTranslator(
        probe: (_) => false,
        config: (_, _) => null,
        installed: (_, _) => true,
      );
      expect(t.maxOpen, kMaxOpenModels);
    });
  });

  group('holds', () {
    test(
      'a route is held while it runs and let go after, on a throw too',
      () async {
        final t = BergamotTranslator(
          probe: (_) => false,
          config: (_, _) => null,
          installed: (_, _) => true,
        );
        const pivot = [('ru', 'en'), ('en', 'ar')];
        final gate = Completer<void>();
        final run = t.holding(pivot, () => gate.future);
        expect(t.held, {'ru-en': 1, 'en-ar': 1});
        // two translations through english hold it twice
        final other = t.holding([('de', 'en'), ('en', 'ar')], () async {
          expect(t.held, {'ru-en': 1, 'en-ar': 2, 'de-en': 1});
          throw StateError('broken');
        });
        await expectLater(other, throwsStateError);
        expect(t.held, {'ru-en': 1, 'en-ar': 1});
        gate.complete();
        await run;
        expect(t.held, isEmpty);
        await t.close();
      },
    );

    test('the hub holds both legs of a pivot for the whole message', () async {
      final f = fakeHub(installed: true, catalog: dirCatalog);
      for (final id in ['ru-en', 'en-de']) {
        await f.hub.downloads.refresh(id);
      }
      final gate = f.translator.gate = Completer<void>();
      final out = f.hub.translate('Привет', const Offer('ru', 'de'));
      await pumpEventQueue();
      expect(f.translator.holdingNow, [
        [('ru', 'en'), ('en', 'de')],
      ]);
      gate.complete();
      expect(await out, '[de] [en] Привет');
      expect(f.translator.holdingNow, isEmpty);
      expect(f.translator.asked, ['ru-en:Привет', 'en-de:[en] Привет']);
    });
  });
}
