// SPDX-License-Identifier: GPL-3.0-or-later
// files sent together are one bubble: they travel under their own field,
// which a phone before them reads past, they are kept apart from photo
// albums, and the bubble draws a row each: a tile that brings one still
// waiting, "Get all" for the rest, a retry for one that did not go, and
// nothing that ever comes on its own
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/album.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/media_progress.dart';
import 'package:kryfo/transfers.dart';
import 'package:kryfo/widgets/file_bubble.dart';
import 'package:kryfo/widgets/file_stack.dart';
import 'package:kryfo/widgets/file_wait.dart';

import 'old_wire/envelope_051.dart' as v051;

class Item {
  final String who;
  final AlbumTag? tag;
  final bool media;
  final bool file;
  final int at;
  const Item(this.who, this.tag, {this.media = false, this.file = true})
    : at = 0;
}

void main() {
  group('the wire and the row', () {
    test('a set goes under fa, an album under al', () {
      const set = AlbumTag('0123456789abcdef', 3, 1, files: true);
      const album = AlbumTag('0123456789abcdef', 3, 1);
      expect(set.wireKey, kFileSetWire);
      expect(album.wireKey, 'al');
      expect(AlbumTag.fromWire(set.toWire(), files: true), set);
      expect(AlbumTag.fromWire(album.toWire()), album);
      expect(set == album, isFalse);
    });

    test('a set is kept with its own mark, and read back as one', () {
      const set = AlbumTag('0123456789abcdef', 2, 0, files: true);
      final row = set.toRow();
      expect(row['album_id'], 'f:0123456789abcdef');
      expect(set.rowId, 'f:0123456789abcdef');
      expect(AlbumTag.ofRow(row), set);
      const album = AlbumTag('0123456789abcdef', 2, 0);
      expect(AlbumTag.ofRow(album.toRow()), album);
    });

    test('an id that says it is a set is no album on the wire', () {
      expect(
        AlbumTag.fromWire({'id': 'f:0123456789abcdef', 'n': 2, 'i': 0}),
        isNull,
      );
    });

    test('the envelope carries fa and reads it back as a set', () async {
      const set = AlbumTag('aaaaaaaaaaaaaaaa', 2, 1, files: true);
      final w = await wrapMessage('', msgUid: 'u1', album: set);
      final body = jsonDecode(w.substring('halo/1:'.length)) as Map;
      expect(body['fa'], {'id': 'aaaaaaaaaaaaaaaa', 'n': 2, 'i': 1});
      expect(body.containsKey('al'), isFalse);
      // 'fs' is the face signature's: a set never takes it
      expect(body.containsKey('fs'), isFalse);
      expect(unwrapMessage(w).album, set);
      // a phone before sets reads past it: the file stands alone there
      expect(v051.unwrapMessage(w).toString().contains("files"), isFalse);
    });

    test('a plan for files marks each place as a set', () {
      final plan = albumPlan(['a', 'b', 'c'], 'words', files: true);
      expect(plan.map((x) => x.album!.files), everyElement(isTrue));
      expect(plan.first.caption, 'words');
      expect(plan.skip(1).map((x) => x.caption), everyElement(''));
      // to someone not accepted yet each goes alone
      final alone = albumPlan(['a', 'b'], '', files: true, alone: true);
      expect(alone.map((x) => x.album), everyElement(isNull));
    });
  });

  group('the index', () {
    AlbumIndex<Item> index(List<Item> rows) => AlbumIndex<Item>(
      rows,
      tag: (r) => r.tag,
      owner: (r) => r.who,
      media: (r) => r.media,
      written: (r) => r.at,
      file: (r) => r.file,
    );

    test('a set holds files, an album only photos and videos', () {
      const s = 'bbbbbbbbbbbbbbbb';
      final a = Item('x', const AlbumTag(s, 2, 0, files: true));
      final b = Item('x', const AlbumTag(s, 2, 1, files: true));
      final ix = index([a, b]);
      expect(ix.runOf(a), isNotNull);
      expect(ix.runOf(a), same(ix.runOf(b)));
      expect(ix.runOf(a)!.tag.files, isTrue);
      expect(ix.hidden(b), isTrue);
    });

    test('a set and an album of one id never share a bubble', () {
      const s = 'cccccccccccccccc';
      final photo = Item('x', const AlbumTag(s, 2, 0), media: true);
      final file = Item('x', const AlbumTag(s, 2, 1, files: true));
      final ix = index([photo, file]);
      expect(ix.runOf(photo), isNot(same(ix.runOf(file))));
    });

    test('words or a voice note tagged as a set stand alone', () {
      const s = 'dddddddddddddddd';
      final words = Item(
        'x',
        const AlbumTag(s, 2, 0, files: true),
        file: false,
      );
      expect(index([words]).runOf(words), isNull);
    });
  });

  group('the bubble', () {
    setUp(() => fileWaits.value = const {});
    tearDown(() => fileWaits.value = const {});

    Widget host(Widget child, {bool still = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Scaffold(body: Center(child: child)),
      ),
    );

    FileStackRow ready(String id, String name) =>
        FileStackRow(id: id, name: name, ready: () => Text('here $name'));

    testWidgets('one waiting shows the tile and until when, never comes on '
        'its own', (t) async {
      final got = <String>[];
      setFileWait(
        'u1',
        const FileWait(
          size: 48 * 1024,
          state: WaitState.asks,
          rule: AutoGet.never,
        ),
      );
      await t.pumpWidget(
        host(
          FileStack(
            isOut: false,
            onGet: got.add,
            onPause: (_) {},
            rows: [
              ready('u0', 'route.pdf'),
              FileStackRow(
                id: 'u1',
                name: 'gear-list.xlsx',
                waitUid: 'u1',
                until: DateTime(2026, 12, 9),
                ready: () => const Text('here gear'),
              ),
            ],
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('here route.pdf'), findsOneWidget);
      expect(find.text('here gear'), findsNothing);
      expect(find.byType(FileWaitMark), findsOneWidget);
      expect(find.textContaining('until'), findsOneWidget);
      // one alone waiting: no "Get all"
      expect(find.textContaining('Get all'), findsNothing);
      expect(got, isEmpty);
      await t.tap(find.byType(FileWaitMark));
      await t.pump(const Duration(milliseconds: 300));
      expect(got, ['u1']);
    });

    testWidgets('get all brings every one waiting, then counts them in', (
      t,
    ) async {
      final got = <String>[];
      for (final u in ['a', 'b', 'c']) {
        setFileWait(
          u,
          const FileWait(
            size: 1000000,
            state: WaitState.asks,
            rule: AutoGet.never,
          ),
        );
      }
      await t.pumpWidget(
        host(
          FileStack(
            isOut: false,
            onGet: got.add,
            onPause: (_) {},
            rows: [
              for (final u in ['a', 'b', 'c'])
                FileStackRow(
                  id: u,
                  name: '$u.zip',
                  waitUid: u,
                  ready: () => Text('here $u'),
                ),
            ],
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Get all'), findsOneWidget);
      await t.tap(find.textContaining('Get all'));
      expect(got, ['a', 'b', 'c']);
      for (final u in ['a', 'b', 'c']) {
        setFileWait(u, fileWaitOf(u)!.copyWith(state: WaitState.coming));
      }
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Getting 0 of 3'), findsOneWidget);
      setFileWait('a', null);
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('here a'), findsOneWidget);
      expect(find.text('Getting 1 of 3'), findsOneWidget);
    });

    for (final still in [false, true]) {
      testWidgets('a failed row shakes once and a tap sends it again '
          '(still: $still)', (t) async {
        var tries = 0;
        Widget stack(bool failed) => host(
          FileStack(
            isOut: true,
            onGet: (_) {},
            onPause: (_) {},
            rows: [
              FileStackRow(
                id: 'x',
                name: 'permit-scan.pdf',
                failed: failed,
                onRetry: () => tries++,
                ready: () => const Text('here scan'),
              ),
            ],
          ),
          still: still,
        );
        await t.pumpWidget(stack(false));
        await t.pumpWidget(stack(true));
        await t.pump(const Duration(milliseconds: 500));
        expect(find.text('here scan'), findsNothing);
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
        await t.tap(find.byIcon(Icons.refresh_rounded));
        expect(tries, 1);
      });
    }
  });

  testWidgets('theirs with its download removed says so', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FileCard(path: null, name: 'route.pdf', isOut: false),
        ),
      ),
    );
    await t.pump();
    expect(find.text(l10n.fileNotHere), findsOneWidget);
  });

  group('the ring', () {
    for (final still in [false, true]) {
      for (final queued in [false, true]) {
        testWidgets('done, the ring fills the rest of the way, then a tick '
            '(still: $still, ${queued ? 'never started' : 'part way'})', (
          t,
        ) async {
          Widget card(String? uid, {bool failed = false}) => MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: still),
              child: Scaffold(
                body: FileCard(
                  path: null,
                  name: 'route.pdf',
                  isOut: true,
                  sendingUid: uid,
                  queued: queued,
                  failed: failed,
                ),
              ),
            ),
          );
          if (!queued) mediaSendProgress['s1'] = 0.3;
          addTearDown(() => mediaSendProgress.remove('s1'));
          await t.pumpWidget(card('s1'));
          await t.pump();
          // waiting or part way: its ring is there from the start
          expect(find.byType(FileSendRing), findsOneWidget);
          mediaSendProgress.remove('s1');
          await t.pumpWidget(card(null));
          await t.pump(const Duration(milliseconds: 100));
          // it runs to full first, never jumps straight to the tile
          expect(
            find.byType(FileSendRing),
            still ? findsNothing : findsOneWidget,
          );
          await t.pump(const Duration(milliseconds: 250));
          await t.pump();
          expect(
            find.byIcon(Icons.check_rounded),
            still ? findsNothing : findsOneWidget,
          );
          await t.pump(const Duration(milliseconds: 900));
          await t.pump(const Duration(milliseconds: 300));
          expect(find.byIcon(Icons.check_rounded), findsNothing);
        });
      }
    }

    testWidgets('one that did not go: no fill, no tick', (t) async {
      Widget card(String? uid) => MaterialApp(
        home: Scaffold(
          body: FileCard(
            path: null,
            name: 'route.pdf',
            isOut: true,
            sendingUid: uid,
            queued: true,
            failed: uid == null,
          ),
        ),
      );
      await t.pumpWidget(card('s2'));
      await t.pump();
      await t.pumpWidget(card(null));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(FileSendRing), findsNothing);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });
  });
}
