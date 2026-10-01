// SPDX-License-Identifier: GPL-3.0-or-later
// a group row reading sending settles once its send ends, wherever that send
// ran: this screen, the outbox, or the same chat before it was reopened
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/group_send_watch.dart';

import 'source_body.dart';

void main() {
  test('reopened while its upload runs: settles when that send ends', () {
    final w = GroupSendWatch();
    // back after 30 s: young, so it loads sending, with the old send running
    expect(
      w.loaded('a', sending: true, dead: false, inflight: true),
      SendSeen.keep,
    );
    expect(
      w.needsCheck('a', sending: true, failed: false, inflight: true),
      isFalse,
    );
    // the old send let go and marked it sent
    expect(
      w.needsCheck('a', sending: true, failed: false, inflight: false),
      isTrue,
    );
    expect(
      w.verdict('a', sending: true, sent: true, dead: false, inflight: false),
      SendSeen.sent,
    );
  });

  test('reopened while its upload runs: one that did not go fails', () {
    final w = GroupSendWatch();
    w.loaded('a', sending: true, dead: false, inflight: true);
    expect(
      w.verdict('a', sending: true, sent: false, dead: false, inflight: false),
      SendSeen.failed,
    );
    // and a reload before anything else keeps it failed, not spinning
    expect(
      w.loaded('a', sending: true, dead: false, inflight: false),
      SendSeen.failed,
    );
    // its sender marking it sent a beat later still lands
    expect(
      w.needsCheck('a', sending: false, failed: true, inflight: false),
      isTrue,
    );
    expect(
      w.verdict('a', sending: false, sent: true, dead: false, inflight: false),
      SendSeen.sent,
    );
    expect(w.watched('a'), isFalse);
  });

  test('loaded while tor warms up, then sent by the outbox', () {
    final w = GroupSendWatch();
    expect(
      w.loaded('a', sending: true, dead: false, inflight: false),
      SendSeen.keep,
    );
    // the outbox has it
    expect(
      w.needsCheck('a', sending: true, failed: false, inflight: true),
      isFalse,
    );
    expect(w.watched('a'), isTrue);
    expect(
      w.needsCheck('a', sending: true, failed: false, inflight: false),
      isTrue,
    );
    expect(
      w.verdict('a', sending: true, sent: true, dead: false, inflight: false),
      SendSeen.sent,
    );
  });

  test('nobody sending it: kept while young, failed once dead', () {
    final w = GroupSendWatch();
    expect(
      w.verdict('a', sending: true, sent: false, dead: false, inflight: false),
      SendSeen.keep,
    );
    expect(
      w.verdict('a', sending: true, sent: false, dead: true, inflight: false),
      SendSeen.failed,
    );
    expect(
      w.loaded('b', sending: true, dead: true, inflight: false),
      SendSeen.failed,
    );
  });

  test('a send of this screen is its own to settle', () async {
    final w = GroupSendWatch();
    final gate = Completer<void>();
    final run = w.owning('a', () => gate.future);
    expect(w.isOwn('a'), isTrue);
    expect(
      w.loaded('a', sending: true, dead: true, inflight: false),
      SendSeen.keep,
    );
    expect(
      w.needsCheck('a', sending: true, failed: false, inflight: false),
      isFalse,
    );
    expect(
      w.verdict('a', sending: true, sent: false, dead: true, inflight: false),
      SendSeen.keep,
    );
    // found busy: once this screen lets go, the other send is watched
    w.busy('a');
    gate.complete();
    await run;
    expect(w.isOwn('a'), isFalse);
    expect(w.watched('a'), isTrue);
  });

  test('two runs on one row: still its own until both end', () async {
    final w = GroupSendWatch();
    final g1 = Completer<void>();
    final g2 = Completer<void>();
    final r1 = w.owning('a', () => g1.future);
    final r2 = w.owning('a', () => g2.future);
    g1.complete();
    await r1;
    expect(w.isOwn('a'), isTrue);
    g2.complete();
    await r2;
    expect(w.isOwn('a'), isFalse);
  });

  group('the group chat', () {
    final screen = sourceOf('lib/screens/group_chat_screen.dart');

    test('places every loaded row, full load and append alike', () {
      expect('_placeLoadedSend(m)'.allMatches(screen).length, 2);
      final load = bodyOf(screen, 'Future<void> _load(');
      expect(load, contains('_placeLoadedSend(m)'));
      final append = bodyOf(screen, 'Future<void> _appendNewInner(');
      expect(append, contains('_placeLoadedSend(m)'));
    });

    test('settles on every change of the chat and on the retry tick', () {
      final changed = bodyOf(screen, 'void _onAppStateChanged(');
      final at = changed.indexOf('_seenRev = rev;');
      expect(changed.indexOf('_settleOthersSends()'), greaterThan(at));
      final tick = bodyOf(screen, 'void _autoRetryTick(');
      expect(tick, contains('_settleOthersSends()'));
    });

    test('every send it starts runs as its own', () {
      expect(
        RegExp(r'appState\s*\.sendToGroup\(').allMatches(screen).length,
        4,
      );
      expect(
        RegExp(r'\(\) => appState\.sendToGroup\(').allMatches(screen).length,
        4,
      );
      expect(
        RegExp(r'appState\s*\.sendMediaToGroup\(').allMatches(screen).length,
        RegExp(
          r'\(\) => appState\.sendMediaToGroup\(',
        ).allMatches(screen).length,
      );
      expect('_sendGroupMedia(\n'.allMatches(screen).length, 4);
    });
  });
}
