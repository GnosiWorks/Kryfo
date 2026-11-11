// SPDX-License-Identifier: GPL-3.0-or-later
// the app's own banner call: with previews off it names no one and says
// nothing of the message, with them on it shows who and what; a message
// request shows only with "Pop-ups for message requests" on; in the
// background nothing shows
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart' show AppIo;
import 'package:kryfo/notifications.dart' show setHideNotifContent;
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/in_app_banner.dart';
import 'package:kryfo/widgets/kryfo_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _nav = GlobalKey<NavigatorState>();

const _lena = BannerNote(
  chat: 'calm-river-lamp',
  title: 'Lena',
  body: 'See you at nine',
  avatarSeed: 'calm-river-lamp',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    lockState.openForTest();
    bannerOverlay = () => _nav.currentState?.overlay;
  });
  tearDown(clearInAppBanner);

  Future<void> app(WidgetTester t) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpWidget(
      MaterialApp(
        navigatorKey: _nav,
        theme: buildHaloTheme(),
        home: const Scaffold(body: Text('a chat')),
      ),
    );
  }

  testWidgets('previews off: "New message", no name, no face, no words', (
    t,
  ) async {
    await app(t);
    await setHideNotifContent(true);
    expect(await const AppIo().banner(_lena, hidden: false), isTrue);
    await t.pumpAndSettle();
    expect(find.text(l10n.notificationsNewMessage), findsOneWidget);
    expect(find.text('Lena'), findsNothing);
    expect(find.text('See you at nine'), findsNothing);
    expect(find.byType(KryfoAvatar), findsNothing);
  });

  testWidgets('previews on: who and what', (t) async {
    await app(t);
    await setHideNotifContent(false);
    expect(await const AppIo().banner(_lena, hidden: false), isTrue);
    await t.pumpAndSettle();
    expect(find.text('Lena'), findsOneWidget);
    expect(find.text('See you at nine'), findsOneWidget);
    expect(find.byType(KryfoAvatar), findsOneWidget);
  });

  testWidgets('a request follows its pop-ups switch', (t) async {
    await app(t);
    await setHideNotifContent(false);
    final prefs = await SharedPreferences.getInstance();
    final k = HaloContainer.everyday.key('kryfo.requests.popups');
    await prefs.setBool(k, false);
    expect(
      await const AppIo().banner(_lena, hidden: false, request: true),
      isFalse,
    );
    await prefs.setBool(k, true);
    expect(
      await const AppIo().banner(_lena, hidden: false, request: true),
      isTrue,
    );
  });

  testWidgets('in the background nothing shows', (t) async {
    await app(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(await const AppIo().banner(_lena, hidden: false), isFalse);
    await t.pump();
    expect(bannerUp, isFalse);
  });
}
