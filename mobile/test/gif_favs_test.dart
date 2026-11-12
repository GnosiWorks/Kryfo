// SPDX-License-Identifier: GPL-3.0-or-later
// favourite gifs: kept as files with a row for their place, per container;
// the picker's favourites tab, its edit mode, holding a found gif, reduced
// motion, right to left, large text and the looks in light and dark
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/gifs/gif_fav_panel.dart';
import 'package:kryfo/gifs/gif_favs.dart';
import 'package:kryfo/gifs/gif_panel.dart';
import 'package:kryfo/gifs/gif_source.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:kryfo/stickers/sticker_recents.dart';
import 'package:kryfo/stickers/sticker_sheet.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/halo_sheet.dart';

import 'narrow_settings.dart' show loadAppFonts;
import 'sqlite_ffi.dart';
import 'sticker_test_util.dart';

// one pixel of [rgb]: the colour sits in the first palette entry
Uint8List _gif(int rgb) {
  final b = base64Decode(
    'R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==',
  );
  b[13] = (rgb >> 16) & 0xff;
  b[14] = (rgb >> 8) & 0xff;
  b[15] = rgb & 0xff;
  return b;
}

const _tones = [0x6B5640, 0x44506B, 0x5E3D4A, 0x3E5A4C, 0x6A6340, 0x4A3D5E];

GifFavStore _store(SqliteMem db, Directory dir) =>
    GifFavStore(db: () async => db, folder: () async => dir);

class _Gifs implements GifSource {
  @override
  Future<GifPage> search(String q, {int offset = 0, String? provider}) =>
      trending();
  @override
  Future<GifPage> trending({int offset = 0, String? provider}) async => GifPage(
    items: [
      for (var i = 0; i < 4; i++)
        GifItem(
          'g$i',
          GifMedia('$kGifRelay/gif/v1/m/p$i.x', 200, 160),
          GifMedia('$kGifRelay/gif/v1/m/f$i.x', 480, 360),
        ),
    ],
    provider: 'giphy',
    brand: 'GIPHY',
    next: null,
  );
  @override
  Future<Uint8List?> bytes(String url) async => _gif(0x336699);
}

