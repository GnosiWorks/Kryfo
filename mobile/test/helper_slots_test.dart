import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/helper_slots.dart';
import 'package:kryfo/l10n/app_localizations.dart';

// an address in group g
KnockAddress at(String a, String g) => KnockAddress(a, g);

// batch i of the main identity's contacts (engine/batches.go)
String lane(int i) => 'everyday:0:$i';

// every slot serves one group, and every address sits on a slot of its own
// group
void expectApart(SlotBook b, List<KnockAddress> live) {
  final groupOf = {for (final a in live) a.address: a.group};
  for (final e in b.byAddress.entries) {
    expect(b.owner[e.value], groupOf[e.key], reason: e.key);
  }
  final groupsOn = <int, Set<String>>{};
  for (final e in b.byAddress.entries) {
    (groupsOn[e.value] ??= {}).add(groupOf[e.key]!);
  }
  for (final g in groupsOn.values) {
    expect(g.length, 1);
  }
}

void main() {
  final rnd = Random(7);

  test('a batch has one slot, its addresses share it', () {
    final live = [
      for (var i = 0; i < 10; i++) at('c$i', lane(i ~/ 8)),
      at('fc', 'firstcontact:fc'),
    ];
    final b = planSlots(const SlotBook(), live, rnd).book;
    expect(b.byAddress.length, 11);
    expect(b.byAddress.values.toSet().length, 3);
    expect({for (var i = 0; i < 8; i++) b.slotOf('c$i')}.length, 1);
    expectApart(b, live);
  });

  test('a slot never serves two groups, whatever comes and goes', () {
    final r = Random(3);
    var book = const SlotBook();
    var live = <KnockAddress>[];
    final served = <String, String>{};
    for (var step = 0; step < 300; step++) {
      final n = r.nextInt(6);
      if (n < 3 || live.isEmpty) {
        final g = switch (r.nextInt(6)) {
          0 => 'room:${r.nextInt(5)}',
          1 => 'firstcontact:${r.nextInt(2)}',
          _ => lane(r.nextInt(4)),
        };
        live = [...live, at('a$step', g)];
      } else {
        live = [...live]..removeAt(r.nextInt(live.length));
      }
      book = planSlots(book, live, r).book;
      expectApart(book, live);
      // one endpoint, one group, for good
      for (final e in book.byAddress.entries) {
        final g = live.firstWhere((a) => a.address == e.key).group;
        final key = '${e.value}.${book.gen[e.value] ?? 0}';
        expect(served.putIfAbsent(key, () => g), g, reason: key);
      }
    }
  });

  test('an address keeps its slot', () {
    final live = [at('a', lane(0)), at('b', lane(1))];
    final b1 = planSlots(const SlotBook(), live, rnd).book;
    final b2 = planSlots(b1, [...live, at('c', lane(0))], rnd).book;
    expect(b2.slotOf('a'), b1.slotOf('a'));
    expect(b2.slotOf('b'), b1.slotOf('b'));
  });

  test('a batch owns one slot, however full', () {
    final live = [for (var i = 0; i < 8; i++) at('c$i', lane(0))];
    final b = planSlots(const SlotBook(), live, rnd).book;
    expect(b.byAddress.length, 8);
    expect(b.byAddress.values.toSet().length, 1);
  });

  test('the main groups keep their slots from the rooms', () {
    // rooms first: one slot waits for the first-contact address
    var live = [for (var i = 0; i < 20; i++) at('r$i', 'room:$i')];
    var b = planSlots(const SlotBook(), live, rnd).book;
    expect(b.byAddress.length, kHelperSlots - 1);
    live = [...live, at('fc', 'firstcontact:fc')];
    b = planSlots(b, live, rnd).book;
    expect(b.slotOf('fc'), isNotNull);
    // all at once, rooms do not take what the batches need
    live = [
      for (var i = 0; i < 20; i++) at('r$i', 'room:$i'),
      for (var i = 0; i < 40; i++) at('c$i', lane(i ~/ 8)),
      at('fc', 'firstcontact:fc'),
    ];
    final all = planSlots(const SlotBook(), live, rnd).book;
    for (final a in ['fc', for (var i = 0; i < 40; i++) 'c$i']) {
      expect(all.slotOf(a), isNotNull, reason: a);
    }
    expect(all.owner.values.where((g) => g.startsWith('room:')).length, 10);
    expectApart(all, live);
  });

  // a phone as it is now: [n] chats, one in ten hidden (never registered),
  // the rest in batches of eight in listen order, one first-contact
  // address. how many addresses get no slot
  ({int batches, int hidden, int unregistered}) phoneOf(
    int n, {
    SlotBook book = const SlotBook(),
  }) {
    final hidden = n ~/ 10;
    final everyday = n - hidden;
    final live = [
      for (var i = 0; i < everyday; i++) at('c$i', lane(i ~/ 8)),
      at('fc', 'firstcontact:fc'),
    ];
    final b = planSlots(book, live, Random(1)).book;
    expectApart(b, live);
    return (
      batches: (everyday + 7) ~/ 8,
      hidden: hidden,
      unregistered: live.where((a) => b.slotOf(a.address) == null).length,
    );
  }

  test('slots for 15, 50 and 120 contacts: one per batch and the first-'
      'contact address, under the cap', () {
    for (final n in [15, 50, 120]) {
      final p = phoneOf(n);
      // ignore: avoid_print
      print(
        '$n contacts: ${p.batches} batches + 1 first-contact = '
        '${p.batches + 1} of $kHelperSlots slots, ${p.hidden} hidden lanes '
        '(${p.batches + 1 + p.hidden} if they were registered), '
        '${p.unregistered} unregistered',
      );
      expect(p.unregistered, 0, reason: '$n contacts');
    }
    // past the cap the newest batches are left to the check-ins, never
    // put on another batch's endpoint
    final big = phoneOf(200);
    expect(big.batches + 1, greaterThan(kHelperSlots));
    expect(big.unregistered, 200 - big.hidden - (kHelperSlots - 1) * 8);
  });

  test('the four lanes before batches let their slots go once', () {
    // a 0.5 phone: three slots for each of everyday:0..3
    final owner = <int, String>{
      for (var s = 0; s < 12; s++) s: 'everyday:${s ~/ 3}',
    };
    final old = SlotBook(
      byAddress: {for (var s = 0; s < 12; s++) 'old$s': s},
      owner: owner,
    );
    final plan = planSlots(old, [
      for (var i = 0; i < 50; i++) at('c$i', lane(i ~/ 8)),
      at('fc', 'firstcontact:fc'),
    ], rnd);
    expect(plan.renew, {for (var s = 0; s < 12; s++) s});
    expect(
      plan.book.owner.values.where(
        (g) => RegExp(r'^everyday:\d+$').hasMatch(g),
      ),
      isEmpty,
    );
    // their new endpoints serve batches from the next round
    final next = planSlots(plan.book, [
      for (var i = 0; i < 50; i++) at('c$i', lane(i ~/ 8)),
      at('fc', 'firstcontact:fc'),
    ], rnd);
    for (var i = 0; i < 50; i++) {
      expect(next.book.slotOf('c$i'), isNotNull, reason: 'c$i');
    }
    expect(next.renew, isEmpty);
  });

  test('a room that is gone gives its slot back on a new endpoint', () {
    final live = [at('c0', lane(0)), at('r', 'room:x')];
    final p1 = planSlots(const SlotBook(), live, rnd);
    final s = p1.book.slotOf('r')!;
    expect(p1.renew, isEmpty);
    final p2 = planSlots(p1.book, [at('c0', lane(0))], rnd);
    expect(p2.renew, {s});
    expect(p2.book.owner[s], isNull);
    expect(p2.book.gen[s], 1);
    expect(p2.book.instance(s), 'kryfo-$s.1');
    // the next room may take it, under the new generation only
    final p3 = planSlots(p2.book, [at('c0', lane(0)), at('r2', 'room:y')], rnd);
    expect(p3.book.slotOf('r2'), s);
    expect(p3.book.instance(s), 'kryfo-$s.1');
  });

  test('a batch is never let go, even with nobody in it', () {
    final p1 = planSlots(const SlotBook(), [at('c', lane(2))], rnd);
    final s = p1.book.slotOf('c')!;
    final p2 = planSlots(p1.book, const [], rnd);
    expect(p2.renew, isEmpty);
    expect(p2.book.owner[s], lane(2));
  });

  test('a replaced first-contact address does not inherit the old slot', () {
    final p1 = planSlots(const SlotBook(), [
      at('fc1', 'firstcontact:fc1'),
    ], rnd);
    final old = p1.book.slotOf('fc1')!;
    final p2 = planSlots(p1.book, [at('fc2', 'firstcontact:fc2')], rnd);
    expect(p2.book.slotOf('fc2'), isNot(old));
    expect(p2.renew, {old});
  });

  test('every slot without an address has a stand-in key', () {
    final b = planSlots(const SlotBook(), [at('c', lane(0))], rnd).book;
    for (var s = 0; s < kHelperSlots; s++) {
      if (s == b.slotOf('c')) continue;
      expect(b.standIn[s], matches(RegExp(r'^[0-9a-f]{64}$')));
    }
    expect(b.standIn.values.toSet().length, kHelperSlots - 1);
  });

  test('what is registered: addresses on their endpoint, stand-ins on the '
      'rest, and a stand-in forgotten once its slot carries an address', () {
    final b0 = planSlots(const SlotBook(), const [], rnd).book;
    final eps = {for (var s = 0; s < kHelperSlots; s++) s: 'https://p/up$s'};
    final w0 = wantedItems(b0, eps);
    expect(w0.length, kHelperSlots);
    expect(w0.every((i) => i.key != null && i.endpoint.isNotEmpty), isTrue);

    final b1 = planSlots(b0, [at('c', lane(0))], rnd).book;
    final s = b1.slotOf('c')!;
    final w1 = wantedItems(b1, eps);
    final mine = w1.where((i) => i.address == 'c').single;
    expect(mine.endpoint, 'https://p/up$s');
    final forget = w1.where((i) => i.slot == s && i.key != null).single;
    expect(forget.endpoint, isEmpty);
    expect(forget.toJson(), {'k': b0.standIn[s], 's': s, 'e': ''});
    // a slot with no endpoint yet is left for later
    expect(wantedItems(b1, const {}), isEmpty);
  });

  test('endpoints count only for the book\'s generation', () {
    const b = SlotBook(gen: {3: 2});
    final eps = slotEndpoints(b, {
      'kryfo-0.0': 'https://p/a',
      'kryfo-3.1': 'https://p/old',
      'kryfo-3.2': 'https://p/new',
      'kryfo-16.0': 'https://p/x',
      'other': 'https://p/y',
    });
    expect(eps, {0: 'https://p/a', 3: 'https://p/new'});
  });

  test('the book survives a round trip and a bad one reads empty', () {
    final b = planSlots(const SlotBook(), [
      at('a', lane(0)),
      at('r', 'room:1'),
    ], rnd).book;
    final back = SlotBook.read(b.write());
    expect(back.byAddress, b.byAddress);
    expect(back.owner, b.owner);
    expect(back.standIn, b.standIn);
    for (final bad in [null, '', 'not json', '[1,2]', '{"a": {"x": 99}}']) {
      expect(SlotBook.read(bad).byAddress, isEmpty, reason: bad);
    }
    expect(
      SlotBook.read('{"o": {"40": "x"}, "k": {"1": "short"}}').owner,
      isEmpty,
    );
  });

  test('the engine\'s list is read, and anything else is nothing', () {
    expect(
      knockAddressesOf('[{"i":"x","g":"everyday:1"},{"i":3}]').single.group,
      'everyday:1',
    );
    expect(knockAddressesOf('error: no engine'), isEmpty);
  });

  test(
    'about one contact address in five rests, each in a month of its own',
    () {
      const t0 = 1800000000000;
      const day = 24 * 60 * 60 * 1000;
      final ids = [for (var i = 0; i < 2000; i++) 'id$i'];
      final resting = ids.where((id) => restsNow(id, t0)).length;
      expect(resting, inInclusiveRange(300, 500));
      // over a year each id changes now and then, and not on one shared day
      final changeDays = <int>{};
      for (final id in ids.take(200)) {
        var was = restsNow(id, t0);
        for (var d = 1; d < 365; d++) {
          final now = restsNow(id, t0 + d * day);
          if (now != was) changeDays.add(d);
          was = now;
        }
      }
      expect(changeDays.length, greaterThan(100));
    },
  );

  test('the getting messages note says how long a contact rests', () {
    expect(kRestWindowMs, 30 * 24 * 60 * 60 * 1000);
    expect(kRestOneIn, 5);
    expect(
      lookupAppLocalizations(const Locale('en')).gettingMessagesHelperNote,
      contains('about one month in five'),
    );
  });
}
