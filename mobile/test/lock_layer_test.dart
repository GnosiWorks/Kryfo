// SPDX-License-Identifier: GPL-3.0-or-later
// the app lock as a layer (lock_layer.dart), on the app's own MaterialApp
// (app_shell.dart): nothing the app draws, however it draws it, shows, takes
// a touch, reaches the screen reader or takes back while the lock is up.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/app_shell.dart';
import 'package:kryfo/lock_guard.dart';
import 'package:kryfo/lock_layer.dart';
import 'package:kryfo/theme.dart';

class _Lock extends ChangeNotifier {
  bool loaded = true;
  bool locked = false;
  void set({bool? loaded, bool? locked}) {
    this.loaded = loaded ?? this.loaded;
    this.locked = locked ?? this.locked;
    notifyListeners();
  }
}

// a stand-in pin pad: still and without glyphs, so its pixels are the same
// from pump to pump and in any app it is drawn in
class _Pad extends StatefulWidget {
  const _Pad(this.app);
  final _App app;
  @override
  State<_Pad> createState() => _PadState();
}

class _PadState extends State<_Pad> {
  @override
  void initState() {
    super.initState();
    widget.app.pads++;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HaloColors.ink,
    body: Center(
      child: GestureDetector(
        onTap: () => widget.app.padTaps++,
        child: Semantics(
          label: 'pin pad',
          container: true,
          child: const SizedBox(
            width: 300,
            height: 300,
            child: ColoredBox(color: Color(0xFF334455)),
          ),
        ),
      ),
    ),
  );
}

class _App {
  _App(this.tester);
  final WidgetTester tester;
  final lock = _Lock();
  late final guard = LockGuard(isLocked: () => !lock.loaded || lock.locked);
  var nav = GlobalKey<NavigatorState>();
  final shot = GlobalKey();
  int taps = 0;
  int pads = 0;
  int padTaps = 0;
  int keys = 0;
  bool quiet = false;
  // the app's own lock-up: a vault session shuts here
  int ups = 0;
  VoidCallback? onUp;
  final scroll = ScrollController();
  final homeFocus = FocusNode();
  late BuildContext home;

  NavigatorState get n => nav.currentState!;

