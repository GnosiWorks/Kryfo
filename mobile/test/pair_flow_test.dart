// SPDX-License-Identifier: GPL-3.0-or-later
// a pairing by an eight digit code, both sides, on stand-in hooks: what
// each engine answer becomes on screen, that nothing is added before the
// person says so, that every way out lets the engine's run and the invite
// go, and that six digits never reach the engine
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/pair_flow.dart';
import 'package:kryfo/widgets/pair_join.dart' show PairCodeFormatter;

class _Fake {
  final calls = <String>[];
  final steps = <String>[];
  String shareSays = 'ok 7 07 123 456';
  String joinSays = 'ok 9';
  bool noInvite = false;
  PairPeer? peer = const PairPeer(
    link: 'kryfo://share?v=4&i=x',
    id: 'their-three-words',
  );
  (String, bool) adds = ('', true);
  String? joined;

  PairHooks hooks() => PairHooks(
    invite: () async {
      calls.add('invite');
      return noInvite ? null : PairMine(Uint8List.fromList([1, 2, 3]));
    },
    share: (inv) async {
      calls.add('share');
      return shareSays;
    },
    join: (code, inv) async {
      calls.add('join');
      joined = code;
      return joinSays;
    },
    step: (h) async {
      calls.add('step $h');
      return steps.isEmpty ? 'wait 0' : steps.removeAt(0);
    },
    close: (h) async => calls.add('close $h'),
    read: (kin4) async {
      calls.add('read ${utf8.decode(kin4)}');
      return peer;
    },
    hold: (mine, p) async => calls.add('hold'),
    add: (p, mine, {required sharer}) async {
      calls.add('add ${sharer ? 'sharer' : 'joiner'}');
      return adds;
    },
    drop: (mine) async => calls.add('drop'),
  );
}

String _done(String s) => 'done ${base64Encode(utf8.encode(s))}';

