// SPDX-License-Identifier: GPL-3.0-or-later
// the sticker picker: what it offers, what a tap and a long press do, the
// tab pill, a tab per pack, back, and recents that stay with their
// identity.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/app_localizations.dart';
import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:kryfo/stickers/sticker_recents.dart';
import 'package:kryfo/stickers/sticker_sheet.dart';
import 'package:kryfo/stickers/sticker_view.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/halo_sheet.dart';

import 'sticker_test_util.dart';

class _Harness {
  _Harness(this.t, this.lib);
  final WidgetTester t;
  final StickerLibrary lib;
  late BuildContext home;
  StickerPick? picked;
  bool closed = false;

  Future<void> pump({bool reduce = false}) async {
    await t.pumpWidget(
      MaterialApp(
        theme: buildHaloTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(disableAnimations: reduce),
          child: child!,
        ),
        home: Builder(
          builder: (c) {
            home = c;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
  }

  Future<void> open() async {
    closed = false;
    picked = null;
    showHaloSheet<StickerPick>(
      home,
      scroll: true,
      builder: (_) => StickerSheet(
        recents: StickerRecents(HaloContainer.everyday),
        library: lib,
      ),
    ).then((r) {
      picked = r;
      closed = true;
    });
    await frames(30);
  }

  Future<void> frames(int n) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
  }

  Finder cell(String emoji) => find.bySemanticsLabel('Sticker $emoji');
}

void main() {
  final lib = useLibrary();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('it offers the pack, and no recent tab yet', (t) async {
    final h = _Harness(t, lib);
    await h.pump();
    await h.open();
    for (final e in ['👋', '😂', '👍', '❤️']) {
      expect(h.cell(e), findsOneWidget, reason: e);
    }
    expect(find.bySemanticsLabel('Recent'), findsNothing);
    expect(find.bySemanticsLabel('Fokia'), findsWidgets);
    // the grid plays once the sheet is up, within its budget
    expect(
      t.allRenderObjects.whereType<RenderSticker>().toSet().where(
        (b) => b.time >= 0,
      ),
      isNotEmpty,
    );
  });

  testWidgets('a tap picks it and puts it first in recent', (t) async {
    final h = _Harness(t, lib);
    await h.pump();
    await h.open();
    final cell = t.getRect(h.cell('😂'));
    await t.tap(h.cell('😂'));
    await h.frames(20);
    expect(h.closed, true);
    expect(h.picked?.ref, const StickerRef('fokia', 2));
    // where it was drawn, for the flight to its bubble
    final from = h.picked!.from;
    expect(from.isEmpty, false);
    expect(cell.contains(from.center), true);
    expect(from.width, lessThan(cell.width));

    await h.open();
    expect(find.bySemanticsLabel('Recent'), findsWidgets);
    // 😂 twice now: once in recent, once in the pack
    expect(h.cell('😂'), findsNWidgets(2));
    await t.tap(h.cell('👋'));
    await h.frames(20);
    final now = await StickerRecents(HaloContainer.everyday).load();
    expect(now, const [StickerRef('fokia', 1), StickerRef('fokia', 2)]);
  });

  testWidgets('a tab per pack, fokia first, and the remix on offer', (t) async {
    final h = _Harness(t, lib);
    await h.pump();
    await h.open();
    final fokia = find.bySemanticsLabel('Fokia');
    final remix = find.bySemanticsLabel('Fokia Remix');
    expect(fokia, findsWidgets);
    expect(remix, findsWidgets);
    expect(find.bySemanticsLabel('Recent'), findsNothing);
    // the tabs, in order: fokia at the start, the remix one step on
    expect(
      t.getRect(remix.first).left - t.getRect(fokia.first).left,
      closeTo(44, 0.5),
    );
    Rect pill() => t.getRect(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == HaloColors.amberSoft,
      ),
    );
    final before = pill();
    await t.tap(remix.first);
    await h.frames(25);
    expect(pill().left - before.left, closeTo(44, 0.5));
    // the grid went down to the remix stickers, all of them moving
    expect(h.cell('🎻'), findsOneWidget);
    await t.tap(h.cell('🎻'));
    await h.frames(20);
    expect(h.picked?.ref, const StickerRef('fokiaremix', 36));

    // recent mixes the two packs, newest first
    await h.open();
    await t.tap(h.cell('👋'));
    await h.frames(20);
    expect(await StickerRecents(HaloContainer.everyday).load(), const [
      StickerRef('fokia', 1),
      StickerRef('fokiaremix', 36),
    ]);
    await h.open();
    final sheet = t.state<StickerSheetState>(find.byType(StickerSheet));
    expect(sheet.recent, const [
      StickerRef('fokia', 1),
      StickerRef('fokiaremix', 36),
    ]);
    expect(h.cell('🎻'), findsWidgets);
    expect(find.bySemanticsLabel('Recent'), findsWidgets);
    expect(
      t.getRect(remix.first).left - t.getRect(fokia.first).left,
      closeTo(44, 0.5),
    );
  });

  testWidgets('recent keeps only what the packs can draw', (t) async {
    FlutterSecureStorage.setMockInitialValues({
      'sticker_recents': 'fokiaremix:30,otter:3,fokiaremix:9,fokia:2',
    });
    final h = _Harness(t, lib);
    await h.pump();
    await h.open();
    final sheet = t.state<StickerSheetState>(find.byType(StickerSheet));
    expect(sheet.recent, const [
      StickerRef('fokiaremix', 30),
      StickerRef('fokia', 2),
    ]);
  });

  testWidgets('the tab pill slides to the tab tapped', (t) async {
    FlutterSecureStorage.setMockInitialValues({'sticker_recents': 'fokia:4'});
    final h = _Harness(t, lib);
    await h.pump();
    await h.open();
    Rect pill() => t.getRect(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == HaloColors.amberSoft,
      ),
    );
    final before = pill();
    await t.tap(find.bySemanticsLabel('Fokia').first);
    await h.frames(20);
    final after = pill();
    expect(after.left - before.left, closeTo(44, 0.5));
    await t.tap(find.bySemanticsLabel('Recent').first);
    await h.frames(20);
    expect(pill().left, closeTo(before.left, 0.5));
  });

