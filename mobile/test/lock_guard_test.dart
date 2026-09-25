// SPDX-License-Identifier: GPL-3.0-or-later
// nothing gets past the app lock (lock_guard.dart)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/theme.dart';

// an app with the guard on its navigator and a gate that puts a lock
// route up the way _LockGate does
class _Harness {
  _Harness(this.tester);
  final WidgetTester tester;
  bool locked = false;
  late final LockGuard g = LockGuard(isLocked: () => locked)
    ..onLockLost = pushLock;
  final nav = GlobalKey<NavigatorState>();
  late BuildContext inside;

  Future<void> pump() => tester.pumpWidget(
    MaterialApp(
      navigatorKey: nav,
      scaffoldMessengerKey: haloMessengerKey,
      navigatorObservers: [g],
      home: Scaffold(
        body: Builder(
          builder: (c) {
            inside = c;
            return const Text('home');
          },
        ),
      ),
    ),
  );

  void pushLock() {
    // as _LockGate builds it: up at once, fading only on the way out
    final r = PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
      pageBuilder: (_, _, _) =>
          const ScaffoldMessenger(child: Scaffold(body: Text('pin'))),
    );
    g.lock = r;
    nav.currentState!.push(r);
  }

  Future<void> lockUp() async {
    locked = true;
    g.locking();
    pushLock();
    await tester.pumpAndSettle();
  }

  Future<void> unlock() async {
    locked = false;
    final l = g.lock!;
    g.lock = null;
    nav.currentState!.removeRoute(l);
    g.lifted();
    await tester.pumpAndSettle();
  }

  void push(String name) => nav.currentState!.push(
    MaterialPageRoute<void>(builder: (_) => Scaffold(body: Text(name))),
  );
}

void main() {
  test('a tap waits while locked and happens once the lock lifts', () async {
    var locked = true;
    final g = LockGuard(isLocked: () => locked);
    final done = <String>[];
    await g.afterUnlock(() async => done.add('tap'), key: 'chat:a');
    await g.afterUnlock(() async => done.add('link'), key: 'link:x');
    // the same chat tapped again while locked opens once
    await g.afterUnlock(() async => done.add('tap again'), key: 'chat:a');
    expect(done, isEmpty);
    locked = false;
    g.lifted();
    await Future<void>.delayed(Duration.zero);
    expect(done, ['link', 'tap again']);
    // nothing twice, and nothing waits once it is open
    g.lifted();
    await g.afterUnlock(() async => done.add('now'));
    expect(done, ['link', 'tap again', 'now']);
    // a link arriving by two routes at once is handled once
    await g.afterUnlock(() async => done.add('dup'), key: 'link:y');
    await g.afterUnlock(() async => done.add('dup'), key: 'link:y');
    expect(done.where((d) => d == 'dup').length, 1);
  });

  test('what is open closes when the lock goes up, and only once', () {
    final g = LockGuard(isLocked: () => false);
    var menu = 0, player = 0;
    g.closeOnLock(() => menu++);
    final unguard = g.closeOnLock(() => player++);
    unguard();
    g.locking();
    g.locking();
    expect(menu, 1);
    expect(player, 0);
  });

  test('what starts after the lock went up closes at once', () async {
    final g = LockGuard(isLocked: () => true);
    var closed = 0;
    final unguard = g.closeOnLock(() => closed++);
    // taking it off the list does not stop it closing
    unguard();
    await Future<void>.delayed(Duration.zero);
    expect(closed, 1);
    g.locking();
    expect(closed, 1);
  });

  test('a system dialog waits for the lock to lift', () async {
    var locked = true;
    final g = LockGuard(isLocked: () => locked);
    var opened = false;
    unawaited(g.unlocked().then((_) => opened = true));
    await Future<void>.delayed(Duration.zero);
    expect(opened, isFalse);
    locked = false;
    g.lifted();
    await Future<void>.delayed(Duration.zero);
    expect(opened, isTrue);
    // and does not wait at all while the app is open
    var now = false;
    await g.unlocked().then((_) => now = true);
    expect(now, isTrue);
  });

  testWidgets('a screen pushed while locked waits under the lock', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.pump();
    await h.lockUp();
    h.push('sheet');
    // not one frame of it shows
    await tester.pump();
    expect(find.text('sheet'), findsNothing);
    expect(find.text('pin'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('sheet'), findsNothing);
    expect(h.g.lock!.isCurrent, isTrue);
    // after the pin it is there, not lost
    await h.unlock();
    expect(find.text('sheet'), findsOneWidget);
  });

  testWidgets('a pop from under the lock does not take the lock down', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.pump();
    h.push('chat');
    await tester.pumpAndSettle();
    await h.lockUp();
    // what a screen under the lock does when an async result lands: its
    // pop reaches the top route, which is the lock
    h.nav.currentState!.pop();
    await tester.pump();
    expect(find.text('chat'), findsNothing);
    expect(find.text('pin'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('chat'), findsNothing);
    expect(h.g.lock!.isCurrent, isTrue);
    // and a removal of the lock route, the same
    h.nav.currentState!.removeRoute(h.g.lock!);
    await tester.pump();
    expect(find.text('pin'), findsOneWidget);
    expect(find.text('chat'), findsNothing);
    await h.unlock();
    expect(find.text('chat'), findsOneWidget);
  });

  testWidgets('something drawn above the routes after the lock went up '
      'is gone before its first frame', (tester) async {
    final h = _Harness(tester);
    await h.pump();
    await h.lockUp();
    // what a message menu does when its db write ends after the lock
    final entry = OverlayEntry(
      builder: (_) => const Positioned.fill(child: Text('menu')),
    );
    h.nav.currentState!.overlay!.insert(entry);
    var gone = false;
    h.g.closeOnLock(() {
      if (gone) return;
      gone = true;
      entry.remove();
    });
    await tester.pump();
    expect(find.text('menu'), findsNothing);
    expect(find.text('pin'), findsOneWidget);
  });

  testWidgets('a toast waits for the lock and never shows on the pin pad', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.pump();
    haloWhenOpen = (act) => h.g.afterUnlock(act);
    addTearDown(() => haloWhenOpen = null);
    await h.lockUp();
    showHaloToast(h.inside, 'joined the room');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('joined the room'), findsNothing);
    await h.unlock();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('joined the room'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
