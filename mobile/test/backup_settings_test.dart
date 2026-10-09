// SPDX-License-Identifier: GPL-3.0-or-later
// a backup carries the privacy settings, and a restore puts them back
// before the restart reads them: on a new phone as they were, in a decoy as
// the decoy's own. no PIN, no hidden chats, nothing of the wipe or the lock
// and nothing of the phone alone ever goes in. a file from before settings
// were carried leaves them as they are. the backup and restore are the real
// ones over real files in a scratch folder; the cipher, the databases and
// the engine are stand-ins
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart';
import 'package:kryfo/backup_stream.dart';
import 'package:kryfo/carried_settings.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/delivery_mode.dart';
import 'package:kryfo/intro_prefs.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show HaloDb, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/notifications.dart' show loadHideNotifContent;
import 'package:kryfo/scam_prefs.dart';
import 'package:kryfo/session.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'pin_flow_fakes.dart';

class _Cipher implements ChunkCipher {
  @override
  Uint8List seal(int index, int type, Uint8List plain) =>
      Uint8List.fromList([index & 255, type, ...plain.map((b) => b ^ 7)]);
  @override
  Uint8List? open(int index, int type, Uint8List sealed) {
    if (sealed.length < 2 || sealed[0] != (index & 255) || sealed[1] != type) {
      return null;
    }
    return Uint8List.fromList(sealed.sublist(2).map((b) => b ^ 7).toList());
  }
}

// the decoy's database as a decoy backup reads it: its onion key
class _Raw implements Database {
  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #query) {
      return Future.value(<Map<String, Object?>>[
        {'v': '0a0b0c'},
      ]);
    }
    throw UnimplementedError('the stand-in was asked for ${i.memberName}');
  }
}

class _Db implements HaloDb {
  _Db(this.container);
  @override
  final HaloContainer container;
  final log = <String>[];

  @override
  Future<void> close() async => log.add('close');
  @override
  Future<void> retire() async => log.add('retire');
  @override
  Future<void> checkpoint() async {}
  @override
  Future<Database> open() async => _Raw();
  @override
  Future<Map<String, String>?> loadIdentity() async => {
    'ed_priv': 'decoy-ed',
    'x_priv': 'decoy-x',
  };
  @override
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async =>
      (people: const <String, bool>{}, groups: const <String>{});
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

class _Engine implements HaloEngine {
  final restored = <String>[];
  @override
  String restoreIdentity(String ed, String x) {
    restored.add(ed);
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('the engine was asked for ${i.memberName}');
}

// the identity and the copies, with no engine and no sqlcipher
class _Side extends BackupSide {
  const _Side();

  @override
  ({String ed, String x, String id}) identity() =>
      (ed: 'everyday-ed', x: 'everyday-x', id: 'me-me-me');

  @override
  Future<T> still<T>(
    Future<T> Function(HaloDb? vault) work, {
    required bool made,
  }) => work(null);

  @override
  Future<void> copyEveryday(String to) => File(to).writeAsString('everyday db');

  @override
  Future<Set<String>> scrub(String copy, String key) async => {};

  @override
  Future<void> scrubDev(String copy, String key) async {}

