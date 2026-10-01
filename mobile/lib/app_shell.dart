// SPDX-License-Identifier: GPL-3.0-or-later
// the app's MaterialApp, shared with the lock's tests so they pump exactly
// what the app runs
import 'package:flutter/material.dart';

import 'back_on_top.dart';
import 'l10n/app_localizations.dart';
import 'lock_layer.dart';
import 'theme.dart';

MaterialApp haloAppShell({
  required GlobalKey<NavigatorState> navigatorKey,
  required Widget home,
  // the lock, around the navigator
  required Widget Function(Widget navigator) lock,
  Locale? locale,
}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    // a chat under one that closes takes the screen back
    navigatorObservers: [pageRoutes],
    // back reaches android through the lock, which keeps it while it is up
    onNavigationNotification: lockBack.navigation,
    scaffoldMessengerKey: haloMessengerKey,
    title: 'Kryfo',
    // the debug banner is drawn above everything, the lock too
    debugShowCheckedModeBanner: false,
    theme: buildHaloTheme(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    // one place for the two accessibility settings everything else should
    // obey. clamped rather than uncapped: past 1.6 the chat bubbles stop
    // being readable, which helps nobody.
    builder: (ctx, child) {
      final mq = MediaQuery.of(ctx);
      return MediaQuery(
        data: mq.copyWith(
          textScaler: mq.textScaler.clamp(
            minScaleFactor: 0.85,
            maxScaleFactor: 1.6,
          ),
        ),
        // the lock sits here, above the navigator, so it covers every
        // screen, sheet, menu and toast. nothing may go between this
        // MediaQuery and the lock.
        child: lock(child ?? const SizedBox.shrink()),
      );
    },
    // one scroll feel everywhere: ios-style rubber-band on every platform,
    // no stretch-glow
    scrollBehavior: const HaloScrollBehavior(),
    home: home,
  );
}

class HaloScrollBehavior extends ScrollBehavior {
  const HaloScrollBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, _) =>
      child; // no glow, the bounce is the feedback
}
