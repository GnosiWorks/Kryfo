// SPDX-License-Identifier: GPL-3.0-or-later
// the onboarding fades out over home once instead of a cut. home is made
// once, under it, and stays; the onboarding keeps its state on the way out.
// with less movement it is a plain cut
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/fade_over.dart';

import 'source_body.dart';

var _homeMade = 0;
var _homeGone = 0;
var _leavingMade = 0;
var _taps = 0;

class _Home extends StatefulWidget {
  const _Home();
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  @override
  void initState() {
    super.initState();
    _homeMade++;
  }

  @override
  void dispose() {
    _homeGone++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(onPressed: () => _taps++, child: const Text('home')),
  );
}

class _Leaving extends StatefulWidget {
  const _Leaving({super.key});
  @override
  State<_Leaving> createState() => _LeavingState();
}

class _LeavingState extends State<_Leaving> {
  @override
  void initState() {
    super.initState();
    _leavingMade++;
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Colors.black,
    child: Center(child: Text('setup')),
  );
}

// the gate's shape: the onboarding in a switcher, then home with it fading
class _Gate extends StatefulWidget {
  final ValueNotifier<int> state;
  const _Gate(this.state);
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  final _key = GlobalKey();
  Widget? _last;
  Widget? _leaving;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: widget.state,
    builder: (_, v, _) {
      if (v == 0) {
        final before = _Leaving(key: _key);
        _last = before;
        _leaving = null;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: before,
        );
      }
      if (_last?.key == _key) _leaving = _last;
      _last = null;
      return FadeOver(leaving: _leaving, child: const _Home());
    },
  );
}

Widget _app(ValueNotifier<int> state, {bool still = false}) => MaterialApp(
  builder: (ctx, child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: child!,
  ),
  home: _Gate(state),
);

double _overOpacity(WidgetTester t) => t
    .widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(FadeOver),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  setUp(() {
    _homeMade = 0;
    _homeGone = 0;
    _leavingMade = 0;
    _taps = 0;
  });

  testWidgets('the onboarding fades out over home, once', (t) async {
    final state = ValueNotifier(0);
    await t.pumpWidget(_app(state));
    expect(_leavingMade, 1);
    expect(_homeMade, 0);

    state.value = 1;
    await t.pump();
    // home is there under it from the first frame, the onboarding as it was
    expect(find.text('setup'), findsOneWidget);
    expect(find.text('home'), findsOneWidget);
    expect(_leavingMade, 1);
    expect(_homeMade, 1);
    expect(_overOpacity(t), 1);

    await t.pump(FadeOver.duration ~/ 2);
    final mid = _overOpacity(t);
    expect(mid, inExclusiveRange(0, 1));
    // a tap goes to home, not to the screen on its way out
    await t.tap(find.text('home'));
    expect(_taps, 1);

    await t.pump(FadeOver.duration);
    expect(find.text('setup'), findsNothing);
    expect(find.text('home'), findsOneWidget);
    // home was made once and is still the same one
    expect(_homeMade, 1);
    expect(_homeGone, 0);

    // later rebuilds play nothing again
    await t.pumpAndSettle();
    state.value = 2;
    await t.pump();
    expect(find.text('setup'), findsNothing);
    expect(t.hasRunningAnimations, isFalse);
    expect(_homeMade, 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('with less movement it is a cut', (t) async {
    final state = ValueNotifier(0);
    await t.pumpWidget(_app(state, still: true));
    state.value = 1;
    await t.pump();
    expect(find.text('setup'), findsNothing);
    expect(find.text('home'), findsOneWidget);
    await t.pump(FadeOver.duration);
    expect(find.text('setup'), findsNothing);
    expect(_homeMade, 1);
    expect(_homeGone, 0);
    await t.pumpWidget(const SizedBox());
  });

  test('the onboarding gate hands over to home through it', () {
    final src = sourceOf('lib/app/gates.dart');
    final from = src.indexOf('class _OnboardingGateState');
    final gate = src.substring(from, src.indexOf('\nclass ', from + 1));
    expect(gate, contains('key: _onboardingKey,'));
    expect(
      gate,
      contains('if (_last?.key == _onboardingKey) _leaving = _last;'),
    );
    expect(
      gate,
      contains('return FadeOver(leaving: _leaving, child: widget.child);'),
    );
    expect(gate, isNot(contains('return widget.child;')));
  });
}