  testWidgets('a long press shows it big; sliding swaps; lifting shows send', (
    t,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'sticker_recents': 'fokia:17'});
    final h = _Harness(t, lib);
    await h.pump();
    await h.open();
    final big = find.byWidgetPredicate(
      (w) => w is StickerView && w.size >= 200,
    );
    final g = await t.startGesture(t.getCenter(h.cell('🔒').first));
    await t.pump(const Duration(milliseconds: 360));
    await h.frames(15);
    expect(big, findsOneWidget);
    expect((t.widget(big) as StickerView).sticker.id, 17);
    // no buttons while the finger is down
    expect(find.text('Send'), findsNothing);

    await g.moveTo(t.getCenter(h.cell('❤️')));
    await h.frames(15);
    expect((t.widget(big) as StickerView).sticker.id, 4);

    await g.up();
    await h.frames(15);
    expect(find.text('Send'), findsOneWidget);
    // a pack sticker, not a recent one: nothing to remove
    expect(find.text('Remove from recent'), findsNothing);

    final shown = t.getRect(big);
    await t.tap(find.text('Send'));
    await h.frames(20);
    expect(h.picked?.ref, const StickerRef('fokia', 4));
    // it flies from the big one, not from its cell
    expect(h.picked!.from.center.dx, closeTo(shown.center.dx, 1));
    expect(h.picked!.from.width, closeTo(shown.width, 1));
    expect(big, findsNothing);
  });

  testWidgets('a recent one can be removed from recent', (t) async {
    FlutterSecureStorage.setMockInitialValues({
      'sticker_recents': 'fokia:2,fokia:1',
    });
    final h = _Harness(t, lib);
    await h.pump();
    await h.open();
    final g = await t.startGesture(t.getCenter(h.cell('😂').first));
    await t.pump(const Duration(milliseconds: 360));
    await g.up();
    await h.frames(20);
    await t.tap(find.text('Remove from recent'));
    await h.frames(30);
    expect(await StickerRecents(HaloContainer.everyday).load(), const [
      StickerRef('fokia', 1),
    ]);
    // the sheet stays; 😂 is only in the pack now
    expect(h.closed, false);
    expect(h.cell('😂'), findsOneWidget);
  });

  testWidgets('back closes the preview before the sheet', (t) async {
    final h = _Harness(t, lib);
    await h.pump();
    await h.open();
    final g = await t.startGesture(t.getCenter(h.cell('👋')));
    await t.pump(const Duration(milliseconds: 360));
    await g.up();
    await h.frames(15);
    expect(find.text('Send'), findsOneWidget);
    await t.binding.handlePopRoute();
    await h.frames(25);
    expect(find.text('Send'), findsNothing);
    expect(h.closed, false);
    await t.binding.handlePopRoute();
    await h.frames(25);
    expect(h.closed, true);
    expect(h.picked, isNull);
  });

  testWidgets('reduced motion: it all works, without the pops', (t) async {
    final h = _Harness(t, lib);
    await h.pump(reduce: true);
    await h.open();
    // nothing plays in the grid
    expect(
      t.allRenderObjects.whereType<RenderSticker>().toSet().every(
        (b) => b.time < 0,
      ),
      true,
    );
    final g = await t.startGesture(t.getCenter(h.cell('👋')));
    await t.pump(const Duration(milliseconds: 360));
    await g.up();
    await h.frames(15);
    await t.tap(find.text('Send'));
    await h.frames(20);
    expect(h.picked?.ref, const StickerRef('fokia', 1));
  });

  testWidgets('the grid rests after its loops, fresh on the next opening', (
    t,
  ) async {
    final pack = lib.pack('fokia')!;
    final h = _Harness(t, lib);
    await h.pump();
    await h.open();
    bool playing() =>
        t.allRenderObjects.whereType<RenderSticker>().any((b) => b.time >= 0);
    expect(playing(), true);
    // every cell on screen takes its turn in the budget, plays its loops
    // and rests; a round is at most a phase and the loops of the longest
    final longest = pack.playable
        .map((id) => pack.sticker(id)!.loopMs)
        .reduce((a, b) => a > b ? a : b);
    final round = (kStickerPickLoops + 1) * longest;
    for (var ms = 0; ms < 20 * round && playing(); ms += 100) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(playing(), false);
    final rested = StickerView.frames;
    await h.frames(100);
    expect(StickerView.frames, rested);
    expect(t.binding.hasScheduledFrame, false);

    // closed and opened again: they play again
    await t.binding.handlePopRoute();
    await h.frames(25);
    expect(h.closed, true);
    await h.open();
    expect(playing(), true);
  });

  testWidgets('the big one rests after its loops; a tap plays it again', (
    t,
  ) async {
    final pack = lib.pack('fokia')!;
    final h = _Harness(t, lib);
    await h.pump();
    await h.open();
    final g = await t.startGesture(t.getCenter(h.cell('👋')));
    await t.pump(const Duration(milliseconds: 360));
    await g.up();
    await h.frames(15);
    RenderSticker big() => t.allRenderObjects
        .whereType<RenderSticker>()
        .firstWhere((b) => b.size.width >= 200);
    expect(big().time, greaterThanOrEqualTo(0));
    final loop = pack.sticker(1)!.loopMs;
    await h.frames((kStickerPickLoops + 1) * loop ~/ 20 + 10);
    expect(big().time, -1);
    final rested = StickerView.frames;
    await h.frames(50);
    expect(StickerView.frames, rested);

    await t.tapAt(
      t.getCenter(
        find.byWidgetPredicate((w) => w is StickerView && w.size >= 200),
      ),
    );
    await h.frames(10);
    expect(StickerView.frames, greaterThan(rested + 5));
    expect(big().time, greaterThan(0));
    // still open: the tap played it, it did not close the preview
    expect(find.text('Send'), findsOneWidget);
  });

  test('recents: newest first, no twice, at most twenty', () async {
    final r = StickerRecents(HaloContainer.everyday);
    for (var i = 1; i <= 25; i++) {
      await r.add(StickerRef('fokia', i));
    }
    await r.add(const StickerRef('fokia', 10));
    final now = await r.load();
    expect(now.length, kStickerRecentMax);
    expect(now.first, const StickerRef('fokia', 10));
    expect(now.where((x) => x.id == 10).length, 1);
    expect(now[1], const StickerRef('fokia', 25));
  });

  test('recents belong to their identity', () async {
    await StickerRecents(
      HaloContainer.everyday,
    ).add(const StickerRef('fokia', 2));
    final decoy = StickerRecents(HaloContainer.decoy);
    expect(await decoy.load(), isEmpty);
    await decoy.add(const StickerRef('fokia', 19));
    expect(await StickerRecents(HaloContainer.everyday).load(), const [
      StickerRef('fokia', 2),
    ]);
    expect(await decoy.load(), const [StickerRef('fokia', 19)]);
    expect(HaloContainer.decoy.key('sticker_recents'), 'd.sticker_recents');
  });

  test('recents ignore what they cannot read', () async {
    FlutterSecureStorage.setMockInitialValues({
      'sticker_recents': 'fokia:3,,FOKIA:1,fokia:99999,fokia:x,fokia:3,x:1',
    });
    expect(await StickerRecents(HaloContainer.everyday).load(), const [
      StickerRef('fokia', 3),
      StickerRef('x', 1),
    ]);
  });
}
