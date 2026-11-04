// SPDX-License-Identifier: GPL-3.0-or-later
// a pairing in the decoy looks and acts as the everyday one does, on the
// decoy's own lane: its share shows a fresh eight digit code with its count
// and waits, its join looks at the box and says what a code with nothing
// there says, at the everyday times. no invite is made, nothing is put up
// or answered: the only engine call is the read-only look
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show HaloEngine, pairHooks, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/pair_flow.dart';
import 'package:kryfo/session.dart';

import 'arrival_fakes.dart';

class _Engine implements HaloEngine {
  final looked = <String>[];
  final other = <String>[];
  String says = 'look';
  @override
  Future<String> decoyPairLook(String box) async {
    looked.add(box);
    await Future<void>.delayed(const Duration(seconds: 2));
    return says;
  }

  @override
  dynamic noSuchMethod(Invocation i) {
    other.add(i.memberName.toString());
    throw UnimplementedError('engine: ${i.memberName}');
  }
}

void main() {
  late _Engine e;
  setUp(() {
    e = _Engine();
    useEngineForTest(e);
    final decoy = ArrivalRows(HaloContainer.decoy);
    useDatabasesForTest(decoy, Session(decoy));
    pairNow = () => TestWidgetsFlutterBinding.instance.clock.now();
  });

  testWidgets('the decoy shows a code of its own and waits on it, putting '
      'nothing anywhere', (t) async {
    final r = PairRun.share(pairHooks());
    r.start();
    await t.pump(const Duration(seconds: 3));
    expect(r.phase, PairPhase.live);
    expect(r.code, matches(RegExp(r'^\d\d \d\d\d \d\d\d$')));
    expect(e.looked.toSet(), {r.code!.substring(0, 2)});
    await t.pump(const Duration(seconds: 30));
    expect(r.phase, PairPhase.live);
    expect(r.line, PairLine.waiting);
    expect(e.looked.toSet(), {r.code!.substring(0, 2)});
    expect(e.other, isEmpty);
    // it burns as a real one does
    await t.pump(kPairCodeLife);
    expect(r.line, PairLine.burned);
    r.dispose();
    await t.pump(const Duration(seconds: 5));
    expect(e.other, isEmpty);
  });

  testWidgets('the decoy\'s join runs the everyday lines at the everyday '
      'times: looking, nothing yet, nothing at that code', (t) async {
    final r = PairRun.join(pairHooks());
    r.begin('07 123 456');
    await t.pump();
    expect(r.phase, PairPhase.live);
    expect(r.line, PairLine.looking);
    await t.pump(const Duration(seconds: 15));
    expect(r.line, PairLine.nothingYet);
    await t.pump(kPairLookFor);
    expect(r.phase, PairPhase.ended);
    expect(r.line, PairLine.nothingAtCode);
    expect(e.looked, isNotEmpty);
    expect(e.looked.toSet(), {'07'});
    expect(e.other, isEmpty);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('no relay answering the decoy says what it says on the '
      'everyday side', (t) async {
    e.says = 'unreached';
    final s = PairRun.share(pairHooks());
    s.start();
    await t.pump(const Duration(seconds: 3));
    expect(s.line, PairLine.unreached);
    final j = PairRun.join(pairHooks());
    j.begin('07123456');
    await t.pump(kPairLookFor + const Duration(seconds: 5));
    expect(j.line, PairLine.unreached);
    expect(e.other, isEmpty);
    await t.pump(const Duration(seconds: 5));
  });
}
