// SPDX-License-Identifier: GPL-3.0-or-later
// the album on screen: its grid for each count, with a place held for what
// is still coming and the grid mirrored right to left; the viewer, which
// opens at the tile tapped, counts and swipes in album order, plays a video
// where it is, and with no movement asked for fades instead of flying
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/widgets/album_grid.dart';
import 'package:kryfo/widgets/album_viewer.dart';

import 'pin_flow_fakes.dart' show app, phone;

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAQAAAADCAIAAAA7ljmRAAAAEElEQVR4nGP4Oo8bjhhwcgCFmhNpSPXr6AAAAABJRU5ErkJggg==',
);

void quiet(WidgetTester t, {List<String>? video}) {
  final m = t.binding.defaultBinaryMessenger;
  const secure = MethodChannel('halo/platform');
  const player = MethodChannel('kryfo/video');
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  m.setMockMethodCallHandler(secure, (_) async => null);
  m.setMockMethodCallHandler(player, (c) async {
    video?.add(c.method);
    return switch (c.method) {
      'open' => {'id': 7, 'w': 640, 'h': 360, 'ms': 4000},
      'state' => {'ms': 0, 'playing': true, 'done': false},
      _ => null,
    };
  });
  addTearDown(() {
    m.setMockMethodCallHandler(SystemChannels.platform, null);
    m.setMockMethodCallHandler(secure, null);
    m.setMockMethodCallHandler(player, null);
  });
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('album_widgets'));
  tearDown(() => dir.deleteSync(recursive: true));

  String photo(String name) =>
      (File('${dir.path}/$name.png')..writeAsBytesSync(_png)).path;

  List<AlbumTile?> tiles(int n) => [
    for (var i = 0; i < n; i++) AlbumTile(path: photo('p$i')),
  ];

  Future<void> grid(
    WidgetTester t,
    List<AlbumTile?> tiles, {
    TextDirection dir = TextDirection.ltr,
    void Function(int)? onOpen,
  }) async {
    quiet(t);
    await t.pumpWidget(
      app(
        Directionality(
          textDirection: dir,
          child: Scaffold(
            body: Center(
              child: AlbumGrid(tiles: tiles, width: 300, onOpen: onOpen),
            ),
          ),
        ),
      ),
    );
    await t.pump();
  }

  Rect cell(WidgetTester t, int slot) => t.getRect(
    find.descendant(
      of: find.byType(AlbumGrid),
      matching: find.byKey(ValueKey(slot)),
    ),
  );

  group('the grid', () {
    testWidgets('two, three and four show every item', (t) async {
      for (final n in [2, 3, 4]) {
        await grid(t, tiles(n));
        for (var i = 0; i < n; i++) {
          expect(cell(t, i).width, greaterThan(0), reason: '$n $i');
        }
        expect(find.textContaining('+'), findsNothing);
      }
    });

    testWidgets('more shows four, the last counting the rest', (t) async {
      await grid(t, tiles(7));
      expect(find.byKey(const ValueKey(4)), findsNothing);
      expect(find.text('+3'), findsOneWidget);
      await grid(t, tiles(10));
      expect(find.text('+6'), findsOneWidget);
    });

    testWidgets('a place still coming holds its tile, and nothing moves '
        'when it lands', (t) async {
      await grid(t, [null, AlbumTile(path: photo('a')), null]);
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      final before = t.getSize(find.byType(AlbumGrid));
      final cells = [for (var i = 0; i < 3; i++) cell(t, i)];
      await grid(t, tiles(3));
      expect(t.getSize(find.byType(AlbumGrid)), before);
      expect([for (var i = 0; i < 3; i++) cell(t, i)], cells);
    });

    testWidgets('right to left, the first item is on the right', (t) async {
      await grid(t, tiles(2));
      expect(cell(t, 0).left, lessThan(cell(t, 1).left));
      await grid(t, tiles(2), dir: TextDirection.rtl);
      expect(cell(t, 0).left, greaterThan(cell(t, 1).left));
      await grid(t, tiles(3), dir: TextDirection.rtl);
      expect(cell(t, 0).left, greaterThan(cell(t, 1).left));
    });

    testWidgets('a video shows its play mark, a tap opens its place', (
      t,
    ) async {
      final opened = <int>[];
      await grid(t, [
        AlbumTile(path: photo('a')),
        AlbumTile(path: '${dir.path}/v.mp4', video: true),
      ], onOpen: opened.add);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      await t.tap(find.byKey(const ValueKey(1)));
      await t.pump(const Duration(milliseconds: 200));
      expect(opened, [1]);
    });

    testWidgets('a screen reader hears each place and the album', (t) async {
      final h = t.ensureSemantics();
      await grid(t, [AlbumTile(path: photo('a')), null, null, null, null]);
      expect(find.bySemanticsLabel(RegExp('Album, 5 items')), findsOneWidget);
      expect(find.bySemanticsLabel('Photo, 1 of 5'), findsOneWidget);
      expect(find.bySemanticsLabel('On its way, 2 of 5'), findsOneWidget);
      h.dispose();
    });
  });

  group('the viewer', () {
    Future<void> open(
      WidgetTester t,
      List<AlbumItem> items, {
      int start = 0,
      bool still = false,
      TextDirection dir = TextDirection.ltr,
      List<String>? video,
    }) async {
      phone(t);
      quiet(t, video: video);
      lockState.openForTest();
      // a right-to-left language, so the pages the viewer pushes are too
      await t.pumpWidget(
        app(
          Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => openAlbum(ctx, items, start: start),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          still: still,
          locale: dir == TextDirection.rtl
              ? const Locale('ar')
              : const Locale('en'),
        ),
      );
      await t.tap(find.text('open'));
      // the decode wait gives up after 300 ms; then the page comes
      await t.pump(const Duration(milliseconds: 350));
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
    }

    List<AlbumItem> three() => [
      AlbumItem(photo('a')),
      AlbumItem(photo('b')),
      AlbumItem(photo('c')),
    ];

    // a swipe past half the page: one page on
    Future<void> swipe(WidgetTester t, double dx) async {
      await t.drag(find.byType(PageView), Offset(dx.sign * 250, 0));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
    }

    int at(WidgetTester t) =>
        t.state<AlbumViewerState>(find.byType(AlbumViewer)).at;

    testWidgets('opens at the tile tapped and counts in album order', (
      t,
    ) async {
      await open(t, three(), start: 1);
      expect(find.text('2 of 3'), findsOneWidget);
      expect(at(t), 1);
      await swipe(t, -500);
      expect(find.text('3 of 3'), findsOneWidget);
      // the last is the last
      await swipe(t, -500);
      expect(at(t), 2);
      await swipe(t, 500);
      await swipe(t, 500);
      expect(find.text('1 of 3'), findsOneWidget);
      // the close button takes it back
      await t.tap(find.byIcon(Icons.close_rounded));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(AlbumViewer), findsNothing);
    });

    testWidgets('right to left, the next one is a swipe the other way', (
      t,
    ) async {
      await open(t, three(), dir: TextDirection.rtl);
      expect(at(t), 0);
      await swipe(t, -500);
      expect(at(t), 0);
      await swipe(t, 500);
      expect(at(t), 1);
    });

    testWidgets('it flies from its tile, or fades with reduced motion', (
      t,
    ) async {
      Finder hero() => find.descendant(
        of: find.byType(AlbumViewer),
        matching: find.byType(Hero),
      );
      await open(t, three());
      expect(hero(), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await open(t, three(), still: true);
      expect(find.byType(AlbumViewer), findsOneWidget);
      expect(hero(), findsNothing);
    });

    testWidgets('a video plays where it is, and stops when swiped from', (
      t,
    ) async {
      final calls = <String>[];
      await open(t, [
        AlbumItem(photo('a')),
        AlbumItem('${dir.path}/v.mp4', video: true),
      ], video: calls);
      expect(calls, isNot(contains('open')));
      await swipe(t, -500);
      expect(find.text('2 of 2'), findsOneWidget);
      expect(calls, containsAllInOrder(['open', 'play']));
      expect(find.byType(Texture), findsOneWidget);
      // swiped from, it stops: paused, or let go as its page goes
      await swipe(t, 500);
      expect(calls.where((c) => c == 'pause' || c == 'close'), isNotEmpty);
      expect(calls.lastIndexOf('play'), lessThan(calls.length - 1));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
      expect(calls, contains('close'));
    });
  });
}
