// SPDX-License-Identifier: GPL-3.0-or-later
// the pages off settings on a small phone, 360 wide: each language, text
// size and theme asked for, and nothing runs off the edge. the bridges page
// also keeps its switch on screen and its text buttons a finger high
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloEngine, appState, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/screens/backup_screen.dart';
import 'package:kryfo/screens/blocked_screen.dart';
import 'package:kryfo/screens/bridges_screen.dart';
import 'package:kryfo/screens/getting_messages_screen.dart';
import 'package:kryfo/screens/modes_screen.dart';
import 'package:kryfo/screens/pins_screen.dart';
import 'package:kryfo/screens/restore_screen.dart';
import 'package:kryfo/screens/seen_screen.dart';
import 'package:kryfo/screens/settings_screen.dart';
import 'package:kryfo/screens/transport_screen.dart';
import 'package:kryfo/screens/why_kryfo_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/halo_switch.dart';
import 'package:kryfo/widgets/press_scale.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart' show DevTestDb, devApp, devMem, devWorld;
import 'pin_flow_fakes.dart' show FakeHost, appOnly, makeLock;

// the app's own fonts, so a line is as wide as on a phone
Future<void> loadAppFonts() async {
  const families = {
    'Fraunces': ['Fraunces.ttf', 'Fraunces-Italic.ttf'],
    'Instrument Sans': ['InstrumentSans.ttf', 'InstrumentSans-Italic.ttf'],
    'JetBrains Mono': ['JetBrainsMono.ttf', 'JetBrainsMono-Italic.ttf'],
    'Noto Serif Cyrillic': [
      'NotoSerif-Cyrillic.ttf',
      'NotoSerif-Cyrillic-Italic.ttf',
    ],
    'Noto Sans Cyrillic': ['NotoSans-Cyrillic.ttf'],
    'Noto Sans Vietnamese': ['NotoSans-Vietnamese.ttf'],
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

// the developer world's database, which also knows who is blocked
class _Db extends DevTestDb {
  _Db() : super(devMem);
  @override
  Future<Set<String>> blockedIds() async => {
    for (final r in devMem.rows('contacts'))
      if (r['blocked'] == 1) r['halo_id'] as String,
  };
}

class _Engine implements HaloEngine {
  @override
  String bridgeState() => 'false|0|0';
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

Locale _locale(String tag) {
  final p = tag.split('_');
  return Locale.fromSubtags(
    languageCode: p[0],
    scriptCode: p.length > 1 ? p[1] : null,
  );
}

// a small phone, and one tall enough that every row of a list is built
const _heights = [640.0, 6000.0];

// brings a widget the list has not built yet into view
Future<void> _reach(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await t.pump(const Duration(milliseconds: 500));
}

void narrowSettings({
  required List<String> langs,
  required List<double> scales,
  List<bool> themes = const [false, true],
}) {
  // every page in every language, size and theme. after: what to do once
  // it is up, to reach a second state. check: what else must hold
  Future<void> sweep(
    WidgetTester t,
    Future<Widget> Function() page, {
    Future<void> Function(WidgetTester t)? after,
    void Function(WidgetTester t)? check,
  }) async {
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    addTearDown(() => setL10nLocale(const Locale('en')));
    addTearDown(() => HaloColors.setLight(false));

    final runs = <String>[];
    final was = FlutterError.onError;
    var now = '';
    FlutterError.onError = (d) {
      final where = RegExp(
        r'The relevant error-causing widget was:\s*\n\s*.*\n\s*(.*)',
      ).firstMatch(d.toString())?.group(1);
      runs.add('$now: ${d.exceptionAsString().split('\n').first} $where');
    };
    try {
      for (final lang in langs) {
        for (final scale in scales) {
          for (final light in themes) {
            for (final h in _heights) {
              now = '$lang x$scale ${light ? 'light' : 'dark'} h$h';
              t.view.physicalSize = Size(360, h);
              HaloColors.setLight(light);
              final locale = _locale(lang);
              setL10nLocale(locale);
              final w = await page();
              await t.pumpWidget(
                KeyedSubtree(
                  key: ValueKey(now),
                  child: devApp(w, locale: locale, scale: scale),
                ),
              );
              for (var i = 0; i < 3; i++) {
                await t.pump(const Duration(seconds: 1));
              }
              if (after != null) {
                await after(t);
                for (var i = 0; i < 3; i++) {
                  await t.pump(const Duration(seconds: 1));
                }
              }
              check?.call(t);
              await t.pumpWidget(const SizedBox());
              await t.pump(const Duration(seconds: 2));
            }
          }
        }
      }
    } finally {
      FlutterError.onError = was;
    }
    expect(runs, isEmpty, reason: runs.toSet().join('\n'));
  }

  // the switch whole on screen, and each text button a finger high
  void bridgesReachable(WidgetTester t) {
    final sw = find.byType(HaloSwitch);
    if (sw.evaluate().isNotEmpty) {
      final r = t.getRect(sw);
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(360));
    }
    for (final label in [
      l10n.bridgesPasteFromClipboard,
      l10n.bridgesRequestBridges,
    ]) {
      final b = find.ancestor(
        of: find.text(label),
        matching: find.byType(PressScale),
      );
      if (b.evaluate().isEmpty) continue;
      expect(t.getSize(b.first).height, greaterThanOrEqualTo(48));
    }
  }

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

  testWidgets('bridges', (t) async {
    await sweep(t, () async => const BridgesScreen(), check: bridgesReachable);
  });

  testWidgets('bridges, a line saved', (t) async {
    await sweep(
      t,
      () async => const BridgesScreen(),
      after: (t) async {
        final field = find.byType(TextField);
        await _reach(t, field);
        await t.enterText(
          field.first,
          'obfs4 1.2.3.4:443 ABCDEF cert=abc iat-mode=0',
        );
      },
      check: bridgesReachable,
    );
  });

  testWidgets('speed and privacy', (t) async {
    await sweep(t, () async => const ModesScreen());
  });

  testWidgets('getting messages', (t) async {
    await sweep(t, () async => const GettingMessagesScreen());
  });

  testWidgets('app lock, off', (t) async {
    await sweep(t, () async {
      final lock = await makeLock(null);
      return PinsScreen(
        lock: lock.state,
        host: FakeHost(lock: lock.state),
      );
    });
  });

  testWidgets('app lock, on, advanced open', (t) async {
    await sweep(
      t,
      () async {
        final lock = await makeLock(appOnly);
        return PinsScreen(
          lock: lock.state,
          host: FakeHost(lock: lock.state),
        );
      },
      after: (t) async {
        final adv = find.text(l10n.pinsAdvanced);
        await _reach(t, adv);
        await t.tap(adv);
      },
    );
  });

  testWidgets('blocked, empty', (t) async {
    await sweep(t, () async => const BlockedScreen());
  });

  testWidgets('blocked, one', (t) async {
    await devMem.insert('contacts', {
      'halo_id': 'grey-owl-dune',
      'onion': '',
      'xpub': 'x-grey-owl-dune',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'blocked': 1,
    });
    await sweep(t, () async => const BlockedScreen());
  });

  testWidgets('transport', (t) async {
    await sweep(t, () async => const TransportScreen());
  });

  testWidgets('backup', (t) async {
    await sweep(t, () async => const BackupScreen());
  });

  testWidgets('restore', (t) async {
    await sweep(t, () async => const RestoreScreen());
  });

  testWidgets('why kryfo', (t) async {
    await sweep(t, () async => const WhyKryfoScreen());
  });

  testWidgets('what we can see', (t) async {
    await sweep(t, () async => const SeenScreen());
  });

  testWidgets('settings', (t) async {
    await sweep(t, () async => const SettingsScreen());
  });
}
