// SPDX-License-Identifier: GPL-3.0-or-later
// words shared from another app: the subject over the text unless the text
// says it already, direction controls and stray controls out, cut to a
// message's size on a whole character. they wait for the lock, a decoy's
// unlock included, and are let go when the app is left first. once shown
// they show only in the session that showed them
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/share_text.dart';

// what organic maps sends for a place
const _mapsSubject = 'Hey, check out my pin at Organic Maps!';
const _mapsText =
    'Café Sperl\r\nGumpendorfer Straße 11, Vienna\r\n48.19785, 16.36196\r\n'
    'https://omaps.app/o4B4pYZsRs/Caf%C3%A9_Sperl';

void main() {
  group('the words', () {
    test('a place from a map app: subject, then its lines', () {
      expect(
        sharedWords(subject: _mapsSubject, text: _mapsText),
        '$_mapsSubject\nCafé Sperl\nGumpendorfer Straße 11, Vienna\n'
        '48.19785, 16.36196\nhttps://omaps.app/o4B4pYZsRs/Caf%C3%A9_Sperl',
      );
    });

    test('a page from a browser: its title over its link', () {
      expect(
        sharedWords(subject: 'Tor Project', text: 'https://torproject.org'),
        'Tor Project\nhttps://torproject.org',
      );
    });

    test('a subject the text already says is not said twice', () {
      expect(
        sharedWords(subject: 'see you at 6', text: 'see you at 6 sharp'),
        'see you at 6 sharp',
      );
      expect(sharedWords(subject: '  ', text: 'just this'), 'just this');
      expect(sharedWords(subject: 'only a subject'), 'only a subject');
      expect(sharedWords(text: ' \n '), '');
      expect(sharedWords(), '');
    });

    test('direction controls and stray controls go, lines stay', () {
      expect(
        sharedWords(text: 'invoice \u202Egpj.exe\u202C done'),
        'invoice gpj.exe done',
      );
      expect(
        sharedWords(subject: '\u2067name\u2069', text: 'a\u0000b\tc\u0007'),
        'name\nab\tc',
      );
      // persian keeps its joiners
      expect(sharedWords(text: 'می\u200Cخواهم'), 'می\u200Cخواهم');
      expect(sharedWords(text: 'one\n\n\n\n\ntwo'), 'one\n\ntwo');
    });

    test('a subject inside a word is still said; one the text starts with '
        'or holds as a line is not', () {
      expect(
        sharedWords(subject: 'Hi', text: 'History of Vienna'),
        'Hi\nHistory of Vienna',
      );
      expect(
        sharedWords(subject: 'map', text: 'see the roadmap'),
        'map\nsee the roadmap',
      );
      expect(
        sharedWords(subject: 'Café Sperl', text: 'Café Sperl, Vienna'),
        'Café Sperl, Vienna',
      );
      expect(
        sharedWords(subject: 'Café Sperl', text: 'a pin\n Café Sperl \nlink'),
        'a pin\n Café Sperl \nlink',
      );
    });

    test('c1 controls go, unicode line breaks become plain ones', () {
      expect(sharedWords(text: 'a\u0085b\u009Bc\u0080d'), 'abcd');
      expect(sharedWords(text: 'one\u2028two\u2029three'), 'one\ntwo\nthree');
      expect(sharedWords(subject: 'title\u0090', text: 'x'), 'title\nx');
    });

    test('cut to what a message holds', () {
      expect(kShareTextMax, 4096);
      final long = sharedWords(text: 'a' * 5000);
      expect(long.length, kShareTextMax);
      // an emoji across the edge stays whole or goes whole
      final edge = sharedWords(text: '${'a' * 4095}👍🏽 tail');
      expect(edge, 'a' * 4095);
      final fits = sharedWords(text: '${'a' * 4092}👍🏽 tail');
      expect(fits, '${'a' * 4092}👍🏽');
      expect(sharedWords(text: 'short', max: 3), 'sho');
    });

    test('what android hands over', () {
      final s = SharedText.from({
        'id': 'ab12',
        'text': 'https://example.org',
        'subject': 'Example',
        'seen': null,
      })!;
      expect(s.id, 'ab12');
      expect(s.words, 'Example\nhttps://example.org');
      expect(s.seenIn, isNull);
      expect(SharedText.from({'id': '', 'text': 'x'}), isNull);
      expect(SharedText.from(null), isNull);
      expect(
        SharedText.from({'id': 'c', 'text': 'x', 'seen': 'decoy'})!.seenIn,
        'decoy',
      );
    });

    test('the session it is shown in', () {
      expect(shareSessionTag(decoy: false, vault: false), 'everyday');
      expect(shareSessionTag(decoy: false, vault: true), 'everyday+vault');
      expect(shareSessionTag(decoy: true, vault: false), 'decoy');
      expect(shareSessionTag(decoy: true, vault: true), 'decoy+vault');
    });
  });

  group('the lock comes first', () {
    late bool locked;
    late String where;
    late LockGuard guard;
    late ShareGate gate;
    const fresh = SharedText('s1', 'words');

    setUp(() {
      locked = false;
      where = 'everyday';
      guard = LockGuard(isLocked: () => locked);
      gate = ShareGate(guard: guard, where: () => where);
    });

    // [f] once it is done, null while it still waits
    Future<bool?> after(WidgetTester t, Future<bool> f) async {
      bool? out;
      unawaited(f.then((v) => out = v));
      await t.pump();
      return out;
    }

    testWidgets('open: at once', (t) async {
      expect(await after(t, gate.clear(fresh)), isTrue);
    });

    testWidgets('locked: only after the pin', (t) async {
      locked = true;
      bool? out;
      unawaited(gate.clear(fresh).then((v) => out = v));
      await t.pump();
      expect(out, isNull);
      locked = false;
      guard.lifted();
      await t.pump();
      expect(out, isTrue);
    });

    testWidgets('a decoy pin opens it too, in the decoy', (t) async {
      locked = true;
      bool? out;
      unawaited(gate.clear(fresh).then((v) => out = v));
      await t.pump();
      locked = false;
      where = 'decoy';
      guard.dropHeld();
      await t.pump();
      expect(out, isTrue);
    });

    testWidgets('left before the pin: let go', (t) async {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      locked = true;
      bool? out;
      unawaited(gate.clear(fresh).then((v) => out = v));
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      expect(out, isNull);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await t.pump();
      expect(out, isFalse);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets('arriving in the background is not leaving', (t) async {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      locked = true;
      bool? out;
      unawaited(gate.clear(fresh).then((v) => out = v));
      await t.pump();
      // on its way up it passes through hidden
      for (final s in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        t.binding.handleAppLifecycleStateChanged(s);
      }
      await t.pump();
      expect(out, isNull);
      locked = false;
      guard.lifted();
      await t.pump();
      expect(out, isTrue);
    });

    testWidgets('shown once: it waits out leaving, in its own session only', (
      t,
    ) async {
      const seen = SharedText('s2', 'words', seenIn: 'everyday');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      locked = true;
      bool? out;
      unawaited(gate.clear(seen).then((v) => out = v));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      expect(out, isNull);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      locked = false;
      guard.lifted();
      await t.pump();
      expect(out, isTrue);

      locked = true;
      out = null;
      unawaited(gate.clear(seen).then((v) => out = v));
      await t.pump();
      locked = false;
      where = 'decoy';
      guard.dropHeld();
      await t.pump();
      expect(out, isFalse);
      where = 'everyday+vault';
      expect(await after(t, gate.clear(seen)), isFalse);
    });
  });
}
