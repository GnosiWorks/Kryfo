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

const decoyKey =
    "x'2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e'";

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
          ? String.fromCharCodes(e.readAsBytesSync())
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
    FlutterSecureStorage.setMockInitialValues({kDecoyKeyName: decoyKey});
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
    put('k2.db', 'decoy');
    put('media_k2/d.jpg', 'a decoy photo');
    put('k3.db', 'hidden');
    put('k3.db-wal', 'hidden log');
    put('media_k3/h.jpg', 'a hidden photo');
    put('wallpapers_k3/hw.jpg', 'a hidden wallpaper');
    put('k4.db', 'decoy hidden');
    put('media_k4/dh.jpg', 'a decoy hidden photo');
  }

  // a database gone and a file of random bytes holding its place
  void heldPlace(String name, String was) {
    final b = File(at(name)).readAsBytesSync();
    expect(String.fromCharCodes(b), isNot(was), reason: name);
    expect(b.length % 4096, 0, reason: name);
    expect(b.length, inInclusiveRange(40 * 4096, 120 * 4096), reason: name);
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
        await const FlutterSecureStorage().read(key: kDecoyKeyName),
        decoyKey,
      );
    });

    test('with no pin table no vault can open: their files go, a listed '
        'decoy and the everyday side stay', () async {
      phone();
      await sweepContainers({HaloContainer.decoy.id}, pinTable: false);
      for (final gone in [
        'k3.db-wal',
        'media_k3/h.jpg',
        'wallpapers_k3/hw.jpg',
        'media_k4/dh.jpg',
      ]) {
        expect(there(gone), isFalse, reason: gone);
      }
      heldPlace('k3.db', 'hidden');
      heldPlace('k4.db', 'decoy hidden');
      for (final kept in [
        'halo.db',
        'halo.db-wal',
        'onion.key',
        'media/a.jpg',
        'wallpapers/w.jpg',
        'k2.db',
        'media_k2/d.jpg',
      ]) {
        expect(there(kept), isTrue, reason: kept);
      }
    });

    test('a decoy no list names goes whole, with its vault, even when only '
        'a folder of it is left', () async {
      phone();
      File(at('k2.db')).deleteSync();
      await sweepContainers({}, pinTable: true);
      for (final gone in ['media_k2/d.jpg', 'media_k4/dh.jpg']) {
        expect(there(gone), isFalse, reason: gone);
      }
      heldPlace('k2.db', 'decoy');
      heldPlace('k4.db', 'decoy hidden');
      // its key went, and another holds its place
      final key = await const FlutterSecureStorage().read(key: kDecoyKeyName);
      expect(key, allOf(isNot(decoyKey), startsWith("x'")));
      // the everyday side's vault may still open: left as it is
      for (final kept in [
        'halo.db',
        'media/a.jpg',
        'k3.db',
        'k3.db-wal',
        'media_k3/h.jpg',
        'wallpapers_k3/hw.jpg',
      ]) {
        expect(there(kept), isTrue, reason: kept);
      }
    });

    test('with nothing left over, nothing changes', () async {
      put('halo.db', 'everyday');
      put('media/a.jpg', 'a photo');
      final before = all();
      await sweepContainers({}, pinTable: false);
      // but the places every install holds
      expect(
        all()..removeWhere((k, _) => ['k2.db', 'k3.db', 'k4.db'].contains(k)),
        before,
      );
      for (final n in ['k2.db', 'k3.db', 'k4.db']) {
        heldPlace(n, '');
      }
      expect(
        await const FlutterSecureStorage().read(key: kDecoyKeyName),
        decoyKey,
      );
    });
  });

  group('the places held', () {
    test('three starts with no decoy and no hidden chats change none of '
        'them', () async {
      put('halo.db', 'everyday');
      FlutterSecureStorage.setMockInitialValues({});
      await sweepContainers({}, pinTable: true);
      Map<String, (List<int>, DateTime)> held() => {
        for (final n in ['k2.db', 'k3.db', 'k4.db'])
          n: (File(at(n)).readAsBytesSync(), File(at(n)).lastModifiedSync()),
      };
      final before = held();
      final key = await const FlutterSecureStorage().read(key: kDecoyKeyName);
      expect(key, isNotNull);
      for (final pinTable in [true, false]) {
        // a filesystem's times are coarse: a remade file would show
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        await sweepContainers({}, pinTable: pinTable);
      }
      final after = held();
      for (final n in before.keys) {
        expect(after[n]!.$1, before[n]!.$1, reason: n);
        expect(after[n]!.$2, before[n]!.$2, reason: n);
      }
      expect(await const FlutterSecureStorage().read(key: kDecoyKeyName), key);
    });

    test('no key holds the decoy\'s place while one from before waits to '
        'move', () async {
      FlutterSecureStorage.setMockInitialValues({kOldDecoyKeyName: decoyKey});
      await makeContainerPlaceholders(root.path);
      final kept = await const FlutterSecureStorage().readAll();
      expect(kept.containsKey(kDecoyKeyName), isFalse);
      expect(kept[kOldDecoyKeyName], decoyKey);
    });
  });

  group('the names before the numbers', () {
    // what a phone before 0.6.1 held: the decoy and both vaults by role
    void older() {
      put('halo.db', 'everyday');
      put('halo_d.db', 'decoy');
      put('halo_d.db-wal', 'decoy log');
      put('halo_v.db', 'hidden');
      put('halo_v.db-journal', 'hidden journal');
      put('halo_dv.db', 'decoy hidden');
    }

    Future<Map<String, String>> store() =>
        const FlutterSecureStorage().readAll();

    test('move to their numbers, the decoy\'s key too, and a second start '
        'changes nothing', () async {
      older();
      // a decoy restore before this left its onion key beside it
      put('onion_d.key', 'decoy onion');
      put('onion_k2.key', 'decoy onion');
      FlutterSecureStorage.setMockInitialValues({
        kOldDecoyKeyName: decoyKey,
        kListedContainers: HaloContainer.decoy.id,
      });
      await moveToNumberedNames(root.path);
      final files = all();
      expect(files, {
        'halo.db': 'everyday',
        'k2.db': 'decoy',
        'k2.db-wal': 'decoy log',
        'k3.db': 'hidden',
        'k3.db-journal': 'hidden journal',
        'k4.db': 'decoy hidden',
      });
      final kept = await store();
      expect(kept[kDecoyKeyName], decoyKey);
      expect(kept.containsKey(kOldDecoyKeyName), isFalse);
      expect(await listedContainers(), {HaloContainer.decoy.id});
      // one length, listed or not
      expect(kept[kListedContainers]!.length, 66);
      await moveToNumberedNames(root.path);
      expect(all(), files);
      expect(await store(), kept);
    });

    test('a move cut short goes on, the database last over what holds its '
        'place', () async {
      older();
      // the log moved, the database not yet, and a place held already
      File(at('halo_d.db-wal')).renameSync(at('k2.db-wal'));
      put('k2.db', 'a place held');
      FlutterSecureStorage.setMockInitialValues({
        kOldDecoyKeyName: decoyKey,
        kDecoyKeyName: decoyKey,
      });
      await moveToNumberedNames(root.path);
      expect(all()['k2.db'], 'decoy');
      expect(all()['k2.db-wal'], 'decoy log');
      expect(there('halo_d.db'), isFalse);
      expect((await store())[kDecoyKeyName], decoyKey);
      expect((await store()).containsKey(kOldDecoyKeyName), isFalse);
    });

    test('every install holds the same names, a decoy or not', () async {
      Future<Set<String>> names() async {
        await sweepContainers(await listedContainers(), pinTable: true);
        // a database open now has its log beside it, as anywhere
        return {
          ...all().keys.where(
            (n) => !n.endsWith('-wal') && !n.endsWith('-journal'),
          ),
          ...(await store()).keys,
        };
      }

      put('halo.db', 'everyday');
      FlutterSecureStorage.setMockInitialValues({});
      final plain = await names();
      expect(plain, containsAll(['k2.db', 'k3.db', 'k4.db']));
      expect(plain, containsAll([kDecoyKeyName, kListedContainers]));
      final listLength = (await store())[kListedContainers]!.length;

      root.deleteSync(recursive: true);
      root.createSync();
      older();
      FlutterSecureStorage.setMockInitialValues({
        kOldDecoyKeyName: decoyKey,
        kListedContainers: HaloContainer.decoy.id,
      });
      await moveToNumberedNames(root.path);
      expect(await names(), plain);
      expect((await store())[kListedContainers]!.length, listLength);
      expect(all()['k2.db'], 'decoy');
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
