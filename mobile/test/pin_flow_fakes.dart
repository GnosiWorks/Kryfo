// SPDX-License-Identifier: GPL-3.0-or-later
// stand-ins for App lock and its flows: the lock over a storage and an
// engine kept in memory, and the app side as a list of chats that a hide
// moves and a remove brings back
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/hide_picker.dart';
import 'package:kryfo/screens/pin_flow_screen.dart';

class MemStore implements LockStore {
  final Map<String, String> m = {};

  @override
  Future<String?> read(String key) async => m[key];

  @override
  Future<void> write(String key, String value) async => m[key] = value;

  @override
  Future<void> delete(String key) async => m.remove(key);
}

// the engine's rules in dart, as lock_state_test has them: a table is
// {"v", "n", "e": {index: {"p", "k", "c", "w"}}}
class MemEngine implements PinEngine {
  Map<String, dynamic> _t(String s) => jsonDecode(s) as Map<String, dynamic>;

  static bool _clashes(Map e, int index, String pin) {
    for (final kv in e.entries) {
      if (kv.key != '$index' && (kv.value as Map)['p'] == pin) return true;
    }
    return false;
  }

  @override
  Future<Map<String, dynamic>> calibrate() async => {'n': 15, 'ms': 120};

  @override
  Future<String> newTable(int logN) async =>
      jsonEncode({'v': 2, 'n': logN, 'e': <String, dynamic>{}});

  @override
  Future<Map<String, dynamic>> check(
    String pin,
    String table,
    String legacy,
  ) async {
    var r = <String, dynamic>{
      'i': -1,
      'k': 0,
      'c': '',
      'la': false,
      'lw': false,
      'u': '',
    };
    for (final kv in (_t(table)['e'] as Map<String, dynamic>).entries) {
      final v = kv.value as Map;
      if (v['p'] == pin) {
        r = {
          ...r,
          'i': int.parse(kv.key),
          'k': v['k'],
          'c': v['c'] ?? '',
          'u': v['w'] ?? '',
        };
      }
    }
    return r;
  }

  @override
  Future<Map<String, dynamic>> setup(
    String pin,
    String table,
    String legacy,
    int index,
    int kind,
    String container,
    String wrapPlain,
  ) async {
    final t = _t(table);
    final e = Map<String, dynamic>.from(t['e'] as Map);
    if (_clashes(e, index, pin)) throw PinCollision();
    e['$index'] = {'p': pin, 'k': kind, 'c': container, 'w': wrapPlain};
    return {
      't': {...t, 'v': 2, 'e': e},
    };
  }

  @override
  Future<Map<String, dynamic>> rewrap(
    String oldPin,
    String newPin,
    String table,
    String legacy,
    int index,
  ) async {
    final t = _t(table);
    final e = Map<String, dynamic>.from(t['e'] as Map);
    final at = e['$index'] as Map?;
    if (at == null || at['p'] != oldPin) throw StateError('wrong pin');
    if ((at['w'] ?? '') == '') throw StateError('nothing wrapped');
    if (_clashes(e, index, newPin)) throw PinCollision();
    e['$index'] = {...at, 'p': newPin};
    return {
      't': {...t, 'v': 2, 'e': e},
    };
  }

  @override
  Future<String> upgrade(String table) async =>
      jsonEncode({..._t(table), 'v': 2});

  @override
  Future<String> clear(String table, int index) async {
    final t = _t(table);
    final e = Map<String, dynamic>.from(t['e'] as Map)..remove('$index');
    return jsonEncode({...t, 'v': 2, 'e': e});
  }
}

class StillClock implements LockClock {
  @override
  Future<int> uptimeMs() async => 1000000;
  @override
  Future<int> bootCount() async => 7;
}

// no fingerprint on this phone, so nothing asks the platform
class NoBio implements LockBio {
  @override
  Future<bool> ready() async => false;
  @override
  Future<String> state() async => 'none';
  @override
  Future<bool> enable() async => false;
  @override
  Future<void> disable() async {}
  @override
  Future<String> unlock(String title, String cancel) async => 'none';
}

const appPin = '1234';
const wipePin = '9999';
const decoyPin = '5555';
const vaultPin = '246810';
final vaultKey = '1f' * 32;

String _containerOf(int index, int kind) => switch (kind) {
  PinKind.decoy => HaloContainer.decoy.id,
  PinKind.vault when index == PinSlot.decoyVault => HaloContainer.decoyVault.id,
  PinKind.vault => HaloContainer.vault.id,
  _ => HaloContainer.everyday.id,
};

class Lock {
  Lock(this.state, this.store);
  final LockState state;
  final MemStore store;

  Map<String, dynamic> get entries =>
      jsonDecode(store.m['halo.lock.table']!)['e'] as Map<String, dynamic>;
}

