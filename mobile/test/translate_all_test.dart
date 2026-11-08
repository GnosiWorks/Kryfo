// SPDX-License-Identifier: GPL-3.0-or-later
// translation for every language: one pack per direction, a route straight
// across or through english, the languages page with sizes and the ways
// each goes, the offer under a message with the size of what its route
// needs, wi-fi only waiting by itself, removing a language with what it
// made, and nothing at all for a language with no route
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/translate_languages_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/translate/catalog.dart';
import 'package:kryfo/translate/chat_translation.dart';
import 'package:kryfo/translate/detect.dart';
import 'package:kryfo/translate/downloads.dart';
import 'package:kryfo/translate/engine_bridge.dart';
import 'package:kryfo/translate/lang_names.dart';
import 'package:kryfo/translate/settings.dart';
import 'package:kryfo/translate/translate_bubble.dart';

import 'sqlite_ffi.dart';
import 'translate_fakes.dart';

const _ru = 'Привет, увидимся завтра на вокзале';
const _de = 'Hallo, wir sehen uns morgen am Bahnhof';

int _gz(String id) => dirCatalog.bundle(id)!.gz;

Finder _rich(String s) => find.textContaining(s, findRichText: true);

Widget _framed(Widget home, {Locale? locale}) => MaterialApp(
  theme: buildHaloTheme(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: home,
);

Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 150));
  await t.pumpAndSettle();
}

// a german reader, the message guessed as [lang]
Fakes _reader({
  String app = 'de',
  String lang = 'ru',
  Set<String> have = const {},
  bool wifiOnly = false,
  bool wifi = true,
  MemoryTranslateStore? store,
}) => fakeHub(
  app: app,
  catalog: dirCatalog,
  have: have,
  wifi: wifi,
  wifiWait: const Duration(milliseconds: 100),
  settings: TranslateSettings(wifiOnly: wifiOnly),
  store: store,
  words: {_ru: '[de] $_ru'},
  guess: (_) => LangGuess(lang, 1),
);

