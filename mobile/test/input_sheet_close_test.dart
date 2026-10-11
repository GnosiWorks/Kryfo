// SPDX-License-Identifier: GPL-3.0-or-later
// the input sheet keeps its field alive for as long as it is drawn: save,
// cancel and a swipe down all run the whole slide away with nothing used
// after it was let go, with movement and without
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/widgets/confirm_sheet.dart';

Widget _host(Widget child, {bool still = false}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (ctx, c) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: c!,
  ),
  home: Scaffold(body: Center(child: child)),
);

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

void _quiet(WidgetTester t) {
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

const _title = 'Edit message';

// opens the sheet as the chat's edit does, and keeps what it gave back
Future<List<String?>> _open(WidgetTester t, {bool still = false}) async {
  _phone(t);
  _quiet(t);
  final got = <String?>[];
  await t.pumpWidget(
    _host(
      still: still,
      Builder(
        builder: (ctx) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async => got.add(
            await showInputSheet(
              ctx,
              title: _title,
              initial: 'T 1',
              multiline: true,
              maxLength: 4096,
            ),
          ),
          child: const SizedBox(width: 80, height: 80, child: Text('go')),
        ),
      ),
    ),
  );
  await t.tap(find.text('go'));
  await t.pumpAndSettle();
  expect(find.text(_title), findsOneWidget);
  return got;
}

bool _disposed(ChangeNotifier c) {
  try {
    ChangeNotifier.debugAssertNotDisposed(c);
    return false;
  } on FlutterError {
    return true;
  }
}

TextEditingController _field(WidgetTester t) =>
    t.widget<TextField>(find.byType(TextField)).controller!;

// every frame of the way out, then the route is gone and its controller
// with it
Future<void> _closesClean(WidgetTester t, TextEditingController ctrl) async {
  for (var i = 0; i < 30; i++) {
    await t.pump(const Duration(milliseconds: 16));
    expect(t.takeException(), isNull);
  }
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
  expect(find.text(_title), findsNothing);
  expect(find.byType(TextField), findsNothing);
  expect(_disposed(ctrl), isTrue);
}

void main() {
  for (final still in [false, true]) {
    final how = still ? ' with less movement' : '';

    testWidgets('save closes the sheet cleanly$how', (t) async {
      final got = await _open(t, still: still);
      final ctrl = _field(t);
      await t.enterText(find.byType(TextField), 'T 1 edited');
      await t.pump();
      await t.tap(find.text('Save'));
      await _closesClean(t, ctrl);
      expect(got, ['T 1 edited']);
    });

    testWidgets('cancel closes the sheet cleanly$how', (t) async {
      final got = await _open(t, still: still);
      final ctrl = _field(t);
      await t.enterText(find.byType(TextField), 'T 1 changed my mind');
      await t.pump();
      await t.tap(find.text('Cancel'));
      await _closesClean(t, ctrl);
      expect(got, [null]);
    });

    testWidgets('a swipe down closes the sheet cleanly$how', (t) async {
      final got = await _open(t, still: still);
      final ctrl = _field(t);
      await t.enterText(find.byType(TextField), 'T 1 swiped');
      await t.pump();
      await t.fling(find.text(_title), const Offset(0, 600), 2000);
      await _closesClean(t, ctrl);
      expect(got, [null]);
    });
  }

  testWidgets('the field keeps its words through the slide away', (t) async {
    await _open(t);
    final ctrl = _field(t);
    await t.enterText(find.byType(TextField), 'still here');
    await t.pump();
    await t.tap(find.text('Save'));
    // halfway out the field is still drawn with what was written
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('still here'), findsOneWidget);
    expect(_disposed(ctrl), isFalse);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(_disposed(ctrl), isTrue);
  });
}
