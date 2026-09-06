import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/intro_chip.dart';
import 'package:kryfo/widgets/kryfo_avatar.dart';

// the vouched request row hangs on this chip: the introducer's face, our
// name for them, amber never grey, and a green check only when we verified
// them. pinned here so a restyle cannot quietly turn it grey.

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

void main() {
  testWidgets('names the introducer in amber with their face', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const IntroducedBy(
          label: 'introduced by sam',
          seed: 'thumb-behave-boring',
          avatar: 7,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text('introduced by sam'));
    expect(text.style?.color, HaloColors.amber);
    expect(text.style?.fontSize, 12);
    final face = tester.widget<KryfoAvatar>(find.byType(KryfoAvatar));
    expect(face.seed, 'thumb-behave-boring');
    expect(face.choice, 7);
    expect(face.size, 18);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('a verified introducer gets a green check', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const IntroducedBy(
          label: 'introduced by sam',
          seed: 'x-y-z',
          verified: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final check = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
    expect(check.color, HaloColors.green);
  });

  testWidgets('waits out its delay before popping in', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const IntroducedBy(
          label: 'introduced by sam',
          seed: 'x-y-z',
          delay: Duration(milliseconds: 300),
        ),
      ),
    );
    // still invisible before the delay has passed
    await tester.pump(const Duration(milliseconds: 100));
    final chipFade = find.descendant(
      of: find.byType(IntroducedBy),
      matching: find.byType(FadeTransition),
    );
    final before = tester.widget<FadeTransition>(chipFade);
    expect(before.opacity.value, 0);
    // let the delay elapse, then the pop itself
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    final after = tester.widget<FadeTransition>(chipFade);
    expect(after.opacity.value, 1);
  });
}
