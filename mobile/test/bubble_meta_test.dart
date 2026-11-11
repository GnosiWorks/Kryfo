// SPDX-License-Identifier: GPL-3.0-or-later
// a bubble's time and tick sit at the end of its last line when they fit,
// else on a line of their own at the end; in either direction and at large
// text. only the newest of ours spells Delivered, every one says it to a
// screen reader. a group run ends where the next sender, day or minute does
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/screens/group_chat_screen.dart' show endsSenderRun;
import 'package:kryfo/widgets/bubble_meta.dart';
import 'package:kryfo/widgets/chat_parts.dart';
import 'package:kryfo/widgets/tick_mark.dart';

const _meta = SizedBox(key: ValueKey('meta'), width: 40, height: 12);

Widget _host(
  String text, {
  double width = 200,
  TextDirection dir = TextDirection.ltr,
  double scale = 1,
  Widget meta = _meta,
  Widget? below,
}) => MaterialApp(
  builder: (ctx, c) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(scale)),
    child: c!,
  ),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: MetaFlow(
            textDirection: dir,
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MetaAnchor(
                  child: Text(
                    text,
                    textDirection: dir,
                    style: const TextStyle(fontSize: 14, height: 1.2),
                  ),
                ),
                ?below,
              ],
            ),
            meta: meta,
          ),
        ),
      ),
    ),
  ),
);

RenderMetaFlow _flow(WidgetTester t) =>
    t.renderObject<RenderMetaFlow>(find.byType(MetaFlow));

