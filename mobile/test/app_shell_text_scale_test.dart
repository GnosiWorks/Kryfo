// SPDX-License-Identifier: GPL-3.0-or-later
// the phone's text size reaches the app up to 2x, the largest android
// offers. the nav bar's words follow it and stay whole in their tabs
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_shell.dart';
import 'package:kryfo/widgets/nav_bar.dart';

final _nav = GlobalKey<NavigatorState>();

Widget _shell(Widget home) => haloAppShell(
  navigatorKey: _nav,
  home: home,
  lock: (n) => n,
  locale: const Locale('en'),
);

void main() {
  for (final (asked, got) in [
    (1.0, 1.0),
    (2.0, 2.0),
    (3.0, 2.0),
    (0.5, 0.85),
  ]) {
    testWidgets('a phone at ${asked}x gets ${got}x', (t) async {
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(
        () => m.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      t.platformDispatcher.textScaleFactorTestValue = asked;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      late double seen;
      await t.pumpWidget(
        _shell(
          Builder(
            builder: (ctx) {
              seen = MediaQuery.textScalerOf(ctx).scale(14) / 14;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, closeTo(got, 0.001));
    });
  }

  testWidgets('the nav bar at 2x on a small phone: whole, nothing cut', (
    t,
  ) async {
    t.view.physicalSize = const Size(720, 1280);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        builder: (ctx, c) => MediaQuery(
          data: MediaQuery.of(
            ctx,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: c!,
        ),
        home: Scaffold(
          bottomNavigationBar: HaloNavBar(
            active: HaloTab.chats,
            onPick: (_) {},
          ),
        ),
      ),
    );
    await t.pump();
    expect(t.takeException(), isNull);
    final bar = t.getRect(find.byType(HaloNavBar));
    for (final e
        in find
            .descendant(
              of: find.byType(HaloNavBar),
              matching: find.byType(Text),
            )
            .evaluate()) {
      final r = t.getRect(find.byWidget(e.widget));
      expect(bar.contains(r.topLeft) && bar.contains(r.bottomRight), isTrue);
    }
  });
}
