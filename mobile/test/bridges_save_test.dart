// SPDX-License-Identifier: GPL-3.0-or-later
// a save of bridge lines the engine could not read leaves bridges off. the
// switch goes off, the line under the button says so in the warning colour,
// and the reconnect that follows, which runs without bridges, is not
// reported as connected. lines it took are reported as usual
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloEngine, appState, useEngineForTest;
import 'package:kryfo/screens/bridges_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/halo_switch.dart';
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart' show app;

// the engine's bridge calls, answering as it does for the lines it is given
class _Engine implements HaloEngine {
  _Engine({required this.takes});

  final bool takes;
  bool _on = false;

  @override
  String setBridges(String lines, bool on) {
    _on = on && takes;
    return takes ? 'ok: 2 bridges' : 'ok: 0 accepted, 2 not understood';
  }

  @override
  String bridgeState() => '$_on|${_on ? 2 : 0}|0';

  @override
  void restartTor() {}

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

Future<void> _saveAndConnect(WidgetTester t, {required bool takes}) async {
  // tall enough that the list builds every card
  t.view.physicalSize = const Size(1800, 9000);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  useEngineForTest(_Engine(takes: takes));
  appState.sendModeForTest = 'private';
  appState.setTorStatusForTest(TorStatus.starting);
  appState.setRouteOKForTest(true);
  await t.pumpWidget(app(const BridgesScreen()));
  await t.pump(const Duration(seconds: 1));
  await t.enterText(
    find.byType(TextField).first,
    'obfs4 1.2.3.4:443 AAAA\nobfs4 5.6.7.8:443 BBBB',
  );
  await t.tap(find.byType(HaloSwitch));
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(find.text(l10n.bridgesSaveAndReconnect));
  await t.pump(const Duration(milliseconds: 300));
  // tor comes back on a new route that carries traffic
  appState.setRouteGenForTest(appState.routeGen + 1);
  appState.setTorStatusForTest(TorStatus.publishing);
  await t.pump(const Duration(seconds: 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() {
    appState.sendModeForTest = 'private';
    appState.setTorStatusForTest(TorStatus.off);
  });

  testWidgets('no usable line: bridges stay off and nothing says connected', (
    t,
  ) async {
    final haptics = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add('${call.arguments}');
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _saveAndConnect(t, takes: false);
    expect(appState.bridgesOn, isFalse);
    expect(t.widget<HaloSwitch>(find.byType(HaloSwitch)).value, isFalse);
    final line = find.text(l10n.bridgesNoneUsable);
    expect(line, findsOneWidget);
    expect(t.widget<Text>(line).style!.color, HaloColors.rose);
    expect(find.text(l10n.bridgesConnected), findsNothing);
    // the save's own tap, and no second one for a connection
    expect(
      haptics.where((h) => h == 'HapticFeedbackType.mediumImpact'),
      hasLength(1),
    );
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 4));
  });

  testWidgets('lines it took are reported connected', (t) async {
    await _saveAndConnect(t, takes: true);
    expect(appState.bridgesOn, isTrue);
    expect(find.text(l10n.bridgesConnected), findsWidgets);
    expect(find.text(l10n.bridgesNoneUsable), findsNothing);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 4));
  });
}
