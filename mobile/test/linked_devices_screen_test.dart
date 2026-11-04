// SPDX-License-Identifier: GPL-3.0-or-later
// your own linked devices in settings: this phone alone, linked computers
// with their day and use, the amber line before the 30 days run out,
// removing one or all, renaming, the five limit, and the link page's
// history choice. scanning stays off until linking is wired. right to left,
// big text, reduced motion and both themes each hold
import 'package:flutter/material.dart';
import 'dart:ui' show CheckedState;

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/link_flow.dart';
import 'package:kryfo/devices/own_devices.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/screens/linked_devices_screen.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/halo_buttons.dart';

final _now = DateTime(2026, 10, 28, 15);

class _Devices implements OwnDevices {
  List<OwnDevice> all;
  final removed = <String>[];
  final renamed = <String, String>{};
  var others = 0;
  @override
  final bool linksHere;
  @override
  final bool linkedDevice;
  _Devices(this.all, {this.linksHere = true, this.linkedDevice = false});

  @override
  Future<List<OwnDevice>> load() async => all;

  @override
  Future<void> remove(String id) async {
    removed.add(id);
    all = [
      for (final d in all)
        if (d.id != id) d,
    ];
  }

  @override
  Future<void> removeOthers() async {
    others++;
    all = [
      for (final d in all)
        if (d.thisDevice) d,
    ];
  }

  @override
  Future<void> rename(String id, String name) async => renamed[id] = name;

  @override
  bool get canLink => false;

  @override
  LinkFlow linkFlow(String code, LinkHistory history) =>
      throw StateError('no link here');

  @override
  Future<void> opened() async {}
}

const _phone = OwnDevice(
  id: 'phone',
  name: 'This phone',
  kind: DeviceKind.phone,
  thisDevice: true,
);

OwnDevice _computer(
  String id,
  String name, {
  DateTime? used,
  int? unlinksIn,
  List<String> code = const ['12345', '67890', '13579', '24680'],
}) => OwnDevice(
  id: id,
  name: name,
  kind: DeviceKind.computer,
  linkedAt: DateTime(2026, 10, 12),
  lastUsed: used,
  unlinksInDays: unlinksIn,
  code: code,
);