  Widget tree() => RepaintBoundary(
    key: shot,
    child: haloAppShell(
      navigatorKey: nav,
      lock: (navigator) => LockGate(
        app: navigator,
        lock: lock,
        loaded: () => lock.loaded,
        locked: () => lock.locked,
        load: () async {},
        leaving: () => lock.set(locked: true),
        returned: () {},
        guard: guard,
        quiet: () => quiet,
        pad: (_) => _Pad(this),
        lockingUp: () {
          ups++;
          onUp?.call();
        },
      ),
      home: Builder(
        builder: (c) {
          home = c;
          return Scaffold(
            body: Focus(
              focusNode: homeFocus,
              onKeyEvent: (_, e) {
                if (e is KeyDownEvent) keys++;
                return KeyEventResult.handled;
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: ListView(
                  controller: scroll,
                  children: [
                    const Hero(
                      tag: 'avatar',
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: ColoredBox(color: Color(0xFFFF0000)),
                      ),
                    ),
                    const Text('secret home'),
                    const SizedBox(height: 3000),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Future<void> pump() async {
    await tester.pumpWidget(tree());
    await tester.pump();
  }

  // a session switch: the app gets a new root navigator
  Future<void> swapNavigator() async {
    nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(tree());
    await tester.pump();
  }

  Future<void> lockUp() async {
    lock.set(locked: true);
    await tester.pump();
  }

  Future<void> unlock() async {
    lock.set(locked: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<List<int>> capture() async {
    final boundary =
        shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    late List<int> bytes;
    await tester.runAsync(() async {
      final img = await boundary.toImage();
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      bytes = data!.buffer.asUint8List().toList();
    });
    return bytes;
  }

  // every label the screen reader would find
  Set<String> labels() {
    final out = <String>{};
    void walk(SemanticsNode n) {
      if (n.label.isNotEmpty) out.add(n.label);
      n.visitChildren((c) {
        walk(c);
        return true;
      });
    }

    final root = tester.binding.renderViews.first.debugSemantics;
    if (root != null) walk(root);
    return out;
  }
}

Widget _page(String text) => Scaffold(
  body: Column(
    children: [
      const Hero(
        tag: 'avatar',
        child: SizedBox(
          width: 200,
          height: 200,
          child: ColoredBox(color: Color(0xFF00FF00)),
        ),
      ),
      Text(text),
    ],
  ),
);

// android's word that the app was left
Future<void> _away(WidgetTester tester) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      lockWindowChannel.name,
      lockWindowChannel.codec.encodeMessage('away'),
      (_) {},
    );

void main() {
  setUp(() {
    haloWhenOpen = null;
  });

  testWidgets('the locked screen shows only the pad', (tester) async {
    final a = _App(tester);
    // the pad drawn by itself, in a bare app: what the locked screen must be
    await tester.pumpWidget(
      RepaintBoundary(
        key: a.shot,
        child: MaterialApp(debugShowCheckedModeBanner: false, home: _Pad(a)),
      ),
    );
    await tester.pump();
    final lockAlone = await a.capture();
    await tester.pumpWidget(const SizedBox());
    await a.pump();
    a.n.push(MaterialPageRoute<void>(builder: (_) => _page('a chat')));
    await tester.pumpAndSettle();
    await a.lockUp();
    // nothing of the app's shell or screens on it, only the pad
    expect(await a.capture(), lockAlone, reason: 'the lock just up');

    Future<void> same(String what) async {
      for (final d in const [
        Duration.zero,
        Duration(milliseconds: 16),
        Duration(milliseconds: 150),
        Duration(milliseconds: 400),
        Duration(seconds: 2),
      ]) {
        await tester.pump(d);
        expect(await a.capture(), lockAlone, reason: '$what, after $d');
      }
    }

    // a screen pushed, with a hero flight
    a.n.push(MaterialPageRoute<void>(builder: (_) => _page('pushed')));
    await same('a pushed screen');
    // a screen popped from under the lock
    a.n.pop();
    await same('a pop');
    // something inserted above every route: a message menu, a recorder bar
    a.n.overlay!.insert(
      OverlayEntry(
        builder: (_) =>
            const Positioned.fill(child: ColoredBox(color: Color(0xFFFF00FF))),
      ),
    );
    await same('a root overlay entry');
    // a dialog and a sheet
    showDialog<void>(
      context: a.home,
      builder: (_) => const AlertDialog(title: Text('a dialog')),
    );
    await same('a dialog');
    showModalBottomSheet<void>(
      context: a.home,
      builder: (_) => const SizedBox(height: 300, child: Text('a sheet')),
    );
    await same('a sheet');
    // a snackbar through the app's messenger, and a toast
    haloMessengerKey.currentState!.showSnackBar(
      const SnackBar(content: Text('a snackbar')),
    );
    await same('a snackbar');
    showHaloToast(a.home, 'a toast');
    await same('a toast');
    // and a whole new root navigator, as a session switch makes
    await a.swapNavigator();
    await same('a session switch');
  });

  testWidgets('input never reaches the app while locked', (tester) async {
    final a = _App(tester);
    await a.pump();
    // the app takes all three while open
    a.homeFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(a.keys, 1);
    await a.lockUp();
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    for (var x = 5.0; x < size.width; x += size.width / 7) {
      for (var y = 5.0; y < size.height; y += size.height / 11) {
        await tester.tapAt(Offset(x, y));
        await tester.dragFrom(Offset(x, y), const Offset(0, -80));
      }
    }
    for (final k in [
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.tab,
    ]) {
      await tester.sendKeyEvent(k);
    }
    await tester.pump();
    expect(a.taps, 0);
    expect(a.keys, 1);
    expect(a.scroll.offset, 0);
    // the pad itself does take them
    expect(a.padTaps, greaterThan(0));
    await a.unlock();
    await tester.tapAt(Offset(size.width / 2, size.height / 2));
    expect(a.taps, 1);
    await tester.dragFrom(
      Offset(size.width / 2, size.height / 2),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(a.scroll.offset, greaterThan(0));
  });

  testWidgets('a held finger lets go on lock', (tester) async {
    final a = _App(tester);
    await a.pump();
    final g = await tester.startGesture(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 50));
    await a.lockUp();
    await g.up();
    await tester.pump();
    expect(a.taps, 0);
  });

  testWidgets('the screen reader sees only the lock', (tester) async {
    final handle = tester.ensureSemantics();
    final a = _App(tester);
    await a.pump();
    a.n.push(MaterialPageRoute<void>(builder: (_) => _page('a chat')));
    await tester.pumpAndSettle();
    expect(a.labels(), contains('a chat'));
    await a.lockUp();
    await tester.pump();
    final seen = a.labels();
    expect(seen, contains('pin pad'));
    for (final l in ['a chat', 'secret home']) {
      expect(seen, isNot(contains(l)));
    }
    await a.unlock();
    expect(a.labels(), contains('a chat'));
    expect(a.labels(), isNot(contains('pin pad')));
    handle.dispose();
  });

  testWidgets('back while locked takes nothing from the app', (tester) async {
    final told = <bool>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
          told.add(call.arguments as bool);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.addObserver(lockBack);
    addTearDown(() => tester.binding.removeObserver(lockBack));
    final a = _App(tester);
    await a.pump();
    a.n.push(MaterialPageRoute<void>(builder: (_) => _page('a chat')));
    await tester.pumpAndSettle();
    await a.lockUp();
    // android is told back is dart's, and dart keeps it
    expect(told.last, isTrue);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    await a.unlock();
    await tester.pumpAndSettle();
    expect(find.text('a chat'), findsOneWidget);
    // after the pin android hears the navigator again: it can go back
    expect(told.last, isTrue);
    a.n.pop();
    await tester.pumpAndSettle();
    // at home it cannot, and back goes to android
    expect(told.last, isFalse);
  });

  testWidgets('locking mid-fade brings a fresh pad', (tester) async {
    final a = _App(tester);
    await a.pump();
    await a.lockUp();
    final lockAlone = await a.capture();
    expect(a.pads, 1);
    a.lock.set(locked: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(_Pad), findsOneWidget);
    await a.lockUp();
    expect(a.pads, 2);
    expect(await a.capture(), lockAlone);
  });

  testWidgets('reduced motion lifts the lock in one frame', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final a = _App(tester);
    await a.pump();
    await a.lockUp();
    a.lock.set(locked: false);
    await tester.pump();
    expect(find.byType(_Pad), findsNothing);
    expect(find.text('secret home'), findsOneWidget);
  });

  testWidgets('only ink shows before the lock is read', (tester) async {
    final a = _App(tester);
    a.lock.loaded = false;
    a.lock.locked = true;
    await a.pump();
    expect(find.byType(_Pad), findsNothing);
    expect(find.text('secret home'), findsNothing);
    a.lock.set(loaded: true);
    await tester.pump();
    expect(find.byType(_Pad), findsOneWidget);
    expect(a.pads, 1);
  });

  testWidgets('a toast from before the lock is dropped', (tester) async {
    final a = _App(tester);
    await a.pump();
    showHaloToast(a.home, 'before');
    await tester.pump();
    await a.lockUp();
    await a.unlock();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('before'), findsNothing);
  });

  testWidgets('a toast under the lock waits for unlock', (tester) async {
    final a = _App(tester);
    await a.pump();
    await a.lockUp();
    haloWhenOpen = (act) => a.guard.afterUnlock(act);
    showHaloToast(a.home, 'during');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('during', skipOffstage: false), findsNothing);
    await a.unlock();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('during'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('media outside the tree stops on lock', (tester) async {
    final a = _App(tester);
    await a.pump();
    var playing = true;
    a.guard.closeOnLock(() => playing = false);
    await a.lockUp();
    expect(playing, isFalse);
    // and what only finishes starting under it stops at once
    var recording = true;
    a.guard.closeOnLock(() => recording = false);
    await tester.pump();
    expect(recording, isFalse);
  });

  testWidgets('leaving locks at once and keeps the pad', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final a = _App(tester);
    await a.pump();
    expect(find.byType(_Pad), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    // a pulled-down shade or a permission prompt is not leaving
    expect(a.lock.locked, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(a.lock.locked, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(_Pad), findsOneWidget);
    expect(a.pads, 1);
    expect(find.text('secret home'), findsNothing);
  });

  testWidgets('the window leaving the screen locks', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final a = _App(tester);
    await a.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await _away(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(a.lock.locked, isTrue);
    expect(find.byType(_Pad), findsOneWidget);
    expect(find.text('secret home'), findsNothing);
  });

  test('android tells the lock when the window leaves', () {
    final k = File(
      'android/app/src/main/kotlin/app/kryfo/MainActivity.kt',
    ).readAsStringSync();
    expect(k, contains('"${lockWindowChannel.name}"'));
    expect(k, contains('override fun onWindowVisibilityChanged'));
    // the listener form needs android 14, the app runs from 7
    expect(k, isNot(contains('OnWindowVisibilityChangeListener')));
    expect(k, contains('override fun onUserLeaveHint'));
  });

  testWidgets('a decoy unlock drops what waited', (tester) async {
    final a = _App(tester);
    await a.pump();
    await a.lockUp();
    var opened = false;
    await a.guard.afterUnlock(() async => opened = true, key: 'chat:x');
    a.quiet = true;
    await a.unlock();
    expect(opened, isFalse);
    // while an everyday unlock lets it happen
    a.quiet = false;
    await a.lockUp();
    await a.guard.afterUnlock(() async => opened = true, key: 'chat:y');
    await a.unlock();
    expect(opened, isTrue);
  });

  testWidgets('a vault unlock lets what waited happen', (tester) async {
    final a = _App(tester);
    await a.pump();
    await a.lockUp();
    var opened = false;
    await a.guard.afterUnlock(() async => opened = true, key: 'chat:h');
    // the vault session is the everyday identity's: not quiet
    a.quiet = false;
    await a.unlock();
    expect(opened, isTrue);
  });

  testWidgets('the lock going up tells the app once', (tester) async {
    final a = _App(tester);
    await a.pump();
    // shutting the vault tells the lock about it while it goes up
    a.onUp = () => a.lock.set();
    await a.lockUp();
    expect(a.ups, 1);
    expect(a.pads, 1);
    expect(find.byType(_Pad), findsOneWidget);
    await a.unlock();
    expect(a.ups, 1);
    a.onUp = null;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(a.ups, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(_Pad), findsOneWidget);
  });

  testWidgets('left while the pin was checked, it locks again', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final a = _App(tester);
    await a.pump();
    await a.lockUp();
    expect(a.ups, 1);
    var opened = false;
    await a.guard.afterUnlock(() async => opened = true, key: 'chat:h');
    // the app goes while the check runs: already locked, nothing changes
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    // then the check lets it in, with nobody in front
    a.lock.set(locked: false);
    await tester.pump();
    expect(a.lock.locked, isTrue);
    expect(a.ups, 2, reason: 'what the unlock opened is shut again');
    expect(opened, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(_Pad), findsOneWidget);
    expect(find.text('secret home'), findsNothing);
    // back in front, the next unlock is an unlock
    await a.unlock();
    expect(opened, isTrue);
    expect(find.text('secret home'), findsOneWidget);
  });

  testWidgets('left while the pin was checked, android said so', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final a = _App(tester);
    await a.pump();
    await a.lockUp();
    var opened = false;
    await a.guard.afterUnlock(() async => opened = true, key: 'chat:w');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await _away(tester);
    a.lock.set(locked: false);
    await tester.pump();
    expect(a.lock.locked, isTrue);
    expect(opened, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(_Pad), findsOneWidget);
    await a.unlock();
    expect(opened, isTrue);
    expect(find.text('secret home'), findsOneWidget);
  });

  testWidgets('a session switch keeps the pad, drops screens', (tester) async {
    final a = _App(tester);
    await a.pump();
    a.n.push(MaterialPageRoute<void>(builder: (_) => _page('a chat')));
    await tester.pumpAndSettle();
    await a.lockUp();
    expect(a.pads, 1);
    await a.swapNavigator();
    await tester.pumpAndSettle();
    expect(a.pads, 1, reason: 'the pad keeps what was typed');
    expect(find.byType(_Pad), findsOneWidget);
    await a.unlock();
    await tester.pumpAndSettle();
    expect(find.text('a chat', skipOffstage: false), findsNothing);
    expect(find.text('secret home'), findsOneWidget);
    a.n.push(MaterialPageRoute<void>(builder: (_) => _page('after')));
    await tester.pumpAndSettle();
    expect(find.text('after'), findsOneWidget);
    a.n.pop();
    await tester.pumpAndSettle();
    expect(find.text('secret home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
