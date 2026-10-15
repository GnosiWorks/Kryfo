// SPDX-License-Identifier: GPL-3.0-or-later
// a text whose send is slow is never sent twice: a reload while it goes
// leaves it sending, the retries every half minute leave it be, and its
// verdict reaches the bubble drawn now. one a block held back is shown
// failed and goes on a tap alone, never while the block holds. the chat's
// own screen, with real signal over rows kept in maps and a relay that
// answers when told. send now counts what is left after its sends, and in
// onion a text waits for a route a relay got through, not tor's word
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devchat/dev_chat.dart' show devChatTables;
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        kNotSent,
        makePreKeyBundleB64,
        processPeerBundle,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/message_envelope.dart' show grindPow, powBits, verifyPow;
import 'package:kryfo/album.dart' show AlbumTag;
import 'package:kryfo/screens/chat_screen.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/widgets/motion.dart' show SendPill, TorStatus;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show
        CiphertextMessage,
        Curve,
        PreKeySignalMessage,
        SessionCipher,
        SignalMessage,
        SignalProtocolAddress;
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart';
import 'mem_db.dart';

const _peer = 'amber-slow-river';

// what the chat's screen reads and writes of its database, kept in maps
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
  Future<bool> isMuted(String haloId) async => _flag(haloId, 'muted');
  @override
  Future<bool> isVerified(String haloId) async => _flag(haloId, 'verified');
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
  }) async {
    final rows = [
      for (final r in _thread(peerId))
        if (beforeRowid == null || (r['id'] as int) < beforeRowid) r,
    ];
    return rows.length > limit ? rows.sublist(rows.length - limit) : rows;
  }

  @override
  Future<List<Map<String, Object?>>> unsentOutbox({
    Set<String> skip = const {},
  }) async => [
    for (final r in mem.rows('messages'))
      if (r['direction'] == 'out' &&
          r['sent'] == 0 &&
          r['msg_uid'] != null &&
          r['group_id'] == null &&
          !skip.contains(r['peer_id']))
        r,
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
  final nonces = <String, int>{};
  @override
  Future<void> setPowNonce(String msgUid, int nonce) async =>
      nonces[msgUid] = nonce;
  @override
  Future<int?> powNonceOf(String msgUid) async => nonces[msgUid];
  @override
  Future<int?> lightBurn(String msgUid) async {
    final r = _row(msgUid);
    final lit = r?['burn_at'] as int?;
    final secs = r?['burn_secs'] as int?;
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
  Future<void> markSent(String msgUid) => mem.update(
    'messages',
    {'sent': 1},
    where: 'msg_uid = ?',
    whereArgs: [msgUid],
  );
  @override
  Future<bool> isSent(String msgUid) async => _row(msgUid)?['sent'] == 1;
  @override
  Future<({bool sent, bool delivered})> sendState(String msgUid) async =>
      (sent: _row(msgUid)?['sent'] == 1, delivered: false);
  @override
  Future<void> holdBack(String msgUid) => mem.update(
    'messages',
    {'sent': kNotSent},
    where: 'msg_uid = ? AND sent = ?',
    whereArgs: [msgUid, 0],
  );
  @override
  Future<void> sendAgain(String msgUid) => mem.update(
    'messages',
    {'sent': 0},
    where: 'msg_uid = ? AND sent = ?',
    whereArgs: [msgUid, kNotSent],
  );

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
  }) async {
    await mem.insert('messages', {
      'peer_id': peerId,
      'direction': direction,
      'plaintext': plaintext,
      'sent_at': sentAt ?? DateTime.now().millisecondsSinceEpoch,
      'msg_uid': msgUid,
      'reply_to': replyTo,
      'sent': sent,
    });
  }
}

// the relay: every send waits for its answer
class _Engine implements HaloEngine {
  final sends = <Completer<String>>[];
  final ciphers = <String>[];

  @override
  Future<String> nostrSend(String peerXPubHex, String b64Cipher) {
    final c = Completer<String>();
    sends.add(c);
    ciphers.add(b64Cipher);
    return c.future;
  }

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
  late SignalSession amber;
  late MemDb mem;
  late _Db db;
  late _Engine relay;
  late Directory docs;

