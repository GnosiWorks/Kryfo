// SPDX-License-Identifier: GPL-3.0-or-later
// an accent switch reaches every widget on screen at once, const ones too,
// is kept for the next start, and the appearance screen shows it on a
// small chat as it lands
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/atmosphere.dart' show AtmosphereWash;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show appState, themeRevision;
import 'package:kryfo/screens/appearance_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/wallpaper.dart' show ChatWall;
import 'package:kryfo/widgets/halo_buttons.dart';
import 'package:kryfo/widgets/halo_rows.dart';
import 'package:kryfo/widgets/theme_refresh.dart';

// a const widget drawn in the accent
class _Probe extends StatelessWidget {
  const _Probe();
  @override
  Widget build(BuildContext context) =>
      ColoredBox(key: const ValueKey('probe'), color: HaloColors.amber);
}

class _Rebuilds extends StatefulWidget {
  final Widget child;
  const _Rebuilds({super.key, required this.child});
  @override
  State<_Rebuilds> createState() => _RebuildsState();
}

class _RebuildsState extends State<_Rebuilds> {
  void again() => setState(() {});
  @override
  Widget build(BuildContext context) => widget.child;
}

Color _probe(WidgetTester t) =>
    t.widget<ColoredBox>(find.byKey(const ValueKey('probe'))).color;

Color _rowIcon(WidgetTester t) => t
    .widget<Icon>(
      find.descendant(
        of: find.byType(HaloRow),
        matching: find.byIcon(Icons.palette_outlined),
      ),
    )
    .color!;

const _rowAndProbe = Column(
  children: [
    SizedBox(width: 40, height: 40, child: _Probe()),
    HaloRow(label: 'Accent colour', icon: Icons.palette_outlined),
  ],
);

