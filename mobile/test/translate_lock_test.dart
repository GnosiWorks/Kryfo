// SPDX-License-Identifier: GPL-3.0-or-later
// the app locking: every open chat, everyday, hidden or the decoy's, drops
// what it translated and guessed, and nothing is made again behind the lock
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/translate/chat_translation.dart';
import 'package:kryfo/translate/detect.dart';
import 'package:kryfo/translate/translate_bubble.dart';

import 'translate_fakes.dart';

const _zh = '你好，我们明天见吧';
const _en = 'Hello, see you tomorrow';
const _zh2 = '我们后天在车站见吧';
const _en2 = 'See you at the station the day after tomorrow';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

class _Lock extends ChangeNotifier {
  bool locked = false;
  void set(bool on) {
    locked = on;
    notifyListeners();
  }
}

void main() {
  test(
    'a lock wipes every chat, the hidden one too, and its guesses',
    () async {
      var asked = 0;
      final f = fakeHub(
        installed: true,
        words: {_zh: _en, _zh2: _en2},
        guess: (t) {
          asked++;
          return detectLanguage(t);
        },
      );
      final lock = _Lock();
      f.hub.followLock(lock, () => lock.locked);
      final everyday = ChatTranslation(f.hub, 'heron');
      // a hidden chat's: the vault's, the same hub
      final hidden = ChatTranslation(f.hub, 'hidden-wren');
      await settle();
      await everyday.toggle('m1', _zh);
      await hidden.toggle('h1', _zh2);
      expect(everyday.of('m1').text, _en);
      expect(hidden.of('h1').text, _en2);

      lock.set(true);
      expect(everyday.of('m1').text, isNull);
      expect(hidden.of('h1').text, isNull);
      expect(everyday.of('m1').phase, MsgPhase.idle);
      // nothing is guessed or translated behind the lock
      final guessed = asked;
      final translated = f.translator.asked.length;
      expect(everyday.offer(_zh), isNull);
      expect(await everyday.toggle('m1', _zh), isNull);
      everyday.autoFor('m1', _zh);
      await settle();
      expect(asked, guessed);
      expect(f.translator.asked.length, translated);
      expect(everyday.of('m1').text, isNull);

      lock.set(false);
      // the guesses went with the lock: asked again once it is open
      expect(everyday.offer(_zh)?.from, 'zh');
      expect(asked, guessed + 1);
      everyday.dispose();
      hidden.dispose();
    },
  );

  test('one under way when the app locks is not kept', () async {
    final f = fakeHub(installed: true, words: {_zh: _en});
    final lock = _Lock();
    f.hub.followLock(lock, () => lock.locked);
    final c = ChatTranslation(f.hub, 'heron');
    await settle();
    final run = c.toggle('m1', _zh);
    lock.set(true);
    await run;
    lock.set(false);
    expect(c.of('m1').text, isNull);
    expect(c.shown('m1'), isFalse);
    c.dispose();
  });

  test('the decoy: its guesses go with the lock too', () async {
    var asked = 0;
    final f = fakeHub(
      quiet: true,
      guess: (t) {
        asked++;
        return detectLanguage(t);
      },
    );
    final lock = _Lock();
    f.hub.followLock(lock, () => lock.locked);
    final c = ChatTranslation(f.hub, 'decoy-chat');
    await settle();
    expect(c.offer(_zh)?.from, 'zh');
    expect(c.offer(_zh)?.from, 'zh');
    expect(asked, 1);
    lock.set(true);
    lock.set(false);
    c.offer(_zh);
    expect(asked, 2);
    c.dispose();
  });

  test("the app's own lock", () async {
    final f = fakeHub(installed: true, words: {_zh: _en});
    lockState.openForTest(enabled: true);
    addTearDown(lockState.openForTest);
    final stop = f.hub.followLock(lockState, () => lockState.locked);
    addTearDown(stop);
    final c = ChatTranslation(f.hub, 'heron');
    addTearDown(c.dispose);
    await settle();
    await c.toggle('m1', _zh);
    expect(c.of('m1').text, _en);
    lockState.lock();
    expect(lockState.locked, isTrue);
    expect(c.of('m1').text, isNull);
    expect(f.hub.locked, isTrue);
  });

  testWidgets('behind the lock the bubble shows the words as they came', (
    t,
  ) async {
    final f = fakeHub(installed: true, words: {_zh: _en});
    final lock = _Lock();
    f.hub.followLock(lock, () => lock.locked);
    final c = ChatTranslation(f.hub, 'heron');
    addTearDown(c.dispose);
    await f.store.setChatAuto('heron', true);
    await t.pumpWidget(
      MaterialApp(
        theme: buildHaloTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: TranslatedBody(
              chat: c,
              msgKey: 'm1',
              text: _zh,
              original: const Text(_zh),
              translated: (w) => Text(w),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text(_en), findsOneWidget);
    final translated = f.translator.asked.length;

    lock.set(true);
    await t.pumpAndSettle();
    expect(find.text(_en), findsNothing);
    expect(find.text(_zh), findsOneWidget);
    expect(
      find.textContaining(l10n.translateAction, findRichText: true),
      findsNothing,
    );
    // a chat that translates on its own does not start again behind it
    expect(f.translator.asked.length, translated);

    lock.set(false);
    await t.pumpAndSettle();
    expect(find.text(_en), findsOneWidget);
  });
}