void main() {
  group('meta flow', () {
    testWidgets('a short line keeps the meta on it', (t) async {
      await t.pumpWidget(_host('Hi'));
      expect(_flow(t).inline, isTrue);
      final text = t.getRect(find.text('Hi'));
      final meta = t.getRect(find.byKey(const ValueKey('meta')));
      // one line high, the meta after the words, level with their foot
      expect(t.getSize(find.byType(MetaFlow)).height, text.height);
      expect(meta.left, greaterThanOrEqualTo(text.right));
      expect(meta.bottom, text.bottom);
    });

    testWidgets('a full last line sends it under', (t) async {
      // the test font is square: 14 of 14 px fill 196 of 200
      await t.pumpWidget(_host('abcdefghijklmn'));
      expect(_flow(t).inline, isFalse);
      final text = t.getRect(find.byType(Text));
      final meta = t.getRect(find.byKey(const ValueKey('meta')));
      expect(meta.top, greaterThanOrEqualTo(text.bottom));
      // at the end
      expect(meta.right, t.getRect(find.byType(MetaFlow)).right);
    });

    testWidgets('long text with a short last line reflows around it', (
      t,
    ) async {
      await t.pumpWidget(
        _host('This is a longer message that wraps onto a second line ok'),
      );
      expect(_flow(t).inline, isTrue);
      final text = t.getRect(find.byType(Text));
      final meta = t.getRect(find.byKey(const ValueKey('meta')));
      expect(meta.bottom, text.bottom);
      expect(t.getSize(find.byType(MetaFlow)).height, text.height);
    });

    testWidgets('right to left: the meta takes the left end', (t) async {
      await t.pumpWidget(_host('مرحبا', dir: TextDirection.rtl));
      expect(_flow(t).inline, isTrue);
      final text = t.getRect(find.byType(Text));
      final meta = t.getRect(find.byKey(const ValueKey('meta')));
      expect(meta.right, lessThanOrEqualTo(text.left + 0.5));
      expect(meta.left, t.getRect(find.byType(MetaFlow)).left);
    });

    testWidgets('right to left, full line: under it, at the left', (t) async {
      await t.pumpWidget(_host('مممممممممممممم', dir: TextDirection.rtl));
      expect(_flow(t).inline, isFalse);
      final flow = t.getRect(find.byType(MetaFlow));
      final text = t.getRect(find.byType(Text));
      final meta = t.getRect(find.byKey(const ValueKey('meta')));
      expect(meta.left, flow.left);
      expect(meta.top, greaterThanOrEqualTo(text.bottom));
    });

    testWidgets('large text: the fit uses the scaled words', (t) async {
      await t.pumpWidget(_host('Good morning to', width: 300));
      expect(_flow(t).inline, isTrue);
      await t.pumpWidget(_host('Good morning to', width: 300, scale: 2));
      expect(_flow(t).inline, isFalse);
      expect(t.takeException(), isNull);
    });

    testWidgets('something under the words sends the meta under it', (t) async {
      await t.pumpWidget(
        _host('Hi', below: const SizedBox(width: 100, height: 30)),
      );
      expect(_flow(t).inline, isFalse);
    });

    testWidgets('no meta: the body alone, no gap', (t) async {
      await t.pumpWidget(_host('Hi', meta: const SizedBox.shrink()));
      expect(
        t.getSize(find.byType(MetaFlow)).height,
        t.getSize(find.text('Hi')).height,
      );
    });

    testWidgets('inside an intrinsic width bubble a short text stays one '
        'line', (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MetaFlow(
                        body: const MetaAnchor(child: Text('Ok see you then')),
                        meta: _meta,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(_flow(t).inline, isTrue);
      expect(t.getSize(find.byType(MetaFlow)).width, lessThan(260));
    });
  });

  group('delivered word', () {
    Widget tick({required bool delivered, required bool word}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SentTick(
            delivered: delivered,
            deliveredLabel: 'Delivered',
            word: word,
            color: Colors.black,
            labelStyle: const TextStyle(fontSize: 9),
          ),
        ),
      ),
    );

    testWidgets('only the newest spells it; older ones keep the tick', (
      t,
    ) async {
      await t.pumpWidget(tick(delivered: true, word: true));
      expect(find.text('Delivered'), findsOneWidget);
      // a newer one was delivered: the word folds back into the tick
      await t.pumpWidget(tick(delivered: true, word: false));
      await t.pumpAndSettle();
      expect(find.text('Delivered'), findsNothing);
      expect(find.byType(TickMark), findsOneWidget);
    });

    testWidgets('a screen reader hears Delivered on every one, once', (
      t,
    ) async {
      final sem = t.ensureSemantics();
      await t.pumpWidget(tick(delivered: true, word: false));
      expect(find.bySemanticsLabel('Delivered'), findsOneWidget);
      await t.pumpWidget(tick(delivered: true, word: true));
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('Delivered'), findsOneWidget);
      sem.dispose();
    });
  });

  group('group runs', () {
    final at = DateTime(2026, 11, 11, 12);
    test('the same sender within two minutes goes on', () {
      expect(
        endsSenderRun(
          sender: 'a',
          out: false,
          when: at,
          next: (
            sender: 'a',
            out: false,
            when: at.add(const Duration(seconds: 60)),
          ),
        ),
        isFalse,
      );
    });
    test('another sender, ours, a gap or a new day ends it', () {
      bool ends(({String sender, bool out, DateTime when})? n) =>
          endsSenderRun(sender: 'a', out: false, when: at, next: n);
      expect(ends(null), isTrue);
      expect(ends((sender: 'b', out: false, when: at)), isTrue);
      expect(ends((sender: 'me', out: true, when: at)), isTrue);
      expect(
        ends((
          sender: 'a',
          out: false,
          when: at.add(const Duration(minutes: 3)),
        )),
        isTrue,
      );
      expect(
        ends((sender: 'a', out: false, when: DateTime(2026, 11, 12, 0, 0, 30))),
        isTrue,
      );
    });
    test('ours run on whoever this phone is', () {
      expect(
        endsSenderRun(
          sender: 'x',
          out: true,
          when: at,
          next: (sender: 'y', out: true, when: at),
        ),
        isFalse,
      );
    });
  });
}
