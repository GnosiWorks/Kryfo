// SPDX-License-Identifier: GPL-3.0-or-later
// gif search: what the relay's answer may hold, what goes over the wire and
// what never does, the opt-in, the picker's states, sending, reduced motion,
// right to left and large text. no network: a fake source and a fake wire.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/gifs/gif_engine.dart';
import 'package:kryfo/gifs/gif_opt_in.dart';
import 'package:kryfo/gifs/gif_panel.dart';
import 'package:kryfo/gifs/gif_picture.dart';
import 'package:kryfo/gifs/gif_source.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/l10n/numbers.dart';
import 'package:kryfo/quiet_wait.dart';
import 'package:kryfo/main.dart'
    show HaloDb, HaloEngine, appState, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/session.dart';
import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:kryfo/stickers/sticker_recents.dart';
import 'package:kryfo/stickers/sticker_sheet.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/halo_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sticker_test_util.dart';

// one white pixel
final _gif = base64Decode(
  'R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==',
);

GifItem _item(int i) => GifItem(
  'g$i',
  GifMedia('$kGifRelay/gif/v1/m/p$i.x', 200, 120 + (i % 4) * 40),
  GifMedia('$kGifRelay/gif/v1/m/f$i.x', 480, 360),
);

GifPage _page(int from, {int n = kGifPage, String provider = 'giphy'}) =>
    GifPage(
      items: [for (var i = from; i < from + n; i++) _item(i)],
      provider: provider,
      brand: provider == 'klipy' ? 'Klipy' : 'GIPHY',
      next: from + n,
    );

class _FakeGifs implements GifSource {
  final asked = <String>[];
  final fetched = <String>[];
  // what a question gets; the default is a full page
  GifPage Function(String q, int offset)? answer;
  // held until completed: the loading state stays up
  Completer<void>? hold;
  Uint8List? full = _gif;

  Future<GifPage> _answer(String q, int offset, String? provider) async {
    asked.add('$q@$offset${provider == null ? '' : '/$provider'}');
    await hold?.future;
    return answer?.call(q, offset) ?? _page(offset);
  }

  @override
  Future<GifPage> search(String q, {int offset = 0, String? provider}) =>
      _answer(q, offset, provider);

  @override
  Future<GifPage> trending({int offset = 0, String? provider}) =>
      _answer('', offset, provider);

  @override
  Future<Uint8List?> bytes(String url) async {
    fetched.add(url);
    return url.contains('/f') ? full : _gif;
  }
}

// the engine's gif lane, counted: a quiet session calls none of it
class _GifLane implements HaloEngine {
  final calls = <String>[];
  @override
  Future<String> gifPost(String url, String body) async {
    calls.add(url);
    return 'error: wire';
  }

  @override
  Future<String> gifGet(String url) async {
    calls.add(url);
    return 'error: wire';
  }

