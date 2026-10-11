// SPDX-License-Identifier: GPL-3.0-or-later
// a tapped notification opens what it rang for: a group or room by its
// 'group:<id>' payload, a request on the requests screen, an accepted chat
// as itself. what is gone, blocked or not this session's opens nothing. the
// tap carries a random tag, read back to its chat in the session's own
// containers only
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show
        NotifChat,
        NotifGroup,
        NotifRequests,
        notifChatFor,
        notifTargetFor,
        useDatabasesForTest;
import 'package:kryfo/devchat/support.dart' show kSupportPayload;
import 'package:kryfo/session.dart';

import 'arrival_fakes.dart';

void main() {
  late ArrivalRows live;

  setUp(() {
    live = ArrivalRows(HaloContainer.everyday)
      ..person('friend-of-mine')
      ..person('new-face-here', accepted: 0)
      ..person('gone-quiet-one', accepted: 0)
      ..group('grp000000001', ['me', 'friend-of-mine']);
    live.people['gone-quiet-one']!['blocked'] = 1;
    useDatabasesForTest(live, Session(live));
  });

  test('a group or room opens by its id', () async {
    final t = await notifTargetFor('group:grp000000001');
    expect(t, isA<NotifGroup>());
    expect((t as NotifGroup).groupId, 'grp000000001');
  });

  test('a group no longer here opens nothing', () async {
    expect(await notifTargetFor('group:grp000000009'), isNull);
    expect(await notifTargetFor('group:'), isNull);
  });

  test('a request opens the requests', () async {
    expect(await notifTargetFor('new-face-here'), isA<NotifRequests>());
  });

  test('a deleted chat opens nothing until they write again', () async {
    live.person('let-go-before', accepted: 0, archived: 1);
    expect(await notifTargetFor('let-go-before'), isNull);
  });

  test('an accepted chat opens as itself', () async {
    final t = await notifTargetFor('friend-of-mine');
    expect(t, isA<NotifChat>());
    expect((t as NotifChat).row['halo_id'], 'friend-of-mine');
  });

  test('someone blocked or unknown opens nothing', () async {
    expect(await notifTargetFor('gone-quiet-one'), isNull);
    expect(await notifTargetFor('never-seen-before'), isNull);
  });

  test('the decoy open: an everyday group opens nothing', () async {
    final decoy = ArrivalRows(HaloContainer.decoy);
    useDatabasesForTest(live, Session(decoy));
    expect(await notifTargetFor('group:grp000000001'), isNull);
    expect(await notifTargetFor('new-face-here'), isNull);
  });

  group('a tapped tag', () {
    test('names the chat it was made for, in its container', () async {
      final tag = await live.notifTag('group:grp000000001');
      expect(tag, isNot(contains('grp000000001')));
      expect(await notifChatFor(tag), 'group:grp000000001');
      expect(await notifChatFor('no-such-tag'), isNull);
    });

    test('the support inbox opens by its own payload', () async {
      expect(await notifChatFor(kSupportPayload), kSupportPayload);
    });

    test('the decoy open: an everyday tag names nothing', () async {
      final tag = await live.notifTag('friend-of-mine');
      final decoy = ArrivalRows(HaloContainer.decoy);
      useDatabasesForTest(live, Session(decoy));
      expect(await notifChatFor(tag), isNull);
    });

    test('a hidden chat\'s tag only while its vault is open', () async {
      final vault = ArrivalRows(HaloContainer.vault)
        ..person('hidden-friend-one');
      final tag = await vault.notifTag('hidden-friend-one');
      useDatabasesForTest(live, await Session.withVault(live, vault));
      expect(await notifChatFor(tag), 'hidden-friend-one');
      final open = await Session.withVault(live, vault);
      expect(await open.notifTagsOf('hidden-friend-one'), {tag});
      // shut: its file is closed, and the session after has no vault
      vault.shut = true;
      useDatabasesForTest(live, await Session.withVault(live, vault));
      expect(await notifChatFor(tag), isNull);
      useDatabasesForTest(live, Session(live));
      expect(await notifChatFor(tag), isNull);
    });

    test('a chat\'s tags in each container open', () async {
      final vault = ArrivalRows(HaloContainer.vault);
      final a = await live.notifTag('friend-of-mine');
      final b = await vault.notifTag('friend-of-mine');
      final s = await Session.withVault(live, vault);
      expect(await s.notifTagsOf('friend-of-mine'), {a, b});
      expect(await s.notifTagsOf('never-seen-before'), isEmpty);
    });
  });
}
