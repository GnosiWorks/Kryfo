// SPDX-License-Identifier: GPL-3.0-or-later
// making a poll: an answer taken out folds away where it was and is let go,
// the way to take one out pops in once there is a third. the result's
// shares and the count of votes roll to their new figures. all of it rests,
// with less movement nothing slides, and the rows mirror right to left.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/polls.dart';
import 'package:kryfo/widgets/new_poll_sheet.dart';
import 'package:kryfo/widgets/poll_card.dart';

Widget host(
  Widget child, {
  bool still = false,
  TextDirection dir = TextDirection.ltr,
}) => MaterialApp(
  builder: (ctx, c) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: Directionality(textDirection: dir, child: c!),
  ),
  home: Scaffold(body: Center(child: child)),
);

void quiet(WidgetTester t) {
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  m.setMockMethodCallHandler(SystemChannels.textInput, (_) async => null);
  addTearDown(() {
    m.setMockMethodCallHandler(SystemChannels.platform, null);
    m.setMockMethodCallHandler(SystemChannels.textInput, null);
  });
}

Future<void> settles(WidgetTester t) async {
  await t.pumpAndSettle();
  expect(t.binding.transientCallbackCount, 0);
}

void main() {
  group('the new poll sheet', () {
    PollDraft? sent;

    Future<void> open(
      WidgetTester t, {
      bool still = false,
      TextDirection dir = TextDirection.ltr,
    }) async {
      t.view.physicalSize = const Size(720, 1600);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      quiet(t);
      sent = null;
      await t.pumpWidget(
        host(
          Builder(
            builder: (ctx) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async => sent = await showNewPollSheet(ctx),
              child: const SizedBox(width: 60, height: 60),
            ),
          ),
          still: still,
          dir: dir,
        ),
      );
      await t.tap(find.byType(GestureDetector).first);
      await t.pumpAndSettle();
    }

    Finder fields() => find.byType(TextField);

    // question, then three answers: a fourth empty one waits under them
    Future<void> fill(WidgetTester t) async {
      await t.enterText(fields().at(0), 'Dinner?');
      await t.enterText(fields().at(1), 'Ramen');
      await t.enterText(fields().at(2), 'Tacos');
      await t.pumpAndSettle();
      await t.enterText(fields().at(3), 'Soup');
      await t.pumpAndSettle();
    }

    Finder crosses() => find.bySemanticsLabel('Delete');

    testWidgets('an answer taken out folds away, then goes', (t) async {
      final h = t.ensureSemantics();
      await open(t);
      expect(crosses(), findsNothing);
      await fill(t);
      expect(fields(), findsNWidgets(5));
      expect(crosses(), findsNWidgets(3));
      final tacos = find.ancestor(
        of: find.text('Tacos'),
        matching: find.byType(SizeTransition),
      );
      final full = t.getSize(tacos.first).height;
      await t.tap(crosses().at(1));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(t.getSize(tacos.first).height, lessThan(full));
      expect(t.getSize(tacos.first).height, greaterThan(0));
      await settles(t);
      expect(find.text('Tacos'), findsNothing);
      expect(fields(), findsNWidgets(4));
      await t.tap(find.text('Send poll'));
      await t.pumpAndSettle();
      expect(sent!.options, ['Ramen', 'Soup']);
      h.dispose();
    });

    testWidgets('reduced motion: taken out at once', (t) async {
      final h = t.ensureSemantics();
      await open(t, still: true);
      await fill(t);
      await t.tap(crosses().at(1));
      await t.pump();
      await t.pump();
      // gone at once; the focus moved to the answer above it
      expect(find.text('Tacos'), findsNothing);
      h.dispose();
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('right to left: the way out sits on the left', (t) async {
      final h = t.ensureSemantics();
      await open(t, dir: TextDirection.rtl);
      await fill(t);
      final cross = t.getCenter(crosses().at(0)).dx;
      final word = t.getCenter(find.text('Ramen')).dx;
      expect(cross, lessThan(word));
      h.dispose();
      await t.pumpWidget(const SizedBox());
    });
  });

  group('the rolling figures', () {
    Widget roll(String text, double v, {bool still = false}) => host(
      RollText(text: text, value: v, style: const TextStyle(fontSize: 12)),
      still: still,
    );

    Offset slideOf(WidgetTester t, String text) {
      final s = t.widget<SlideTransition>(
        find
            .ancestor(
              of: find.text(text),
              matching: find.byType(SlideTransition),
            )
            .first,
      );
      return s.position.value;
    }

    testWidgets('a share that grows rolls up, one that shrinks down', (
      t,
    ) async {
      await t.pumpWidget(roll('40%', 0.4));
      await t.pumpWidget(roll('60%', 0.6));
      await t.pump(const Duration(milliseconds: 40));
      expect(slideOf(t, '60%').dy, greaterThan(0));
      await settles(t);
      await t.pumpWidget(roll('20%', 0.2));
      await t.pump(const Duration(milliseconds: 40));
      expect(slideOf(t, '20%').dy, lessThan(0));
      await settles(t);
      expect(find.text('60%'), findsNothing);
    });

    testWidgets('reduced motion: the figure only fades', (t) async {
      await t.pumpWidget(roll('40%', 0.4, still: true));
      await t.pumpWidget(roll('60%', 0.6, still: true));
      await t.pump(const Duration(milliseconds: 40));
      expect(
        find.descendant(
          of: find.byType(RollText),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
      await settles(t);
    });

    testWidgets('a vote on the card rolls its share', (t) async {
      quiet(t);
      const spec = PollSpec(options: ['Ramen', 'Tacos']);
      Widget card(Map<String, PollVote> votes) => host(
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
      );
      await t.pumpWidget(
        card({
          'me': const PollVote([0], 1),
          'a': const PollVote([1], 1),
        }),
      );
      await settles(t);
      expect(find.text('50%'), findsNWidgets(2));
      await t.pumpWidget(
        card({
          'me': const PollVote([0], 1),
          'a': const PollVote([1], 1),
          'b': const PollVote([0], 1),
        }),
      );
      await t.pump(const Duration(milliseconds: 40));
      expect(find.byType(RollText), findsWidgets);
      await settles(t);
      expect(find.text('50%'), findsNothing);
    });
  });
}
