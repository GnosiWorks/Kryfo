// SPDX-License-Identifier: GPL-3.0-or-later
// the main linked devices screens pixel for pixel, on a phone and a
// computer: the phone's link once it took (with the way to the copy), the
// history copy under way and ended with a gap, the device list, and what a
// removed device shows. the copy's page opens from the link that took
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/history_export.dart';
import 'package:kryfo/devices/history_ffi.dart' show HistoryCount;
import 'package:kryfo/devices/history_link.dart';
import 'package:kryfo/devices/link_flow.dart';
import 'package:kryfo/devices/linked_lock.dart';
import 'package:kryfo/devices/own_devices.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/screens/history_copy_screen.dart';
import 'package:kryfo/screens/link_screens.dart';
import 'package:kryfo/screens/linked_devices_screen.dart';
import 'package:kryfo/screens/unlinked_screen.dart';
import 'package:kryfo/theme.dart';

import 'narrow_settings.dart' show loadAppFonts;

class _Flow extends LinkFlow {
  _Flow([super.first = const LinkStage(LinkStep.reaching)]);
  @override
  Future<void> start() async {}
  @override
  Future<void> match() async {}
  @override
  void noMatch() {}
  @override
  void cancel() {}
}

class _Devices implements OwnDevices {
  _Devices(this.all);
  final List<OwnDevice> all;
  @override
  Future<List<OwnDevice>> load() async => all;
  @override
  Future<void> remove(String id) async {}
  @override
  Future<void> removeOthers() async {}
  @override
  Future<void> rename(String id, String name) async {}
  @override
  bool get canLink => true;
  @override
  bool get linksHere => true;
  @override
  bool get linkedDevice => false;
  @override
  LinkFlow linkFlow(String code, LinkHistory history) => _Flow();
  @override
  Future<void> opened() async {}
  @override
  bool get canLeave => false;
  @override
  Future<void> leaveHere() async {}
}

final _now = DateTime(2026, 11, 5, 15);

final _devices = [
  const OwnDevice(
    id: 'phone',
    name: 'This phone',
    kind: DeviceKind.phone,
    thisDevice: true,
  ),
  OwnDevice(
    id: 'desk',
    name: 'Desk at home',
    kind: DeviceKind.computer,
    linkedAt: DateTime(2026, 10, 12),
    lastUsed: DateTime(2026, 11, 5, 9),
    code: const ['12345', '67890', '13579', '24680'],
  ),
  OwnDevice(
    id: 'laptop',
    name: 'Laptop',
    kind: DeviceKind.computer,
    linkedAt: DateTime(2026, 10, 1),
    lastUsed: DateTime(2026, 10, 9),
    unlinksInDays: 4,
    code: const ['24680', '13579', '67890', '12345'],
  ),
];

Widget _app(Widget home) => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: home,
);

Future<void> _show(WidgetTester t, Widget page, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  setL10nLocale(const Locale('en'));
  await t.pumpWidget(_app(page));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

Future<String> _name(HistoryChatRef c) async => c.group ? 'Night shift' : 'Ana';

const _going = HistoryCopyStage(
  HistoryCopyStep.copying,
  bytes: 84 * 1024 * 1024,
  records: 100,
  at: 40,
);

final _gaps = HistoryCopyStage(
  HistoryCopyStep.gaps,
  bytes: 84 * 1024 * 1024,
  records: 100,
  at: 100,
  gaps: [
    HistoryChatGap(
      const HistoryChatRef(true, 'g1'),
      const HistoryCount(120, 4, 9000),
      const HistoryCount(117, 3, 8800),
    ),
  ],
);

void main() {
  setUpAll(lockState.openForTest);

  testWidgets('a link that took offers the copy, and its page opens over '
      'the devices', (t) async {
    var seen = 0;
    await _show(
      t,
      LinkRunScreen(
        flow: _Flow(const LinkStage(LinkStep.done)),
        onSeeCopy: () => seen++,
      ),
      const Size(390, 844),
    );
    expect(find.text(l10n.devicesLinkDone), findsOneWidget);
    await t.tap(find.text(l10n.historyCopySee));
    expect(seen, 1);
    // none without a page to open
    await _show(
      t,
      LinkRunScreen(flow: _Flow(const LinkStage(LinkStep.done))),
      const Size(390, 844),
    );
    expect(find.text(l10n.historyCopySee), findsNothing);
  });

  testWidgets('a chat\'s name on the copy page is read once, whatever moves', (
    t,
  ) async {
    var reads = 0;
    final stage = ValueNotifier<HistoryCopyStage?>(_gaps);
    await _show(
      t,
      HistoryCopyScreen(
        stage: stage,
        nameOf: (c) async {
          reads++;
          return 'Night shift';
        },
      ),
      const Size(390, 844),
    );
    await t.pumpAndSettle();
    expect(find.text('Night shift'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      stage.value = HistoryCopyStage(
        HistoryCopyStep.gaps,
        bytes: _gaps.bytes,
        records: 100,
        at: 100,
        gaps: _gaps.gaps,
      );
      await t.pump();
    }
    expect(reads, 1);
  });

  group('pixel for pixel', () {
    setUpAll(loadAppFonts);
    for (final (name, size) in [
      ('phone', const Size(390, 844)),
      ('desk', const Size(1280, 800)),
    ]) {
      testWidgets('$name: the phone\'s link took', (t) async {
        await _show(
          t,
          LinkRunScreen(
            flow: _Flow(const LinkStage(LinkStep.done)),
            onSeeCopy: () {},
          ),
          size,
        );
        await expectLater(
          find.byType(LinkRunScreen),
          matchesGoldenFile('goldens/linked_${name}_link_done.png'),
        );
      });
      testWidgets('$name: the history copy under way', (t) async {
        await _show(
          t,
          HistoryCopyScreen(stage: ValueNotifier(_going), nameOf: _name),
          size,
        );
        await expectLater(
          find.byType(HistoryCopyScreen),
          matchesGoldenFile('goldens/linked_${name}_copy_going.png'),
        );
      });
      testWidgets('$name: the history copy ended with a gap', (t) async {
        await _show(
          t,
          HistoryCopyScreen(stage: ValueNotifier(_gaps), nameOf: _name),
          size,
        );
        await t.pumpAndSettle();
        await expectLater(
          find.byType(HistoryCopyScreen),
          matchesGoldenFile('goldens/linked_${name}_copy_gaps.png'),
        );
      });
      testWidgets('$name: the device list', (t) async {
        await _show(
          t,
          LinkedDevicesScreen(source: _Devices(_devices), now: () => _now),
          size,
        );
        await t.pumpAndSettle();
        await expectLater(
          find.byType(LinkedDevicesScreen),
          matchesGoldenFile('goldens/linked_${name}_devices.png'),
        );
      });
      testWidgets('$name: a removed device', (t) async {
        await _show(
          t,
          UnlinkedScreen(why: LinkedEnd.removed, onClose: () {}),
          size,
        );
        await t.pumpAndSettle();
        await expectLater(
          find.byType(UnlinkedScreen),
          matchesGoldenFile('goldens/linked_${name}_removed.png'),
        );
      });
    }
  });
}
