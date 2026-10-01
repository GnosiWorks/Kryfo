// SPDX-License-Identifier: GPL-3.0-or-later
// the me, support, add someone, share, backup and onboarding screens: what
// moves settles, what copies says so, and with less movement nothing moves.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloEngine, appState, showAddContact, useEngineForTest;
import 'package:kryfo/screens/backup_screen.dart';
import 'package:kryfo/screens/donate_screen.dart';
import 'package:kryfo/screens/my_kryfo_screen.dart';
import 'package:kryfo/screens/onboarding_screen.dart';
import 'package:kryfo/screens/profile_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/press_scale.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget framed(
  Widget home, {
  bool still = false,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: home,
);

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(720, 1600);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

// the platform answers nothing: haptics, the clipboard
void quiet(WidgetTester t) {
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

// the toast, and the minute a copied id stays on the clipboard
Future<void> drain(WidgetTester t) async {
  await t.pump(const Duration(seconds: 4));
  await t.pump(const Duration(seconds: 61));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    // off onion: the support page asks nothing of the network
    appState.sendModeForTest = 'balanced';
  });

  group('me', () {
    testWidgets('a copy shows a tick on its row, then the glyph again', (
      t,
    ) async {
      phone(t);
      quiet(t);
      await t.pumpWidget(framed(const ProfileScreen()));
      await t.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      await t.tap(find.text('...'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await t.pump(const Duration(milliseconds: 1300));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      await drain(t);
    });

    testWidgets('a badge glows three times, then rests', (t) async {
      phone(t);
      SharedPreferences.setMockInitialValues({
        'supporter_tier': 'patron',
        'supporter_show_self': true,
      });
      await t.pumpWidget(framed(const ProfileScreen()));
      await t.pump(const Duration(seconds: 1));
      expect(t.hasRunningAnimations, isTrue);
      await t.pump(const Duration(seconds: 11));
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('no badge, nothing ticks once it has come in', (t) async {
      phone(t);
      await t.pumpWidget(framed(const ProfileScreen()));
      await t.pump(const Duration(seconds: 1));
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: the page is simply there', (t) async {
      phone(t);
      await t.pumpWidget(framed(const ProfileScreen(), still: true));
      await t.pump();
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('support', () {
    testWidgets('a new coin eases the box to its height, no overflow', (
      t,
    ) async {
      phone(t);
      await t.pumpWidget(framed(const DonateScreen()));
      await t.pump(const Duration(seconds: 1));
      final before = t.getSize(find.byType(AnimatedSize)).height;
      await t.tap(find.text(l10n.donateMonero));
      await t.pump(const Duration(milliseconds: 20));
      await t.pump(const Duration(milliseconds: 100));
      final mid = t.getSize(find.byType(AnimatedSize)).height;
      await t.pump(const Duration(milliseconds: 400));
      final after = t.getSize(find.byType(AnimatedSize)).height;
      expect(after, isNot(before));
      expect(mid, isNot(after), reason: 'on its way, not jumped');
      expect(t.takeException(), isNull);
      await t.pump(const Duration(seconds: 1));
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a tier picked pops and settles; amounts are mono', (t) async {
      phone(t);
      await t.pumpWidget(framed(const DonateScreen()));
      await t.pump(const Duration(seconds: 1));
      final amount = t.widget<AnimatedDefaultTextStyle>(
        find
            .ancestor(
              of: find.text(r'$50'),
              matching: find.byType(AnimatedDefaultTextStyle),
            )
            .first,
      );
      expect(amount.style.fontFamily, HaloType.monoFamily);
      await t.tap(find.text(l10n.donateTierPatron));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.hasRunningAnimations, isTrue);
      await t.pump(const Duration(milliseconds: 500));
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: picks are instant and nothing grows', (
      t,
    ) async {
      phone(t);
      await t.pumpWidget(framed(const DonateScreen(), still: true));
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text(l10n.donateTierGuardian));
      await t.tap(find.text(l10n.donateSolana));
      await t.pump();
      expect(t.hasRunningAnimations, isFalse);
      for (final s in t.widgetList<AnimatedScale>(find.byType(AnimatedScale))) {
        expect(s.scale, 1);
      }
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a check that fails gives the button back', (t) async {
      // wide: the test font's square glyphs would not fit the address row
      t.view.physicalSize = const Size(2000, 3200);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      quiet(t);
      appState.sendModeForTest = 'private';
      final e = _BadgeEngine();
      useEngineForTest(e);
      await t.pumpWidget(framed(const DonateScreen()));
      await t.pump(const Duration(seconds: 1));
      await t.ensureVisible(find.text(l10n.donatePayWithBitcoin));
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.text(l10n.donatePayWithBitcoin));
      await t.pump(const Duration(seconds: 1));
      // the quarter hour runs out with nothing paid
      for (var i = 0; i < 16; i++) {
        await t.pump(const Duration(seconds: 59));
      }
      await t.pump(const Duration(seconds: 1));
      expect(find.text(l10n.donateIPaidCheckAgain), findsOneWidget);
      e.down = true;
      await t.tap(find.text(l10n.donateIPaidCheckAgain));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      e.down = false;
      expect(find.text(l10n.donateChecking), findsNothing);
      expect(find.text(l10n.donateIPaidCheckAgain), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 61));
    });

    testWidgets('copying the address ticks the button', (t) async {
      phone(t);
      quiet(t);
      await t.pumpWidget(framed(const DonateScreen()));
      await t.pump(const Duration(seconds: 1));
      await t.ensureVisible(find.text(l10n.donateCopyAddress));
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.text(l10n.donateCopyAddress));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await drain(t);
    });
  });

  group('add someone', () {
    Future<void> open(WidgetTester t, {bool still = false}) async {
      phone(t);
      await t.pumpWidget(
        framed(
          Builder(
            builder: (c) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showAddContact(c),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          still: still,
        ),
      );
      await t.tap(find.text('open'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
    }

    Color? addThem(WidgetTester t) =>
        (t
                    .widget<AnimatedContainer>(
                      find
                          .ancestor(
                            of: find.text(l10n.appAddThem),
                            matching: find.byType(AnimatedContainer),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration)
            .color;

    testWidgets('"add them" fills once there is something to add', (t) async {
      await open(t);
      expect(addThem(t), Colors.transparent);
      await t.enterText(find.byType(TextField), '@wren');
      await t.pump(const Duration(milliseconds: 250));
      expect(addThem(t), HaloColors.amber);
      await t.enterText(find.byType(TextField), '');
      await t.pump(const Duration(milliseconds: 250));
      expect(addThem(t), Colors.transparent);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets('the field lights while it is typed in', (t) async {
      await open(t);
      Border edge() =>
          (t
                          .widget<AnimatedContainer>(
                            find
                                .ancestor(
                                  of: find.byType(TextField),
                                  matching: find.byType(AnimatedContainer),
                                )
                                .first,
                          )
                          .decoration
                      as BoxDecoration)
                  .border!
              as Border;
      expect(edge().top.width, 0.5);
      await t.tap(find.byType(TextField));
      await t.pump();
      await t.pump(const Duration(milliseconds: 250));
      expect(edge().top.width, 1);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets('reduced motion: presses do not scale', (t) async {
      await open(t, still: true);
      final g = await t.startGesture(
        t.getCenter(find.text(l10n.appScanTheirCode)),
      );
      await t.pump(const Duration(milliseconds: 150));
      final s = t.widget<AnimatedScale>(
        find
            .ancestor(
              of: find.text(l10n.appScanTheirCode),
              matching: find.byType(AnimatedScale),
            )
            .first,
      );
      expect(s.scale, 1);
      await g.cancel();
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  });

  group('every way to add someone', () {
    double bodyOpacity(WidgetTester t) => t
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.text(l10n.myKryfoTheLinkCarriesYour),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    testWidgets('a way opens with its body fading up, then rests', (t) async {
      phone(t);
      await t.pumpWidget(framed(const MyKryfoScreen()));
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text(l10n.myKryfoTheyReSomewhereElse));
      await t.pump();
      await t.pump(const Duration(milliseconds: 120));
      expect(bodyOpacity(t), lessThan(1));
      await t.pump(const Duration(milliseconds: 600));
      expect(bodyOpacity(t), 1);
      // rows the list builds as it grows arrive with their own stagger
      await t.pump(const Duration(milliseconds: 400));
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: it opens at once', (t) async {
      phone(t);
      await t.pumpWidget(framed(const MyKryfoScreen(), still: true));
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text(l10n.myKryfoTheyReSomewhereElse));
      await t.pump();
      expect(bodyOpacity(t), 1);
      // the chevron is already turned: only the ink's own fade may run
      final turn = t.widget<RotationTransition>(
        find.descendant(
          of: find.ancestor(
            of: find.text(l10n.myKryfoTheyReSomewhereElse),
            matching: find.byType(InkWell),
          ),
          matching: find.byType(RotationTransition),
        ),
      );
      expect(turn.turns.value, 0.5);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('backup', () {
    testWidgets('both choices span the page and the ring springs', (t) async {
      phone(t);
      await t.pumpWidget(framed(const BackupScreen()));
      await t.pump(const Duration(seconds: 1));
      final a = t.getSize(
        find
            .ancestor(
              of: find.text(l10n.backupBackUp),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final b = t.getSize(
        find
            .ancestor(
              of: find.text(l10n.backupMoveToAnotherDevice),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(a.width, b.width);
      await t.tap(find.text(l10n.backupMoveToAnotherDevice));
      await t.pump(const Duration(milliseconds: 60));
      expect(t.hasRunningAnimations, isTrue);
      await t.pump(const Duration(milliseconds: 500));
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('onboarding', () {
    testWidgets('the welcome glow plays twice, then rests', (t) async {
      phone(t);
      await t.pumpWidget(
        framed(OnboardingScreen(appState: appState, onComplete: () {})),
      );
      await t.pump(const Duration(seconds: 1));
      expect(t.hasRunningAnimations, isTrue);
      await t.pump(const Duration(seconds: 5));
      expect(t.hasRunningAnimations, isFalse);
      expect(
        find.ancestor(
          of: find.text(l10n.onboardingBegin),
          matching: find.byType(PressScale),
        ),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('the name writes itself in, shines, then rests', (t) async {
      phone(t);
      await t.pumpWidget(
        framed(OnboardingScreen(appState: appState, onComplete: () {})),
      );
      await t.ensureVisible(find.text(l10n.onboardingBegin));
      await t.tap(find.text(l10n.onboardingBegin));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.onboardingYourKryfoId), findsOneWidget);
      await t.pump(const Duration(seconds: 9));
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: each step is simply there', (t) async {
      phone(t);
      await t.pumpWidget(
        framed(
          OnboardingScreen(appState: appState, onComplete: () {}),
          still: true,
        ),
      );
      await t.pump();
      expect(t.hasRunningAnimations, isFalse);
      await t.ensureVisible(find.text(l10n.onboardingBegin));
      await t.tap(find.text(l10n.onboardingBegin));
      await t.pump();
      expect(find.text(l10n.onboardingYourKryfoId), findsOneWidget);
      await t.pump();
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('system back walks one step back, then leaves from the first', (
      t,
    ) async {
      phone(t);
      quiet(t);
      await t.pumpWidget(
        framed(OnboardingScreen(appState: appState, onComplete: () {})),
      );
      bool leaves() =>
          (t.widget(find.byWidgetPredicate((w) => w is PopScope).first)
                  as PopScope)
              .canPop;
      expect(leaves(), isTrue);
      await t.ensureVisible(find.text(l10n.onboardingBegin));
      await t.tap(find.text(l10n.onboardingBegin));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.onboardingYourKryfoId), findsOneWidget);
      expect(leaves(), isFalse);
      await t.binding.handlePopRoute();
      await t.pump();
      // it slides back rather than jumping
      await t.pump(const Duration(milliseconds: 140));
      expect(find.text(l10n.onboardingYourKryfoId), findsOneWidget);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.onboardingYourKryfoId), findsNothing);
      expect(find.text(l10n.onboardingBegin), findsOneWidget);
      expect(leaves(), isTrue);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: back is simply the step before', (t) async {
      phone(t);
      quiet(t);
      await t.pumpWidget(
        framed(
          OnboardingScreen(appState: appState, onComplete: () {}),
          still: true,
        ),
      );
      final pages = t.widget<PageView>(find.byType(PageView)).controller!;
      pages.jumpToPage(4);
      await t.pump();
      await t.binding.handlePopRoute();
      await t.pump();
      expect(pages.page, 3);
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(const SizedBox());
    });

    // a small phone at twice the text size: the name and face steps scroll
    // instead of spilling past the bottom or the side
    for (final lang in ['en', 'de']) {
      testWidgets('large text, $lang: the name and face steps fit', (t) async {
        t.view.physicalSize = const Size(720, 1280);
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        quiet(t);
        setL10nLocale(Locale(lang));
        addTearDown(() => setL10nLocale(const Locale('en')));
        await t.pumpWidget(
          MaterialApp(
            locale: Locale(lang),
            theme: buildHaloTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (ctx, child) => MediaQuery(
              data: MediaQuery.of(ctx).copyWith(
                disableAnimations: true,
                textScaler: const TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: OnboardingScreen(appState: appState, onComplete: () {}),
          ),
        );
        final pages = t.widget<PageView>(find.byType(PageView)).controller!;
        for (final step in [1, 2]) {
          pages.jumpToPage(step);
          await t.pump();
          await t.pump(const Duration(seconds: 4));
          expect(t.takeException(), isNull, reason: 'step $step');
        }
        // the face step's buttons stay reachable
        expect(
          find.text(l10n.onboardingContinue).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.text(l10n.onboardingKeepMyInitial).hitTestable(),
          findsOneWidget,
        );
        await t.pumpWidget(const SizedBox());
      });
    }

    testWidgets('right to left: the path arrows point the reading way', (
      t,
    ) async {
      phone(t);
      setL10nLocale(const Locale('fa'));
      addTearDown(() => setL10nLocale(const Locale('en')));
      await t.pumpWidget(
        framed(
          OnboardingScreen(appState: appState, onComplete: () {}),
          locale: const Locale('fa'),
          still: true,
        ),
      );
      t.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(6);
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      final arrows = find.text('→');
      expect(arrows, findsNWidgets(2));
      for (final e in arrows.evaluate()) {
        final flip = t.widget<Transform>(
          find
              .ancestor(
                of: find.byWidget(e.widget),
                matching: find.byType(Transform),
              )
              .first,
        );
        expect(flip.transform.storage[0], -1);
      }
      await t.pumpWidget(const SizedBox());
    });
  });
}

// the badge service: an invoice, then a receipt that stays pending, or a
// tor call that throws
class _BadgeEngine implements HaloEngine {
  bool down = false;
  @override
  Future<String> torPost(String url, String body) async =>
      '{"id":"inv1","tier":"supporter","address":"bc1qtest","btc":"0.0002"}';
  @override
  Future<String> torGetJson(String url) async {
    if (down) throw StateError('isolate');
    return '{"status":"pending"}';
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
