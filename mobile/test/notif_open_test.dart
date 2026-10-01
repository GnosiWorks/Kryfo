// SPDX-License-Identifier: GPL-3.0-or-later
// a tapped notification opens what it rang for: a group or room by its
// 'group:<id>' payload, a request on the requests screen, an accepted chat
// as itself. what is gone, blocked or not this session's opens nothing
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show
        NotifChat,
        NotifGroup,
        NotifRequests,
        notifTargetFor,
        useDatabasesForTest;
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
}
