// SPDX-License-Identifier: GPL-3.0-or-later
// one chat's translations: tap, show original, auto, and what a missing
// pack or library says
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/translate/bergamot_ffi.dart';
import 'package:kryfo/translate/chat_translation.dart';
import 'package:kryfo/translate/engine_bridge.dart';
import 'package:kryfo/translate/settings.dart';
import 'package:kryfo/translate/translator.dart';

import 'translate_fakes.dart';

const _zh = '你好，我们明天见吧';
const _en = 'Hello, see you tomorrow';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  test(
    'tap: translated; tap again: the original; again: no new work',
    () async {
      final f = fakeHub(installed: true, words: {_zh: _en});
      final c = ChatTranslation(f.hub, 'heron');
      await settle();
      expect(c.offer(_zh)?.from, 'zh');
      expect(c.offer('see you tomorrow'), isNull);
      expect(await c.toggle('m1', _zh), isNull);
      expect(c.of('m1').phase, MsgPhase.shown);
      expect(c.of('m1').text, _en);
      await c.toggle('m1', _zh);
      expect(c.of('m1').phase, MsgPhase.idle);
      await c.toggle('m1', _zh);
      expect(c.shown('m1'), isTrue);
      expect(f.translator.asked, hasLength(1));
      c.dispose();
    },
  );

  test('no pack: what is missing, and nothing downloads by itself', () async {
    final f = fakeHub(words: {_zh: _en});
    final c = ChatTranslation(f.hub, 'heron');
    await settle();
    final need = await c.toggle('m1', _zh);
    expect(need, isNotNull);
    expect(need!.why, TranslateBlock.noModel);
    expect(need.missing.single.lang, 'zh');
    expect(need.offer.seen, 'zh');
    expect(c.of('m1').phase, MsgPhase.idle);
    expect(f.backend.started, isEmpty);
    c.dispose();
  });

  test('no library: said, with nothing missing to download', () async {
    final f = fakeHub(installed: true, lib: false);
    final c = ChatTranslation(f.hub, 'heron');
    await settle();
    final need = await c.toggle('m1', _zh);
    expect(need!.why, TranslateBlock.noLib);
    expect(need.missing, isEmpty);
    c.dispose();
  });

  test('a library failure shows as failed, and a retry works', () async {
    final f = fakeHub(installed: true, words: {_zh: _en});
    f.translator.breakNext = true;
    final c = ChatTranslation(f.hub, 'heron');
    await settle();
    await c.toggle('m1', _zh);
    expect(c.of('m1').phase, MsgPhase.failed);
    await c.toggle('m1', _zh);
    expect(c.of('m1').text, _en);
    c.dispose();
  });

  test('auto is off unless set, per chat', () async {
    final f = fakeHub(installed: true, words: {_zh: _en});
    final a = ChatTranslation(f.hub, 'heron');
    final b = ChatTranslation(f.hub, 'fox');
    await settle();
    expect(a.auto, isFalse);
    a.autoFor('m1', _zh);
    await settle();
    expect(a.of('m1').phase, MsgPhase.idle);

    await a.setAuto(true);
    expect(await f.store.chatAuto('heron'), isTrue);
    expect(await f.store.chatAuto('fox'), isNull);
    expect(b.auto, isFalse);
    a.autoFor('m1', _zh);
    await settle();
    expect(a.of('m1').text, _en);
    b.autoFor('m1', _zh);
    await settle();
    expect(b.of('m1').phase, MsgPhase.idle);
    a.dispose();
    b.dispose();
  });

  test(
    'auto never fetches a pack, and leaves the original when asked',
    () async {
      final f = fakeHub(words: {_zh: _en});
      final c = ChatTranslation(f.hub, 'heron');
      await settle();
      await c.setAuto(true);
      c.autoFor('m1', _zh);
      await settle();
      expect(c.of('m1').phase, MsgPhase.idle);
      expect(f.backend.started, isEmpty);

      // the pack arrives: auto picks it up, and a tap back stays back
      f.backend.finish('zh');
      await f.hub.downloads.refresh('zh');
      c.autoFor('m1', _zh);
      await settle();
      expect(c.shown('m1'), isTrue);
      await c.toggle('m1', _zh);
      c.autoFor('m1', _zh);
      await settle();
      expect(c.shown('m1'), isFalse);
      c.dispose();
    },
  );

  test(
    'auto off: what it translated goes back, what was tapped stays',
    () async {
      final f = fakeHub(installed: true);
      final c = ChatTranslation(f.hub, 'heron');
      await settle();
      await c.setAuto(true);
      c.autoFor('auto', _zh);
      await settle();
      await c.toggle('tapped', '今天天气很好');
      expect(c.shown('auto'), isTrue);
      expect(c.shown('tapped'), isTrue);
      await c.setAuto(false);
      expect(c.shown('auto'), isFalse);
      expect(c.shown('tapped'), isTrue);
      c.dispose();
    },
  );

  test('a change on the person\'s page reaches the open chat', () async {
    final f = fakeHub(installed: true);
    final c = ChatTranslation(f.hub, 'heron');
    await settle();
    expect(c.auto, isFalse);
    await f.hub.setChatAuto('heron', true);
    expect(c.auto, isTrue);
    c.dispose();
  });

  test('the default in settings applies to chats nobody set', () async {
    final f = fakeHub(
      installed: true,
      settings: const TranslateSettings(autoDefault: true),
    );
    final c = ChatTranslation(f.hub, 'heron');
    await settle();
    expect(c.auto, isTrue);
    await f.store.setChatAuto('fox', false);
    final d = ChatTranslation(f.hub, 'fox');
    await settle();
    expect(d.auto, isFalse);
    c.dispose();
    d.dispose();
  });

  test('a reader of chinese is offered english, not chinese', () async {
    final f = fakeHub(installed: true, app: 'zh');
    final c = ChatTranslation(f.hub, 'heron');
    await settle();
    expect(c.offer(_zh), isNull);
    expect(c.offer('Are you coming to the meeting tomorrow?')?.to, 'zh');
    c.dispose();
  });

  test('no translation library in this build: blocked, not broken', () async {
    final t = BergamotTranslator(
      config: (_, _) => 'models: []',
      installed: (_, _) => true,
      lib: 'libkryfo_translate_not_here.so',
    );
    expect(t.hasLib, isFalse);
    expect(await t.blockFor('zh', 'en'), TranslateBlock.noLib);
    await expectLater(
      t.translate('你好', from: 'zh', to: 'en'),
      throwsA(isA<TranslateUnavailable>()),
    );
    final none = BergamotTranslator(
      config: (_, _) => null,
      installed: (_, _) => false,
      lib: 'libkryfo_translate_not_here.so',
    );
    expect(await none.blockFor('zh', 'en'), TranslateBlock.noModel);
    await t.close();
  });

  test(
    'an engine without the calls: no guess, no catalog, no download',
    () async {
      final e = FfiTranslateEngine();
      expect(e.detect('你好'), isNull);
      expect(e.catalog(), isNull);
      expect(await e.fetch('zh', '/nowhere', ''), startsWith('error: engine'));
      expect(e.progress('zh').state, 'idle');
      expect(await e.installed('zh', '/nowhere'), isFalse);
      expect(e.config('zh', 'en', '/nowhere'), isNull);
    },
  );
}
