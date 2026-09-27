// SPDX-License-Identifier: GPL-3.0-or-later
// the house pieces every screen shares: a page opening, a bar that a page
// scrolls under, a value or a page swapping in place, and the bottom tabs
// sliding in from the side they lie on. each comes to rest, holds still
// with less movement and mirrors right to left.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show appState;
import 'package:kryfo/screens/home_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/motion.dart';
import 'package:kryfo/widgets/swap.dart';
import 'package:shared_preferences/shared_preferences.dart';

// one theme for every pump: a new one each time would animate between them
final _theme = buildHaloTheme();

Widget framed(
  Widget home, {
  bool still = false,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  theme: _theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: home,
);

// wide enough for the tools tab in the test font
void phone(WidgetTester t) {
  t.view.physicalSize = const Size(1000, 1800);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

// the vertical offset the route's slide gives the page, in pixels
double pageRise(WidgetTester t, Finder page) {
  final slide = t.widget<SlideTransition>(
    find.ancestor(of: page, matching: find.byType(SlideTransition)).first,
  );
  return slide.position.value.dy;
}

class _Opener extends StatelessWidget {
  const _Opener();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(
          context,
        ).push(haloRoute(const Scaffold(body: Text('the page')))),
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  group('a page opening', () {
    testWidgets('rises and fades in, then rests', (t) async {
      await t.pumpWidget(framed(const _Opener()));
      await t.tap(find.text('open'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(pageRise(t, find.text('the page')), greaterThan(0));
      await t.pump(const Duration(milliseconds: 300));
      expect(pageRise(t, find.text('the page')), 0);
      expect(t.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion: it only fades, nothing moves', (t) async {
      await t.pumpWidget(framed(const _Opener(), still: true));
      await t.tap(find.text('open'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(pageRise(t, find.text('the page')), 0);
      final fade = t.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('the page'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, lessThan(1));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.hasRunningAnimations, isFalse);
    });
  });

  group('a bar a page scrolls under', () {
    testWidgets('stays plain: no tint and no lift', (t) async {
      await t.pumpWidget(
        framed(
          Scaffold(
            backgroundColor: HaloColors.surface,
            appBar: AppBar(
              backgroundColor: HaloColors.surface,
              title: const Text('bar'),
            ),
            body: ListView(
              children: [
                for (var i = 0; i < 60; i++)
                  SizedBox(height: 40, child: Text('row $i')),
              ],
            ),
          ),
        ),
      );
      Material bar() => t.widget<Material>(
        find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byType(Material),
            )
            .first,
      );
      await t.drag(find.byType(ListView), const Offset(0, -400));
      await t.pumpAndSettle();
      expect(bar().elevation, 0);
      expect(bar().surfaceTintColor, Colors.transparent);
      expect(bar().color, HaloColors.surface);
    });
  });

  group('a value swapping in place', () {
    Widget value(String v, {bool still = false}) => framed(
      Scaffold(
        body: Center(
          child: RiseSwap(child: Text(v, key: ValueKey(v))),
        ),
      ),
      still: still,
    );

    testWidgets('the new words rise in over the old, then rest', (t) async {
      await t.pumpWidget(value('Off'));
      await t.pumpWidget(value('On'));
      await t.pump(const Duration(milliseconds: 60));
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('On'), findsOneWidget);
      expect(t.hasRunningAnimations, isTrue);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Off'), findsNothing);
      expect(t.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion: the change is simply there', (t) async {
      await t.pumpWidget(value('Off', still: true));
      await t.pumpWidget(value('On', still: true));
      await t.pump();
      expect(find.text('Off'), findsNothing);
      expect(t.hasRunningAnimations, isFalse);
    });

    Widget page(String v, {bool still = false}) => framed(
      Scaffold(
        body: FadeSwap(child: Text(v, key: ValueKey(v))),
      ),
      still: still,
    );

    testWidgets('a page fades over the last and rests', (t) async {
      await t.pumpWidget(page('form'));
      await t.pumpWidget(page('done'));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('form'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('form'), findsNothing);
      expect(t.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion: the next page is simply there', (t) async {
      await t.pumpWidget(page('form', still: true));
      await t.pumpWidget(page('done', still: true));
      await t.pump();
      expect(find.text('form'), findsNothing);
      expect(t.hasRunningAnimations, isFalse);
    });
  });

  group('the bottom tabs', () {
    // where the tools tab's title sits across the screen
    double toolsX(WidgetTester t) =>
        t.getCenter(find.text(l10n.toolsWhatDoesThisPhoto)).dx;

    Future<void> open(
      WidgetTester t, {
      bool still = false,
      Locale locale = const Locale('en'),
    }) async {
      phone(t);
      // the phone answers nothing: the tools channel, haptics
      final m = t.binding.defaultBinaryMessenger;
      m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(
        () => m.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await t.pumpWidget(
        framed(
          HomeScreen(
            haloId: 'neon-tiger-saturn',
            onAddContact: () {},
            onNewGroup: () {},
            onNewRoom: () {},
            onOpenDev: () {},
            onOpenSettingsDirect: () {},
            onOpenChat: (_) {},
            onOpenGroup: (_) {},
          ),
          still: still,
          locale: locale,
        ),
      );
      await t.pump(const Duration(seconds: 1));
    }

    setUp(() {
      // the battery prompt was seen: nothing asks the platform
      SharedPreferences.setMockInitialValues({
        'battery_opt_prompt_seen': true,
        'miui_autostart_prompt_seen': true,
      });
      FlutterSecureStorage.setMockInitialValues({});
      appState.sendModeForTest = 'balanced';
    });

    testWidgets('a tab to the right slides in from the right, then rests', (
      t,
    ) async {
      await open(t);
      await t.tap(find.text(l10n.navBarTools));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      final mid = toolsX(t);
      await t.pump(const Duration(seconds: 1));
      expect(mid, greaterThan(toolsX(t) + 4));
      // the tools tab's own welcome breathes a while longer, then rests
      await t.pump(const Duration(seconds: 12));
      expect(t.hasRunningAnimations, isFalse);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets('right to left: it comes in from the left', (t) async {
      await open(t, locale: const Locale('ar'));
      await t.tap(find.text(l10n.navBarTools));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      final mid = toolsX(t);
      await t.pump(const Duration(seconds: 1));
      expect(mid, lessThan(toolsX(t) - 4));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets('reduced motion: the tab is simply there', (t) async {
      await open(t, still: true);
      await t.tap(find.text(l10n.navBarTools));
      await t.pump();
      final first = toolsX(t);
      await t.pump(const Duration(seconds: 1));
      expect(toolsX(t), first);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets('the tool sweep waits while kryfo is away', (t) async {
      final sweeps = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('halo/tools'),
        (call) async {
          if (call.method == 'sweep') sweeps.add('sweep');
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('halo/tools'),
          null,
        ),
      );
      await open(t);
      expect(sweeps, hasLength(1), reason: 'one sweep as home opens');
      await t.pump(const Duration(minutes: 5));
      expect(sweeps, hasLength(2), reason: 'and every five minutes');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump(const Duration(minutes: 20));
      expect(sweeps, hasLength(2), reason: 'nothing while away');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump(const Duration(minutes: 5));
      expect(sweeps, hasLength(3), reason: 'back on its beat once in front');
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  });
}
