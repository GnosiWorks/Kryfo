// SPDX-License-Identifier: GPL-3.0-or-later
// a sticker in a chat: its size and pill, the pop and the reduced-motion
// fade, the tile for one this version lacks, the flight from the sheet,
// "Sticker" wherever a sticker is quoted, and each pack's stickers drawn
// from that pack.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/stickers/sticker_bubble.dart';
import 'package:kryfo/stickers/sticker_flight.dart';
import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:kryfo/stickers/sticker_view.dart';
import 'package:kryfo/stickers/sticker_wire.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/pins.dart';

import 'sticker_test_util.dart';

Widget _host(Widget child, {bool reduce = false}) => MaterialApp(
  theme: buildHaloTheme(),
  builder: (c, page) => MediaQuery(
    data: MediaQuery.of(c).copyWith(disableAnimations: reduce),
    child: page!,
  ),
  home: Scaffold(
    body: Align(
      alignment: Alignment.bottomRight,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

// each element above a render object reports it again: once each
List<RenderSticker> _boxes(WidgetTester t) =>
    t.allRenderObjects.whereType<RenderSticker>().toSet().toList();

Rect _rectOf(RenderBox b) => b.localToGlobal(Offset.zero) & b.size;

Future<void> _frames(WidgetTester t, int n) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

double _scale(WidgetTester t) =>
    t.widget<ScaleTransition>(find.byKey(kStickerPopKey)).scale.value;

void main() {
  final lib = useLibrary();
  final pack = lib.pack('fokia')!;
  final hi = pack.sticker(1)!;
  final wave = StickerWire.of(pack, hi);
  final remix = lib.pack('fokiaremix')!;
  final violin = remix.sticker(36)!;
  final tiny = StickerWire.of(remix, violin);

  testWidgets('168 across, no bubble, the pill at the bottom end', (t) async {
    await t.pumpWidget(
      _host(
        StickerBubble(
          wire: wave,
          emoji: hi.emoji,
          isOut: true,
          stamp: const StickerStamp(
            time: '12:04',
            sent: true,
            delivered: 'Delivered',
          ),
        ),
      ),
    );
    final box = _boxes(t).single;
    expect(box.size, const Size.square(kStickerBubble));
    final sticker = _rectOf(box);
    final time = t.getRect(find.text('12:04'));
    expect(find.text('✓'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    // inside the sticker's square, in its bottom end corner
    expect(sticker.contains(time.center), true);
    expect(sticker.bottom - time.bottom, lessThan(12));
    final end = t.getRect(find.text('Delivered')).right;
    expect(end, lessThan(sticker.right));
    expect(end, greaterThan(sticker.right - 16));
    // nothing painted behind it
    expect(
      find.descendant(
        of: find.byType(StickerBubble),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color == HaloColors.amber,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('a failed one says so in its pill, instead of the time', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        StickerBubble(
          wire: wave,
          emoji: hi.emoji,
          isOut: true,
          stamp: const StickerStamp(time: '12:04', alert: 'Failed'),
        ),
      ),
    );
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('12:04'), findsNothing);
  });

  testWidgets('a screen reader hears "Sticker" and its emoji', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(
      _host(StickerBubble(wire: wave, emoji: hi.emoji, isOut: false)),
    );
    expect(find.bySemanticsLabel('Sticker ${hi.emoji}'), findsOneWidget);
    h.dispose();
  });

  testWidgets('reduced motion: the still, and nothing runs', (t) async {
    await t.pumpWidget(
      _host(
        StickerBubble(wire: wave, emoji: hi.emoji, isOut: false),
        reduce: true,
      ),
    );
    final before = StickerView.frames;
    await _frames(t, 20);
    expect(StickerView.frames, before);
    expect(t.binding.hasScheduledFrame, false);
    expect(_boxes(t).single.time, -1);
  });

  testWidgets('a chat sticker rests after its loops, a tap plays it again', (
    t,
  ) async {
    await t.pumpWidget(
      _host(StickerBubble(wire: wave, emoji: hi.emoji, isOut: false)),
    );
    // an old message waits out its phase, then plays its loops
    await _frames(t, ((kStickerChatLoops + 1) * hi.loopMs / 16).ceil() + 10);
    expect(_boxes(t).single.time, -1);
    expect(t.binding.hasScheduledFrame, false);
    final rested = StickerView.frames;
    await _frames(t, 60);
    expect(StickerView.frames, rested);

    await t.tap(find.byType(StickerBubble));
    await _frames(t, 10);
    expect(StickerView.frames, greaterThan(rested + 5));
    expect(_boxes(t).single.time, greaterThan(0));
  });

  testWidgets('reduced motion: an arrival fades in, with no pop', (t) async {
    await t.pumpWidget(
      _host(
        StickerBubble(
          wire: wave,
          emoji: hi.emoji,
          isOut: false,
          arriving: true,
        ),
        reduce: true,
      ),
    );
    expect(_scale(t), 1);
    await t.pump(const Duration(milliseconds: 60));
    final fade = t.widget<FadeTransition>(
      find.descendant(
        of: find.byType(StickerBubble),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    await t.pump(const Duration(milliseconds: 100));
    expect(fade.opacity.value, 1);
    expect(t.binding.hasScheduledFrame, false);
    expect(_boxes(t).single.time, -1);
  });

  testWidgets('an arrival pops from .72, then starts its loop', (t) async {
    await t.pumpWidget(
      _host(
        StickerBubble(
          wire: wave,
          emoji: hi.emoji,
          isOut: false,
          arriving: true,
        ),
      ),
    );
    expect(_scale(t), closeTo(0.72, 0.001));
    // the still while it pops
    await _frames(t, 3);
    expect(_scale(t), greaterThan(0.72));
    expect(_boxes(t).single.time, -1);
    // the house spring is done in well under half a second
    await _frames(t, 25);
    expect(_scale(t), 1);
    await _frames(t, 10);
    expect(_boxes(t).single.time, greaterThan(0));
  });

  testWidgets('one this version lacks is a tile with its emoji', (t) async {
    final newer = StickerWire.parse('fokia:999:3')!;
    await t.pumpWidget(
      _host(
        StickerBubble(
          wire: newer,
          emoji: '🦊',
          isOut: false,
          stamp: const StickerStamp(time: '09:30'),
        ),
      ),
    );
    expect(_boxes(t), isEmpty);
    expect(t.getSize(find.byType(StickerPlaceholder)), const Size.square(120));
    expect(find.text('🦊'), findsOneWidget);
    expect(find.text('Sticker'), findsOneWidget);
    expect(find.text('From a newer Kryfo'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);

    // another pack, and words where the emoji would be: no emoji shown
    await t.pumpWidget(
      _host(
        StickerBubble(
          wire: StickerWire.parse('otter:2:1')!,
          emoji: 'hi there',
          isOut: false,
        ),
      ),
    );
    expect(find.text('hi there'), findsNothing);
    expect(find.text('Sticker'), findsOneWidget);
  });

  testWidgets('hidden until its flight lands, then goes on from there', (
    t,
  ) async {
    final landing = StickerLanding();
    await t.pumpWidget(
      _host(
        StickerBubble(
          wire: wave,
          emoji: hi.emoji,
          isOut: true,
          landing: landing,
        ),
      ),
    );
    expect(_boxes(t), isEmpty);
    // the box is laid out, so the flight can find it
    expect(landing.rect?.size, const Size.square(kStickerBubble));

    landing.land(900);
    await t.pump();
    expect(_boxes(t).single.time, closeTo(900, 0.001));
    await t.pump(const Duration(milliseconds: 90));
    final fade = t.widget<FadeTransition>(
      find.descendant(
        of: find.byType(StickerBubble),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fade.opacity.value, 1);
  });

  testWidgets('the flight arcs up from the cell and hands over', (t) async {
    final landing = StickerLanding();
    late BuildContext page;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            page = c;
            return Scaffold(
              body: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: StickerBubble(
                    wire: wave,
                    emoji: hi.emoji,
                    isOut: true,
                    landing: landing,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    const from = Rect.fromLTWH(40, 60, 72, 72);
    final to = landing.rect!;
    var gone = false;
    flySticker(
      page,
      sticker: hi,
      from: from,
      at: 400,
      landing: landing,
      fallback: () => to,
      onGone: () => gone = true,
    );
    await t.pump();
    // the flight starts where the cell was, already playing
    expect(_rectOf(_boxes(t).single), from);
    var lift = 0.0;
    for (var i = 0; i < 40 && !landing.landed.value; i++) {
      await t.pump(const Duration(milliseconds: 16));
      if (landing.landed.value) break;
      final c = _rectOf(_boxes(t).single).center;
      final k = (c.dx - from.center.dx) / (to.center.dx - from.center.dx);
      final chord = from.center.dy + k * (to.center.dy - from.center.dy);
      lift = math.max(lift, chord - c.dy);
    }
    expect(landing.landed.value, true);
    expect(lift, greaterThan(8));
    expect(landing.at, greaterThanOrEqualTo(400));

    await _frames(t, 8);
    expect(gone, true);
    // only the bubble's own copy is left, where the flight came down
    final left = _boxes(t).single;
    expect(_rectOf(left), to);
    expect(left.time, greaterThanOrEqualTo(0));
  });

  testWidgets('a quote of a sticker says "Sticker" by its still', (t) async {
    await t.pumpWidget(
      _host(
        StickerQuoteCard(
          author: 'You',
          text: 'Sticker',
          sticker: wave,
          onTap: () {},
        ),
      ),
    );
    expect(find.text('Sticker'), findsOneWidget);
    expect(find.text(hi.emoji), findsNothing);
    final thumb = _boxes(t).single;
    expect(thumb.size, const Size.square(kStickerThumb));
    expect(thumb.time, -1);
  });

  testWidgets('a remix sticker draws from its own pack', (t) async {
    expect(tiny.value, 'fokiaremix:36:1');
    await t.pumpWidget(
      _host(StickerBubble(wire: tiny, emoji: violin.emoji, isOut: false)),
    );
    expect(identical(_boxes(t).single.sticker, violin), true);
    expect(find.byType(StickerPlaceholder), findsNothing);

    // its quote and a reply's thumbnail too
    await t.pumpWidget(
      _host(StickerQuoteCard(author: 'You', text: 'Sticker', sticker: tiny)),
    );
    expect(identical(_boxes(t).single.sticker, violin), true);
    expect(_boxes(t).single.size, const Size.square(kStickerThumb));
  });

  testWidgets('an app with only fokia shows a remix sticker as the tile', (
    t,
  ) async {
    StickerLibrary.use(StickerLibrary([loadPack()]));
    addTearDown(useLibrary);
    await t.pumpWidget(
      _host(
        StickerBubble(
          wire: tiny,
          emoji: '🎻',
          isOut: false,
          stamp: const StickerStamp(time: '09:30'),
        ),
      ),
    );
    expect(_boxes(t), isEmpty);
    expect(t.getSize(find.byType(StickerPlaceholder)), const Size.square(120));
    expect(find.text('🎻'), findsOneWidget);
    expect(find.text('Sticker'), findsOneWidget);
    expect(find.text('From a newer Kryfo'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);

    // a quote of it: the sticker glyph, no still
    await t.pumpWidget(
      _host(StickerQuoteCard(author: 'You', text: 'Sticker', sticker: tiny)),
    );
    expect(_boxes(t), isEmpty);
    expect(find.text('Sticker'), findsOneWidget);
  });

  testWidgets('a pinned sticker is listed as "Sticker"', (t) async {
    late BuildContext page;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            page = c;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    final pin = PinEntry(
      uid: 'u1',
      author: 'You',
      authorSeed: 'seed',
      when: DateTime(2026, 9, 26, 12, 4),
      text: hi.emoji,
      sticker: wave,
    );
    expect(pin.preview, 'Sticker');
    showPinsSheet(
      page,
      load: () async => [pin],
      onJump: (_) {},
      onUnpin: (_) async {},
    );
    await _frames(t, 30);
    expect(find.text('Sticker'), findsOneWidget);
    expect(find.text(hi.emoji), findsNothing);
    expect(_boxes(t).single.size, const Size.square(kStickerThumb));
  });
}
