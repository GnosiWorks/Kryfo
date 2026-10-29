// SPDX-License-Identifier: GPL-3.0-or-later
// the 0.6 onboarding: five steps by name, play and foss apart, the @name step
// skipped by default, the invite text with a page link and the download page,
// and a message typed while tor starts reads as sending
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/handle_claim.dart';
import 'package:kryfo/invite_share.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/link_view.dart';
import 'package:kryfo/main.dart'
    show
        HaloDb,
        HaloEngine,
        appState,
        parseHaloUri,
        useDatabasesForTest,
        useEngineForTest,
        AppStateRoute,
        AppStateProfile;
import 'package:kryfo/rooms.dart' show firstKryfoLink;
import 'package:kryfo/screens/onboarding_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';

final _v3 =
    'kryfo://share?id=amber-river-lantern&onion=abc.onion&v=3'
    '&bundle=AAEC%2Bw%3D%3D&fc=${'ab' * 32}';

// a v3 link as the app builds it, the card with the kyber prekey
String _fullV3() {
  String b(int n) => base64Encode(List.generate(n, (i) => (i * 37 + n) & 255));
  final card = base64Encode(
    utf8.encode(
      jsonEncode({
        'registrationId': 16380,
        'deviceId': 1,
        'preKeyId': 16777215,
        'preKeyPublic': b(33),
        'signedPreKeyId': 1,
        'signedPreKeyPublic': b(33),
        'signedPreKeySignature': b(64),
        'kyberPreKeyId': 16777215,
        'kyberPreKeyPublic': b(1569),
        'kyberPreKeySignature': b(64),
        'identityKey': b(33),
      }),
    ),
  );
  return 'kryfo://share?id=coconut-umbrella-squirrel&onion=${'a' * 56}.onion'
      '&v=3&bundle=$card&fc=${'ab' * 32}';
}

Widget _framed(Widget home) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: home,
);

