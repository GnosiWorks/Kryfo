// SPDX-License-Identifier: GPL-3.0-or-later
// a kryfo link from another app, a web page or a cold start asks before it
// adds or joins anything, never under the lock, and a no changes nothing.
// an invite's id has to be three words and is held up against the people
// here, and a room's name is cleaned before it is shown. the door the link
// would go through is a stand-in that counts its calls
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/main.dart' show LinkKin;
import 'package:kryfo/rooms.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/kryfo_link_text.dart';

const _invite =
    'kryfo://share?id=tourist-admit-sun&onion=abcdefghijklmnop.onion'
    '&v=3&bundle=QUJDRA';

String _room({int hours = 2, String name = 'Night shift'}) => RoomLink(
  roomId: 'room-one',
  name: name,
  expiresAt: DateTime.now().add(Duration(hours: hours)).millisecondsSinceEpoch,
  creatorPub: 'a' * 64,
  fcPk: 'b' * 64,
).encode();

class _Door {
  final taken = <String>[];
  Future<String> call(String link) async {
    taken.add(link);
    return 'done';
  }
}

class _World {
  var locked = false;
  late final guard = LockGuard(isLocked: () => locked);
  final door = _Door();
  late BuildContext ctx;
  String? result;
  var finished = false;
  // what the invite's id is to the people here
  (LinkKin, String) kin = (LinkKin.stranger, '');
  final kinAsked = <String>[];

  Future<void> start(WidgetTester t) async {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    await t.pumpWidget(
      MaterialApp(
        theme: buildHaloTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold();
          },
        ),
      ),
    );
  }

  Future<void> open(WidgetTester t, String raw, {String? selfId}) async {
    finished = false;
    result = null;
    takeOutsideLink(
      ctx,
      raw,
      guard: guard,
      act: door.call,
      kin: (link) async {
        kinAsked.add(link);
        return kin;
      },
      selfId: selfId,
    ).then((r) {
      result = r;
      finished = true;
    });
    await t.pumpAndSettle();
  }
}

