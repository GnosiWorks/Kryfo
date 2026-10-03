// SPDX-License-Identifier: GPL-3.0-or-later
// joining with a pairing code: nothing is added until the person has seen
// the face and three words the code led to and said they match. not them
// adds nothing, a code that points at two invites is refused outright, the
// card springs in under 300 ms or simply appears with less movement, and
// the words stay left to right in a right-to-left language. the sharing
// side shows its own three words under the code.
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show appState;
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/kryfo_avatar.dart';
import 'package:kryfo/widgets/pair_code_panel.dart';
import 'package:kryfo/widgets/pair_join.dart';

import 'pin_flow_fakes.dart' show app, phone;

const _words = 'thumb-behave-boring';
const _invite = 'kryfo://share?id=$_words&onion=x.onion&v=3&bundle=zz&fc=ab';

class _Pair {
  _Pair(this.answers);
  // one per look, the last one repeating
  final List<String> answers;
  final looked = <String>[];
  final added = <String>[];
  final done = <String>[];

  Widget widget() => Scaffold(
    key: ObjectKey(this),
    body: PairJoin(
      fetch: (code) async {
        looked.add(code);
        return answers[min(looked.length, answers.length) - 1];
      },
      add: (invite) async {
        added.add(invite);
        return 'added';
      },
      onAdded: done.add,
      retryGap: Duration.zero,
    ),
  );
}

Future<void> _look(WidgetTester t, [String code = '482 913']) async {
  await t.enterText(find.byType(TextField), code);
  await t.tap(find.text(l10n.pairCodeAddThem));
}

// how far the card has grown and faded in
double _scale(WidgetTester t) => t
    .widget<ScaleTransition>(
      find
          .ancestor(
            of: find.byType(PairConfirm),
            matching: find.byType(ScaleTransition),
          )
          .first,
    )
    .scale
    .value;

