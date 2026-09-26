// SPDX-License-Identifier: GPL-3.0-or-later
// what the app lock's layer cannot cover by drawing (lock_guard.dart)
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/lock_guard.dart';

void main() {
  test('a tap waits for the lock to lift', () async {
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

  test('open menus close once on lock', () {
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

  test('a menu opened while locked closes at once', () async {
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

  test('a system dialog waits for unlock', () async {
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

  test('a decoy unlock drops what waited, and a dialog gives up', () async {
    var locked = true;
    final g = LockGuard(isLocked: () => locked);
    final done = <String>[];
    await g.afterUnlock(() async => done.add('tap'), key: 'chat:a');
    Object? gaveUp;
    unawaited(g.unlocked().catchError((Object e) => gaveUp = e));
    locked = false;
    g.dropHeld();
    await Future<void>.delayed(Duration.zero);
    expect(gaveUp, isA<LockDropped>());
    // and nothing of it comes back on a later everyday unlock
    g.lifted();
    await Future<void>.delayed(Duration.zero);
    expect(done, isEmpty);
  });
}