void main() {
  group('the steps', () {
    test('five, in order, the same count on play and foss', () {
      expect(onboardingSteps(play: false), [
        OnboardStep.welcome,
        OnboardStep.identity,
        OnboardStep.name,
        OnboardStep.notify,
        OnboardStep.invite,
      ]);
      expect(onboardingSteps(play: true), [
        OnboardStep.welcome,
        OnboardStep.identity,
        OnboardStep.name,
        OnboardStep.delivery,
        OnboardStep.invite,
      ]);
    });
  });

  group('the invite text', () {
    test('the page link carries the kryfo link\'s query after the #', () {
      final web = webInviteOf(_v3)!;
      expect(web, 'https://relay.kryfo.app/i#${_v3.substring(14)}');
      expect(kryfoInviteOf(web), _v3);
      expect(webInviteOf('kryfo://room?x=1'), isNull);
      expect(webInviteOf('https://example.com/?a'), isNull);
    });

    test('a page link reads as the invite, alone or in a whole message', () {
      final web = webInviteOf(_v3)!;
      expect(parseHaloUri(web)?['id'], 'amber-river-lantern');
      expect(parseHaloUri(web)?['v'], '3');
      final pasted = 'Add me\n$web\n\nGet it: https://kryfo.app/download';
      expect(kryfoInviteOf(pasted), contains(_v3));
      expect(kryfoInviteOf(pasted), contains('https://kryfo.app/download'));
      // the ? form earlier builds of 0.6 wrote
      final older = 'https://relay.kryfo.app/i?${_v3.substring(14)}';
      expect(kryfoInviteOf(older), _v3);
      expect(kryfoInviteOf('($older)'), '($_v3)');
    });

    test('real sizes: a v3 with the kyber key, a v4 link', () {
      final v3 = _fullV3();
      expect(v3.length, greaterThan(3500));
      final web = webInviteOf(v3)!;
      expect(kryfoInviteOf(web), v3);
      expect(parseHaloUri(web)?['id'], 'coconut-umbrella-squirrel');
      final v4 =
          'kryfo://share?v=4&i='
          '${base64Url.encode(List.filled(2460, 0xfb)).replaceAll('=', '')}';
      final web4 = webInviteOf(v4)!;
      expect(web4, startsWith('https://relay.kryfo.app/i#v=4&i='));
      expect(kryfoInviteOf('Tap: $web4\nthanks'), 'Tap: $v4\nthanks');
    });

    test('only a link of its own: lookalikes and links inside others stay', () {
      final q = _v3.substring(14);
      for (final s in [
        'https://evil.example/r?u=https://relay.kryfo.app/i#$q',
        'https://evil.example/r?u=https://relay.kryfo.app/i?$q',
        'http://relay.kryfo.app/i?$q',
        'https://evil.example/https://relay.kryfo.app/i#$q',
        'xhttps://relay.kryfo.app/i#$q',
        'http://relay.kryfo.app/i#$q',
        'https://relay.kryfo.app/i/#$q',
        'https://relay.kryfo.app/i/?$q',
        'https://relay.kryfo.app/ix#$q',
        'https://relay.kryfo.app.evil/i#$q',
        'https://user@relay.kryfo.app/i#$q',
        'https://relay.kryfo.app:443/i#$q',
        'https://evilrelay.kryfo.app/i#$q',
      ]) {
        expect(kryfoInviteOf(s), s, reason: s);
        expect(parseHaloUri(s), isNull, reason: s);
      }
    });

    test('a right-to-left share text reads back as the invite', () {
      setL10nLocale(const Locale('ar'));
      addTearDown(() => setL10nLocale(const Locale('en')));
      final s = inviteShareText('amber-river-lantern', _v3, lang: 'ar');
      expect(s, contains('\u2068https://relay.kryfo.app/i#'));
      expect(firstKryfoLink(kryfoInviteOf(s)), _v3);
    });

    test('the share text: the name, the page and the download page', () {
      setL10nLocale(const Locale('en'));
      final s = inviteShareText('amber-river-lantern', _v3, lang: 'en');
      expect(s, contains('amber-river-lantern'));
      expect(s, contains(webInviteOf(_v3)!));
      expect(s, contains('https://kryfo.app/download'));
      expect(s, isNot(contains('kryfo://')));
      // the page and the download link each on a line of their own
      final lines = s.split('\n');
      expect(lines, contains(webInviteOf(_v3)));
      expect(lines, contains('https://kryfo.app/download'));
    });

    test('in another language: its download page', () {
      setL10nLocale(const Locale('de'));
      addTearDown(() => setL10nLocale(const Locale('en')));
      final s = inviteShareText('amber-river-lantern', _v3, lang: 'de');
      expect(s, contains('https://kryfo.app/de/download'));
      expect(s, contains(webInviteOf(_v3)!));
    });
  });

  group('the @name step', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final db = _Db();
      useDatabasesForTest(db, Session(db));
      useEngineForTest(_Engine());
      appState.myId = 'amber-river-lantern-x';
      appState.sendModeForTest = 'private';
    });

    Future<PageController> toName(WidgetTester t) async {
      t.view.physicalSize = const Size(411, 891) * 2;
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(
        () => m.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await t.pumpWidget(
        _framed(OnboardingScreen(appState: appState, onComplete: () {})),
      );
      final pages = t.widget<PageView>(find.byType(PageView)).controller!;
      pages.jumpToPage(2);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      return pages;
    }

    testWidgets('skip is the way on, and moves to the next step', (t) async {
      final pages = await toName(t);
      expect(find.text(l10n.onboardingNameLine), findsOneWidget);
      // skip is the main button: the amber one
      expect(find.text(l10n.onboardingNameSkip), findsOneWidget);
      expect(find.textContaining('@wren'), findsNothing);
      await t.tap(find.text(l10n.onboardingNameSkip));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(pages.page, 3);
      expect(appState.myHandle, isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a free name: claiming leads, skipping stays under it', (
      t,
    ) async {
      final pages = await toName(t);
      await t.enterText(find.byType(TextField), 'Wren');
      await t.pump();
      expect(find.text(l10n.handleChecking), findsOneWidget);
      await t.pump(const Duration(milliseconds: 600));
      await t.pump();
      expect(find.text(l10n.handleAvailable), findsOneWidget);
      expect(find.text(l10n.onboardingNameClaim('wren')), findsOneWidget);
      expect(find.text(l10n.onboardingNameSkip), findsOneWidget);
      // the same checks as the handle screen: a bad shape never asks
      await t.enterText(find.byType(TextField), 'w!');
      await t.pump();
      expect(find.text(l10n.handleNameRule), findsOneWidget);
      expect(find.text(l10n.onboardingNameClaim('w!')), findsNothing);
      await t.tap(find.text(l10n.onboardingNameSkip));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(pages.page, 3);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('no new key once an @name is claimed, also after a restart', (
      t,
    ) async {
      final pages = await toName(t);
      pages.jumpToPage(1);
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      expect(find.text(l10n.onboardingTryAnother), findsOneWidget);
      // claimed on the name step, then back here
      await appState.setMyHandle('wren');
      addTearDown(() => appState.setMyHandle(null));
      await t.pump();
      expect(find.text(l10n.onboardingTryAnother), findsNothing);
      expect(find.text(l10n.onboardingUseThisName), findsOneWidget);
      // the app gone and back: setup from the start, the handle kept
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        _framed(OnboardingScreen(appState: appState, onComplete: () {})),
      );
      t.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(1);
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      expect(find.text(l10n.onboardingUseThisName), findsOneWidget);
      expect(find.text(l10n.onboardingTryAnother), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    test('a claim waits for the invite with its onion', () async {
      expect(claimInvite, readyInvite);
      var gate = Completer<String?>();
      claimInvite = () => gate.future;
      addTearDown(() => claimInvite = readyInvite);
      addTearDown(() => appState.setMyHandle(null));
      _Engine.claims.clear();
      final c = HandleClaimer(TextEditingController(text: 'wren'))
        ..state = 'free';
      var done = c.claim();
      await pumpEventQueue();
      expect(_Engine.claims, isEmpty);
      gate.complete(_v3);
      expect(await done, 'ok');
      expect(_Engine.claims, ['wren $_v3']);
      expect(appState.myHandle, 'wren');
      // none in time: nothing goes to the registry
      await appState.setMyHandle(null);
      gate = Completer<String?>();
      c.state = 'free';
      done = c.claim();
      gate.complete(null);
      expect(await done, isNot('ok'));
      expect(_Engine.claims, hasLength(1));
      expect(appState.myHandle, isNull);
    });
  });

  group('a message typed while tor starts', () {
    LinkView link(LinkKind k) =>
        LinkView(kind: k, status: TorStatus.starting, pct: 10);

    test('reads as sending while tor comes up, failed once it is down', () {
      for (final k in [LinkKind.connecting, LinkKind.climbing]) {
        expect(
          sendReadsBlocked(online: true, torReady: false, link: link(k)),
          isFalse,
          reason: '$k',
        );
      }
      expect(
        sendReadsBlocked(
          online: true,
          torReady: false,
          link: link(LinkKind.off),
        ),
        isTrue,
      );
      expect(
        sendReadsBlocked(
          online: false,
          torReady: false,
          link: link(LinkKind.connecting),
        ),
        isTrue,
      );
      expect(
        sendReadsBlocked(
          online: true,
          torReady: true,
          link: link(LinkKind.ready),
        ),
        isFalse,
      );
    });
  });
}

class _Db implements HaloDb {
  @override
  HaloContainer get container => HaloContainer.everyday;
  @override
  Future<void> saveIdentity(String id, String edPriv, String xPriv) async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Engine implements HaloEngine {
  static final claims = <String>[];
  @override
  Future<String> handleCheck(String h) async => 'free';
  @override
  Future<String> handleClaim(String h, String invite, String bio) async {
    claims.add('$h $invite');
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
