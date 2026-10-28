// SPDX-License-Identifier: GPL-3.0-or-later
// the icon and notifications screen: the grid marks the phone's icon, a
// pick moves the ring and the preview and changes nothing until confirmed,
// a confirm switches and the app opens again. without a PIN the sheet
// offers one. a decoy reads and writes the phone's values. right to left,
// big text, reduced motion and a screen reader each hold
import 'package:flutter/material.dart';
import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/rendering.dart' show SemanticsData;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_icon.dart';
import 'package:kryfo/battery_brand.dart' show PhoneBrand;
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_guard.dart' show LockGuard;
import 'package:kryfo/notifications.dart';
import 'package:kryfo/screens/icon_screen.dart';
import 'package:kryfo/widgets/app_face_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart' show devApp, devWorld;

class _Faces implements AppFaceChannel {
  AppFace face;
  final asked = <AppFace>[];
  bool ok = true;
  _Faces(this.face);
  @override
  Future<AppFace?> read() async => face;
  @override
  Future<bool> switchTo(AppFace f) async {
    asked.add(f);
    return ok;
  }
}

class _Shade extends AndroidFlutterLocalNotificationsPlugin {
  var cleared = 0;
  @override
  Future<void> cancelAll() async => cleared++;
  @override
  Future<void> createNotificationChannel(AndroidNotificationChannel c) async {}
}

late _Faces _faces;
late _Shade _shade;
// what the app's restart was asked
var _reopened = 0;

Future<void> _world({
  AppFace face = AppFace.kryfo,
  Map<String, Object> prefs = const {},
  HaloContainer container = HaloContainer.everyday,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  FlutterSecureStorage.setMockInitialValues({});
  forgetNotifPlain();
  forgetAppFace();
  _faces = _Faces(face);
  appFaceChannel = _faces;
  _shade = _Shade();
  FlutterLocalNotificationsPlatform.instance = _shade;
  _reopened = 0;
  await devWorld(container: container);
}

Future<void> _open(
  WidgetTester t, {
  bool still = false,
  double scale = 1,
  Locale locale = const Locale('en'),
  Size size = const Size(400, 1400),
  Future<bool> Function(AppFace)? onSwitch,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  setL10nLocale(locale);
  addTearDown(() => setL10nLocale(const Locale('en')));
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('halo/platform'),
    (_) async => true,
  );
  await t.pumpWidget(
    devApp(
      IconScreen(
        hideLine: () async => hideAppsLine(PhoneBrand.samsung, 34),
        guard: LockGuard(isLocked: () => false),
        onSwitch:
            onSwitch ??
            (f) async {
              final ok = await switchAppFace(f);
              if (ok) _reopened++;
              return ok;
            },
      ),
      still: still,
      scale: scale,
      locale: locale,
    ),
  );
  await t.pumpAndSettle();
}

Finder _tile(AppFace f) => find.bySemanticsLabel(l10n.iconButtonLabel(f.label));

SemanticsData _sem(WidgetTester t, Finder f) =>
    t.getSemantics(f).getSemanticsData();

// the ring is the one box with the accent's border, drawn behind the icons
Rect _ring(WidgetTester t) => t.getRect(
  find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).border?.top.width == 2 &&
        (w.decoration as BoxDecoration).shape == BoxShape.rectangle,
  ),
);

