// SPDX-License-Identifier: GPL-3.0-or-later
// what translation holds goes when it should: a burned message's
// translation at once, a shut vault's chats with the session, the models
// in the background. and a translation is never written anywhere
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/translate/chat_translation.dart';
import 'package:kryfo/translate/hub.dart';
import 'package:kryfo/translate/settings.dart';

import 'sqlite_ffi.dart';
import 'translate_fakes.dart';

const _zh = '你好，我们明天见吧';
const _en = 'Hello, see you tomorrow';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

class _Rev extends ChangeNotifier {
  int rev = 0;
  void bump() {
    rev++;
    notifyListeners();
  }
}

void main() {
  test('a forgotten message keeps no translation', () async {
    final f = fakeHub(installed: true, words: {_zh: _en});
    final c = ChatTranslation(f.hub, 'heron');
    await settle();
    await c.toggle('m1', _zh);
    expect(c.of('m1').text, _en);
    c.forget('m1', _zh);
    expect(c.of('m1').phase, MsgPhase.idle);
    expect(c.of('m1').text, isNull);
    c.dispose();
  });

  test('one under way when its message burns is not kept', () async {
    final f = fakeHub(installed: true, words: {_zh: _en});
    final c = ChatTranslation(f.hub, 'heron');
    await settle();
    final run = c.toggle('m1', _zh);
    c.forget('m1', _zh);
    await run;
    expect(c.of('m1').text, isNull);
    expect(c.shown('m1'), isFalse);
    c.dispose();
  });

  test('a new session drops what was read of the chats', () async {
    final f = fakeHub(installed: true);
    final rev = _Rev();
    final stop = f.hub.followSessions(rev, () => rev.rev);
    await f.hub.ready();
    await f.hub.chatAuto('hidden-chat');
    expect(f.hub.chatAutoNow('hidden-chat'), isNotNull);
    // a notify with no new session keeps it
    rev.notifyListeners();
    expect(f.hub.chatAutoNow('hidden-chat'), isNotNull);
    rev.bump();
    expect(f.hub.chatAutoNow('hidden-chat'), isNull);
    stop();
    await f.hub.chatAuto('hidden-chat');
    rev.bump();
    expect(f.hub.chatAutoNow('hidden-chat'), isNotNull);
  });

  test('the background closes the models', () async {
    final f = fakeHub(installed: true);
    final away = TranslateAway(f.hub);
    away.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await settle();
    expect(f.translator.closes, 0);
    away.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await settle();
    expect(f.translator.closes, 1);
    away.didChangeAppLifecycleState(AppLifecycleState.paused);
    await settle();
    expect(f.translator.closes, 2);
    away.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle();
    expect(f.translator.closes, 2);
  });

  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;

  test(
    'nothing of a message or its translation reaches the database',
    () async {
      final db = SqliteMem.open()!;
      await appSchemaOn(db);
      final f = fakeHub(installed: true, words: {_zh: _en});
      final hub = TranslationHub(
        store: DbTranslateStore(() async => db),
        translator: f.translator,
        downloads: f.hub.downloads,
        catalog: f.hub.catalog,
        appLang: () => 'en',
      );
      await hub.ready();
      final c = ChatTranslation(hub, 'heron');
      await settle();
      await c.setAuto(true);
      await c.toggle('m1', _zh);
      expect(c.of('m1').text, _en);
      c.autoFor('m2', '明天下午三点在车站');
      await settle();
      c.dispose();

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      for (final t in tables) {
        final name = t['name'] as String;
        for (final row in await db.query(name)) {
          for (final v in row.values) {
            if (v is! String) continue;
            for (final words in [_zh, _en, '明天', 'Hello']) {
              expect(v.contains(words), isFalse, reason: '$name holds "$v"');
            }
          }
        }
      }
      await db.close();
    },
    skip: skip,
  );
}
