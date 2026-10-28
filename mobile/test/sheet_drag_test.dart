// SPDX-License-Identifier: GPL-3.0-or-later
// a sheet drags down to close from anywhere on it, its handle too, and a
// quick fling closes it. a sheet that scrolls takes the pull at its top and
// scrolls its content back up first. pumped with the app's own scroll feel,
// which scrolls every scroll view always
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_shell.dart' show HaloScrollBehavior;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show showAddContact;
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/halo_sheet.dart';
import 'package:kryfo/widgets/sheet_handle.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(
  void Function(BuildContext) open, {
  bool still = false,
  double text = 1,
}) => MaterialApp(
  theme: buildHaloTheme(),
  scrollBehavior: const HaloScrollBehavior(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(
      ctx,
    ).copyWith(disableAnimations: still, textScaler: TextScaler.linear(text)),
    child: child!,
  ),
  home: Builder(
    builder: (c) => Scaffold(
      body: Center(
        child: TextButton(onPressed: () => open(c), child: const Text('open')),
      ),
    ),
  ),
);

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(720, 1600);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

Future<void> _open(WidgetTester t) async {
  await t.tap(find.text('open'));
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

Finder get _sheet => find.byType(BottomSheet);
double _top(WidgetTester t) => t.getTopLeft(_sheet).dy;

// a long sheet: forty rows under a handle, more than the screen holds
Widget _long(BuildContext c) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    const SheetHandle(),
    for (var i = 0; i < 40; i++)
      SizedBox(height: 56, child: Center(child: Text('row $i'))),
  ],
);

