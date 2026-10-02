// SPDX-License-Identifier: GPL-3.0-or-later
// an edit that comes in changes the line home shows for that chat, as a
// local edit does. the wire and signal are stand-ins
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show AppState, useDatabasesForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _bob = 'bob-who-edits';
const _eve = 'eve-who-edits';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;
  late ArrivalRows live;
  late ArrivalIo io;
  late AppState app;
  var n = 0;

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('edit_preview');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    live = ArrivalRows(HaloContainer.everyday);
    io = ArrivalIo();
    live.person(_bob, onion: 'o-$_bob', xpub: 'x-$_bob');
    live.person(_eve, onion: 'o-$_eve', xpub: 'x-$_eve');
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    app = AppState(io: io, router: router)..myId = 'me';
    useDatabasesForTest(live, Session(live));
  });

  tearDown(() => docs.deleteSync(recursive: true));

  Future<void> from(String who, String plain) async {
    final c = 'c${n++}';
    io.opens[c] = (who, plain);
    await app.receiveOnion([c]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  String? lineOf(String who) =>
      app.contacts.singleWhere((c) => c.haloId == who).preview;

  test('an edit that comes in changes home\'s line', () async {
    await from(
      _bob,
      await wrapMessage('see you at 5', msgUid: 'u1', sender: asSender(_bob)),
    );
    await app.refreshContacts();
    expect(lineOf(_bob), 'see you at 5');
    await from(
      _bob,
      await wrapMessage(
        '',
        edit: const EditFrame(targetUid: 'u1', newText: 'see you at 6'),
        sender: asSender(_bob),
      ),
    );
    expect(live.msg('u1')!['plaintext'], 'see you at 6');
    expect(lineOf(_bob), 'see you at 6');
  });

  test('one from someone else changes neither', () async {
    await from(
      _bob,
      await wrapMessage('see you at 5', msgUid: 'u2', sender: asSender(_bob)),
    );
    await app.refreshContacts();
    await from(
      _eve,
      await wrapMessage(
        '',
        edit: const EditFrame(targetUid: 'u2', newText: 'never'),
        sender: asSender(_eve),
      ),
    );
    expect(live.msg('u2')!['plaintext'], 'see you at 5');
    expect(lineOf(_bob), 'see you at 5');
  });
}
