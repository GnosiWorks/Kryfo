// SPDX-License-Identifier: GPL-3.0-or-later
// the session over two containers: which one a call goes to, and how the
// lists of both come together. the databases are fakes that keep the rows
// they are given and note every call, so nothing here needs sqlite
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart' show HaloDb;
import 'package:kryfo/polls.dart' show PollSpec, PollVote;
import 'package:kryfo/search.dart' show SearchKind;
import 'package:kryfo/session.dart';

// only what Session asks for. a call with an answer is written out; one
// without goes through noSuchMethod, and anything else fails on its type
class _Db implements HaloDb {
  _Db(this._container, this.name);

  final HaloContainer _container;
  final String name;
  // a vault that has closed: any touch fails the test
  bool dead = false;
  final calls = <String>[];

  Map<String, bool> people = {};
  Set<String> groups = {};
  Set<String> uids = {};
  List<Map<String, Object?>> contactRows = [];
  List<Map<String, Object?>> requests = [];
  List<Map<String, Object?>> parked = [];
  List<Map<String, Object?>> groupRows = [];
  List<Map<String, Object?>> saved = [];
  List<Map<String, Object?>> found = [];
  List<Map<String, Object?>> vouches = [];
  Map<String, Map<String, Object?>> lasts = {};
  Set<String> blocked = {};
  Map<String, List<MapEntry<String, String>>> reactions = {};
  Map<String, Map<String, PollVote>> votes = {};

  T _hit<T>(String call, T answer) {
    if (dead) throw StateError('$name touched after it closed: $call');
    calls.add(call);
    return answer;
  }

  @override
  HaloContainer get container {
    if (dead) throw StateError('$name touched after it closed: container');
    return _container;
  }

  @override
  Future<({Map<String, bool> people, Set<String> groups})> heldChats() async =>
      _hit('heldChats', (people: people, groups: groups));
  @override
  Future<bool> messageExists(String msgUid) async =>
      _hit('messageExists:$msgUid', uids.contains(msgUid));
  @override
  Future<List<Map<String, Object?>>> contacts() async =>
      _hit('contacts', contactRows);
  @override
  Future<List<Map<String, Object?>>> pendingRequests() async =>
      _hit('pendingRequests', requests);
  @override
  Future<int> pendingRequestCount() async =>
      _hit('pendingRequestCount', requests.length);
  @override
  Future<List<Map<String, Object?>>> parkedRequests() async =>
      _hit('parkedRequests', parked);
  @override
  Future<List<Map<String, Object?>>> loadGroups() async =>
      _hit('loadGroups', groupRows);
  @override
  Future<List<Map<String, Object?>>> savedMessages() async =>
      _hit('savedMessages', saved.take(500).toList());
  @override
  Future<List<Map<String, Object?>>> searchMessages(
    String? match,
    SearchKind kind, {
    int limit = 300,
  }) async => _hit('searchMessages', found.take(limit).toList());
  @override
  Future<List<Map<String, Object?>>> vouchesFor(String haloId) async =>
      _hit('vouchesFor:$haloId', vouches);
  @override
  Future<Map<String, Map<String, Object?>>> lastMessages() async =>
      _hit('lastMessages', lasts);
  @override
  Future<Set<String>> blockedIds() async => _hit('blockedIds', blocked);
  @override
  Future<Map<String, List<MapEntry<String, String>>>> loadReactionsFor(
    List<String> msgUids,
  ) async => _hit('loadReactionsFor', reactions);
  @override
  Future<Map<String, Map<String, PollVote>>> pollVotesFor(
    List<String> uids,
  ) async => _hit('pollVotesFor', votes);
  @override
  Future<Map<String, Object?>?> getContact(String haloId) async =>
      _hit('getContact:$haloId', null);
  @override
  Future<List<String>> getGroupMembers(String groupId) async =>
      _hit('getGroupMembers:$groupId', const <String>[]);
  @override
  Future<bool> groupExists(String groupId) async =>
      _hit('groupExists:$groupId', true);
  @override
  Future<List<Map<String, Object?>>> pinnedIn({
    String? peerId,
    String? groupId,
  }) async => _hit('pinnedIn:${groupId ?? peerId}', const []);
  @override
  Future<bool> isSent(String msgUid) async => _hit('isSent:$msgUid', true);
  @override
  Future<({bool sent, bool delivered})> sendState(String msgUid) async =>
      _hit('sendState:$msgUid', (sent: true, delivered: false));
  @override
  Future<({PollSpec spec, String? groupId, bool mine})?> pollRow(
    String uid,
  ) async => _hit('pollRow:$uid', null);
  @override
  Future<bool> putPollVote(
    String pollUid,
    String voter,
    String? groupId,
    List<int> choices,
    int seq,
  ) async => _hit('putPollVote:$pollUid', true);