// the scroll view nearest a row
ScrollPosition _pos(WidgetTester t, String row) =>
    Scrollable.of(t.element(find.text(row))).position;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('add someone', () {
    Future<void> openAdd(
      WidgetTester t, {
      bool still = false,
      double text = 1,
    }) async {
      _phone(t);
      await t.pumpWidget(_app(showAddContact, still: still, text: text));
      await _open(t);
      expect(find.text(l10n.appAddSomeone), findsOneWidget);
    }

    testWidgets('a drag down from the middle closes it', (t) async {
      await openAdd(t);
      await t.drag(find.text(l10n.appScanTheirCodeOr), const Offset(0, 400));
      await t.pumpAndSettle();
      expect(find.text(l10n.appAddSomeone), findsNothing);
    });

    testWidgets('the sheet follows the finger and springs back from a '
        'short pull', (t) async {
      await openAdd(t);
      final rest = _top(t);
      final g = await t.startGesture(
        t.getCenter(find.text(l10n.appScanTheirCodeOr)),
      );
      await g.moveBy(const Offset(0, 20));
      await g.moveBy(const Offset(0, 60));
      await t.pump();
      expect(_top(t), greaterThan(rest + 40));
      await t.pump(const Duration(milliseconds: 200));
      await g.up();
      await t.pumpAndSettle();
      expect(_top(t), rest);
    });

    testWidgets('the handle drags it', (t) async {
      await openAdd(t);
      await t.drag(find.byType(SheetHandle), const Offset(0, 400));
      await t.pumpAndSettle();
      expect(find.text(l10n.appAddSomeone), findsNothing);
    });

    testWidgets('a quick fling down closes it', (t) async {
      await openAdd(t);
      await t.fling(find.text(l10n.appAddSomeone), const Offset(0, 80), 1600);
      await t.pumpAndSettle();
      expect(find.text(l10n.appAddSomeone), findsNothing);
    });

    testWidgets('a drag on the field closes it too', (t) async {
      await openAdd(t);
      await t.drag(find.byType(TextField), const Offset(0, 400));
      await t.pumpAndSettle();
      expect(find.text(l10n.appAddSomeone), findsNothing);
    });

    testWidgets('with the keyboard up the field still types, and a drag '
        'down closes the sheet', (t) async {
      await openAdd(t);
      await t.tap(find.byType(TextField));
      t.view.viewInsets = const FakeViewPadding(bottom: 1200);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '@wren');
      await t.pump();
      expect(find.text('@wren'), findsOneWidget);
      // the sheet scrolls under the keyboard: up to its top first
      final g = await t.startGesture(t.getCenter(find.text('@wren')));
      for (var i = 0; i < 30; i++) {
        await g.moveBy(const Offset(0, 20));
        await t.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await t.pumpAndSettle();
      expect(find.text(l10n.appAddSomeone), findsNothing);
    });

    testWidgets('a drag up moves neither the sheet nor its content', (t) async {
      await openAdd(t);
      final rest = _top(t);
      final title = t.getTopLeft(find.text(l10n.appAddSomeone));
      final g = await t.startGesture(
        t.getCenter(find.text(l10n.appScanTheirCodeOr)),
      );
      for (var i = 0; i < 6; i++) {
        await g.moveBy(const Offset(0, -20));
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(_top(t), rest);
      expect(t.getTopLeft(find.text(l10n.appAddSomeone)), title);
      await g.up();
      await t.pumpAndSettle();
    });

    testWidgets('large text: a drag down still closes it', (t) async {
      await openAdd(t, text: 1.3);
      await t.drag(find.text(l10n.appScanTheirCodeOr), const Offset(0, 500));
      await t.pumpAndSettle();
      expect(find.text(l10n.appAddSomeone), findsNothing);
    });

    testWidgets('reduced motion: a drag down still closes it', (t) async {
      await openAdd(t, still: true);
      await t.drag(find.text(l10n.appScanTheirCodeOr), const Offset(0, 400));
      await t.pumpAndSettle();
      expect(find.text(l10n.appAddSomeone), findsNothing);
    });
  });

  group('a sheet taller than the screen', () {
    Future<void> openLong(WidgetTester t, {bool scroll = false}) async {
      _phone(t);
      await t.pumpWidget(
        _app(
          (c) => showHaloSheet<void>(
            c,
            scroll: scroll,
            builder: scroll
                ? (s) => SizedBox(
                    height: 500,
                    child: ListView(
                      children: [
                        for (var i = 0; i < 40; i++)
                          SizedBox(
                            height: 56,
                            child: Center(child: Text('row $i')),
                          ),
                      ],
                    ),
                  )
                : _long,
          ),
        ),
      );
      await _open(t);
    }

    testWidgets('a drag down at its top closes it', (t) async {
      await openLong(t);
      await t.drag(find.text('row 3'), const Offset(0, 500));
      await t.pumpAndSettle();
      expect(_sheet, findsNothing);
    });

    testWidgets('scrolled down, a drag down scrolls it up first', (t) async {
      await openLong(t);
      final rest = _top(t);
      await t.drag(find.text('row 6'), const Offset(0, -300));
      await t.pumpAndSettle();
      final pos = _pos(t, 'row 8');
      final scrolled = pos.pixels;
      expect(scrolled, greaterThan(250));
      // less than it scrolled: the content moves, the sheet stays
      await t.drag(find.text('row 8'), const Offset(0, 150));
      await t.pumpAndSettle();
      expect(_top(t), rest);
      expect(pos.pixels, lessThan(scrolled - 100));
      // the rest of the way up, then on down: the sheet goes
      await t.drag(find.text('row 8'), const Offset(0, 700));
      await t.pumpAndSettle();
      expect(_sheet, findsNothing);
    });

    testWidgets('scrolled down, a fling down scrolls and leaves the sheet', (
      t,
    ) async {
      await openLong(t);
      final rest = _top(t);
      await t.drag(find.text('row 6'), const Offset(0, -600));
      await t.pumpAndSettle();
      await t.fling(find.text('row 12'), const Offset(0, 60), 1600);
      await t.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      expect(_top(t), rest);
    });

    testWidgets('at its top, a quick fling down closes it', (t) async {
      await openLong(t);
      await t.fling(find.text('row 2'), const Offset(0, 80), 1600);
      await t.pumpAndSettle();
      expect(_sheet, findsNothing);
    });

    testWidgets('pulled down a little and back up, it scrolls on', (t) async {
      await openLong(t);
      final rest = _top(t);
      final g = await t.startGesture(t.getCenter(find.text('row 4')));
      for (var i = 0; i < 5; i++) {
        await g.moveBy(const Offset(0, 20));
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(_top(t), greaterThan(rest + 60));
      for (var i = 0; i < 15; i++) {
        await g.moveBy(const Offset(0, -20));
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(_top(t), rest);
      expect(_pos(t, 'row 4').pixels, greaterThan(150));
      await t.pump(const Duration(milliseconds: 300));
      await g.up();
      await t.pumpAndSettle();
      expect(_top(t), rest);
    });

    testWidgets('a flick up while it still rises scrolls and keeps it', (
      t,
    ) async {
      _phone(t);
      await t.pumpWidget(_app((c) => showHaloSheet<void>(c, builder: _long)));
      await t.tap(find.text('open'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      final ctl = t.widget<BottomSheet>(_sheet).animationController!;
      expect(ctl.value, lessThan(1));
      // the part of it already on the screen
      final at = t.getTopLeft(_sheet) + const Offset(200, 60);
      expect(at.dy, lessThan(760));
      await t.flingFrom(at, const Offset(0, -120), 2000);
      await t.pump();
      await t.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      expect(ctl.value, 1);
      expect(_pos(t, 'row 2').pixels, greaterThan(0));
    });

    testWidgets('a scroll taking over mid pull lets the sheet go back up', (
      t,
    ) async {
      await openLong(t);
      final rest = _top(t);
      final pos = _pos(t, 'row 4');
      final g = await t.startGesture(t.getCenter(find.text('row 4')));
      for (var i = 0; i < 5; i++) {
        await g.moveBy(const Offset(0, 20));
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(_top(t), greaterThan(rest + 60));
      // as a field scrolling itself into view does
      unawaited(
        pos.animateTo(
          200,
          duration: const Duration(seconds: 2),
          curve: Curves.linear,
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(_top(t), rest);
      await g.up();
      await t.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      expect(_top(t), rest);
    });

    testWidgets('a sheet with a list of its own drags down from it', (t) async {
      await openLong(t, scroll: true);
      await t.drag(find.text('row 3'), const Offset(0, 500));
      await t.pumpAndSettle();
      expect(_sheet, findsNothing);
    });

    testWidgets('a sheet that may not close does not drag', (t) async {
      _phone(t);
      await t.pumpWidget(
        _app((c) => showHaloSheet<void>(c, dismissible: false, builder: _long)),
      );
      await _open(t);
      final rest = _top(t);
      await t.drag(find.text('row 3'), const Offset(0, 500));
      await t.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      expect(_top(t), rest);
    });
  });
}
