// SPDX-License-Identifier: GPL-3.0-or-later
// a file of ours that is still going out when the chat is opened again
// shows as sending, with how far it is, and follows the send it did not
// start to its end: done, or failed with a tap to retry once no send holds
// it. the chat's own screen over rows kept in maps
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/album.dart' show AlbumTag;
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/l10n/dates.dart' show hourMinute;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/l10n/numbers.dart' show percent;
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        makePreKeyBundleB64,
        processPeerBundle,
        useDatabasesForTest,
        useEngineForTest,
        AppStateRoute,
        AppStateMessages,
        AppStateRefresh;
import 'package:kryfo/media_progress.dart'
    show mediaProgressEnd, mediaProgressStart, mediaProgressUpdate;
import 'package:kryfo/media_send.dart'
    show mediaInflight, mediaSendsTick, releaseMedia;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/widgets/chat_parts.dart' show SentTick;
import 'package:kryfo/widgets/motion.dart' show SendPill;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show Curve;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';

const _peer = 'amber-who-listens';

class _Db extends DevTestDb {
  _Db(super.mem);

  Map<String, Object?>? _contact(String id) {
    for (final r in mem.rows('contacts')) {
      if (r['halo_id'] == id) return r;
    }
    return null;
  }

  Map<String, Object?>? _row(String uid) {
    for (final r in mem.rows('messages')) {
      if (r['msg_uid'] == uid) return r;
    }
    return null;
  }

  List<Map<String, Object?>> _thread(String peer) => [
    for (final r in mem.rows('messages'))
      if (r['peer_id'] == peer && r['group_id'] == null)
        {...r, 'rowid': r['id']},
  ];

  bool _flag(String id, String col) => _contact(id)?[col] == 1;

  @override
  Future<Map<String, Object?>?> getContact(String haloId) async =>
      _contact(haloId);
  @override
  Future<bool> isAccepted(String haloId) async => _flag(haloId, 'accepted');
  @override
  Future<bool> isBackPaired(String peerId) async =>
      _flag(peerId, 'back_paired');
  @override
  Future<bool> isBlocked(String haloId) async => _flag(haloId, 'blocked');
  @override
  Future<bool> isMuted(String haloId) async => false;
  @override
  Future<bool> isVerified(String haloId) async => false;
  @override
  Future<bool> keyChanged(String haloId) async => false;
  @override
  Future<String?> getAtmosphere(String peerId) async => null;
  @override
  Future<void> clearUnread(String peerId) async {}
  @override
  Future<void> dropHeld(String peerId) async {}
  @override
  Future<int> countMessagesFrom(String peerId, {bool inGroups = false}) async =>
      _thread(peerId).where((r) => r['direction'] == 'in').length;
  @override
  Future<int> countMessagesTo(String peerId) async =>
      _thread(peerId).where((r) => r['direction'] == 'out').length;
  @override
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async => [];
  @override
  Future<Map<String, Object?>?> shieldFor(String haloId) async => null;
  @override
  Future<void> purgeExpiredBurns({
    Future<Set<String>> Function()? blocked,
  }) async {}
  @override
  Future<List<Map<String, Object?>>> messagesFor(String peerId) async =>
      _thread(peerId);
  @override
  Future<List<Map<String, Object?>>> messagesPage(
    String peerId, {
    int? beforeRowid,
    int? beforeAt,
    int limit = 60,
  }) async => [
    for (final r in _thread(peerId))
      if (beforeRowid == null || (r['id'] as int) < beforeRowid) r,
  ];
  @override
  Future<List<Map<String, Object?>>> messagesAfter(
    String peerId,
    int afterRowid,
  ) async => [
    for (final r in _thread(peerId))
      if ((r['id'] as int) > afterRowid) r,
  ];
  @override
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async => {};
  @override
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async => [];
  @override
  Future<bool> messageExists(String msgUid) async => _row(msgUid) != null;
  @override
  Future<bool> isSent(String msgUid) async => _row(msgUid)?['sent'] == 1;
  @override
  Future<({bool sent, bool delivered})> sendState(String msgUid) async => (
    sent: _row(msgUid)?['sent'] == 1,
    delivered: _row(msgUid)?['delivered'] == 1,
  );
  // as the app's: the clock of a timed message of ours, started if unset
  @override
  Future<int?> lightBurn(String msgUid) async {
    final r = _row(msgUid);
    if (r == null) return null;
    final lit = r['burn_at'] as int?;
    final secs = r['burn_secs'] as int?;
    if (lit != null || secs == null) return lit;
    final at = DateTime.now().millisecondsSinceEpoch + secs * 1000;
    await mem.update(
      'messages',
      {'burn_at': at},
      where: 'msg_uid = ?',
      whereArgs: [msgUid],
    );
    return at;
  }

  @override
  Future<void> saveMessage(
    String peerId,
    String direction,
    String plaintext, {
    int? burnAt,
    int? burnSecs,
    String? msgUid,
    String? replyTo,
    String? groupId,
    String? mediaPath,
    String? filePath,
    String? fileName,
    bool voiceDisguised = false,
    bool saved = false,
    int sent = 1,
    String? preview,
    bool secure = false,
    String? poll,
    String? sticker,
    int? sentAt,
    int? writtenAt,
    bool viaDev = false,
    AlbumTag? album,
  }) async {}
}

// nothing is sent here
class _Engine implements HaloEngine {
  @override
  String myEdPubkey() => 'ed-me';
  @override
  String myXPubkey() => 'x-me';
  @override
  void nostrSubscribeBg(String peerXPubHex, {bool fresh = false}) {}
  @override
  void nostrUnsubscribeBg(String peerXPubHex) {}
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void _mock(String channel, Future<Object?> Function(MethodCall c)? h) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), h);