void main() {
  final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('gif_favs');
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('the store', () {
    test(
      'a gif goes to the front as a file; what is not a gif does not',
      () async {
        final s = _store(SqliteMem.open()!, tmp);
        expect(await s.add(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0])), isFalse);
        expect(await s.add(_gif(1)), isTrue);
        expect(await s.add(_gif(2)), isTrue);
        final all = await s.load();
        expect(all, hasLength(2));
        expect(File(all.first.path).readAsBytesSync(), _gif(2));
        expect(all.first.path, startsWith('${tmp.path}/$kFavFolder/'));
        expect((all.first.w, all.first.h), (1, 1));
        // nothing names where it came from
        expect(all.first.path, isNot(contains('giphy')));
      },
      skip: skip,
    );

    test('the same gif again moves up, never twice', () async {
      final s = _store(SqliteMem.open()!, tmp);
      await s.add(_gif(1));
      await s.add(_gif(2));
      await s.add(_gif(1));
      final all = await s.load();
      expect(all, hasLength(2));
      expect(File(all.first.path).readAsBytesSync(), _gif(1));
      expect(Directory('${tmp.path}/$kFavFolder').listSync(), hasLength(2));
    }, skip: skip);

    test('removed: the row and the file go', () async {
      final s = _store(SqliteMem.open()!, tmp);
      await s.add(_gif(1));
      final f = (await s.load()).single;
      await s.remove(f);
      expect(await s.load(), isEmpty);
      expect(File(f.path).existsSync(), isFalse);
    }, skip: skip);

    test('the order kept is the order shown', () async {
      final s = _store(SqliteMem.open()!, tmp);
      for (var i = 0; i < 4; i++) {
        await s.add(_gif(i));
      }
      final all = await s.load();
      await s.reorder(all.reversed.toList());
      expect(await s.load(), all.reversed.toList());
      // a new one still goes first
      await s.add(_gif(9));
      expect(File((await s.load()).first.path).readAsBytesSync(), _gif(9));
    }, skip: skip);

    test('a row whose file went is let go', () async {
      final s = _store(SqliteMem.open()!, tmp);
      await s.add(_gif(1));
      await s.add(_gif(2));
      final all = await s.load();
      File(all.first.path).deleteSync();
      expect(await s.load(), [all.last]);
    }, skip: skip);

    test('past the most kept, the last ones go', () async {
      final s = _store(SqliteMem.open()!, tmp);
      for (var i = 0; i <= kGifFavMost; i++) {
        await s.add(_gif(i));
      }
      final all = await s.load();
      expect(all, hasLength(kGifFavMost));
      expect(File(all.first.path).readAsBytesSync(), _gif(kGifFavMost));
      expect(
        Directory('${tmp.path}/$kFavFolder').listSync(),
        hasLength(kGifFavMost),
      );
    }, skip: skip);

    test('each identity its own: the decoy starts with none', () async {
      final day = _store(SqliteMem.open()!, Directory('${tmp.path}/a'));
      final decoy = _store(SqliteMem.open()!, Directory('${tmp.path}/b'));
      await day.add(_gif(1));
      expect(await decoy.load(), isEmpty);
      expect(await day.load(), hasLength(1));
    }, skip: skip);
  });

  group('the favourites tab', () {
    setUpAll(loadAppFonts);
    late StickerLibrary lib;
    setUpAll(() => lib = useLibrary());

    Future<(GifFavStore, List<GifFav>)> seeded(int n) async {
      final s = _store(SqliteMem.open()!, tmp);
      for (var i = n - 1; i >= 0; i--) {
        await s.add(_gif(_tones[i % _tones.length] + i));
      }
      return (s, await s.load());
    }

    Future<(GifFavStore, List<GifFav>)> seed(WidgetTester t, int n) async =>
        (await t.runAsync(() => seeded(n)))!;

    Future<void> app(
      WidgetTester t,
      Widget child, {
      bool reduce = false,
      bool light = false,
      double scale = 1,
      Locale locale = const Locale('en'),
    }) async {
      t.view.physicalSize = const Size(390, 600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      HaloColors.setLight(light);
      addTearDown(() => HaloColors.setLight(false));
      setL10nLocale(locale);
      addTearDown(() => setL10nLocale(const Locale('en')));
      await t.pumpWidget(
        MaterialApp(
          theme: buildHaloTheme(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c).copyWith(
              disableAnimations: reduce,
              textScaler: TextScaler.linear(scale),
            ),
            child: w!,
          ),
          home: Scaffold(backgroundColor: HaloColors.surface, body: child),
        ),
      );
    }

    // the pictures are files: they decode outside the fake clock
    Future<void> settle(WidgetTester t) async {
      for (final e in find.byType(Image).evaluate()) {
        precacheImage((e.widget as Image).image, e);
      }
      for (var i = 0; i < 60; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await t.pump(const Duration(milliseconds: 20));
      }
    }

    Widget panel(
      GifFavStore s,
      List<GifFav> favs, {
      ValueChanged<Uint8List>? onPick,
      Key? key,
    }) => GifFavPanel(
      key: key,
      store: s,
      initial: favs,
      controller: ScrollController(),
      onPick: onPick ?? (_) {},
    );

    testWidgets('empty: how to add one, and where they are kept', (t) async {
      final s = _store(SqliteMem.open()!, tmp);
      await app(t, panel(s, const []));
      await t.pump();
      expect(find.text('No favourites yet'), findsOneWidget);
      expect(
        find.text('Hold a GIF in a chat or in GIFs to add it here.'),
        findsOneWidget,
      );
      expect(
        find.text('Kept on this phone, encrypted. Works without GIF search.'),
        findsOneWidget,
      );
    }, skip: skip != null);

    testWidgets('a tap shows which, a second sends its gif', (t) async {
      final (s, favs) = await seed(t, 3);
      Uint8List? sent;
      await app(t, panel(s, favs, onPick: (b) => sent = b));
      await settle(t);
      final first = find.bySemanticsLabel('Favourite GIF 1');
      await t.tap(first);
      await t.pump(const Duration(milliseconds: 300));
      expect(sent, isNull);
      expect(find.text('Send'), findsOneWidget);
      await t.tap(first);
      await settle(t);
      expect(sent, File(favs.first.path).readAsBytesSync());
    }, skip: skip != null);

    testWidgets('hold: edit, a cross removes, done ends it', (t) async {
      final (s, favs) = await seed(t, 3);
      final key = GlobalKey<GifFavPanelState>();
      await app(t, panel(s, favs, key: key));
      await settle(t);
      await t.longPress(find.bySemanticsLabel('Favourite GIF 2'));
      await t.pump(const Duration(milliseconds: 400));
      expect(key.currentState!.editing, isTrue);
      expect(find.text('Your favourites'), findsOneWidget);
      expect(
        find.text('Hold and drag to reorder. Tap the cross to remove.'),
        findsOneWidget,
      );
      await t.tap(find.byIcon(Icons.close_rounded).first);
      await settle(t);
      expect(key.currentState!.order, hasLength(2));
      expect(await t.runAsync(() => s.load()), hasLength(2));
      await t.tap(find.text('Done'));
      await t.pump(const Duration(milliseconds: 400));
      expect(key.currentState!.editing, isFalse);
    }, skip: skip != null);

    testWidgets('a screen reader moves one and the order is kept', (t) async {
      final h = t.ensureSemantics();
      final (s, favs) = await seed(t, 3);
      final key = GlobalKey<GifFavPanelState>();
      await app(t, panel(s, favs, key: key));
      await settle(t);
      final first = t.getSemantics(find.bySemanticsLabel('Favourite GIF 1'));
      final edit = first.getSemanticsData().customSemanticsActionIds!.single;
      t.binding.pipelineOwner.semanticsOwner!.performAction(
        first.id,
        SemanticsAction.customAction,
        edit,
      );
      await t.pump(const Duration(milliseconds: 400));
      expect(key.currentState!.editing, isTrue);
      final node = t.getSemantics(find.bySemanticsLabel('Favourite GIF 1'));
      final labels = {
        for (final id in node.getSemanticsData().customSemanticsActionIds!)
          CustomSemanticsAction.getAction(id)!.label: id,
      };
      expect(
        labels.keys,
        containsAll(['Move later', 'Remove from favourites']),
      );
      t.binding.pipelineOwner.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.customAction,
        labels['Move later'],
      );
      await settle(t);
      expect(key.currentState!.order.map((f) => f.id), [
        favs[1].id,
        favs[0].id,
        favs[2].id,
      ]);
      final kept = await t.runAsync(() => s.load());
      expect(kept!.map((f) => f.id), [favs[1].id, favs[0].id, favs[2].id]);
      h.dispose();
    }, skip: skip != null);

    testWidgets('hold and drag: the order follows the finger', (t) async {
      final (s, favs) = await seed(t, 4);
      final key = GlobalKey<GifFavPanelState>();
      await app(t, panel(s, favs, key: key));
      await settle(t);
      await t.longPress(find.bySemanticsLabel('Favourite GIF 1'));
      await t.pump(const Duration(milliseconds: 400));
      final from = t.getCenter(find.bySemanticsLabel('Favourite GIF 1'));
      final to = t.getCenter(find.bySemanticsLabel('Favourite GIF 4'));
      final g = await t.startGesture(from);
      await t.pump(const Duration(milliseconds: 300));
      await g.moveTo(Offset.lerp(from, to, 0.5)!);
      await t.pump(const Duration(milliseconds: 50));
      await g.moveTo(to);
      await t.pump(const Duration(milliseconds: 50));
      await g.up();
      await settle(t);
      expect(key.currentState!.order.last.id, favs.first.id);
      final kept = await t.runAsync(() => s.load());
      expect(kept!.last.id, favs.first.id);
    }, skip: skip != null);

    testWidgets('reduced motion: stills, and edit is there at once', (t) async {
      final (s, favs) = await seed(t, 2);
      await app(t, panel(s, favs), reduce: true);
      await settle(t);
      expect(find.byType(Image), findsNothing);
      await t.longPress(find.bySemanticsLabel('Favourite GIF 1'));
      await t.pump();
      expect(find.text('Your favourites'), findsOneWidget);
    }, skip: skip != null);

    testWidgets('large text on a small phone, arabic: nothing overflows', (
      t,
    ) async {
      final (s, favs) = await seed(t, 3);
      await app(t, panel(s, favs), scale: 1.5, locale: const Locale('ar'));
      await settle(t);
      await t.longPress(find.bySemanticsLabel('صورة GIF مفضلة ١'));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull);
    }, skip: skip != null);

    for (final (name, light, locale, edit) in [
      ('dark', false, const Locale('en'), false),
      ('light', true, const Locale('en'), false),
      ('rtl', false, const Locale('ar'), false),
      ('edit', false, const Locale('en'), true),
    ]) {
      testWidgets('looks: $name', (t) async {
        final (s, favs) = await seed(t, 5);
        await app(
          t,
          SizedBox(height: 600, child: panel(s, favs)),
          light: light,
          locale: locale,
        );
        await settle(t);
        if (edit) {
          await t.longPress(find.bySemanticsLabel('Favourite GIF 1'));
          await settle(t);
        }
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/gif_favs_$name.png'),
        );
      }, skip: skip != null);
    }

    group('in the picker', () {
      Future<SheetPick?> open(
        WidgetTester t,
        GifFavStore s,
        List<GifFav> favs,
      ) async {
        late BuildContext home;
        await app(
          t,
          Builder(
            builder: (c) {
              home = c;
              return const SizedBox.expand();
            },
          ),
        );
        t.view.physicalSize = const Size(390, 844);
        await t.pump();
        SheetPick? picked;
        showHaloSheet<SheetPick>(
          home,
          scroll: true,
          builder: (_) => StickerSheet(
            recents: StickerRecents(HaloContainer.everyday),
            library: lib,
            gifs: GifTabs(
              source: _Gifs(),
              route: GifRoute.onion,
              loadOn: () async => true,
              saveOn: (_) async {},
              loadAsked: () async => true,
              markAsked: () async {},
              favs: s,
            ),
          ),
        ).then((r) => picked = r);
        await settle(t);
        return picked;
      }

      testWidgets('opens on the favourites, first of the tabs', (t) async {
        final (s, favs) = await seed(t, 2);
        await open(t, s, favs);
        expect(find.text('Favourites'), findsOneWidget);
        expect(find.bySemanticsLabel('Favourite GIF 1'), findsOneWidget);
        // the board's order: favourites, gifs, stickers, then the phone's
        double x(String s) => t.getCenter(find.text(s)).dx;
        expect(x('Favourites'), lessThan(x('GIFs')));
        expect(x('GIFs'), lessThan(x('Stickers')));
      }, skip: skip != null);

      testWidgets('none yet: the stickers first, the tab still there', (
        t,
      ) async {
        final s = _store(SqliteMem.open()!, tmp);
        await open(t, s, const []);
        expect(find.text('Favourites'), findsOneWidget);
        expect(find.text('No favourites yet'), findsNothing);
        await t.tap(find.text('Favourites'));
        await settle(t);
        expect(find.text('No favourites yet'), findsOneWidget);
      }, skip: skip != null);

      testWidgets('a found gif held is kept, with its star and a word', (
        t,
      ) async {
        final s = _store(SqliteMem.open()!, tmp);
        await open(t, s, const []);
        await t.tap(find.text('GIFs'));
        await settle(t);
        await t.longPress(find.bySemanticsLabel('GIF 1'));
        await settle(t);
        expect(find.byType(StarPop), findsOneWidget);
        expect(find.text('Added to favourites'), findsOneWidget);
        final kept = await t.runAsync(() => s.load());
        expect(kept, hasLength(1));
        expect(File(kept!.single.path).readAsBytesSync(), _gif(0x336699));
        await t.pump(const Duration(seconds: 4));
      }, skip: skip != null);
    });
  });
}
