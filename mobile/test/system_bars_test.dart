// SPDX-License-Identifier: GPL-3.0-or-later
// the bars over the app: icons by theme on screens with and without an app
// bar, a theme switch follows, the black viewers keep their icons light, and
// no style carries a bar colour, which would reach window setters android 15
// deprecates
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_shell.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/photo_viewer.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAQAAAADCAIAAAA7ljmRAAAAEElEQVR4nGP4Oo8bjhhwcgCFmhNpSPXr6AAAAABJRU5ErkJggg==',
);

void main() {
  final theme = ValueNotifier<int>(0);
  final nav = GlobalKey<NavigatorState>();

  // every style sent to the engine
  final sent = <Map<Object?, Object?>>[];

  Future<void> open(WidgetTester t, Widget home, {double navBar = 96}) async {
    sent.clear();
    final m = t.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setSystemUIOverlayStyle') {
        sent.add(call.arguments as Map<Object?, Object?>);
      }
      return null;
    });
    addTearDown(
      () => m.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    t.view.physicalSize = const Size(1000, 1800);
    t.view.devicePixelRatio = 2;
    t.view.padding = FakeViewPadding(top: 64, bottom: navBar);
    t.view.viewPadding = FakeViewPadding(top: 64, bottom: navBar);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ListenableBuilder(
        listenable: theme,
        builder: (_, _) => haloAppShell(
          navigatorKey: nav,
          home: home,
          lock: (navigator) => navigator,
        ),
      ),
    );
    await t.pump();
  }

  Future<void> switchTo(WidgetTester t, {required bool light}) async {
    HaloColors.setLight(light);
    theme.value++;
    // the theme eases over, the app bar's style flips halfway
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  tearDown(() => HaloColors.setLight(false));

  // the bars are made transparent natively; a colour from here would make
  // the engine call setStatusBarColor and setNavigationBarColor
  void expectNoColours() {
    expect(sent, isNotEmpty);
    for (final s in sent) {
      expect(s['statusBarColor'], isNull, reason: '$s');
      expect(s['systemNavigationBarColor'], isNull, reason: '$s');
      expect(s['systemNavigationBarDividerColor'], isNull, reason: '$s');
    }
  }

  testWidgets('no app bar: no bar colours, icons by theme', (t) async {
    HaloColors.setLight(true);
    await open(t, const Scaffold(body: SizedBox.expand()));
    var s = SystemChrome.latestStyle!;
    expect(s.statusBarColor, isNull);
    expect(s.systemNavigationBarColor, isNull);
    expect(s.statusBarIconBrightness, Brightness.dark);
    expect(s.statusBarBrightness, Brightness.light);
    expect(s.systemNavigationBarIconBrightness, Brightness.dark);
    // a theme switch follows
    await switchTo(t, light: false);
    s = SystemChrome.latestStyle!;
    expect(s.statusBarIconBrightness, Brightness.light);
    expect(s.statusBarBrightness, Brightness.dark);
    expect(s.systemNavigationBarIconBrightness, Brightness.light);
    await switchTo(t, light: true);
    expect(SystemChrome.latestStyle!.statusBarIconBrightness, Brightness.dark);
    expectNoColours();
  });

  testWidgets('an app bar agrees with the screens without one', (t) async {
    HaloColors.setLight(true);
    await open(
      t,
      Scaffold(
        appBar: AppBar(title: const Text('t')),
        body: const SizedBox.expand(),
      ),
    );
    expect(SystemChrome.latestStyle!.statusBarIconBrightness, Brightness.dark);
    await switchTo(t, light: false);
    expect(SystemChrome.latestStyle!.statusBarIconBrightness, Brightness.light);
    expectNoColours();
  });

  testWidgets('a navigation bar outside the app keeps light icons', (t) async {
    // android 9 and older: the app stops above the bar, which is dark
    HaloColors.setLight(true);
    await open(t, const Scaffold(body: SizedBox.expand()), navBar: 0);
    final s = SystemChrome.latestStyle!;
    expect(s.statusBarIconBrightness, Brightness.dark);
    expect(s.systemNavigationBarIconBrightness, Brightness.light);
    expectNoColours();
  });

  testWidgets('the photo viewer is black: light icons', (t) async {
    HaloColors.setLight(true);
    await open(t, const Scaffold(body: SizedBox.expand()));
    nav.currentState!.push(
      PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (_, _, _) => PhotoViewer(
          image: MemoryImage(_png),
          route: const AlwaysStoppedAnimation(1),
        ),
      ),
    );
    await t.pumpAndSettle();
    var s = SystemChrome.latestStyle!;
    expect(s.statusBarIconBrightness, Brightness.light);
    expect(s.systemNavigationBarIconBrightness, Brightness.light);
    nav.currentState!.pop();
    await t.pumpAndSettle();
    s = SystemChrome.latestStyle!;
    expect(s.statusBarIconBrightness, Brightness.dark);
    expectNoColours();
  });
}
