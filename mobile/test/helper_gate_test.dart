// the helper app in getting messages: always shown, greyed until our relay
// can knock and the route is onion, and the sheet that finds or gets one
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
import 'package:kryfo/widgets/card_action.dart';
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
    appState.relaySaidNoForTest = false;
    appState.sendModeForTest = 'private';
    appState.deliveryModeForTest = DeliveryMode.always;
    openOutsideForTest = null;
    setRouteForTest = null;
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

  double helperOpacity(WidgetTester t) => t
      .widget<AnimatedOpacity>(
        find
            .ancestor(of: helperCard, matching: find.byType(AnimatedOpacity))
            .first,
      )
      .opacity;

  group('the gate', () {
    testWidgets('a relay that cannot knock: greyed, and a tap does '
        'nothing', (t) async {
      phone(t);
      appState.sendModeForTest = 'private';
      appState.relaySaidNoForTest = true;
      final moved = <String>[];
      setRouteForTest = (m) async => moved.add(m);
      await t.pumpWidget(framed(const GettingMessagesScreen()));
      await settle(t);
      expect(helperCard, findsOneWidget);
      expect(helperOpacity(t), lessThan(1));
      expect(find.text(l10n.gettingMessagesHelperRelayNotYet), findsOneWidget);
      expect(find.byKey(const ValueKey('helperChecking')), findsNothing);
      await t.tap(helperCard);
      await settle(t);
      expect(moved, isEmpty);
      expect(find.byType(BottomSheet), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a relay not answered yet: checking with a spinner, never '
        'that it does not offer this', (t) async {
      phone(t);
      appState.sendModeForTest = 'private';
      await t.pumpWidget(framed(const GettingMessagesScreen()));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.gettingMessagesHelperChecking), findsOneWidget);
      expect(find.byKey(const ValueKey('helperChecking')), findsOneWidget);
      expect(find.text(l10n.gettingMessagesHelperRelayNotYet), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: the checking spinner stands still', (t) async {
      phone(t);
      appState.sendModeForTest = 'private';
      await t.pumpWidget(framed(const GettingMessagesScreen(), still: true));
      await t.pump(const Duration(milliseconds: 300));
      final spin = t.widget<CircularProgressIndicator>(
        find.byKey(const ValueKey('helperChecking')),
      );
      expect(spin.value, isNotNull);
      await t.pumpWidget(framed(const GettingMessagesScreen()));
      await t.pump(const Duration(milliseconds: 300));
      expect(
        t
            .widget<CircularProgressIndicator>(
              find.byKey(const ValueKey('helperChecking')),
            )
            .value,
        isNull,
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('on onion with a relay that knocks: the card can be picked', (
      t,
    ) async {
      phone(t);
      appState.sendModeForTest = 'private';
      appState.relayKnocksForTest = true;
      await t.pumpWidget(framed(const GettingMessagesScreen()));
      await settle(t);
      expect(helperCard, findsOneWidget);
      expect(find.text(l10n.gettingMessagesHelperBody), findsOneWidget);
      expect(helperOpacity(t), 1);
      expect(find.text(l10n.gettingMessagesHelperOnionOnly), findsNothing);
      expect(find.text(l10n.gettingMessagesHelperRelayNotYet), findsNothing);
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('off the onion route it is greyed and says so: '
        'registrations go over tor or not at all', (t) async {
      phone(t);
      appState.relayKnocksForTest = true;
      appState.sendModeForTest = 'fast';
      await t.pumpWidget(framed(const GettingMessagesScreen()));
      await settle(t);
      expect(helperCard, findsOneWidget);
      expect(helperOpacity(t), lessThan(1));
      expect(find.text(l10n.gettingMessagesHelperOnionOnly), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a tap off onion moves the route to onion, then the card '
        'can be picked', (t) async {
      phone(t);
      appState.relayKnocksForTest = true;
      appState.sendModeForTest = 'balanced';
      final moved = <String>[];
      setRouteForTest = (m) async {
        moved.add(m);
        appState.sendModeForTest = m;
      };
      await t.pumpWidget(framed(const GettingMessagesScreen()));
      await settle(t);
      await t.tap(helperCard);
      await settle(t);
      expect(moved, ['private']);
      expect(find.text(l10n.gettingMessagesHelperOnionOnly), findsNothing);
      expect(helperOpacity(t), 1);
      // nothing picked by the tap that moved the route
      expect(appState.deliveryMode, DeliveryMode.always);
      expect(find.byType(BottomSheet), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a route that would not move says so and stays greyed', (
      t,
    ) async {
      phone(t);
      appState.relayKnocksForTest = true;
      appState.sendModeForTest = 'fast';
      setRouteForTest = (m) async => throw StateError('not saved');
      await t.pumpWidget(framed(const GettingMessagesScreen()));
      await settle(t);
      await t.tap(helperCard);
      await t.pump();
      expect(find.text(l10n.modesNotChanged), findsOneWidget);
      expect(find.text(l10n.gettingMessagesHelperOnionOnly), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
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

  group('the pill', () {
    Finder pill(String label) => find.descendant(
      of: find.byType(CardAction),
      matching: find.text(label),
    );

    testWidgets('off onion it says switch to onion, filled, and a tap on it '
        'moves the route', (t) async {
      phone(t);
      appState.relayKnocksForTest = true;
      appState.sendModeForTest = 'fast';
      final moved = <String>[];
      setRouteForTest = (m) async {
        moved.add(m);
        appState.sendModeForTest = m;
      };
      await t.pumpWidget(framed(const GettingMessagesScreen()));
      await settle(t);
      final useOnion = pill(l10n.gettingMessagesHelperUseOnion);
      expect(useOnion, findsOneWidget);
      final a = t.widget<CardAction>(
        find.ancestor(of: useOnion, matching: find.byType(CardAction)),
      );
      expect(a.fill, HaloColors.amber);
      expect(a.ink, HaloColors.onAmber);
      await t.tap(useOnion);
      await settle(t);
      expect(moved, ['private']);
      // usable now: the pill sets it up
      expect(useOnion, findsNothing);
      expect(pill(l10n.gettingMessagesHelperSetUp), findsOneWidget);
      // alone on its line it sits at the card's end, under the finger
      expect(
        t.getCenter(pill(l10n.gettingMessagesHelperSetUp)).dx,
        greaterThan(260),
      );
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('a relay that cannot knock has no pill, a phone on the '
        'helper app needs none', (t) async {
      phone(t);
      appState.sendModeForTest = 'private';
      appState.relaySaidNoForTest = true;
      await t.pumpWidget(framed(const GettingMessagesScreen(), still: true));
      await settle(t);
      expect(find.byType(CardAction), findsNothing);
      appState.deliveryModeForTest = DeliveryMode.helper;
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(framed(const GettingMessagesScreen(), still: true));
      await settle(t);
      expect(find.byType(CardAction), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    test('the card says it in one short line', () {
      expect(l10n.gettingMessagesHelperBody.length, lessThan(100));
      expect('.'.allMatches(l10n.gettingMessagesHelperBody).length, 2);
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
