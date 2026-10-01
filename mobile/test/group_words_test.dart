// SPDX-License-Identifier: GPL-3.0-or-later
// what groups and rooms say, in the language on screen: the member cap, an
// unnamed room, the leave sheet's line for each role, a room key's name and
// who the @ picker offers
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show AppState, GroupFull, useDatabasesForTest;
import 'package:kryfo/mentions.dart';
import 'package:kryfo/rooms.dart';
import 'package:kryfo/screens/group_info_screen.dart'
    show leaveLine, memberLabel;
import 'package:kryfo/session.dart';

import 'arrival_fakes.dart';

final _key = 'c0ffee' * 10 + 'beef';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => setL10nLocale(const Locale('en')));

  group('the member cap', () {
    late AppState app;
    setUp(() {
      final live = ArrivalRows(HaloContainer.everyday)
        ..group('grp000000001', ['me', 'one-two-three']);
      live.groupRows['grp000000001']!['is_admin'] = 1;
      useDatabasesForTest(live, Session(live));
      app = AppState()..myId = 'me';
    });

    List<String> ids(int n) => [for (var i = 0; i < n; i++) 'id-$i'];

    test('a new group past it is turned down in the screen\'s words', () async {
      setL10nLocale(const Locale('de'));
      await expectLater(
        app.createGroupAndAnnounce('big', ids(AppState.kGroupMemberCap)),
        throwsA(
          isA<GroupFull>().having(
            (e) => e.message,
            'message',
            l10n.appGroupHoldsUpTo(AppState.kGroupMemberCap),
          ),
        ),
      );
      expect(
        const GroupFull().message,
        'In eine Gruppe passen höchstens 50 Personen',
      );
    });

    test('adding past it is turned down the same way', () async {
      await expectLater(
        app.addMembersToGroup(
          'grp000000001',
          ids(AppState.kGroupMemberCap - 1),
        ),
        throwsA(isA<GroupFull>()),
      );
    });

    test('the number is the language\'s own', () {
      setL10nLocale(const Locale('fa'));
      expect(const GroupFull().message, contains('۵۰'));
    });
  });

  test('a link with no room name names it in the screen\'s words', () {
    final link = RoomLink(
      roomId: 'room00000001',
      name: '',
      expiresAt: 9999999999999,
      creatorPub: _key,
      fcPk: _key,
      cap: null,
    ).encode();
    setL10nLocale(const Locale('de'));
    expect(RoomLink.parse(link)!.name, 'Raum');
    setL10nLocale(const Locale('en'));
    expect(RoomLink.parse(link)!.name, 'Room');
  });

  test('an uncapped room says where it stops', () {
    expect(
      l10n.roomCreateOffUpTo(AppState.kGroupMemberCap),
      'Off. Anyone with the link, up to 50',
    );
  });

  group('the leave sheet', () {
    test('a member is told the group goes from this phone', () {
      final s = leaveLine(room: false, admin: false);
      expect(s, l10n.groupInfoLeaveGroupLine);
      expect(s, isNot(contains('see you leave')));
    });

    test('the admin is told no one can change it after', () {
      expect(
        leaveLine(room: false, admin: true),
        l10n.groupInfoLeaveGroupAdmin,
      );
    });

    test('a room\'s maker is told its link stops letting anyone in', () {
      expect(leaveLine(room: true, admin: true), l10n.groupInfoLeaveRoomMaker);
      expect(
        leaveLine(room: true, admin: false),
        l10n.groupInfoEverythingInItIs,
      );
    });
  });

  test('a room key goes by its short tag, a person by their words', () {
    expect(memberLabel(_key), roomTag(_key));
    expect(memberLabel(_key), hasLength(6));
    expect(memberLabel('one-two-three'), 'one-two-three');
  });

  group('the @ picker', () {
    test('offers the other members of a group', () {
      final m = mentionable(
        ['me-me-me', 'one-two-three', 'four-five-six'],
        me: 'me-me-me',
        room: false,
        names: {'one-two-three': 'Ana'},
      );
      expect(m.map((c) => c.id), ['one-two-three', 'four-five-six']);
      expect(m.first.name, 'Ana');
    });

    test('offers no one in a room, its keys are not mentions', () {
      expect(mentionable([_key, 'c' * 64], me: _key, room: true), isEmpty);
    });
  });
}
