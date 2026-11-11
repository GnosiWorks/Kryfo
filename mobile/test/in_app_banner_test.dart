// SPDX-License-Identifier: GPL-3.0-or-later
// the in-app banner: shows only in front, open, out of the decoy, off the
// chat on screen, unmuted, and a hidden chat's only in its open vault. it
// drops in, a tap opens its chat, a swipe up or four seconds send it away,
// more from one chat count up in place, the lock takes it at once, and with
// reduced motion it only fades
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/in_app_banner.dart';

final _nav = GlobalKey<NavigatorState>();

Widget _app({bool still = false, TextDirection dir = TextDirection.ltr}) =>
    MaterialApp(
      navigatorKey: _nav,
      theme: buildHaloTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (ctx, c) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
        child: Directionality(textDirection: dir, child: c!),
      ),
      home: const Scaffold(body: Center(child: Text('a chat'))),
    );

const _lena = BannerNote(
  chat: 'calm-river-lamp',
  title: 'Lena',
  body: 'See you at nine',
  avatarSeed: 'calm-river-lamp',
);

void main() {
  final opened = <String>[];
  setUp(() {
    opened.clear();
    bannerOverlay = () => _nav.currentState?.overlay;
    bannerOpens = (chat) async => opened.add(chat);
    haloClearBanner = clearInAppBanner;
  });
  tearDown(clearInAppBanner);

  group('when it fits', () {
    bool fits({
      bool inFront = true,
      bool locked = false,
      bool quiet = false,
      bool reading = false,
      bool muted = false,
      bool inVault = false,
      bool hiddenChat = false,
    }) => bannerFits(
      inFront: inFront,
      locked: locked,
      quiet: quiet,
      reading: reading,
      muted: muted,
      inVault: inVault,
      hiddenChat: hiddenChat,
    );
    test('in front and open, another chat', () => expect(fits(), isTrue));
    test('in the background the phone rings instead', () {
      expect(fits(inFront: false), isFalse);
    });
    test('never over the lock, never in the decoy', () {
      expect(fits(locked: true), isFalse);
      expect(fits(quiet: true), isFalse);
    });
    test('not the chat on screen, not a muted one', () {
      expect(fits(reading: true), isFalse);
      expect(fits(muted: true), isFalse);
    });
    test('a hidden chat only in its open vault, and in the vault only its '
        'own', () {
      expect(fits(hiddenChat: true), isFalse);
      expect(fits(hiddenChat: true, inVault: true), isTrue);
      expect(fits(inVault: true), isFalse);
    });
  });

  testWidgets('it drops in with who and what, a tap opens the chat', (t) async {
    await t.pumpWidget(_app());
    showInAppBanner(_lena);
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    // on its way in from above
    final y = t.getTopLeft(find.text('Lena')).dy;
    await t.pump(const Duration(milliseconds: 300));
    expect(t.getTopLeft(find.text('Lena')).dy, greaterThan(y));
    expect(find.text('See you at nine'), findsOneWidget);
    await t.tap(find.text('Lena'));
    await t.pumpAndSettle();
    expect(opened, ['calm-river-lamp']);
    expect(find.text('Lena'), findsNothing);
    expect(bannerUp, isFalse);
  });

  testWidgets('a swipe up sends it away; left alone it goes after four '
      'seconds', (t) async {
    await t.pumpWidget(_app());
    showInAppBanner(_lena);
    await t.pumpAndSettle();
    await t.drag(find.text('Lena'), const Offset(0, -60));
    await t.pumpAndSettle();
    expect(find.text('Lena'), findsNothing);
    expect(opened, isEmpty);
    showInAppBanner(_lena);
    await t.pump();
    await t.pump(const Duration(seconds: 3));
    expect(find.text('Lena'), findsOneWidget);
    await t.pump(kBannerStays);
    await t.pumpAndSettle();
    expect(find.text('Lena'), findsNothing);
  });

  testWidgets('more from the same chat count up in place; another chat '
      'takes its place', (t) async {
    await t.pumpWidget(_app());
    showInAppBanner(_lena);
    await t.pumpAndSettle();
    showInAppBanner(_lena);
    showInAppBanner(_lena);
    await t.pumpAndSettle();
    expect(find.text(l10n.bannerNewMessages(3)), findsOneWidget);
    expect(find.text('Lena'), findsOneWidget);
    showInAppBanner(
      const BannerNote(
        chat: 'group:g1',
        title: 'Hikers',
        body: 'Ari: hi',
        avatarSeed: 'g1',
        group: true,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Hikers'), findsOneWidget);
    expect(find.text('Ari: hi'), findsOneWidget);
    expect(find.text('Lena'), findsNothing);
  });

  testWidgets('the lock takes it at once', (t) async {
    await t.pumpWidget(_app());
    showInAppBanner(_lena);
    await t.pumpAndSettle();
    haloClearToasts();
    await t.pump();
    expect(find.text('Lena'), findsNothing);
    expect(bannerUp, isFalse);
  });

  testWidgets('a line that names no one shows no face', (t) async {
    await t.pumpWidget(_app());
    showInAppBanner(
      BannerNote(chat: 'x', title: l10n.notificationsNewMessage, body: ''),
    );
    await t.pumpAndSettle();
    expect(find.text(l10n.notificationsNewMessage), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    final sem = t.ensureSemantics();
    await t.pump();
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(l10n.bannerOpen))),
      findsOneWidget,
    );
    sem.dispose();
  });

  testWidgets('reduced motion: it fades, it does not drop', (t) async {
    await t.pumpWidget(_app(still: true));
    showInAppBanner(_lena);
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    final y = t.getTopLeft(find.text('Lena')).dy;
    await t.pumpAndSettle();
    expect(t.getTopLeft(find.text('Lena')).dy, y);
  });

  testWidgets('right to left, large text: the face on the right, nothing '
      'overflows', (t) async {
    t.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(_app(dir: TextDirection.rtl));
    showInAppBanner(
      const BannerNote(
        chat: 'calm-river-lamp',
        title: 'ليلى من مجموعة المشي الطويلة جدا',
        body: 'نلتقي عند المحطة في التاسعة تماما من فضلك',
        avatarSeed: 'calm-river-lamp',
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final title = t.getRect(find.text('ليلى من مجموعة المشي الطويلة جدا'));
    expect(
      title.right,
      lessThan(t.view.physicalSize.width / t.view.devicePixelRatio - 40),
    );
  });
}
