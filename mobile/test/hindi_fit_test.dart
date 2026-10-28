// SPDX-License-Identifier: GPL-3.0-or-later
// hindi in the app's own fonts on a small phone, at a larger text size and
// at the phone's biggest (which the app clamps the way app_shell does):
// onboarding step by step, the lock pad, the language sheet and a confirm
// sheet. no overflow, no line cut short, no word broken, nothing off screen
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloDb, HaloEngine, appState, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/screens/lock_screen.dart';
import 'package:kryfo/screens/onboarding_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/confirm_sheet.dart';
import 'package:kryfo/widgets/language_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'narrow_settings.dart' show loadAppFonts;
import 'pin_flow_fakes.dart' show appOnly, makeLock;

const _hi = Locale('hi');

// what a phone asks for, and what the app makes of it
const _scales = [(1.3, 1.3), (2.0, 1.6)];

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

Widget _framed(Widget home, double scale, {bool light = false}) {
  HaloColors.setLight(light);
  return MaterialApp(
    locale: _hi,
    theme: buildHaloTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(
        ctx,
      ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home,
  );
}

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 1920);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

// every hindi line on screen whole, inside its box and on the screen
List<String> _misfits(WidgetTester t, String page) {
  final bad = <String>[];
  final ex = t.takeException();
  if (ex != null) bad.add('$page: $ex');
  final width = t.view.physicalSize.width / t.view.devicePixelRatio;
  final deva = RegExp('[\u0900-\u097F]');
  var seen = 0;
  for (final e in find.byType(RichText).evaluate()) {
    final p = e.renderObject! as RenderParagraph;
    final s = p.text.toPlainText();
    if (!deva.hasMatch(s) || !p.attached || !p.hasSize) continue;
    seen++;
    // a line meant to end in an ellipsis is cut on purpose
    if (p.overflow == TextOverflow.ellipsis) continue;
    final w = p.size.width;
    if (p.didExceedMaxLines) bad.add('$page, cut short: $s');
    if (p.getMaxIntrinsicHeight(w) > p.size.height + 0.5) {
      bad.add('$page, clipped: $s');
    }
    final word = p.getMinIntrinsicWidth(double.infinity);
    if (word > w + 0.5) bad.add('$page, a word broken: $s');
    final left = p.localToGlobal(Offset.zero).dx;
    if (left < -0.5 || left + w > width + 0.5) bad.add('$page, off: $s');
  }
  if (seen == 0) bad.add('$page: no hindi on screen');
  return bad;
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final db = _Db();
    useDatabasesForTest(db, Session(db));
    useEngineForTest(_Engine());
    appState.myId = 'amber-river-lantern-x';
    setL10nLocale(_hi);
  });
  tearDown(() {
    setL10nLocale(const Locale('en'));
    HaloColors.setLight(false);
  });

  test('hindi letters are set upright and without tracking', () {
    expect(track(0.4), 0);
    expect(slant(), FontStyle.normal);
    expect(HaloType.sansFallbackNow, contains('Noto Sans Devanagari'));
    expect(HaloType.serif(height: 1.05).height, greaterThanOrEqualTo(1.3));
    setL10nLocale(const Locale('en'));
    expect(track(0.4), 0.4);
    expect(HaloType.serif(height: 1.05).height, 1.05);
  });

  for (final (asked, scale) in _scales) {
    for (final light in [false, true]) {
      final how = 'text $asked, ${light ? 'light' : 'dark'}';

      testWidgets('$how: every onboarding step fits', (t) async {
        _phone(t);
        await t.pumpWidget(
          _framed(
            OnboardingScreen(appState: appState, onComplete: () {}),
            scale,
            light: light,
          ),
        );
        await t.pump(const Duration(seconds: 1));
        final bad = <String>[];
        final pages = t.widget<PageView>(find.byType(PageView)).controller!;
        for (var step = 0; step < 7; step++) {
          pages.jumpToPage(step);
          await t.pump();
          await t.pump(const Duration(seconds: 1));
          bad.addAll(_misfits(t, 'step $step'));
        }
        expect(bad, isEmpty, reason: bad.join('\n'));
        await t.pumpWidget(const SizedBox());
      });

      testWidgets('$how: the lock pad fits', (t) async {
        _phone(t);
        final lock = await makeLock(appOnly);
        await t.pumpWidget(
          _framed(LockScreen(lock: lock.state), scale, light: light),
        );
        await t.pump(const Duration(seconds: 2));
        expect(find.text(l10n.lockYourPin), findsOneWidget);
        final bad = _misfits(t, 'lock');
        expect(bad, isEmpty, reason: bad.join('\n'));
        await t.pumpWidget(const SizedBox());
      });

      testWidgets('$how: the language sheet and a wipe sheet fit', (t) async {
        _phone(t);
        await t.pumpWidget(
          _framed(
            Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () => pickLanguage(context),
                      child: const Text('language'),
                    ),
                    TextButton(
                      onPressed: () => showConfirmSheet(
                        context,
                        title: l10n.settingsWipeKryfo,
                        line: l10n.settingsIdentityMessagesContactsAnd,
                        yes: l10n.settingsWipeKryfo2,
                        detail: l10n.flowLaw,
                      ),
                      child: const Text('wipe'),
                    ),
                  ],
                ),
              ),
            ),
            scale,
            light: light,
          ),
        );
        final bad = <String>[];
        await t.tap(find.text('language'));
        await t.pump();
        await t.pump(const Duration(seconds: 1));
        expect(find.text('हिन्दी'), findsWidgets);
        bad.addAll(_misfits(t, 'language'));
        await t.tapAt(const Offset(10, 10));
        await t.pump(const Duration(seconds: 1));
        await t.tap(find.text('wipe'));
        await t.pump();
        await t.pump(const Duration(seconds: 1));
        expect(find.text(l10n.settingsWipeKryfo), findsOneWidget);
        bad.addAll(_misfits(t, 'wipe'));
        expect(bad, isEmpty, reason: bad.join('\n'));
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
