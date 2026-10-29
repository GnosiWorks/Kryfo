// SPDX-License-Identifier: GPL-3.0-or-later
// the 0.6 onboarding: five steps by name, play and foss apart, the @name step
// skipped by default, the invite text with a page link and the download page,
// and a message typed while tor starts reads as sending
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
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
import 'package:kryfo/screens/onboarding_screen.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';

final _v3 =
    'kryfo://share?id=amber-river-lantern&onion=abc.onion&v=3'
    '&bundle=AAEC%2Bw%3D%3D&fc=${'ab' * 32}';

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
    test('the page link carries the kryfo link\'s query as it is', () {
      final web = webInviteOf(_v3)!;
      expect(web, startsWith('https://relay.kryfo.app/i?'));
      expect(web.substring(web.indexOf('?')), _v3.substring(_v3.indexOf('?')));
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
      // another host is left as it came
      const other = 'https://relay.kryfo.app.evil/i?id=a';
      expect(kryfoInviteOf(other), other);
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
  @override
  Future<String> handleCheck(String h) async => 'free';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