void main() {
  group('routes', () {
    const c = dirCatalog;
    test('straight across when a pack holds the direction', () {
      expect(c.route('de', 'en'), [('de', 'en')]);
      expect(c.route('en', 'ru'), [('en', 'ru')]);
      // the older pack that holds both
      expect(c.route('zh', 'en'), [('zh', 'en')]);
      expect(c.route('en', 'zh'), [('en', 'zh')]);
      expect(c.bundlesFor(c.route('en', 'zh')!).map((b) => b.id), ['zh']);
    });

    test('through english, needing exactly the two direction packs', () {
      expect(c.route('ru', 'de'), [('ru', 'en'), ('en', 'de')]);
      expect(c.bundlesFor(c.route('ru', 'de')!).map((b) => b.id), [
        'ru-en',
        'en-de',
      ]);
      expect(c.route('tr', 'zh'), [('tr', 'en'), ('en', 'zh')]);
    });

    test('a leg missing: no route', () {
      // no model into turkish
      expect(c.route('de', 'tr'), isNull);
      expect(c.route('en', 'tr'), isNull);
      expect(c.route('ja', 'de'), isNull);
      expect(c.route('de', 'de'), isNull);
    });

    test('bundlesFor gives what is missing', () {
      final r = c.route('ru', 'de')!;
      expect(c.bundlesFor(r, have: (id) => id == 'en-de').map((b) => b.id), [
        'ru-en',
      ]);
      expect(c.bundlesFor(r, have: (_) => true), isEmpty);
    });

    test('the ways each language goes, and its size', () {
      expect(c.waysOf('de'), LangWays.both);
      expect(c.waysOf('tr'), LangWays.intoEnglish);
      expect(c.waysOf('ja'), isNull);
      expect(c.sizeOf('ru'), _gz('ru-en') + _gz('en-ru'));
      expect(c.languages, ['de', 'ru', 'tr', 'zh']);
      expect(c.packsOf('de').map((b) => b.id), ['de-en', 'en-de']);
    });

    test('the engine answer per direction parses, the older one too', () {
      final c = TranslateCatalog.parse(
        '{"base":"http://x.onion/models/","langs":[{"lang":"de-en","gz":5,'
        '"disk":9,"pairs":["de-en"],"dirs":["deen-tiny"]},{"id":"en-de",'
        '"from":"en","to":"de","dir":"ende-tiny","gz":6,"disk":7}]}',
      )!;
      expect(c.route('de', 'en'), [('de', 'en')]);
      expect(c.bundle('en-de')!.dirs, ['ende-tiny']);
      expect(c.waysOf('de'), LangWays.both);
      expect(
        TranslateCatalog.parse(
          '{"base":"b","packs":[{"id":"x","gz":1,"disk":1,"pairs":["a-en"],'
          '"dirs":[]}]}',
        ),
        isNull,
      );
    });

    test('the shipped catalog: every app language both ways', () {
      for (final l in builtInCatalog.languages) {
        expect(builtInCatalog.packsOf(l).length, 2, reason: l);
        expect(
          builtInCatalog.route(l, 'de') ?? builtInCatalog.route(l, 'en'),
          isNotNull,
        );
      }
      expect(builtInCatalog.route('ru', 'de'), [('ru', 'en'), ('en', 'de')]);
      expect(builtInCatalog.languages, isNot(contains('zh_hant')));
    });
  });

  group('the languages page', () {
    test('the app language first, then the ones read, then by name', () {
      final (first, rest) = orderLanguages(
        dirCatalog,
        appLang: 'ru',
        mine: const ['tr', 'en', 'zh_Hant'],
      );
      expect(first, ['ru', 'tr', 'zh']);
      expect(rest, ['de']);
      // english is no download of its own
      final (f2, r2) = orderLanguages(dirCatalog, appLang: 'en', mine: []);
      expect(f2, isEmpty);
      expect(r2.toSet(), {'de', 'ru', 'tr', 'zh'});
    });

    testWidgets('sizes, the ways each goes, the order and a download', (
      t,
    ) async {
      t.view.physicalSize = const Size(800, 2400);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final f = fakeHub(
        app: 'ru',
        catalog: dirCatalog,
        settings: const TranslateSettings(wifiOnly: false, mine: ['tr']),
      );
      await f.hub.ready();
      await t.pumpWidget(_framed(TranslateLanguagesScreen(hub: f.hub)));
      await t.pumpAndSettle();
      // suggested first: the app's language, then the ones read
      final y = {
        for (final l in ['ru', 'tr', 'de', 'zh'])
          l: t.getTopLeft(find.byKey(ValueKey('lang-$l'))).dy,
      };
      expect(y['ru']!, lessThan(y['tr']!));
      expect(y['tr']!, lessThan(y['de']!));
      expect(
        t.getTopLeft(find.text(l10n.translateSuggested)).dy,
        lessThan(y['ru']!),
      );
      final more = t.getTopLeft(find.text(l10n.translateMoreLanguages)).dy;
      expect(more, greaterThan(y['tr']!));
      expect(more, lessThan(y['de']!));
      expect(find.text(l10n.translateTagApp), findsOneWidget);
      expect(find.text(l10n.translateTagRead), findsOneWidget);
      // each one's download size: its packs together
      String sized(String l) =>
          l10n.translateNotDownloaded(packSize(dirCatalog.sizeOf(l)));
      expect(find.text(sized('ru')), findsOneWidget);
      expect(find.text(sized('tr')), findsOneWidget);
      expect(sized('ru'), isNot(sized('tr')));
      // one way only says so in one line; both ways says that
      expect(
        t.widget<Text>(find.byKey(const ValueKey('ways-tr'))).data,
        l10n.translateWaysInto,
      );
      expect(
        t.widget<Text>(find.byKey(const ValueKey('ways-de'))).data,
        l10n.translateWaysBoth,
      );
      // a language with no pack is not there
      expect(find.byKey(const ValueKey('lang-ja')), findsNothing);
      expect(find.byKey(const ValueKey('lang-en')), findsNothing);

      // one tap fetches both its directions, with their progress
      await t.tap(find.byKey(const ValueKey('act-de')));
      await _settle(t);
      expect(f.backend.started.toSet(), {'de-en', 'en-de'});
      f.backend.statuses['de-en'] = FetchStatus(
        'running',
        done: _gz('de-en') ~/ 2,
        total: _gz('de-en'),
      );
      await _settle(t);
      expect(
        find.text(
          l10n.translateProgress(
            packSize(_gz('de-en') ~/ 2),
            packSize(_gz('de-en') + _gz('en-de')),
          ),
        ),
        findsOneWidget,
      );
      f.backend.finish('de-en');
      await _settle(t);
      // one in, one to go: still coming
      expect(f.hub.langState('de').phase, DlPhase.running);
      f.backend.finish('en-de');
      await _settle(t);
      expect(f.hub.langState('de').phase, DlPhase.installed);
      expect(
        find.text(
          l10n.translateInstalledShown(
            packSize(
              dirCatalog.bundle('de-en')!.disk +
                  dirCatalog.bundle('en-de')!.disk,
            ),
          ),
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });
  });

  group('the offer under a message', () {
    Future<ChatTranslation> open(WidgetTester t, Fakes f, String text) async {
      await f.hub.ready();
      final c = ChatTranslation(f.hub, 'heron');
      addTearDown(c.dispose);
      await t.pumpWidget(
        _framed(
          Scaffold(
            body: TranslatedBody(
              chat: c,
              msgKey: 'u1',
              text: text,
              original: Text(text),
              translated: (s) => Text(s),
            ),
          ),
        ),
      );
      await _settle(t);
      return c;
    }

    testWidgets('"Download <language> (<size>)?" with the route\'s total', (
      t,
    ) async {
      final f = _reader();
      await open(t, f, _ru);
      final total = packSize(_gz('ru-en') + _gz('en-de'));
      final offer = l10n.translateOfferDownload(langName('ru'), total);
      expect(_rich(offer), findsOneWidget);
      // nothing fetched without a tap
      await t.pump(const Duration(seconds: 1));
      expect(f.backend.started, isEmpty);
      // one tap: the pack sheet asks first, with both packs as one
      await t.tap(_rich(offer));
      await t.pumpAndSettle();
      expect(
        find.text(
          l10n.translatePackLineTwoShown(langName('ru'), langName('de'), total),
        ),
        findsOneWidget,
      );
      expect(f.backend.started, isEmpty);
      await t.tap(find.text(l10n.translateDownload(total)));
      await _settle(t);
      expect(f.backend.started.toSet(), {'ru-en', 'en-de'});
      f.backend.finish('ru-en');
      f.backend.finish('en-de');
      await _settle(t);
      await t.tap(find.text(l10n.commonDone));
      await t.pumpAndSettle();
      // the message the tap was for, through english
      expect(find.text('[de] [de] $_ru'), findsOneWidget);
      expect(f.translator.asked.first, startsWith('ru-en:'));
    });

    testWidgets('one leg already there: only the other counts', (t) async {
      final f = _reader(have: {'en-de'});
      await open(t, f, _ru);
      expect(
        _rich(
          l10n.translateOfferDownload(langName('ru'), packSize(_gz('ru-en'))),
        ),
        findsOneWidget,
      );
    });

    testWidgets('only the target\'s leg missing: named after it', (t) async {
      // a russian message for a german reader, russian's pack there: the
      // download is german's, and the offer says so, as the sheet does
      final f = _reader(have: {'ru-en'});
      await open(t, f, _ru);
      final size = packSize(_gz('en-de'));
      final offer = l10n.translateOfferDownload(langName('de'), size);
      expect(_rich(offer), findsOneWidget);
      await t.tap(_rich(offer));
      await t.pumpAndSettle();
      expect(
        find.text(l10n.translatePackLineShown(langName('de'), size)),
        findsOneWidget,
      );
    });

    testWidgets('everything there: the usual translate line', (t) async {
      final f = _reader(have: {'ru-en', 'en-de'});
      await open(t, f, _ru);
      expect(find.byKey(const ValueKey('tr-idle')), findsOneWidget);
      expect(find.byKey(const ValueKey('tr-offer')), findsNothing);
    });

    testWidgets('no route: nothing shown at all', (t) async {
      // turkish has no pack from english, so german cannot go into it
      final f = _reader(app: 'tr', lang: 'de');
      await open(t, f, _de);
      expect(find.byKey(const ValueKey('tr-offer')), findsNothing);
      expect(find.byKey(const ValueKey('tr-idle')), findsNothing);
      expect(find.byIcon(Icons.translate_rounded), findsNothing);
      // a language with no pack at all, the same
      final g = _reader(lang: 'ja');
      await open(t, g, 'これは日本語の文章です、また明日');
      expect(find.byIcon(Icons.translate_rounded), findsNothing);
      expect(f.backend.started, isEmpty);
    });

    testWidgets('wi-fi only: waits with a plain line, then goes by itself', (
      t,
    ) async {
      final f = _reader(wifiOnly: true, wifi: false);
      await open(t, f, _ru);
      final total = packSize(_gz('ru-en') + _gz('en-de'));
      await t.tap(_rich(l10n.translateOfferDownload(langName('ru'), total)));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.translateDownload(total)));
      await _settle(t);
      expect(find.text(l10n.translateWaitsWifi), findsOneWidget);
      expect(find.text(l10n.translateDownloadAnyway), findsOneWidget);
      expect(f.backend.started, isEmpty);
      // the sheet put away: the message says it waits
      await t.tapAt(const Offset(10, 10));
      await t.pumpAndSettle();
      expect(
        _rich(l10n.translateLineWaitsWifi(langName('ru'))),
        findsOneWidget,
      );
      await t.pump(const Duration(milliseconds: 400));
      expect(f.backend.started, isEmpty);
      // on wi-fi: it starts with no tap
      f.wifi = true;
      await t.pump(const Duration(milliseconds: 250));
      await t.pump(const Duration(milliseconds: 250));
      expect(f.backend.started.toSet(), {'ru-en', 'en-de'});
      await t.pump(const Duration(milliseconds: 150));
      expect(
        _rich(l10n.translateLineDownloading(langName('ru'))),
        findsOneWidget,
      );
      f.backend.finish('ru-en');
      f.backend.finish('en-de');
      await _settle(t);
    });

    test('a wait cancelled stops waiting', () async {
      final f = _reader(wifiOnly: true, wifi: false);
      await f.hub.ready();
      await f.hub.downloadLang('de');
      expect(f.hub.langState('de').phase, DlPhase.wifiNeeded);
      f.hub.cancelLang('de');
      expect(f.hub.langState('de').phase, DlPhase.absent);
      f.wifi = true;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(f.backend.started, isEmpty);
    });
  });

  group('remove', () {
    KeptTranslation k(String way) =>
        KeptTranslation(KeptTranslation.hashOf(way), way, 'x');

    test('frees the space and drops what was made with it', () async {
      final store = MemoryTranslateStore(
        const TranslateSettings(wifiOnly: false),
      );
      store.keptRows['heron'] = {
        'a': k('ru>de>none'),
        'b': k('de>en>none'),
        'c': k('en>de>none'),
        'd': k('ru>en>none'),
        'e': k('zh>en>none'),
      };
      final f = _reader(have: {'de-en', 'en-de', 'ru-en'}, store: store);
      await f.hub.ready();
      expect(await f.hub.removeLang('de'), isTrue);
      expect(f.backend.removed.toSet(), {'de-en', 'en-de'});
      expect(f.backend.have, {'ru-en'});
      expect(f.hub.langState('de').phase, DlPhase.absent);
      // into or out of german goes; the rest stays
      expect(store.keptRows['heron']!.keys.toSet(), {'d', 'e'});
      expect(store.settings.cuts, {'from:de': 1, 'to:de': 1});
      // a container that was shut catches up once, and only once
      store.keptRows['wren'] = {'f': k('ru>de>none')};
      store.cutDone.clear();
      await f.hub.dropKept();
      expect(store.keptRows['wren'], isEmpty);
      store.keptRows['wren'] = {'g': k('ru>de>none')};
      await f.hub.dropKept();
      expect(store.keptRows['wren']!.keys, ['g']);
    });

    test('an open chat lets go of what it showed with it', () async {
      final f = _reader(have: {'ru-en', 'en-de'});
      await f.hub.ready();
      final c = ChatTranslation(f.hub, 'heron');
      addTearDown(c.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(await c.toggle('u1', _ru), isNull);
      expect(c.shown('u1', _ru), isTrue);
      await f.hub.removeLang('de');
      await Future<void>.delayed(Duration.zero);
      expect(c.shown('u1', _ru), isFalse);
      expect(c.of('u1', _ru).text, isNull);
      // the offer is back, for what is now missing
      expect(f.hub.missing(c.offer(_ru)!).map((b) => b.id), ['en-de']);
    });

    final skip = SqliteMem.open() == null ? 'no sqlite on this host' : null;
    test('in the database: by way, once per removal', () async {
      final db = SqliteMem.open()!;
      await appSchemaOn(db);
      await db.insert('contacts', {
        'halo_id': 'heron',
        'onion': '',
        'xpub': 'ab',
        'first_seen': 1,
        'last_seen': 1,
      });
      final store = DbTranslateStore(() async => db);
      final ways = ['ru>de>none', 'de>en>none', 'ru>en>none', 'en>zh>tw'];
      for (final (i, w) in ways.indexed) {
        await db.insert('messages', {
          'peer_id': 'heron',
          'direction': 'in',
          'plaintext': w,
          'sent_at': 1,
          'msg_uid': 'u$i',
        });
        await store.keep('heron', 'u$i', k(w), w);
      }
      await store.dropKept(0, cuts: {'from:de': 1, 'to:de': 1});
      expect((await store.kept('heron')).keys.toSet(), {'u2', 'u3'});
      await store.keep('heron', 'u0', k(ways[0]), ways[0]);
      // asked again with the same counts: nothing more goes
      await store.dropKept(0, cuts: {'from:de': 1, 'to:de': 1});
      expect((await store.kept('heron')).keys.toSet(), {'u0', 'u2', 'u3'});
      // a cut that is not a language takes nothing
      await store.dropKept(0, cuts: {'to:*': 1, 'from:ru>x': 1});
      expect((await store.kept('heron')).length, 3);
    }, skip: skip);
  });
}
