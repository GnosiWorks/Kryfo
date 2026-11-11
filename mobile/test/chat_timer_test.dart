// SPDX-License-Identifier: GPL-3.0-or-later
// each chat keeps its own flame: the step to 98 gives chats and groups a
// timer of their own, one chat's choice never reaches another, and the
// time shows beside the flame while it is on
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart';
import 'package:kryfo/widgets/burn_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'source_body.dart';
import 'sqlite_channel.dart';

const _lena = 'amber-otter-lake';
const _jonas = 'brisk-cedar-moon';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the database', () {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    late Directory docs;
    SqliteChannel? sql;
    setUp(() {
      sql = SqliteChannel.install();
      docs = Directory.systemTemp.createTempSync('chat_timer');
      m.setMockMethodCallHandler(paths, (_) async => docs.path);
      FlutterSecureStorage.setMockInitialValues({
        'halo.db.passphrase': '0e' * 32,
      });
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() {
      sql?.uninstall();
      m.setMockMethodCallHandler(paths, null);
      if (docs.existsSync()) docs.deleteSync(recursive: true);
    });

    test('each chat keeps its own, none until one is set', () async {
      if (sql == null) return markTestSkipped('no sqlite on this host');
      final db = HaloDb();
      final raw = await db.open();
      expect(await raw.getVersion(), 98);
      for (final id in [_lena, _jonas]) {
        await raw.insert('contacts', {
          'halo_id': id,
          'onion': '',
          'xpub': '',
          'first_seen': 0,
          'last_seen': 0,
          'nickname': id,
        });
      }
      expect(await db.chatBurnOf(_lena), isNull);
      await db.setChatBurn(_lena, 3600);
      expect(await db.chatBurnOf(_lena), 3600);
      expect(await db.chatBurnOf(_jonas), isNull);
      await db.setChatBurn(_lena, 0);
      expect(await db.chatBurnOf(_lena), 0);
      await db.close();
    });

    test(
      'remove download takes theirs off, keeps the message, never ours',
      () async {
        if (sql == null) return markTestSkipped('no sqlite on this host');
        final db = HaloDb();
        final raw = await db.open();
        await db.saveMessage(
          _lena,
          'in',
          'map',
          msgUid: 'i1',
          filePath: '/m/a.zip',
          fileName: 'a.zip',
        );
        await db.saveMessage(
          _lena,
          'out',
          'mine',
          msgUid: 'o1',
          filePath: '/m/b.zip',
          fileName: 'b.zip',
        );
        expect(await db.dropDownload('i1'), '/m/a.zip');
        expect(await db.dropDownload('o1'), isNull);
        final rows = await raw.query(
          'messages',
          columns: ['msg_uid', 'file_path', 'file_name'],
          orderBy: 'id',
        );
        expect(rows, [
          {'msg_uid': 'i1', 'file_path': null, 'file_name': 'a.zip'},
          {'msg_uid': 'o1', 'file_path': '/m/b.zip', 'file_name': 'b.zip'},
        ]);
        await db.close();
      },
    );

    test('the step to 98 adds a timer to chats and groups', () async {
      if (sql == null) return markTestSkipped('no sqlite on this host');
      final db = HaloDb();
      final raw = await db.open();
      await raw.execute('ALTER TABLE contacts DROP COLUMN chat_burn');
      await raw.execute('ALTER TABLE groups DROP COLUMN chat_burn');
      await raw.setVersion(97);
      await db.close();
      final again = HaloDb();
      final up = await again.open();
      expect(await up.getVersion(), 98);
      for (final t in ['contacts', 'groups']) {
        final cols = [
          for (final c in await up.rawQuery("PRAGMA table_info('$t')"))
            c['name'],
        ];
        expect(cols, contains('chat_burn'), reason: t);
      }
      await again.close();
    });
  });

  test('a chat reads and keeps its own flame, never the shared one', () {
    for (final (file, id) in [
      ('lib/screens/chat_screen.dart', 'widget.peerHaloId'),
      ('lib/screens/group_chat_screen.dart', 'widget.groupId'),
    ]) {
      final src = sourceOf(file);
      expect(src, contains('appState.loadChatBurn($id'), reason: file);
      expect(src, contains('appState.saveChatBurn($id'), reason: file);
      expect(src, isNot(contains('saveGhostPref(')), reason: file);
      expect(src, isNot(contains('loadGhostPref(')), reason: file);
      expect(src, contains('FlameTime(on: ghost, secs: burnSeconds)'));
    }
  });

  test('the time is said as short as it goes', () {
    expect(burnShort(30), '30s');
    expect(burnShort(300), '5m');
    expect(burnShort(3600), '1h');
    expect(burnShort(86400), '1d');
  });

  for (final still in [false, true]) {
    testWidgets('the label eases in beside the flame (still: $still)', (
      t,
    ) async {
      Widget host(bool on) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: still),
          child: Scaffold(body: FlameTime(on: on, secs: 3600)),
        ),
      );
      await t.pumpWidget(host(false));
      expect(find.text('1h'), findsNothing);
      await t.pumpWidget(host(true));
      await t.pump(const Duration(milliseconds: 250));
      expect(find.text('1h'), findsOneWidget);
      await t.pumpWidget(host(false));
      await t.pump(const Duration(milliseconds: 250));
      expect(find.text('1h'), findsNothing);
    });
  }
}
