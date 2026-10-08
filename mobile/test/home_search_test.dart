// SPDX-License-Identifier: GPL-3.0-or-later
// search opens from a round button in the home header: the field grows out
// of it with the keyboard up once it lands, and shrinks back on the way out.
// with less movement the page only fades. the header keeps its four
// controls on a small phone at a big font in the long languages, both
// themes, and mirrors right to left.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloDb, HaloEngine, TorHalo, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/screens/home_screen.dart';
import 'package:kryfo/screens/search_screen.dart';
import 'package:kryfo/search.dart' show SearchKind;
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Db implements HaloDb {
  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<List<Map<String, Object?>>> contacts() async => [];
  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async => {};
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async => [];
  @override
  Future<int> pendingRequestCount() async => 0;
  @override
  Future<List<Map<String, Object?>>> loadGroups() async => [];
  // nothing found, which is all the flight back needs
  @override
  Future<List<Map<String, Object?>>> searchMessages(
    String? match,
    SearchKind kind, {
    int limit = 300,
  }) async => [];
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

class _Engine implements HaloEngine {
  @override
  Map<String, dynamic> transportState() => {'relays': []};
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

Future<void> _loadFonts() async {
  const families = {
    'Fraunces': ['Fraunces.ttf', 'Fraunces-Italic.ttf'],
    'Instrument Sans': ['InstrumentSans.ttf', 'InstrumentSans-Italic.ttf'],
    'JetBrains Mono': ['JetBrainsMono.ttf', 'JetBrainsMono-Italic.ttf'],
    'Noto Serif Cyrillic': [
      'NotoSerif-Cyrillic.ttf',
      'NotoSerif-Cyrillic-Italic.ttf',
    ],
    'Noto Sans Cyrillic': ['NotoSans-Cyrillic.ttf'],
    'Noto Naskh Arabic': ['NotoNaskhArabic-Kryfo.ttf'],
    'Noto Sans Arabic': ['NotoSansArabic-Kryfo.ttf'],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      loader.addFont(
        File(
          'assets/fonts/$f',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    }
    await loader.load();
  }
}

Widget _app({
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
  home: HomeScreen(
    haloId: 'neon-tiger-saturn',
    onAddContact: () {},
    onNewGroup: () {},
    onNewRoom: () {},
    onOpenDev: () {},
    onOpenSettingsDirect: () {},
    onOpenChat: (_) {},
    onOpenGroup: (_) {},
  ),
);

void _phone(WidgetTester t, {Size size = const Size(412, 900)}) {
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

// the header comes in a beat after the page: past both
Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(seconds: 1));
  await t.pump(const Duration(seconds: 1));
}

Future<void> _drain(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

final _door = find.byType(SearchDoor);
final _flight = find.byKey(const ValueKey('search-flight'));

FocusNode _focus(WidgetTester t) =>
    t.widget<TextField>(find.byType(TextField)).focusNode!;

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    final db = _Db();
    useDatabasesForTest(db, Session(db));
    useEngineForTest(_Engine());
  });

  tearDown(() {
    HaloColors.setLight(false);
    setL10nLocale(const Locale('en'));
  });

  testWidgets('the header button grows into the field, focused on landing', (
    t,
  ) async {
    _phone(t);
    final sem = t.ensureSemantics();
    await t.pumpWidget(_app());
    await _settle(t);
    // a full finger's room, named for a screen reader as the field was
    expect(t.getSize(_door).width, greaterThanOrEqualTo(48));
    expect(t.getSize(_door).height, greaterThanOrEqualTo(48));
    expect(t.getSemantics(_door).label, l10n.searchHint);
    expect(t.getSemantics(_door).flagsCollection.isButton, isTrue);
    final round = t.getRect(
      find.descendant(of: _door, matching: find.byType(Hero)),
    );

    await t.tap(_door);
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
    // the flight starts from the round button
    expect(_flight, findsOneWidget);
    final start = t.getRect(_flight);
    expect((start.center - round.center).distance, lessThan(3));
    await t.pump(const Duration(milliseconds: 120));
    final mid = t.getRect(_flight);
    expect(mid.width, greaterThan(start.width));
    expect(mid.width, lessThan(412 - 60));
    await t.pumpAndSettle();
    expect(_flight, findsNothing);
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(_focus(t).hasFocus, isTrue);
    expect(t.getSize(find.byType(TextField)).width, greaterThan(250));

    // typed words fly back with the field, which ends in the button again
    await t.enterText(find.byType(TextField), 'map');
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byTooltip(l10n.commonBack));
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
    expect(_flight, findsOneWidget);
    expect(
      find.descendant(of: _flight, matching: find.text('map')),
      findsOneWidget,
    );
    await t.pumpAndSettle();
    expect(find.byType(SearchScreen), findsNothing);
    expect(
      t.getRect(find.descendant(of: _door, matching: find.byType(Hero))),
      round,
    );
    await _drain(t);
    sem.dispose();
  });

  testWidgets('with less movement the page only fades, nothing flies', (
    t,
  ) async {
    _phone(t);
    await t.pumpWidget(_app(still: true));
    await _settle(t);
    await t.tap(_door);
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
    expect(_flight, findsNothing);
    final route = ModalRoute.of(t.element(find.byType(SearchScreen)))!;
    expect(route.transitionDuration, kSearchFade);
    // the field is where it ends from the first frame
    final first = t.getRect(find.byType(TextField));
    expect(
      find.ancestor(
        of: find.byType(SearchScreen),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );
    await t.pumpAndSettle();
    // the edge thickens with the focus, nothing more
    final last = t.getRect(find.byType(TextField));
    expect(
      (last.topLeft - first.topLeft).distance,
      lessThan(1),
      reason: '$first $last',
    );
    expect(_focus(t).hasFocus, isTrue);
    await t.tap(find.byTooltip(l10n.commonBack));
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
    expect(_flight, findsNothing);
    await t.pumpAndSettle();
    expect(find.byType(SearchScreen), findsNothing);
    await _drain(t);
  });

  for (final light in [false, true]) {
    for (final code in ['en', 'de', 'ru', 'fa', 'ar']) {
      testWidgets(
        'the header fits at 360 and 1.3 in $code, ${light ? 'light' : 'dark'}',
        (t) async {
          HaloColors.setLight(light);
          setL10nLocale(Locale(code));
          _phone(t, size: const Size(360, 760));
          final sem = t.ensureSemantics();
          await t.pumpWidget(_app(locale: Locale(code), scale: 1.3));
          await _settle(t);
          expect(t.takeException(), isNull);
          final gear = t.getRect(find.bySemanticsLabel(l10n.commonSettings));
          final add = t.getRect(find.bySemanticsLabel(l10n.homeAddAContact));
          final door = t.getRect(_door);
          final tor = t.getRect(find.byType(TorHalo));
          for (final r in [door, gear, add, tor]) {
            expect(r.left, greaterThanOrEqualTo(0));
            expect(r.right, lessThanOrEqualTo(360));
          }
          // in reading order, mirrored right to left
          final rtl = code == 'fa' || code == 'ar';
          final order = [door, gear, add, tor];
          for (var i = 0; i + 1 < order.length; i++) {
            if (rtl) {
              expect(order[i].left, greaterThanOrEqualTo(order[i + 1].right));
            } else {
              expect(order[i].right, lessThanOrEqualTo(order[i + 1].left));
            }
          }
          // the date beside them keeps a readable width
          final date = t.getRect(find.text('neon-tiger-saturn'));
          expect(date.width, greaterThan(60));
          await t.tap(_door);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          expect(_focus(t).hasFocus, isTrue);
          await _drain(t);
          sem.dispose();
        },
      );
    }
  }
}
