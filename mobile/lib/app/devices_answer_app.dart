// SPDX-License-Identifier: GPL-3.0-or-later
// answers from a computer in the developer's inbox. the computer hands its
// words to the phone ('oa', own_answer.dart) and the phone sends them as
// its own, on the developer's key and the chat's own session: that key
// never leaves the phone, and the person sees nothing new. the phone takes
// one only from a device still on its list, only in a chat of the inbox
// that is not hidden, not the developer chat and not someone blocked, and
// so many an hour; while the decoy is open it waits

part of '../main.dart';

/// the most answers kept on the phone while the decoy is open
const kOwnAnswersHeldMost = 512;

/// on a linked device, signal_meta: '1' while its phone sends its answers
const kOwnDevAnswersMeta = 'own_dev_answers';

/// why the phone sent no answer of a device's
const kAnswerNotInbox = 'inbox';
const kAnswerTooMany = 'many';

bool _ownDevAnswers = false;

@visibleForTesting
set devAnswersForTest(bool on) => _ownDevAnswers = on;

/// a linked device's seal went to its phone, which sends it as its own
class DeviceHanded extends DeviceSent {
  const DeviceHanded();
}

Future<void> _ownDevAnswersLoad(Database d) async {
  final r = await d.query(
    'signal_meta',
    columns: ['v'],
    where: 'k = ?',
    whereArgs: [kOwnDevAnswersMeta],
    limit: 1,
  );
  _ownDevAnswers = r.isNotEmpty && r.first['v'] == '1';
}

