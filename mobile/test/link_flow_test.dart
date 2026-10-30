// SPDX-License-Identifier: GPL-3.0-or-later
// a link as the screens see it, over a stand-in for the engine's calls:
// the phone's side signs its next list only after the person's yes and
// keeps what the device sent before it says done; the new device takes
// its place, writes the rows, sends as many bundles as the phone asked
// for; a no ends both; the decoy's link reaches nobody and calls nothing
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/devices/link_calls.dart';
import 'package:kryfo/devices/link_flow.dart';

// the engine as a script: each state call answers what [state] holds now
class _Calls implements LinkCalls {
  final said = <String>[];
  final args = <String, Map<String, Object?>>{};
  Map<String, dynamic> state = {'st': 'accept'};
  final answers = <String, Map<String, dynamic>>{};

  @override
  Map<String, dynamic> call(String op, Map<String, Object?> a) {
    if (op != 'state') said.add(op);
    args[op] = a;
    if (op == 'state') return state;
    return answers[op] ?? {};
  }
}

String _b(List<int> x) => base64Encode(x);

class _Phone implements PhoneLinkHooks {
  final signed = <Uint8List>[];
  LinkTaken? kept;
  @override
  Future<String> identity() async => '05${'ab' * 32}';
  @override
  Future<int> phoneReg() async => 4321;
  @override
  Future<Uint8List> sign(Uint8List body) async {
    signed.add(body);
    return Uint8List.fromList([9, 9, 9]);
  }

  @override
  Future<void> keep(LinkTaken t) async => kept = t;
}

class _Join implements JoinLinkHooks {
  final steps = <String>[];
  int? wanted;
  Uint8List? stream;
  @override
  Future<({String key, int reg})> myKey() async =>
      (key: '05${'cd' * 32}', reg: 77);
  @override
  Future<void> placed(JoinPlace p) async => steps.add('placed ${p.device}');
  @override
  Future<void> writeRows(Map<String, dynamic> answer) async =>
      steps.add('rows ${(answer['rows'] as List).length}');
  @override
  Future<JoinBundles> bundles(int device, int want) async {
    wanted = want;
    steps.add('bundles $device');
    return (
      first: Uint8List.fromList([1]),
      last: Uint8List.fromList([2]),
      once: [
        for (var i = 0; i < want; i++) Uint8List.fromList([3, i]),
      ],
      made: 1000,
    );
  }

  @override
  Future<void> joined(JoinPlace p, Uint8List s) async {
    steps.add('joined');
    stream = s;
  }
}

const _tick = Duration(milliseconds: 10);

