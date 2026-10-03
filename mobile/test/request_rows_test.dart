// SPDX-License-Identifier: GPL-3.0-or-later
// the requests inbox and its count hold someone who asked: a one to one
// message, a sealed one waiting, or an introduction. a group member known
// only by key asked for nothing and is in neither, though the receive side
// still tries every row not accepted. sqlite here is a stand-in on its
// channel that notes what it is asked
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show HaloDb, kHeldOfAccepted, kRequestRows;
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const sqlite = MethodChannel('com.davidmartos96.sqflite_sqlcipher');
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docs;
  late List<String> said;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('request_rows');
    File(p.join(docs.path, 'halo.db')).writeAsStringSync('the database');
    said = [];
    FlutterSecureStorage.setMockInitialValues({'halo.db.passphrase': 'pw'});
    m.setMockMethodCallHandler(paths, (_) async => docs.path);
    m.setMockMethodCallHandler(sqlite, (call) async {
      final args = call.arguments;
      final sql = args is Map ? '${args['sql'] ?? ''}' : '';
      said.add(sql);
      switch (call.method) {
        case 'openDatabase':
          return 1;
        case 'query':
          if (sql == kHeldOfAccepted) {
            return {
              'columns': ['peer_id'],
              'rows': [
                ['accepted-one'],
              ],
            };
          }
          if (sql.contains('user_version')) {
            return {
              'columns': ['user_version'],
              'rows': [
                [57],
              ],
            };
          }
          return {
            'columns': ['c'],
            'rows': [
              [0],
            ],
          };
      }
      return null;
    });
  });

  tearDown(() {
    m.setMockMethodCallHandler(sqlite, null);
    m.setMockMethodCallHandler(paths, null);
    docs.deleteSync(recursive: true);
  });

  test('a request is someone who asked, never a group member by key '
      'alone', () {
    // a one to one message: a group's do not count
    expect(
      kRequestRows,
      contains(
        'EXISTS (SELECT 1 FROM messages m WHERE m.peer_id = contacts.halo_id '
        'AND m.group_id IS NULL)',
      ),
    );
    expect(kRequestRows, contains('FROM held_onion'));
    expect(kRequestRows, contains('FROM vouches'));
    expect(
      kRequestRows,
      startsWith('accepted = 0 AND blocked = 0 AND IFNULL(archived, 0) = 0'),
    );
  });

  test('the inbox and its count ask by the same rule', () async {
    final db = HaloDb();
    await db.open();
    said.clear();
    await db.askedRequests();
    expect(said.where((s) => s.contains('FROM contacts')), [
      contains(kRequestRows),
    ]);
    // the receive side still tries and listens for every row not accepted,
    // a group member's included, or their group messages would not open
    said.clear();
    await db.pendingRequests();
    expect(said.where((s) => s.contains('FROM contacts')), [
      isNot(contains('EXISTS')),
    ]);
    said.clear();
    await db.pendingRequestCount();
    expect(
      said.where((s) => s.contains('FROM contacts')).first,
      contains(kRequestRows),
    );
  });

  test('the shelf goes in without an accept only for someone accepted '
      'already and not blocked', () async {
    expect(
      kHeldOfAccepted,
      contains('JOIN contacts c ON c.halo_id = h.peer_id'),
    );
    expect(kHeldOfAccepted, contains('c.accepted = 1'));
    expect(kHeldOfAccepted, contains('IFNULL(c.blocked, 0) = 0'));
    final db = HaloDb();
    await db.open();
    said.clear();
    expect(await db.heldOfAccepted(), ['accepted-one']);
    expect(said.where((s) => s.contains('held_onion')), [kHeldOfAccepted]);
  });
}
