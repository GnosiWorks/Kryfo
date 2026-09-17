import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/remembered_height.dart';

Widget _host(String id, double childHeight) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: RememberedHeight(
        id: id,
        child: SizedBox(width: 100, height: childHeight),
      ),
    ),
  ),
);

void main() {
  testWidgets('a measured row starts at that height the next time', (t) async {
    await t.pumpWidget(_host('a', 200));
    expect(t.getSize(find.byType(RememberedHeight)).height, 200);
    // built again before its content has any height, as an undecoded photo is
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(_host('a', 0));
    expect(t.getSize(find.byType(RememberedHeight)).height, 200);
  });

  testWidgets('a short first layout is not remembered', (t) async {
    await t.pumpWidget(_host('b', 4));
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(_host('b', 0));
    expect(t.getSize(find.byType(RememberedHeight)).height, 0);
  });

  testWidgets('never past what the parent allows', (t) async {
    await t.pumpWidget(_host('c', 260));
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 100),
            child: const RememberedHeight(
              id: 'c',
              child: SizedBox(width: 100, height: 0),
            ),
          ),
        ),
      ),
    );
    expect(t.getSize(find.byType(RememberedHeight)).height, 100);
  });
}
