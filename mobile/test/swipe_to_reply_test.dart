import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/swipe_to_reply.dart';

// a ticker made inside dispose throws and keeps the chat route from
// unmounting, so an untouched bubble has to come and go cleanly

void main() {
  testWidgets('an unswiped bubble unmounts cleanly', (
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