void main() {
  testWidgets('an invite from outside asks first, and a no adds no one', (
    t,
  ) async {
    final w = _World();
    await w.start(t);
    await w.open(t, _invite);
    expect(find.text(l10n.kryfoLinkTextAdd('tourist-admit-sun')), findsOne);
    expect(
      find.text(l10n.kryfoLinkTextThisIsAnInvite('tourist-admit-sun')),
      findsOne,
    );
    expect(w.door.taken, isEmpty, reason: 'nothing before the answer');
    await t.tap(find.text(l10n.kryfoLinkTextNotNow));
    await t.pumpAndSettle();
    expect(w.finished, isTrue);
    expect(w.result, isNull);
    expect(w.door.taken, isEmpty);

    await w.open(t, _invite);
    await t.tap(find.text(l10n.kryfoLinkTextAddThem));
    await t.pumpAndSettle();
    expect(w.door.taken, [_invite]);
    expect(w.result, 'done');
  });

  testWidgets('a room link from outside asks before it joins', (t) async {
    final w = _World();
    await w.start(t);
    final link = _room();
    await w.open(t, link);
    expect(find.text(l10n.kryfoLinkTextJoinRoom('Night shift')), findsOne);
    expect(find.text(l10n.kryfoLinkTextThisIsARoom), findsOne);
    expect(w.door.taken, isEmpty);
    await t.tap(find.text(l10n.kryfoLinkTextNotNow));
    await t.pumpAndSettle();
    expect(w.door.taken, isEmpty);

    await w.open(t, link);
    await t.tap(find.text(l10n.kryfoLinkTextJoin2));
    await t.pumpAndSettle();
    expect(w.door.taken, [link]);
  });

  testWidgets('a tap beside the sheet is a no', (t) async {
    final w = _World();
    await w.start(t);
    await w.open(t, _invite);
    await t.tapAt(const Offset(20, 20));
    await t.pumpAndSettle();
    expect(w.finished, isTrue);
    expect(w.door.taken, isEmpty);
  });

  testWidgets('the question goes as the lock comes up, and adds no one', (
    t,
  ) async {
    final w = _World();
    await w.start(t);
    await w.open(t, _invite);
    expect(find.text(l10n.kryfoLinkTextAddThem), findsOne);
    w.locked = true;
    w.guard.locking();
    await t.pumpAndSettle();
    expect(find.text(l10n.kryfoLinkTextAddThem), findsNothing);
    expect(w.finished, isTrue);
    expect(w.result, isNull);
    expect(w.door.taken, isEmpty);
  });

  testWidgets('under the lock nothing is asked and nothing taken', (t) async {
    final w = _World();
    await w.start(t);
    w.locked = true;
    await w.open(t, _invite);
    expect(find.text(l10n.kryfoLinkTextAddThem), findsNothing);
    expect(w.finished, isTrue);
    expect(w.door.taken, isEmpty);
  });

  testWidgets('what the door cannot read never reaches it', (t) async {
    final w = _World();
    await w.start(t);
    for (final raw in [
      'kryfo://share?onion=x.onion',
      'kryfo://pair?code=123',
      'kryfo://room?id=x',
      'not a link',
    ]) {
      await w.open(t, raw);
      expect(w.result, l10n.kryfoLinkTextThatLinkIsNot, reason: raw);
    }
    expect(find.text(l10n.kryfoLinkTextAddThem), findsNothing);
    expect(w.door.taken, isEmpty);
  });

  testWidgets('the question is about the link the door would take', (t) async {
    final w = _World();
    await w.start(t);
    // words around it, or a second link behind it, do not change who it adds
    await w.open(t, 'kryfo://x?$_invite kryfo://share?id=other-name-here');
    expect(find.text(l10n.kryfoLinkTextAdd('tourist-admit-sun')), findsOne);
    await t.tap(find.text(l10n.kryfoLinkTextAddThem));
    await t.pumpAndSettle();
    expect(w.door.taken, [_invite]);
  });

  testWidgets('one\'s own invite and a closed room have nothing to ask', (
    t,
  ) async {
    final w = _World();
    await w.start(t);
    await w.open(t, _invite, selfId: 'tourist-admit-sun');
    expect(find.text(l10n.kryfoLinkTextAddThem), findsNothing);
    final closed = _room(hours: -1);
    await w.open(t, closed);
    expect(find.text(l10n.kryfoLinkTextJoin2), findsNothing);
    // the door says what it is and adds or joins nothing for either
    expect(w.door.taken, [_invite, closed]);
  });

  test('every link from outside goes through the question', () {
    final app = File('lib/main.dart').readAsStringSync();
    final stream = RegExp(
      r'uriLinkStream\.listen\(\(uri\) async \{([\s\S]*?)\n    \}\);',
    ).firstMatch(app)?.group(1);
    final cold = RegExp(
      r'getInitialLink\(\)([\s\S]*?)\.catchError',
    ).firstMatch(app)?.group(1);
    for (final body in [stream, cold]) {
      expect(body, isNotNull);
      expect(body, contains('_outsideLink(uri'));
      expect(body, isNot(contains('handleHaloUri')));
    }
    final outside = RegExp(
      r'Future<void> _outsideLink\(Uri uri, String how\) =>([\s\S]*?)\n      \}\);',
    ).firstMatch(app)?.group(1);
    expect(outside, isNotNull);
    expect(outside, contains('lockGuard.afterUnlock'));
    // of those held under the lock, only the latest
    expect(outside, contains("slot: 'outside-link'"));
    expect(outside, contains('takeOutsideLink('));
    expect(outside, isNot(contains('handleHaloUri')));
  });

  testWidgets('one already in the chats, on the same key, is said so and '
      'nothing is added', (t) async {
    final w = _World()..kin = (LinkKin.kept, 'Ana');
    await w.start(t);
    await w.open(t, _invite);
    expect(w.kinAsked, [_invite]);
    expect(find.text(l10n.kryfoLinkTextAddThem), findsNothing);
    expect(w.result, l10n.kryfoLinkTextYouAlreadyHave('Ana'));
    expect(w.door.taken, isEmpty);
  });

  testWidgets('a contact\'s words on another key are never shown as them, '
      'and add no one', (t) async {
    final w = _World()..kin = (LinkKin.otherKey, 'Ana');
    await w.start(t);
    await w.open(t, _invite);
    expect(find.text(l10n.kryfoLinkTextNotTheOne('Ana')), findsOne);
    expect(find.text(l10n.appLinkOtherKey('tourist-admit-sun')), findsOne);
    expect(find.text(l10n.kryfoLinkTextAddThem), findsNothing);
    await t.tap(find.text(l10n.appOk));
    await t.pumpAndSettle();
    expect(w.finished, isTrue);
    expect(w.result, isNull);
    expect(w.door.taken, isEmpty);
  });

  testWidgets('words someone here is called by are asked about as someone '
      'else', (t) async {
    final w = _World()..kin = (LinkKin.lookalike, 'tourist-admit-sun');
    await w.start(t);
    await w.open(t, _invite);
    expect(find.text(l10n.kryfoLinkTextAdd('tourist-admit-sun')), findsOne);
    expect(
      find.text(l10n.kryfoLinkTextSomeoneElse('tourist-admit-sun')),
      findsOne,
    );
    await t.tap(find.text(l10n.kryfoLinkTextAddThem));
    await t.pumpAndSettle();
    expect(w.door.taken, [_invite]);
  });

  testWidgets('an id that is not three words is no invite', (t) async {
    final w = _World();
    await w.start(t);
    for (final id in [
      'Tourist-admit-sun',
      'tourist-admit-\u202Enus',
      'a b c',
    ]) {
      await w.open(
        t,
        'kryfo://share?id=${Uri.encodeQueryComponent(id)}'
        '&onion=abcdefghijklmnop.onion&v=3&bundle=QUJDRA',
      );
      expect(w.result, l10n.kryfoLinkTextThatLinkIsNot, reason: id);
    }
    expect(w.kinAsked, isEmpty);
    expect(w.door.taken, isEmpty);
  });

  testWidgets('a room\'s name is shown without controls, on one line, cut '
      'short, under a title of two lines at most', (t) async {
    final w = _World();
    await w.start(t);
    final long = 'Night\u202E shift\n\t\u200Bcrew ${'x' * 80}';
    await w.open(t, _room(name: long));
    final shown = 'Night shift crew ${'x' * 31}';
    expect(roomLinkName(long), shown);
    final title = find.text(l10n.kryfoLinkTextJoinRoom(shown));
    expect(title, findsOne);
    final text = t.widget<Text>(title);
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
    await t.tap(find.text(l10n.kryfoLinkTextNotNow));
    await t.pumpAndSettle();
    // the invite's question is held to two lines too
    await w.open(t, _invite);
    expect(
      t
          .widget<Text>(find.text(l10n.kryfoLinkTextAdd('tourist-admit-sun')))
          .maxLines,
      2,
    );
  });
}
