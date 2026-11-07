// SPDX-License-Identifier: GPL-3.0-or-later
// the first screen after a wipe, a link erase or an unlink: the lock screen's
// root gives way to the app's, and the welcome page's buttons are laid out
// and painted with no pointer event, even while dart thinks the window hidden
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/desktop/desk_frames.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloDb, HaloEngine, appState, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/screens/onboarding_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

// the outermost fade around the welcome's button
double _shown(WidgetTester t) {
  final fades = find.ancestor(
    of: find.text(l10n.onboardingBegin),
    matching: find.byType(Opacity),
  );
  var v = 1.0;
  for (final e in fades.evaluate()) {
    v *= (e.widget as Opacity).opacity;
  }
  return v;
}

// time goes by with no frame drawn: only what was scheduled draws next
Future<void> _wait(WidgetTester t, Duration d) async {
  await t.binding.delayed(d);
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

  void quiet(WidgetTester t) {
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  void hidden(WidgetTester t) {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    addTearDown(
      () => t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
  }

  testWidgets('after the lock root, the welcome button draws with no input '
      'while dart thinks the window hidden', (t) async {
    quiet(t);
    // the lock screen's root, then the wipe's next run puts the app's in
    deskRunApp(_app(const SizedBox()));
    await t.pump();
    hidden(t);
    deskRunApp(_app(OnboardingScreen(appState: appState, onComplete: () {})));
    await _wait(t, Duration.zero);
    expect(t.binding.hasScheduledFrame, isTrue);
    await t.pump();
    expect(find.text(l10n.onboardingBegin), findsOneWidget);
    // the entrance cannot tick while frames are off: its cap ends it and
    // asks for the frame that shows it
    await _wait(t, const Duration(seconds: 2));
    expect(t.binding.hasScheduledFrame, isTrue);
    await t.pump();
    expect(_shown(t), 1);
    final r = t.getRect(find.text(l10n.onboardingBegin));
    expect(r.width, greaterThan(0));
    expect(r.height, greaterThan(0));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a cold start: the welcome rises in full on frames alone', (
    t,
  ) async {
    quiet(t);
    await t.pumpWidget(
      _app(OnboardingScreen(appState: appState, onComplete: () {})),
    );
    for (var i = 0; i < 90; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(_shown(t), 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the runner says the window is up: a hidden lifecycle is '
      'put right and a frame comes', (t) async {
    await t.pumpWidget(const SizedBox());
    hidden(t);
    expect(t.binding.framesEnabled, isFalse);
    deskWindowFrame(const {'shown': true, 'active': false});
    expect(t.binding.lifecycleState, AppLifecycleState.inactive);
    expect(t.binding.framesEnabled, isTrue);
    expect(t.binding.hasScheduledFrame, isTrue);
    await t.pump();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    deskWindowFrame(const {'shown': true, 'active': true});
    expect(t.binding.lifecycleState, AppLifecycleState.resumed);
    await t.pump();
  });

  testWidgets('a window still hidden stays hidden, and still gets its frame', (
    t,
  ) async {
    await t.pumpWidget(const SizedBox());
    hidden(t);
    deskWindowFrame(const {'shown': false, 'active': false});
    expect(t.binding.lifecycleState, AppLifecycleState.hidden);
    expect(t.binding.hasScheduledFrame, isTrue);
    await t.pump();
    deskWindowFrame(null);
    expect(t.binding.lifecycleState, AppLifecycleState.hidden);
    await t.pump();
  });

  testWidgets('a shown window with no lifecycle heard yet is put right', (
    t,
  ) async {
    await t.pumpWidget(const SizedBox());
    t.binding.resetInternalState();
    addTearDown(
      () => t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
    expect(t.binding.lifecycleState, isNull);
    deskWindowFrame(const {'shown': true, 'active': true});
    expect(t.binding.lifecycleState, AppLifecycleState.resumed);
    await t.pump();
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
