// SPDX-License-Identifier: GPL-3.0-or-later
// android's back swipe on a house route: the page follows the finger and
// shows the one below, letting go pops it, cancelling springs it back with
// its state kept. while the lock is up the swipe takes nothing and draws
// nothing below; a route that will not pop and reduced motion get no preview
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/lock_layer.dart' show lockBack;
import 'package:kryfo/widgets/back_preview.dart';
import 'package:kryfo/widgets/motion.dart' show haloRoute;

Future<void> _send(WidgetTester t, String method, [Object? args]) async {
  final msg = SystemChannels.backGesture.codec.encodeMethodCall(
    MethodCall(method, args),
  );
  await t.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.backGesture.name,
    msg,
    (_) {},
  );
}

Map<String, Object?> _event(double progress, {bool left = true}) => {
  'touchOffset': <double>[left ? 10 : 390, 300],
  'progress': progress,
  'swipeEdge': left ? 0 : 1,
};

Future<void> _start(WidgetTester t, {bool left = true}) =>
    _send(t, 'startBackGesture', _event(0, left: left));
Future<void> _move(WidgetTester t, double p, {bool left = true}) =>
    _send(t, 'updateBackGestureProgress', _event(p, left: left));

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;
  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => setState(() => n++), child: Text('count $n'));
}

final _nav = GlobalKey<NavigatorState>();

Widget _app({bool still = false}) => MaterialApp(
  navigatorKey: _nav,
  builder: (ctx, c) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: c!,
  ),
  home: const Scaffold(body: Center(child: Text('below'))),
);

Future<void> _open(WidgetTester t, Widget page) async {
  _nav.currentState!.push(haloRoute<void>(page));
  await t.pumpAndSettle();
}

// how big the page is drawn against the screen
double _scale(WidgetTester t) {
  final page = t.getRect(
    find.ancestor(of: find.byType(_Counter), matching: find.byType(Scaffold)),
  );
  return page.width / (t.view.physicalSize.width / t.view.devicePixelRatio);
}

const _page = Scaffold(body: Center(child: _Counter()));

void main() {
  setUp(() => lockBack.locked = false);
  tearDown(() => lockBack.locked = true);

  testWidgets('the page follows the swipe, the one below shows, letting go '
      'pops it', (t) async {
    await t.pumpWidget(_app());
    await _open(t, _page);
    expect(find.text('below'), findsNothing);
    await _start(t);
    await _move(t, 0.5);
    await t.pump();
    expect(_scale(t), lessThan(1));
    expect(_scale(t), greaterThanOrEqualTo(kBackScale));
    // the screen below is drawn while the swipe is held
    expect(find.text('below'), findsOneWidget);
    // from the left edge it slides right
    final at = t.getTopLeft(find.byType(_Counter));
    await _move(t, 0.9);
    await t.pump();
    expect(t.getTopLeft(find.byType(_Counter)).dx, greaterThan(at.dx));
    await _send(t, 'commitBackGesture');
    await t.pumpAndSettle();
    expect(find.byType(_Counter), findsNothing);
    expect(find.text('below'), findsOneWidget);
  });

  testWidgets('cancelled, it springs back with its state kept', (t) async {
    await t.pumpWidget(_app());
    await _open(t, _page);
    await t.tap(find.text('count 0'));
    await t.pump();
    await _start(t, left: false);
    await _move(t, 0.6, left: false);
    await t.pump();
    expect(_scale(t), lessThan(1));
    await _send(t, 'cancelBackGesture');
    await t.pumpAndSettle();
    expect(_scale(t), 1);
    expect(find.text('count 1'), findsOneWidget);
    expect(find.text('below'), findsNothing);
  });

  testWidgets('while locked the swipe takes nothing and shows nothing '
      'below', (t) async {
    t.binding.addObserver(lockBack);
    addTearDown(() => t.binding.removeObserver(lockBack));
    await t.pumpWidget(_app());
    await _open(t, _page);
    lockBack.locked = true;
    await _start(t);
    await _move(t, 0.7);
    await t.pump();
    expect(_scale(t), 1);
    expect(find.text('below'), findsNothing);
    await _send(t, 'commitBackGesture');
    await t.pumpAndSettle();
    expect(find.byType(_Counter), findsOneWidget);
  });

  testWidgets('a route that will not pop gets no preview', (t) async {
    await t.pumpWidget(_app());
    await _open(t, const PopScope(canPop: false, child: _page));
    await _start(t);
    await _move(t, 0.7);
    await t.pump();
    expect(_scale(t), 1);
    expect(find.text('below'), findsNothing);
    await _send(t, 'commitBackGesture');
    await t.pumpAndSettle();
    expect(find.byType(_Counter), findsOneWidget);
  });

  testWidgets('reduced motion: no preview, back still goes back', (t) async {
    await t.pumpWidget(_app(still: true));
    await _open(t, _page);
    await _start(t);
    await _move(t, 0.7);
    await t.pump();
    expect(_scale(t), 1);
    expect(find.text('below'), findsNothing);
    await _send(t, 'commitBackGesture');
    await t.pumpAndSettle();
    expect(find.byType(_Counter), findsNothing);
  });

  testWidgets('a push and a pop keep the rise and fade', (t) async {
    await t.pumpWidget(_app());
    _nav.currentState!.push(haloRoute<void>(_page));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    final o = t.widget<Opacity>(
      find
          .ancestor(of: find.byType(_Counter), matching: find.byType(Opacity))
          .first,
    );
    expect(o.opacity, greaterThan(0));
    expect(o.opacity, lessThan(1));
    await t.pumpAndSettle();
    expect(_scale(t), 1);
  });
}
