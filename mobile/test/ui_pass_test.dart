// SPDX-License-Identifier: GPL-3.0-or-later
// small things that move or sit right: the reach pill rolls its count in
// place, the shared sheet buttons give under a finger, the pin pad reads
// left to right in every language, the scam shield buttons fit in russian
// at a big font, and a poll's hint folds away once voted. each one still
// with less movement.
import 'package:flutter/gestures.dart' show kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/polls.dart';
import 'package:kryfo/screens/shield_sheet.dart';
import 'package:kryfo/widgets/chat_parts.dart' show GrowSwap;
import 'package:kryfo/widgets/confirm_sheet.dart';
import 'package:kryfo/widgets/file_reach.dart';
import 'package:kryfo/widgets/pin_pad.dart';
import 'package:kryfo/widgets/poll_card.dart';

Widget host(
  Widget child, {
  bool still = false,
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, c) => MediaQuery(
    data: MediaQuery.of(
      ctx,
    ).copyWith(disableAnimations: still, textScaler: TextScaler.linear(scale)),
    child: c!,
  ),
  home: Scaffold(body: Center(child: child)),
);

void quiet(WidgetTester t) {
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

// a button that opens [open] when tapped
Widget opener(Future<void> Function(BuildContext) open) => Builder(
  builder: (ctx) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => open(ctx),
    child: const SizedBox(width: 80, height: 80, child: Text('go')),
  ),
);

