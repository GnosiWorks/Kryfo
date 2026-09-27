// SPDX-License-Identifier: GPL-3.0-or-later
// speed and privacy, and getting messages: the cards press, the pages come
// to rest, and a status dot holds still unless tor is on its way.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/getting_messages_screen.dart';
import 'package:kryfo/screens/modes_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/motion.dart' show BreathDot;
import 'package:kryfo/widgets/press_scale.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget framed(Widget home, {bool still = false}) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: home,
);

void main() {
  late Directory docs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    docs = Directory.systemTemp.createTempSync('modes');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => docs.path,
        );
  });

  tearDown(() => docs.deleteSync(recursive: true));

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(720, 1600);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
  }

  group('speed and privacy', () {
    double press(WidgetTester t, String name) => t
        .widget<AnimatedScale>(
          find
              .ancestor(
                of: find.text(name),
                matching: find.byType(AnimatedScale),
              )
              .first,
        )
        .scale;

    testWidgets('a card dips while pressed and the page rests', (t) async {
      phone(t);
      await t.pumpWidget(framed(const ModesScreen()));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 500));
      }
      expect(t.hasRunningAnimations, isFalse);
      expect(
        find.ancestor(
          of: find.text(l10n.modesRelay),
          matching: find.byType(PressScale),
        ),
        findsOneWidget,
      );
      final g = await t.startGesture(t.getCenter(find.text(l10n.modesRelay)));
      await t.pump(const Duration(milliseconds: 150));
      expect(press(t, l10n.modesRelay), lessThan(1));
      await g.cancel();
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 300));
      expect(press(t, l10n.modesRelay), 1);
      expect(t.hasRunningAnimations, isFalse);
    });

    testWidgets('hops read in mono, like every count', (t) async {
      phone(t);
      await t.pumpWidget(framed(const ModesScreen()));
      await t.pump(const Duration(seconds: 1));
      final three = t.widget<Text>(find.text('3'));
      expect(three.style!.fontFamily, HaloType.monoFamily);
    });

    testWidgets('reduced motion: a press does not move', (t) async {
      phone(t);
      await t.pumpWidget(framed(const ModesScreen(), still: true));
      await t.pump(const Duration(seconds: 1));
      final g = await t.startGesture(t.getCenter(find.text(l10n.modesRelay)));
      await t.pump(const Duration(milliseconds: 150));
      expect(t.hasRunningAnimations, isFalse);
      await g.cancel();
    });
  });

  group('getting messages', () {
    testWidgets('nothing on its way: the dot holds still, the page rests', (
      t,
    ) async {
      phone(t);
      await t.pumpWidget(framed(const GettingMessagesScreen()));
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(BreathDot), findsNothing);
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(const SizedBox());
    });
  });
}
