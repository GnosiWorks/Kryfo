// SPDX-License-Identifier: GPL-3.0-or-later
// onboarding: steps fade through, the bar counts, a new name lands word by
// word, every step's button stays in reach on a small phone, the shade on the
// notification step pulls down once and fits, and with less movement nothing
// moves.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloDb, HaloEngine, appState, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/screens/onboarding_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/language_sheet.dart' show LanguageRow;
import 'package:kryfo/widgets/tor_boot_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget framed(
  Widget home, {
  bool still = false,
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(
      ctx,
    ).copyWith(disableAnimations: still, textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

Widget onboarding({bool still = false, Locale? locale, double scale = 1}) =>
    framed(
      OnboardingScreen(appState: appState, onComplete: () {}),
      still: still,
      locale: locale ?? const Locale('en'),
      scale: scale,
    );

void phone(WidgetTester t, {Size size = const Size(411, 891)}) {
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

// the platform answers nothing: haptics
void quiet(WidgetTester t) {
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

void lang(String code) {
  setL10nLocale(Locale(code));
  addTearDown(() => setL10nLocale(const Locale('en')));
}

// the step frame's fade, the outermost one around [text]
double shown(WidgetTester t, String text) => t
    .widget<Opacity>(
      find.ancestor(of: find.text(text), matching: find.byType(Opacity)).last,
    )
    .opacity;

PageController pages(WidgetTester t) =>
    t.widget<PageView>(find.byType(PageView)).controller!;

// the quiet notification in the shade, folded to one line
Finder quietLine() =>
    find.textContaining(l10n.androidServiceTitle, findRichText: true);

List<double> fades(WidgetTester t, Finder f) => [
  for (final o in t.widgetList<Opacity>(
    find.ancestor(of: f, matching: find.byType(Opacity)),
  ))
    o.opacity,
];

Future<void> toShade(WidgetTester t) async {
  pages(t).jumpToPage(5);
  await t.pump();
}

Future<void> toName(WidgetTester t) async {
  await t.tap(find.text(l10n.onboardingBegin));
  await t.pump();
  await t.pump(const Duration(seconds: 4));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final db = _Db();
    useDatabasesForTest(db, Session(db));
    useEngineForTest(_Engine());
    appState.myId = 'amber-river-lantern-x';
  });

  testWidgets('a step fades out before the next one settles in', (t) async {
    phone(t);
    quiet(t);
    await t.pumpWidget(onboarding());
    await t.pump(const Duration(seconds: 6));
    await t.tap(find.text(l10n.onboardingBegin));
    await t.pump();
    await t.pump(const Duration(milliseconds: 170));
    expect(shown(t, l10n.onboardingBegin), 0);
    final mid = shown(t, l10n.onboardingYourKryfoId);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    await t.pump(const Duration(milliseconds: 300));
    expect(shown(t, l10n.onboardingYourKryfoId), 1);
    expect(find.text(l10n.onboardingBegin), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the language on the welcome page, then back and the count', (
    t,
  ) async {
    phone(t);
    quiet(t);
    await t.pumpWidget(onboarding(still: true));
    await t.pump();
    expect(find.byType(LanguageRow).hitTestable(), findsOneWidget);
    expect(find.byTooltip(l10n.commonBack).hitTestable(), findsNothing);
    await toName(t);
    expect(find.text('02 / 07'), findsOneWidget);
    expect(find.byType(LanguageRow).hitTestable(), findsNothing);
    await t.tap(find.byTooltip(l10n.commonBack));
    await t.pump();
    expect(pages(t).page, 0);
    expect(find.text(l10n.onboardingBegin), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a new name: the old words lift away, the new ones land', (
    t,
  ) async {
    phone(t);
    quiet(t);
    await t.pumpWidget(onboarding());
    await t.pump(const Duration(seconds: 3));
    await toName(t);
    expect(t.hasRunningAnimations, isFalse);
    await t.tap(find.text(l10n.onboardingTryAnother));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    // the old name holds while it leaves
    expect(find.text('amber'), findsOneWidget);
    expect(find.text('cedar'), findsNothing);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('cedar'), findsOneWidget);
    expect(find.text('amber'), findsNothing);
    expect(t.hasRunningAnimations, isTrue);
    await t.pump(const Duration(seconds: 3));
    expect(t.hasRunningAnimations, isFalse);
    expect(find.text('harbor'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion: steps, the bar and a new name are just there', (
    t,
  ) async {
    phone(t);
    quiet(t);
    await t.pumpWidget(onboarding(still: true));
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
    await t.tap(find.text(l10n.onboardingBegin));
    await t.pump();
    expect(pages(t).page, 1);
    expect(shown(t, l10n.onboardingYourKryfoId), 1);
    expect(find.text('02 / 07'), findsOneWidget);
    expect(t.hasRunningAnimations, isFalse);
    await t.tap(find.text(l10n.onboardingTryAnother));
    await t.pump();
    await t.pump();
    expect(find.text('cedar'), findsOneWidget);
    expect(t.hasRunningAnimations, isFalse);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the picked way of sending reads as the checked one', (t) async {
    phone(t);
    quiet(t);
    final sem = t.ensureSemantics();
    await t.pumpWidget(onboarding(still: true));
    pages(t).jumpToPage(3);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    Matcher radio(bool on) => isSemantics(
      isInMutuallyExclusiveGroup: true,
      hasCheckedState: true,
      isChecked: on,
    );
    SemanticsNode card(String title) => t.getSemantics(find.text(title));
    expect(card(l10n.onboardingOnion), radio(true));
    expect(card(l10n.onboardingRelay), radio(false));
    await t.tap(find.text(l10n.onboardingRelay));
    await t.pump();
    expect(card(l10n.onboardingOnion), radio(false));
    expect(card(l10n.onboardingRelay), radio(true));
    expect(find.text(l10n.onboardingUseThis), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    sem.dispose();
  });

  testWidgets('right to left: the bar fills from the right, the id reads '
      'left to right', (t) async {
    phone(t);
    quiet(t);
    lang('ar');
    await t.pumpWidget(onboarding(still: true, locale: const Locale('ar')));
    await toName(t);
    final bars = find.byType(FractionallySizedBox);
    expect(t.getRect(bars.first).left, greaterThan(t.getRect(bars.last).left));
    expect(
      t.getCenter(find.text('amber')).dx,
      lessThan(t.getCenter(find.text('lantern')).dx),
    );
    final back = t.widget<Icon>(
      find.descendant(
        of: find.byTooltip(l10n.commonBack),
        matching: find.byType(Icon),
      ),
    );
    expect(back.icon!.matchTextDirection, isTrue);
    await t.pumpWidget(const SizedBox());
  });

  // a small phone at a larger text size: nothing spills, and every step's
  // button stays where a thumb finds it without scrolling
  for (final code in ['en', 'ar']) {
    for (final light in [false, true]) {
      final theme = light ? 'light' : 'dark';
      testWidgets('360 wide, text 1.3, $code, $theme: every step fits', (
        t,
      ) async {
        phone(t, size: const Size(360, 640));
        quiet(t);
        lang(code);
        HaloColors.setLight(light);
        addTearDown(() => HaloColors.setLight(false));
        await t.pumpWidget(
          onboarding(still: true, locale: Locale(code), scale: 1.3),
        );
        final buttons = [
          l10n.onboardingBegin,
          l10n.onboardingUseThisName,
          l10n.onboardingContinue,
          l10n.onboardingKeepOnion,
          l10n.onboardingIUnderstand,
          l10n.onboardingGotIt,
          l10n.onboardingNotNowAddPeople,
        ];
        for (var step = 0; step < buttons.length; step++) {
          pages(t).jumpToPage(step);
          await t.pump();
          await t.pump(const Duration(seconds: 1));
          expect(t.takeException(), isNull, reason: 'step $step');
          expect(
            find.text(buttons[step]).hitTestable(),
            findsOneWidget,
            reason: 'step $step',
          );
        }
        await t.pumpWidget(framed(const TorBootSplash(), scale: 1.3));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull, reason: 'splash');
        await t.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('the notification step: the shade pulls down once, then rests', (
    t,
  ) async {
    phone(t);
    quiet(t);
    final sem = t.ensureSemantics();
    await t.pumpWidget(onboarding());
    await t.pump(const Duration(seconds: 6));
    await toShade(t);
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Kryfo'), findsOneWidget);
    expect(find.text(l10n.notificationsNewMessage), findsOneWidget);
    expect(quietLine(), findsOneWidget);
    expect(fades(t, quietLine()).reduce((a, b) => a < b ? a : b), lessThan(1));
    expect(t.hasRunningAnimations, isTrue);
    await t.pump(const Duration(seconds: 2));
    expect(fades(t, quietLine()), everyElement(1.0));
    expect(t.hasRunningAnimations, isFalse);
    // the words start at the left
    expect(t.getCenter(find.text('Kryfo')).dx, lessThan(411 / 2));
    expect(
      find.bySemanticsLabel(
        '${l10n.androidServiceTitle}. ${l10n.androidServiceText}',
      ),
      findsOneWidget,
    );
    await t.pumpWidget(const SizedBox());
    sem.dispose();
  });

  testWidgets('reduced motion: the shade is simply there', (t) async {
    phone(t);
    quiet(t);
    await t.pumpWidget(onboarding(still: true));
    await t.pump();
    await toShade(t);
    expect(fades(t, quietLine()), everyElement(1.0));
    expect(
      fades(t, find.text(l10n.notificationsNewMessage)),
      everyElement(1.0),
    );
    expect(t.hasRunningAnimations, isFalse);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('right to left: the shade reads from the right', (t) async {
    phone(t);
    quiet(t);
    lang('ar');
    await t.pumpWidget(onboarding(still: true, locale: const Locale('ar')));
    await toShade(t);
    expect(quietLine(), findsOneWidget);
    final name = t.getRect(find.text('Kryfo'));
    final line = t.getRect(find.text(l10n.notificationsNewMessage));
    expect(name.center.dx, greaterThan(411 / 2));
    expect(name.right, moreOrLessEquals(line.right, epsilon: 0.5));
    await t.pumpWidget(const SizedBox());
  });

  for (final code in ['en', 'ar']) {
    for (final light in [false, true]) {
      final theme = light ? 'light' : 'dark';
      testWidgets('360 wide, text 1.5, $code, $theme: the shade fits', (
        t,
      ) async {
        phone(t, size: const Size(360, 640));
        quiet(t);
        lang(code);
        HaloColors.setLight(light);
        addTearDown(() => HaloColors.setLight(false));
        await t.pumpWidget(
          onboarding(still: true, locale: Locale(code), scale: 1.5),
        );
        await toShade(t);
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        expect(quietLine(), findsOneWidget);
        for (final f in [
          quietLine(),
          find.text('Kryfo'),
          find.text(l10n.notificationsNewMessage),
        ]) {
          final r = t.getRect(f);
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(360));
        }
        expect(find.text(l10n.onboardingGotIt).hitTestable(), findsOneWidget);
        await t.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('the splash words come up once, the hops keep going', (t) async {
    phone(t);
    await t.pumpWidget(framed(const TorBootSplash()));
    await t.pump();
    expect(shown(t, l10n.torBootSplashNoShortcutsNoTraces), lessThan(1));
    await t.pump(const Duration(seconds: 1));
    expect(shown(t, l10n.torBootSplashNoShortcutsNoTraces), 1);
    expect(t.hasRunningAnimations, isTrue);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the splash names its hops in every language', (t) async {
    phone(t, size: const Size(360, 640));
    for (final loc in AppLocalizations.supportedLocales) {
      setL10nLocale(loc);
      addTearDown(() => setL10nLocale(const Locale('en')));
      await t.pumpWidget(
        framed(const TorBootSplash(), locale: loc, scale: 1.3),
      );
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull, reason: '$loc');
      for (final hop in [
        l10n.torBootSplashHopEntry,
        l10n.torBootSplashHopMiddle,
        l10n.torBootSplashHopExit,
      ]) {
        expect(find.text(hop), findsOneWidget, reason: '$loc $hop');
      }
      for (final word in ['guard', 'relay', 'exit']) {
        expect(find.text(word), findsNothing, reason: '$loc');
      }
      await t.pumpWidget(const SizedBox());
    }
  });
}

class _Db implements HaloDb {
  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<void> saveIdentity(String id, String edPriv, String xPriv) async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Engine implements HaloEngine {
  @override
  String generateIdentity() => 'cedar-moss-harbor-y';
  @override
  String myEdPrivkey() => '00';
  @override
  String myXPrivkey() => '00';
  @override
  String myXPubkey() => '00';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
