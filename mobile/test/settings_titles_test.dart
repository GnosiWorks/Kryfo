// SPDX-License-Identifier: GPL-3.0-or-later
// every section title on the pages and sheets off settings is the one
// HaloSection: the same style and gaps on each, nothing drawn its own way.
// it holds its contrast in every accent and theme, and at big text sizes
// and in every language it wraps, never clips, starting on the right side
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/atmosphere.dart';
import 'package:kryfo/bridge_mode.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloEngine, appState, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/screens/appearance_screen.dart';
import 'package:kryfo/screens/bridges_screen.dart';
import 'package:kryfo/screens/getting_messages_screen.dart';
import 'package:kryfo/screens/restore_screen.dart';
import 'package:kryfo/screens/settings_screen.dart';
import 'package:kryfo/screens/transport_screen.dart';
import 'package:kryfo/screens/wallpaper_sheet.dart';
import 'package:kryfo/screens/why_kryfo_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/wallpaper.dart';
import 'package:kryfo/widgets/halo_rows.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart' show DevTestDb, devApp, devMem, devWorld;
import 'narrow_settings.dart' show loadAppFonts;

// the pages and sheets settings opens, and the ones they open in turn
const _settingsFiles = {
  'settings_screen',
  'why_kryfo_screen',
  'appearance_screen',
  'wallpaper_sheet',
  'transport_screen',
  'bridges_screen',
  'bridge_sheets',
  'seen_screen',
  'modes_screen',
  'blocked_screen',
  'pins_screen',
  'lock_setup_screen',
  'pin_flow_screen',
  'hide_picker',
  'backup_screen',
  'restore_screen',
  'getting_messages_screen',
  'follow_section',
  'dev_about_sheet',
};

// opened from there, but not settings: a chat, the home and the camera
const _notSettings = {'chat_screen', 'home_screen', 'scan_screen'};

// what a title looks like and the gaps around it, as on every page
const _above = 28.0;
const _below = 10.0;
TextStyle _want() => HaloType.sans(
  size: 14,
  weight: FontWeight.w600,
  color: HaloColors.amberText,
);

String _src(String name) => File('lib/screens/$name.dart').readAsStringSync();

class _Engine implements HaloEngine {
  @override
  String setBridgeMode(String mode, String opts) => 'ok';
  @override
  String bridgeLineChecks() => '[]';
  @override
  Map<String, dynamic> transportState() => {
    'relays': [
      {'url': 'wss://relay.example', 'fails': 0},
    ],
    'sub_count': 0,
    'secs_since_recv': -1,
    'secs_since_send': -1,
    'hsdir_uploads': 0,
    'publishing_secs': -1,
  };
  @override
  Map<String, dynamic> memStats() => const {};
  @override
  String lastReconnect() => '';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

// a page, the titles it shows, and what to do once it is up
class _Page {
  final String name;
  final Widget Function() build;
  final List<String> Function() titles;
  final Future<void> Function(WidgetTester t)? after;
  final void Function()? setUp;
  const _Page(this.name, this.build, this.titles, {this.after, this.setUp});
}

Future<void> _reach(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await t.pump(const Duration(milliseconds: 500));
}

// a button that opens the wallpaper sheet, tapped
class _SheetOpener extends StatelessWidget {
  const _SheetOpener();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Builder(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showWallpaperSheet(ctx, Atmo.none, allowPhoto: true),
        child: const SizedBox(width: 60, height: 60, child: Text('open')),
      ),
    ),
  );
}