void main() {
  late MemDb mem;
  late Directory docs;
  late File note;
  late DateTime written;

  setUpAll(() async {
    final me = Curve.generateKeyPair();
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
    final pair = Curve.generateKeyPair();
    final amber = SignalSession();
    await amber.bootstrap(
      database: MemDb(),
      xPubBytes: pair.publicKey.serialize().sublist(1),
      xPrivBytes: pair.privateKey.serialize(),
    );
    await processPeerBundle(_peer, await makePreKeyBundleB64(amber));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'battery_opt_prompt_seen': true,
      'miui_autostart_prompt_seen': true,
    });
    FlutterSecureStorage.setMockInitialValues({'send_mode': 'balanced'});
    appState.sendModeForTest = 'balanced';
    useEngineForTest(_Engine());
    docs = Directory.systemTemp.createTempSync('media_stall_chat');
    _mock('plugins.flutter.io/path_provider', (_) async => docs.path);
    _mock('com.llfbandit.record/messages', (_) async => null);
    // a voice bubble reads its length with a player this host has not
    _mock('com.ryanheise.just_audio.methods', (c) async {
      if (c.method == 'init') return Completer<Object?>().future;
      return <String, Object?>{};
    });
    note = File('${docs.path}/note.wav')
      ..writeAsBytesSync(List.filled(4096, 7));
    mem = MemDb();
    await devChatTables(mem, now: 1);
    await mem.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
    });
    final at = DateTime.now().millisecondsSinceEpoch;
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': 'send me the note',
      'sent_at': at - 600000,
      'msg_uid': 'in1',
      'sent': 1,
    });
    // written two minutes ago, not across yet
    written = DateTime.fromMillisecondsSinceEpoch(at - 120000);
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'out',
      'plaintext': '',
      'sent_at': at - 120000,
      'msg_uid': 'v1',
      'file_path': note.path,
      'file_name': 'voice.wav',
      'sent': 0,
    });
    final db = _Db(mem);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  });

  tearDown(() {
    mediaProgressEnd('v1');
    releaseMedia('v1');
    _mock('plugins.flutter.io/path_provider', null);
    _mock('com.llfbandit.record/messages', null);
    _mock('com.ryanheise.just_audio.methods', null);
    docs.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester t, [int beats = 8]) async {
    for (var i = 0; i < beats; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Widget chat() => ChatScreen(
    peerHaloId: _peer,
    peerOnion: '',
    peerXPub: 'ab' * 32,
    avatarSeed: _peer,
  );

  Finder failed() => find.text(l10n.chatFailedTapToRetry);

  testWidgets('a note still going from a chat left shows as sending with '
      'how far it is, and follows the send to its end', (t) async {
    lockState.openForTest();
    // the send the chat left behind holds the row
    mediaInflight.add('v1');
    mediaProgressStart('v1', chatKey: _peer);
    mediaProgressUpdate('v1', 0.42);
    await devOpen(t, chat());
    await settle(t);
    expect(find.byType(SendPill), findsOneWidget);
    expect(find.text(percent(0.42)), findsOneWidget);
    expect(failed(), findsNothing);
    // it stalled: no send holds it, and the bubble says so
    mediaProgressEnd('v1');
    releaseMedia('v1');
    await settle(t);
    expect(find.byType(SendPill), findsNothing);
    expect(failed(), findsOneWidget);
    // the outbox takes it over: sending again
    mediaInflight.add('v1');
    mediaSendsTick.value++;
    await settle(t);
    expect(find.byType(SendPill), findsOneWidget);
    expect(failed(), findsNothing);
    // and it went
    await mem.update(
      'messages',
      {'sent': 1},
      where: 'msg_uid = ?',
      whereArgs: ['v1'],
    );
    releaseMedia('v1');
    await settle(t);
    expect(find.byType(SendPill), findsNothing);
    expect(failed(), findsNothing);
    // across, not read yet: its time and a clock, never a tick
    expect(find.text(hourMinute(written)), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    expect(find.byType(SentTick), findsNothing);
    // their receipt: the tick and Delivered
    await mem.update(
      'messages',
      {'delivered': 1},
      where: 'msg_uid = ?',
      whereArgs: ['v1'],
    );
    appState.chatChanged(_peer);
    await settle(t);
    expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    expect(find.byType(SentTick), findsOneWidget);
    expect(find.text(l10n.chatDelivered), findsOneWidget);
    await devClose(t);
  });

  testWidgets('a timed note the outbox finished starts its clock in the '
      'open chat', (t) async {
    lockState.openForTest();
    await mem.update(
      'messages',
      {'burn_secs': 3600},
      where: 'msg_uid = ?',
      whereArgs: ['v1'],
    );
    mediaInflight.add('v1');
    await devOpen(t, chat());
    await settle(t);
    expect(find.byType(SendPill), findsOneWidget);
    // the outbox's send went, and lit the row's clock or left it to us
    await mem.update(
      'messages',
      {'sent': 1},
      where: 'msg_uid = ?',
      whereArgs: ['v1'],
    );
    releaseMedia('v1');
    await settle(t);
    final row = mem.rows('messages').firstWhere((r) => r['msg_uid'] == 'v1');
    expect(row['burn_at'], isNotNull);
    // the countdown in the bubble's own line, not the composer's timer
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            w.icon == Icons.local_fire_department_outlined &&
            w.size == 11,
      ),
      findsOneWidget,
    );
    await devClose(t);
  });

  testWidgets('a reopened chat shows a note that no send holds as failed, '
      'with a tap to retry', (t) async {
    lockState.openForTest();
    await devOpen(t, chat());
    await settle(t);
    expect(failed(), findsOneWidget);
    expect(find.byType(SendPill), findsNothing);
    await devClose(t);
  });
}
