import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/swipe_to_reply.dart';

// every bubble wears this. a version of it once built its spring on first
// use, which for an unswiped bubble meant inside dispose, and a ticker made
// that late throws and stops the whole chat route from unmounting. so: pump
// one, never touch it, take it out, and demand silence.

void main() {
  testWidgets('an unswiped bubble comes and goes without a word', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeToReply(onReply: () {}, child: const Text('hello')),
        ),
      ),
    );
    expect(find.text('hello'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('hello'), findsNothing);
  });

  testWidgets('a swiped bubble settles back and calls reply', (tester) async {
    var replies = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeToReply(
            onReply: () => replies++,
            child: const SizedBox(width: 300, height: 60),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(SwipeToReply), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(replies, 1);
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
