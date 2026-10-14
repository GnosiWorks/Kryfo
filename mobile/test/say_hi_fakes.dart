// SPDX-License-Identifier: GPL-3.0-or-later
// a one to one chat's rows kept in maps, and a relay that answers when
// told: what the say hi and request fit tests open the chat's screen over
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/main.dart' show HaloEngine;

import 'dev_chat_fakes.dart';

// what the chat's screen reads and writes of its database, kept in maps
class SayHiDb extends DevTestDb {
  SayHiDb(super.mem, [super.container]);

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
  }) async => [];
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
  Future<int?> lightBurn(String msgUid) async => null;
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
    bool viaDev = false,
  }) async {
    await mem.insert('messages', {
      'peer_id': peerId,
      'direction': direction,
      'plaintext': plaintext,
      'sent_at': sentAt ?? DateTime.now().millisecondsSinceEpoch,
      'msg_uid': msgUid,
      'reply_to': replyTo,
      'sent': sent,
      'sticker': sticker,
    });
  }
}

// the relay: every send waits for its answer
class SayHiRelay implements HaloEngine {
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

void mockChannel(String channel, Future<Object?> Function(MethodCall c)? h) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), h);