void main() {
  late DateTime now;
  setUp(() {
    now = DateTime(2026, 11, 4, 12);
    pairNow = () => now;
  });
  tearDown(() => pairNow = DateTime.now);

  test('digits in every script the app types are read, the marks between '
      'them skipped, anything else refused', () {
    expect(pairDigits('07 123 456'), '07123456');
    expect(pairDigits('٠٧١٢٣٤٥٦'), '07123456');
    expect(pairDigits('۰۷ ۱۲۳ ۴۵۶'), '07123456');
    expect(pairDigits('०७१२३४५६'), '07123456');
    expect(pairDigits('０７１２３４５６'), '07123456');
    expect(pairDigits('\u200e07\u202f123\u2011456\u2069'), '07123456');
    expect(pairDigits('07a23456'), isNull);
    expect(pairDigits('07.123.456'), isNull);
    expect(pairCodeShown('07123456'), '07 123 456');
    expect(pairCodeShown('071'), '07 1');
    expect(pairOldCode('482913'), isTrue);
    expect(pairOldCode('482 913'), isTrue);
    expect(pairOldCode('۴۸۲۹۱۳'), isTrue);
    expect(pairOldCode('07123456'), isFalse);
    expect(pairOldCode('48291'), isFalse);
  });

  test('the field shows what is typed as NN NNN NNN, eight digits at most', () {
    const f = PairCodeFormatter();
    TextEditingValue t(String s) =>
        f.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: s));
    expect(t('0712').text, '07 12');
    expect(t('07123456789').text, '07 123 456');
    expect(t('۰۷۱۲۳').text, '07 123');
    expect(t('07-1x2').text, '07 12');
    expect(t('07123456').selection.baseOffset, 10);
  });

  testWidgets(
    'the sharer: the code, a wrong try said, the match, and the add only '
    'on the person\'s word, with the invite kept for their opener',
    (t) async {
      {
        final f = _Fake();
        final r = PairRun.share(f.hooks());
        r.start();
        await t.pump();
        expect(r.phase, PairPhase.live);
        expect(r.code, '07 123 456');
        expect(r.burns, now.add(kPairCodeLife));
        expect(f.calls.take(2), ['invite', 'share']);
        f.steps.addAll(['wait 1', _done('joiner-invite')]);
        await t.pump();
        expect(r.line, PairLine.waiting);
        await t.pump(const Duration(seconds: 3));
        expect(r.line, PairLine.wrongTyped);
        expect(r.warn, isTrue);
        expect(r.wrong, 1);
        await t.pump(const Duration(seconds: 3));
        expect(r.phase, PairPhase.matched);
        expect(r.peer!.id, 'their-three-words');
        expect(
          f.calls,
          containsAllInOrder(['close 7', 'read joiner-invite', 'hold']),
        );
        expect(f.calls.where((c) => c.startsWith('add')), isEmpty);
        // no more rounds once it matched
        final steps = f.calls.where((c) => c.startsWith('step')).length;
        await t.pump(const Duration(seconds: 30));
        expect(f.calls.where((c) => c.startsWith('step')).length, steps);
        r.confirm();
        await t.pump();
        expect(r.phase, PairPhase.added);
        expect(f.calls.last, 'add sharer');
        expect(f.calls, isNot(contains('drop')));
        r.dispose();
        await t.pump();
        expect(f.calls, isNot(contains('drop')));
      }
    },
  );

  testWidgets('not them adds nothing and lets the invite go', (t) async {
    {
      final f = _Fake()..steps.add(_done('x'));
      final r = PairRun.share(f.hooks());
      r.start();
      await t.pump();
      expect(r.phase, PairPhase.matched);
      r.notThem();
      await t.pump();
      expect(r.phase, PairPhase.ended);
      expect(r.line, PairLine.notAdded);
      expect(f.calls.last, 'drop');
      expect(f.calls.where((c) => c.startsWith('add')), isEmpty);
    }
  });

  testWidgets(
    'a sharer\'s end: each one wipes the run and lets the invite go, and '
    'says why',
    (t) async {
      for (final (says, line) in [
        ('error: tries', PairLine.threeWrong),
        ('error: expired', PairLine.burned),
        ('error: gone', PairLine.failed),
      ]) {
        {
          final f = _Fake()..steps.add(says);
          final r = PairRun.share(f.hooks());
          r.start();
          await t.pump();
          expect(r.phase, PairPhase.ended, reason: says);
          expect(r.line, line, reason: says);
          expect(
            f.calls,
            containsAllInOrder(['close 7', 'drop']),
            reason: says,
          );
        }
      }
    },
  );

  testWidgets('a code burns on the second its count says, and its run goes', (
    t,
  ) async {
    {
      final f = _Fake();
      final r = PairRun.share(f.hooks(), gap: const Duration(seconds: 50));
      r.start();
      await t.pump();
      now = now.add(kPairCodeLife - const Duration(seconds: 1));
      await t.pump(kPairCodeLife - const Duration(seconds: 1));
      expect(r.phase, PairPhase.live);
      now = now.add(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      expect(r.phase, PairPhase.ended);
      expect(r.line, PairLine.burned);
      expect(f.calls, containsAllInOrder(['close 7', 'drop']));
    }
  });

  testWidgets(
    'a share no relay took, or no invite yet, is said and leaves nothing',
    (t) async {
      {
        final f = _Fake()..shareSays = pairUnreached;
        final r = PairRun.share(f.hooks());
        r.start();
        await t.pump();
        expect(r.line, PairLine.unreached);
        expect(r.warn, isTrue);
        expect(f.calls, ['invite', 'share', 'drop']);
        final g = _Fake()..noInvite = true;
        final q = PairRun.share(g.hooks());
        q.start();
        await t.pump();
        expect(q.line, PairLine.inviteNotReady);
        expect(g.calls, ['invite']);
      }
    },
  );

  test('six digits are an older Kryfo\'s code: said at once, no invite made, '
      'nothing sent to the engine', () async {
    final f = _Fake();
    final r = PairRun.join(f.hooks());
    await r.begin('482 913');
    expect(r.line, PairLine.oldCode);
    expect(f.calls, isEmpty);
    await r.begin('0712345');
    expect(r.line, PairLine.eightDigits);
    expect(f.calls, isEmpty);
  });

  testWidgets(
    'the joiner: looking, waiting, the match, then the add and its own '
    'invite let go',
    (t) async {
      {
        final f = _Fake()..steps.addAll(['look', 'wait 0']);
        final r = PairRun.join(f.hooks());
        r.begin('۰۷ ۱۲۳ ۴۵۶');
        await t.pump();
        expect(f.joined, '07123456');
        expect(r.line, PairLine.looking);
        await t.pump(const Duration(seconds: 3));
        expect(r.line, PairLine.waiting);
        now = now.add(kPairStillAfter);
        await t.pump(const Duration(seconds: 3));
        expect(r.line, PairLine.stillWaiting);
        f.steps.add(_done('sharer-invite'));
        await t.pump(const Duration(seconds: 3));
        expect(r.phase, PairPhase.matched);
        expect(f.calls, isNot(contains('hold')));
        r.confirm();
        await t.pump();
        expect(r.phase, PairPhase.added);
        expect(f.calls.sublist(f.calls.length - 2), ['add joiner', 'drop']);
      }
    },
  );

  testWidgets('nothing at the code is said after a minute of looking', (
    t,
  ) async {
    {
      final f = _Fake();
      final r = PairRun.join(f.hooks());
      for (var i = 0; i < 40; i++) {
        f.steps.add('look');
      }
      r.begin('07123456');
      await t.pump();
      now = now.add(const Duration(seconds: 13));
      await t.pump(const Duration(seconds: 3));
      expect(r.line, PairLine.nothingYet);
      now = now.add(kPairLookFor);
      await t.pump(const Duration(seconds: 3));
      expect(r.phase, PairPhase.ended);
      expect(r.line, PairLine.nothingAtCode);
      expect(f.calls, containsAllInOrder(['close 9', 'drop']));
    }
  });

  testWidgets('a joiner\'s end says why: tries, an answer that never came, the '
      'code\'s time', (t) async {
    for (final (says, line) in [
      ('error: tries', PairLine.tooManyTries),
      ('error: unanswered', PairLine.unanswered),
      ('error: expired', PairLine.ranOut),
    ]) {
      {
        final f = _Fake()..steps.add(says);
        final r = PairRun.join(f.hooks());
        r.begin('07123456');
        await t.pump();
        expect(r.line, line, reason: says);
        expect(r.warn, isTrue, reason: says);
        expect(f.calls, containsAllInOrder(['close 9', 'drop']));
      }
    }
    for (final (says, line) in [
      ('error: tries', PairLine.tooManyTries),
      ('error: old', PairLine.oldCode),
      (pairUnreached, PairLine.unreached),
    ]) {
      {
        final f = _Fake()..joinSays = says;
        final r = PairRun.join(f.hooks());
        r.begin('07123456');
        await t.pump();
        expect(r.line, line, reason: says);
        expect(f.calls, ['invite', 'join', 'drop']);
      }
    }
  });

  testWidgets('a match whose invite does not read is no match', (t) async {
    {
      final f = _Fake()
        ..peer = null
        ..steps.add(_done('damaged'));
      final r = PairRun.join(f.hooks());
      r.begin('07123456');
      await t.pump();
      expect(r.phase, PairPhase.ended);
      expect(r.line, PairLine.failed);
      expect(f.calls.last, 'drop');
    }
  });

  testWidgets(
    'the screen going lets the run and the invite go, mid-run or before '
    'the engine answered',
    (t) async {
      {
        final f = _Fake();
        final r = PairRun.join(f.hooks());
        r.begin('07123456');
        await t.pump();
        r.dispose();
        await t.pump();
        expect(f.calls, containsAllInOrder(['close 9', 'drop']));
        final g = _Fake();
        final s = PairRun.share(g.hooks());
        s.start();
        s.dispose();
        await t.pump();
        // gone before the invite came back: it goes, and nothing is shared
        expect(g.calls, ['invite', 'drop']);
        final steps = g.calls.where((c) => c.startsWith('step')).length;
        await t.pump(const Duration(seconds: 20));
        expect(g.calls.where((c) => c.startsWith('step')).length, steps);
      }
    },
  );

  testWidgets(
    'the store keeps one run per container and lets the one before go',
    (t) async {
      {
        final f = _Fake();
        final codes = PairCodes();
        final one = codes.begin('everyday', f.hooks());
        one.start();
        await t.pump();
        final two = codes.begin('everyday', f.hooks());
        await t.pump();
        expect(codes.of('everyday'), same(two));
        expect(f.calls, containsAll(['close 7', 'drop']));
        expect(codes.of('decoy'), isNull);
        expect(codes.left(one), 600);
        codes.clear();
        await t.pump(const Duration(seconds: 5));
      }
    },
  );

  testWidgets('a joiner waiting on its answer rides out rounds no relay '
      'answered; one that never heard a relay gives up after a minute', (
    t,
  ) async {
    final f = _Fake()
      ..steps.addAll(['wait 0', for (var i = 0; i < 30; i++) 'unreached']);
    final r = PairRun.join(f.hooks());
    r.begin('07123456');
    await t.pump();
    now = now.add(kPairLookFor * 2);
    await t.pump(const Duration(seconds: 6));
    expect(r.phase, PairPhase.live);
    expect(r.line, PairLine.unreached);
    r.dispose();
    await t.pump(const Duration(seconds: 5));
    final g = _Fake()..steps.addAll([for (var i = 0; i < 30; i++) 'unreached']);
    final q = PairRun.join(g.hooks());
    q.begin('07123456');
    await t.pump();
    now = now.add(kPairLookFor);
    await t.pump(const Duration(seconds: 3));
    expect(q.phase, PairPhase.ended);
    expect(q.line, PairLine.unreached);
    expect(q.warn, isTrue);
  });

  testWidgets('a sharer whose code matched while its finish is still going '
      'out does not burn, and matches once it went', (t) async {
    final f = _Fake()
      ..steps.addAll(['wait 0', 'finishing', 'finishing', _done('late')]);
    final r = PairRun.share(f.hooks(), gap: const Duration(minutes: 4));
    r.start();
    await t.pump();
    await t.pump(const Duration(minutes: 4));
    expect(r.line, PairLine.waiting);
    now = now.add(kPairCodeLife + const Duration(minutes: 1));
    await t.pump(const Duration(minutes: 7));
    expect(r.phase, PairPhase.live);
    await t.pump(const Duration(minutes: 4));
    expect(r.phase, PairPhase.matched);
    expect(f.calls, isNot(contains('drop')));
    r.dispose();
    await t.pump(const Duration(minutes: 5));
  });
}