final _pages = [
  _Page(
    'settings',
    () => const SettingsScreen(),
    () => [
      l10n.settingsPrivacy,
      l10n.settingsSecurity,
      l10n.settingsAppearance,
      l10n.settingsBackup,
      l10n.settingsVoice,
      l10n.settingsAbout,
      l10n.settingsFollowTitle,
      l10n.settingsDangerZone,
    ],
  ),
  _Page(
    'appearance',
    () => AppearanceScreen(
      onPick: (_) async {},
      readDefault: () async => ChatWall.none,
    ),
    () => [l10n.settingsAccentColour, l10n.appearanceChatWallpaper],
  ),
  _Page(
    'wallpaper sheet',
    () => const _SheetOpener(),
    () => [
      l10n.wallpaperMoods,
      l10n.wallpaperGradients,
      l10n.wallpaperPatterns,
      l10n.wallpaperYourPhoto,
    ],
    after: (t) async {
      await t.tap(find.text('open'));
    },
  ),
  _Page(
    'transport',
    () => const TransportScreen(),
    () => [
      l10n.transportStayingAlive,
      l10n.appTor,
      l10n.transportNetwork,
      l10n.transportRelays,
      l10n.transportTraffic,
      l10n.transportContacts,
    ],
  ),
  _Page(
    'bridges, lines saved and more open',
    () => const BridgesScreen(),
    () => [l10n.bridgesSavedLines],
    setUp: () {
      appState.bridgeSetupForTest = const BridgeSetup(
        choice: BridgeChoice.friend,
        friendLines: 'obfs4 1.2.3.4:443 ABCDEF cert=abc iat-mode=0',
        consent: 'yes',
        country: 'ir',
      );
    },
    after: (t) async {
      final more = find.text(l10n.bridgesMore);
      await _reach(t, more);
      await t.tap(more);
    },
  ),
  _Page(
    'getting messages',
    () => const GettingMessagesScreen(),
    () => [l10n.gettingMessagesOnTheLockScreen],
  ),
  _Page('restore', () => const RestoreScreen(), () => [l10n.restoreTheFile]),
  _Page(
    'why kryfo',
    () => const WhyKryfoScreen(),
    () => [l10n.whyKryfoTheHonestPart],
  ),
];

Future<void> _show(
  WidgetTester t,
  _Page page, {
  Locale locale = const Locale('en'),
  double scale = 1,
  Size size = const Size(360, 6000),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  setL10nLocale(locale);
  page.setUp?.call();
  await t.pumpWidget(
    KeyedSubtree(
      key: UniqueKey(),
      child: devApp(page.build(), locale: locale, scale: scale),
    ),
  );
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(seconds: 1));
  }
  if (page.after != null) {
    await page.after!(t);
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(seconds: 1));
    }
  }
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

// the paragraph a title is drawn in, when on screen
RenderParagraph? _paragraph(String title) {
  final f = find.text(title, findRichText: true);
  for (final e in f.evaluate()) {
    if (e.widget is RichText) return e.renderObject! as RenderParagraph;
  }
  return null;
}

bool _inSection(String title) => find
    .ancestor(of: find.text(title), matching: find.byType(HaloSection))
    .evaluate()
    .isNotEmpty;

TextStyle _styleOf(RenderParagraph p) => (p.text as TextSpan).style!;

// what a title sits on: the first solid ground above it
Color _ground(String title) {
  final e = find.text(title).evaluate().first;
  Color? found;
  e.visitAncestorElements((a) {
    final w = a.widget;
    Color? c;
    if (w is Scaffold) c = w.backgroundColor;
    if (w is Material && w.type != MaterialType.transparency) c = w.color;
    if (w is DecoratedBox && w.decoration is BoxDecoration) {
      c = (w.decoration as BoxDecoration).color;
    }
    if (c != null && c.a == 1) {
      found = c;
      return false;
    }
    return true;
  });
  return found ?? HaloColors.surface;
}