// a lock with these pins set: {slot: (pin, kind)}, vault entries wrapping
// the vault key. null for no app lock at all
Future<Lock> makeLock(
  Map<int, (String, int)>? pins, {
  bool inDecoy = false,
  bool inVault = false,
  bool wipeOn = false,
}) async {
  final store = MemStore();
  if (pins != null) {
    store.m['halo.lock.enabled'] = 'true';
    if (wipeOn) store.m['halo.lock.panic_enabled'] = 'true';
    store.m['halo.lock.table'] = jsonEncode({
      'v': 2,
      'n': 15,
      'e': {
        for (final e in pins.entries)
          '${e.key}': {
            'p': e.value.$1,
            'k': e.value.$2,
            'c': _containerOf(e.key, e.value.$2),
            'w': e.value.$2 == PinKind.vault ? vaultKey : '',
          },
      },
    });
  }
  final s = LockState(
    store: store,
    engine: MemEngine(),
    clock: StillClock(),
    bio: NoBio(),
    revealAfter: Duration.zero,
  );
  await s.load();
  if (inDecoy) s.inDecoy = true;
  if (inVault) s.inVault = true;
  return Lock(s, store);
}

const Map<int, (String, int)> appOnly = {
  PinSlot.app: (appPin, PinKind.everyday),
};

const Map<int, (String, int)> withVault = {
  PinSlot.app: (appPin, PinKind.everyday),
  PinSlot.vault: (vaultPin, PinKind.vault),
};

// the app side: chats on show and chats hidden, moved as the app moves them
class FakeHost extends PinsHost {
  FakeHost({
    this.lock,
    List<HideChoice>? everyday,
    List<HideChoice>? hidden,
    this.decoy = false,
    this.failHide = false,
  }) : everyday = everyday ?? [],
       hidden = hidden ?? [];

  final LockState? lock;
  final List<HideChoice> everyday;
  final List<HideChoice> hidden;
  bool decoy;
  bool failHide;
  final calls = <String>[];
  final _n = ChangeNotifier();

  @override
  Listenable get changes => _n;

  @override
  bool get hasDecoy => decoy;

  @override
  Future<bool> setDecoyPin(String pin) async {
    calls.add('setDecoyPin');
    return true;
  }

  @override
  Future<void> removeDecoy() async {
    calls.add('removeDecoy');
    decoy = false;
  }

  // as the app makes one: whatever was there goes first, the entry last
  @override
  Future<bool> createVault(String pin) async {
    calls.add('createVault');
    await lock!.clearVault();
    hidden.clear();
    return lock!.setupVaultPin(pin, vaultKey);
  }

  @override
  Future<int> hideChats({
    List<String> people = const [],
    List<String> groups = const [],
  }) async {
    calls.add('hideChats');
    if (failHide) throw StateError('move cut short');
    final ids = {...people, ...groups};
    final went = everyday.where((c) => ids.contains(c.id)).toList();
    everyday.removeWhere(went.contains);
    hidden.addAll(went);
    return went.length;
  }

  @override
  Future<void> vaultSetupDone() async => calls.add('vaultSetupDone');

  @override
  Future<void> removeVault() async {
    calls.add('removeVault');
    everyday.addAll(hidden);
    hidden.clear();
    await lock!.clearVault();
    lock!.inVault = false;
  }

  @override
  Future<void> destroyVault() async {
    calls.add('destroyVault');
    hidden.clear();
    await lock?.clearVault();
  }

  @override
  List<HideChoice> hideable() => [...everyday];

  @override
  Future<void> backup(BuildContext context) async => calls.add('backup');

  // what changes chats: a change of pin calls none of these
  List<String> get moves => [
    for (final c in calls)
      if (const {
        'createVault',
        'hideChats',
        'removeVault',
        'destroyVault',
      }.contains(c))
        c,
  ];
}

List<HideChoice> someChats() => [
  const HideChoice(id: 'g2hidden0001', name: 'Saturday hike', group: true),
  const HideChoice(id: 'hidden-wreck-tone', name: 'Hana'),
  const HideChoice(id: 'visible-plain-row', name: 'Vic'),
];

// the app around a screen: a phone's size, the language's direction and
// reduced motion when asked
Widget app(
  Widget home, {
  bool still = false,
  Locale locale = const Locale('en'),
  GlobalKey? shot,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: RepaintBoundary(key: shot, child: child!),
  ),
  home: home,
);

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

// the haptics asked for, by type
List<String> hearHaptics(WidgetTester t) {
  final got = <String>[];
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        got.add((call.arguments as String).split('.').last);
      }
      return null;
    },
  );
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return got;
}

// the screen reader's whole tree, without the numbers nodes are given
String semanticsTree(WidgetTester t) {
  final root = t.binding.renderViews.first.debugSemantics!;
  return root
      .toStringDeep(childOrder: DebugSemanticsDumpOrder.traversalOrder)
      .replaceAll(RegExp(r'#\d+'), '')
      .replaceAll(RegExp(r'id: \d+'), '');
}

Future<List<int>> pixels(WidgetTester t, GlobalKey shot) async {
  final boundary =
      shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late List<int> bytes;
  await t.runAsync(() async {
    final img = await boundary.toImage();
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    bytes = data!.buffer.asUint8List().toList();
  });
  return bytes;
}

// a button the page may have scrolled away on a small screen
// scrolled only as far as it takes, so nothing springs back after
Future<void> press(WidgetTester t, Finder f) async {
  await Scrollable.ensureVisible(t.element(f), alignment: 1);
  await t.pump();
  await t.tap(f);
}

// digits on the pad, then its enter key
Future<void> typePin(WidgetTester t, String pin) async {
  for (final d in pin.split('')) {
    await t.tap(find.text(d));
    await t.pump();
  }
}

Future<void> enter(WidgetTester t) async {
  await t.tap(find.byIcon(Icons.check_rounded));
  await t.pump();
}
