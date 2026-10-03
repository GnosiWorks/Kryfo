import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/halo_sheet.dart';
import 'package:kryfo/widgets/sheet_handle.dart';

void main() {
  testWidgets('showHaloSheet opens rounded and returns a value', (
    tester,
  ) async {
    String? got;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () {
              showHaloSheet<String>(
                ctx,
                builder: (c) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SheetHandle(),
                    TextButton(
                      onPressed: () => Navigator.pop(c, 'picked'),
                      child: const Text('pick'),
                    ),
                  ],
                ),
              ).then((v) => got = v);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // one frame to start the route, then the rise finishes inside 300ms
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    final shape = sheet.shape as RoundedRectangleBorder;
    expect(
      shape.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(kSheetRadius)),
    );
    expect(find.byType(SheetHandle), findsOneWidget);
    await tester.tap(find.text('pick'), warnIfMissed: true);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(got, 'picked');
    expect(find.byType(BottomSheet), findsNothing);
  });

  // a sheet that leaves scrolling to showHaloSheet scrolls as one. a scroll
  // view of its own inside takes every drag and never moves, and what lies
  // below the screen cannot be reached
  test('no sheet scrolls inside the sheet scroll', () {
    final bad = <String>[];
    final calls = RegExp(r'showHaloSheet(<[^>]*>)?\(');
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in calls.allMatches(src)) {
        var depth = 1;
        var i = m.end;
        while (depth > 0 && i < src.length) {
          final c = src[i++];
          if (c == '(') depth++;
          if (c == ')') depth--;
        }
        final call = src.substring(m.start, i);
        if (call.contains('scroll: true')) continue;
        final own =
            call.contains('SingleChildScrollView(') ||
            call.contains('CustomScrollView(') ||
            RegExp(r'(ListView|GridView)(\.builder)?\(').hasMatch(call) &&
                !call.contains('NeverScrollableScrollPhysics');
        if (own) {
          bad.add('${f.path}:${src.substring(0, m.start).split('\n').length}');
        }
      }
    }
    expect(bad, isEmpty);
  });
}