void main() {
  testWidgets('the grid marks the icon the phone shows', (t) async {
    await _world(face: AppFace.tasks);
    final h = t.ensureSemantics();
    await _open(t);
    for (final f in AppFace.values) {
      final d = _sem(t, _tile(f));
      expect(
        d.flagsCollection.isSelected == Tristate.isTrue,
        f == AppFace.tasks,
        reason: f.name,
      );
      expect(d.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      expect(d.flagsCollection.isButton, isTrue);
    }
    // the preview says one line, the icon in it nothing more
    expect(
      find.bySemanticsLabel(l10n.iconPreviewLabel(AppFace.tasks.label)),
      findsOneWidget,
    );
    expect(find.text(l10n.iconHint), findsOneWidget);
    // nothing to confirm until a different one is picked
    expect(find.text(l10n.iconConfirmButton), findsNothing);
    h.dispose();
  });

  testWidgets('a pick moves the ring and changes nothing yet', (t) async {
    await _world();
    await _open(t);
    final before = _ring(t);
    await t.tap(_tile(AppFace.notes));
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    final mid = _ring(t);
    await t.pumpAndSettle();
    final after = _ring(t);
    // it springs over, not jumps
    expect(mid.left, greaterThan(before.left));
    expect(mid.left, lessThan(after.left));
    expect(
      after.center.dx,
      closeTo(t.getCenter(find.byType(AppFaceIcon).at(2)).dx, 1),
    );
    expect(_faces.asked, isEmpty);
    expect(find.text(l10n.iconConfirmButton), findsOneWidget);
    expect(find.text(l10n.iconHintKryfo), findsNothing);
    // back to the one in use: nothing to confirm again
    await t.tap(_tile(AppFace.kryfo));
    await t.pumpAndSettle();
    expect(find.text(l10n.iconConfirmButton), findsNothing);
  });

  testWidgets('no PIN: the sheet offers one, and a confirm switches', (
    t,
  ) async {
    await _world(prefs: {'kept_drafts': 'x'});
    await _open(t);
    await t.tap(_tile(AppFace.weather));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.iconConfirmButton));
    await t.pumpAndSettle();
    expect(
      find.text(l10n.iconConfirmTitle(AppFace.weather.label)),
      findsOneWidget,
    );
    expect(
      find.text(l10n.iconConfirmLine(AppFace.weather.label)),
      findsOneWidget,
    );
    expect(find.text(l10n.iconNoPinLine), findsOneWidget);
    expect(find.text(l10n.iconSetPin), findsOneWidget);
    // offered, not asked for: change icon is still the main answer
    await t.tap(find.text(l10n.iconConfirmButton).last);
    await t.pumpAndSettle();
    expect(_faces.asked, [AppFace.weather]);
    expect(_reopened, 1);
    // what the shade held would name the old entry
    expect(_shade.cleared, 1);
    // and the next start says it worked, once
    expect(await takeFaceChanged(), isTrue);
    expect(await takeFaceChanged(), isFalse);
  });

  testWidgets('a switch android will not take says so and stays', (t) async {
    await _world();
    _faces.ok = false;
    await _open(t);
    await t.tap(_tile(AppFace.news));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.iconConfirmButton));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.iconConfirmButton).last);
    await t.pumpAndSettle();
    expect(_faces.asked, [AppFace.news]);
    expect(_reopened, 0);
    expect(await takeFaceChanged(), isFalse);
    expect(find.text(l10n.iconConfirmButton), findsOneWidget);
  });

  testWidgets('the three choices are one radio group, plain the phone\'s', (
    t,
  ) async {
    await _world(prefs: {'notif_hide_content': true});
    final h = t.ensureSemantics();
    await _open(t);
    bool checked(String label) =>
        _sem(
          t,
          find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}')),
        ).flagsCollection.isChecked ==
        CheckedState.isTrue;
    expect(checked(l10n.notifShowNew), isTrue);
    expect(checked(l10n.notifShowAll), isFalse);
    expect(checked(l10n.notifShowPlain), isFalse);
    await t.tap(find.text(l10n.notifShowPlain));
    await t.pumpAndSettle();
    expect(checked(l10n.notifShowPlain), isTrue);
    expect(checked(l10n.notifShowNew), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('notif_plain'), isTrue);
    // the preview setting is left as it was, for when plain goes off
    expect(prefs.getBool('notif_hide_content'), isTrue);
    expect(find.text(l10n.notifHeaderLimit), findsOneWidget);
    await t.tap(find.text(l10n.notifShowAll));
    await t.pumpAndSettle();
    expect(prefs.getBool('notif_plain'), isFalse);
    expect(prefs.getBool('notif_hide_content'), isFalse);
    h.dispose();
  });

  testWidgets('a decoy reads and writes the phone\'s values', (t) async {
    await _world(
      face: AppFace.notes,
      prefs: {'notif_plain': true},
      container: HaloContainer.decoy,
    );
    await _open(t);
    expect(
      _sem(t, _tile(AppFace.notes)).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(find.text(l10n.notifHeaderLimit), findsOneWidget);
    await t.tap(find.text(l10n.notifShowNew));
    await t.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('notif_plain'), isFalse);
    // the preview is the decoy's own
    expect(prefs.getBool('d.notif_hide_content'), isTrue);
    expect(prefs.getBool('notif_hide_content'), isNull);
  });

  testWidgets('right to left: the first icon is at the right', (t) async {
    await _world();
    await _open(t, locale: const Locale('ar'));
    final kryfo = t.getCenter(_tile(AppFace.kryfo));
    final news = t.getCenter(_tile(AppFace.news));
    expect(kryfo.dx, greaterThan(news.dx));
    expect(t.takeException(), isNull);
  });

  for (final scale in [1.5, 2.0]) {
    testWidgets('text at $scale: fewer across, nothing cut, the button '
        'at the bottom', (t) async {
      await _world();
      await _open(t, scale: scale, size: const Size(360, 740));
      expect(t.takeException(), isNull);
      final first = t.getCenter(_tile(AppFace.kryfo)).dy;
      final across = AppFace.values
          .where((f) => (t.getCenter(_tile(f)).dy - first).abs() < 1)
          .length;
      expect(across, scale >= 2 ? 2 : 3);
      await t.tap(_tile(AppFace.news));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      // the page scrolls to it rather than dropping it under the bar
      final button = find.text(l10n.iconConfirmButton);
      await t.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      expect(t.getRect(button).bottom, lessThanOrEqualTo(740));
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('reduced motion: the ring jumps', (t) async {
    await _world();
    await _open(t, still: true);
    await t.tap(_tile(AppFace.tasks));
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
    final at = _ring(t);
    await t.pumpAndSettle();
    expect(_ring(t), at);
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('what this changes: the limits, and the phone\'s own way', (
    t,
  ) async {
    await _world();
    await _open(t);
    await t.tap(find.text(l10n.iconWhatChanges));
    await t.pumpAndSettle();
    expect(find.text(l10n.iconSheetGlance), findsOneWidget);
    expect(find.text(l10n.iconSheetStays), findsOneWidget);
    expect(find.text(l10n.iconSheetSecureFolder), findsOneWidget);
    // what other apps and android still see, and where new saves go
    expect(find.text(l10n.iconSheetOthers), findsOneWidget);
    expect(find.text(l10n.iconSheetSaves), findsOneWidget);
  });

  test('the phone\'s own way to hide apps, only where kryfo knows it', () {
    expect(hideAppsLine(PhoneBrand.samsung, 30), l10n.iconSheetSecureFolder);
    expect(hideAppsLine(PhoneBrand.xiaomi, 35), l10n.iconSheetXiaomi);
    expect(hideAppsLine(PhoneBrand.other, 35), l10n.iconSheetPrivateSpace);
    expect(hideAppsLine(PhoneBrand.oppo, 34), isNull);
  });

  test('plain wins over the preview setting', () {
    expect(notifShowOf(plain: true, hidden: false), NotifShow.plain);
    expect(notifShowOf(plain: false, hidden: true), NotifShow.newMessage);
    expect(notifShowOf(plain: false, hidden: false), NotifShow.all);
  });
}
