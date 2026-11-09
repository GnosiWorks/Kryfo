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

/// how long the phone keeps what it took of a computer's answers
const kOwnAnswersKeptFor = Duration(days: 30);

/// a computer's timed answer on the phone, its clock not started: it starts
/// once the chat is opened there (answersSeen)
const kAnswerUnseenBurn = 8640000000000000;

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
    // one taken already goes no more: the same frame sent again, or words
    // sent once, here or from another device, taken back or burnt since
    final fk = _answerKey('f', chat, frame);
    final tk = a.kind == AnswerKind.text ? _answerKey('t', chat, a.uid) : null;
    if (await _answerSeen(d, fk) != null) return true;
    if (tk != null &&
        (await _answerSeen(d, tk) != null || await live.messageExists(a.uid))) {
      return true;
    }
    if (!await _ownAnswerCounted(d, from)) {
      await _ownManyAnswers(d, from);
      await _ownAnswerNo(chat, a, kAnswerTooMany);
      return false;
    }
    // kept only once taken: a throw or a refusal leaves no key, so the
    // computer's try again goes through and hears the refusal again
    Future<void> taken() async {
      await _answerNote(d, fk);
      if (tk != null) await _answerNote(d, tk);
    }

    // nothing of the everyday account leaves while the decoy is open: it
    // waits in the everyday database with its device, and goes once the
    // pin opens it
    if (everydayHeld) {
      final n =
          Sqflite.firstIntValue(
            await d.rawQuery('SELECT COUNT(*) FROM own_answers_held'),
          ) ??
          0;
      if (n >= kOwnAnswersHeldMost) return false;
      await d.insert('own_answers_held', {
        'uid': fk,
        'chat': ownChatName(chat),
        'frame': frame,
        'dev': from.id,
        'dkey': from.key,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await taken();
      return true;
    }
    if (!await _ownAnswerGo(chat, a)) return false;
    await taken();
    return true;
  }

  // a key of own_answers_seen: what kind, in which chat, of what
  String _answerKey(String kind, OwnChat chat, String of) =>
      ownHash('$kind\n${ownChatName(chat)}\n$of');

  // a kept key: null when not kept, else its words ('' for none)
  Future<String?> _answerSeen(Database d, String k) async {
    final r = await d.query(
      'own_answers_seen',
      columns: ['text'],
      where: 'k = ?',
      whereArgs: [k],
      limit: 1,
    );
    return r.isEmpty ? null : (r.first['text'] as String? ?? '');
  }

  Future<void> _answerNote(Database d, String k, [String? text]) async {
    final now = answerClock();
    await d.delete(
      'own_answers_seen',
      where: 'at < ?',
      whereArgs: [now - kOwnAnswersKeptFor.inMilliseconds],
    );
    await d.insert('own_answers_seen', {
      'k': k,
      'at': now,
      'text': text,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // what waited while the decoy was open goes now, by the rules as they
  // stand now
  Future<void> _ownAnswersHeldGo() async {
    final own = _ownSync;
    if (own == null || linkedRole || !_ownSends || !_devIdentity) return;
    if (everydayHeld) return;
    final d = await live.open();
    final listed = await own.others(kMainIdent);
    for (final r in await d.query(
      'own_answers_held',
      orderBy: 'rowid',
      limit: 64,
    )) {
      Future<void> done() =>
          d.delete('own_answers_held', where: 'uid = ?', whereArgs: [r['uid']]);
      final chat = ownChatOf(r['chat']);
      final a = ownAnswerOf(r['frame'] as String);
      // a device removed meanwhile hands nothing, held or not
      final still = listed.any((p) => p.id == r['dev'] && p.key == r['dkey']);
      if (chat == null || a == null || !still) {
        await done();
        continue;
      }
      try {
        await _ownAnswerGo(chat, a);
        await done();
      } catch (e) {
        // kept for the next pass
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
        // taken back on the computer before its words came: they never go
        if (await _answerSeen(d, _answerKey('un', chat, a.uid)) != null) {
          return true;
        }
        // edited there first: the words as they stand now go
        final edited = await _answerSeen(d, _answerKey('ed', chat, a.uid));
        final q = a.reply;
        final quoted = q != null && (await live.chatOf(q))?.$1 == id;
        // the first answer takes a waiting chat on, as his own does
        await answerSupport(id);
        await live.saveMessage(
          id,
          'out',
          edited != null && edited.isNotEmpty ? edited : a.text,
          msgUid: a.uid,
          replyTo: quoted ? q : null,
          burnSecs: a.burn,
          preview: a.preview == null ? null : jsonEncode(a.preview),
          sent: 0,
        );
        // its clock here starts once the chat is opened on this phone: a
        // timed answer from a computer never burns unseen
        if (a.burn != null) {
          await d.update(
            'messages',
            {'burn_at': kAnswerUnseenBurn},
            where: "msg_uid = ? AND direction = 'out' AND burn_at IS NULL",
            whereArgs: [a.uid],
          );
        }
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
        // its words not here yet: the edit waits for them
        if (!await live.messageExists(a.uid)) {
          await _answerNote(d, _answerKey('ed', chat, a.uid), a.text);
          return true;
        }
        if (!await mine(a.uid, edit: true)) return false;
        await live.editMessage(a.uid, a.text);
        await editInChat(id, a.uid, a.text);
      case AnswerKind.takeBack:
        // its words not here yet: they never go when they come
        if (!await live.messageExists(a.uid)) {
          await _answerNote(d, _answerKey('un', chat, a.uid));
          return true;
        }
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

  // one more answer of [from]'s this hour, or none past the cap. read and
  // written in one go, so two at once cannot both take the last place
  Future<bool> _ownAnswerCounted(Database d, OwnPeer from) async {
    final k = 'own_answers:${from.id}:${from.key}';
    final now = answerClock();
    return d.transaction((t) async {
      final r = await t.query(
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
      await t.insert('signal_meta', {
        'k': k,
        'v': jsonEncode(at),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    });
  }

  /// on his phone: a computer's timed answers in [peer]'s chat start their
  /// clocks, now that the chat is open here
  Future<void> answersSeen(String peer) async {
    if (linkedRole || sessionQuiet || !_devIdentity) return;
    final d = await live.open();
    final rows = await d.query(
      'messages',
      columns: ['id', 'burn_secs'],
      where: "peer_id = ? AND direction = 'out' AND burn_at = ?",
      whereArgs: [peer, kAnswerUnseenBurn],
    );
    if (rows.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final r in rows) {
      final secs = (r['burn_secs'] as num?)?.toInt() ?? 0;
      await d.update(
        'messages',
        {'burn_at': now + secs * 1000},
        where: 'id = ? AND burn_at = ?',
        whereArgs: [r['id'], kAnswerUnseenBurn],
      );
    }
    chatChanged(peer);
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
