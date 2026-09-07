import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/shift_in_place.dart';

Widget _list(List<String> order) => MaterialApp(
  home: ListView(
    children: [
      for (final id in order)
        ShiftInPlace(
          key: ValueKey(id),
          child: SizedBox(height: 60, child: Text(id)),
        ),
    ],
  ),
);

double _dy(WidgetTester t, String id) {
  final tr = t.widget<Transform>(
    find.ancestor(of: find.text(id), matching: find.byType(Transform)).first,
  );
  return tr.transform.getTranslation().y;
}

void main() {
  testWidgets('a row that moves to the top slides there', (tester) async {
    await tester.pumpWidget(_list(['a', 'b', 'c']));
    await tester.pump();
    expect(_dy(tester, 'c'), 0);
    await tester.pumpWidget(_list(['c', 'a', 'b']));
    // the frame after the reorder: c is drawn at the top but still offset
    // down toward where it came from
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_dy(tester, 'c'), greaterThan(40));
    expect(_dy(tester, 'a'), lessThan(-20));
    await tester.pumpAndSettle();
    expect(_dy(tester, 'c'), 0);
    expect(_dy(tester, 'a'), 0);
  });

  testWidgets('a rebuild without a move stays put', (tester) async {
    await tester.pumpWidget(_list(['a', 'b']));
    await tester.pump();
    await tester.pumpWidget(_list(['a', 'b']));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_dy(tester, 'b'), 0);
  });
}