double _ratio(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  setUpAll(loadAppFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    appState.sendModeForTest = 'balanced';
    useEngineForTest(_Engine());
    await devWorld();
    final db = DevTestDb(devMem);
    useDatabasesForTest(db, Session(db));
  });

  void quiet(WidgetTester t) {
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    addTearDown(t.view.reset);
    addTearDown(() => setL10nLocale(const Locale('en')));
    addTearDown(() => HaloColors.setLight(false));
    addTearDown(() => HaloColors.setAccent(HaloAccent.yellow));
    addTearDown(() => appState.bridgeSetupForTest = const BridgeSetup());
  }

  group('source', () {
    test('settings pages draw no section title of their own', () {
      final own = RegExp(
        r'class _(Head|Label|Section|Title)\b|Widget _(head|label|title)\(',
      );
      final bad = [
        for (final f in _settingsFiles)
          for (final m in own.allMatches(_src(f))) '$f: ${m[0]}',
      ];
      expect(bad, isEmpty);
    });

    test('a title brings its own gap: no spacer goes before one', () {
      final before = RegExp(
        r'SizedBox\(height: [\d.]+\),\s*(HaloSection\(|const FollowSection\()',
      );
      final bad = [
        for (final f in _settingsFiles)
          for (final m in before.allMatches(_src(f)))
            '$f: ${m[0]!.replaceAll(RegExp(r'\s+'), ' ')}',
      ];
      expect(bad, isEmpty);
    });

    test('every page settings opens is checked here', () {
      final imp = RegExp(r"^import '([a-z_]+)\.dart'", multiLine: true);
      final missed = <String>[];
      for (final f in _settingsFiles) {
        for (final m in imp.allMatches(_src(f))) {
          final n = m[1]!;
          if (!File('lib/screens/$n.dart').existsSync()) continue;
          if (!_settingsFiles.contains(n) && !_notSettings.contains(n)) {
            missed.add('$f opens $n');
          }
        }
      }
      expect(missed, isEmpty);
    });
  });

  group('style', () {
    testWidgets('bigger and heavier than before, in the accent', (t) async {
      quiet(t);
      for (final light in [false, true]) {
        for (final a in HaloAccent.values) {
          HaloColors.setLight(light);
          HaloColors.setAccent(a);
          // keyed: a const tree would keep the last theme's colour
          await t.pumpWidget(
            devApp(Scaffold(body: HaloSection('Tor', key: UniqueKey()))),
          );
          final s = _styleOf(_paragraph('Tor')!);
          final why = '${a.name} ${light ? 'light' : 'dark'}';
          expect(s.fontSize, greaterThanOrEqualTo(14), reason: why);
          expect(s.fontWeight!.value, greaterThanOrEqualTo(600), reason: why);
          expect(s.color, HaloColors.amberText, reason: why);
        }
      }
    });

    for (final page in _pages) {
      testWidgets('${page.name}: every title is a HaloSection', (t) async {
        quiet(t);
        await _show(t, page);
        final bad = <String>[];
        final want = _want();
        for (final title in page.titles()) {
          final p = _paragraph(title);
          if (p == null) {
            bad.add('not shown: $title');
            continue;
          }
          if (!_inSection(title)) bad.add('drawn its own way: $title');
          final s = _styleOf(p);
          if (s.fontSize != want.fontSize ||
              s.fontWeight != want.fontWeight ||
              s.color != want.color ||
              s.fontFamily != want.fontFamily) {
            bad.add(
              'other style: $title (${s.fontFamily} ${s.fontSize} '
              '${s.fontWeight})',
            );
          }
        }
        // and each title on the page is one of those
        final sections = t.widgetList<HaloSection>(find.byType(HaloSection));
        for (final s in sections) {
          if (!page.titles().contains(s.label)) bad.add('unlisted: ${s.label}');
        }
        await _close(t);
        expect(bad, isEmpty);
      });
    }

    // a title 28 under the group before it, its group 10 under it
    for (final name in ['settings', 'appearance']) {
      testWidgets('$name: the same gaps around every title', (t) async {
        quiet(t);
        final page = _pages.firstWhere((p) => p.name == name);
        await _show(t, page);
        final groups = [
          for (final e in find.byType(Material).evaluate())
            if ((e.widget as Material).shape is RoundedRectangleBorder)
              t.getRect(find.byWidget(e.widget)),
          for (final e in find.byType(Container).evaluate())
            if ((e.widget as Container).decoration is BoxDecoration &&
                ((e.widget as Container).decoration as BoxDecoration)
                        .borderRadius !=
                    null)
              t.getRect(find.byWidget(e.widget)),
        ];
        final gaps = <String>[];
        for (final title in page.titles()) {
          final r = t.getRect(find.text(title));
          final under = groups.where((g) => g.top >= r.bottom - 0.5).toList()
            ..sort((a, b) => a.top.compareTo(b.top));
          final over = groups.where((g) => g.bottom <= r.top + 0.5).toList()
            ..sort((a, b) => b.bottom.compareTo(a.bottom));
          if (under.isNotEmpty) {
            gaps.add('$title below ${(under.first.top - r.bottom).round()}');
          }
          // only where a group is what comes right before it
          if (over.isNotEmpty) {
            final between = find
                .byType(RichText)
                .evaluate()
                .map((e) => t.getRect(find.byWidget(e.widget)))
                .where(
                  (x) => x.top >= over.first.bottom && x.bottom <= r.top + 0.5,
                );
            if (between.isEmpty) {
              gaps.add('$title above ${(r.top - over.first.bottom).round()}');
            }
          }
        }
        await _close(t);
        for (final g in gaps) {
          final n = int.parse(g.split(' ').last);
          final want = g.contains(' below ') ? _below : _above;
          expect(n, want.round(), reason: g);
        }
        expect(gaps, isNotEmpty);
      });
    }
  });

  group('contrast', () {
    // 14 at w600 is not large text: 4.5:1
    for (final light in [false, true]) {
      for (final accent in HaloAccent.values) {
        final mode = light ? 'light' : 'dark';
        testWidgets('${accent.name} in $mode', (t) async {
          quiet(t);
          HaloColors.setLight(light);
          HaloColors.setAccent(accent);
          final bad = <String>[];
          for (final name in ['settings', 'wallpaper sheet', 'transport']) {
            final page = _pages.firstWhere((p) => p.name == name);
            await _show(t, page);
            for (final title in page.titles()) {
              final p = _paragraph(title);
              if (p == null) continue;
              final c = _styleOf(p).color!;
              final ground = _ground(title);
              final r = _ratio(c, ground);
              if (r < 4.5) bad.add('$name $title ${r.toStringAsFixed(2)}');
              if (c == HaloColors.text3 || c == HaloColors.text2) {
                bad.add('$name $title in grey');
              }
            }
            await _close(t);
          }
          expect(bad, isEmpty);
        });
      }
    }
  });

  group('big text', () {
    final rtl = {'ar', 'fa'};
    for (final page in _pages) {
      testWidgets('${page.name}: titles wrap whole in every language', (
        t,
      ) async {
        quiet(t);
        final bad = <String>[];
        final was = FlutterError.onError;
        var now = '';
        FlutterError.onError = (d) =>
            bad.add('$now: ${d.exceptionAsString().split('\n').first}');
        try {
          for (final locale in AppLocalizations.supportedLocales) {
            for (final scale in [1.5, 2.0]) {
              now = '${locale.toLanguageTag()} x$scale';
              await _show(
                t,
                page,
                locale: locale,
                scale: scale,
                size: const Size(360, 16000),
              );
              for (final title in page.titles()) {
                final p = _paragraph(title);
                if (p == null) {
                  bad.add('$now not shown: $title');
                  continue;
                }
                final w = p.size.width;
                if (p.didExceedMaxLines) bad.add('$now cut short: $title');
                if (p.getMaxIntrinsicHeight(w) > p.size.height + 0.5) {
                  bad.add('$now clipped: $title');
                }
                final left = p.localToGlobal(Offset.zero).dx;
                if (left < -0.5 || left + w > 360.5) {
                  bad.add('$now off screen: $title');
                }
                // the words start at the reading side of the page
                final boxes = p.getBoxesForSelection(
                  TextSelection(baseOffset: 0, extentOffset: title.length),
                );
                final atStart = rtl.contains(locale.languageCode)
                    ? left + boxes.map((b) => b.right).reduce(math.max) > 180
                    : left + boxes.map((b) => b.left).reduce(math.min) < 180;
                if (!atStart) bad.add('$now not at its start: $title');
              }
              await _close(t);
            }
          }
        } finally {
          FlutterError.onError = was;
        }
        expect(bad, isEmpty, reason: bad.toSet().join('\n'));
      });
    }
  });
}
