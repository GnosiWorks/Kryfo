// SPDX-License-Identifier: GPL-3.0-or-later
// a sticker on screen runs only while it can be seen and the phone lets
// things move: not under reduced motion, not under TickerMode (the app lock
// uses it), not scrolled off, and not past its surface's budget.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_shell.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/lock_layer.dart';
import 'package:kryfo/stickers/sticker_pack.dart';
import 'package:kryfo/stickers/sticker_view.dart';
import 'package:kryfo/theme.dart';

import 'sticker_test_util.dart';

Widget _plain(Widget child, {bool reduce = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduce),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  ),
);

// each element above a render object reports it again: once each
List<RenderSticker> _boxes(WidgetTester t) =>
    t.allRenderObjects.whereType<RenderSticker>().toSet().toList();

Future<void> _frames(WidgetTester t, int n) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 17));
  }
}

// frames that go on while the app is behind another user or app, which a
// phone may draw whatever the app was told
Future<void> _awayFrames(WidgetTester t, int n) async {
  for (var i = 0; i < n; i++) {
    t.binding.scheduleForcedFrame();
    await t.pump(const Duration(milliseconds: 17));
  }
}

class _Lock extends ChangeNotifier {
  bool locked = false;
  void set(bool v) {
    locked = v;
    notifyListeners();
  }
}

