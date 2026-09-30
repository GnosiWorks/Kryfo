// SPDX-License-Identifier: GPL-3.0-or-later
// a chat of the same id in two containers is two chats. a message for the
// everyday one while the decoy's is on screen counts as unread, and one
// for the chat on screen in its own session is read. what arrives in
// slices is shown only in the chat of the container it is filed in, and
// what the screens keep between visits is kept per container. the
// databases, signal and the engine are stand-ins
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show AppState, claimChat, releaseChat, useDatabasesForTest;
import 'package:kryfo/media_progress.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _x = 'same-three-words';

class _World {
  final live = ArrivalRows(HaloContainer.everyday);
  final decoy = ArrivalRows(HaloContainer.decoy);
  final io = ArrivalIo();
  late AppState app;
  var _n = 0;

  static Future<_World> make() async {
    final w = _World();
    w.live.person(_x, onion: 'o-$_x', xpub: 'x-$_x');
    w.decoy.person(_x, onion: 'o-$_x', xpub: 'x-$_x');
    final router = VaultRouter(ArrivalStore(), ArrivalSeal());
    await router.load();
    w.app = AppState(io: w.io, router: router)..myId = 'me';
    w.everyday();
    return w;
  }

  void everyday() => useDatabasesForTest(live, Session(live));
  void inDecoy() => useDatabasesForTest(live, Session(decoy));

  Future<void> from(String who, String plain) async {
    final c = 'c${_n++}';
    io.opens[c] = (who, plain);
    await app.receiveOnion([c]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  Future<void> text(String uid) => wrapMessage(
    'hi',
    msgUid: uid,
    sender: asSender(_x),
  ).then((m) => from(_x, m));

  Future<void> slice(String mid, int index, int total) async => from(
    _x,
    await wrapMessage(
      '',
      msgUid: mid,
      mediaId: mid,
      chunkIndex: index,
      chunkTotal: total,
      fileB64: base64Encode(List.filled(300, index)),
      fileName: 'x.bin',
      sender: asSender(_x),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('chat_per_container');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    // the chat on screen counts only while the lock is down
    lockState.openForTest();
  });

  tearDown(() {
    releaseChat(_x);
    docs.deleteSync(recursive: true);
  });

  test('the chat on screen in the decoy leaves the everyday one '
      'unread', () async {
    final w = await _World.make();
    w.inDecoy();
    claimChat(_x);
    await w.text('m1');
    await w.text('m2');
    expect(w.live.msg('m1'), isNotNull);
    expect(w.live.people[_x]!['unread'], 2);
    expect(w.live.calls, isNot(contains('clearUnread:$_x')));
    expect(w.decoy.rowWrites, isEmpty);
    expect(w.decoy.msg('m1'), isNull);
  });

  test('the chat on screen in its own session is read', () async {
    final w = await _World.make();
    claimChat(_x);
    await w.text('m1');
    expect(w.live.people[_x]!['unread'], 0);
    expect(w.live.calls, contains('clearUnread:$_x'));
    expect(w.io.rang, isEmpty);
    // left, the next one counts
    releaseChat(_x);
    await w.text('m2');
    expect(w.live.people[_x]!['unread'], 1);
  });

  test('a file coming in slices shows in the chat of its own '
      'container', () async {
    final w = await _World.make();
    w.inDecoy();
    await w.slice('f1', 0, 3);
    final everyday = HaloContainer.everyday.chatKey(_x);
    expect(incomingMediaProgress.keys.toList(), [everyday]);
    expect(incomingMediaProgress, isNot(contains(_x)));
    expect(
      incomingMediaProgress,
      isNot(contains(HaloContainer.decoy.chatKey(_x))),
    );
    await w.slice('f1', 1, 3);
    await w.slice('f1', 2, 3);
    expect(incomingMediaProgress, isEmpty);
  });

  test('a session keys a chat by the container that holds it', () async {
    final w = await _World.make();
    expect(Session(w.live).chatKey(_x), HaloContainer.everyday.chatKey(_x));
    expect(Session(w.decoy).chatKey(_x), HaloContainer.decoy.chatKey(_x));
    expect(Session(w.live).chatKey(_x), isNot(Session(w.decoy).chatKey(_x)));
  });

  // drafts, read marks and progress are looked up by the session's key for
  // the chat, never by its id alone
  test('the chat screens keep what they hold per container', () {
    final byId = RegExp(
      r'(?:_draftPer\w+|_lastReadPer\w+)\s*(?:\[|\.remove\()\s*widget\.',
    );
    final bannerById = RegExp(r'IncomingMediaBanner\(\s*chatKey:\s*widget\.');
    for (final f in Directory('lib/screens').listSync()) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      expect(byId.hasMatch(src), isFalse, reason: f.path);
      expect(bannerById.hasMatch(src), isFalse, reason: f.path);
    }
    for (final f in [
      'lib/screens/chat_screen.dart',
      'lib/screens/group_chat_screen.dart',
    ]) {
      expect(
        File(f).readAsStringSync(),
        contains('_memo = session.chatKey(widget.'),
        reason: f,
      );
    }
  });
}
