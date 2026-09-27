// SPDX-License-Identifier: GPL-3.0-or-later
// the chat list's rows: a new one grows in, one that goes folds where it was
// and is let go, one that moves glides, a status dot rests after a few
// breaths. all of it comes to rest and none of it moves when the phone asks
// for no movement
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/burn_fade.dart';
import 'package:kryfo/widgets/motion.dart';
import 'package:kryfo/widgets/row_motion.dart';
import 'package:kryfo/widgets/shift_in_place.dart';

Widget host(Widget child, {bool still = false}) => MaterialApp(
  builder: (ctx, c) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
    child: c!,
  ),
  home: Scaffold(body: child),
);

Future<void> settles(WidgetTester t) async {
  await t.pumpAndSettle();
  expect(t.binding.transientCallbackCount, 0);
}

// a list the way home draws it: each row glides, folds and grows
class _List extends StatefulWidget {
  final List<String> rows;
  final bool quiet;
  const _List(this.rows, {this.quiet = false});
  @override
  State<_List> createState() => _ListState();
}

class _ListState extends State<_List> {
  late final RowSet<String> _set = RowSet(
    keyOf: (s) => s,
    onGone: () => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _set.start(widget.rows);
  }

  @override
  void didUpdateWidget(_List old) {
    super.didUpdateWidget(old);
    _set.update(widget.rows, quiet: widget.quiet);
  }

  @override
  void dispose() {
    _set.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _set.built());
    return ListView(
      children: [
        for (final (i, r) in _set.rows.indexed)
          ShiftInPlace(
            key: ValueKey(r),
            index: i,
            child: FadeFold(
              leaving: _set.leaving(r),
              child: GrowIn(
                active: _set.fresh(r),
                child: SizedBox(height: 60, child: Text(r)),
              ),
            ),
          ),
      ],
    );
  }
}

double _height(WidgetTester t, String row) =>
    t.getSize(find.byKey(ValueKey(row))).height;

void main() {
  group('row set', () {
    test('keeps a row that went where it was until it has folded', () {
      final gone = <int>[];
      final set = RowSet<String>(keyOf: (s) => s, onGone: () => gone.add(1));
      set.start(['a', 'b', 'c']);
      set.update(['a', 'c', 'd']);
      expect(set.rows, ['a', 'b', 'c', 'd']);
      expect(set.leaving('b'), isTrue);
      expect(set.fresh('d'), isTrue);
      expect(set.fresh('a'), isFalse);
      set.built();
      expect(set.fresh('d'), isFalse);
      // it came back before its fold ended: it stays
      set.update(['a', 'b', 'c', 'd']);
      expect(set.leaving('b'), isFalse);
      expect(set.fresh('b'), isFalse);
      set.dispose();
      expect(gone, isEmpty);
    });

    test('under the lock changes just are', () {
      final set = RowSet<String>(keyOf: (s) => s, onGone: () {});
      set.start(['a', 'b']);
      set.update(['b', 'c'], quiet: true);
      expect(set.rows, ['b', 'c']);
      expect(set.fresh('c'), isFalse);
      expect(set.leaving('a'), isFalse);
      set.dispose();
    });
  });

  group('the list', () {
    testWidgets('a new row grows in and pushes the rest down', (t) async {
      await t.pumpWidget(host(const _List(['a', 'b'])));
      await t.pumpWidget(host(const _List(['n', 'a', 'b'])));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      final h = _height(t, 'n');
      expect(h, greaterThan(0));
      expect(h, lessThan(60));
      await settles(t);
      expect(_height(t, 'n'), 60);
    });

    testWidgets('a row that goes folds away, then is let go', (t) async {
      await t.pumpWidget(host(const _List(['a', 'b', 'c'])));
      await t.pumpWidget(host(const _List(['a', 'c'])));
      await t.pump(const Duration(milliseconds: 120));
      expect(find.text('b'), findsOneWidget);
      final h = _height(t, 'b');
      expect(h, lessThan(60));
      await settles(t);
      await t.pump(FadeFold.gone);
      await settles(t);
      expect(find.text('b'), findsNothing);
    });

    testWidgets('nothing grows or folds when motion is reduced', (t) async {
      await t.pumpWidget(host(const _List(['a', 'b']), still: true));
      await t.pumpWidget(host(const _List(['n', 'a']), still: true));
      await t.pump();
      await t.pump(const Duration(milliseconds: 40));
      expect(_height(t, 'n'), 60);
      // the one going only fades, keeping its height
      expect(_height(t, 'b'), 60);
      await settles(t);
      await t.pump(FadeFold.gone);
      await settles(t);
    });

    testWidgets('a row that moves is simply there when motion is reduced', (
      t,
    ) async {
      await t.pumpWidget(host(const _List(['a', 'b', 'c']), still: true));
      await t.pump();
      await t.pumpWidget(host(const _List(['c', 'a', 'b']), still: true));
      await t.pump();
      await t.pump(const Duration(milliseconds: 16));
      final tr = t.widget<Transform>(
        find
            .ancestor(of: find.text('c'), matching: find.byType(Transform))
            .first,
      );
      expect(tr.transform.getTranslation().y, 0);
      await settles(t);
    });

    testWidgets('under the lock rows come and go as they are', (t) async {
      await t.pumpWidget(host(const _List(['a', 'b'], quiet: true)));
      await t.pumpWidget(host(const _List(['n', 'a'], quiet: true)));
      await t.pump();
      expect(_height(t, 'n'), 60);
      expect(find.text('b'), findsNothing);
      await settles(t);
    });

    testWidgets('an unchanged list asks for no frames', (t) async {
      await t.pumpWidget(host(const _List(['a', 'b'])));
      await t.pumpWidget(host(const _List(['a', 'b'])));
      await t.pump();
      expect(t.binding.transientCallbackCount, 0);
    });
  });

  group('breath dot', () {
    Color dot(WidgetTester t) {
      final box = t.widget<Container>(
        find.descendant(
          of: find.byType(BreathDot),
          matching: find.byType(Container),
        ),
      );
      return (box.decoration! as BoxDecoration).color!;
    }

    testWidgets('given breaths, it rests full once they are done', (t) async {
      await t.pumpWidget(
        host(const BreathDot(color: Colors.amber, size: 7, breaths: 3)),
      );
      await t.pump(const Duration(seconds: 1));
      expect(t.binding.transientCallbackCount, greaterThan(0));
      await t.pump(const Duration(seconds: 7));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.binding.transientCallbackCount, 0);
      expect(dot(t).a, 1);
    });

    testWidgets('without, it breathes on as before', (t) async {
      await t.pumpWidget(host(const BreathDot(color: Colors.amber)));
      await t.pump(const Duration(seconds: 12));
      expect(t.binding.transientCallbackCount, greaterThan(0));
      await t.pumpWidget(host(const SizedBox()));
    });
  });
}
