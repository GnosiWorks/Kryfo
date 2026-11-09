// SPDX-License-Identifier: GPL-3.0-or-later
// every word in onboarding is in a full colour: no grey or second tone, no
// fade at rest, and 4.5:1 on what it sits on (3:1 for big type and icons).
// all six steps, every accent, both themes, the play build with and without
// play services and the foss one, plus the states the steps pass through.
// a source scan keeps grey and dimmed words out of the files
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/bridge_mode.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/google_push.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        HaloDb,
        HaloEngine,
        appState,
        useDatabasesForTest,
        useEngineForTest,
        AppStateRoute,
        AppStateProfile,
        AppStateBridges,
        AppStateDelivery;
import 'package:kryfo/screens/handle_screen.dart'
    show HandleAvailability, HandleSlowLine;
import 'package:kryfo/screens/onboarding_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/store.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'narrow_settings.dart' show loadAppFonts;

const _gpush = MethodChannel('halo/gpush');

Widget _framed(Widget home) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: home,
);

double _ratio(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

// what a paragraph sits on: the solid ground under it, with every see
// through layer between laid over it
Color _ground(Element e) {
  final layers = <Color>[];
  Color? solid;
  e.visitAncestorElements((a) {
    final w = a.widget;
    Color? c;
    if (w is Scaffold) c = w.backgroundColor;
    if (w is Material && w.type != MaterialType.transparency) c = w.color;
    if (w is DecoratedBox && w.decoration is BoxDecoration) {
      c = (w.decoration as BoxDecoration).color;
    }
    if (w is ColoredBox) c = w.color;
    if (c == null || c.a == 0) return true;
    if (c.a == 1) {
      solid = c;
      return false;
    }
    layers.add(c);
    return true;
  });
  var g = solid ?? HaloColors.ink;
  for (final c in layers.reversed) {
    g = Color.alphaBlend(c, g);
  }
  return g;
}

// how much of a paragraph reaches the screen through the fades above it
double _seen(RenderObject r) {
  var o = 1.0;
  RenderObject? at = r;
  while (at != null) {
    if (at is RenderOpacity) o *= at.opacity;
    if (at is RenderAnimatedOpacityMixin) o *= at.opacity.value;
    at = at.parent;
  }
  return o;
}

// every span of every paragraph on screen, as "where: why" for each misfit
List<String> _misfits(WidgetTester t, String where) {
  final bad = <String>[];
  final grey = {HaloColors.text2, HaloColors.text3, HaloColors.warm};
  final screen = Offset.zero & t.view.physicalSize / t.view.devicePixelRatio;
  for (final e in find.byType(RichText).evaluate()) {
    final r = e.renderObject;
    if (r is! RenderParagraph || !r.hasSize || !r.attached) continue;
    final box = r.localToGlobal(Offset.zero) & r.size;
    if (!box.overlaps(screen)) continue;
    final o = _seen(r);
    // hidden, as the step bar on the welcome step: not words on screen
    if (o == 0) continue;
    final icon = e.findAncestorWidgetOfExactType<Icon>() != null;
    final ground = _ground(e);
    void walk(InlineSpan s, TextStyle? up) {
      final style = up?.merge(s.style) ?? s.style;
      if (s is TextSpan) {
        final words = (s.text ?? '').trim();
        if (words.isNotEmpty) {
          final c = style?.color;
          final name = words.length > 40 ? '${words.substring(0, 40)}…' : words;
          if (c == null) {
            bad.add('$where: "$name" has no colour');
          } else {
            if (grey.contains(c)) bad.add('$where: "$name" in grey');
            if (o < 1) bad.add('$where: "$name" faded to $o');
            final size = style?.fontSize ?? 14;
            final bold = (style?.fontWeight?.value ?? 400) >= 700;
            final big = icon || size >= 18 || (size >= 14 && bold);
            final need = big ? 3.0 : 4.5;
            final ratio = _ratio(c, ground);
            if (ratio < need) {
              bad.add('$where: "$name" ${ratio.toStringAsFixed(2)}:1');
            }
          }
        }
      }
      s.visitDirectChildren((child) {
        walk(child, style);
        return true;
      });
    }

    walk(r.text, null);
  }
  return bad;
}

String _src(String path) => File(path).readAsStringSync();

// one class's source, from its line to the next top level class
String _classOf(String src, String name) {
  final from = src.indexOf('class $name ');
  expect(from, isNot(-1), reason: name);
  final next = src.indexOf('\nclass ', from + 1);
  return src.substring(from, next == -1 ? src.length : next);
}

void main() {
  setUpAll(loadAppFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    final db = _Db();
    useDatabasesForTest(db, Session(db));
    useEngineForTest(_Engine());
    appState.myId = 'amber-river-lantern-x';
    appState.sendModeForTest = 'private';
  });

  void quiet(WidgetTester t) {
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    t.view.physicalSize = const Size(411, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    addTearDown(() => HaloColors.setLight(false));
    addTearDown(() => HaloColors.setAccent(HaloAccent.yellow));
    addTearDown(() => playBuildForTest = null);
    addTearDown(() => appState.bridgeSetupForTest = const BridgeSetup());
    addTearDown(() => appState.sendModeForTest = 'private');
    addTearDown(() => m.setMockMethodCallHandler(_gpush, null));
  }

  // a build: play with or without play services, or foss
  void build(WidgetTester t, {required bool play, bool google = false}) {
    playBuildForTest = play;
    GooglePush.instance.forgetAvailable();
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _gpush,
      (c) async => c.method == 'available' ? google : null,
    );
    appState.googleAvailableForTest = google;
  }

  Future<PageController> open(WidgetTester t) async {
    await t.pumpWidget(
      _framed(OnboardingScreen(appState: appState, onComplete: () {})),
    );
    await t.pump(const Duration(seconds: 1));
    return t.widget<PageView>(find.byType(PageView)).controller!;
  }

  Future<void> step(WidgetTester t, PageController pages, int i) async {
    pages.jumpToPage(i);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  }

  group('every step', () {
    for (final light in [false, true]) {
      for (final accent in HaloAccent.values) {
        final mode = light ? 'light' : 'dark';
        testWidgets('${accent.name} in $mode', (t) async {
          quiet(t);
          HaloColors.setLight(light);
          HaloColors.setAccent(accent);
          final bad = <String>[];
          for (final (name, play, google) in [
            ('play', true, true),
            ('play, no play services', true, false),
            ('foss', false, false),
          ]) {
            build(t, play: play, google: google);
            final pages = await open(t);
            final count = onboardingSteps().length;
            expect(count, 6);
            for (var i = 0; i < count; i++) {
              await step(t, pages, i);
              bad.addAll(_misfits(t, '$name, step ${i + 1}'));
            }
            await close(t);
          }

          // tor blocked or watched: the route step's one card
          build(t, play: true, google: true);
          appState.bridgeSetupForTest = const BridgeSetup(skipDirect: true);
          var pages = await open(t);
          await step(t, pages, 3);
          expect(find.text(l10n.onboardingRouteBlockedLead), findsOneWidget);
          bad.addAll(_misfits(t, 'route, blocked'));
          await close(t);
          appState.bridgeSetupForTest = const BridgeSetup();

          // fast: google push with its fast line, the helper app shown,
          // not pickable
          appState.sendModeForTest = 'balanced';
          pages = await open(t);
          await step(t, pages, 4);
          expect(
            find.text(l10n.gettingMessagesHelperOnionOnly),
            findsOneWidget,
          );
          bad.addAll(_misfits(t, 'delivery, fast'));
          await close(t);
          appState.sendModeForTest = 'private';

          // a claimed @name, back on its step
          await appState.setMyHandle('wren');
          pages = await open(t);
          await step(t, pages, 2);
          bad.addAll(_misfits(t, 'claimed @name'));
          await close(t);
          await appState.setMyHandle(null);

          // the @name answers as the step shows them
          for (final (s, slow) in [
            ('checking', false),
            ('checking', true),
            ('free', false),
            ('taken', false),
            ('shape', false),
            ('failed', false),
          ]) {
            await t.pumpWidget(
              _framed(
                Scaffold(
                  backgroundColor: HaloColors.ink,
                  body: Column(
                    children: [
                      HandleAvailability(state: s, slow: slow),
                      HandleSlowLine(show: slow),
                    ],
                  ),
                ),
              ),
            );
            await t.pump(const Duration(seconds: 1));
            bad.addAll(_misfits(t, '@name $s${slow ? ', slow' : ''}'));
          }
          await close(t);
          expect(bad, isEmpty, reason: bad.toSet().join('\n'));
        });
      }
    }
  });

  group('source', () {
    // grey, a second tone or words dimmed by opacity
    final grey = RegExp(
      r'HaloColors\.(text2|text3|warm)\b'
      r'|opacity:[^,;\n]*\b0?\.\d'
      r'|HaloColors\.(text|amberText)\.withValues\(alpha',
    );

    List<String> hits(String where, String src) => [
      for (final (i, line) in src.split('\n').indexed)
        if (grey.hasMatch(line)) '$where:${i + 1}: ${line.trim()}',
    ];

    test('onboarding draws no grey or dimmed words', () {
      expect(
        hits('onboarding_screen', _src('lib/screens/onboarding_screen.dart')),
        isEmpty,
      );
    });

    test('the @name pieces the step uses draw none either', () {
      final src = _src('lib/screens/handle_screen.dart');
      for (final c in ['HandleSlowLine', 'HandleAvailability', 'HandleField']) {
        final body = _classOf(src, c);
        expect(hits(c, body), isEmpty);
        // raw status colours fail in the light theme: their text twins
        expect(
          RegExp(r'c = HaloColors\.(green|rose|amber);').hasMatch(body),
          isFalse,
          reason: c,
        );
      }
    });

    test('the language row and the computer step draw none either', () {
      final lang = _classOf(
        _src('lib/widgets/language_sheet.dart'),
        'LanguageRow',
      );
      expect(hits('LanguageRow', lang), isEmpty);
      expect(
        hits('desk_run_section', _src('lib/screens/desk_run_section.dart')),
        isEmpty,
      );
    });
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
  Future<String> handleCheck(String h) async => 'free';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
