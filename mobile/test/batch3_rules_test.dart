// SPDX-License-Identifier: GPL-3.0-or-later
// the batch 3 review's rules: a spoiler is offered only where every phone
// blurs one, nothing leaves a chat that blocks or a room (ours too), nothing
// timed, marked or a spoiler leaves from the files tab, a set of files
// retries the row tapped, spoilers stay blurred on the shared pages, the
// history copy carries the new columns, and the tray settles with no swing
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/history_export.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/picture_lock.dart';
import 'package:kryfo/show_in_chat.dart';
import 'package:kryfo/typing.dart';
import 'package:kryfo/widgets/send_sheet.dart';
import 'package:kryfo/widgets/send_tray.dart';
import 'package:kryfo/widgets/shared_media.dart';
import 'package:kryfo/widgets/spoiler_cover.dart';

import 'source_body.dart';

void main() {
  test('this build says it blurs spoilers', () {
    expect(kMyCaps, contains(kCapSpoilers));
    expect(kKnownCaps, contains(kCapSpoilers));
  });

  test('both chats offer spoilers only where every phone has the word', () {
    for (final (file, call) in [
      ('lib/screens/chat_screen.dart', 'spoilersFor(widget.peerHaloId)'),
      (
        'lib/screens/group_chat_screen.dart',
        'spoilersForGroup(widget.groupId)',
      ),
    ]) {
      final src = sourceOf(file);
      expect(bodyOf(src, 'Future<void> _showAttachSheet('), contains(call));
      expect(bodyOf(src, 'Future<MediaSendResult?> _preview('), contains(call));
      expect(
        bodyOf(src, 'Future<MediaSendResult?> _preview('),
        contains('spoilers: spoilers,'),
      );
    }
  });

  test('a sheet send is one bubble: no second preview, one caption, '
      'photos inside a file set', () {
    SendPick p(String n, {bool media = false}) => SendPick(
      path: '/x/$n',
      name: n,
      size: 1,
      from: SendTab.files,
      media: media,
    );
    final r = SendSheetResult([
      p('a.jpg', media: true),
      p('b.pdf'),
      p('c.zip'),
      p('d.jpg', media: true),
    ], caption: 'trip');
    expect(r.runs.map((x) => (x.media, x.picks.length)), [(false, 4)]);
    final photos = SendSheetResult([
      p('a.jpg', media: true),
      p('d.jpg', media: true),
    ]);
    expect(photos.runs.map((x) => (x.media, x.picks.length)), [(true, 2)]);
    final asFiles = SendSheetResult(r.picks, asFiles: true);
    expect(asFiles.runs.map((x) => (x.media, x.picks.length)), [(false, 4)]);
    for (final file in [
      'lib/screens/chat_screen.dart',
      'lib/screens/group_chat_screen.dart',
    ]) {
      final body = bodyOf(sourceOf(file), 'Future<void> _sendFromSheet(');
      expect(body, isNot(contains('_preview')), reason: file);
      expect(body, isNot(contains('sendGalleryPicks')), reason: file);
      expect(body, contains('for (final run in r.runs)'), reason: file);
      expect(body, contains("caption = '';"), reason: file);
    }
  });

  test('menus keep ours in a chat that blocks, and in a room', () {
    expect(
      sourceOf('lib/screens/chat_screen.dart'),
      contains('final kept = theirsKept || _shots.blocking;'),
    );
    expect(
      sourceOf('lib/screens/group_chat_screen.dart'),
      contains('final kept = theirsKept || _isRoom || _shots.blocking;'),
    );
  });

  test('a set of files retries only the row tapped', () {
    expect(
      sourceOf('lib/screens/chat_screen.dart'),
      contains('onRetry: run == null || run.tag.files\n'),
    );
  });

  test('the history copy carries spoilers and each chat\'s timer', () {
    expect(kHistoryMessageCols, contains('spoiler'));
    expect(kHistoryContactCols, contains('chat_burn'));
    expect(kHistoryGroupCols, contains('chat_burn'));
  });

  test('the tray\'s spring never swings past the end', () {
    var last = 0.0;
    for (var i = 0; i <= 100; i++) {
      final v = kCalmSpring.transform(i / 100);
      expect(v, lessThanOrEqualTo(1.0 + 1e-9));
      expect(v, greaterThanOrEqualTo(last - 1e-9));
      last = v;
    }
    expect(kCalmSpring.transform(1), closeTo(1, 1e-9));
  });

  group('the files tab', () {
    setUp(() {
      chatShown('p');
      openPictures();
      forgetSpoilersForTest();
    });
    tearDown(() => chatGone('p'));

    Future<void> menu(
      WidgetTester t,
      SharedItem it, {
      bool blocking = false,
      bool room = false,
    }) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          home: SharedScreen(
            chatId: 'p',
            title: 'Lena',
            group: room,
            blocking: blocking || room,
            room: room,
            hidden: false,
            start: SharedTab.files,
            load: () async => SharedLists(files: [it]),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      await t.longPress(find.text('route'));
      await t.pumpAndSettle();
    }

    final when = DateTime(2025, 11, 9);
    SharedItem file({
      bool mine = true,
      bool timed = false,
      bool secure = false,
    }) => SharedItem(
      path: '/f/route.pdf',
      name: 'route.pdf',
      uid: 'u1',
      mine: mine,
      timed: timed,
      secure: secure,
      when: when,
    );

    void none(WidgetTester t) {
      expect(find.text(l10n.filesOpen), findsOneWidget);
      expect(find.text(l10n.chatForward), findsNothing);
      expect(find.text(l10n.fileSaveToDevice), findsNothing);
    }

    testWidgets('ours, in an everyday chat, goes', (t) async {
      await menu(t, file());
      expect(find.text(l10n.chatForward), findsOneWidget);
      expect(find.text(l10n.fileSaveToDevice), findsOneWidget);
    });

    testWidgets('ours, in a chat that blocks, stays', (t) async {
      await menu(t, file(), blocking: true);
      none(t);
    });

    testWidgets('ours, in a burner room, stays', (t) async {
      await menu(t, file(), room: true);
      none(t);
    });

    testWidgets('a timed one, ours or read, stays', (t) async {
      await menu(t, file(timed: true));
      none(t);
    });

    testWidgets('a marked one stays', (t) async {
      await menu(t, file(mine: false, secure: true));
      none(t);
    });
  });

  testWidgets('a spoiler in the shared grid is blurred until tapped', (
    t,
  ) async {
    openPictures();
    forgetSpoilersForTest();
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SharedPhotoGrid(
            paths: ['/m/a.jpg', '/m/b.jpg'],
            spoilers: {'/m/b.jpg': 'u2'},
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    final covers = t.widgetList<SpoilerCover>(find.byType(SpoilerCover));
    expect(covers.where((c) => c.on).map((c) => c.uid), ['u2']);
    expect(find.byType(ImageFiltered), findsOneWidget);
  });

  testWidgets('the shared section holds its place while it is read', (t) async {
    Future<double> height(bool loaded) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SharedMediaSection(
                key: ValueKey(loaded),
                paths: loaded ? ['/m/a.jpg'] : const [],
                count: loaded ? 1 : 0,
                loaded: loaded,
                files: 2,
                voice: 1,
                links: 3,
              ),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 500));
      return t.getSize(find.byType(SharedMediaSection)).height;
    }

    final reading = await height(false);
    final read = await height(true);
    expect((reading - read).abs(), lessThan(8));
  });
}