  @override
  Future<String> gifGetFile(String url, String path) async {
    calls.add(url);
    return 'error: wire';
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Harness {
  _Harness(this.t, this.lib);
  final WidgetTester t;
  final StickerLibrary lib;
  late BuildContext home;
  SheetPick? picked;
  bool closed = false;
  bool on = false;
  bool asked = false;
  final saved = <bool>[];
  final gifs = _FakeGifs();

  Future<void> pump({
    bool reduce = false,
    double scale = 1,
    Locale locale = const Locale('en'),
    Size size = const Size(390, 844),
  }) async {
    t.view.physicalSize = size * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    setL10nLocale(locale);
    addTearDown(() => setL10nLocale(const Locale('en')));
    await t.pumpWidget(
      MaterialApp(
        theme: buildHaloTheme(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(
            disableAnimations: reduce,
            textScaler: TextScaler.linear(scale),
          ),
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

  // [tabs]: the app's own, as a chat hands them in
  Future<void> open({GifTabs? tabs, GifRoute route = GifRoute.onion}) async {
    closed = false;
    picked = null;
    showHaloSheet<SheetPick>(
      home,
      scroll: true,
      builder: (_) => StickerSheet(
        recents: StickerRecents(HaloContainer.everyday),
        library: lib,
        gifs:
            tabs ??
            GifTabs(
              source: gifs,
              route: route,
              loadOn: () async => on,
              saveOn: (v) async {
                on = v;
                if (v) asked = true;
                saved.add(v);
              },
              loadAsked: () async => asked,
              markAsked: () async => asked = true,
            ),
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

  Future<void> tab(String label) async {
    await t.tap(find.text(label));
    await frames(25);
  }

  // the sheet scrolls until [text] is on the screen
  Future<void> reveal(String text) async {
    for (var i = 0; i < 12; i++) {
      final at = t.getCenter(find.text(text));
      if (at.dy < t.view.physicalSize.height / t.view.devicePixelRatio - 40) {
        return;
      }
      await t.dragFrom(const Offset(20, 300), const Offset(0, -250));
      await frames(10);
    }
  }

  Finder tile(int i) => find.bySemanticsLabel(l10n.gifTileA11y(whole(i + 1)));

  Future<void> close() async {
    Navigator.of(home).pop();
    await frames(20);
  }
}

const _askTor =
    "GIF search goes through Kryfo's server over Tor. GIPHY never sees you. "
    'Turn it on?';
const _askKryfo =
    "GIF search goes through Kryfo's server. GIPHY never sees you. "
    'Turn it on?';
const _off = 'GIF search is off';
const _pointer = 'GIFs saved on your phone are in On this phone.';

void main() {
  final lib = useLibrary();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    quietWait = () => Duration.zero;
  });

  group('the relay answer', () {
    test('only our own media paths are kept', () {
      final body = jsonEncode({
        'provider': 'klipy',
        'next': 24,
        'items': [
          {
            'id': 'a',
            'preview': {'url': '/gif/v1/m/abc.def', 'w': 200, 'h': 150},
            'full': {'url': '/gif/v1/m/ghi.jkl', 'w': 480, 'h': 360},
          },
          {
            'id': 'elsewhere',
            'preview': {'url': 'https://media.giphy.com/x.gif', 'w': 1, 'h': 1},
            'full': {'url': '/gif/v1/m/ghi.jkl', 'w': 480, 'h': 360},
          },
          {
            'id': 'climbs',
            'preview': {'url': '/gif/v1/m/../../x.y', 'w': 1, 'h': 1},
            'full': {'url': '/gif/v1/m/ghi.jkl', 'w': 480, 'h': 360},
          },
          {
            'id': 'sizeless',
            'preview': {'url': '/gif/v1/m/abc.def', 'w': 0, 'h': 150},
            'full': {'url': '/gif/v1/m/ghi.jkl', 'w': 480, 'h': 360},
          },
        ],
      });
      final p = parseGifPage(body);
      expect(p.items.map((i) => i.id), ['a']);
      expect(p.items.single.preview.url, '$kGifRelay/gif/v1/m/abc.def');
      expect(p.brand, 'Klipy');
      expect(p.next, 24);
      expect(parseGifPage('<html>').error, GifError.unreachable);
      expect(parseGifPage('{"items":[],"next":null}').next, isNull);
    });

    test('a tile keeps to a sane shape', () {
      expect(_item(0).ratio, closeTo(0.6, 0.001));
      const tall = GifItem('t', GifMedia('u', 10, 1000), GifMedia('u', 1, 1));
      expect(tall.ratio, 1.8);
    });
  });

  group('the wire', () {
    late Directory tmp;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('gif_wire');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => tmp.path,
          );
      gifMemory.clear();
    });
    tearDown(() {
      gifMemory.clear();
      tmp.deleteSync(recursive: true);
    });

    test('the question goes in the body, to our relay only', () async {
      final w = _Wire();
      final src = RelayGifSource(w, quiet: () => false, overTor: () => true);
      final p = await src.search('happy seal', offset: 24, provider: 'klipy');
      expect(p.error, GifError.none);
      expect(w.posts.single.$1, '$kGifRelay/gif/v1/search');
      expect(w.posts.single.$1, isNot(contains('seal')));
      final body = jsonDecode(w.posts.single.$2) as Map;
      expect(body['q'], 'happy seal');
      expect(body['offset'], 24);
      expect(body['limit'], kGifPage);
      expect(body['provider'], 'klipy');
      expect(body['lang'], 'en');
      await src.trending();
      expect(w.gets.single, startsWith('$kGifRelay/gif/v1/trending?'));
    });

    test('a quiet session reaches nothing', () async {
      final w = _Wire();
      final src = RelayGifSource(w, quiet: () => true, overTor: () => true);
      expect((await src.search('seal')).error, isNot(GifError.none));
      expect((await src.trending()).error, isNot(GifError.none));
      expect(await src.bytes('$kGifRelay/gif/v1/m/a.b'), isNull);
      expect(w.posts, isEmpty);
      expect(w.gets, isEmpty);
      expect(w.files, isEmpty);
    });

    test('errors are told apart, tor only on the onion route', () async {
      for (final (said, tor, want) in [
        ('error: status 429', true, GifError.busy),
        ('error: status 400', true, GifError.refused),
        ('error: tor client: tor not started', true, GifError.offline),
        ('error: tor client: tor not started', false, GifError.unreachable),
        ('error: gif timeout', true, GifError.unreachable),
        ('error: gif timeout', false, GifError.unreachable),
        ('error: get: dial tcp: i/o timeout', false, GifError.unreachable),
        ('error: status 502', true, GifError.unreachable),
      ]) {
        final src = RelayGifSource(
          _Wire(answer: said),
          quiet: () => false,
          overTor: () => tor,
        );
        expect((await src.search('seal')).error, want, reason: '$said $tor');
      }
    });

    test('trending asks whole pages and no size of its own', () async {
      final w = _Wire();
      final src = RelayGifSource(w, quiet: () => false, overTor: () => true);
      await src.trending(offset: 48, provider: 'giphy');
      final q = Uri.parse(w.gets.single).queryParameters;
      expect(q['offset'], '48');
      expect(q.containsKey('limit'), false);
    });

    test('a lock while a picture is on its way keeps nothing', () async {
      final w = _Wire()..gate = Completer();
      VoidCallback? lock;
      final mem = GifMemory(
        onLock: (c) {
          lock = c;
          return () => lock = null;
        },
      );
      final src = RelayGifSource(
        w,
        quiet: () => false,
        overTor: () => true,
        memory: mem,
      );
      final url = '$kGifRelay/gif/v1/m/a.b';
      final got = src.bytes(url);
      await pumpEventQueue();
      // watched from the start, though nothing is kept yet
      expect(lock, isNotNull);
      lock!();
      w.gate!.complete();
      expect(await got, isNull);
      expect(mem.isEmpty, true);
      await pumpEventQueue();
      final parts = await gifPartsDir();
      expect(
        parts.existsSync() ? parts.listSync() : const <FileSystemEntity>[],
        isEmpty,
      );
    });

    test('the lock sweeps what a crash left on disk', () async {
      VoidCallback? lock;
      final mem = GifMemory(
        onLock: (c) {
          lock = c;
          return () => lock = null;
        },
      );
      final parts = await gifPartsDir();
      File('${parts.path}/x.part')
        ..createSync(recursive: true)
        ..writeAsBytesSync(_gif);
      mem.watch();
      lock!();
      for (var i = 0; i < 20 && parts.existsSync(); i++) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      expect(parts.existsSync(), false);
    });

    test(
      'a picture is read once, kept in memory, never left on disk',
      () async {
        final w = _Wire();
        VoidCallback? lock;
        final mem = GifMemory(
          onLock: (c) {
            lock = c;
            return () => lock = null;
          },
        );
        final src = RelayGifSource(
          w,
          quiet: () => false,
          overTor: () => true,
          memory: mem,
        );
        final url = '$kGifRelay/gif/v1/m/a.b';
        expect(await src.bytes(url), _gif);
        expect(await src.bytes(url), _gif);
        expect(w.files, hasLength(1));
        final parts = await gifPartsDir();
        expect(
          parts.existsSync() ? parts.listSync() : const <FileSystemEntity>[],
          isEmpty,
        );
        // another host is never asked
        expect(await src.bytes('https://media.giphy.com/x.gif'), isNull);
        expect(w.files, hasLength(1));
        // the lock takes them all
        lock!();
        expect(mem.isEmpty, true);
        expect(lock, isNull);
        await src.bytes(url);
        expect(w.files, hasLength(2));
      },
    );

    test('memory keeps under its ceiling, the oldest going first', () {
      final mem = GifMemory(ceiling: 10, onLock: (_) => () {});
      mem['a'] = Uint8List(4);
      mem['b'] = Uint8List(4);
      expect(mem['a'], isNotNull);
      mem['c'] = Uint8List(4);
      expect(mem['b'], isNull);
      expect(mem['a'], isNotNull);
      expect(mem.size, 8);
    });
  });

  test('the setting is each identity\'s own, off until turned on', () async {
    expect(await loadGifSearchOn(), false);
    await saveGifSearchOn(true, HaloContainer.decoy);
    expect(await loadGifSearchOn(HaloContainer.decoy), true);
    expect(await loadGifSearchOn(), false);
  });

  test('asked is each identity\'s own; turning on counts as asked', () async {
    expect(await loadGifAsked(), false);
    await markGifAsked(HaloContainer.decoy);
    expect(await loadGifAsked(HaloContainer.decoy), true);
    expect(await loadGifAsked(), false);
    await saveGifSearchOn(true);
    expect(await loadGifAsked(), true);
    await saveGifSearchOn(false);
    expect(await loadGifAsked(), true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('d.kryfo.gif.asked'), true);
    expect(prefs.getBool('kryfo.gif.asked'), true);
  });

  test('a wiped identity is asked again', () async {
    await markGifAsked(HaloContainer.decoy);
    await HaloContainer.decoy.wipeFiles();
    expect(await loadGifAsked(HaloContainer.decoy), false);
  });

  group('the picker', () {
    testWidgets('tabs: stickers, gifs, on this phone', (t) async {
      final h = _Harness(t, lib);
      await h.pump();
      await h.open();
      expect(find.text('Stickers'), findsOneWidget);
      expect(find.text('GIFs'), findsOneWidget);
      expect(find.text('On this phone'), findsOneWidget);
      await h.tab('On this phone');
      await t.tap(find.text('Choose a GIF'));
      await h.frames(20);
      expect(h.picked, isA<PhoneGifPick>());
      expect(h.gifs.asked, isEmpty);
    });

    testWidgets('a decoy has the gifs tab and its own switch, and its '
        'search reaches nothing', (t) async {
      final wire = _GifLane();
      useEngineForTest(wire);
      appState.sendModeForTest = 'private';
      final decoy = HaloDb(HaloContainer.decoy);
      useDatabasesForTest(HaloDb(), Session(decoy));
      addTearDown(() {
        final e = HaloDb();
        useDatabasesForTest(e, Session(e));
      });
      final h = _Harness(t, lib);
      await h.pump();
      await h.open(tabs: appGifTabs());
      expect(find.text('Stickers'), findsOneWidget);
      expect(find.text('GIFs'), findsOneWidget);
      expect(find.text('On this phone'), findsOneWidget);
      await h.tab('GIFs');
      expect(find.text(_askTor), findsOneWidget);
      // the answer comes after a wait like one that went out, never at once
      quietWait = () => const Duration(seconds: 3);
      await t.tap(find.text('Turn on'));
      await h.frames(30);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('d.kryfo.gif.on'), isTrue);
      expect(prefs.getBool('d.kryfo.gif.asked'), isTrue);
      expect(prefs.getBool('kryfo.gif.on'), isNull);
      expect(prefs.getBool('kryfo.gif.asked'), isNull);
      const calm = "Couldn't reach Kryfo's GIF service.";
      expect(find.text(calm), findsNothing);
      await t.pump(const Duration(seconds: 3));
      await h.frames(10);
      expect(find.text(calm), findsOneWidget);
      await t.enterText(find.byType(TextField), 'cats');
      await h.frames(40);
      expect(find.text(calm), findsNothing);
      await t.pump(const Duration(seconds: 3));
      await h.frames(10);
      expect(find.text(calm), findsOneWidget);
      expect(wire.calls, isEmpty);
      Navigator.of(h.home).pop();
      await h.frames(20);
    });

    for (final reduce in [false, true]) {
      testWidgets('off: the first visit asks once, then only says it is off'
          '${reduce ? ', reduced motion' : ''}', (t) async {
        final h = _Harness(t, lib);
        await h.pump(reduce: reduce);
        await h.open();
        await h.tab('GIFs');
        expect(find.text(_askTor), findsOneWidget);
        expect(find.text('Search GIFs, privately'), findsNothing);
        expect(find.text(_off), findsNothing);
        expect(h.asked, isTrue);
        expect(h.gifs.asked, isEmpty);

        await t.tap(find.text('Not now'));
        await h.frames(20);
        expect(find.text(_askTor), findsNothing);
        expect(find.text(_off), findsOneWidget);
        expect(find.text(_pointer, findRichText: true), findsOneWidget);
        expect(find.text('Search GIFs, privately'), findsNothing);
        // still on the gifs tab
        expect(find.text('Choose a GIF'), findsNothing);
        expect(h.saved, isEmpty);
        expect(h.gifs.asked, isEmpty);

        // the stickers and back: no second question
        await h.tab('Stickers');
        await h.tab('GIFs');
        expect(find.text(_askTor), findsNothing);
        expect(find.text(_off), findsOneWidget);

        // the next time the picker opens: no question either
        await h.close();
        await h.open();
        await h.tab('GIFs');
        expect(find.text(_askTor), findsNothing);
        expect(find.text(_off), findsOneWidget);

        await t.tap(find.text('Turn on'));
        await h.frames(30);
        expect(h.saved, [true]);
        expect(h.gifs.asked, ['@0']);
        expect(find.text(_off), findsNothing);
        expect(find.text('Trending'), findsOneWidget);
        expect(h.tile(0), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('turn on from the question shows the grid', (t) async {
      final h = _Harness(t, lib);
      await h.pump();
      await h.open();
      await h.tab('GIFs');
      expect(find.text(_askTor), findsOneWidget);
      await t.tap(find.text('Turn on'));
      await h.frames(30);
      expect(h.saved, [true]);
      expect(h.gifs.asked, ['@0']);
      expect(find.text(_askTor), findsNothing);
      expect(find.text(_off), findsNothing);
      expect(find.text('Trending'), findsOneWidget);
      expect(h.tile(0), findsOneWidget);
      expect(find.text('Powered by GIPHY'), findsOneWidget);
      expect(
        find.text('Searched through Kryfo, GIPHY never sees you.'),
        findsOneWidget,
      );
      expect(find.text('Onion · 3 hops'), findsOneWidget);
      expect(find.text('The GIF service never sees you'), findsOneWidget);
    });

    testWidgets('asked before, still off: no question, the quiet line', (
      t,
    ) async {
      final h = _Harness(t, lib)..asked = true;
      await h.pump();
      await h.open();
      await h.tab('GIFs');
      expect(find.text(_askTor), findsNothing);
      expect(find.text('Search GIFs, privately'), findsNothing);
      expect(find.text(_off), findsOneWidget);
      // where the phone's own gifs are, a tap away
      await t.tap(find.text(_pointer, findRichText: true));
      await h.frames(25);
      expect(find.text('Choose a GIF'), findsOneWidget);
      expect(h.gifs.asked, isEmpty);
    });

    testWidgets('on already: the grid, never a question', (t) async {
      final h = _Harness(t, lib)..on = true;
      await h.pump();
      await h.open();
      await h.tab('GIFs');
      expect(find.text(_askTor), findsNothing);
      expect(find.text(_off), findsNothing);
      expect(h.tile(0), findsOneWidget);
    });

    testWidgets('the question says tor only on the onion route', (t) async {
      for (final route in GifRoute.values) {
        final h = _Harness(t, lib);
        await h.pump();
        await h.open(route: route);
        await h.tab('GIFs');
        final onion = route == GifRoute.onion;
        expect(find.text(_askTor), onion ? findsOneWidget : findsNothing);
        expect(find.text(_askKryfo), onion ? findsNothing : findsOneWidget);
        await h.close();
      }
    });

    for (final quiet in [false, true]) {
      testWidgets('the app\'s own tabs ask once per identity'
          '${quiet ? ': the decoy the same' : ''}', (t) async {
        final wire = _GifLane();
        useEngineForTest(wire);
        appState.sendModeForTest = 'balanced';
        final c = quiet ? HaloContainer.decoy : HaloContainer.everyday;
        final db = HaloDb(c);
        useDatabasesForTest(HaloDb(), Session(db));
        addTearDown(() {
          final e = HaloDb();
          useDatabasesForTest(e, Session(e));
          appState.sendModeForTest = 'private';
        });
        final h = _Harness(t, lib);
        await h.pump();
        await h.open(tabs: appGifTabs());
        await h.tab('GIFs');
        expect(find.text(_askKryfo), findsOneWidget);
        expect(find.text(_askTor), findsNothing);
        await t.tap(find.text('Not now'));
        await h.frames(20);
        expect(find.text(_off), findsOneWidget);
        await h.close();
        await h.open(tabs: appGifTabs());
        await h.tab('GIFs');
        expect(find.text(_askKryfo), findsNothing);
        expect(find.text(_off), findsOneWidget);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(c.key('kryfo.gif.asked')), isTrue);
        expect(prefs.getBool(c.key('kryfo.gif.on')), isNull);
        final other = quiet ? HaloContainer.everyday : HaloContainer.decoy;
        expect(prefs.getBool(other.key('kryfo.gif.asked')), isNull);
        expect(wire.calls, isEmpty);
        await h.close();
      });
    }

    testWidgets('loading, then results; empty; error with a retry', (t) async {
      final h = _Harness(t, lib)..on = true;
      h.gifs.hold = Completer();
      await h.pump();
      await h.open();
      await h.tab('GIFs');
      expect(h.tile(0), findsNothing);
      h.gifs.hold!.complete();
      h.gifs.hold = null;
      await h.frames(20);
      expect(h.tile(0), findsOneWidget);

      h.gifs.answer = (q, _) =>
          const GifPage(provider: 'giphy', brand: 'GIPHY');
      await t.enterText(find.byType(TextField), 'zzzz');
      await h.frames(30);
      expect(find.text('No GIFs found. Try other words.'), findsOneWidget);

      // a question the relay would not take reads as nothing found
      h.gifs.answer = (q, _) => const GifPage.failed(GifError.refused);
      await t.enterText(find.byType(TextField), '!!!');
      await h.frames(30);
      expect(find.text('No GIFs found. Try other words.'), findsOneWidget);
      expect(find.text("Couldn't reach Kryfo's GIF service."), findsNothing);

      h.gifs.answer = (q, _) => const GifPage.failed(GifError.unreachable);
      await t.enterText(find.byType(TextField), 'seal');
      await h.frames(30);
      expect(find.text("Couldn't reach Kryfo's GIF service."), findsOneWidget);
      h.gifs.answer = null;
      await t.tap(find.text('Try again'));
      await h.frames(20);
      expect(h.tile(0), findsOneWidget);
      expect(h.gifs.asked.last, 'seal@0');
    });

    testWidgets('typing waits for a pause; klipy is named when it answers', (
      t,
    ) async {
      final h = _Harness(t, lib)..on = true;
      await h.pump();
      await h.open();
      await h.tab('GIFs');
      h.gifs.asked.clear();
      h.gifs.answer = (q, o) => _page(o, provider: 'klipy');
      await t.enterText(find.byType(TextField), 's');
      await t.pump(const Duration(milliseconds: 200));
      await t.enterText(find.byType(TextField), 'se');
      await t.pump(const Duration(milliseconds: 200));
      await t.enterText(find.byType(TextField), 'seal');
      expect(h.gifs.asked, isEmpty);
      await h.frames(30);
      expect(h.gifs.asked, ['seal@0']);
      expect(find.text('Powered by Klipy'), findsOneWidget);
      expect(
        find.text('Searched through Kryfo, Klipy never sees you.'),
        findsOneWidget,
      );
    });

    testWidgets('more come as the grid nears its end, from the same '
        'provider', (t) async {
      final h = _Harness(t, lib)..on = true;
      await h.pump();
      await h.open();
      await h.tab('GIFs');
      for (var i = 0; i < 12; i++) {
        await t.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await h.frames(5);
      }
      await h.frames(20);
      expect(h.gifs.asked, contains('@24/giphy'));
      expect(t.takeException(), isNull);
    });

    testWidgets('the field takes fifty code points, as the relay counts', (
      t,
    ) async {
      final h = _Harness(t, lib)..on = true;
      await h.pump();
      await h.open();
      await h.tab('GIFs');
      // a thumbs up with a skin tone is two code points, one character
      await t.enterText(find.byType(TextField), '👍🏽' * 30);
      await h.frames(30);
      final text = t.widget<TextField>(find.byType(TextField)).controller!.text;
      expect(text.runes.length, 50);
      expect(h.gifs.asked.last, '${'👍🏽' * 25}@0');
      // farsi with its joiner goes as typed
      await t.enterText(find.byType(TextField), 'گربه\u200cها');
      await h.frames(30);
      expect(h.gifs.asked.last, 'گربه\u200cها@0');
    });

    testWidgets('a tap shows which, send sends its full gif', (t) async {
      final h = _Harness(t, lib)..on = true;
      await h.pump();
      await h.open();
      await h.tab('GIFs');
      expect(find.text('Send'), findsNothing);
      await t.tap(h.tile(1));
      await h.frames(15);
      expect(find.text('Send'), findsOneWidget);
      expect(h.closed, false);
      await t.tap(find.text('Send'));
      await h.frames(20);
      expect(h.gifs.fetched, contains('$kGifRelay/gif/v1/m/f1.x'));
      final pick = h.picked;
      expect(pick, isA<GifPick>());
      expect((pick as GifPick).bytes, _gif);
    });

    testWidgets('what is not a gif is never sent', (t) async {
      final h = _Harness(t, lib)..on = true;
      await h.pump();
      await h.open();
      await h.tab('GIFs');
      h.gifs.full = Uint8List.fromList(utf8.encode('<html>'));
      await t.tap(h.tile(0));
      await h.frames(10);
      await t.tap(h.tile(0));
      await h.frames(20);
      expect(h.closed, false);
      expect(find.text("Couldn't get that GIF. Try again."), findsOneWidget);
      await h.frames(200);
    });

    testWidgets('reduced motion: stills only, everything still works', (
      t,
    ) async {
      final h = _Harness(t, lib)..on = true;
      await h.pump(reduce: true);
      await h.open();
      await h.tab('GIFs');
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await h.frames(10);
      expect(find.byType(StillFrame), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(GifPanel),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
      await t.tap(h.tile(0));
      await h.frames(5);
      await t.tap(find.text('Send'));
      await h.frames(10);
      expect(h.picked, isA<GifPick>());
    });

    testWidgets('right to left: the first gif starts on the right', (t) async {
      final h = _Harness(t, lib)..on = true;
      await h.pump(locale: const Locale('ar'));
      await h.open();
      await h.tab(lookupAppLocalizations(const Locale('ar')).gifTab);
      final first = t.getRect(h.tile(0));
      final second = t.getRect(h.tile(1));
      expect(first.left, greaterThan(second.left));
      expect(t.takeException(), isNull);
    });

    for (final ar in [false, true]) {
      testWidgets('large text on a small phone${ar ? ', arabic' : ''}', (
        t,
      ) async {
        final h = _Harness(t, lib);
        final loc = Locale(ar ? 'ar' : 'en');
        final words = lookupAppLocalizations(loc);
        await h.pump(scale: 1.6, size: const Size(360, 740), locale: loc);
        await h.open();
        await h.tab(words.gifTab);
        expect(find.text(words.gifAskOverTor(kGifBrand)), findsOneWidget);
        // the question keeps the sheet's height: its buttons scroll into view
        await t.ensureVisible(find.text(words.gifNotNow));
        await h.frames(10);
        await t.tap(find.text(words.gifNotNow));
        await h.frames(20);
        expect(find.text(words.gifSearchOff), findsOneWidget);
        await t.tap(find.text(words.gifAskTurnOn));
        await h.frames(30);
        expect(find.text(words.gifSearchHint), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  });

  group('the opt-in sheet', () {
    testWidgets('names the route honestly', (t) async {
      for (final tor in [true, false]) {
        await t.pumpWidget(
          MaterialApp(
            theme: buildHaloTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: GifOptIn(overTor: tor, onTurnOn: () {}, onNotNow: () {}),
              ),
            ),
          ),
        );
        await t.pump(const Duration(seconds: 1));
        expect(
          find.text('Searched over Tor'),
          tor ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Searched through Kryfo'),
          tor ? findsNothing : findsOneWidget,
        );
      }
    });
  });

  group('in the chat', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('gif_bubble'));
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<void> bubble(WidgetTester t, String path, {bool reduce = false}) =>
        t.pumpWidget(
          MaterialApp(
            theme: buildHaloTheme(),
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c).copyWith(disableAnimations: reduce),
              child: child!,
            ),
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    width: 240,
                    child: ChatPicture(
                      path: path,
                      child: const SizedBox(
                        key: ValueKey('playing'),
                        height: 100,
                      ),
                    ),
                  ),
                  GifSentLine(path: path),
                ],
              ),
            ),
          ),
        );

    testWidgets('a gif plays with its badge and says it went inside', (
      t,
    ) async {
      final f = File('${tmp.path}/a.jpg')..writeAsBytesSync(_gif);
      await t.runAsync(() => isGifFile(f.path));
      await bubble(t, f.path);
      await t.pump();
      expect(find.byKey(const ValueKey('playing')), findsOneWidget);
      expect(find.byType(GifBadge), findsOneWidget);
      expect(find.text('Sent inside your message'), findsOneWidget);
    });

    testWidgets('reduced motion: a still and a play mark', (t) async {
      final f = File('${tmp.path}/b.jpg')..writeAsBytesSync(_gif);
      await t.runAsync(() => isGifFile(f.path));
      await bubble(t, f.path, reduce: true);
      await t.pump();
      expect(find.byKey(const ValueKey('playing')), findsNothing);
      expect(find.byType(StillFrame), findsOneWidget);
      await t.tap(find.bySemanticsLabel('Play GIF'));
      await t.pump();
      expect(find.byKey(const ValueKey('playing')), findsOneWidget);
    });

    testWidgets('a photo stays a photo', (t) async {
      final f = File('${tmp.path}/c.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]);
      await t.runAsync(() => isGifFile(f.path));
      await bubble(t, f.path, reduce: true);
      await t.pump();
      expect(find.byKey(const ValueKey('playing')), findsOneWidget);
      expect(find.byType(GifBadge), findsNothing);
      expect(find.text('Sent inside your message'), findsNothing);
    });
  });
}

class _Wire implements GifWire {
  _Wire({this.answer});
  final String? answer;
  // held until completed: a picture still on its way
  Completer<void>? gate;
  final posts = <(String, String)>[];
  final gets = <String>[];
  final files = <String>[];

  String get _page => answer ?? jsonEncode({'provider': 'giphy', 'items': []});

  @override
  Future<String> post(String url, String body) async {
    posts.add((url, body));
    return _page;
  }

  @override
  Future<String> get(String url) async {
    gets.add(url);
    return _page;
  }

  @override
  Future<String> getFile(String url, String path) async {
    files.add(url);
    await gate?.future;
    await File(path).writeAsBytes(_gif);
    return 'ok ${_gif.length}';
  }
}
