// SPDX-License-Identifier: GPL-3.0-or-later
// a group voice note whose row waits for a move of its group: a lock
// meanwhile keeps nothing of it and says so once it lifts, where the group
// is there to see. a row that is refused says the note was not sent, and
// never where the group is not
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/album.dart' show AlbumTag;
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_guard.dart' show lockGuard;
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show HaloDb, appState, live, session, useDatabasesForTest;
import 'package:kryfo/polls.dart' show PollVote;
import 'package:kryfo/screens/group_chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart' show haloToastOverlay, haloWhenOpen;
import 'package:kryfo/widgets/voice_mic.dart' show HoldToTalkMic, VoiceTake;
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show app, phone;

const _group = 'g2hidden0001';

// a database with the group, as its screen reads it, and the rows of ours
// it keeps
class _GroupDb implements HaloDb {
  _GroupDb(this.container);

  @override
  final HaloContainer container;
  final saved = <String>[];
  // the row is refused, as for a group ended meanwhile
  var refuse = false;

  @override
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async =>
      (people: <String, bool>{}, groups: {_group});
  @override
  Future<List<Map<String, Object?>>> loadGroups() async => [];
  @override
  Future<Map<String, Object?>?> getGroup(String groupId) async => {
    'group_id': _group,
    'name': 'Saturday hike',
    'is_admin': 0,
  };
  @override
  Future<bool> groupExists(String groupId) async => true;
  @override
  Future<String?> getGroupAtmosphere(String groupId) async => null;
  @override
  Future<List<String>> getGroupMembers(String groupId) async => ['a', 'b'];
  @override
  Future<Set<String>> blockedIds() async => {};
  @override
  Future<List<Map<String, Object?>>> groupMessagesPage(
    String groupId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async => [];
  @override
  Future<List<Map<String, Object?>>> loadGroupMessages(String groupId) async =>
      [];
  @override
  Future<List<Map<String, Object?>>> groupMessagesAfter(
    String groupId,
    int afterRowid,
  ) async => [];
  @override
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async => {};
  @override
  Future<Map<String, Map<String, PollVote>>> pollVotesFor(
    List<String> uids,
  ) async => {};
  @override
  Future<Map<String, ({int have, int of, int gaveUp})>> groupFileReach(
    String groupId,
  ) async => {};
  @override
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async => [];
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async => null;
  @override
  Future<void> markRoomSeen(String groupId) async {}
  @override
  Future<void> clearGroupUnread(String groupId) async {}
  @override
  Future<({bool sent, bool delivered})> sendState(String msgUid) async =>
      (sent: false, delivered: false);

  @override
  Future<bool> saveInGroup(
    String peerId,
    String plaintext, {
    required String groupId,
    required String msgUid,
    int? burnSecs,
    String? replyTo,
    String? mediaPath,
    String? filePath,
    String? fileName,
    bool voiceDisguised = false,
    int sent = 0,
    String? preview,
    String? poll,
    String? sticker,
    AlbumTag? album,
    int? writtenAt,
  }) async {
    if (refuse) return false;
    saved.add(msgUid);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

late Directory _tmp;

void _mock(String channel, Future<Object?> Function(MethodCall c)? h) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), h);

// the group open, from a page under it
Future<void> _open(WidgetTester t) async {
  phone(t);
  await t.pumpWidget(
    app(
      Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => Navigator.of(ctx).push(
              MaterialPageRoute<void>(
                builder: (_) => const GroupChatScreen(groupId: _group),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pump();
  await t.pump(const Duration(seconds: 1));
  final root = t.state<NavigatorState>(find.byType(Navigator).first);
  haloToastOverlay = () => root.overlay;
  addTearDown(() => haloToastOverlay = null);
}

// a note let go, as recorded, and the group left at once: sent is sent
Future<void> _speak(WidgetTester t) async {
  final take = File('${_tmp.path}/vn_take.wav')
    ..writeAsBytesSync(List.filled(4096, 7));
  t
      .widget<HoldToTalkMic>(find.byType(HoldToTalkMic))
      .onSend(VoiceTake(path: take.path, ms: 1200, disguise: false));
  t.state<NavigatorState>(find.byType(Navigator).first).pop();
  // gone before its bubble could show
  await t.pump();
  await t.pump(const Duration(seconds: 1));
  expect(find.byType(GroupChatScreen), findsNothing);
  await _settle(t);
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 20; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 60));
  }
}

// frames run until [done] holds
Future<void> _until(WidgetTester t, bool Function() done) async {
  for (var i = 0; i < 300 && !done(); i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 60));
  }
  expect(done(), isTrue);
}

// frames run until the media folder of [c] holds [n] files
Future<void> _filesIn(WidgetTester t, HaloContainer c, int n) async {
  for (var i = 0; i < 300; i++) {
    if ((await _files(t, c))?.length == n) return;
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 60));
  }
  fail('the media folder never held $n files');
}

// what is said waits for [lifted], as it waits for the lock to lift
Completer<void> _sayLater() {
  final lifted = Completer<void>();
  haloWhenOpen = (act) async {
    await lifted.future;
    await act();
  };
  addTearDown(() => haloWhenOpen = null);
  return lifted;
}

// a move of the group that holds its save until the call handed back
void Function() _moving() {
  var on = true;
  final end = appState.holdMoveForTest([_group]);
  void stop() {
    if (on) end();
    on = false;
  }

  addTearDown(stop);
  return stop;
}