  @override
  Future<void> settleBurns(String copy, String key, int at) async {}
}

// every PIN, the hidden chats' key, the wipe and the lock's counters, as
// the phone keeps them. none of it may leave in a backup
const _never = {
  'halo.lock.enabled': 'true',
  'halo.lock.panic_enabled': 'true',
  'halo.lock.table':
      '{"v":2,"e":{"0":{"p":"$appPin"},"1":{"p":"$wipePin"},'
      '"2":{"p":"$decoyPin"},"3":{"p":"$vaultPin"}}}',
  'halo.lock.fails': '3',
  'halo.lock.until': '99',
};

// every carried setting away from its default, the everyday side's and
// the phone's
const _changedSecure = {
  'block_screenshots': 'true',
  'theme_light': 'true',
  'send_mode': 'balanced',
  'disguise_on': '1',
};
const _changedPrefs = <String, Object>{
  'notif_hide_content': false,
  'kryfo.scamshield.on': false,
  'kryfo.intro.accept': false,
  'delivery_mode': 'checkins',
  'app_locale': 'de',
};

// the phone's alone: none of it travels
const _phoneOnly = <String, Object>{
  'battery_opt_prompt_seen': true,
  'miui_autostart_prompt_seen': true,
  'notif_blocked_hint_dismissed': true,
  'delivery_heartbeat': 1234,
  'delivery_last_check': 5678,
  'delivery_last_wake': 91011,
  'hb.listen': 'x',
};

const _everydaySettings = {
  Carried.screenshots: true,
  Carried.light: true,
  Carried.voice: true,
  Carried.previewsHidden: false,
  Carried.shield: false,
  Carried.intros: false,
  Carried.route: 'balanced',
  Carried.delivery: 'checkins',
  Carried.language: 'de',
};

const _defaults = {
  Carried.screenshots: false,
  Carried.light: false,
  Carried.voice: false,
  Carried.previewsHidden: true,
  Carried.shield: true,
  Carried.intros: true,
  Carried.route: 'private',
  Carried.delivery: 'always',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late String docs;
  late String stage;
  late _Db live;
  late _Db decoy;
  late _Engine engine;

  void put(String name, String body) => File(p.join(docs, name))
    ..createSync(recursive: true)
    ..writeAsStringSync(body);

  setUp(() {
    root = Directory.systemTemp.createTempSync('backup_settings');
    docs = p.join(root.path, 'docs');
    stage = p.join(root.path, 'stage');
    Directory(docs).createSync();
    Directory(stage).createSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => docs,
        );
    forgetLeftoverSweep();
    forgetRestoredHidden();
    live = _Db(HaloContainer.everyday);
    decoy = _Db(HaloContainer.decoy);
    engine = _Engine();
    useEngineForTest(engine);
    useDatabasesForTest(live, Session(live));
  });

  tearDown(() {
    restoreCipherForTest = null;
    forgetRestoredHidden();
    useDatabasesForTest(live, Session(live));
    root.deleteSync(recursive: true);
  });

  // the old phone: everyday settings changed, the decoy's changed the
  // other way, every PIN set and the phone's own things noted
  void oldPhone() {
    SharedPreferences.setMockInitialValues({
      ..._changedPrefs,
      ..._phoneOnly,
      'd.notif_hide_content': true,
      'd.kryfo.scamshield.on': true,
      'd.kryfo.intro.accept': true,
      'd.supporter_tier': 'decoy',
    });
    FlutterSecureStorage.setMockInitialValues({
      'halo.db.passphrase': 'everyday key',
      'halo.d.key': "x'${'2e' * 32}'",
      ..._changedSecure,
      ..._never,
      'd.disguise_on': '0',
    });
  }

