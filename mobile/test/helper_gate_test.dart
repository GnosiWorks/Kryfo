// the helper app in getting messages: hidden until our relay can knock and
// only on the private route, and the sheet that finds or gets a helper app
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/delivery_mode.dart';
import 'package:kryfo/helper_push.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show appState;
import 'package:kryfo/open_outside.dart';
import 'package:kryfo/screens/getting_messages_screen.dart';
import 'package:kryfo/screens/helper_sheet.dart';
import 'package:kryfo/theme.dart';
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
    docs = Directory.systemTemp.createTempSync('helper');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => docs.path,
        );
  });

  tearDown(() {
    appState.relayKnocksForTest = false;
    appState.sendModeForTest = 'private';
    appState.deliveryModeForTest = DeliveryMode.always;
    openOutsideForTest = null;
    docs.deleteSync(recursive: true);
  });

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(720, 1600);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
  }

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
  }

  final helperCard = find.text('Through a helper app');

  group('the gate', () {
    testWidgets('a relay that cannot knock: no helper app', (t) async {
      phone(t);
      appState.sendModeForTest = 'private';
      await t.pumpWidget(framed(const GettingMessagesScreen()));
      await settle(t);
      expect(helperCard, findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('our relay knocks: the helper app grows in', (t) async {
      phone(t);
      appState.sendModeForTest = 'private';
      appState.relayKnocksForTest = true;
      await t.pumpWidget(framed(const GettingMessagesScreen()));
      await settle(t);
      expect(helperCard, findsOneWidget);
      expect(find.text(l10n.gettingMessagesHelperBody), findsOneWidget);
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('off the private route it stays hidden: registrations go '
        'over tor or not at all', (t) async {
      phone(t);
      appState.relayKnocksForTest = true;
      appState.sendModeForTest = 'fast';
      await t.pumpWidget(framed(const GettingMessagesScreen()));
      await settle(t);
      expect(helperCard, findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a phone on the helper app always sees its choice and the '
        'note on fake wake-ups', (t) async {
      phone(t);
      appState.deliveryModeForTest = DeliveryMode.helper;
      appState.sendModeForTest = 'fast';
      await t.pumpWidget(framed(const GettingMessagesScreen(), still: true));
      await t.pump(const Duration(seconds: 1));
      expect(helperCard, findsOneWidget);
      expect(find.text(l10n.gettingMessagesHelperNote), findsOneWidget);
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('the sheet', () {
    testWidgets('no helper app: get ntfy, and coming back with it installed '
        'carries on by itself', (t) async {
      phone(t);
      var apps = <HelperApp>[];
      final used = <String>[];
      final opened = <Uri>[];
      openOutsideForTest = (u) async {
        opened.add(u);
        return true;
      };
      HelperApp? got;
      await t.pumpWidget(
        framed(
          Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () async {
                  got = await showModalBottomSheet<HelperApp>(
                    context: ctx,
                    builder: (_) => HelperSheet(
                      appsForTest: () async => apps,
                      useForTest: (a) async {
                        used.add(a.package);
                        return true;
                      },
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await settle(t);
      expect(find.text(l10n.helperSheetNeedTitle), findsOneWidget);
      await t.tap(find.text(l10n.helperSheetGetNtfy));
      await t.pump();
      expect(opened.single.toString(), kNtfyStore);
      await t.tap(find.text(l10n.helperSheetOtherApps));
      await t.pump();
      expect(opened.last.toString(), kHelperApps);

      // back from the store with ntfy on the phone
      apps = [const HelperApp('io.heckel.ntfy', 'ntfy')];
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(used, ['io.heckel.ntfy']);
      expect(find.text(l10n.helperSheetSetUp('ntfy')), findsOneWidget);
      await t.pump(const Duration(seconds: 1));
      await settle(t);
      expect(got?.package, 'io.heckel.ntfy');
      expect(find.text(l10n.helperSheetSetUp('ntfy')), findsNothing);
    });

    testWidgets('a helper app that does not answer says so, and nothing is '
        'set', (t) async {
      phone(t);
      await t.pumpWidget(
        framed(
          const Scaffold(
            body: HelperSheet(appsForTest: _two, useForTest: _never),
          ),
          still: true,
        ),
      );
      await settle(t);
      expect(find.text(l10n.helperSheetPickTitle), findsOneWidget);
      await t.tap(find.text('ntfy'));
      await settle(t);
      expect(find.text(l10n.helperSheetNoAnswer('ntfy')), findsOneWidget);
      expect(t.hasRunningAnimations, isFalse);
    });
  });
}

Future<List<HelperApp>> _two() async => const [
  HelperApp('io.heckel.ntfy', 'ntfy'),
  HelperApp('org.unifiedpush.distributor.nextpush', 'NextPush'),
];

Future<bool> _never(HelperApp _) async => false;
