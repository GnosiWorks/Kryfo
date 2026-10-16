// SPDX-License-Identifier: GPL-3.0-or-later
// people search goes over tor or not at all, on every route. with tor not
// up a plain line takes the place of the wait or the error and leads to the
// qr and link ways in; tor coming up asks again. a slow but working tor
// says it is still reaching the registry, and a ready one searches as
// before. on balanced and fast it is tor that counts, not the direct route.
// nothing in the app or the engine reaches the registry any other way
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        HaloDb,
        HaloEngine,
        appState,
        handleHaloUriAdded,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/screens/search_screen.dart';
import 'package:kryfo/search.dart' show SearchKind;
import 'package:kryfo/session.dart';
import 'package:kryfo/widgets/halo_bar.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';

class _Db implements HaloDb {
  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<List<Map<String, Object?>>> contacts() async => [];
  @override
  Future<List<Map<String, Object?>>> searchMessages(
    String? match,
    SearchKind kind, {
    int limit = 300,
  }) async => [];
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('the stand-in was asked for ${i.memberName}');
}

// the registry over tor: every ask is counted, and answered when told
class _Engine implements HaloEngine {
  final asks = <String>[];
  Completer<String>? held;
  @override
  Future<String> torPost(String url, String body) {
    asks.add(url);
    final h = held;
    if (h != null) return h.future;
    return Future.value('{"results":[{"handle":"wren","name":"Wren"}]}');
  }

  @override
  Future<String> torGetJson(String url) async {
    asks.add(url);
    return 'error: status 404';
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

Widget _host() => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const SearchScreen(),
);

void main() {
  late _Engine engine;
  late Directory docs;

  setUp(() {
    // a debug build first looks for a canned answer in its documents
    docs = Directory.systemTemp.createTempSync('people_needs_tor');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => docs.path,
        );
    SharedPreferences.setMockInitialValues({});
    engine = _Engine();
    useEngineForTest(engine);
    final db = _Db();
    useDatabasesForTest(db, Session(db));
    appState.sendModeForTest = 'private';
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    docs.deleteSync(recursive: true);
    appState.setTorStatusForTest(TorStatus.off);
    appState.setRouteOKForTest(false);
    appState.sendModeForTest = 'balanced';
  });

  // [route]: the engine's verdict on the send route, tor's own on onion
  void tor(bool up, {bool? route}) {
    appState.setTorStatusForTest(up ? TorStatus.reachable : TorStatus.starting);
    appState.setRouteOKForTest(route ?? up);
  }

  Future<void> open(WidgetTester t) async {
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    m.setMockMethodCallHandler(SystemChannels.textInput, (_) async => null);
    addTearDown(() {
      m.setMockMethodCallHandler(SystemChannels.platform, null);
      m.setMockMethodCallHandler(SystemChannels.textInput, null);
    });
    await t.pumpWidget(_host());
    await t.pump(const Duration(seconds: 1));
  }