// the phone's word in its profile op
Future<void> _ownDevAnswersPut(Database d, Object? on) async {
  _ownDevAnswers = on == true;
  await d.insert('signal_meta', {
    'k': kOwnDevAnswersMeta,
    'v': _ownDevAnswers ? '1' : '0',
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

/// the clock the answer count reads. a test hands in its own
@visibleForTesting
int Function() answerClock = () => DateTime.now().millisecondsSinceEpoch;

extension AppStateAnswers on AppState {
  /// on a computer linked to his phone: [peer]'s chat is answered by the
  /// phone, from here
  Future<bool> answersViaPhone(String peer) async =>
      _ownDevAnswers && await inboxChatHere(peer);

  // ---- on the computer ----

  // signalSeal for a chat of his inbox: handed to the phone, or not sent
  // from here at all. never on this device's own sessions: his people's
  // apps know one key of his
  Future<Never> _ownAnswerSeal(
    String peer,
    String frame, {
    required bool onlySettled,
  }) async {
    final own = _ownSync;
    if (onlySettled ||
        !_ownDevAnswers ||
        own == null ||
        ownAnswerOf(frame) == null ||
        !await own.answer(kMainIdent, (id: peer, group: false), frame)) {
      throw DeviceCannotReach(peer);
    }
    throw const DeviceHanded();
  }

  // the phone's copy of an answer handed from here: it went
  Future<bool> _ownAnswerWent(OwnChat chat, String uid) async {
    if (!linkedRole || chat.group) return false;
    final n = await (await live.open()).update(
      'messages',
      {'sent': 1},
      where: "msg_uid = ? AND direction = 'out' AND peer_id = ? AND sent != 1",
      whereArgs: [uid, chat.id],
    );
    return n > 0;
  }

  // the phone sent no answer: its row says not sent, and a tap tries again
  Future<bool> _ownAnswerRefused(OwnChat chat, Map<String, dynamic> a) async {
    if (!linkedRole || chat.group) return false;
    final u = a['u'];
    if (u is! String) return false;
    final n = await (await live.open()).update(
      'messages',
      {'sent': kNotSent},
      where: "msg_uid = ? AND direction = 'out' AND peer_id = ? AND sent = 0",
      whereArgs: [u, chat.id],
    );
    if (n == 0) return false;
    _bumpChatRev(chat.id);
    notifyListeners();
    return true;
  }

  // ---- on the phone ----

  // a device's answer, as own sync hands it
  Future<bool> _ownAnswerIn(
    int ident,
    OwnPeer from,
    OwnChat chat,
    String frame,
  ) async {
    if (!linkedDevicesOn || linkedRole || !_devIdentity) return false;
    if (ident != kMainIdent || chat.group) return false;
    final own = _ownSync;
    if (own == null) return false;
    // a device removed since is no device of mine: a stolen one stops here
    final listed = (await own.others(
      ident,
    )).any((p) => p.id == from.id && p.key == from.key);
    if (!listed) return false;
    final a = ownAnswerOf(frame);
    if (a == null) return false;
    final d = await live.open();
    // one sent already, here or from another device, goes no more
    if (a.kind == AnswerKind.text && await live.messageExists(a.uid)) {
      return true;
    }
    if (!await _ownAnswerCounted(d, from)) {
      await _ownManyAnswers(d, from);
      await _ownAnswerNo(chat, a, kAnswerTooMany);
      return false;
    }
    // nothing of the everyday account leaves while the decoy is open: it
    // waits in the everyday database, and goes once the pin opens it
    if (everydayHeld) {
      final n =
          Sqflite.firstIntValue(
            await d.rawQuery('SELECT COUNT(*) FROM own_answers_held'),
          ) ??
          0;
      if (n >= kOwnAnswersHeldMost) return false;
      await d.insert('own_answers_held', {
        'uid': ownHash('${ownChatName(chat)}\n$frame'),
        'chat': ownChatName(chat),
        'frame': frame,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return true;
    }
    return _ownAnswerGo(chat, a);
  }

  // what waited while the decoy was open goes now, by the rules as they
  // stand now
  Future<void> _ownAnswersHeldGo() async {
    if (linkedRole || !_ownSends || !_devIdentity || everydayHeld) return;
    final d = await live.open();
    for (final r in await d.query('own_answers_held', limit: 64)) {
      await d.delete(
        'own_answers_held',
        where: 'uid = ?',
        whereArgs: [r['uid']],
      );
      final chat = ownChatOf(r['chat']);
      final a = ownAnswerOf(r['frame'] as String);
      if (chat == null || a == null) continue;
      try {
        await _ownAnswerGo(chat, a);
      } catch (e) {
        dlog('answers: one held not sent (${e.runtimeType})');
      }
    }
  }

  // whether [id] is a chat of the inbox an answer may go to
  Future<bool> _answerableHere(OwnChat chat) async {
    final id = chat.id;
    if (chat.group || isDevId(id) || isOwnNotes(chat)) return false;
    // a hidden chat is no chat of the inbox, whatever its rows say
    if (session.isHidden(id) || _routeOf(id, null) != RouteTo.everyday) {
      return false;
    }
    if (await live.getContact(id) == null) return false;
    if (await blockedAnywhere(id)) return false;
    return await live.support.has(id) || await live.hasViaDev(id);
  }

  Future<bool> _ownAnswerGo(OwnChat chat, OwnAnswer a) async {
    final id = chat.id;
    if (!await _answerableHere(chat)) {
      await _ownAnswerNo(chat, a, kAnswerNotInbox);
      return false;
    }
    final d = await live.open();
    // a row of mine in this chat
    Future<bool> mine(String uid, {bool edit = false}) async => (await d.query(
      'messages',
      columns: ['id'],
      where:
          "msg_uid = ? AND direction = 'out' AND peer_id = ? AND "
          "(group_id IS NULL OR group_id = '')"
          "${edit ? ' AND sticker IS NULL' : ''}",
      whereArgs: [uid, id],
      limit: 1,
    )).isNotEmpty;
    switch (a.kind) {
      case AnswerKind.text:
        if (await live.messageExists(a.uid)) return true;
        final q = a.reply;
        final quoted = q != null && (await live.chatOf(q))?.$1 == id;
        // the first answer takes a waiting chat on, as his own does
        await answerSupport(id);
        await live.saveMessage(
          id,
          'out',
          a.text,
          msgUid: a.uid,
          replyTo: quoted ? q : null,
          burnSecs: a.burn,
          preview: a.preview == null ? null : jsonEncode(a.preview),
          sent: 0,
        );
        unawaited(_ownAnswerSend(id, a.uid));
      case AnswerKind.reaction:
        final at = await live.chatOf(a.uid);
        if (at == null || at.$1 != id || at.$2 != null) return false;
        if (a.text.isEmpty) {
          await live.removeReaction(a.uid, '');
        } else {
          await live.addReaction(a.uid, '', a.text);
        }
        await reactInChat(id, a.uid, a.text);
      case AnswerKind.edit:
        if (!await mine(a.uid, edit: true)) return false;
        await live.editMessage(a.uid, a.text);
        await editInChat(id, a.uid, a.text);
      case AnswerKind.takeBack:
        if (!await mine(a.uid)) return false;
        await takeDropBackOf(a.uid);
        await live.deleteMessage(a.uid);
        unawaited(_io.unnotifyMessage(a.uid));
        await unsendInChat(id, a.uid);
    }
    chatChanged(id);
    await refreshContacts();
    return true;
  }

  // the answer's row goes now, as the outbox sends one: sealed on his key,
  // copied to my devices, tried again by the outbox if it does not go
  Future<void> _ownAnswerSend(String id, String uid) async {
    final r = await (await live.open()).query(
      'messages',
      where: "msg_uid = ? AND direction = 'out' AND peer_id = ? AND sent = 0",
      whereArgs: [uid, id],
      limit: 1,
    );
    if (r.isEmpty || !claimSend(uid)) return;
    try {
      await _drainOne(r.first, live);
    } catch (e) {
      dlog('answers: not sent now (${e.runtimeType})');
    } finally {
      releaseSend(uid);
    }
  }

  // the device hears a text of its did not go, so its row says not sent
  Future<void> _ownAnswerNo(OwnChat chat, OwnAnswer a, String why) async {
    if (a.kind != AnswerKind.text) return;
    try {
      await _ownSync?.op(kMainIdent, 'answer', chat, {'u': a.uid, 'x': why});
    } catch (e) {
      dlog('answers: refusal not told (${e.runtimeType})');
    }
  }

  // one more answer of [from]'s this hour, or none past the cap
  Future<bool> _ownAnswerCounted(Database d, OwnPeer from) async {
    final k = 'own_answers:${from.id}:${from.key}';
    final now = answerClock();
    final r = await d.query(
      'signal_meta',
      columns: ['v'],
      where: 'k = ?',
      whereArgs: [k],
      limit: 1,
    );
    var at = <int>[];
    if (r.isNotEmpty) {
      try {
        at = [
          for (final x in jsonDecode(r.first['v'] as String) as List)
            if (x is int && x <= now && now - x < 3600000) x,
        ];
      } catch (_) {
        // a count that does not read starts again
      }
    }
    if (at.length >= kOwnAnswersAnHour) return false;
    at.add(now);
    await d.insert('signal_meta', {
      'k': k,
      'v': jsonEncode(at),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return true;
  }

  // a computer past its answers: the devices notice on the home, once
  Future<void> _ownManyAnswers(Database d, OwnPeer from) async {
    final uids = await ownDevicesWithKeys(d, kMainIdent, [
      (id: from.id, key: from.key),
    ]);
    if (uids.isEmpty) return;
    await d.insert('dev_marks', {
      'ident': kMainIdent,
      'peer': '',
      'kind': kManyAnswersNoticeMark,
      'key': uids.first,
      'at': answerClock(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await readLinkNotices(d);
  }
}