void main() {
  tearDown(() => setL10nLocale(const Locale('en')));

  test('the words come from the invite, and only real ones', () {
    expect(pairInviteWords(_invite), _words);
    expect(pairInviteWords('https://example.com/?id=$_words'), isNull);
    expect(pairInviteWords('kryfo://share?id=Robert%27);DROP'), isNull);
    expect(pairInviteWords('kryfo://share?onion=x.onion'), isNull);
    expect(pairInviteWords('kryfo://share?id=a-b'), isNull);
  });

  testWidgets('the face and words come first, and add only on Add', (t) async {
    phone(t);
    final p = _Pair([_invite]);
    await t.pumpWidget(app(p.widget()));
    await _look(t);
    await t.pumpAndSettle();

    expect(p.looked, ['482913']);
    expect(find.byType(PairConfirm), findsOneWidget);
    expect(find.text(l10n.pairCodeIsThisThem), findsOneWidget);
    expect(find.text(_words), findsOneWidget);
    expect(find.text(l10n.pairCodeCheckMatches), findsOneWidget);
    expect(t.widget<KryfoAvatar>(find.byType(KryfoAvatar)).seed, _words);
    expect(find.byType(TextField), findsNothing);
    expect(p.added, isEmpty);

    await t.tap(find.text(l10n.commonAdd));
    await t.pumpAndSettle();
    expect(p.added, [_invite]);
    expect(p.done, ['added']);
  });

  testWidgets('not them adds nothing and asks for a new code', (t) async {
    phone(t);
    final p = _Pair([_invite]);
    await t.pumpWidget(app(p.widget()));
    await _look(t);
    await t.pumpAndSettle();

    await t.tap(find.text(l10n.pairCodeNotThem));
    await t.pumpAndSettle();
    expect(find.byType(PairConfirm), findsNothing);
    expect(find.text(l10n.pairCodeNotAdded), findsOneWidget);
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '');
    expect(p.added, isEmpty);
    expect(p.done, isEmpty);
  });

  testWidgets('a code used twice is refused, with nothing to confirm', (
    t,
  ) async {
    phone(t);
    final p = _Pair(['twice']);
    await t.pumpWidget(app(p.widget()));
    await _look(t);
    await t.pumpAndSettle();

    expect(find.text(l10n.pairCodeUsedTwice), findsOneWidget);
    expect(find.byType(PairConfirm), findsNothing);
    expect(find.text(_words), findsNothing);
    // refused on the first look, not tried again
    expect(p.looked, hasLength(1));
    expect(p.added, isEmpty);
  });

  testWidgets('nothing there yet is looked for again, then given up', (
    t,
  ) async {
    phone(t);
    final p = _Pair(['empty', 'empty', _invite]);
    await t.pumpWidget(app(p.widget()));
    await _look(t);
    await t.pumpAndSettle();
    expect(p.looked, hasLength(3));
    expect(find.byType(PairConfirm), findsOneWidget);

    final q = _Pair(['empty']);
    await t.pumpWidget(app(q.widget()));
    await t.pumpAndSettle();
    await _look(t);
    await t.pumpAndSettle();
    expect(q.looked, hasLength(3));
    expect(find.text(l10n.pairCodeNothingAtThatCode), findsOneWidget);
    expect(q.added, isEmpty);
  });

  testWidgets('no network is said as that, not as an empty code, and '
      'not in the engine\'s words', (t) async {
    phone(t);
    final p = _Pair([pairUnreached]);
    await t.pumpWidget(app(p.widget()));
    await _look(t);
    await t.pumpAndSettle();
    expect(find.text(l10n.pairCodeUnreached), findsOneWidget);
    expect(find.text(l10n.pairCodeNothingAtThatCode), findsNothing);
    expect(find.textContaining('error'), findsNothing);
    expect(find.textContaining('unreached'), findsNothing);
    expect(p.added, isEmpty);
  });

  testWidgets('the card springs in and settles within 300 ms', (t) async {
    phone(t);
    final p = _Pair([_invite]);
    await t.pumpWidget(app(p.widget()));
    await _look(t);
    for (var i = 0; i < 5 && find.byType(PairConfirm).evaluate().isEmpty; i++) {
      await t.pump();
    }
    expect(find.byType(PairConfirm), findsOneWidget);
    await t.pump(const Duration(milliseconds: 40));
    final mid = _scale(t);
    expect(mid, greaterThan(0.94));
    expect(mid, lessThan(1));
    await t.pump(const Duration(milliseconds: 260));
    expect(_scale(t), closeTo(1, 0.005));
    await t.pumpAndSettle();
  });

  testWidgets('with less movement the card is simply there', (t) async {
    phone(t);
    final p = _Pair([_invite]);
    await t.pumpWidget(app(p.widget(), still: true));
    await _look(t);
    for (var i = 0; i < 5 && find.byType(PairConfirm).evaluate().isEmpty; i++) {
      await t.pump();
    }
    expect(find.byType(PairConfirm), findsOneWidget);
    expect(_scale(t), 1);
    expect(find.byType(TextField), findsNothing);
    final face = find.ancestor(
      of: find.byType(KryfoAvatar),
      matching: find.byType(Transform),
    );
    expect(t.widget<Transform>(face.first).transform.storage[0], 1);
  });

  testWidgets('with less movement a refusal line is simply there', (t) async {
    phone(t);
    final p = _Pair(['twice']);
    await t.pumpWidget(app(p.widget(), still: true));
    await _look(t);
    await t.pump();
    await t.pump();
    expect(find.text(l10n.pairCodeUsedTwice), findsOneWidget);
    expect(find.byType(AnimatedSize), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('right to left: the card mirrors, the words do not', (t) async {
    phone(t);
    setL10nLocale(const Locale('ar'));
    final p = _Pair([_invite]);
    await t.pumpWidget(app(p.widget(), locale: const Locale('ar')));
    await _look(t);
    await t.pumpAndSettle();

    expect(find.text(l10n.pairCodeIsThisThem), findsOneWidget);
    expect(l10n.pairCodeIsThisThem, isNot('Is this them?'));
    final words = find.text(_words);
    expect(t.widget<Text>(words).textDirection, TextDirection.ltr);
    expect(
      Directionality.of(t.element(find.text(l10n.pairCodeCheckMatches))),
      TextDirection.rtl,
    );
    await t.tap(find.text(l10n.pairCodeNotThem));
    await t.pumpAndSettle();
    expect(find.text(l10n.pairCodeNotAdded), findsOneWidget);
    expect(p.added, isEmpty);
  });

  testWidgets('the sharing side shows its own three words', (t) async {
    phone(t);
    await t.pumpWidget(
      app(
        const Scaffold(
          body: Center(child: PairWordsTag(words: _words)),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text(l10n.pairCodePanelYourWords), findsOneWidget);
    expect(find.text(_words), findsOneWidget);
    expect(t.widget<Text>(find.text(_words)).textDirection, TextDirection.ltr);
  });

  testWidgets('no relay answering is not a wrong code', (t) async {
    phone(t);
    final p = _Pair([pairUnreached]);
    await t.pumpWidget(app(p.widget()));
    await _look(t);
    await t.pumpAndSettle();
    // tried again, as a code not shared yet is
    expect(p.looked, hasLength(3));
    expect(find.text(l10n.pairCodeUnreached), findsOneWidget);
    expect(find.text(l10n.pairCodeNothingAtThatCode), findsNothing);
    expect(
      t.widget<Text>(find.text(l10n.pairCodeUnreached)).style!.color,
      HaloColors.rose,
    );

    // one look that was answered is enough to call the code empty
    final q = _Pair([pairUnreached, 'empty', pairUnreached]);
    await t.pumpWidget(app(q.widget()));
    await t.pumpAndSettle();
    await _look(t);
    await t.pumpAndSettle();
    expect(find.text(l10n.pairCodeNothingAtThatCode), findsOneWidget);

    // a relay answering on a later look still finds the invite
    final r = _Pair([pairUnreached, _invite]);
    await t.pumpWidget(app(r.widget()));
    await t.pumpAndSettle();
    await _look(t);
    await t.pumpAndSettle();
    expect(find.byType(PairConfirm), findsOneWidget);
  });

  testWidgets('an engine error is worded, in every language', (t) async {
    phone(t);
    for (final loc in const [Locale('en'), Locale('fa')]) {
      setL10nLocale(loc);
      final p = _Pair(['error: key: no curve point']);
      await t.pumpWidget(app(p.widget(), locale: loc));
      await t.pumpAndSettle();
      await _look(t);
      await t.pumpAndSettle();
      expect(p.looked, hasLength(1));
      expect(find.text(l10n.pairCodeFailed), findsOneWidget);
      expect(find.textContaining('no curve point'), findsNothing);
    }
    expect(pairErrorText(pairUnreached), l10n.pairCodeUnreached);
  });

  test('the share side and the engine name no relay the same way', () {
    final engine = File('../engine/paircode.go').readAsStringSync();
    expect(engine, contains('const pairUnreached = "$pairUnreached"'));
    for (final f in [
      'lib/widgets/pair_code_panel.dart',
      'lib/widgets/pair_join.dart',
      'lib/screens/pair_code_screen.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src, isNot(contains("replaceFirst('error: ', '')")), reason: f);
      expect(src, isNot(contains('no relays accepted')), reason: f);
    }
  });

  test('a share waits longer than the engine does for its publish', () {
    final nostr = File('../engine/nostr.go').readAsStringSync();
    final onion = RegExp(
      r'onionDialWait = (\d+) \* time\.Second',
    ).firstMatch(nostr);
    final extra = RegExp(
      r'const publishWait = onionDialWait \+ (\d+)\*time\.Second',
    ).firstMatch(nostr);
    expect(onion, isNotNull);
    expect(extra, isNotNull);
    final engineWait =
        int.parse(onion!.group(1)!) + int.parse(extra!.group(1)!);
    final pair = File('../engine/paircode.go').readAsStringSync();
    final publish = RegExp(
      r'func pairCodePublish\(.*?\n}',
      dotAll: true,
    ).firstMatch(pair);
    expect(publish, isNotNull);
    expect(
      publish!.group(0),
      contains('context.WithTimeout(context.Background(), publishWait)'),
    );
    final app = File('lib/main.dart').readAsStringSync();
    final wait = RegExp(
      r'Future<String> pairCodePublish\([^;]*Duration\(seconds: (\d+)\)',
    ).firstMatch(app);
    expect(wait, isNotNull);
    expect(int.parse(wait!.group(1)!), greaterThan(engineWait));
  });

  testWidgets('a share no relay took is worded, in the warning colour', (
    t,
  ) async {
    phone(t);
    final was = appState.myOnion;
    appState.myOnion = 'sharer.onion';
    addTearDown(() => appState.myOnion = was);
    for (final (res, said) in [
      (pairUnreached, l10n.pairCodeUnreached),
      ('error: relay said no', l10n.pairCodeFailed),
    ]) {
      final codes = <String>[];
      await t.pumpWidget(
        app(
          PairCodePanel(
            publish: (code) async {
              codes.add(code);
              return res;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.pairCodePanelOrMakeASix));
      await t.pumpAndSettle();
      expect(codes, hasLength(1));
      expect(find.text(said), findsOneWidget);
      expect(t.widget<Text>(find.text(said)).style!.color, HaloColors.rose);
      expect(find.textContaining('relay said no'), findsNothing);
      // nothing went up, so the button is there for another go
      expect(find.text(l10n.pairCodePanelOrMakeASix), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    }
  });
}