Future<List<String>?> _files(WidgetTester t, HaloContainer c) => t.runAsync(
  () async => [
    for (final e in (await c.mediaDir()).listSync()) e.uri.pathSegments.last,
  ],
);

Future<void> _close(WidgetTester t) async {
  await t.pump(const Duration(seconds: 5));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    lockState.openForTest();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    _tmp = Directory.systemTemp.createTempSync('group_voice');
    _mock('plugins.flutter.io/path_provider', (_) async => _tmp.path);
    _mock('com.llfbandit.record/messages', (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDown(() {
    for (final c in [
      'plugins.flutter.io/path_provider',
      'com.llfbandit.record/messages',
    ]) {
      _mock(c, null);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    try {
      _tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('a lock while a move holds its save: nothing kept or sent, '
      'and said once the lock lifts', (t) async {
    final db = _GroupDb(HaloContainer.everyday);
    useDatabasesForTest(db, Session(db));
    await _open(t);
    final lifted = _sayLater();
    final end = _moving();
    await _speak(t);
    await _filesIn(t, HaloContainer.everyday, 1);
    await _until(t, () => appState.waitingOnMoveForTest == 1);
    // placed, and its save waits for the move
    expect(await _files(t, HaloContainer.everyday), hasLength(1));
    expect(db.saved, isEmpty);
    lockGuard.locking();
    end();
    await _filesIn(t, HaloContainer.everyday, 0);
    expect(db.saved, isEmpty);
    expect(await _files(t, HaloContainer.everyday), isEmpty);
    expect(find.text(l10n.voiceLockedNotSent), findsNothing);
    lifted.complete();
    await _until(
      t,
      () => find.text(l10n.voiceLockedNotSent).evaluate().isNotEmpty,
    );
    expect(find.text(l10n.voiceLockedNotSent), findsOneWidget);
    expect(find.text(l10n.voiceNotSent), findsNothing);
    await _close(t);
  });

  for (final back in [true, false]) {
    final heard = back
        ? 'the vault opened again hears it was not sent'
        : 'the everyday side without the vault hears nothing';
    testWidgets('a hidden group, locked while a move holds its save: nothing '
        'kept, and $heard', (t) async {
      final everyday = _GroupDb(HaloContainer.everyday);
      final vault = _GroupDb(HaloContainer.vault);
      useDatabasesForTest(everyday, await Session.withVault(everyday, vault));
      expect(session.isHidden(_group), isTrue);
      await _open(t);
      final lifted = _sayLater();
      final end = _moving();
      await _speak(t);
      await _filesIn(t, HaloContainer.vault, 1);
      await _until(t, () => appState.waitingOnMoveForTest == 1);
      expect(await _files(t, HaloContainer.vault), hasLength(1));
      // the lock shuts the vault
      lockGuard.locking();
      useDatabasesForTest(live, Session(everyday));
      end();
      await _filesIn(t, HaloContainer.vault, 0);
      await _settle(t);
      expect(vault.saved, isEmpty);
      expect(everyday.saved, isEmpty);
      expect(await _files(t, HaloContainer.vault), isEmpty);
      if (back) {
        useDatabasesForTest(live, await Session.withVault(everyday, vault));
      }
      lifted.complete();
      if (back) {
        await _until(
          t,
          () => find.text(l10n.voiceLockedNotSent).evaluate().isNotEmpty,
        );
      } else {
        await _settle(t);
      }
      expect(
        find.text(l10n.voiceLockedNotSent),
        back ? findsOneWidget : findsNothing,
      );
      expect(find.text(l10n.voiceNotSent), findsNothing);
      // nothing names the group
      expect(find.textContaining('Saturday hike'), findsNothing);
      await _close(t);
    });
  }

  testWidgets('a save refused: the person hears the note was not sent', (
    t,
  ) async {
    final db = _GroupDb(HaloContainer.everyday)..refuse = true;
    useDatabasesForTest(db, Session(db));
    await _open(t);
    await _speak(t);
    await _until(t, () => find.text(l10n.voiceNotSent).evaluate().isNotEmpty);
    expect(db.saved, isEmpty);
    expect(await _files(t, HaloContainer.everyday), isEmpty);
    expect(find.text(l10n.voiceNotSent), findsOneWidget);
    await _close(t);
  });

  testWidgets('a hidden group whose vault shut while its save waited: '
      'refused, and nothing said on the everyday side', (t) async {
    final everyday = _GroupDb(HaloContainer.everyday);
    final vault = _GroupDb(HaloContainer.vault);
    useDatabasesForTest(everyday, await Session.withVault(everyday, vault));
    await _open(t);
    final end = _moving();
    await _speak(t);
    await _filesIn(t, HaloContainer.vault, 1);
    await _until(t, () => appState.waitingOnMoveForTest == 1);
    useDatabasesForTest(live, Session(everyday));
    end();
    await _filesIn(t, HaloContainer.vault, 0);
    await _settle(t);
    expect(vault.saved, isEmpty);
    expect(everyday.saved, isEmpty);
    expect(await _files(t, HaloContainer.vault), isEmpty);
    expect(find.text(l10n.voiceNotSent), findsNothing);
    expect(find.textContaining('Saturday hike'), findsNothing);
    await _close(t);
  });
}
