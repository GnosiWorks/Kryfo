// SPDX-License-Identifier: GPL-3.0-or-later
// what a start clears away: the folders a backup or a restore cut short
// staged in, the files of a container nothing can open any more, and raw
// voice recordings. what is still in use is never touched. the folders are
// real ones in a scratch folder
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/backup.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show sweepVoiceLeftovers;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  String at(String name) => p.join(root.path, name);
  void put(String name, [String what = 'x']) => (File(
    at(name),
  )..parent.createSync(recursive: true)).writeAsStringSync(what);
  bool there(String name) =>
      FileSystemEntity.typeSync(at(name)) != FileSystemEntityType.notFound;
  // every path under the folder with what it holds
  Map<String, String> all() => {
    for (final e in root.listSync(recursive: true))
      p.relative(e.path, from: root.path): e is File
          ? e.readAsStringSync()
          : '/',
  };

  setUp(() {
    root = Directory.systemTemp.createTempSync('boot_sweep');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => root.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'halo.d.key': "x'${'2e' * 32}'",
    });
    forgetLeftoverSweep();
  });

  tearDown(() => root.deleteSync(recursive: true));

  // what a phone holds in use: the everyday side, a decoy and both vaults
  void phone() {
    put('halo.db', 'everyday');
    put('halo.db-wal', 'everyday log');
    put('onion.key', 'onion');
    put('media/a.jpg', 'a photo');
    put('wallpapers/w.jpg', 'a wallpaper');
    put('halo_d.db', 'decoy');
    put('media_d/d.jpg', 'a decoy photo');
    put('halo_v.db', 'hidden');
    put('halo_v.db-wal', 'hidden log');
    put('media_v/h.jpg', 'a hidden photo');
    put('wallpapers_v/hw.jpg', 'a hidden wallpaper');
    put('halo_dv.db', 'decoy hidden');
    put('media_dv/dh.jpg', 'a decoy hidden photo');
  }

  group('backup and restore leftovers', () {
    test('what a backup or a restore cut short left is gone, and nothing '
        'else', () async {
      phone();
      final kept = all();
      put('backup_stage/halo.db', 'a copy');
      put('backup_stage/onion.key', 'onion');
      put('backup_stage/vault/halo_v.db', 'a hidden copy');
      put('restore_d/restore_stage/halo.db', 'restored');
      put('restore_d/halo.db', 'restored');
      put('restore_stage/media/r.jpg', 'restored photo');
      put('restore_hidden/halo_v.db', 'restored hidden');
      put('restore_peek.db', 'a look inside');
      put('restore_peek_v.db', 'a look at the hidden');
      await sweepBackupLeftovers();
      expect(all(), kept);
    });

    test('a sweep with nothing to do does nothing', () async {
      phone();
      // names that only look alike
      put('backup_stage.txt', 'not a stage');
      put('media/restore_stage/r.jpg', 'a photo in a folder of that name');
      final before = all();
      await sweepBackupLeftovers();
      expect(all(), before);
    });

    test('once a start: a stage made after it is left to its backup', () async {
      await sweepBackupLeftovers();
      put('backup_stage/halo.db', 'a backup under way');
      await sweepBackupLeftovers();
      expect(there('backup_stage/halo.db'), isTrue);
    });
  });

  group('containers', () {
    test('a live container is never touched', () async {
      phone();
      final before = all();
      await sweepContainers({HaloContainer.decoy.id}, pinTable: true);
      expect(all(), before);
      expect(
        await const FlutterSecureStorage().read(key: 'halo.d.key'),
        isNotNull,
      );
    });

    test('with no pin table no vault can open: their files go, a listed '
        'decoy and the everyday side stay', () async {
      phone();
      await sweepContainers({HaloContainer.decoy.id}, pinTable: false);
      for (final gone in [
        'halo_v.db',
        'halo_v.db-wal',
        'media_v',
        'wallpapers_v',
        'halo_dv.db',
        'media_dv',
      ]) {
        expect(there(gone), isFalse, reason: gone);
      }
      for (final kept in [
        'halo.db',
        'halo.db-wal',
        'onion.key',
        'media/a.jpg',
        'wallpapers/w.jpg',
        'halo_d.db',
        'media_d/d.jpg',
      ]) {
        expect(there(kept), isTrue, reason: kept);
      }
    });

    test('a decoy no list names goes whole, with its vault, even when only '
        'a folder of it is left', () async {
      phone();
      File(at('halo_d.db')).deleteSync();
      await sweepContainers({}, pinTable: true);
      for (final gone in ['media_d', 'halo_dv.db', 'media_dv']) {
        expect(there(gone), isFalse, reason: gone);
      }
      expect(
        await const FlutterSecureStorage().read(key: 'halo.d.key'),
        isNull,
      );
      // the everyday side's vault may still open: left as it is
      for (final kept in [
        'halo.db',
        'media/a.jpg',
        'halo_v.db',
        'halo_v.db-wal',
        'media_v/h.jpg',
        'wallpapers_v/hw.jpg',
      ]) {
        expect(there(kept), isTrue, reason: kept);
      }
    });

    test('with nothing left over, nothing changes', () async {
      put('halo.db', 'everyday');
      put('media/a.jpg', 'a photo');
      final before = all();
      await sweepContainers({}, pinTable: false);
      expect(all(), before);
      expect(
        await const FlutterSecureStorage().read(key: 'halo.d.key'),
        isNotNull,
      );
    });
  });

  group('voice leftovers', () {
    test('one that will not go is logged, and the rest still go', () async {
      for (final n in ['vn_1.wav', 'vn_2.wav', 'vn_3.wav', 'note.txt']) {
        put(n);
      }
      Directory(at('vn_folder.wav')).createSync();
      await sweepVoiceLeftovers(
        root,
        drop: (f) async {
          if (p.basename(f.path) == 'vn_2.wav') {
            throw const FileSystemException('held');
          }
          await f.delete();
        },
      );
      expect(there('vn_1.wav'), isFalse);
      expect(there('vn_3.wav'), isFalse);
      expect(there('vn_2.wav'), isTrue);
      expect(there('note.txt'), isTrue);
      expect(there('vn_folder.wav'), isTrue);
    });
  });
}