Widget _app(
  Widget home, {
  bool still = false,
  double scale = 1,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(
      ctx,
    ).copyWith(disableAnimations: still, textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

Future<void> _open(
  WidgetTester t,
  OwnDevices source, {
  bool still = false,
  double scale = 1,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  setL10nLocale(locale);
  addTearDown(() => setL10nLocale(const Locale('en')));
  await t.pumpWidget(
    _app(
      LinkedDevicesScreen(source: source, now: () => _now),
      still: still,
      scale: scale,
      locale: locale,
    ),
  );
  await t.pumpAndSettle();
}

HaloPrimaryButton _button(WidgetTester t, String label) => t.widget(
  find.byWidgetPredicate((w) => w is HaloPrimaryButton && w.label == label),
);

void main() {
  test('the settings row names devices, never counts them', () {
    setL10nLocale(const Locale('en'));
    expect(devicesRowValue([_phone]), 'This phone only');
    expect(
      devicesRowValue([_phone, _computer('a', 'Desk'), _computer('b', 'Lap')]),
      'Desk, Lap',
    );
  });

  test('the home card names every new device, not only the newest', () {
    setL10nLocale(const Locale('en'));
    final one = linkNoticeWords([
      (name: 'Desk', at: DateTime(2026, 10, 27)),
    ], _now);
    expect(one.title, l10n.devicesNewNotice);
    expect(one.line, contains('Desk'));
    final two = linkNoticeWords([
      (name: 'Desk', at: DateTime(2026, 10, 27)),
      (name: 'Lap', at: DateTime(2026, 10, 28)),
    ], _now);
    expect(two.title, l10n.devicesNewNoticeMany);
    expect(two.line, l10n.devicesNewNoticeManyLine('Desk, Lap'));
  });

  test('use comes in four steps, never a time', () {
    expect(deviceUseOf(null, _now), DeviceUse.notYet);
    expect(deviceUseOf(DateTime(2026, 10, 28, 0, 5), _now), DeviceUse.today);
    expect(deviceUseOf(DateTime(2026, 10, 27, 23), _now), DeviceUse.week);
    expect(deviceUseOf(DateTime(2026, 10, 22), _now), DeviceUse.week);
    expect(deviceUseOf(DateTime(2026, 10, 20), _now), DeviceUse.month);
  });

  test('a typed name is trimmed, loses direction controls and fits', () {
    expect(deviceNameOf('  Desk  '), 'Desk');
    expect(deviceNameOf('a\u202eb'), 'ab');
    expect(deviceNameOf('tab\there'), 'tabhere');
    expect(deviceNameOf('   '), isNull);
    expect(deviceNameOf('\u2066\u2069'), isNull);
    expect(deviceNameOf('x' * kDeviceNameMax), 'x' * kDeviceNameMax);
    expect(deviceNameOf('x' * (kDeviceNameMax + 1)), isNull);
    // counted in characters, so persian or chinese get as many as latin
    expect(deviceNameOf('电' * kDeviceNameMax), isNotNull);
  });

  test('linked devices stay out of builds until linking is wired', () {
    expect(kLinkedDevicesOn, isFalse);
    expect(const ThisPhoneOnly(phoneName: 'p').canLink, isFalse);
  });

  testWidgets('this phone alone: what linking gives, and the two rules', (
    t,
  ) async {
    await _open(t, ThisPhoneOnly(phoneName: 'This phone'));
    expect(find.text('This phone'), findsOneWidget);
    expect(find.text(l10n.devicesOnlyThisPhone), findsOneWidget);
    expect(find.text(l10n.devicesEmptyTitle), findsOneWidget);
    expect(find.text(l10n.devicesContactsSeeNothing), findsOneWidget);
    expect(find.text(l10n.devicesUnusedRule), findsOneWidget);
    expect(find.text(l10n.devicesRemoveAll), findsNothing);
    // this phone's row opens nothing
    await t.tap(find.text('This phone'));
    await t.pumpAndSettle();
    expect(find.text(l10n.devicesRename), findsNothing);
    // the link page opens, but cannot scan until linking is wired
    await t.tap(find.text(l10n.devicesLinkADevice));
    await t.pumpAndSettle();
    expect(find.byType(LinkDeviceScreen), findsOneWidget);
    expect(_button(t, l10n.devicesScanCode).onTap, isNull);
  });

  testWidgets('linked computers show the day, the use and the amber line', (
    t,
  ) async {
    final src = _Devices([
      _phone,
      _computer('a', 'Desk', used: DateTime(2026, 10, 28, 9)),
      _computer('b', 'Old laptop', used: DateTime(2026, 10, 1), unlinksIn: 3),
      _computer('c', 'Spare', unlinksIn: 8),
    ]);
    await _open(t, src);
    expect(find.text('Linked 12 Oct · Used today'), findsOneWidget);
    expect(find.text('Linked 12 Oct · Used this month'), findsOneWidget);
    expect(find.text('Linked 12 Oct · Not used yet'), findsOneWidget);
    expect(find.text(l10n.devicesUnlinksSoon(3)), findsOneWidget);
    expect(find.text(l10n.devicesUnlinksSoon(8)), findsNothing);
    final amber = t.widget<Text>(find.text(l10n.devicesUnlinksSoon(3)));
    expect(amber.style!.color, HaloColors.warnText);
    expect(find.text(l10n.devicesEmptyTitle), findsNothing);
    expect(find.text(l10n.devicesRemoveAll), findsOneWidget);
    expect(l10n.devicesUnlinksSoon(0), 'Unlinks today unless you open it');
    expect(l10n.devicesUnlinksSoon(1), 'Unlinks tomorrow unless you open it');
  });

  testWidgets(
    'a device sheet shows its code; remove asks, then folds it away',
    (t) async {
      final src = _Devices([_phone, _computer('a', 'Desk')]);
      await _open(t, src);
      await t.tap(find.text('Desk'));
      await t.pumpAndSettle();
      expect(find.text(l10n.devicesDeviceCode), findsOneWidget);
      expect(find.text('67890'), findsOneWidget);
      expect(find.text(l10n.devicesDeviceCodeLine), findsOneWidget);
      await t.tap(find.text(l10n.devicesRemove));
      await t.pumpAndSettle();
      expect(find.text(l10n.devicesRemoveTitle('Desk')), findsOneWidget);
      expect(find.text(l10n.devicesRemoveLine), findsOneWidget);
      // kept: nothing happens
      await t.tap(find.text(l10n.confirmSheetKeep));
      await t.pumpAndSettle();
      expect(src.removed, isEmpty);
      await t.tap(find.text('Desk'));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.devicesRemove));
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.devicesRemove).last);
      await t.pumpAndSettle();
      expect(src.removed, ['a']);
      expect(find.text('Desk'), findsNothing);
      expect(find.text(l10n.devicesRemoved('Desk')), findsOneWidget);
      expect(find.text(l10n.devicesEmptyTitle), findsOneWidget);
    },
  );

  testWidgets('rename keeps the name on this phone only', (t) async {
    final src = _Devices([_phone, _computer('a', 'Desk')]);
    await _open(t, src);
    await t.tap(find.text('Desk'));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.devicesRename));
    await t.pumpAndSettle();
    expect(find.text(l10n.devicesRenameLine), findsOneWidget);
    await t.enterText(find.byType(TextField), '  Work\u202e  ');
    await t.tap(find.text(l10n.confirmSheetSave));
    await t.pumpAndSettle();
    expect(src.renamed, {'a': 'Work'});
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('remove all asks once and leaves this phone', (t) async {
    final src = _Devices([
      _phone,
      _computer('a', 'Desk'),
      _computer('b', 'Lap'),
    ]);
    await _open(t, src);
    await t.tap(find.text(l10n.devicesRemoveAll));
    await t.pumpAndSettle();
    expect(find.text(l10n.devicesRemoveAllLine), findsOneWidget);
    await t.tap(find.text(l10n.devicesRemoveAllYes));
    await t.pumpAndSettle();
    expect(src.others, 1);
    expect(find.text('Desk'), findsNothing);
    expect(find.text('Lap'), findsNothing);
    expect(find.text(l10n.devicesRemovedAll), findsOneWidget);
  });

  testWidgets('a linked computer says whose it is and links nothing', (
    t,
  ) async {
    final src = _Devices(
      [
        const OwnDevice(
          id: 'me',
          name: 'This computer',
          kind: DeviceKind.computer,
          thisDevice: true,
        ),
        const OwnDevice(
          id: 'phone',
          name: 'Your phone',
          kind: DeviceKind.phone,
        ),
      ],
      linksHere: false,
      linkedDevice: true,
    );
    await _open(t, src);
    expect(find.text(l10n.joinDone), findsOneWidget);
    expect(find.text(l10n.devicesOnlyThisPhoneShown), findsNothing);
    expect(find.text(l10n.devicesLinkADevice), findsNothing);
    expect(find.text(l10n.devicesRemoveAll), findsNothing);
    expect(find.text(l10n.devicesEmptyTitle), findsNothing);
    // its phone's row opens nothing: the phone renames and removes
    await t.tap(find.text('Your phone'));
    await t.pumpAndSettle();
    expect(find.text(l10n.devicesRename), findsNothing);
  });

  testWidgets('a computer that holds the account offers no link in 0.6', (
    t,
  ) async {
    await _open(t, _Devices([_phone], linksHere: false));
    expect(find.text(l10n.devicesLinkADevice), findsNothing);
    expect(find.text(l10n.devicesUnusedRule), findsOneWidget);
  });

  testWidgets('five linked: the button rests and says why', (t) async {
    final src = _Devices([
      _phone,
      for (var i = 0; i < kMaxLinkedDevices; i++)
        _computer('$i', 'Computer $i'),
    ]);
    await _open(t, src);
    expect(find.text(l10n.devicesFull), findsOneWidget);
    expect(_button(t, l10n.devicesLinkADevice).onTap, isNull);
  });

  testWidgets('the history choice: all, text only, or none', (t) async {
    LinkHistory? got;
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(LinkDeviceScreen(onScan: (h) => got = h)));
    await t.pumpAndSettle();
    expect(find.text(l10n.devicesHiddenStay), findsOneWidget);
    await t.tap(find.text(l10n.devicesScanCode));
    expect(got, LinkHistory.all);
    await t.tap(find.text(l10n.devicesSkipMedia));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.devicesScanCode));
    expect(got, LinkHistory.textOnly);
    await t.tap(find.text(l10n.devicesHistoryNone));
    await t.pumpAndSettle();
    // nothing to skip without a copy
    expect(find.text(l10n.devicesSkipMedia), findsNothing);
    await t.tap(find.text(l10n.devicesScanCode));
    expect(got, LinkHistory.none);
  });

  testWidgets('a screen reader hears the choices as one group', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(_app(const LinkDeviceScreen()));
    await t.pumpAndSettle();
    final copy = t
        .getSemantics(find.text(l10n.devicesHistoryCopy))
        .getSemanticsData();
    expect(copy.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
    expect(copy.flagsCollection.isChecked, CheckedState.isTrue);
    h.dispose();
  });

  for (final locale in const [Locale('ar'), Locale('fa')]) {
    testWidgets('right to left in ${locale.languageCode}', (t) async {
      final src = _Devices([_phone, _computer('a', 'Desk', unlinksIn: 2)]);
      await _open(t, src, locale: locale);
      expect(t.takeException(), isNull);
      final rtl = Directionality.of(t.element(find.text('Desk')));
      expect(rtl, TextDirection.rtl);
      await t.tap(find.text('Desk'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('big text on a small phone does not clip', (t) async {
    final src = _Devices([
      _phone,
      _computer('a', 'A long computer name here', unlinksIn: 2),
    ]);
    await _open(t, src, scale: 2, size: const Size(320, 640));
    expect(t.takeException(), isNull);
    await t.tap(find.text(l10n.devicesLinkADevice));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.dragUntilVisible(
      find.text(l10n.devicesScanCode),
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('reduced motion settles at once', (t) async {
    final src = _Devices([_phone, _computer('a', 'Desk')]);
    await _open(t, src, still: true);
    await t.tap(find.text('Desk'));
    await t.pump();
    expect(find.text(l10n.devicesDeviceCode), findsOneWidget);
  });

  for (final light in [false, true]) {
    testWidgets('${light ? 'light' : 'dark'} theme', (t) async {
      HaloColors.setLight(light);
      addTearDown(() => HaloColors.setLight(false));
      final src = _Devices([_phone, _computer('a', 'Desk', unlinksIn: 1)]);
      await _open(t, src);
      final name = t.widget<Text>(find.text('Desk'));
      expect(name.style!.color, HaloColors.text);
      final line = t.widget<Text>(find.text(l10n.devicesContactsSeeNothing));
      expect(line.style!.color, HaloColors.text2);
    });
  }
}
