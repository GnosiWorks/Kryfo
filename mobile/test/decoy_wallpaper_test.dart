// SPDX-License-Identifier: GPL-3.0-or-later
// a decoy hide cut short after the chat left the decoy's rows and before
// its files moved leaves its wallpaper in the decoy's folder, named only
// by the decoy's own vault. opening the decoy leaves it, and opening that
// vault puts it in place. the real database methods over rows kept in
// maps, the files real ones in a scratch folder
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloDb, QuietIdentity, tidyWallpapers;
import 'package:kryfo/vault_life.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'mem_db.dart';

class _Rows extends HaloDb {
  _Rows(this.mem, super.container);
  final MemDb mem;
  @override
  Future<Database> open() async => mem;
  // what the home list reads of it, which this test does not look at
  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async => {};
  @override
  Future<int> pendingRequestCount() async => 0;
}

const _dh = 'decoy-hidden-one';
const _quiet = QuietIdentity(
  id: 'decoy-own-words',
  edPub: 'ed-decoy',
  xPub: 'x-decoy',
  onion: 'o-decoy',
  invite: 'kryfo://share?id=decoy-own-words',
);

// the decoy's vault as a move reads it: its marks, and the files its rows
// name, by folder and leaf
class _Mover implements ChatMover {
  _Mover(this.vault);
  final _Rows vault;
  var marked = const MoveMarks().hiding(const ChatRef(_dh));

  @override
  Future<void> attach() async {}
  @override
  Future<void> detach() async {}
  @override
  Future<MoveMarks> marks() async => marked;
  @override
  Future<void> putMarks(MoveMarks m) async => marked = m;
  @override
  Future<List<String>> vaultFiles(ChatRef c) async => [
    for (final r in vault.mem.rows('contacts'))
      if (r['halo_id'] == c.id && r['atmosphere'] is String)
        'wallpapers/${p.basename(r['atmosphere'] as String)}',
  ];

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the mover was asked for ${i.memberName}');
}

class _Host implements VaultHost {
  _Host(this.m);
  final _Mover m;

  @override
  ChatMover mover(HaloDb primary, HaloDb? vault) => m;
  @override
  Future<void> moveFile(String from, String to) async {
    Directory(p.dirname(to)).createSync(recursive: true);
    File(from).renameSync(to);
  }

  @override
  Future<void> shred(String path) async => File(path).deleteSync();

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the host was asked for ${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('decoy_wallpaper');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => docs.deleteSync(recursive: true));

  test('a decoy hide cut short keeps its wallpaper for the vault', () async {
    final before = DateTime.now().subtract(const Duration(minutes: 10));
    final old = before.subtract(const Duration(hours: 1));
    final decoy = _Rows(MemDb(), HaloContainer.decoy);
    final vault = _Rows(MemDb(), HaloContainer.decoyVault);
    // the vault's database is on disk, shut
    File(await HaloContainer.decoyVault.dbPath()).writeAsStringSync('shut');
    final leaf = 'wp_${'cd' * 16}.jpg';
    final dv = await HaloContainer.decoyVault.folder('wallpapers');
    await vault.mem.insert('contacts', {
      'halo_id': _dh,
      'onion': 'o',
      'xpub': 'x',
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'atmosphere': 'image:${p.join(dv.path, leaf)}',
    });
    // its rows left the decoy, its file did not
    final d = await HaloContainer.decoy.folder('wallpapers');
    final left = File(p.join(d.path, leaf))
      ..writeAsBytesSync([4, 2])
      ..setLastModifiedSync(old);

    // the decoy opens at start: nothing of it goes
    expect(await tidyWallpapers(decoy, before: before), isEmpty);
    expect(left.existsSync(), isTrue);

    // the vault opens: settled, the file is where its rows are
    final m = _Mover(vault);
    final app = AppState(host: _Host(m));
    await app.useDecoyForTest(decoy, _quiet);
    await app.settleVault(vault);
    expect(m.marked.isEmpty, isTrue);
    final placed = File(p.join(dv.path, leaf));
    expect(placed.readAsBytesSync(), [4, 2]);
    expect(left.existsSync(), isFalse);
    // and its open sweeps both sides without it
    expect(await tidyWallpapers(vault, before: before), isEmpty);
    expect(
      await tidyWallpapers(decoy, before: before, vaultOpen: true),
      isEmpty,
    );
    expect(placed.existsSync(), isTrue);
  });

  test('a decoy with no vault on disk is swept at its open', () async {
    final before = DateTime.now().subtract(const Duration(minutes: 10));
    final decoy = _Rows(MemDb(), HaloContainer.decoy);
    final d = await HaloContainer.decoy.folder('wallpapers');
    final orphan = File(p.join(d.path, 'wp_${'ef' * 16}.jpg'))
      ..writeAsBytesSync([1])
      ..setLastModifiedSync(before.subtract(const Duration(hours: 1)));
    expect((await tidyWallpapers(decoy, before: before)).map((f) => f.path), [
      orphan.path,
    ]);
  });
}
