// SPDX-License-Identifier: GPL-3.0-or-later
// the tools' own screens: a code assembles as it first appears, each stage
// fades into the next, a finished file's padlock snaps and is felt once,
// a button that cannot be used yet is quieter in its own colours rather
// than faded, and with less movement all of it is simply there.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/clean_screen.dart';
import 'package:kryfo/screens/lock_file_screen.dart';
import 'package:kryfo/screens/photo_knows_screen.dart';
import 'package:kryfo/screens/qr_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/tools/tools_bridge.dart';
import 'package:kryfo/widgets/tool_parts.dart';

final _theme = buildHaloTheme();

Widget framed(
  Widget home, {
  bool still = false,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  theme: _theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: home,
);

// a phone, and the haptics asked for
List<String> phone(WidgetTester t) {
  t.view.physicalSize = const Size(1000, 1800);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final felt = <String>[];
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') {
      felt.add((call.arguments as String).split('.').last);
    }
    return null;
  });
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
  return felt;
}

// the tools channel: a copy that fails after a moment
void failingCopy(WidgetTester t) {
  const ch = MethodChannel('halo/tools');
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(ch, (call) async {
    if (call.method == 'copyIn') {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      throw PlatformException(code: 'read');
    }
    return null;
  });
  addTearDown(() => m.setMockMethodCallHandler(ch, null));
}

// a second at a time, so a ticker started late still gets its frames
Future<void> rest(WidgetTester t, [int seconds = 10]) async {
  for (var i = 0; i < seconds; i++) {
    await t.pump(const Duration(seconds: 1));
  }
}

