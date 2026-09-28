// SPDX-License-Identifier: GPL-3.0-or-later
// what the developer chat's screen tests share: a card made the way an
// invite carries one, a phone's database kept in maps, and home, a screen
// or a sheet pumped in a language at a font size
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/devchat/dev_chat.dart';
import 'package:kryfo/devchat/dev_key.dart';
import 'package:kryfo/devchat/support.dart' show SupportChats;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show HaloDb, appState, haloUriV3, useDatabasesForTest;
import 'package:kryfo/screens/home_screen.dart';
import 'package:kryfo/search.dart' show SearchKind;
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart' as signal;

import 'mem_db.dart';

// a card as a v3 invite carries it, read by the app's own parser
DevKey devCard(String keyId, {DevKeyStatus status = DevKeyStatus.current}) {
  final pair = signal.Curve.generateKeyPair();
  final bundle = base64Encode(
    utf8.encode(
      jsonEncode({'identityKey': base64Encode(pair.publicKey.serialize())}),
    ),
  );
  final link = haloUriV3(
    'quiet-amber-lake',
    '',
    Uri.encodeQueryComponent(bundle),
    'ab' * 32,
  );
  return DevKey.fromLink(link, keyId: keyId, status: status)!;
}

// the everyday or a decoy's database, as the session reaches it
class DevTestDb implements HaloDb {
  DevTestDb(this.mem, [this.container = HaloContainer.everyday]);

  final MemDb mem;
  @override
  final HaloContainer container;

  @override
  DevChat get devChat => DevChat(() async => mem, shred: (_) async {});

  @override
  SupportChats get support => SupportChats(() async => mem);

  @override
  Future<List<Map<String, Object?>>> contacts() =>
      mem.query('contacts', where: 'accepted = ?', whereArgs: [1]);

  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async {
    final out = <String, Map<String, Object?>>{};
    for (final r in mem.rows('messages')) {
      if (r['group_id'] != null) continue;
      final id = r['peer_id'] as String;
      if ((out[id]?['id'] as int? ?? 0) < (r['id'] as int)) out[id] = r;
    }
    return out;
  }

  @override
  Future<int> pendingRequestCount() async => 0;

  @override
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async =>
      (people: <String, bool>{}, groups: <String>{});

  // the words of the match, each somewhere in an accepted chat's message
  @override
  Future<List<Map<String, Object?>>> searchMessages(
    String? match,
    SearchKind kind, {
    int limit = 300,
  }) async {
    final words = RegExp(
      r'[\p{L}\p{N}]+',
      unicode: true,
    ).allMatches(match ?? '').map((m) => m[0]!.toLowerCase()).toList();
    final ok = {
      for (final c in mem.rows('contacts'))
        if (c['accepted'] == 1) c['halo_id'],
    };
    return [
      for (final r in mem.rows('messages').reversed)
        if (r['group_id'] == null &&
            ok.contains(r['peer_id']) &&
            words.every(
              (w) =>
                  (r['plaintext'] as String? ?? '').toLowerCase().contains(w),
            ))
          r,
    ];
  }

  @override
  Future<String?> contactXPub(String haloId) async {
    final r = await mem.query(
      'contacts',
      columns: ['xpub'],
      where: 'halo_id = ?',
      whereArgs: [haloId],
    );
    return r.isEmpty ? null : r.first['xpub'] as String?;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

late MemDb devMem;

// a phone's database as a fresh install makes it, or as an update finds it
// with its chats already there: either way the row is seeded after them
Future<void> devWorld({
  List<(String, int, bool)> chats = const [],
  HaloContainer container = HaloContainer.everyday,
}) async {
  devMem = MemDb(except: {'devchat'});
  for (final (id, seen, pinned) in chats) {
    await devMem.insert('contacts', {
      'halo_id': id,
      'onion': '',
      'xpub': 'x-$id',
      'first_seen': 1,
      'last_seen': seen,
      'accepted': 1,
      'pinned': pinned ? 1 : 0,
    });
  }
  await devChatTables(devMem, now: 1);
  final db = DevTestDb(devMem, container);
  if (container.quiet) {
    // the everyday one under it has the developer's own identity
    final everyday = MemDb(except: {'devchat'});
    await devChatTables(everyday);
    useDatabasesForTest(DevTestDb(everyday), Session(db));
  } else {
    useDatabasesForTest(db, Session(db));
  }
  await appState.refreshContacts();
}

DevChat get devTestChat => DevChat(() async => devMem, shred: (_) async {});

Widget devHome({List<GroupSummary> groups = const []}) => ListenableBuilder(
  listenable: appState,
  builder: (_, _) => HomeScreen(
    haloId: 'neon-tiger-saturn',
    contacts: appState.contacts,
    devRow: appState.devRow,
    groups: groups,
    onAddContact: () {},
    onNewGroup: () {},
    onNewRoom: () {},
    onOpenDev: () {},
    onOpenSettingsDirect: () {},
    onOpenChat: (_) {},
    onOpenGroup: (_) {},
  ),
);

Widget devApp(
  Widget home, {
  bool still = false,
  Locale? locale,
  double scale = 1,
}) => MaterialApp(
  locale: locale ?? l10nLocale,
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(
      ctx,
    ).copyWith(disableAnimations: still, textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

Future<void> devOpen(
  WidgetTester t,
  Widget home, {
  bool still = false,
  Locale locale = const Locale('en'),
  double scale = 1,
  Size size = const Size(1000, 1800),
  double ratio = 2,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = ratio;
  addTearDown(t.view.reset);
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
  setL10nLocale(locale);
  await t.pumpWidget(devApp(home, still: still, locale: locale, scale: scale));
  await t.pump(const Duration(seconds: 1));
}

// the rows' timers and entrances run out before the next test
Future<void> devClose(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}
