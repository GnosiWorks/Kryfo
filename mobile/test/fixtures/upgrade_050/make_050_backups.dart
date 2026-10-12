// SPDX-License-Identifier: GPL-3.0-or-later
// makes the 0.5.0 backups the restore test reads, from the 0.5.0 files
// beside it. it runs inside a 0.5.0 checkout with that checkout's engine
// built for this computer (make_050_backups.sh), so the files are what
// 0.5.0's own writer and cipher make: everyday.backup without the hidden
// chats, hidden.backup made with them open
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart';
import 'package:kryfo/session.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'host_engine.dart';
import 'sqlite_channel.dart';

// the passphrase both are made under
const passphrase = 'test backup 050';

class _Engine implements HaloEngine {
  _Engine(this.ed, this.x);
  final String ed;
  final String x;
  @override
  String myEdPrivkey() => ed;
  @override
  String myXPrivkey() => x;
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Platform.environment['UPGRADE_OUT'] ?? '';
  final engineAt = Platform.environment['KRYFO_HOST_ENGINE'] ?? '';
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory docs;
  late SqliteChannel sql;
  final keys =
      (jsonDecode(File(p.join(out, 'keys.json')).readAsStringSync()) as Map)
          .cast<String, String>();

  setUpAll(() {
    expect(loadHostEngine(engineAt), isTrue, reason: engineAt);
  });

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('make_050_backups');
    for (final f in ['halo.db', 'halo_d.db', 'halo_v.db']) {
      File(p.join(out, f)).copySync(p.join(docs.path, f));
    }
    // a photo, a wallpaper and the onion key in the everyday folders, and
    // a photo of the hidden chats in theirs
    File(p.join(docs.path, 'media', 'a-6.jpg'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([0xff, 0xd8, 0xff, 0xd9]);
    File(p.join(docs.path, 'wallpapers', 'amber-otter-lake.png'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([0x89, 0x50, 0x4e, 0x47]);
    File(p.join(docs.path, 'media_v', 'h-1.jpg'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([0xff, 0xd8, 0x00, 0xff, 0xd9]);
    File(
      p.join(docs.path, 'onion.key'),
    ).writeAsBytesSync(List.generate(64, (i) => i));
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => docs.path,
    );
    FlutterSecureStorage.setMockInitialValues({
      'halo.db.passphrase': keys['everyday']!,
      'halo.d.key': keys['decoy']!,
      'onboarding_done': 'true',
      // what the identity keeps outside its database
      'my_handle': 'quietmaple',
      'my_handle_bio': 'night owl',
      'my_handle_listed': 'true',
      'my_handle_name': 'Quiet',
      'my_avatar': '7',
      'fc_counter': '3',
      'peer_fc': jsonEncode({'amber-otter-lake': 2, 'hush-pine-rill': 1}),
    });
    SharedPreferences.setMockInitialValues({
      'onboarding.complete': true,
      'supporter_tier': 'gold',
      'supporter_receipt_payload': 'receipt-payload',
      'supporter_receipt_sig': 'receipt-sig',
    });
    sql = SqliteChannel.install()!;
  });

  tearDown(() => sql.uninstall());

  Future<void> make(String name, {required bool hidden}) async {
    final live = HaloDb();
    final id = (await live.loadIdentity())!;
    useEngineForTest(_Engine(id['ed_priv']!, id['x_priv']!));
    appState.myId = id['id']!;
    final vault = HaloDb.withKey(HaloContainer.vault, keys['vault']!);
    useDatabasesForTest(
      live,
      hidden ? await Session.withVault(live, vault) : Session(live),
    );
    await createBackupFile(passphrase, p.join(out, name));
    await live.close();
    await vault.close();
  }

  test('a backup without the hidden chats', () async {
    expect(out, isNotEmpty, reason: 'UPGRADE_OUT names where they go');
    await make('everyday.backup', hidden: false);
  });

  test('a backup with the hidden chats open', () async {
    await make('hidden.backup', hidden: true);
  });
}
