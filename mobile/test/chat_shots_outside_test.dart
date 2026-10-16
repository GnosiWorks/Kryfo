// SPDX-License-Identifier: GPL-3.0-or-later
// what a chat that blocks screenshots keeps out of the app's other pages.
// Saved shows a plain line for a message saved from one, and from a room,
// which always blocks: no words, no picture. search shows one line per such
// chat, how many matched and to open the chat, with no words, sender or
// time. other chats show as ever. the protections card says the window is
// covered while home's card about the old switch still waits
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show GroupPreview, HaloDb, appState, useDatabasesForTest;
import 'package:kryfo/screens/home_screen.dart' show ContactPreview;
import 'package:kryfo/screens/saved_screen.dart';
import 'package:kryfo/screens/search_screen.dart';
import 'package:kryfo/search.dart' show SearchKind;
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart' show devClose, devOpen;

const _blocks = 'calm-orbit-lantern';
const _plain = 'quiet-amber-field';
const _room = 'room-one';

Map<String, Object?> _row(
  int id,
  String peer,
  String text, {
  String? group,
  String? media,
}) => {
  'id': id,
  'rowid': id,
  'peer_id': peer,
  'group_id': group,
  'direction': 'in',
  'plaintext': text,
  'msg_uid': 'u$id',
  'sent_at': 1760000000000 + id,
  'written_at': 1760000000000 + id,
  'saved': 1,
  'media_path': media,
};

class _Db implements HaloDb {
  _Db(this.rows);
  final List<Map<String, Object?>> rows;
  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<List<Map<String, Object?>>> savedMessages() async => rows;
  @override
  Future<List<Map<String, Object?>>> contacts() async => [
    for (final id in [_blocks, _plain])
      {'halo_id': id, 'nickname': id == _blocks ? 'Lena' : 'Sam'},
  ];
  @override
  Future<List<Map<String, Object?>>> loadGroups() async => [
    {'group_id': _room, 'name': 'Night room'},
  ];
  @override
  Future<List<Map<String, Object?>>> searchMessages(
    String? match,
    SearchKind kind, {
    int limit = 300,
  }) async => rows;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

void main() {
  late Directory docs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    docs = Directory.systemTemp.createTempSync('shots_outside');
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => docs.path,
    );
    final pic = File('${docs.path}/p.jpg')..writeAsBytesSync([0xff, 0xd8]);
    final rows = [
      _row(1, _blocks, 'the plan for friday'),
      _row(2, _blocks, '', media: pic.path),
      _row(3, _plain, 'the plan for sunday'),
      _row(4, 'room-key', 'the plan for the room', group: _room),
    ];
    final db = _Db(rows);
    useDatabasesForTest(db, Session(db));
    appState.contacts = [
      ContactPreview(haloId: _blocks, avatarSeed: _blocks, shotsBlocking: true),
      ContactPreview(haloId: _plain, avatarSeed: _plain),
    ];
    appState.groups = [
      GroupPreview(
        groupId: _room,
        name: 'Night room',
        memberCount: 2,
        isAdmin: false,
        createdAt: DateTime(2026),
        expiresAt: 1900000000000,
      ),
    ];
  });

  tearDown(() {
    appState.contacts = [];
    appState.groups = [];
    docs.deleteSync(recursive: true);
  });

  testWidgets('Saved shows a plain line for a blocking chat and a room, no '
      'words and no picture; another chat as ever', (t) async {
    await devOpen(t, const SavedScreen());
    await t.pump(const Duration(seconds: 1));
    expect(find.text('the plan for friday'), findsNothing);
    expect(find.text('the plan for the room'), findsNothing);
    expect(find.text(l10n.savedKeptInChat), findsNWidgets(3));
    expect(find.byType(Image), findsNothing);
    expect(find.text('the plan for sunday'), findsOneWidget);
    await devClose(t);
  });

  testWidgets('search shows one line for a blocking chat and a room, with '
      'how many matched; another chat as ever', (t) async {
    await devOpen(t, const SearchScreen());
    await t.enterText(find.byType(TextField), 'plan');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining('friday', findRichText: true), findsNothing);
    expect(find.textContaining('the room', findRichText: true), findsNothing);
    expect(find.text(l10n.searchKeptMatches(2)), findsOneWidget);
    expect(find.text(l10n.searchKeptMatches(1)), findsOneWidget);
    expect(find.text(l10n.notificationsNewMessage), findsNothing);
    expect(find.textContaining('sunday', findRichText: true), findsOneWidget);
    await devClose(t);
  });
}
