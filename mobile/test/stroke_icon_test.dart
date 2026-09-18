import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/stroke_icon.dart';

const chats =
    'M4.5 6.8A2.8 2.8 0 0 1 7.3 4h9.4a2.8 2.8 0 0 1 2.8 2.8v6.4a2.8 2.8 0 0 1-2.8 2.8H11l-4.3 3.4V16a2.8 2.8 0 0 1-2.2-2.8z';
const tools =
    'M14.8 6.2a4.2 4.2 0 0 0-5.6 5.3L4 16.7 7.3 20l5.2-5.2a4.2 4.2 0 0 0 5.3-5.6l-2.5 2.5-2.7-.6-.6-2.7z';
const support =
    'M12 19.5s-7-4.3-7-9.6A3.9 3.9 0 0 1 12 7.6a3.9 3.9 0 0 1 7 2.3c0 5.3-7 9.6-7 9.6z';
const me =
    'M15.6 8.5a3.6 3.6 0 1 1-7.2 0 3.6 3.6 0 1 1 7.2 0zM5 19.5c1.3-3.4 4-4.9 7-4.9s5.7 1.5 7 4.9';

void main() {
  test('the four tab icons parse and stay inside the 24 box', () {
    for (final d in [chats, tools, support, me]) {
      final b = parseSvgPath(d).getBounds();
      expect(b.left, greaterThanOrEqualTo(0), reason: d);
      expect(b.top, greaterThanOrEqualTo(0), reason: d);
      expect(b.right, lessThanOrEqualTo(24), reason: d);
      expect(b.bottom, lessThanOrEqualTo(24), reason: d);
      expect(b.width, greaterThan(10), reason: d);
    }
  });

  test('relative and absolute forms land in the same place', () {
    final a = parseSvgPath('M2 2L10 2L10 10Z').getBounds();
    final r = parseSvgPath('m2 2h8v8z').getBounds();
    expect(a, r);
  });

  test('numbers run together the way svg writes them', () {
    final b = parseSvgPath('M1 1l2.5-.5.5 2').getBounds();
    expect(b.right, closeTo(4, 1e-9));
    expect(b.top, closeTo(0.5, 1e-9));
    expect(b.bottom, closeTo(2.5, 1e-9));
  });

  test('a circle from two arcs is round', () {
    final b = parseSvgPath(
      'M15.6 8.5a3.6 3.6 0 1 1-7.2 0 3.6 3.6 0 1 1 7.2 0z',
    ).getBounds();
    expect(b.width, closeTo(7.2, 0.01));
    expect(b.height, closeTo(7.2, 0.01));
  });

  test('a smooth curve mirrors the last control point', () {
    final s = parseSvgPath('M0 10c0-10 10-10 10 0s10 10 10 0');
    final c = parseSvgPath('M0 10c0-10 10-10 10 0c0 10 10 10 10 0');
    expect(s.getBounds(), c.getBounds());
  });

  test('garbage throws, it does not draw something else', () {
    expect(() => parseSvgPath('M1 1 Q 2 2 3 3'), throwsFormatException);
    expect(() => parseSvgPath('1 2 3'), throwsFormatException);
    expect(() => parseSvgPath('M1 1 L x y'), throwsFormatException);
  });

  testWidgets('it takes the size it is given', (t) async {
    await t.pumpWidget(
      const Center(
        child: StrokeIcon([chats], size: 21, color: Color(0xFFFFFFFF)),
      ),
    );
    expect(t.getSize(find.byType(StrokeIcon)), const Size(21, 21));
  });
}
