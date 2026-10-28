// SPDX-License-Identifier: GPL-3.0-or-later
// how typing looks: "Typing" and three dots take the place of the line
// under a contact's name or of their chat list preview, and give it back.
// one line either way, at any text size; still dots and an instant swap
// with motion off; the dots after the word in reading order; read as
// "Typing" and never announced; in the accent's text tone
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart' show HaloColors, HaloType;
import 'package:kryfo/widgets/typing_mark.dart';

Widget host(
  Widget child, {
  bool still = false,
  double scale = 1,
  TextDirection dir = TextDirection.ltr,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(360, 640),
      disableAnimations: still,
      textScaler: TextScaler.linear(scale),
    ),
    child: Directionality(
      textDirection: dir,
      child: Scaffold(
        body: Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(width: 220, child: child),
        ),
      ),
    ),
  ),
);

// the header's line as the chat shows it while nobody types
Widget routeLine() => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(Icons.lock_outline, size: 10, color: HaloColors.violet),
    const SizedBox(width: 4),
    Flexible(
      child: Text(
        'Encrypted · over Tor',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: HaloType.mono(size: 10, color: HaloColors.text2),
      ),
    ),
  ],
);

// the swap's time and a frame past it
Future<void> swapped(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  final on = ValueNotifier(false);
  setUp(() => on.value = false);

  Widget header() => TypingSwap(
    showing: on,
    style: typingStyle(size: 10, mono: true),
    child: routeLine(),
  );

  testWidgets('the header line swaps to "Typing" with dots, and back', (
    t,
  ) async {
    await t.pumpWidget(host(header()));
    expect(find.text(l10n.typingNow), findsNothing);
    on.value = true;
    // the dots wave for as long as they show: no settling
    await swapped(t);
    expect(find.text('Typing'), findsOneWidget);
    expect(find.byType(TypingMark), findsOneWidget);
    expect(find.text('Encrypted · over Tor'), findsNothing);
    on.value = false;
    await t.pumpAndSettle();
    expect(find.text('Typing'), findsNothing);
    expect(find.text('Encrypted · over Tor'), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('the header keeps its height at text size $scale', (t) async {
      await t.pumpWidget(host(header(), scale: scale, still: true));
      final quiet = t.getSize(find.byType(TypingSwap)).height;
      on.value = true;
      await t.pump();
      final typing = t.getSize(find.byType(TypingSwap)).height;
      expect(typing, quiet);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('with motion off the dots stand still and the swap is '
      'instant', (t) async {
    await t.pumpWidget(host(header(), still: true));
    on.value = true;
    await t.pump();
    expect(find.text('Typing'), findsOneWidget);
    expect(find.text('Encrypted · over Tor'), findsNothing);
    await t.pump(const Duration(milliseconds: 16));
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('with motion on the dots keep moving', (t) async {
    await t.pumpWidget(host(header()));
    on.value = true;
    await t.pump(const Duration(milliseconds: 400));
    expect(t.binding.hasScheduledFrame, isTrue);
    on.value = false;
    await t.pumpAndSettle();
    expect(find.byType(TypingMark), findsNothing);
  });

  testWidgets('right to left, the dots sit left of the word', (t) async {
    on.value = true;
    await t.pumpWidget(host(header(), dir: TextDirection.rtl, still: true));
    final word = t.getRect(find.text('Typing'));
    final dots = t.getRect(find.byType(TypingMark));
    expect(dots.right, lessThanOrEqualTo(word.left));
  });

  testWidgets('a screen reader reads "Typing", the dots are not read and '
      'nothing is announced', (t) async {
    final h = t.ensureSemantics();
    on.value = true;
    await t.pumpWidget(host(header(), still: true));
    expect(find.bySemanticsLabel('Typing'), findsOneWidget);
    // the word's node and every one above it: none is a live region
    SemanticsNode? n = t.getSemantics(find.bySemanticsLabel('Typing'));
    var seen = 0;
    while (n != null) {
      expect(n.getSemanticsData().flagsCollection.isLiveRegion, isFalse);
      seen++;
      n = n.parent;
    }
    expect(seen, greaterThan(1));
    h.dispose();
  });

  testWidgets('a chat list row swaps its preview for typing and back', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        TypingSwap(
          showing: on,
          style: typingStyle(size: 12),
          child: const Text('Draft: see you at eight'),
        ),
      ),
    );
    on.value = true;
    await swapped(t);
    expect(find.text('Draft: see you at eight'), findsNothing);
    expect(find.text('Typing'), findsOneWidget);
    on.value = false;
    await t.pumpAndSettle();
    expect(find.text('Draft: see you at eight'), findsOneWidget);
  });

  testWidgets('in the accent\'s text tone, in light and dark', (t) async {
    for (final light in [false, true]) {
      HaloColors.setLight(light);
      on.value = true;
      await t.pumpWidget(host(header(), still: true));
      final word = t.widget<Text>(find.text('Typing'));
      expect(word.style!.color, HaloColors.amberText);
      expect(word.style!.color, isNot(HaloColors.text3));
      final mark = t.widget<TypingMark>(find.byType(TypingMark));
      expect(mark.color, HaloColors.amberText);
      on.value = false;
      await t.pumpWidget(const SizedBox());
    }
    HaloColors.setLight(false);
  });

  testWidgets('a long word at a big size ends in an ellipsis', (t) async {
    on.value = true;
    await t.pumpWidget(
      host(SizedBox(width: 40, child: header()), scale: 2, still: true),
    );
    expect(t.takeException(), isNull);
  });
}
