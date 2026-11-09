// SPDX-License-Identifier: GPL-3.0-or-later
// the developer's inbox on his linked devices. his phone tells them it
// keeps one, passes on what reaches it, and carries each chat's place in
// the inbox on the chat's rows; a device files nothing by itself. a device
// may move a chat between the inbox and Chats and put it away; a delete or
// a block stays where it was made

part of '../main.dart';

/// on a linked device, signal_meta: '1' while its phone keeps the inbox
const kOwnDevInboxMeta = 'own_dev_inbox';

/// the places a chat has in the inbox, as the support table keeps them
const kInboxStates = {'open', 'done', 'out'};

bool _ownDevInbox = false;

/// a linked device of the developer's phone: it shows his inbox
bool get devInboxHere => linkedRole && _ownDevInbox && !sessionQuiet;

@visibleForTesting
set devInboxForTest(bool on) => _ownDevInbox = on;

// on boot, what the phone told last
Future<void> _ownDevInboxLoad(Database d) async {
  final r = await d.query(
    'signal_meta',
    columns: ['v'],
    where: 'k = ?',
    whereArgs: [kOwnDevInboxMeta],
    limit: 1,
  );
  _ownDevInbox = r.isNotEmpty && r.first['v'] == '1';
}

// the phone's word in its profile op
Future<void> _ownDevInboxPut(Database d, Object? on) async {
  _ownDevInbox = on == true;
  await d.insert('signal_meta', {
    'k': kOwnDevInboxMeta,
    'v': _ownDevInbox ? '1' : '0',
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

// whether the support table is there: a migration that could not make it
// leaves every other chat as it was
Future<bool> _inboxTable(Database d) async => (await d.rawQuery(
  "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'support_chats'",
)).isNotEmpty;

extension AppStateInbox on AppState {
  /// the inbox shows here: his phone, or a linked device of it
  bool get devInbox => devMode || devInboxHere;

  // a chat's place in the inbox as my devices are told it: the state, and
  // on the phone when it came. null for a chat not filed there. read on
  // the everyday side while the decoy is open too, for what waits there
  Future<Map<String, Object?>?> _inboxPlace(String id) async {
    if (!_devIdentity && !(linkedRole && _ownDevInbox)) return null;
    final List<Map<String, Object?>> r;
    try {
      r = await (await live.open()).query(
        'support_chats',
        columns: ['state', 'first_at'],
        where: 'halo_id = ?',
        whereArgs: [id],
        limit: 1,
      );
    } catch (e) {
      // a table a migration could not make holds nothing
      dlog('inbox: not read (${e.runtimeType})');
      return null;
    }
    if (r.isEmpty) return null;
    return {'s': r.first['state'], if (!linkedRole) 'f': r.first['first_at']};
  }

  /// a chat of the developer's inbox on a linked device of his phone: one
  /// filed there, or one a message came into through the developer chat
  Future<bool> inboxChatHere(String id) async {
    if (!devInboxHere || isDevChat(id)) return false;
    if (await _inboxPlace(id) != null) return true;
    try {
      return await live.hasViaDev(id);
    } catch (e) {
      dlog('inbox: via dev not read (${e.runtimeType})');
      return false;
    }
  }

  // on a linked device, the phone's word on a chat's place: filed as the
  // phone has it, or no longer filed. nothing else files here. only his
  // phone keeps an inbox, so its word says this device shows one
  Future<void> _inboxTake(String id, Object? sp) async {
    if (!linkedRole || sessionQuiet) return;
    final d = await live.open();
    if (sp == null) {
      await d.delete('support_chats', where: 'halo_id = ?', whereArgs: [id]);
      return;
    }
    if (sp is! Map) return;
    final s = sp['s'], f = sp['f'];
    if (s is! String || !kInboxStates.contains(s)) return;
    if (!_ownDevInbox) await _ownDevInboxPut(d, true);
    await d.insert('support_chats', {
      'halo_id': id,
      'first_at': f is int ? f : DateTime.now().millisecondsSinceEpoch,
      'state': s,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await d.update(
      'support_chats',
      {'state': s},
      where: 'halo_id = ?',
      whereArgs: [id],
    );
  }

  // on the phone, a linked device moved a chat: put away, back in the
  // inbox, or to Chats, by the phone's own rules (a chat that never came
  // through the developer chat moves nowhere)
  Future<void> _inboxFromDevice(String id, Object? sp) async {
    if (linkedRole || !devMode || sp is! Map) return;
    final want = sp['s'];
    if (want is! String || !kInboxStates.contains(want)) return;
    final s = session.primary.support;
    final had = await _inboxPlace(id);
    final now = had?['s'];
    if (now == null) {
      if (want == 'open') await moveToInbox(id);
      return;
    }
    if (now == want) return;
    switch (want) {
      case 'done':
        if (now == 'open') await s.setDone(id, true);
      case 'open':
        if (now == 'done') await s.setDone(id, false);
        if (now == 'out') await moveToInbox(id);
      case 'out':
        await moveToChats(id);
    }
  }
}