void main() {
  testWidgets(
    'the phone signs its list only after the yes, and keeps all before done',
    (t) async {
      {
        final c = _Calls()..answers['link_start'] = {'link': 'L1'};
        final h = _Phone();
        final f = PhoneLinkFlow(c, code: 'kryfo-link:x', hooks: h, poll: _tick);
        f.start();
        await t.pump();
        expect(c.args['link_start'], {
          'offer': 'kryfo-link:x',
          'key': '05${'ab' * 32}',
        });
        expect(f.value.step, LinkStep.reaching);
        c.state = {'st': 'digits', 'sas': '123456'};
        await t.pump(_tick * 2);
        expect(f.value.step, LinkStep.digits);
        expect(f.value.digits, '123456');
        // nothing signed while the person compares
        expect(h.signed, isEmpty);
        expect(c.said, ['link_start']);
        c.answers['list'] = {
          'body': _b([1, 2, 3]),
        };
        f.match();
        await t.pump();
        expect(f.value.step, LinkStep.linking);
        expect(h.signed.single, [1, 2, 3]);
        expect(c.said, ['link_start', 'list', 'sign', 'confirm']);
        expect(c.args['list'], {'link': 'L1', 'ident': 0, 'reg': 4321});
        expect(c.args['sign']!['sig'], _b([9, 9, 9]));
        c.answers['take'] = {
          'device': {'id': 9, 'key': '05${'ee' * 32}', 'reg': 77},
          'list': _b([4]),
          'first': _b([5]),
          'last': _b([6]),
          'once': [
            _b([7]),
            _b([8]),
          ],
          'made': 1234,
          'stream': _b(List.filled(32, 1)),
        };
        c.state = {'st': 'bundles'};
        await t.pump(_tick * 2);
        expect(f.value.step, LinkStep.done);
        expect(h.kept!.device, 9);
        expect(h.kept!.once.length, 2);
        expect(h.kept!.made, 1234);
        expect(c.said.where((s) => s == 'take').length, 1);
        // done stops the polling
        final n = c.said.length;
        await t.pump(_tick * 10);
        expect(c.said.length, n);
        f.dispose();
      }
    },
  );

  testWidgets('a no ends the link and nothing is signed', (t) async {
    {
      final c = _Calls()..answers['link_start'] = {'link': 'L1'};
      final h = _Phone();
      final f = PhoneLinkFlow(c, code: 'kryfo-link:x', hooks: h, poll: _tick);
      f.start();
      c.state = {'st': 'digits', 'sas': '654321'};
      await t.pump(_tick * 2);
      f.noMatch();
      expect(f.value.step, LinkStep.failed);
      expect(f.value.end, LinkEnd.stopped);
      expect(c.said, ['link_start', 'end']);
      expect(h.signed, isEmpty);
      f.dispose();
    }
  });

  testWidgets('no answer from the device says so after the wait', (t) async {
    {
      final c = _Calls()..answers['link_start'] = {'link': 'L1'};
      final f = PhoneLinkFlow(
        c,
        code: 'kryfo-link:x',
        hooks: _Phone(),
        poll: _tick,
      );
      f.start();
      await t.pump(kLinkReachWait - const Duration(seconds: 1));
      expect(f.value.step, LinkStep.reaching);
      await t.pump(const Duration(seconds: 2));
      expect(f.value.step, LinkStep.failed);
      expect(f.value.end, LinkEnd.unreached);
      expect(c.said.last, 'end');
      f.dispose();
    }
  });

  testWidgets("the engine's reasons become the person's", (t) async {
    expect(linkEndOf('expired'), LinkEnd.unreached);
    expect(linkEndOf('unreached'), LinkEnd.unreached);
    expect(linkEndOf('full'), LinkEnd.full);
    expect(linkEndOf('too_many'), LinkEnd.full);
    expect(linkEndOf('refused'), LinkEnd.stopped);
    expect(linkEndOf('ended'), LinkEnd.stopped);
    {
      final c = _Calls()..answers['link_start'] = {'link': 'L1'};
      final f = PhoneLinkFlow(
        c,
        code: 'kryfo-link:x',
        hooks: _Phone(),
        poll: _tick,
      );
      f.start();
      c.state = {'st': 'digits', 'sas': '111111'};
      await t.pump(_tick * 2);
      c.answers['list'] = {'err': 'too_many'};
      f.match();
      await t.pump();
      expect(f.value.end, LinkEnd.full);
      f.dispose();
    }
  });

  testWidgets(
    'the new device takes its place, then sends what the phone asked for',
    (t) async {
      {
        final c = _Calls()
          ..answers['join_start'] = {'link': 'J1', 'offer': 'kryfo-link:abc'}
          ..answers['own'] = {
            'rows': [{}, {}],
          };
        final h = _Join();
        final f = JoinLinkFlow(c, hooks: h, poll: _tick);
        f.start();
        await t.pump();
        expect(c.args['join_start'], {'key': '05${'cd' * 32}', 'reg': 77});
        expect(f.value.step, LinkStep.showing);
        expect(f.value.offer, 'kryfo-link:abc');
        c.state = {'st': 'digits', 'sas': '222333'};
        await t.pump(_tick * 2);
        expect(f.value.digits, '222333');
        f.match();
        await t.pump();
        expect(c.said, ['join_start', 'confirm']);
        c.state = {
          'st': 'placed',
          'identity': '05${'ab' * 32}',
          'key_number': '11111 22222 33333 44444',
          'want': 3,
          'device': {'id': 42, 'key': '05${'cd' * 32}', 'reg': 77},
        };
        await t.pump(_tick * 3);
        expect(h.steps, ['placed 42', 'rows 2', 'bundles 42']);
        expect(h.wanted, 3);
        expect(c.said, ['join_start', 'confirm', 'own', 'bundles']);
        expect((c.args['bundles']!['once'] as List).length, 3);
        expect(c.args['bundles']!['made'], 1000);
        c.answers['take'] = {'stream': _b(List.filled(32, 5))};
        c.state = {'st': 'done'};
        await t.pump(_tick * 2);
        expect(f.value.step, LinkStep.done);
        expect(f.value.keyNumber, '11111 22222 33333 44444');
        expect(h.steps.last, 'joined');
        expect(h.stream!.length, 32);
        f.dispose();
      }
    },
  );

  testWidgets('a refused own list ends the new device before any bundle goes', (
    t,
  ) async {
    {
      final c = _Calls()
        ..answers['join_start'] = {'link': 'J1', 'offer': 'kryfo-link:abc'}
        ..answers['own'] = {'err': 'source', 'rows': []};
      final h = _Join();
      final f = JoinLinkFlow(c, hooks: h, poll: _tick);
      f.start();
      c.state = {
        'st': 'placed',
        'identity': '05${'ab' * 32}',
        'key_number': '1',
        'device': {'id': 42, 'key': 'k', 'reg': 77},
      };
      await t.pump(_tick * 3);
      expect(f.value.step, LinkStep.failed);
      expect(c.said, isNot(contains('bundles')));
      expect(h.steps, isNot(contains('bundles 42')));
      f.dispose();
    }
  });

  testWidgets(
    "the decoy's link waits as long as a real one, then reaches nobody",
    (t) async {
      {
        final f = DecoyLinkFlow();
        f.start();
        expect(f.value.step, LinkStep.reaching);
        await t.pump(kLinkReachWait - const Duration(seconds: 1));
        expect(f.value.step, LinkStep.reaching);
        await t.pump(const Duration(seconds: 10));
        expect(f.value.step, LinkStep.failed);
        expect(f.value.end, LinkEnd.unreached);
        // a yes or a no does nothing: there are never numbers
        f.match();
        f.noMatch();
        expect(f.value.end, LinkEnd.unreached);
        f.dispose();
      }
    },
  );
}
