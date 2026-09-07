import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/halo_sheet.dart';
import 'package:kryfo/widgets/sheet_handle.dart';

void main() {
  testWidgets('showHaloSheet opens with the house shape and returns a value', (
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
}