  setUpAll(() async {
    final me = Curve.generateKeyPair();
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
    final pair = Curve.generateKeyPair();
    amber = SignalSession();
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
    relay = _Engine();
    useEngineForTest(relay);
    grindPowForTest = (_) => 0;
    docs = Directory.systemTemp.createTempSync('text_resend');
    _mock('plugins.flutter.io/path_provider', (_) async => docs.path);
    // the mic's recorder is made with the composer and let go with it
    _mock('com.llfbandit.record/messages', (_) async => null);
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
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': 'are you there',
      'sent_at': DateTime.now().millisecondsSinceEpoch - 600000,
    });
    db = _Db(mem);
    useDatabasesForTest(db, Session(db));
    await appState.refreshContacts();
  });

  tearDown(() {
    grindPowForTest = null;
    _mock('plugins.flutter.io/path_provider', null);
    _mock('com.llfbandit.record/messages', null);
    docs.deleteSync(recursive: true);
  });

  Map<String, Object?> sentRow() =>
      mem.rows('messages').firstWhere((r) => r['direction'] == 'out');

  // what runs off the test's clock (the seal) and the frames after it
  Future<void> settle(WidgetTester t, [int beats = 6]) async {
    for (var i = 0; i < beats; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a reload during a slow send leaves it going, it goes once, '
      'and the bubble shown takes its verdict', (t) async {
    await devOpen(
      t,
      ChatScreen(
        peerHaloId: _peer,
        peerOnion: '',
        peerXPub: 'ab' * 32,
        avatarSeed: _peer,
      ),
    );
    await t.enterText(find.byType(TextField).last, 'on my way');
    // the mic makes way for the send button
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byIcon(Icons.arrow_upward));
    await settle(t);
    expect(relay.sends, hasLength(1), reason: 'the send never left');
    expect(find.byType(SendPill), findsOneWidget);

    // the relay is slow: the row is past a minute old when something else
    // in the chat makes it read its rows again
    await mem.update(
      'messages',
      {'sent_at': DateTime.now().millisecondsSinceEpoch - 120000},
      where: 'direction = ?',
      whereArgs: ['out'],
    );
    appState.chatChanged(_peer);
    await settle(t);
    expect(find.byType(SendPill), findsOneWidget);
    // the retries come round while it is still going
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(seconds: 31));
      await settle(t, 2);
    }
    expect(relay.sends, hasLength(1));

    relay.sends.single.complete('ok');
    await settle(t);
    expect(sentRow()['sent'], 1);
    expect(find.byType(SendPill), findsNothing);
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(seconds: 31));
      await settle(t, 2);
    }
    expect(relay.sends, hasLength(1));
    expect(find.byType(SendPill), findsNothing);
    await devClose(t);
  });

  testWidgets('the sending pill sits under its own bubble, at the end', (
    t,
  ) async {
    await devOpen(
      t,
      ChatScreen(
        peerHaloId: _peer,
        peerOnion: '',
        peerXPub: 'ab' * 32,
        avatarSeed: _peer,
      ),
    );
    await t.enterText(find.byType(TextField).last, 'on my way');
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byIcon(Icons.arrow_upward));
    await settle(t);
    expect(find.byType(SendPill), findsOneWidget);
    final pill = t.getRect(find.byType(SendPill));
    final text = t.getRect(find.text('on my way').last);
    final width = t.view.physicalSize.width / t.view.devicePixelRatio;
    // on the bubble's side of the screen, its end near the bubble's end
    expect(pill.center.dx, greaterThan(width / 2), reason: '$pill in $width');
    expect(
      (pill.right - text.right).abs(),
      lessThan(40),
      reason: '$pill $text',
    );
    relay.sends.single.complete('ok');
    await settle(t);
    await devClose(t);
  });

  // what amber reads of a cipher of ours
  Future<Map<String, dynamic>> ambersRead(String cipher) async {
    final w = base64Decode(cipher);
    final body = Uint8List.fromList(w.sublist(1));
    final c = SessionCipher(
      amber.sessionStore,
      amber.preKeyStore,
      amber.signedPreKeyStore,
      amber.identityStore,
      const SignalProtocolAddress('me-to-amber', 1),
    );
    final plain = w[0] == CiphertextMessage.prekeyType
        ? await c.decrypt(PreKeySignalMessage(body))
        : await c.decryptFromSignal(SignalMessage.fromSerialized(body));
    final s = utf8.decode(plain);
    expect(s, startsWith('halo/1:'));
    return jsonDecode(s.substring(7)) as Map<String, dynamic>;
  }

  // a failed text of ours, as a reload finds it
  Future<void> failed(String uid, String text, {int? burnSecs, int sent = 0}) =>
      mem.insert('messages', {
        'peer_id': _peer,
        'direction': 'out',
        'plaintext': text,
        'sent_at': DateTime.now().millisecondsSinceEpoch - 120000,
        'msg_uid': uid,
        'sent': sent,
        'burn_secs': ?burnSecs,
      });

  Future<void> openChat(WidgetTester t) => devOpen(
    t,
    ChatScreen(
      peerHaloId: _peer,
      peerOnion: '',
      peerXPub: 'ab' * 32,
      avatarSeed: _peer,
    ),
  );

  // written offline, a typo fixed with edit, then the retry comes round
  testWidgets('a short reply under a long quote starts where its words '
      'start', (t) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    const long =
        'that would be something to have, given that people mostly '
        'install from the store';
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'out',
      'plaintext': long,
      'msg_uid': 'q-long',
      'sent': 1,
      'sent_at': now - 4000,
    });
    for (final (i, dir, text) in [
      (1, 'in', 'Yeah'),
      (2, 'out', 'ok'),
      (3, 'in', 'نعم'),
    ]) {
      await mem.insert('messages', {
        'peer_id': _peer,
        'direction': dir,
        'plaintext': text,
        'msg_uid': 'r$i',
        'reply_to': 'q-long',
        'sent': 1,
        'sent_at': now - 3000 + i * 100,
      });
    }
    await devOpen(
      t,
      ChatScreen(
        peerHaloId: _peer,
        peerOnion: '',
        peerXPub: 'ab' * 32,
        avatarSeed: _peer,
      ),
    );
    await settle(t);
    // each reply's quote is the widest thing in its bubble
    Rect quoteAbove(String text) {
      final r = t.getRect(find.text(text));
      return find
          .text(long)
          .evaluate()
          .map((e) => t.getRect(find.byWidget(e.widget)))
          .where((q) => q.bottom <= r.top + 1)
          .reduce((a, b) => a.bottom > b.bottom ? a : b);
    }

    for (final word in ['Yeah', 'ok']) {
      final w = t.getRect(find.text(word));
      final q = quoteAbove(word);
      expect(w.left, lessThanOrEqualTo(q.left), reason: '$word $w under $q');
    }
    final ar = t.getRect(find.text('نعم'));
    final q = quoteAbove('نعم');
    expect(ar.right, greaterThan(q.right - 4), reason: '$ar under $q');
    await devClose(t);
  });

  testWidgets('a retry of an edited opener grinds again for its new words', (
    t,
  ) async {
    const before = 'meet at the statoin';
    const after = 'meet at the station';
    final old = grindPow(before, powBits);
    expect(verifyPow(after, old, powBits), isFalse);
    await failed('e1', after);
    db.nonces['e1'] = old;
    final ground = <String>[];
    grindPowForTest = (text) {
      ground.add(text);
      return grindPow(text, powBits);
    };
    await openChat(t);
    await settle(t);
    await t.pump(const Duration(seconds: 31));
    await settle(t);
    expect(relay.ciphers, hasLength(1), reason: 'the retry never went');
    expect(ground, [after]);
    expect(db.nonces['e1'], isNot(old));
    final read = await t.runAsync(() => ambersRead(relay.ciphers.single));
    expect(read!['m'], after);
    expect(read['pw'], db.nonces['e1']);
    expect(verifyPow(after, read['pw'] as int, powBits), isTrue);
    relay.sends.single.complete('ok');
    await settle(t);
    await devClose(t);
  });

  // shown failed, but a receipt since said it went
  testWidgets(
    'a retry that finds it went starts its clock and sends nothing more',
    (t) async {
      await failed('b1', 'gone already', burnSecs: 30);
      await openChat(t);
      await settle(t);
      // the first retry times out, though the relay did take it
      expect(relay.sends, hasLength(1));
      relay.sends.single.complete('error: timeout');
      await settle(t);
      expect(mem.rows('messages').last['burn_at'], isNull);
      await mem.update(
        'messages',
        {'sent': 1, 'delivered': 1},
        where: 'msg_uid = ?',
        whereArgs: ['b1'],
      );
      final before = DateTime.now().millisecondsSinceEpoch;
      await t.pump(const Duration(seconds: 31));
      await settle(t);
      expect(relay.sends, hasLength(1));
      final at = mem
          .rows('messages')
          .firstWhere((r) => r['msg_uid'] == 'b1')['burn_at'];
      expect(at, isA<int>());
      expect(at as int, greaterThanOrEqualTo(before + 30000));
      await devClose(t);
    },
  );

  Future<void> setBlocked(bool on) => mem.update(
    'contacts',
    {'blocked': on ? 1 : 0},
    where: 'halo_id = ?',
    whereArgs: [_peer],
  );

  Object? sentOf(String uid) =>
      mem.rows('messages').firstWhere((r) => r['msg_uid'] == uid)['sent'];

  Future<void> halfMinutes(WidgetTester t, int n) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(seconds: 31));
      await settle(t, 2);
    }
  }

  testWidgets('a text a block held back shows as failed, goes nowhere by '
      'itself, and a tap while the block holds leaves it not sent and says '
      'why', (t) async {
    await setBlocked(true);
    await failed('n1', 'see you there', sent: kNotSent);
    await openChat(t);
    await settle(t);
    expect(find.text(l10n.chatFailedTapToRetry), findsOneWidget);
    await halfMinutes(t, 3);
    expect(relay.sends, isEmpty);
    // the bar says it already
    final why = find.text(l10n.chatYouBlockedThisContact);
    expect(why, findsOneWidget);

    await t.tap(find.text('see you there'));
    await settle(t);
    expect(relay.sends, isEmpty);
    expect(sentOf('n1'), kNotSent);
    expect(find.text(l10n.chatFailedTapToRetry), findsOneWidget);
    // and the tap too
    expect(why, findsNWidgets(2));
    await t.pump(const Duration(seconds: 4));
    await devClose(t);
  });

  testWidgets('after the unblock it waits for a tap, and the tap sends '
      'it', (t) async {
    await setBlocked(true);
    await failed('n2', 'see you there', sent: kNotSent);
    await openChat(t);
    await settle(t);
    // the unblock, and whatever reads the chat again after it
    await setBlocked(false);
    appState.noteOnline(false);
    await settle(t);
    appState.noteOnline(true);
    appState.chatChanged(_peer);
    await settle(t);
    await halfMinutes(t, 8);
    expect(relay.sends, isEmpty);
    expect(sentOf('n2'), kNotSent);
    expect(find.text(l10n.chatFailedTapToRetry), findsOneWidget);

    await t.tap(find.text('see you there'));
    await settle(t);
    expect(relay.sends, hasLength(1));
    final read = await t.runAsync(() => ambersRead(relay.ciphers.single));
    expect(read!['m'], 'see you there');
    relay.sends.single.complete('ok');
    await settle(t);
    expect(sentOf('n2'), 1);
    expect(find.text(l10n.chatFailedTapToRetry), findsNothing);
    await devClose(t);
  });

  testWidgets('a failed text the block came on is not sent at its next '
      'retry, and stays so after the unblock', (t) async {
    await failed('n3', 'see you there');
    await openChat(t);
    await settle(t);
    // the first retry, on opening, does not get through
    expect(relay.sends, hasLength(1));
    relay.sends.single.complete('error: timeout');
    await settle(t);
    await setBlocked(true);
    await halfMinutes(t, 1);
    expect(relay.sends, hasLength(1));
    expect(sentOf('n3'), kNotSent);
    await setBlocked(false);
    await halfMinutes(t, 8);
    expect(relay.sends, hasLength(1));
    expect(sentOf('n3'), kNotSent);
    expect(find.text(l10n.chatFailedTapToRetry), findsOneWidget);
    await devClose(t);
  });

  testWidgets('a block that comes while a text goes leaves it not sent, '
      'whatever the send then says, and the unblock sends nothing', (t) async {
    await failed('n5', 'see you there');
    await openChat(t);
    await settle(t);
    expect(relay.sends, hasLength(1));
    // the block, as the database makes it, and the chat read again
    await setBlocked(true);
    await mem.update(
      'messages',
      {'sent': kNotSent},
      where: 'msg_uid = ?',
      whereArgs: ['n5'],
    );
    appState.chatChanged(_peer);
    await settle(t);
    relay.sends.single.complete('error: timeout');
    await settle(t);
    await setBlocked(false);
    await halfMinutes(t, 8);
    expect(relay.sends, hasLength(1));
    expect(sentOf('n5'), kNotSent);
    expect(find.text(l10n.chatFailedTapToRetry), findsOneWidget);
    await devClose(t);
  });

  testWidgets('the retries leave a row the block marked while it showed as '
      'failed', (t) async {
    await failed('n9', 'see you there');
    await openChat(t);
    await settle(t);
    relay.sends.single.complete('error: timeout');
    await settle(t);
    // marked under the screen, which has not read it again
    await mem.update(
      'messages',
      {'sent': kNotSent},
      where: 'msg_uid = ?',
      whereArgs: ['n9'],
    );
    await halfMinutes(t, 3);
    expect(relay.sends, hasLength(1));
    expect(sentOf('n9'), kNotSent);
    expect(find.text(l10n.chatFailedTapToRetry), findsOneWidget);
    await devClose(t);
  });

  testWidgets('a held back text paged in from further up shows as failed, '
      'and its tap sends it', (t) async {
    await failed('n6', 'the first one', sent: kNotSent);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < 70; i++) {
      await mem.insert('messages', {
        'peer_id': _peer,
        'direction': 'in',
        'plaintext': 'line $i',
        'sent_at': now - 60000 + i,
        'msg_uid': 'in$i',
      });
    }
    await openChat(t);
    await settle(t);
    final row = find.text('the first one');
    expect(row, findsNothing);
    for (var i = 0; i < 20 && row.evaluate().isEmpty; i++) {
      await t.drag(find.byType(Scrollable).first, const Offset(0, 1500));
      await settle(t, 2);
    }
    expect(row, findsOneWidget);
    expect(find.text(l10n.chatFailedTapToRetry), findsOneWidget);
    await halfMinutes(t, 2);
    expect(relay.sends, isEmpty);
    await t.tap(row);
    await settle(t);
    expect(relay.sends, hasLength(1));
    relay.sends.single.complete('ok');
    await settle(t);
    expect(sentOf('n6'), 1);
    await devClose(t);
  });

  testWidgets('a tap on a held back text sends one copy while the outbox '
      'runs too', (t) async {
    await failed('n7', 'see you there', sent: kNotSent);
    await openChat(t);
    await settle(t);
    await t.tap(find.text('see you there'));
    await settle(t);
    expect(relay.sends, hasLength(1));
    await t.runAsync(appState.drainOutbox);
    await settle(t);
    expect(relay.sends, hasLength(1));
    relay.sends.single.complete('ok');
    await settle(t);
    expect(sentOf('n7'), 1);
    await devClose(t);
  });

  testWidgets('a text the chat is still sending is left to it by the '
      'outbox', (t) async {
    await openChat(t);
    await t.enterText(find.byType(TextField).last, 'on my way');
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byIcon(Icons.arrow_upward));
    await settle(t);
    expect(relay.sends, hasLength(1));
    // the relay is slow: the row is old enough for the outbox to take
    await mem.update(
      'messages',
      {'sent_at': DateTime.now().millisecondsSinceEpoch - 120000},
      where: 'direction = ?',
      whereArgs: ['out'],
    );
    await t.runAsync(appState.drainOutbox);
    await settle(t);
    expect(relay.sends, hasLength(1));
    relay.sends.single.complete('ok');
    await settle(t);
    expect(sentRow()['sent'], 1);
    await devClose(t);
  });

  testWidgets('the retry on reconnect leaves a text the outbox is '
      'sending', (t) async {
    await failed('o1', 'see you there');
    appState.noteOnline(false);
    await openChat(t);
    await settle(t);
    expect(relay.sends, isEmpty);
    // the outbox took it while the chat was offline
    expect(appState.claimSend('o1'), isTrue);
    appState.noteOnline(true);
    await settle(t);
    await halfMinutes(t, 2);
    expect(relay.sends, isEmpty);
    // let go, the chat's own retries take it again
    appState.releaseSend('o1');
    await halfMinutes(t, 1);
    expect(relay.sends, hasLength(1));
    relay.sends.single.complete('ok');
    await settle(t);
    expect(sentOf('o1'), 1);
    await devClose(t);
  });

  testWidgets('an outbox pass reads the chat again once, not once a '
      'row', (t) async {
    for (final uid in ['p1', 'p2', 'p3']) {
      await failed(uid, 'text $uid');
    }
    final before = appState.chatRevOf(_peer);
    await t.runAsync(appState.drainOutbox);
    await settle(t);
    expect(relay.sends, hasLength(3));
    for (final s in relay.sends) {
      s.complete('error: timeout');
    }
    await settle(t);
    expect(appState.chatRevOf(_peer) - before, 1);
  });

  testWidgets('send now says what is left once its sends are done', (t) async {
    await failed('s1', 'see you there');
    var done = false;
    late Future<void> flush;
    await t.runAsync(() async {
      flush = appState.flushOutboxNow().whenComplete(() => done = true);
      for (var i = 0; i < 300 && relay.sends.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    expect(relay.sends, hasLength(1));
    expect(done, isFalse);
    // a second tap while it waits adds nothing
    expect(appState.flushing, isTrue);
    var second = false;
    await t.runAsync(
      () => appState.flushOutboxNow().whenComplete(() => second = true),
    );
    expect(second, isTrue);
    expect(done, isFalse);
    relay.sends.single.complete('ok');
    await t.runAsync(() => flush);
    expect(appState.flushing, isFalse);
    expect(sentOf('s1'), 1);
    expect(appState.queued, 0);
  });

  testWidgets('in onion a text waits while tor says ready and nothing gets '
      'through, and goes once a relay does', (t) async {
    appState.sendModeForTest = 'private';
    appState.setTorStatusForTest(TorStatus.bootstrapped);
    appState.setRouteOKForTest(false);
    addTearDown(() {
      appState.setTorStatusForTest(TorStatus.off);
      appState.setRouteOKForTest(true);
      appState.sendModeForTest = 'balanced';
    });
    await openChat(t);
    await t.enterText(find.byType(TextField).last, 'on my way');
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byIcon(Icons.arrow_upward));
    await settle(t);
    await t.pump(const Duration(seconds: 2));
    await settle(t);
    expect(relay.sends, isEmpty);

    appState.setRouteOKForTest(true);
    await t.pump(const Duration(seconds: 1));
    await settle(t);
    expect(relay.sends, hasLength(1));
    relay.sends.single.complete('ok');
    await settle(t);
    await devClose(t);
  });

  testWidgets('a block in the vault leaves a text here waiting, not '
      'failed, and nothing goes', (t) async {
    final hidden = MemDb();
    await hidden.insert('contacts', {
      'halo_id': _peer,
      'onion': '',
      'xpub': 'ab' * 32,
      'first_seen': 1,
      'last_seen': 1,
      'accepted': 1,
      'back_paired': 1,
      'blocked': 1,
    });
    useDatabasesForTest(db, await Session.withVault(db, _Db(hidden)));
    await failed('n8', 'see you there');
    await openChat(t);
    await settle(t);
    await halfMinutes(t, 8);
    expect(relay.sends, isEmpty);
    expect(sentOf('n8'), 0);
    expect(find.text(l10n.chatFailedTapToRetry), findsNothing);
    expect(find.text('see you there'), findsOneWidget);
    await devClose(t);
  });

  // the last here: the store stays marked restored after it
  testWidgets('after a restore, a text waiting on their card stays going '
      'through the retries and the reloads, and a new one goes on as going', (
    t,
  ) async {
    await t.runAsync(signalSession.markRestored);
    // shown failed from before: the retry finds the seal waits on their card
    await failed('w0', 'from before');
    // opened offline, so its first retry comes once the chat is read
    appState.noteOnline(false);
    await openChat(t);
    await settle(t);
    appState.noteOnline(true);
    await settle(t);
    // past the six retries a failed send gets before it shows as failed
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(seconds: 31));
      await settle(t, 2);
    }
    expect(appState.waitsForCard(_peer), isTrue);
    expect(find.byType(SendPill), findsOneWidget);
    // and as many again, the chat read again each time
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(seconds: 31));
      await settle(t, 2);
      await mem.update(
        'messages',
        {'sent_at': DateTime.now().millisecondsSinceEpoch - 300000},
        where: 'direction = ?',
        whereArgs: ['out'],
      );
      appState.chatChanged(_peer);
      await settle(t, 2);
    }
    expect(appState.waitsForCard(_peer), isTrue);
    expect(find.byType(SendPill), findsOneWidget);

    await t.enterText(find.byType(TextField).last, 'are you there');
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byIcon(Icons.arrow_upward));
    await settle(t);
    // the network gone, one failed would say so: these are still going.
    // a text of theirs coming in draws the chat again
    appState.noteOnline(false);
    await mem.insert('messages', {
      'peer_id': _peer,
      'direction': 'in',
      'plaintext': 'hello?',
      'sent_at': DateTime.now().millisecondsSinceEpoch,
      'msg_uid': 'in1',
    });
    appState.chatChanged(_peer);
    await settle(t);
    expect(find.byType(SendPill), findsNWidgets(2));
    expect(
      [
        for (final r in mem.rows('messages'))
          if (r['direction'] == 'out') r['sent'],
      ],
      [0, 0],
    );
    appState.noteOnline(true);
    await devClose(t);
  });
}
