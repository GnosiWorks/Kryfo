// SPDX-License-Identifier: GPL-3.0-or-later
// settings words wear the normal text colour: no text2 or text3 in the
// settings screens' source except on icons, and the words on the busiest
// pages hold 4.5:1 on what they sit on in both themes
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        useDatabasesForTest,
        useEngineForTest,
        AppStateRoute;
import 'package:kryfo/screens/backup_screen.dart';
import 'package:kryfo/screens/settings_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart' show DevTestDb, devApp, devMem, devWorld;

const settingsScreens = [
  'settings_screen',
  'appearance_screen',
  'auto_get_screen',
  'dev_about_sheet',
  'icon_screen',
  'licences_screen',
  'linked_devices_screen',
  'notifications_screen',
  'profile_screen',
  'translation_screen',
  'backup_screen',
  'blocked_screen',
  'lock_setup_screen',
];

// what a grey may still colour: icons, back buttons, marks, dots
const iconHolders = [
  'Icon(',
  'BackButton(',
  'IconThemeData(',
  'BoxDecoration(',
  '_MarkPainter(',
];
const textHolders = ['HaloType.', 'TextStyle(', 'Text('];

// each grey use whose nearest holder is a text style, as file:line
List<String> greyText(String path) {
  final s = File(path).readAsStringSync();
  final bad = <String>[];
  for (final m in RegExp(r'HaloColors\.text[23]\b').allMatches(s)) {
    final before = s.substring(0, m.start);
    int last(List<String> ts) =>
        ts.map(before.lastIndexOf).reduce(math.max);
    if (last(textHolders) > last(iconHolders)) {
      final line = '\n'.allMatches(before).length + 1;
      bad.add('$path:$line');
    }
  }
  return bad;
}

double ratio(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

// the colour a widget paints behind its child, if any
Color? fillOf(Widget w) => switch (w) {
  ColoredBox(:final color) => color,
  DecoratedBox(decoration: BoxDecoration(:final color?)) => color,
  Material(:final color?, :final type) when type != MaterialType.transparency =>
    color,
  _ => null,
};

// the ground under an element: fills found going up, laid over the page
Color groundOf(Element e) {
  final fills = <Color>[];
  e.visitAncestorElements((a) {
    final c = fillOf(a.widget);
    if (c != null) fills.add(c);
    return c == null || c.a < 1;
  });
  var g = HaloColors.surface;
  for (final c in fills.reversed) {
    g = Color.alphaBlend(c, g);
  }
  return g;
}

class _Db extends DevTestDb {
  _Db() : super(devMem);
  @override
  Future<Set<String>> blockedIds() async => {};
}

class _Engine implements HaloEngine {
  @override
  String bridgeLineChecks() => '[]';
  @override
  Map<String, dynamic> transportState() => {
    'relays': const [],
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

void main() {
  test('no settings text uses text2 or text3', () {
    final bad = [
      for (final f in settingsScreens) ...greyText('lib/screens/$f.dart'),
    ];
    expect(bad, isEmpty);
  });

  test('the scan catches a grey text style', () {
    final f = File('${Directory.systemTemp.createTempSync().path}/g.dart')
      ..writeAsStringSync(
        "Text('a', style: HaloType.sans(color: HaloColors.text2));\n"
        'Icon(Icons.a, color: HaloColors.text3);\n',
      );
    expect(greyText(f.path), ['${f.path}:1']);
  });

  group('words hold 4.5:1', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'battery_opt_prompt_seen': true,
        'miui_autostart_prompt_seen': true,
      });
      FlutterSecureStorage.setMockInitialValues({});
      appState.sendModeForTest = 'balanced';
      useEngineForTest(_Engine());
      await devWorld();
      final db = _Db();
      useDatabasesForTest(db, Session(db));
    });

    for (final (name, page) in [
      ('settings', () => const SettingsScreen()),
      ('backup', () => const BackupScreen()),
    ]) {
      for (final light in [false, true]) {
        testWidgets('$name in ${light ? 'light' : 'dark'}', (t) async {
          final m = t.binding.defaultBinaryMessenger;
          m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
          addTearDown(
            () => m.setMockMethodCallHandler(SystemChannels.platform, null),
          );
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = const Size(360, 6000);
          addTearDown(t.view.reset);
          addTearDown(() => HaloColors.setLight(false));
          HaloColors.setLight(light);
          await t.pumpWidget(devApp(page()));
          for (var i = 0; i < 3; i++) {
            await t.pump(const Duration(seconds: 1));
          }
          final low = <String>[];
          var seen = 0;
          for (final e in find.byType(RichText).evaluate()) {
            // an icon's glyph is an icon, not words
            if (e.findAncestorWidgetOfExactType<Icon>() != null) continue;
            final span = (e.widget as RichText).text;
            final ground = groundOf(e);
            span.visitChildren((s) {
              final c = s.style?.color;
              if (c == null || s is! TextSpan || (s.text ?? '').trim().isEmpty) {
                return true;
              }
              seen++;
              final r = ratio(Color.alphaBlend(c, ground), ground);
              if (r < 4.5) low.add('"${s.text}" ${r.toStringAsFixed(2)}');
              return true;
            });
          }
          expect(seen, greaterThan(10));
          expect(low, isEmpty);
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 2));
        });
      }
    }
  });
}
