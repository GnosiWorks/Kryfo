// SPDX-License-Identifier: GPL-3.0-or-later
// app_shell.dart - the app's MaterialApp, in one place for the app and its
// tests: the lock's tests pump exactly what the app runs, so anything that
// one day goes between the navigator and the lock shows up in them.
import 'package:flutter/material.dart';

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
    // what the navigator says about back goes to android through the lock:
    // while it is up, back is dart's, and goes nowhere
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
    // obey. clamped rather than uncapped - past 1.6 the chat bubbles stop
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
        // the lock sits here, above the navigator itself, so it covers
        // every screen, sheet, menu and toast the app draws. nothing may go
        // between this MediaQuery and the lock.
        child: lock(child ?? const SizedBox.shrink()),
      );
    },
    // one scroll feel everywhere: ios-style rubber-band on every platform,
    // no stretch-glow. the single biggest "premium" tell, and it was unset
    // so android fell back to the clamp+glow default.
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
      child; // no glow - the bounce is the feedback
}