  // file reads finish outside the test's clock
  Future<void> rest(WidgetTester t, [int beats = 4]) async {
    for (var i = 0; i < beats; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  // typed with an @: asked of the registry once the typing rests
  Future<void> ask(WidgetTester t) async {
    await t.enterText(find.byType(TextField), '@wren');
    await t.pump(const Duration(milliseconds: 700));
    await rest(t);
  }

  // a loaded machine can need more beats than rest gives before the ask lands
  Future<void> asked(WidgetTester t) async {
    for (var i = 0; i < 100 && engine.asks.isEmpty; i++) {
      await rest(t, 1);
    }
    await rest(t);
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  }

  testWidgets('tor not up: a plain line, and nothing goes out', (t) async {
    tor(false);
    await open(t);
    await ask(t);
    expect(find.text(l10n.handleSearchNeedsTor), findsOneWidget);
    expect(find.byType(HaloBar), findsNothing);
    expect(find.text(l10n.searchPeopleOffline), findsNothing);
    expect(engine.asks, isEmpty);
    await close(t);
  });

  testWidgets('the line leads to the qr and link ways in', (t) async {
    tor(false);
    await open(t);
    await ask(t);
    await t.tap(find.text(l10n.handleSearchNeedsTor));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text(l10n.appAddSomeone), findsOneWidget);
    await close(t);
  });

  testWidgets('tor coming up asks again, over tor', (t) async {
    tor(false);
    await open(t);
    await ask(t);
    expect(engine.asks, isEmpty);
    tor(true);
    await t.pump();
    await rest(t);
    expect(engine.asks, hasLength(1));
    expect(find.text(l10n.handleSearchNeedsTor), findsNothing);
    expect(find.text('@wren'), findsWidgets);
    await close(t);
  });

  testWidgets('a slow tor says it is still reaching the registry', (t) async {
    tor(true);
    engine.held = Completer<String>();
    await open(t);
    await ask(t);
    expect(find.byType(HaloBar), findsOneWidget);
    expect(find.text(l10n.handleStillReaching), findsNothing);
    await t.pump(const Duration(seconds: 10));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.handleStillReaching), findsOneWidget);
    expect(find.text(l10n.handleSearchNeedsTor), findsNothing);
    engine.held!.complete('{"results":[{"handle":"wren","name":"Wren"}]}');
    await rest(t);
    expect(find.text(l10n.handleStillReaching), findsNothing);
    expect(find.text('@wren'), findsWidgets);
    await close(t);
  });

  testWidgets('tor ready: it searches as before', (t) async {
    tor(true);
    await open(t);
    await ask(t);
    await asked(t);
    expect(engine.asks.single, endsWith('/handle/search'));
    expect(find.text(l10n.handleSearchNeedsTor), findsNothing);
    expect(find.text('@wren'), findsWidgets);
    await close(t);
  });

  for (final mode in ['private', 'balanced', 'fast']) {
    group('on $mode', () {
      setUp(() => appState.sendModeForTest = mode);

      testWidgets('tor down shows the plain line, the direct route up or not', (
        t,
      ) async {
        // off onion the route's relays can be up with tor still starting
        tor(false, route: mode != 'private');
        await open(t);
        await ask(t);
        expect(find.text(l10n.handleSearchNeedsTor), findsOneWidget);
        expect(engine.asks, isEmpty);
        await close(t);
      });

      testWidgets('tor up searches, the direct route up or not', (t) async {
        // off onion tor carries the search while the direct route is down
        tor(true, route: mode == 'private');
        await open(t);
        await ask(t);
        await asked(t);
        expect(engine.asks.single, endsWith('/handle/search'));
        expect(find.text(l10n.handleSearchNeedsTor), findsNothing);
        expect(find.text('@wren'), findsWidgets);
        await close(t);
      });

      test('adding by a handle with tor down says the line', () async {
        tor(false, route: mode != 'private');
        final (line, added) = await handleHaloUriAdded('@wren');
        expect(line, l10n.handleSearchNeedsTor);
        expect(added, isFalse);
        expect(engine.asks, isEmpty);
      });
    });
  }

  test('nothing reaches the registry but through tor', () {
    // no http of its own anywhere in the app: every request is the engine's
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      expect(src, isNot(contains('HttpClient(')), reason: f.path);
      expect(src, isNot(contains("import 'package:http/")), reason: f.path);
    }
    // people search asks through the engine's tor post only
    final search = File('lib/screens/search_screen.dart').readAsStringSync();
    final post = search.substring(
      search.indexOf('Future<String> _peoplePost('),
      search.indexOf('void _openPerson('),
    );
    expect(post, contains('return engine.torPost(url, body);'));
    expect(RegExp(r'engine\.\w+\(').allMatches(post).length, 1);
    // a handle's lookup goes the same way
    final main = File('lib/app/links.dart').readAsStringSync();
    expect(main, contains('_torGetJsonOnIsolate,\n      idOf:'));
    // in the engine the registry, search and badge calls take the services
    // client, built from tor's socks port whatever the route
    String fn(String src, String head) {
      final at = src.indexOf(head);
      expect(at, isNonNegative, reason: head);
      return src.substring(at, src.indexOf('\n}\n', at));
    }

    final nostr = File('../engine/nostr.go').readAsStringSync();
    for (final head in ['func torPost(', 'func torGetJSON(']) {
      final body = fn(nostr, head);
      expect(body, contains('servicesClient(ctx)'), reason: head);
      expect(body, isNot(contains('torNostrClientFor')), reason: head);
      expect(body, isNot(contains('directNostrClient')), reason: head);
    }
    final handle = File('../engine/handle.go').readAsStringSync();
    final reg = fn(handle, 'var handleHTTP = func()');
    expect(reg, contains('servicesClient(ctx)'));
    expect(reg, isNot(contains('torNostrClientFor')));
    final services = File('../engine/services.go').readAsStringSync();
    expect(
      fn(services, 'func servicesClient('),
      contains('servicesTorClient()'),
    );
    final client = fn(services, 'func servicesTorClient(');
    expect(client, contains('torDialerAs('));
    expect(client, contains('torLaneClient('));
    expect(client, contains('return nil, fmt.Errorf("tor not started")'));
    // no mode decides anything in it, and nothing plain is built
    for (final bad in [
      'directNostrClient',
      'modeNeedsTor',
      'currentMode',
      'torNostrClientFor',
      'http.DefaultClient',
      'net.Dialer',
    ]) {
      expect(client, isNot(contains(bad)), reason: bad);
    }
    // and no other engine code hands the services lane a route's client
    for (final f in Directory('../engine').listSync()) {
      if (f is! File ||
          !f.path.endsWith('.go') ||
          f.path.endsWith('_test.go')) {
        continue;
      }
      final src = f.readAsStringSync();
      expect(
        src,
        isNot(contains('torNostrClientFor(laneServices)')),
        reason: f.path,
      );
    }
  });
}
