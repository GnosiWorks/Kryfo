import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/tools_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/stroke_icon.dart';

Widget host(Widget child, {double scale = 1, bool still = false}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 640),
          textScaler: TextScaler.linear(scale),
          disableAnimations: still,
        ),
        child: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('card and tools appear in order', (t) async {
    await t.pumpWidget(host(const ToolsScreen(), still: true));
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    final ys = [
      for (final s in [
        'Photo cleaner',
        'Make a private QR code',
        'Lock a file',
        'Open a locked file',
      ])
        t.getTopLeft(find.text(s)).dy,
    ];
    expect(ys, [...ys]..sort());
  });

  testWidgets('taps reach callbacks, rows without one are inert', (t) async {
    final got = <String>[];
    await t.pumpWidget(
      host(
        ToolsScreen(
          onPickPhoto: () => got.add('photo'),
          onPickVideo: () => got.add('video'),
          onQr: () => got.add('qr'),
        ),
        still: true,
      ),
    );
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    await t.tap(find.text('Pick a photo'));
    await t.tap(find.text('Video'));
    await t.tap(find.text('Make a private QR code'));
    await t.ensureVisible(find.text('Lock a file'));
    await t.tap(find.text('Lock a file'));
    expect(got, ['photo', 'video', 'qr']);
  });

  testWidgets('no text uses text2 or text3', (t) async {
    await t.pumpWidget(host(const ToolsScreen(), still: true));
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    for (final w in t.widgetList<Text>(find.byType(Text))) {
      expect(w.style?.color, isNot(HaloColors.text2), reason: '${w.data}');
      expect(w.style?.color, isNot(HaloColors.text3), reason: '${w.data}');
    }
  });

  double contrast(Color x, Color y) {
    final a = x.computeLuminance(), b = y.computeLuminance();
    return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
  }

  test('the card\'s words hold their contrast in every accent and theme', () {
    addTearDown(() {
      HaloColors.setAccent(HaloAccent.yellow);
      HaloColors.setLight(false);
    });
    for (final light in [false, true]) {
      HaloColors.setLight(light);
      for (final accent in HaloAccent.values) {
        HaloColors.setAccent(accent);
        final why = '${accent.name} ${light ? 'light' : 'dark'}';
        for (final a in [0.04, 0.10]) {
          final ground = photoCardWash(a);
          expect(contrast(HaloColors.text, ground), greaterThan(4.5));
          expect(contrast(HaloColors.warm, ground), greaterThan(4.5));
          final button = Color.alphaBlend(photoButtonFill(), ground);
          expect(
            contrast(HaloColors.text, button),
            greaterThan(4.5),
            reason: why,
          );
          expect(
            contrast(HaloColors.amberText, button),
            greaterThan(3),
            reason: why,
          );
        }
      }
    }
  });

  BoxDecoration buttonLook(WidgetTester t, String label) =>
      t
              .widget<Container>(
                find
                    .ancestor(
                      of: find.text(label),
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .decoration!
          as BoxDecoration;

  for (final light in [false, true]) {
    testWidgets('the main button is a soft wash of the accent, '
        '${light ? 'light' : 'dark'}', (t) async {
      HaloColors.setLight(light);
      addTearDown(() => HaloColors.setLight(false));
      await t.pumpWidget(host(const ToolsScreen(), still: true));
      await t.pumpAndSettle(const Duration(milliseconds: 50));
      final main = buttonLook(t, 'Pick a photo');
      // a wash, never the solid block it was
      expect(main.color, photoButtonFill());
      expect(main.color!.a, lessThan(0.3));
      expect(main.gradient, isNull);
      final words = t.widget<Text>(find.text('Pick a photo'));
      expect(words.style!.color, HaloColors.text);
      // the quiet one is an outline in the page's ink
      final video = buttonLook(t, 'Video');
      expect(video.color, isNull);
      expect(t.widget<Text>(find.text('Video')).style!.color, HaloColors.text);
      // no glow under the card either
      final cards = [
        for (final c in t.widgetList<Container>(
          find.ancestor(
            of: find.text('Photo cleaner'),
            matching: find.byType(Container),
          ),
        ))
          if ((c.decoration as BoxDecoration?)?.gradient != null) c,
      ];
      expect(cards, hasLength(1));
      expect((cards.single.decoration! as BoxDecoration).boxShadow, isNull);
      expect(
        t.widget<Text>(find.text('Photo cleaner')).style!.color,
        HaloColors.text,
      );
    });
  }

  testWidgets('the card says photo cleaner and what it removes', (t) async {
    await t.pumpWidget(host(const ToolsScreen(), still: true));
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Photo cleaner'), findsOneWidget);
    expect(
      find.text(
        'Removes hidden info (metadata) like place, time and phone model',
      ),
      findsOneWidget,
    );
    expect(find.text('What does this photo know?'), findsNothing);
    expect(find.text('Place · phone · time'), findsNothing);
  });

  testWidgets('right to left: the card reads in arabic from the right', (
    t,
  ) async {
    setL10nLocale(const Locale('ar'));
    addTearDown(() => setL10nLocale(const Locale('en')));
    await t.pumpWidget(
      host(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: ToolsScreen(),
        ),
        still: true,
      ),
    );
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    final title = find.text('منظّف الصور');
    expect(title, findsOneWidget);
    expect(
      find.text(
        'يزيل المعلومات المخفية (البيانات الوصفية) مثل المكان والوقت وطراز الهاتف',
      ),
      findsOneWidget,
    );
    // the eye leads on the right, the title follows to its left
    final eye = find.byType(StrokeIcon).first;
    expect(t.getCenter(eye).dx, greaterThan(t.getCenter(title).dx));
    expect(t.getTopRight(title).dx, greaterThan(250));
    expect(t.takeException(), isNull);
  });

  for (final lang in ['en', 'de', 'ar']) {
    testWidgets(
      'largest text: the card\'s words and buttons show whole, $lang',
      (t) async {
        setL10nLocale(Locale(lang));
        addTearDown(() => setL10nLocale(const Locale('en')));
        await t.pumpWidget(
          host(
            Directionality(
              textDirection: lang == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: const ToolsScreen(),
            ),
            scale: 2,
            still: true,
          ),
        );
        await t.pumpAndSettle(const Duration(milliseconds: 50));
        expect(t.takeException(), isNull);
        for (final s in [
          l10n.toolsPhotoCleaner,
          l10n.toolsRemovesHiddenInfo,
          l10n.toolsPickAPhoto,
          l10n.toolsVideo,
        ]) {
          final p = t.renderObject<RenderParagraph>(find.text(s));
          expect(p.didExceedMaxLines, isFalse, reason: s);
        }
        // the buttons grow with their words instead of cutting them
        final button = t.getSize(
          find
              .ancestor(
                of: find.text(l10n.toolsPickAPhoto),
                matching: find.byType(Container),
              )
              .first,
        );
        final words = t.getSize(find.text(l10n.toolsPickAPhoto));
        expect(button.height, greaterThanOrEqualTo(words.height));
      },
    );
  }

  testWidgets('largest font fits a small phone by scrolling', (t) async {
    await t.pumpWidget(host(const ToolsScreen(), scale: 2, still: true));
    await t.pumpAndSettle(const Duration(milliseconds: 50));
    expect(t.takeException(), isNull);
  });

  testWidgets('reduced motion: the dot holds still', (t) async {
    await t.pumpWidget(host(const ToolsScreen(), still: true));
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(t.hasRunningAnimations, false);
  });

  testWidgets('the dot pulses twice as the tab opens, then stops', (t) async {
    await t.pumpWidget(host(const ToolsScreen()));
    await t.pump(const Duration(milliseconds: 600));
    expect(t.hasRunningAnimations, isTrue);
    await t.pump(const Duration(seconds: 5));
    expect(t.hasRunningAnimations, isFalse);
    // at rest it is lit, not caught mid-fade
    final dot = t.widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(ToolsScreen),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(dot.opacity.value, 1);
  });

  double tileScale(WidgetTester t, String title) => t
      .widget<AnimatedScale>(
        find
            .descendant(
              of: find.ancestor(
                of: find.text(title),
                matching: find.byType(GestureDetector),
              ),
              matching: find.byType(AnimatedScale),
            )
            .first,
      )
      .scale;

  Offset nudge(WidgetTester t, String title) => t
      .widget<AnimatedSlide>(
        find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(GestureDetector),
          ),
          matching: find.byType(AnimatedSlide),
        ),
      )
      .offset;

  testWidgets('a pressed row tints, dips and springs back', (t) async {
    var taps = 0;
    await t.pumpWidget(host(ToolsScreen(onQr: () => taps++)));
    await t.pump(const Duration(milliseconds: 500));
    const title = 'Make a private QR code';
    final g = await t.startGesture(t.getCenter(find.text(title)));
    await t.pump(const Duration(milliseconds: 120));
    expect(tileScale(t, title), lessThan(1));
    expect(nudge(t, title).dx, greaterThan(0));
    await g.up();
    await t.pump();
    expect(taps, 1);
    expect(tileScale(t, title), 1);
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(seconds: 5));
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('right to left: the chevron leans the other way', (t) async {
    await t.pumpWidget(
      host(
        Directionality(
          textDirection: TextDirection.rtl,
          child: ToolsScreen(onQr: () {}),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 500));
    const title = 'Make a private QR code';
    final g = await t.startGesture(t.getCenter(find.text(title)));
    await t.pump(const Duration(milliseconds: 120));
    expect(nudge(t, title).dx, lessThan(0));
    await g.up();
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('reduced motion: a press tints but nothing moves', (t) async {
    await t.pumpWidget(host(ToolsScreen(onQr: () {}), still: true));
    await t.pump(const Duration(milliseconds: 500));
    const title = 'Make a private QR code';
    final g = await t.startGesture(t.getCenter(find.text(title)));
    await t.pump(const Duration(milliseconds: 120));
    expect(tileScale(t, title), 1);
    expect(nudge(t, title), Offset.zero);
    await g.up();
    await t.pump(const Duration(milliseconds: 400));
  });

  testWidgets('the card buttons press like the rest of the app', (t) async {
    var picks = 0;
    await t.pumpWidget(host(ToolsScreen(onPickPhoto: () => picks++)));
    await t.pump(const Duration(milliseconds: 500));
    final g = await t.startGesture(t.getCenter(find.text('Pick a photo')));
    // the scroll view has the pointer too: the press shows once it is a tap
    await t.pump(const Duration(milliseconds: 150));
    final pressed = t.widget<AnimatedScale>(
      find
          .ancestor(
            of: find.text('Pick a photo'),
            matching: find.byType(AnimatedScale),
          )
          .first,
    );
    expect(pressed.scale, lessThan(1));
    await g.up();
    expect(picks, 1);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('a screen reader can press every row', (t) async {
    final h = t.ensureSemantics();
    var taps = 0;
    await t.pumpWidget(
      host(ToolsScreen(onQr: () => taps++, onPickVideo: () => taps++)),
    );
    // the rows have faded in once their stagger has played
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    for (final label in [
      RegExp('^Make a private QR code'),
      RegExp(r'^Video$'),
    ]) {
      final node = t.getSemantics(find.bySemanticsLabel(label));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      t.semantics.tap(find.semantics.byLabel(label));
    }
    expect(taps, 2);
    await t.pump(const Duration(seconds: 6));
    h.dispose();
  });
}