  // a phone just installed, nothing set
  void newPhone() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'halo.db.passphrase': 'fresh key',
    });
    put('halo.db', 'fresh');
  }

  Future<String> write(
    Map<String, dynamic> manifest,
    Map<String, String> src,
  ) async {
    final out = p.join(root.path, 'x.kryfo');
    await writeBackup(
      outPath: out,
      salt: Uint8List(16),
      cipher: _Cipher(),
      manifest: manifest,
      root: '',
      source: (n) => src[n]!,
    );
    return out;
  }

  Future<void> restore(String out, {required bool inDecoy}) async {
    final lock = await makeLock({
      PinSlot.app: (appPin, PinKind.everyday),
      PinSlot.decoy: (decoyPin, PinKind.decoy),
    }, inDecoy: inDecoy);
    useDatabasesForTest(live, Session(inDecoy ? decoy : live));
    restoreCipherForTest = _Cipher.new;
    await restoreBackupFile(out, 'pass', lock: lock.state);
  }

  // the settings as the app reads them at its next start
  Future<Map<String, Object>> readBack(HaloContainer c) async {
    const st = FlutterSecureStorage();
    final prefs = await SharedPreferences.getInstance();
    return {
      Carried.screenshots: (await st.read(key: 'block_screenshots')) == 'true',
      Carried.light: (await st.read(key: 'theme_light')) == 'true',
      Carried.voice: (await st.read(key: c.key('disguise_on'))) == '1',
      Carried.previewsHidden: await loadHideNotifContent(c),
      Carried.shield: await loadScamShieldOn(c),
      Carried.intros: await loadAcceptIntros(c),
      Carried.route: await st.read(key: 'send_mode') ?? 'private',
      Carried.delivery: (await loadDeliveryMode()).name,
      Carried.language: prefs.getString('app_locale') ?? 'system',
    };
  }

  group('an everyday backup', () {
    test('carries every privacy setting changed from its default', () async {
      oldPhone();
      final d = await draftBackup(stage, side: const _Side());
      expect(d.manifest['settings'], _everydaySettings);
      // the file written holds them as drafted
      final back = await readBackupManifest(
        await write(d.manifest, d.sources),
        _Cipher(),
      );
      expect(back['settings'], _everydaySettings);
    });

    test('carries the defaults as defaults, and a language that follows '
        'the phone not at all', () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'system'});
      FlutterSecureStorage.setMockInitialValues({
        'halo.db.passphrase': 'everyday key',
      });
      final d = await draftBackup(stage, side: const _Side());
      expect(d.manifest['settings'], _defaults);
    });

    test('carries no PIN, no hidden chats, nothing of the wipe or the lock '
        'and nothing of the phone alone', () async {
      oldPhone();
      final d = await draftBackup(stage, side: const _Side());
      final m = d.manifest;
      expect(m.containsKey('vault'), isFalse);
      final text = jsonEncode(m);
      for (final pin in [appPin, wipePin, decoyPin, vaultPin]) {
        expect(text, isNot(contains('"$pin"')));
        expect(text, isNot(contains(':$pin')));
      }
      for (final k in [..._never.keys, ..._phoneOnly.keys]) {
        expect(text, isNot(contains(k)), reason: k);
      }
      // nor the decoy's
      expect(text, isNot(contains('"d.')));
      expect(
        (m['settings'] as Map).keys.toSet(),
        _everydaySettings.keys.toSet(),
      );
    });

    test('restored, each address reads its relays from where the old phone '
        'had, and nothing of this phone\'s reading is left', () async {
      oldPhone();
      // the engine's anchors on the old phone, one still owing its backlog
      put('nostr_last_aaaaaaaaaaaaaaaa', '1791400000');
      put('nostr_last_bbbbbbbbbbbbbbbb', '1791500000\n');
      put('nostr_last_cccccccccccccccc', '0');
      put('nostr_seen_aaaaaaaaaaaaaaaa', 'ids');
      final d = await draftBackup(stage, side: const _Side());
      expect(d.manifest['catchUp'], {
        'nostr_last_aaaaaaaaaaaaaaaa': 1791400000,
        'nostr_last_bbbbbbbbbbbbbbbb': 1791500000,
      });
      final out = await write(d.manifest, d.sources);
      newPhone();
      // what this phone had read, of another identity or a later time
      for (final f in Directory(docs).listSync()) {
        if (p.basename(f.path).startsWith('nostr_')) f.deleteSync();
      }
      put('nostr_last_dddddddddddddddd', '1799999999');
      put('nostr_seen_dddddddddddddddd', 'ids');
      await restore(out, inDecoy: false);
      final left = {
        for (final f in Directory(docs).listSync())
          if (p.basename(f.path).startsWith('nostr_'))
            p.basename(f.path): File(f.path).readAsStringSync(),
      };
      expect(left, {
        'nostr_last_aaaaaaaaaaaaaaaa': '1791400000',
        'nostr_last_bbbbbbbbbbbbbbbb': '1791500000',
      });
    });

    test('a file without anchors, or with odd ones, leaves every address to '
        'read its relays whole', () async {
      put('nostr_last_eeeeeeeeeeeeeeee', '1790000000');
      put('nostr_seen_eeeeeeeeeeeeeeee', 'ids');
      await landCatchUpAnchors(docs, null);
      expect(
        Directory(
          docs,
        ).listSync().where((f) => p.basename(f.path).startsWith('nostr_')),
        isEmpty,
      );
      await landCatchUpAnchors(docs, {
        '../escape': 5,
        'nostr_last_zz': 5,
        'nostr_last_ffffffffffffffff': 'soon',
        'nostr_last_9999999999999999': -1,
      });
      expect(
        Directory(
          docs,
        ).listSync().where((f) => p.basename(f.path).startsWith('nostr_')),
        isEmpty,
      );
      expect(File(p.join(root.path, 'escape')).existsSync(), isFalse);
    });

    test('restored on a new phone brings every setting back before the '
        'restart, and no PIN', () async {
      oldPhone();
      final d = await draftBackup(stage, side: const _Side());
      final out = await write(d.manifest, d.sources);
      newPhone();
      await restore(out, inDecoy: false);
      expect(engine.restored, ['everyday-ed']);
      expect(await readBack(HaloContainer.everyday), _everydaySettings);
      // the notice says they came back
      expect(restoredSettings, isTrue);
      // nothing of the old phone's lock, wipe or prompts came along
      final secure = await const FlutterSecureStorage().readAll();
      expect(secure.keys.where((k) => k.startsWith('halo.lock.')), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      for (final k in _phoneOnly.keys) {
        expect(prefs.containsKey(k), isFalse, reason: k);
      }
      // nor anything of the decoy
      expect(prefs.getKeys().where((k) => k.startsWith('d.')), isEmpty);
      expect(secure.keys.where((k) => k.startsWith('d.')), isEmpty);
    });

    test(
      'restored where a language was picked keeps the one picked here',
      () async {
        oldPhone();
        final d = await draftBackup(stage, side: const _Side());
        final out = await write(d.manifest, d.sources);
        newPhone();
        SharedPreferences.setMockInitialValues({'app_locale': 'fr'});
        await restore(out, inDecoy: false);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('app_locale'), 'fr');
        expect(await loadScamShieldOn(), isFalse);
      },
    );
  });

  group('a file from before settings were carried', () {
    test('restores with the settings at their defaults', () async {
      oldPhone();
      final d = await draftBackup(stage, side: const _Side());
      d.manifest.remove('settings');
      final out = await write(d.manifest, d.sources);
      newPhone();
      await restore(out, inDecoy: false);
      expect(engine.restored, ['everyday-ed']);
      expect(await readBack(HaloContainer.everyday), {
        ..._defaults,
        Carried.language: 'system',
      });
      // the notice says to check them, not that they came back
      expect(restoredSettings, isFalse);
    });

    test('leaves the settings here as they are', () async {
      oldPhone();
      final d = await draftBackup(stage, side: const _Side());
      d.manifest.remove('settings');
      final out = await write(d.manifest, d.sources);
      // a restore over the same phone
      await restore(out, inDecoy: false);
      expect(await readBack(HaloContainer.everyday), _everydaySettings);
    });
  });

  test('a newer file\'s settings this version does not know are passed '
      'over, and the rest land', () async {
    oldPhone();
    final d = await draftBackup(stage, side: const _Side());
    d.manifest['settings'] = {
      Carried.shield: false,
      // a value of a kind this version does not read
      Carried.intros: 'no',
      Carried.route: 'carrier-pigeon',
      Carried.delivery: 'helper',
      Carried.language: 'xx',
      'something_new': true,
    };
    final out = await write(d.manifest, d.sources);
    newPhone();
    await restore(out, inDecoy: false);
    expect(await readBack(HaloContainer.everyday), {
      ..._defaults,
      Carried.shield: false,
      Carried.language: 'system',
    });
  });

  test('settings that are not a list of names land nothing, and the notice '
      'says to check them', () async {
    for (final odd in <Object?>[
      [true, false],
      'shield=false',
      null,
    ]) {
      oldPhone();
      final d = await draftBackup(stage, side: const _Side());
      d.manifest['settings'] = odd;
      final out = await write(d.manifest, d.sources);
      newPhone();
      await restore(out, inDecoy: false);
      expect(await readBack(HaloContainer.everyday), {
        ..._defaults,
        Carried.language: 'system',
      }, reason: '$odd');
      expect(restoredSettings, isFalse, reason: '$odd');
    }
  });

  test('a helper app\'s delivery here stays as it is', () async {
    oldPhone();
    final d = await draftBackup(stage, side: const _Side());
    final out = await write(d.manifest, d.sources);
    newPhone();
    SharedPreferences.setMockInitialValues({'delivery_mode': 'helper'});
    await restore(out, inDecoy: false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('delivery_mode'), 'helper');
    expect(await loadScamShieldOn(), isFalse);
  });

  test('landed for a decoy, the phone\'s are never written, even when '
      'asked', () async {
    newPhone();
    expect(
      await landCarriedSettings(
        _everydaySettings,
        HaloContainer.decoy,
        phone: true,
      ),
      isTrue,
    );
    expect(await readBack(HaloContainer.everyday), {
      ..._defaults,
      Carried.language: 'system',
    });
    expect(await loadScamShieldOn(HaloContainer.decoy), isFalse);
  });

  group('the decoy', () {
    test('a restore in a decoy lands the identity\'s own settings as the '
        'decoy\'s, and leaves the phone\'s and the everyday side\'s', () async {
      oldPhone();
      final d = await draftBackup(stage, side: const _Side());
      final out = await write(d.manifest, d.sources);
      // a phone whose everyday side keeps its defaults, with a decoy
      newPhone();
      FlutterSecureStorage.setMockInitialValues({
        'halo.db.passphrase': 'fresh key',
        'halo.d.key': 'decoy key',
      });
      put('halo_d.db', 'decoy');
      await restore(out, inDecoy: true);
      expect(engine.restored, isEmpty);
      expect(decoy.log, ['close']);
      // the phone's stayed: the notice does not say they all came back
      expect(restoredSettings, isFalse);
      final c = HaloContainer.decoy;
      expect(await loadScamShieldOn(c), isFalse);
      expect(await loadAcceptIntros(c), isFalse);
      expect(await loadHideNotifContent(c), isFalse);
      expect(
        await const FlutterSecureStorage().read(key: 'd.disguise_on'),
        '1',
      );
      // the phone's and the everyday identity's as they were
      expect(await readBack(HaloContainer.everyday), {
        ..._defaults,
        Carried.language: 'system',
      });
      final secure = await const FlutterSecureStorage().readAll();
      expect(secure.keys.where((k) => k.startsWith('halo.lock.')), isEmpty);
    });

    test('a decoy backup carries the decoy\'s own settings, never the '
        'everyday side\'s, and they land as an account\'s own', () async {
      oldPhone();
      put('halo_d.db', 'decoy db');
      useDatabasesForTest(live, Session(decoy));
      final d = await draftQuietBackup(stage, side: const _Side());
      final carried = d.manifest['settings'] as Map;
      expect(carried, {
        // the phone's, as the decoy sees them
        Carried.screenshots: true,
        Carried.light: true,
        Carried.route: 'balanced',
        Carried.delivery: 'checkins',
        Carried.language: 'de',
        // its own, not the everyday side's
        Carried.voice: false,
        Carried.previewsHidden: true,
        Carried.shield: true,
        Carried.intros: true,
      });
      final text = jsonEncode(d.manifest);
      for (final k in _never.keys) {
        expect(text, isNot(contains(k)), reason: k);
      }
      final out = await write(d.manifest, d.sources);
      newPhone();
      SharedPreferences.setMockInitialValues({
        'kryfo.scamshield.on': false,
        'kryfo.intro.accept': false,
      });
      await restore(out, inDecoy: false);
      expect(await loadScamShieldOn(), isTrue);
      expect(await loadAcceptIntros(), isTrue);
      expect(
        (await readBack(HaloContainer.everyday))[Carried.route],
        'balanced',
      );
    });
  });
}
