import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/widgets/row_anchor.dart';

// rows of uneven height, so every estimate a lazy list makes is wrong
double _h(int i) => 40.0 + (i * 37 % 11) * 22;

class _Host extends StatelessWidget {
  final ScrollController ctrl;
  final RowAnchors anchors;
  final bool reversed;
  final int n;
  const _Host(this.ctrl, this.anchors, this.reversed, this.n);
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: ListView.builder(
      controller: ctrl,
      reverse: reversed,
      itemCount: n,
      itemBuilder: (_, i) {
        final ix = reversed ? n - 1 - i : i;
        return RowAnchor(
          key: ValueKey('k$ix'),
          anchors: anchors,
          id: 'm$ix',
          child: SizedBox(height: _h(ix), child: Text('m$ix')),
        );
      },
    ),
  );
}

Future<bool?> _land(
  WidgetTester t,
  ScrollController c,
  RowAnchors a,
  String id,
  bool reversed,
  int n,
) async {
  bool? result;
  landOnRow(
    ctrl: c,
    anchors: a,
    id: id,
    alive: () => true,
    indexOf: (x) => int.tryParse(x.substring(1)),
    reversed: reversed,
    rough: () {
      final p = c.position;
      final ix = int.parse(id.substring(1));
      final frac = reversed ? (n - 1 - ix) / n : ix / n;
      return frac * p.maxScrollExtent;
    },
    done: (ok) => result = ok,
  );
  for (var i = 0; i < 120 && result == null; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
  return result;
}

double _centreOf(WidgetTester t, String id) => t.getCenter(find.text(id)).dy;

void main() {
  for (final reversed in [true, false]) {
    testWidgets('lands on a far row, twice, in the same place '
        '(reversed: $reversed)', (t) async {
      const n = 600;
      final c = ScrollController();
      final a = RowAnchors();
      await t.pumpWidget(_Host(c, a, reversed, n));
      final mid = t.getSize(find.byType(ListView)).height / 2;

      expect(await _land(t, c, a, 'm40', reversed, n), true);
      final first = _centreOf(t, 'm40');
      expect((first - mid).abs(), lessThan(3));

      // the second tap, from where the first left the view
      expect(await _land(t, c, a, 'm40', reversed, n), true);
      expect((_centreOf(t, 'm40') - first).abs(), lessThan(1));

      // and from the far end
      c.jumpTo(reversed ? 0 : c.position.maxScrollExtent);
      await t.pump();
      expect(await _land(t, c, a, 'm40', reversed, n), true);
      expect((_centreOf(t, 'm40') - first).abs(), lessThan(3));
    });
  }

  testWidgets('a row that is not in the list ends the jump', (t) async {
    final c = ScrollController();
    final a = RowAnchors();
    await t.pumpWidget(_Host(c, a, true, 50));
    bool? result;
    landOnRow(
      ctrl: c,
      anchors: a,
      id: 'gone',
      alive: () => true,
      indexOf: (x) => x == 'gone' ? null : int.tryParse(x.substring(1)),
      reversed: true,
      rough: () => 0,
      done: (ok) => result = ok,
    );
    await t.pump();
    await t.pump();
    expect(result, false);
  });
}
