// SPDX-License-Identifier: GPL-3.0-or-later
// cards that come in one by one are there whatever the ticker does: motion
// off, a screen reader, a held ticker, frames with no clock time. the
// settings route page and onboarding's route step alike. on a small
// phone with large text the page scrolls and says there is more below.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        useDatabasesForTest,
        useEngineForTest,
        AppStateRoute;
import 'package:kryfo/screens/modes_screen.dart';
import 'package:kryfo/screens/onboarding_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/fit_column.dart';
import 'package:kryfo/widgets/stagger_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart' show DevTestDb, devApp, devMem, devWorld;
import 'narrow_settings.dart' show loadAppFonts;

class _Engine implements HaloEngine {
  final modes = <String>[];
  @override
  String setTransportMode(String mode) {
    modes.add(mode);
    return 'ok';
  }

  @override
  String nostrInit(String relaysCSV) => 'ok';
  @override
  Map<String, dynamic> transportState() => {'relays': const []};
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

late _Engine _eng;

// how much of [f] reaches the screen through every fade above it
double seen(WidgetTester t, Finder f) {
  RenderObject? r = t.renderObject(f);
  var o = 1.0;
  while (r != null) {
    if (r is RenderOpacity) o *= r.opacity;
    if (r is RenderAnimatedOpacityMixin) {
      o *= r.opacity.value;
    }
    r = r.parent;
  }
  return o;
}

// fully shown, and a tap at its place lands on it
void there(WidgetTester t, Finder f, String why) {
  expect(f, findsOneWidget, reason: why);
  expect(seen(t, f), 1.0, reason: '$why: faded');
  expect(f.hitTestable(), findsOneWidget, reason: '$why: not tappable');
}

// the tap reached the fast card: it is the one picked now
void picked(WidgetTester t) {
  final card = find.descendant(
    of: find.byKey(const ValueKey('fast')),
    matching: find.byType(Semantics),
  );
  expect(t.widget<Semantics>(card.first).properties.selected, isTrue);
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

Widget _cards(List<int> taps) => MaterialApp(
  home: Scaffold(
    body: ListView(
      children: staggerAll([
        for (var i = 0; i < 4; i++)
          SizedBox(
            height: 80,
            child: TextButton(
              onPressed: () => taps.add(i),
              child: Text('card $i'),
            ),
          ),
      ]),
    ),
  ),
);

Widget _modes({bool still = false, double scale = 1}) =>
    devApp(const ModesScreen(), still: still, scale: scale);

void main() {
  setUpAll(loadAppFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    _eng = _Engine();
    useEngineForTest(_eng);
    await devWorld();
    final db = DevTestDb(devMem);
    useDatabasesForTest(db, Session(db));
    appState.sendModeForTest = 'private';
  });

  tearDown(() {
    appState.sendModeForTest = 'private';
    setL10nLocale(const Locale('en'));
  });

  void quiet(WidgetTester t) {
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  void size(WidgetTester t, Size s) {
    t.view.physicalSize = s;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  Finder private() => find.text(l10n.modesPrivate);
  Finder fast() => find.text(l10n.modesFast);
  Finder more() => find.byKey(const ValueKey('fit-more'));

  testWidgets('motion off: the route cards and the arrow are there from the '
      'first frame', (t) async {
    quiet(t);
    size(t, const Size(320, 568));
    await t.pumpWidget(_modes(still: true, scale: 2));
    await t.pump();
    there(t, private(), 'private');
    // below the fold: in the tree at rest, and the arrow says so at once
    expect(seen(t, fast()), 1.0);
    expect(seen(t, more()), 1.0, reason: 'no sign of more below');
  });

  testWidgets('a screen reader: the cards at rest, no entrance', (t) async {
    quiet(t);
    size(t, const Size(411, 891));
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await t.pumpWidget(_modes());
    there(t, private(), 'private');
    there(t, fast(), 'fast');
  });

  testWidgets('a held ticker: every card shown and tappable', (t) async {
    quiet(t);
    size(t, const Size(411, 891));
    await t.pumpWidget(
      devApp(const TickerMode(enabled: false, child: ModesScreen())),
    );
    await t.pump(const Duration(seconds: 1));
    there(t, private(), 'private');
    there(t, fast(), 'fast');
    await t.tap(fast());
    await t.pump(const Duration(seconds: 1));
    picked(t);
  });

  testWidgets('frames with no clock time: every card shown and tappable', (
    t,
  ) async {
    quiet(t);
    size(t, const Size(411, 891));
    await t.pumpWidget(_modes());
    for (var i = 0; i < 4; i++) {
      await t.pump();
    }
    there(t, private(), 'private');
    there(t, fast(), 'fast');
    await t.tap(fast());
    await t.pump();
    picked(t);
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('a plain list: held ticker and still clock show every card', (
    t,
  ) async {
    final taps = <int>[];
    await t.pumpWidget(TickerMode(enabled: false, child: _cards(taps)));
    for (var i = 0; i < 4; i++) {
      there(t, find.text('card $i'), 'held $i');
    }
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
    await t.pumpWidget(_cards(taps));
    for (var i = 0; i < 4; i++) {
      await t.pump();
    }
    for (var i = 0; i < 4; i++) {
      there(t, find.text('card $i'), 'still clock $i');
      await t.tap(find.text('card $i'));
    }
    expect(taps, [0, 1, 2, 3]);
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('a ticker held on the way in: the cards land anyway', (t) async {
    final taps = <int>[];
    final on = ValueNotifier(true);
    await t.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: on,
        builder: (_, v, _) => TickerMode(enabled: v, child: _cards(taps)),
      ),
    );
    await t.pump(const Duration(milliseconds: 20));
    on.value = false;
    await t.pump(const Duration(milliseconds: 20));
    for (var i = 0; i < 4; i++) {
      there(t, find.text('card $i'), 'held mid-way $i');
    }
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('the entrance still plays when it can be seen', (t) async {
    await t.pumpWidget(_cards([]));
    await t.pump(const Duration(milliseconds: 16));
    await t.pump(const Duration(milliseconds: 16));
    expect(seen(t, find.text('card 3')), lessThan(1.0));
    await t.pump(const Duration(seconds: 1));
    for (var i = 0; i < 4; i++) {
      there(t, find.text('card $i'), 'played $i');
    }
  });

  for (final s in const [Size(320, 568), Size(360, 640)]) {
    for (final scale in const [1.3, 2.0]) {
      testWidgets('small phone ${s.width.toInt()}x${s.height.toInt()} at '
          'x$scale: both cards reachable, the arrow while more is below', (
        t,
      ) async {
        quiet(t);
        size(t, s);
        final errors = <String>[];
        final was = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.exceptionAsString());
        try {
          await t.pumpWidget(_modes(scale: scale));
          await settle(t);
          there(t, private(), 'private');
          final scroll = find.descendant(
            of: find.byType(FitColumn),
            matching: find.byType(Scrollable),
          );
          final pos = t.state<ScrollableState>(scroll.first).position;
          // a card under the fold always has the arrow over it
          final below =
              t.getRect(fast()).bottom >
              t.getRect(find.byType(FitColumn)).bottom;
          if (below) expect(pos.extentAfter, greaterThan(1));
          expect(seen(t, more()), pos.extentAfter > 1 ? 1.0 : 0.0);
          await t.ensureVisible(fast());
          await settle(t);
          there(t, fast(), 'fast after scrolling');
          await t.tap(fast());
          await settle(t);
          picked(t);
          pos.jumpTo(pos.maxScrollExtent);
          await settle(t);
          expect(seen(t, more()), 0.0, reason: 'arrow at the end');
        } finally {
          FlutterError.onError = was;
        }
        expect(errors, isEmpty, reason: errors.join('\n'));
      });
    }
  }

  testWidgets('the arrow shows on the smallest phone at x2', (t) async {
    quiet(t);
    size(t, const Size(320, 568));
    await t.pumpWidget(_modes(scale: 2));
    await settle(t);
    expect(
      t.getRect(fast()).top,
      greaterThan(t.getRect(find.byType(FitColumn)).bottom - 48),
    );
    expect(seen(t, more()), 1.0);
  });

  // onboarding's route step: the same two cards through the same entrance
  for (final s in const [Size(320, 568), Size(360, 640)]) {
    for (final (scale, held) in const [
      (1.3, false),
      (2.0, false),
      (2.0, true),
    ]) {
      testWidgets(
        'onboarding route step ${s.width.toInt()}x${s.height.toInt()} '
        'at x$scale${held ? ', ticker held' : ''}: both cards reachable',
        (t) async {
          quiet(t);
          size(t, s);
          final errors = <String>[];
          final was = FlutterError.onError;
          FlutterError.onError = (d) => errors.add(d.exceptionAsString());
          final sem = t.ensureSemantics();
          try {
            final screen = OnboardingScreen(
              appState: appState,
              onComplete: () {},
            );
            await t.pumpWidget(
              devApp(
                held ? TickerMode(enabled: false, child: screen) : screen,
                scale: scale,
              ),
            );
            await settle(t);
            t.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(3);
            await settle(t);
            there(t, private(), 'private');
            await t.ensureVisible(fast());
            await settle(t);
            there(t, fast(), 'fast after scrolling');
            await t.tap(fast());
            await settle(t);
            expect(t.getSemantics(fast()), isSemantics(isChecked: true));
            await t.pumpWidget(const SizedBox());
            await settle(t);
          } finally {
            FlutterError.onError = was;
            sem.dispose();
          }
          expect(errors, isEmpty, reason: errors.join('\n'));
        },
      );
    }
  }
}