  @override
  dynamic noSuchMethod(Invocation i) {
    final name = RegExp(r'"(.*)"').firstMatch('${i.memberName}')!.group(1);
    final args = i.positionalArguments;
    return _hit(
      args.isEmpty ? '$name' : '$name:${args.first}',
      Future<void>.value(),
    );
  }
}

_Db _everyday() => _Db(HaloContainer.everyday, 'everyday');
_Db _vault() => _Db(HaloContainer.vault, 'vault');

// a session over both, with the calls made while opening it forgotten
Future<Session> _open(_Db p, _Db v) async {
  final s = await Session.withVault(p, v);
  p.calls.clear();
  v.calls.clear();
  return s;
}

Map<String, Object?> _msg(String peer, int at, {String? group}) => {
  'peer_id': peer,
  'group_id': group,
  'sent_at': at,
};

// one call of every kind, on chats a vault would hold (h, hg, vu)
Future<void> _everyKind(Session s) async {
  await s.getContact('h');
  await s.setMuted('h', true);
  await s.getGroupMembers('hg');
  await s.renameGroup('hg', 'n');
  await s.saveMessage('h', 'out', 'x');
  await s.saveMessage('a', 'in', 'x', groupId: 'hg');
  await s.pinnedIn(groupId: 'hg');
  await s.createGroup('ng', 'n', const ['h'], isAdmin: true);
  await s.upsertContact('h', 'o', 'x');
  await s.addReaction('vu', '', 'y');
  await s.deleteMessage('vu');
  await s.sendState('vu');
  await s.queuePin('vu', 'h', true);
  await s.putPollVote('vu', 'me', 'hg', const [0], 1);
  await s.messageExists('vu');
  await s.blockedIds();
  await s.contacts();
  await s.lastMessages();
  await s.loadGroups();
  await s.loadReactionsFor(const ['vu']);
  await s.parkedRequests();
  await s.pendingRequestCount();
  await s.pendingRequests();
  await s.pollVotesFor(const ['vu']);
  await s.purgeExpiredBurns();
  await s.savedMessages();
  await s.searchMessages('w', SearchKind.all);
  await s.vouchesFor('h');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUpAll(() {
    docs = Directory.systemTemp.createTempSync('session_merge');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  group('no vault', () {
    test('every call is the primary', () async {
      final p = _everyday();
      final s = Session(p);
      await _everyKind(s);
      expect(s.vault, isNull);
      expect(s.isHidden('h'), isFalse);
      expect(p.calls, [
        'getContact:h',
        'setMuted:h',
        'getGroupMembers:hg',
        'renameGroup:hg',
        'saveMessage:h',
        'saveMessage:a',
        'pinnedIn:hg',
        'createGroup:ng',
        'upsertContact:h',
        'addReaction:vu',
        'deleteMessage:vu',
        'sendState:vu',
        'queuePin:vu',
        'putPollVote:vu',
        // asked for, not a lookup
        'messageExists:vu',
        'blockedIds',
        'contacts',
        'lastMessages',
        'loadGroups',
        'loadReactionsFor',
        'parkedRequests',
        'pendingRequestCount',
        'pendingRequests',
        'pollVotesFor',
        'purgeExpiredBurns',
        'savedMessages',
        'searchMessages',
        'vouchesFor:h',
      ]);
    });

    test('a closed vault is never touched', () async {
      final p = _everyday();
      final v = _vault()
        ..people = {'h': true}
        ..groups = {'hg'}
        ..uids = {'vu'};
      await Session.withVault(p, v);
      v.dead = true;
      final s = Session(p);
      await _everyKind(s);
      expect(s.isHidden('h'), isFalse);
      expect(s.isHidden('hg'), isFalse);
      expect(
        (await s.mediaDirOf('h')).path,
        '${docs.path}${Platform.pathSeparator}media',
      );
    });
  });

  group('routing', () {
    test('hidden people and groups go to the vault', () async {
      final p = _everyday();
      final v = _vault()
        ..people = {'h': true}
        ..groups = {'hg'};
      final s = await _open(p, v);
      expect(s.isHidden('h'), isTrue);
      expect(s.isHidden('hg'), isTrue);
      expect(s.isHidden('a'), isFalse);
      await s.getContact('h');
      await s.setArchived('h', true);
      await s.clearUnread('h');
      await s.getGroupMembers('hg');
      await s.clearGroupUnread('hg');
      await s.getContact('a');
      await s.getGroupMembers('g');
      // a group row goes by its group, whoever sent it
      await s.saveMessage('a', 'in', 'x', groupId: 'hg');
      await s.saveMessage('h', 'in', 'x', groupId: 'g');
      await s.saveMessage('h', 'out', 'x');
      await s.pinnedIn(peerId: 'h');
      await s.pinnedIn(groupId: 'g');
      expect(v.calls, [
        'getContact:h',
        'setArchived:h',
        'clearUnread:h',
        'getGroupMembers:hg',
        'clearGroupUnread:hg',
        'saveMessage:a',
        'saveMessage:h',
        'pinnedIn:h',
      ]);
      expect(p.calls, [
        'getContact:a',
        'getGroupMembers:g',
        'saveMessage:h',
        'pinnedIn:g',
      ]);
    });

    test('a key held by both is the primary', () async {
      final p = _everyday()..people = {'both': false, 'h': false};
      final v = _vault()..people = {'h': true, 'both': false, 'only': false};
      final s = await _open(p, v);
      // a hidden contact with a key left in the primary stays hidden
      expect(s.isHidden('h'), isTrue);
      expect(s.isHidden('both'), isFalse);
      expect(s.isHidden('only'), isTrue);
      await s.getContact('both');
      await s.getContact('only');
      expect(p.calls, ['getContact:both']);
      expect(v.calls, ['getContact:only']);
    });

    test('the primary is not read when the vault holds no keys', () async {
      final p = _everyday();
      final v = _vault()..people = {'h': true};
      await Session.withVault(p, v);
      expect(p.calls, isEmpty);
      expect(v.calls, ['heldChats']);
    });

    test('new chats and adds go to the primary', () async {
      final p = _everyday();
      final v = _vault()
        ..people = {'h': true}
        ..groups = {'hg'};
      final s = await _open(p, v);
      await s.createGroup('ng', 'n', const ['h'], isAdmin: true);
      await s.createRoom(
        groupId: 'room',
        name: 'n',
        priv: 'k',
        pub: 'p',
        expiresAt: 1,
        creatorPub: 'p',
        fcPk: 'f',
        members: const ['p'],
      );
      await s.upsertContact('new', 'o', 'x');
      await s.groupExists('ng');
      // someone the vault holds stays there
      await s.upsertContact('h', 'o', 'x');
      expect(p.calls, [
        'createGroup:ng',
        'createRoom',
        'upsertContact:new',
        'groupExists:ng',
      ]);
      expect(v.calls, ['upsertContact:h']);
    });

    test('uid calls look in the vault first', () async {
      final p = _everyday();
      final v = _vault()..uids = {'vu'};
      final s = await _open(p, v);
      for (final uid in ['vu', 'pu']) {
        await s.addReaction(uid, '', 'y');
        await s.removeReaction(uid, '');
        await s.editMessage(uid, 't');
        await s.deleteMessage(uid);
        await s.setSaved(uid, true);
        await s.setPinned(uid, true);
        await s.markSent(uid);
        await s.isSent(uid);
        await s.sendState(uid);
        await s.pollRow(uid);
      }
      List<String> done(_Db d) => [
        for (final c in d.calls)
          if (!c.startsWith('messageExists')) c,
      ];
      const kinds = [
        'addReaction',
        'removeReaction',
        'editMessage',
        'deleteMessage',
        'setSaved',
        'setPinned',
        'markSent',
        'isSent',
        'sendState',
        'pollRow',
      ];
      expect(done(v), [for (final k in kinds) '$k:vu']);
      expect(done(p), [for (final k in kinds) '$k:pu']);
      // the primary is never asked where a row is
      expect(p.calls.where((c) => c.startsWith('messageExists')), isEmpty);
      expect(await s.messageExists('vu'), isTrue);
      expect(await s.messageExists('pu'), isFalse);
    });

    test('a uid in neither goes to the named chat', () async {
      final p = _everyday();
      final v = _vault()
        ..people = {'h': true}
        ..groups = {'hg'};
      final s = await _open(p, v);
      await s.queuePin('gone', 'h', true);
      await s.queueEdit('gone', 'h', 't');
      await s.putPollVote('gone', 'me', 'hg', const [0], 1);
      await s.closePollRow(
        'gone',
        const PollSpec(options: ['a', 'b']),
        {},
        'hg',
      );
      await s.queuePin('gone', 'a', true);
      await s.putPollVote('gone', 'me', 'g', const [0], 1);
      await s.putPollVote('gone', 'me', null, const [0], 1);
      await s.addReaction('gone', '', 'y');
      List<String> done(_Db d) => [
        for (final c in d.calls)
          if (!c.startsWith('messageExists')) c,
      ];
      expect(done(v), [
        'queuePin:gone',
        'queueEdit:gone',
        'putPollVote:gone',
        'closePollRow:gone',
      ]);
      expect(done(p), [
        'queuePin:gone',
        'putPollVote:gone',
        'putPollVote:gone',
        'addReaction:gone',
      ]);
    });

    test('chat folders are the owner', () async {
      final p = _everyday();
      final v = _vault()..people = {'h': true};
      final s = await _open(p, v);
      final sep = Platform.pathSeparator;
      expect((await s.mediaDirOf('h')).path, '${docs.path}${sep}media_v');
      expect((await s.mediaDirOf('a')).path, '${docs.path}${sep}media');
      expect(
        (await s.folderOf('h', 'wallpapers')).path,
        '${docs.path}${sep}wallpapers_v',
      );
      // settings stay the primary's
      expect(s.container, HaloContainer.everyday);
    });
  });

  group('merged lists', () {
    late _Db p;
    late _Db v;
    late Session s;

    setUp(() async {
      p = _everyday();
      v = _vault()
        ..people = {'h': true, 'hr': false}
        ..groups = {'hg'};
      s = await _open(p, v);
    });

    test('contacts newest first', () async {
      p.contactRows = [
        {'halo_id': 'a', 'last_seen': 50},
        // left behind by a hide cut short: the vault's row shows
        {'halo_id': 'h', 'last_seen': 45},
        {'halo_id': 'b', 'last_seen': 10},
      ];
      v.contactRows = [
        {'halo_id': 'h', 'last_seen': 40},
        {'halo_id': 'c', 'last_seen': 30},
      ];
      // c is not a chat the vault held at open
      expect((await s.contacts()).map((r) => r['halo_id']), ['a', 'h', 'b']);
    });

    test('groups newest first', () async {
      p.groupRows = [
        {'group_id': 'g1', 'created_at': 30},
        {'group_id': 'hg', 'created_at': 25},
        {'group_id': 'g2', 'created_at': 5},
      ];
      v.groupRows = [
        {'group_id': 'hg', 'created_at': 20},
      ];
      expect((await s.loadGroups()).map((r) => r['group_id']), [
        'g1',
        'hg',
        'g2',
      ]);
    });

    test('requests and their count', () async {
      p.requests = [
        {'halo_id': 'r1', 'last_seen': 9},
        {'halo_id': 'r2', 'last_seen': 3},
      ];
      v.requests = [
        {'halo_id': 'hr', 'last_seen': 6},
      ];
      expect((await s.pendingRequests()).map((r) => r['halo_id']), [
        'r1',
        'hr',
        'r2',
      ]);
      expect(await s.pendingRequestCount(), 3);
      p.parked = [
        {'halo_id': 'x'},
      ];
      v.parked = [
        {'halo_id': 'h'},
      ];
      expect((await s.parkedRequests()).map((r) => r['halo_id']), ['x', 'h']);
    });

    test('saved newest first, 500 at most', () async {
      p.saved = [_msg('a', 100), _msg('h', 90), _msg('b', 10)];
      v.saved = [_msg('h', 95), _msg('q', 50, group: 'hg')];
      expect((await s.savedMessages()).map((r) => r['sent_at']), [
        100,
        95,
        50,
        10,
      ]);
      p.saved = [for (var i = 0; i < 400; i++) _msg('a', 2000 - i * 2)];
      v.saved = [for (var i = 0; i < 400; i++) _msg('h', 1999 - i * 2)];
      final rows = await s.savedMessages();
      expect(rows.length, 500);
      expect(rows.first['sent_at'], 2000);
      expect(rows.last['sent_at'], 1501);
    });

    test('search newest first, limit after the merge', () async {
      p.found = [_msg('a', 100), _msg('b', 30), _msg('c', 20)];
      v.found = [_msg('h', 60), _msg('x', 40, group: 'hg'), _msg('h', 25)];
      final rows = await s.searchMessages('w', SearchKind.all, limit: 4);
      expect(rows.map((r) => r['sent_at']), [100, 60, 40, 30]);
      // each side keeps its own order, arrival order included
      p.found = [_msg('a', 10), _msg('a', 30)];
      v.found = [_msg('h', 20)];
      expect(
        (await s.searchMessages('w', SearchKind.all)).map((r) => r['sent_at']),
        [20, 10, 30],
      );
    });

    test('search finds hidden rows only with the vault', () async {
      v.found = [_msg('h', 60)];
      p.found = [_msg('a', 50)];
      expect((await s.searchMessages('w', SearchKind.all)).length, 2);
      final shut = Session(p);
      expect(
        (await shut.searchMessages(
          'w',
          SearchKind.all,
        )).map((r) => r['peer_id']),
        ['a'],
      );
    });

    test('last messages from the owner', () async {
      p.lasts = {
        'a': {'sent_at': 1},
        'h': {'sent_at': 2},
      };
      v.lasts = {
        'h': {'sent_at': 3},
        'c': {'sent_at': 4},
      };
      expect(await s.lastMessages(), {
        'a': {'sent_at': 1},
        'h': {'sent_at': 3},
      });
    });

    test('vouches oldest first, one a voucher', () async {
      p.vouches = [
        {'voucher_id': 'a', 'created_at': 5},
        {'voucher_id': 'h', 'created_at': 9},
      ];
      v.vouches = [
        {'voucher_id': 'h', 'created_at': 7},
        {'voucher_id': 'b', 'created_at': 8},
      ];
      expect((await s.vouchesFor('r')).map((r) => r['voucher_id']), [
        'a',
        'h',
        'b',
      ]);
    });

    test('blocked anywhere', () async {
      p.blocked = {'x'};
      v.blocked = {'y'};
      expect(await s.blockedIds(), {'x', 'y'});
    });

    test('reactions and votes, the vault first', () async {
      p.reactions = {
        'u1': [const MapEntry('', 'a')],
        'u2': [const MapEntry('', 'b')],
      };
      v.reactions = {
        'u2': [const MapEntry('', 'c')],
      };
      final r = await s.loadReactionsFor(const ['u1', 'u2']);
      expect(r['u1']!.single.value, 'a');
      expect(r['u2']!.single.value, 'c');
      p.votes = {
        'p1': {
          'x': const PollVote([0], 1),
        },
      };
      v.votes = {
        'p1': {
          'y': const PollVote([1], 2),
        },
      };
      expect((await s.pollVotesFor(const ['p1']))['p1']!.keys, ['y']);
    });

    test('burns go in both', () async {
      await s.purgeExpiredBurns();
      expect(p.calls, ['purgeExpiredBurns']);
      expect(v.calls, ['purgeExpiredBurns']);
    });
  });
}