void main() {
  group('the reach pill', () {
    Widget pill(int have, {bool still = false}) => host(
      GrowSwap(
        child: FileReachPill(key: const ValueKey('reach'), have: have, of: 4),
      ),
      still: still,
    );

    testWidgets('a new count rolls in without folding the pill', (t) async {
      await t.pumpWidget(pill(2));
      final h = t.getSize(find.byType(FileReachPill)).height;
      await t.pumpWidget(pill(3));
      await t.pump(const Duration(milliseconds: 80));
      // both for a moment, the pill as tall as ever
      expect(find.text('Sent · 2 of 4 have it'), findsOneWidget);
      expect(find.text('Sent · 3 of 4 have it'), findsOneWidget);
      expect(t.getSize(find.byType(FileReachPill)).height, h);
      expect(t.getSize(find.byType(GrowSwap)).height, greaterThanOrEqualTo(h));
      await t.pumpAndSettle();
      expect(find.text('Sent · 2 of 4 have it'), findsNothing);
      expect(find.bySemanticsLabel('Sent · 3 of 4 have it'), findsOneWidget);
    });

    testWidgets('at once with less movement', (t) async {
      await t.pumpWidget(pill(2, still: true));
      await t.pumpWidget(pill(3, still: true));
      await t.pump();
      expect(find.text('Sent · 2 of 4 have it'), findsNothing);
      expect(find.text('Sent · 3 of 4 have it'), findsOneWidget);
      expect(t.hasRunningAnimations, isFalse);
    });
  });

  group('the shared confirm sheet', () {
    // how far the button holding [label] has shrunk
    double scaleOf(WidgetTester t, String label) => t
        .widget<AnimatedScale>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(AnimatedScale),
          ),
        )
        .scale;

    Future<void> open(WidgetTester t, {bool still = false}) async {
      phone(t);
      quiet(t);
      await t.pumpWidget(
        host(
          opener(
            (ctx) => showConfirmSheet(
              ctx,
              title: 'Delete it?',
              line: 'It goes for good.',
              yes: 'Delete',
              keep: 'Keep',
            ),
          ),
          still: still,
        ),
      );
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
    }

    testWidgets('its buttons give under a finger', (t) async {
      await open(t);
      expect(scaleOf(t, 'Delete'), 1);
      final g = await t.startGesture(t.getCenter(find.text('Delete')));
      // past the press delay the sheet's drag holds a tap to
      await t.pump(kPressTimeout + const Duration(milliseconds: 60));
      expect(scaleOf(t, 'Delete'), lessThan(1));
      await g.cancel();
      await t.pump(const Duration(milliseconds: 200));
      expect(scaleOf(t, 'Delete'), 1);
      final k = await t.startGesture(t.getCenter(find.text('Keep')));
      await t.pump(kPressTimeout + const Duration(milliseconds: 60));
      expect(scaleOf(t, 'Keep'), lessThan(1));
      await k.up();
      await t.pumpAndSettle();
      expect(find.text('Keep'), findsNothing);
    });

    testWidgets('with less movement the press takes no time', (t) async {
      await open(t, still: true);
      final scale = find.ancestor(
        of: find.text('Delete'),
        matching: find.byType(AnimatedScale),
      );
      expect(t.widget<AnimatedScale>(scale).duration, Duration.zero);
      await t.tap(find.text('Keep'));
      await t.pumpAndSettle();
    });
  });

  group('the pin pad', () {
    testWidgets('reads 1 2 3 left to right in arabic too', (t) async {
      phone(t);
      setL10nLocale(const Locale('ar'));
      addTearDown(() => setL10nLocale(const Locale('en')));
      await t.pumpWidget(
        host(
          PinPad(onDigit: (_) {}, onBack: () {}, onEnter: () {}),
          locale: const Locale('ar'),
        ),
      );
      expect(
        Directionality.of(t.element(find.byType(PinPad))),
        TextDirection.rtl,
      );
      expect(
        t.getCenter(find.text('1')).dx,
        lessThan(t.getCenter(find.text('3')).dx),
      );
      expect(
        t.getCenter(find.text('7')).dx,
        lessThan(t.getCenter(find.text('9')).dx),
      );
      // enter on the left, delete on the right, as on the phone's own pad
      expect(
        t.getCenter(find.byIcon(Icons.check_rounded)).dx,
        lessThan(t.getCenter(find.byIcon(Icons.backspace_outlined)).dx),
      );
      expect(find.bySemanticsLabel(l10n.commonDelete), findsOneWidget);
    });
  });

  group('the scam shield sheet', () {
    for (final group in [false, true]) {
      testWidgets('its buttons fit in russian at a big font'
          '${group ? ' in a group' : ''}', (t) async {
        t.view.physicalSize = const Size(720, 1600);
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        quiet(t);
        setL10nLocale(const Locale('ru'));
        addTearDown(() => setL10nLocale(const Locale('en')));
        await t.pumpWidget(
          host(
            opener(
              (ctx) => showShieldSheet(
                ctx,
                'someone',
                const ShieldFlag('Он просит денег', [
                  'Просит перевести деньги',
                ]),
                group: group,
              ),
            ),
            locale: const Locale('ru'),
            scale: 1.6,
          ),
        );
        await t.tap(find.text('go'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        for (final w in [l10n.shieldBlock, l10n.shieldIgnore]) {
          final text = find.text(w);
          expect(text, findsOneWidget);
          // one line, never broken mid-word
          expect(t.getSize(text).height, lessThan(13 * 1.6 * 2));
        }
        await t.tapAt(const Offset(10, 10));
        await t.pumpAndSettle();
      });
    }
  });

  group('a poll card', () {
    const spec = PollSpec(options: ['Ramen', 'Tacos']);
    Widget card(Map<String, PollVote> votes, {bool still = false}) => host(
      PollCard(
        question: 'Dinner?',
        poll: spec,
        votes: votes,
        me: 'me',
        mine: false,
        isOut: false,
        onVote: (_) {},
        nameOf: (id) => id,
      ),
      still: still,
    );

    testWidgets('the hint folds away once voted', (t) async {
      quiet(t);
      await t.pumpWidget(card({}));
      await t.pumpAndSettle();
      expect(find.text(l10n.pollPickOne), findsOneWidget);
      final fold = find
          .descendant(
            of: find.byType(PollCard),
            matching: find.byType(AnimatedSize),
          )
          .first;
      expect(
        find.descendant(of: fold, matching: find.text(l10n.pollPickOne)),
        findsOneWidget,
      );
      final full = t.getSize(fold).height;
      await t.pumpWidget(
        card({
          'me': const PollVote([0], 1),
        }),
      );
      await t.pump(const Duration(milliseconds: 60));
      // on its way shut, not gone in one frame
      final mid = t.getSize(fold).height;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(full));
      await t.pumpAndSettle();
      expect(find.text(l10n.pollPickOne), findsNothing);
      expect(find.text(l10n.pollTakeBack), findsOneWidget);
    });

    testWidgets('with less movement the hint is simply gone', (t) async {
      quiet(t);
      await t.pumpWidget(card({}, still: true));
      await t.pump();
      await t.pumpWidget(
        card({
          'me': const PollVote([0], 1),
        }, still: true),
      );
      await t.pump();
      expect(find.text(l10n.pollPickOne), findsNothing);
      expect(find.text(l10n.pollTakeBack), findsOneWidget);
    });
  });
}
