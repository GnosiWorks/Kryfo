// SPDX-License-Identifier: GPL-3.0-or-later
// nothing opens over the app lock (lock_guard.dart)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/lock_guard.dart';

void main() {
  test('a tap waits while locked and happens once the lock lifts', () async {
    var locked = true;
    final g = LockGuard(isLocked: () => locked);
    final done = <String>[];
    await g.afterUnlock(() async => done.add('tap'));
    await g.afterUnlock(() async => done.add('link'));
    expect(done, isEmpty);
    locked = false;
    g.lifted();
    await Future<void>.delayed(Duration.zero);
    expect(done, ['tap', 'link']);
    // nothing twice, and nothing waits once it is open
    g.lifted();
    await g.afterUnlock(() async => done.add('now'));
    expect(done, ['tap', 'link', 'now']);
  });

  testWidgets('a screen pushed over the lock goes before it paints', (
    tester,
  ) async {
    var locked = false;
    final g = LockGuard(isLocked: () => locked);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        navigatorObservers: [g],
        home: const Text('home'),
      ),
    );
    final lock = PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (_, _, _) => const Text('pin'),
    );
    locked = true;
    g.lock = lock;
    nav.currentState!.push(lock);
    await tester.pumpAndSettle();
    nav.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('chat')),
    );
    // gone by the first frame after the push
    await tester.pump();
    expect(find.text('chat'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('chat'), findsNothing);
    expect(find.text('pin'), findsOneWidget);
    expect(lock.isCurrent, isTrue);

    // once it lifts, screens open as they always did
    locked = false;
    g.lock = null;
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    nav.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('chat')),
    );
    await tester.pumpAndSettle();
    expect(find.text('chat'), findsOneWidget);
  });
}
