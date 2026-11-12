// SPDX-License-Identifier: GPL-3.0-or-later
// a linked computer asks for no tip: the tier is the phone's, and one bought
// there would be overwritten at the next sync
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/device_state.dart' show linkedDevicesForTest;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        HaloEngine,
        appState,
        AppStateRoute,
        linkedRoleForTest,
        useEngineForTest;
import 'package:kryfo/screens/profile_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Engine implements HaloEngine {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _framed(Widget home) => MaterialApp(
  locale: const Locale('en'),
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: home,
);

void _tall(WidgetTester t) {
  t.view.physicalSize = const Size(1600, 3200);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    useEngineForTest(_Engine());
    appState.sendModeForTest = 'private';
    linkedDevicesForTest = true;
  });
  tearDown(() {
    linkedRoleForTest = false;
    linkedDevicesForTest = null;
  });

  test('the bar has no support tab on a linked computer', () {
    linkedRoleForTest = false;
    expect(shownTabs, contains(HaloTab.support));
    linkedRoleForTest = true;
    expect(shownTabs, isNot(contains(HaloTab.support)));
    expect(shownTabs, [HaloTab.chats, HaloTab.tools, HaloTab.me]);
  });

  for (final linked in [false, true]) {
    testWidgets('me ${linked ? 'hides' : 'shows'} the support card '
        '(${linked ? 'linked computer' : 'phone'})', (t) async {
      _tall(t);
      linkedRoleForTest = linked;
      await t.pumpWidget(_framed(const ProfileScreen()));
      await t.pump(const Duration(seconds: 1));
      final card = find.text(l10n.profileKeepKryfoIndependent);
      final head = find.text(l10n.profileSupportKryfo);
      expect(card, linked ? findsNothing : findsOneWidget);
      expect(head, linked ? findsNothing : findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 11));
    });
  }
}