void main() {
  final pack = loadPack();
  final hi = pack.sticker(1)!;

  testWidgets('reduced motion draws the still and runs nothing', (t) async {
    await t.pumpWidget(
      _plain(StickerView(sticker: hi, size: 120), reduce: true),
    );
    final before = StickerView.frames;
    await _frames(t, 20);
    expect(StickerView.frames, before);
    expect(_boxes(t).single.time, -1);
    expect(t.binding.hasScheduledFrame, false);

    // the setting off: it plays
    await t.pumpWidget(_plain(StickerView(sticker: hi, size: 120)));
    await _frames(t, 20);
    expect(StickerView.frames, greaterThan(before + 10));
    expect(_boxes(t).single.time, greaterThan(0));

    // and on again while it plays: back to the still, nothing runs
    await t.pumpWidget(
      _plain(StickerView(sticker: hi, size: 120), reduce: true),
    );
    await t.pump();
    final now = StickerView.frames;
    await _frames(t, 20);
    expect(StickerView.frames, now);
    expect(_boxes(t).single.time, -1);
    expect(t.binding.hasScheduledFrame, false);
  });

  testWidgets('after its loops it rests and nothing runs', (t) async {
    final loop = hi.loopMs;
    await t.pumpWidget(_plain(StickerView(sticker: hi, size: 120, loops: 2)));
    await _frames(t, 10);
    expect(_boxes(t).single.time, greaterThanOrEqualTo(0));
    // two loops and a little
    await _frames(t, (2 * loop / 17).ceil() + 5);
    expect(_boxes(t).single.time, -1);
    expect(t.binding.hasScheduledFrame, false);
    final rested = StickerView.frames;
    await _frames(t, 60);
    expect(StickerView.frames, rested);

    // a replay: from the rest pose at once, then rests again
    await t.pumpWidget(
      _plain(StickerView(sticker: hi, size: 120, loops: 2, replay: 1)),
    );
    await _frames(t, 10);
    expect(StickerView.frames, greaterThan(rested + 5));
    expect(_boxes(t).single.time, greaterThan(0));
    await _frames(t, (2 * loop / 17).ceil() + 5);
    expect(_boxes(t).single.time, -1);
    expect(t.binding.hasScheduledFrame, false);
  });

  testWidgets('no loop count: it keeps playing (the picker)', (t) async {
    await t.pumpWidget(_plain(StickerView(sticker: hi, size: 120)));
    await _frames(t, (3 * hi.loopMs / 17).ceil() + 5);
    final before = StickerView.frames;
    await _frames(t, 20);
    expect(StickerView.frames, greaterThan(before + 10));
  });

  testWidgets('under TickerMode off nothing ticks', (t) async {
    await t.pumpWidget(
      _plain(
        TickerMode(enabled: false, child: StickerView(sticker: hi, size: 120)),
      ),
    );
    final before = StickerView.frames;
    await _frames(t, 30);
    expect(StickerView.frames, before);
    expect(t.binding.hasScheduledFrame, false);

    await t.pumpWidget(
      _plain(
        TickerMode(enabled: true, child: StickerView(sticker: hi, size: 120)),
      ),
    );
    await _frames(t, 10);
    expect(StickerView.frames, greaterThan(before));
  });

  testWidgets('the app lock stops it, and it plays again after', (t) async {
    final lock = _Lock();
    final guard = LockGuard(isLocked: () => lock.locked);
    await t.pumpWidget(
      haloAppShell(
        navigatorKey: GlobalKey<NavigatorState>(),
        lock: (navigator) => LockGate(
          app: navigator,
          lock: lock,
          loaded: () => true,
          locked: () => lock.locked,
          load: () async {},
          leaving: () => lock.set(true),
          returned: () {},
          guard: guard,
          quiet: () => false,
          pad: (_) => ColoredBox(color: HaloColors.ink),
        ),
        home: Scaffold(
          body: Center(child: StickerView(sticker: hi, size: 160)),
        ),
      ),
    );
    await _frames(t, 20);
    final playing = StickerView.frames;
    expect(playing, greaterThan(0));

    lock.set(true);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    final up = StickerView.frames;
    await _frames(t, 40);
    expect(StickerView.frames, up, reason: 'nothing runs under the lock');

    lock.set(false);
    await t.pump();
    await _frames(t, 30);
    expect(StickerView.frames, greaterThan(up + 10));
  });

  testWidgets('a page pushed over it stops it until it comes back', (t) async {
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: Scaffold(
          body: Center(child: StickerView(sticker: hi, size: 160)),
        ),
      ),
    );
    await _frames(t, 10);
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: SizedBox.expand()),
      ),
    );
    await t.pumpAndSettle();
    final covered = StickerView.frames;
    await _frames(t, 30);
    expect(StickerView.frames, covered);
    nav.currentState!.pop();
    await t.pump();
    await _frames(t, 30);
    expect(StickerView.frames, greaterThan(covered));
  });

  testWidgets('scrolled off it stops, and picks up where it was', (t) async {
    final scroll = ScrollController();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: scroll,
            children: [
              SizedBox(height: 120, child: StickerView(sticker: hi, size: 120)),
              const SizedBox(height: 3000),
            ],
          ),
        ),
      ),
    );
    await _frames(t, 30);
    final box = _boxes(t).single;
    expect(box.time, greaterThan(0));

    // out of view, still inside the list's cache: kept, not painted
    scroll.jumpTo(200);
    await t.pump();
    await t.pump(const Duration(milliseconds: 17));
    final parked = StickerView.frames;
    final at = box.time;
    await _frames(t, 40);
    expect(StickerView.frames, parked, reason: 'it stops after one frame');
    expect(box.time, at);
    expect(box.onScreen, false);

    scroll.jumpTo(0);
    await t.pump();
    await t.pump(const Duration(milliseconds: 17));
    await t.pump(const Duration(milliseconds: 17));
    expect(box.onScreen, true);
    // the time it had, not a restart and not the time that passed
    expect((box.time - at).abs(), lessThan(60));
    await _frames(t, 10);
    expect(StickerView.frames, greaterThan(parked));
  });

  testWidgets('a grid of twenty plays six at a time', (t) async {
    final budget = StickerBudget(6);
    final ids = pack.playable;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GridView.count(
            crossAxisCount: 4,
            children: [
              for (var i = 0; i < 20; i++)
                StickerView(
                  sticker: pack.sticker(ids[i % ids.length])!,
                  size: 80,
                  fps: 30,
                  budget: budget,
                  order: i,
                ),
            ],
          ),
        ),
      ),
    );
    await _frames(t, 30);
    expect(budget.playing, 6);
    final moving = _boxes(t).where((b) => b.time >= 0).length;
    expect(moving, 6);
    // the first six in visual order hold the slots
    final order = _boxes(t)
      ..sort((a, b) {
        final pa = a.localToGlobal(Offset.zero),
            pb = b.localToGlobal(Offset.zero);
        return pa.dy != pb.dy ? pa.dy.compareTo(pb.dy) : pa.dx.compareTo(pb.dx);
      });
    expect(order.take(6).every((b) => b.time >= 0), true);
    expect(order.skip(6).every((b) => b.time < 0), true);
  });

  testWidgets('a slot given back goes to the next in line', (t) async {
    final budget = StickerBudget(2);
    final ids = pack.playable;
    Widget grid(int n) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            for (var i = 0; i < n; i++)
              StickerView(
                key: ValueKey(i),
                sticker: pack.sticker(ids[i])!,
                size: 60,
                budget: budget,
                order: i,
              ),
          ],
        ),
      ),
    );
    await t.pumpWidget(grid(4));
    await _frames(t, 10);
    expect(budget.playing, 2);
    // the first two leave: the other two play
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              for (var i = 2; i < 4; i++)
                StickerView(
                  key: ValueKey(i),
                  sticker: pack.sticker(ids[i])!,
                  size: 60,
                  budget: budget,
                  order: i,
                ),
            ],
          ),
        ),
      ),
    );
    await _frames(t, 10);
    expect(budget.playing, 2);
    expect(_boxes(t).every((b) => b.time >= 0), true);
  });

  testWidgets('below the display rate it asks for no frame in between', (
    t,
  ) async {
    await t.pumpWidget(_plain(StickerView(sticker: hi, size: 120, fps: 30)));
    await _frames(t, 4);
    final before = StickerView.frames;
    var waiting = 0;
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(microseconds: 16667));
      if (t.binding.hasScheduledFrame) waiting++;
    }
    expect(StickerView.frames - before, inInclusiveRange(29, 31));
    // between two frames drawn the screen rests
    expect(waiting, 0);
  });

  testWidgets('at the display rate every frame is drawn; at 120 hz half', (
    t,
  ) async {
    await t.pumpWidget(_plain(StickerView(sticker: hi, size: 120)));
    await _frames(t, 4);
    var before = StickerView.frames;
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(microseconds: 16667));
    }
    expect(StickerView.frames - before, inInclusiveRange(59, 60));

    t.view.display.refreshRate = 120;
    addTearDown(t.view.display.resetRefreshRate);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(_plain(StickerView(sticker: hi, size: 120)));
    await t.pump(const Duration(microseconds: 8333));
    await t.pump(const Duration(microseconds: 8333));
    before = StickerView.frames;
    var waiting = 0;
    for (var i = 0; i < 120; i++) {
      await t.pump(const Duration(microseconds: 8333));
      if (t.binding.hasScheduledFrame) waiting++;
    }
    expect(StickerView.frames - before, inInclusiveRange(59, 61));
    expect(waiting, 0);
  });

  testWidgets('muted, its time stands still: it goes on from where it was', (
    t,
  ) async {
    final loop = hi.loopMs;
    Widget view(bool on) => _plain(
      TickerMode(
        enabled: on,
        child: StickerView(sticker: hi, size: 120, loops: 2),
      ),
    );
    await t.pumpWidget(view(true));
    await _frames(t, loop ~/ 2 ~/ 17);
    final box = _boxes(t).single;
    final before = box.time;
    expect(before, greaterThan(0));

    await t.pumpWidget(view(false));
    await t.pump(Duration(milliseconds: 5 * loop));
    await t.pumpWidget(view(true));
    await _frames(t, 2);
    // not five loops on, and not rested for loops nobody saw
    expect((box.time - before).abs(), lessThan(60));

    // half a loop was seen: a loop and a half still to play
    await _frames(t, loop ~/ 17);
    expect(box.time, greaterThanOrEqualTo(0));
    await _frames(t, loop ~/ 17 + 10);
    expect(box.time, -1);
  });

  testWidgets('a page over it: its loops count only time it was seen', (
    t,
  ) async {
    final loop = hi.loopMs;
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: Scaffold(
          body: Center(child: StickerView(sticker: hi, size: 160, loops: 2)),
        ),
      ),
    );
    await _frames(t, loop ~/ 2 ~/ 17);
    // a fading page, as the app's own: the sticker stays painted until the
    // page is up, then it is muted without a frame in between
    nav.currentState!.push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, _, _) => const Scaffold(body: SizedBox.expand()),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
    await _frames(t, 30);
    final box = _boxes(t).single;
    final covered = box.time;
    await t.pump(Duration(milliseconds: 5 * loop));
    nav.currentState!.pop();
    await _frames(t, 4);
    expect(box.time, greaterThanOrEqualTo(0));
    expect((box.time - covered).abs(), lessThan(100));
  });

  testWidgets('under the lock its time stands still too', (t) async {
    final loop = hi.loopMs;
    final lock = _Lock();
    final guard = LockGuard(isLocked: () => lock.locked);
    await t.pumpWidget(
      haloAppShell(
        navigatorKey: GlobalKey<NavigatorState>(),
        lock: (navigator) => LockGate(
          app: navigator,
          lock: lock,
          loaded: () => true,
          locked: () => lock.locked,
          load: () async {},
          leaving: () => lock.set(true),
          returned: () {},
          guard: guard,
          quiet: () => false,
          pad: (_) => ColoredBox(color: HaloColors.ink),
        ),
        home: Scaffold(
          body: Center(child: StickerView(sticker: hi, size: 160, loops: 2)),
        ),
      ),
    );
    await _frames(t, loop ~/ 2 ~/ 17);
    lock.set(true);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    final box = _boxes(t).single;
    final locked = box.time;
    await t.pump(Duration(milliseconds: 5 * loop));
    lock.set(false);
    await t.pump();
    await _frames(t, 4);
    expect(box.time, greaterThanOrEqualTo(0));
    expect((box.time - locked).abs(), lessThan(100));
  });

  // what the app gets when the phone goes to another app or another user.
  // frames can go on behind it, as they do here
  for (final away in [
    [AppLifecycleState.inactive],
    [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ],
  ]) {
    testWidgets('out of front (${away.last.name}) it holds, loops and all', (
      t,
    ) async {
      final loop = hi.loopMs;
      await t.pumpWidget(
        _plain(StickerView(sticker: hi, size: 120, fps: 30, loops: 2)),
      );
      await _frames(t, loop ~/ 2 ~/ 17);
      final box = _boxes(t).single;
      final before = box.time;
      expect(before, greaterThan(0));

      for (final s in away) {
        t.binding.handleAppLifecycleStateChanged(s);
      }
      await t.pump();
      final drawn = StickerView.frames;
      await _awayFrames(t, 5 * loop ~/ 17);
      expect(StickerView.frames, drawn);
      expect(box.time, before);
      // no ticker waiting, and no timer that would start one
      expect(t.binding.transientCallbackCount, 0);

      for (final s in away.reversed.skip(1)) {
        t.binding.handleAppLifecycleStateChanged(s);
      }
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _frames(t, 3);
      // on from where it was, its loop and a half still to play
      expect((box.time - before).abs(), lessThan(80));
      await _frames(t, loop ~/ 17);
      expect(box.time, greaterThanOrEqualTo(0));
      await _frames(t, loop ~/ 17 + 10);
      expect(box.time, -1);
    });
  }

  testWidgets('a view told not to play draws without a ticker', (t) async {
    final s = pack.sticker(3)!;
    await t.pumpWidget(_plain(StickerView(sticker: s, size: 120, play: false)));
    final before = StickerView.frames;
    await _frames(t, 10);
    expect(StickerView.frames, before);
    expect(t.binding.hasScheduledFrame, false);
    expect(kStickerBox, 512);
  });
}