void main() {
  tearDown(() {
    HaloColors.setLight(false);
    HaloColors.setAccent(HaloAccent.yellow);
  });

  testWidgets('a const widget keeps the old accent on a plain rebuild', (
    t,
  ) async {
    final key = GlobalKey<_RebuildsState>();
    await t.pumpWidget(
      MaterialApp(
        home: Material(
          child: _Rebuilds(key: key, child: _rowAndProbe),
        ),
      ),
    );
    final before = HaloColors.amber;
    HaloColors.setAccent(HaloAccent.velvet);
    key.currentState!.again();
    await t.pump();
    // the trap the refresh is there for
    expect(_probe(t), before);
    expect(_rowIcon(t), before);
  });

  for (final light in [false, true]) {
    testWidgets('every widget below the refresh takes the new accent, '
        '${light ? 'light' : 'dark'}', (t) async {
      HaloColors.setLight(light);
      final rev = ValueNotifier(0);
      await t.pumpWidget(
        ThemeRefresh(
          revision: rev,
          child: const MaterialApp(home: Material(child: _rowAndProbe)),
        ),
      );
      expect(_probe(t), HaloAccent.yellow.tones(light).accent);
      for (final a in [HaloAccent.velvet, HaloAccent.lime, HaloAccent.grey]) {
        HaloColors.setAccent(a);
        rev.value++;
        await t.pump();
        expect(_probe(t), a.tones(light).accent, reason: a.name);
        expect(_rowIcon(t), a.tones(light).accent, reason: a.name);
      }
    });
  }

  testWidgets('a button eases to the new accent', (t) async {
    final rev = ValueNotifier(0);
    await t.pumpWidget(
      ThemeRefresh(
        revision: rev,
        child: MaterialApp(
          home: Material(
            child: Center(
              child: HaloPrimaryButton(label: 'Reply', onTap: () {}),
            ),
          ),
        ),
      ),
    );
    Color fill() =>
        (t.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration!
                as BoxDecoration)
            .color!;
    HaloColors.setAccent(HaloAccent.blue);
    rev.value++;
    await t.pumpAndSettle();
    expect(fill(), HaloAccent.blue.dark.accent);
    final text = t.widget<Text>(find.text('Reply'));
    expect(text.style!.color, HaloAccent.blue.dark.on);
  });

  group('kept', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test(
      'a pick is stored for the whole phone and read back at start',
      () async {
        final rev = themeRevision.value;
        await appState.setAccent(HaloAccent.purple);
        expect(themeRevision.value, rev + 1);
        expect(
          await const FlutterSecureStorage().read(key: 'theme_accent'),
          'purple',
        );
        HaloColors.setAccent(HaloAccent.yellow);
        await appState.loadThemePref();
        expect(HaloColors.accent, HaloAccent.purple);
        // the same pick again changes nothing and wakes nothing
        await appState.setAccent(HaloAccent.purple);
        expect(themeRevision.value, rev + 1);
      },
    );

    test(
      'nothing stored, or a name this version does not know: yellow',
      () async {
        HaloColors.setAccent(HaloAccent.blue);
        await appState.loadThemePref();
        expect(HaloColors.accent, HaloAccent.yellow);
        FlutterSecureStorage.setMockInitialValues({'theme_accent': 'teal'});
        HaloColors.setAccent(HaloAccent.blue);
        await appState.loadThemePref();
        expect(HaloColors.accent, HaloAccent.yellow);
      },
    );
  });

  group('the appearance screen', () {
    Future<ValueNotifier<int>> open(
      WidgetTester t, {
      bool still = false,
      TextDirection dir = TextDirection.ltr,
    }) async {
      final rev = ValueNotifier(0);
      await t.pumpWidget(
        ThemeRefresh(
          revision: rev,
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(400, 800),
                disableAnimations: still,
              ),
              child: Directionality(
                textDirection: dir,
                child: AppearanceScreen(
                  readDefault: () async => ChatWall.none,
                  onPick: (a) async {
                    HaloColors.setAccent(a);
                    rev.value++;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      return rev;
    }

    // the preview's own bubble: the one with the sample answer
    Color mine(WidgetTester t) {
      final box = t.widget<Container>(
        find
            .ancestor(
              of: find.text(l10n.appearanceSampleOut),
              matching: find.byType(Container),
            )
            .first,
      );
      return (box.decoration! as BoxDecoration).color!;
    }

    testWidgets('a tap on a colour eases the preview to it', (t) async {
      await open(t);
      expect(mine(t), HaloAccent.yellow.dark.accent);
      await t.tap(find.text(l10n.accentVelvet));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      // on its way
      expect(mine(t), isNot(HaloAccent.yellow.dark.accent));
      expect(mine(t), isNot(HaloAccent.velvet.dark.accent));
      await t.pumpAndSettle();
      expect(mine(t), HaloAccent.velvet.dark.accent);
      expect(HaloColors.accent, HaloAccent.velvet);
    });

    testWidgets('reduced motion: the preview changes at once', (t) async {
      await open(t, still: true);
      await t.tap(find.text(l10n.accentLime));
      await t.pump();
      await t.pump();
      expect(mine(t), HaloAccent.lime.dark.accent);
    });

    testWidgets('each colour is a button that says its name and whether it '
        'is in use; the preview reads as one picture', (t) async {
      final h = t.ensureSemantics();
      await open(t);
      for (final a in HaloAccent.values) {
        final node = t.getSemantics(find.text(accentName(a)));
        expect(node.label, accentName(a));
        expect(node.flagsCollection.isButton, isTrue);
        expect(
          node.flagsCollection.isSelected,
          a == HaloAccent.yellow ? Tristate.isTrue : Tristate.isFalse,
        );
        expect(
          node.flagsCollection.isInMutuallyExclusiveGroup,
          isTrue,
          reason: a.name,
        );
      }
      expect(find.bySemanticsLabel(l10n.appearancePreview), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.appearanceSampleOut), findsNothing);
      h.dispose();
    });

    testWidgets('every colour is at least 44 across to tap', (t) async {
      await open(t);
      for (final a in HaloAccent.values) {
        final size = t.getSize(
          find.ancestor(
            of: find.text(accentName(a)),
            matching: find.byType(AccentSwatch),
          ),
        );
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('right to left: their bubble on the right, yours on the left', (
      t,
    ) async {
      await open(t, dir: TextDirection.rtl);
      final theirs = t.getCenter(find.text(l10n.appearanceSampleIn));
      final yours = t.getCenter(find.text(l10n.appearanceSampleOut));
      expect(theirs.dx, greaterThan(yours.dx));
    });

    testWidgets('the default wallpaper previews behind the small chat and '
        'backing out puts it back', (t) async {
      t.view.physicalSize = const Size(800, 2600);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(
        () => m.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await open(t);
      Finder wash() => find.descendant(
        of: find.byType(AccentPreview),
        matching: find.byType(AtmosphereWash),
      );
      expect(wash(), findsNothing);
      expect(find.text(l10n.atmosphereNone), findsOneWidget);
      await t.tap(find.text(l10n.appearanceEveryChat));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.atmosphereDusk));
      await t.pumpAndSettle();
      expect(wash(), findsOneWidget);
      await t.tapAt(const Offset(10, 10));
      await t.pumpAndSettle();
      expect(wash(), findsNothing);
    });

    testWidgets('light theme: the swatches show the light tones', (t) async {
      HaloColors.setLight(true);
      await open(t);
      expect(mine(t), HaloAccent.yellow.light.accent);
      await t.tap(find.text(l10n.accentBlue));
      await t.pumpAndSettle();
      expect(mine(t), HaloAccent.blue.light.accent);
    });
  });
}
