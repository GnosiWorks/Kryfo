// SPDX-License-Identifier: GPL-3.0-or-later
// the note, group edit, rename and add-a-peer sheets own their field's
// controller: it lives through the whole slide away and goes with the
// route, so nothing is used after it was let go and nothing is left over.
// every way out, with movement and without
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show showImportPeerDialog;
import 'package:kryfo/screens/chat_screen.dart' show showNoteSheet;
import 'package:kryfo/screens/contact_screen.dart' show showRenameSheet;
import 'package:kryfo/screens/group_chat_screen.dart' show showGroupEditSheet;

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

void _setUp(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

bool _disposed(ChangeNotifier c) {
  try {
    ChangeNotifier.debugAssertNotDisposed(c);
    return false;
  } on FlutterError {
    return true;
  }
}

typedef _Opener = Future<Object?> Function(BuildContext ctx);

// opens [open], writes, leaves by [close], and walks every frame out
Future<void> _run(
  WidgetTester t, {
  required _Opener open,
  required String title,
  required Future<void> Function(WidgetTester t) close,
  required Object? expected,
  bool still = false,
}) async {
  _setUp(t);
  final got = <Object?>[];
  await t.pumpWidget(
    _host(
      still: still,
      Builder(
        builder: (ctx) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async => got.add(await open(ctx)),
          child: const SizedBox(width: 80, height: 80, child: Text('go')),
        ),
      ),
    ),
  );
  await t.tap(find.text('go'));
  await t.pumpAndSettle();
  expect(find.text(title), findsOneWidget);
  final ctrl = t.widget<TextField>(find.byType(TextField)).controller!;
  await t.enterText(find.byType(TextField), 'new words');
  await t.pump();
  await close(t);
  // on its way out the field is still drawn on a live controller
  await t.pump(const Duration(milliseconds: 16));
  if (find.byType(TextField).evaluate().isNotEmpty) {
    expect(_disposed(ctrl), isFalse);
  }
  for (var i = 0; i < 30; i++) {
    await t.pump(const Duration(milliseconds: 16));
    expect(t.takeException(), isNull);
  }
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
  expect(find.text(title), findsNothing);
  expect(find.byType(TextField), findsNothing);
  // and once the route is gone, so is the controller
  expect(_disposed(ctrl), isTrue);
  expect(got, [expected]);
}

Future<void> Function(WidgetTester) _tap(String label) =>
    (t) => t.tap(find.text(label));

Future<void> Function(WidgetTester) _swipe(String title) =>
    (t) => t.fling(find.text(title), const Offset(0, 600), 2000);

Future<void> _tapOutside(WidgetTester t) => t.tapAt(const Offset(10, 10));

void main() {
  for (final still in [false, true]) {
    final how = still ? ' with reduced motion' : '';

    group('note sheet$how', () {
      const title = 'Note on this contact';
      final saved = <String>[];
      Future<Object?> open(BuildContext ctx) => showNoteSheet(
        ctx,
        initial: 'old note',
        save: (n) async => saved.add(n),
      );

      testWidgets('save', (t) async {
        saved.clear();
        await _run(
          t,
          open: open,
          title: title,
          close: _tap('Save'),
          expected: true,
          still: still,
        );
        expect(saved, ['new words']);
      });

      testWidgets('swipe down', (t) async {
        saved.clear();
        await _run(
          t,
          open: open,
          title: title,
          close: _swipe(title),
          expected: false,
          still: still,
        );
        expect(saved, isEmpty);
      });
    });

    group('group edit sheet$how', () {
      const title = 'Edit message';
      Future<Object?> open(BuildContext ctx) =>
          showGroupEditSheet(ctx, 'old words');

      testWidgets('save', (t) async {
        await _run(
          t,
          open: open,
          title: title,
          close: _tap('Save'),
          expected: 'new words',
          still: still,
        );
      });

      testWidgets('cancel', (t) async {
        await _run(
          t,
          open: open,
          title: title,
          close: _tap('Cancel'),
          expected: null,
          still: still,
        );
      });

      testWidgets('swipe down', (t) async {
        await _run(
          t,
          open: open,
          title: title,
          close: _swipe(title),
          expected: null,
          still: still,
        );
      });
    });

    group('rename sheet$how', () {
      const title = 'Your name for them';
      Future<Object?> open(BuildContext ctx) =>
          showRenameSheet(ctx, initial: 'Mum', haloId: 'some-three-words');

      testWidgets('save', (t) async {
        await _run(
          t,
          open: open,
          title: title,
          close: _tap('Save'),
          expected: 'new words',
          still: still,
        );
      });

      testWidgets('clear', (t) async {
        await _run(
          t,
          open: open,
          title: title,
          close: _tap('Clear'),
          expected: '',
          still: still,
        );
      });

      testWidgets('swipe down', (t) async {
        await _run(
          t,
          open: open,
          title: title,
          close: _swipe(title),
          expected: null,
          still: still,
        );
      });
    });

    group('add a peer dialog$how', () {
      const title = 'Add a Kryfo';

      testWidgets('import', (t) async {
        await _run(
          t,
          open: showImportPeerDialog,
          title: title,
          close: _tap('Import'),
          expected: ('paste', 'new words'),
          still: still,
        );
      });

      testWidgets('cancel', (t) async {
        await _run(
          t,
          open: showImportPeerDialog,
          title: title,
          close: _tap('Cancel'),
          expected: null,
          still: still,
        );
      });

      testWidgets('tap outside', (t) async {
        await _run(
          t,
          open: showImportPeerDialog,
          title: title,
          close: _tapOutside,
          expected: null,
          still: still,
        );
      });
    });
  }
}