Future<void> drain(WidgetTester t) async {
  await t.pump(const Duration(seconds: 4));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

const _photo = PickedFile(
  uri: 'content://test/photo.jpg',
  name: 'photo.jpg',
  size: 4321,
  mime: 'image/jpeg',
);

// how far the padlock's shackle sits from its place: below zero raised
double shackle(WidgetTester t) => t
    .widget<Transform>(
      find
          .descendant(
            of: find.byType(LockSnap),
            matching: find.byType(Transform),
          )
          .last,
    )
    .transform
    .getTranslation()
    .y;

void main() {
  group('the qr maker', () {
    testWidgets('a code assembles as it first appears, then rests', (t) async {
      phone(t);
      await t.pumpWidget(framed(const QrScreen()));
      await rest(t);
      expect(t.hasRunningAnimations, isFalse, reason: 'the dot rests too');
      expect(find.bySemanticsLabel(l10n.qrQrCode), findsNothing);
      await t.enterText(find.byType(TextField).first, 'https://kryfo.app');
      await t.pump();
      await t.pump(const Duration(milliseconds: 260));
      expect(find.byType(ShaderMask), findsOneWidget);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(ShaderMask), findsNothing);
      // more typing redraws it in place
      await t.enterText(find.byType(TextField).first, 'https://kryfo.app/x');
      await t.pump();
      expect(find.byType(ShaderMask), findsNothing);
      await rest(t);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });

    testWidgets('its hints are text colours, not faded', (t) async {
      phone(t);
      await t.pumpWidget(framed(const QrScreen()));
      await t.pump(const Duration(seconds: 1));
      final hint = t
          .widget<TextField>(find.byType(TextField).first)
          .decoration!
          .hintStyle!;
      expect(hint.color, HaloColors.text3);
      await rest(t);
      await drain(t);
    });

    testWidgets('reduced motion: the code is simply there', (t) async {
      phone(t);
      await t.pumpWidget(framed(const QrScreen(), still: true));
      await t.pump();
      expect(t.hasRunningAnimations, isFalse);
      await t.enterText(find.byType(TextField).first, 'https://kryfo.app');
      await t.pump();
      expect(find.byType(ShaderMask), findsNothing);
      // the field's own scroll into view is the framework's, and short
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byType(ShaderMask), findsNothing);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });

    testWidgets('right to left: it builds and rests', (t) async {
      phone(t);
      await t.pumpWidget(framed(const QrScreen(), locale: const Locale('fa')));
      await t.enterText(find.byType(TextField).first, 'https://kryfo.app');
      await rest(t);
      expect(t.hasRunningAnimations, isFalse);
      expect(t.takeException(), isNull);
      await drain(t);
    });
  });

  group('a finished file', () {
    testWidgets('the padlock pops in, its shackle snaps shut, felt once', (
      t,
    ) async {
      final felt = phone(t);
      await t.pumpWidget(framed(const Center(child: LockSnap())));
      await t.pump(const Duration(milliseconds: 200));
      expect(shackle(t), lessThan(-1), reason: 'still raised');
      await t.pump(const Duration(milliseconds: 400));
      expect(shackle(t), closeTo(0, 0.01));
      expect(t.hasRunningAnimations, isFalse);
      expect(felt, ['lightImpact']);
      await drain(t);
    });

    testWidgets('opened, its shackle springs up into place', (t) async {
      phone(t);
      await t.pumpWidget(framed(const Center(child: LockSnap(open: true))));
      await t.pump(const Duration(milliseconds: 200));
      expect(shackle(t), greaterThan(1));
      await t.pump(const Duration(milliseconds: 400));
      expect(shackle(t), closeTo(0, 0.01));
      await drain(t);
    });

    testWidgets('reduced motion: shut and still, nothing felt', (t) async {
      final felt = phone(t);
      await t.pumpWidget(framed(const Center(child: LockSnap()), still: true));
      await t.pump();
      expect(shackle(t), 0);
      expect(t.hasRunningAnimations, isFalse);
      await t.pump(const Duration(seconds: 1));
      expect(felt, isEmpty);
      await drain(t);
    });
  });

  group('a wide button', () {
    testWidgets('one that cannot be used yet is quieter, never faded', (
      t,
    ) async {
      phone(t);
      Widget button(VoidCallback? tap) => framed(
        Scaffold(
          body: Center(
            child: ToolWideButton(label: 'Lock file', filled: true, onTap: tap),
          ),
        ),
      );
      await t.pumpWidget(button(null));
      expect(
        find.ancestor(
          of: find.text('Lock file'),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
      Color? fill() =>
          (t
                      .widget<AnimatedContainer>(
                        find.ancestor(
                          of: find.text('Lock file'),
                          matching: find.byType(AnimatedContainer),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .color;
      expect(
        t.widget<Text>(find.text('Lock file')).style!.color,
        HaloColors.text3,
      );
      expect(fill(), HaloColors.surface3);
      await t.pumpWidget(button(() {}));
      await t.pump(const Duration(milliseconds: 300));
      expect(fill(), HaloColors.amber);
      expect(t.hasRunningAnimations, isFalse);
    });
  });

  group('a stage fading into the next', () {
    testWidgets('clean: the reading fades into what went wrong', (t) async {
      phone(t);
      failingCopy(t);
      await t.pumpWidget(framed(const CleanScreen(file: _photo)));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text(l10n.cleanReadingTheFile), findsOneWidget);
      await t.pump(const Duration(milliseconds: 250));
      await t.pump(const Duration(milliseconds: 100));
      // both on screen while they cross
      expect(find.text(l10n.cleanReadingTheFile), findsOneWidget);
      expect(find.text(failureTitle('read')), findsOneWidget);
      await rest(t, 2);
      expect(find.text(l10n.cleanReadingTheFile), findsNothing);
      expect(find.text(l10n.commonBack), findsOneWidget);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });

    testWidgets('what a photo knows: the same, and it rests', (t) async {
      phone(t);
      failingCopy(t);
      await t.pumpWidget(framed(const PhotoKnowsScreen(file: _photo)));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text(l10n.photoKnowsReadingTheFile), findsOneWidget);
      await rest(t, 2);
      expect(find.text(l10n.photoKnowsReadingTheFile), findsNothing);
      expect(find.text(failureTitle('read')), findsOneWidget);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });

    testWidgets('reduced motion: the next stage is simply there', (t) async {
      phone(t);
      failingCopy(t);
      await t.pumpWidget(framed(const CleanScreen(file: _photo), still: true));
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      expect(find.text(l10n.cleanReadingTheFile), findsNothing);
      expect(find.text(failureTitle('read')), findsOneWidget);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });

    testWidgets('lock a file: a mismatch eases in and out', (t) async {
      phone(t);
      await t.pumpWidget(framed(const LockFileScreen(file: _photo)));
      await t.pump(const Duration(seconds: 1));
      await t.enterText(find.byType(TextField).at(0), 'correct horse staple');
      await t.enterText(find.byType(TextField).at(1), 'correct horse');
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(find.text(l10n.lockFileTheTwoDoNot), findsOneWidget);
      expect(t.hasRunningAnimations, isTrue);
      await rest(t, 1);
      expect(t.hasRunningAnimations, isFalse);
      await t.enterText(find.byType(TextField).at(1), 'correct horse staple');
      await t.pump();
      await rest(t, 1);
      expect(find.text(l10n.lockFileTheTwoDoNot), findsNothing);
      expect(t.hasRunningAnimations, isFalse);
      await drain(t);
    });
  });
}
