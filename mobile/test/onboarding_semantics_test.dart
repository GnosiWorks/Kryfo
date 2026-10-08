// SPDX-License-Identifier: GPL-3.0-or-later
// onboarding with a screen reader: every step's main button is its own node
// with the button's own bounds, a tap through it moves on, and what a step
// says is read apart from its button.
import 'package:flutter/material.dart';
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
import 'package:kryfo/widgets/press_scale.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'on_screen.dart';

Widget framed(Widget home, {bool still = false}) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: home,
);

PageController pages(WidgetTester t) =>
    t.widget<PageView>(find.byType(PageView)).controller!;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final db = _Db();
    useDatabasesForTest(db, Session(db));
    useEngineForTest(_Engine());
    appState.myId = 'amber-river-lantern-x';
    // onion kept: the step writes it and asks nothing more of the engine
    appState.sendModeForTest = 'private';
  });

  // both in one test: the send mode queue is a future, and one left from
  // an earlier test's clock never answers in the next
  testWidgets('each step\'s button is its own node and moves on', (t) async {
    t.view.physicalSize = const Size(411, 891) * 2;
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final sem = t.ensureSemantics();
    for (final still in [false, true]) {
      var done = false;
      await t.pumpWidget(
        framed(
          OnboardingScreen(appState: appState, onComplete: () => done = true),
          still: still,
        ),
      );
      await t.pump(const Duration(seconds: 3));
      final buttons = [
        l10n.onboardingBegin,
        l10n.onboardingUseThisName,
        l10n.onboardingContinue,
        l10n.onboardingKeepOnion,
        l10n.onboardingIUnderstand,
        l10n.onboardingGotIt,
        l10n.onboardingNotNowAddPeople,
      ];
      // what the last three steps say, and a card each one fades in
      final says = <int, (String, String)>{
        4: (
          l10n.onboardingEverythingElseTheApp,
          l10n.onboardingYourNameIsThreeWords,
        ),
        5: (l10n.onboardingAndroidNeedsAVisible, l10n.onboardingSilentAndAtThe),
        6: (l10n.onboardingTheAppIsReady, l10n.onboardingEveryWayToAdd),
      };
      for (var step = 0; step < buttons.length; step++) {
        final label = buttons[step];
        final why = 'step ${step + 1}${still ? ', still' : ''}';
        expect(pages(t).page, step, reason: why);
        final node = t.getSemantics(find.text(label));
        expect(
          node,
          isSemantics(label: label, isButton: true, hasTapAction: true),
          reason: why,
        );
        // the node is the button: same bounds, not the page around it
        final drawn = t.getRect(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(PressScale),
          ),
        );
        final rect = onScreen(t, node);
        expect(rect.height, lessThan(100), reason: why);
        for (final (a, b) in [
          (rect.left, drawn.left),
          (rect.top, drawn.top),
          (rect.right, drawn.right),
          (rect.bottom, drawn.bottom),
        ]) {
          expect(a, moreOrLessEquals(b, epsilon: 0.5), reason: why);
        }
        final said = says[step];
        if (said != null) {
          final (lead, card) = said;
          final leadNode = t.getSemantics(find.text(lead));
          expect(leadNode.label, lead, reason: why);
          expect(leadNode.id, isNot(node.id), reason: why);
          final cardNode = t.getSemantics(find.text(card));
          expect(cardNode.label, contains(card), reason: why);
          expect(cardNode.id, isNot(node.id), reason: why);
          expect(node.label, isNot(contains(lead)), reason: why);
        }
        t.semantics.tap(find.semantics.byLabel(label));
        // the key store answers on real time
        for (var i = 0; i < 50 && !done && pages(t).page == step; i++) {
          await t.pump(const Duration(milliseconds: 100));
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        await t.pump(const Duration(seconds: 3));
      }
      expect(done, isTrue);
      await t.pumpWidget(const SizedBox());
    }
    sem.dispose();
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
