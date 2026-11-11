// SPDX-License-Identifier: GPL-3.0-or-later
// one chat's transcripts: the model asked for only when words are new, the
// words streaming in and kept beside the note, folded and opened again with
// no model, one note at a time, nothing kept for a note that went or once
// the app locked, the memory wiped behind the lock and on a session switch,
// and every transcript gone when they are turned off
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/voice/chat_transcripts.dart';
import 'package:kryfo/voice/transcript_store.dart';
import 'package:kryfo/voice/voice_ffi.dart';

import 'voice_tx_fakes.dart';

Future<void> _beat() => Future<void>.delayed(Duration.zero);

Future<void> _beats([int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await _beat();
  }
}

void main() {
  late VoiceFakes f;
  late ChatTranscripts c;

  Future<void> make({bool installed = true, VoiceTxStore? store}) async {
    f = fakeVoiceHub(installed: installed, store: store);
    c = ChatTranscripts(f.hub, 'heron');
    await f.hub.ready();
    await _beats();
  }

  tearDown(() {
    c.dispose();
    f.hub.dispose();
  });

  test('no model: the open asks for it and nothing runs', () async {
    await make(installed: false);
    expect(c.offered('u1'), isTrue);
    expect(await c.open('u1', '/n/u1.ogg'), TxNeed.model);
    expect(f.runner.jobs, isEmpty);
    expect(c.of('u1').phase, TxPhase.closed);
  });

  test('no uid, no library or off: no link', () async {
    await make();
    expect(c.offered(null), isFalse);
    final g = fakeVoiceHub(lib: false);
    final none = ChatTranscripts(g.hub, 'heron');
    addTearDown(none.dispose);
    expect(none.offered('u1'), isFalse);
    await f.hub.setOn(false);
    expect(c.offered('u1'), isFalse);
  });

  test('the words come as they are heard, then stay beside the note', () async {
    await make();
    expect(await c.open('u1', '/n/u1.ogg'), isNull);
    await _beats();
    expect(c.of('u1').phase, TxPhase.working);
    final j = f.runner.jobs.single;
    expect(j.path, '/n/u1.ogg');
    j.say(' see you');
    await _beats();
    expect(c.of('u1').phase, TxPhase.working);
    expect(c.of('u1').text, 'see you');
    j.say(' at three', at: 1000);
    j.end('en');
    await _beats();
    expect(c.of('u1').phase, TxPhase.shown);
    expect(c.of('u1').text, 'see you at three');
    expect(c.shownText('u1'), 'see you at three');
    final kept = (await f.store.kept('heron'))['u1']!;
    expect(kept.text, 'see you at three');
    expect(kept.lang, 'en');
    expect(kept.pieces, hasLength(2));
  });

  test('folded and opened again: no model, no second run', () async {
    await make();
    await c.open('u1', '/n/u1.ogg');
    await _beats();
    f.runner.jobs.single
      ..say(' hello there')
      ..end();
    await _beats();
    c.hide('u1');
    expect(c.of('u1').phase, TxPhase.closed);
    expect(c.shownText('u1'), isNull);
    expect((await f.store.kept('heron'))['u1']!.open, isFalse);
    // the model went meanwhile: the words are there all the same
    f.backend.have = false;
    await f.hub.downloads.refresh('base');
    expect(await c.open('u1', '/n/u1.ogg'), isNull);
    expect(c.of('u1').phase, TxPhase.shown);
    expect(f.runner.jobs, hasLength(1));
    expect((await f.store.kept('heron'))['u1']!.open, isTrue);
  });

  test('read back when the chat opens again, open or folded', () async {
    final store = MemoryVoiceTxStore();
    store.rows['heron'] = {
      'u1': const KeptTranscript(
        lang: 'en',
        model: 'base',
        pieces: [TxPiece(0, 1, ' open one')],
      ),
      'u2': const KeptTranscript(
        lang: 'en',
        model: 'base',
        pieces: [TxPiece(0, 1, ' folded one')],
        open: false,
      ),
    };
    await make(store: store);
    expect(c.of('u1').phase, TxPhase.shown);
    expect(c.of('u1').text, 'open one');
    expect(c.of('u2').phase, TxPhase.closed);
    expect(f.runner.jobs, isEmpty);
  });

  test('a broken run: said, and tried again on a tap', () async {
    await make();
    await c.open('u1', '/n/u1.ogg');
    await _beats();
    f.runner.jobs.single.fail();
    await _beats();
    expect(c.of('u1').phase, TxPhase.failed);
    expect(await f.store.kept('heron'), isEmpty);
    await c.retry('u1', '/n/u1.ogg');
    await _beats();
    f.runner.jobs.last
      ..say(' second time')
      ..end();
    await _beats();
    expect(c.of('u1').text, 'second time');
    // a failed one folds away too
    await c.open('u2', '/n/u2.ogg');
    await _beats();
    f.runner.jobs.last.fail();
    await _beats();
    c.hide('u2');
    expect(c.of('u2').phase, TxPhase.closed);
  });

  test('no speech: kept as none, never the model\'s own note', () async {
    await make();
    await c.open('u1', '/n/u1.ogg');
    await _beats();
    f.runner.jobs.single
      ..say(' [BLANK_AUDIO]')
      ..say(' (silence)')
      ..end();
    await _beats();
    final n = c.of('u1');
    expect(n.phase, TxPhase.shown);
    expect(n.silent, isTrue);
    expect(n.text, isEmpty);
    expect((await f.store.kept('heron'))['u1']!.pieces, isEmpty);
    // nothing to copy
    expect(c.shownText('u1'), isNull);
    // tried again: the empty answer goes and the note is heard again
    await c.retry('u1', '/n/u1.ogg');
    await _beats();
    expect(f.runner.jobs, hasLength(2));
    expect(c.of('u1').phase, TxPhase.working);
    expect(await f.store.kept('heron'), isEmpty);
    f.runner.jobs.last
      ..say(' at last')
      ..end();
    await _beats();
    expect(c.of('u1').text, 'at last');
  });

  test('notes on sounds go from the words as they come', () async {
    await make();
    await c.open('u1', '/n/u1.ogg');
    await _beats();
    final j = f.runner.jobs.single;
    j.say(' [MUSIC]');
    await _beats();
    expect(c.of('u1').text, isEmpty);
    j.say(' Hello [BLANK_AUDIO] there.');
    await _beats();
    expect(c.of('u1').phase, TxPhase.working);
    expect(c.of('u1').text, 'Hello there.');
    // the model stuck on one line: said once
    j
      ..say(' Hello there.')
      ..say(' See you.')
      ..end();
    await _beats();
    expect(c.of('u1').text, 'Hello there. See you.');
  });

  test(
    'no detection: theirs in the chat\'s language, ours in the app\'s',
    () async {
      f = fakeVoiceHub(appLang: () => 'pt_BR');
      c = ChatTranscripts(f.hub, 'heron', theirLang: () => 'de');
      await f.hub.ready();
      await _beats();
      await c.open('u1', '/n/u1.ogg');
      await _beats();
      f.runner.jobs.last.end();
      await _beats();
      await c.open('u2', '/n/u2.ogg', mine: true);
      await _beats();
      f.runner.jobs.last.end();
      await _beats();
      expect(f.runner.langs, ['de', 'pt']);
    },
  );

  test(
    'no word from the chat: the app\'s language, english past that',
    () async {
      f = fakeVoiceHub(appLang: () => 'zh_Hant');
      c = ChatTranscripts(f.hub, 'heron', theirLang: () => null);
      await f.hub.ready();
      await c.open('u1', '/n/u1.ogg');
      await _beats();
      expect(f.runner.langs, ['zh']);
    },
  );

  test('audio that cannot be read is a failure, not a crash', () async {
    await make();
    f.runner.throwCode = VoiceError.audio;
    await c.open('u1', '/n/u1.ogg');
    await _beats();
    expect(c.of('u1').phase, TxPhase.failed);
  });

  test('one note at a time: the next waits for the one before', () async {
    await make();
    await c.open('u1', '/n/u1.ogg');
    await c.open('u2', '/n/u2.ogg');
    await _beats();
    expect(f.runner.jobs, hasLength(1));
    expect(c.of('u2').phase, TxPhase.working);
    f.runner.jobs.first
      ..say(' first')
      ..end();
    await _beats(12);
    expect(f.runner.jobs, hasLength(2));
    f.runner.jobs.last
      ..say(' second')
      ..end();
    await _beats();
    expect(c.of('u1').text, 'first');
    expect(c.of('u2').text, 'second');
  });

  test('a note that burns or is unsent while it runs keeps nothing', () async {
    await make();
    await c.open('u1', '/n/u1.ogg');
    await _beats();
    final j = f.runner.jobs.single..say(' secret');
    await _beats();
    c.forget('u1');
    expect(j.cancelled, isTrue);
    expect(c.of('u1').phase, TxPhase.closed);
    j.end();
    await _beats();
    expect(await f.store.kept('heron'), isEmpty);
    // and it does not come back on a tap
    expect(await c.open('u1', '/n/u1.ogg'), isNull);
    expect(f.runner.jobs, hasLength(1));
  });

  test('a kept one burns: gone from memory and the store', () async {
    await make();
    await c.open('u1', '/n/u1.ogg');
    await _beats();
    f.runner.jobs.single
      ..say(' timed words')
      ..end();
    await _beats();
    expect((await f.store.kept('heron')).keys, ['u1']);
    c.forget('u1');
    await _beats();
    expect(c.of('u1').text, isEmpty);
    expect(await f.store.kept('heron'), isEmpty);
  });

  test('the lock stops a run, keeps nothing, and wipes memory', () async {
    await make();
    final store = f.store as MemoryVoiceTxStore;
    store.rows['heron'] = {
      'u9': const KeptTranscript(
        lang: 'en',
        model: 'base',
        pieces: [TxPiece(0, 1, ' kept before')],
      ),
    };
    final c2 = ChatTranscripts(f.hub, 'heron');
    addTearDown(c2.dispose);
    await _beats();
    expect(c2.of('u9').text, 'kept before');
    await c2.open('u1', '/n/u1.ogg');
    await _beats();
    final j = f.runner.jobs.single..say(' half');
    await _beats();
    f.hub.lockedOut();
    expect(j.cancelled, isTrue);
    expect(c2.of('u1').phase, TxPhase.closed);
    expect(c2.of('u9').text, isEmpty);
    expect(c2.offered('u1'), isFalse);
    // nothing starts behind the lock
    expect(await c2.open('u1', '/n/u1.ogg'), isNull);
    expect(f.runner.jobs, hasLength(1));
    f.hub.unlocked();
    await _beats();
    // read back from the store once it opens; the run made nothing
    expect(c2.of('u9').text, 'kept before');
    expect((await f.store.kept('heron')).keys, ['u9']);
  });

  test('a session switch (the decoy, a vault shut) wipes and stops', () async {
    await make();
    final rev = _Rev();
    f.hub.followSessions(rev, () => rev.n);
    await c.open('u1', '/n/u1.ogg');
    await _beats();
    final j = f.runner.jobs.single;
    rev.bump();
    expect(j.cancelled, isTrue);
    expect(c.of('u1').phase, TxPhase.closed);
  });

  test('turned off: every transcript goes, runs stop', () async {
    await make();
    await c.open('u1', '/n/u1.ogg');
    await _beats();
    f.runner.jobs.single
      ..say(' words')
      ..end();
    await _beats();
    await c.open('u2', '/n/u2.ogg');
    await _beats();
    final j = f.runner.jobs.last;
    await f.hub.setOn(false);
    await _beats();
    expect(j.cancelled, isTrue);
    expect(await f.store.kept('heron'), isEmpty);
    expect(c.of('u1').text, isEmpty);
    expect(c.offered('u1'), isFalse);
    expect(f.hub.settings.offs, 1);
    // on again: nothing comes back, nothing runs by itself
    await f.hub.setOn(true);
    await _beats();
    expect(c.of('u1').phase, TxPhase.closed);
    expect(f.runner.jobs, hasLength(2));
  });

  test('made after an off: what a container kept before it goes', () async {
    // turned off while the vault was shut, then the app started again: the
    // vault opens before any chat, so no session switch is heard
    final store = MemoryVoiceTxStore(const VoiceTxSettings(offs: 1))
      ..rows['heron'] = {
        'u9': const KeptTranscript(
          lang: 'en',
          model: 'base',
          pieces: [TxPiece(0, 1, ' from before the off')],
        ),
      };
    await make(store: store);
    expect(c.of('u9').text, isEmpty);
    expect(await store.kept('heron'), isEmpty);
  });

  test('a chat that closes stops its run and keeps nothing', () async {
    await make();
    final c2 = ChatTranscripts(f.hub, 'heron');
    await c2.open('u1', '/n/u1.ogg');
    await _beats();
    final j = f.runner.jobs.single..say(' gone');
    c2.dispose();
    expect(j.cancelled, isTrue);
    await _beats();
    expect(await f.store.kept('heron'), isEmpty);
  });

  test('the model comes: the next open runs', () async {
    await make(installed: false);
    expect(await c.open('u1', '/n/u1.ogg'), TxNeed.model);
    await f.hub.downloads.start('base');
    f.backend.finish();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(f.hub.modelReady, isTrue);
    expect(await c.open('u1', '/n/u1.ogg'), isNull);
    await _beats();
    expect(f.runner.jobs, hasLength(1));
  });

  test('the decoy downloads nothing and has no model', () async {
    await make();
    final g = fakeVoiceHub(installed: true, quiet: true);
    addTearDown(g.hub.dispose);
    final d = ChatTranscripts(g.hub, 'heron');
    addTearDown(d.dispose);
    await g.hub.ready();
    expect(g.hub.modelReady, isFalse);
    expect(await d.open('u1', '/n/u1.ogg'), TxNeed.model);
    await g.hub.downloads.start('base');
    expect(g.backend.started, isEmpty);
    expect(g.runner.jobs, isEmpty);
  });
}

class _Rev extends ChangeNotifier {
  int n = 0;
  void bump() {
    n++;
    notifyListeners();
  }
}
