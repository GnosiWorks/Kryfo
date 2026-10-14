// the helper app mode end to end on this side: a stand-in helper app that
// hands out endpoints the way a distributor does, a stand-in engine that
// takes registrations the way our relay does, and the mode between them.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/helper_delivery.dart';
import 'package:kryfo/helper_push.dart';
import 'package:kryfo/helper_slots.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ch = MethodChannel('halo/helper');

// a unifiedpush distributor: one endpoint per registration, a new one for
// each new registration
class FakeDistributor {
  final String package;
  final Map<String, String> endpoints = {};
  final List<String> dropped = [];
  final List<String> events = [];
  var _n = 0;
  bool installed = true;
  bool answers = true;
  String? chosen;
  // the book's generations as they stood when a registration was let go
  final List<String> bookAtDrop = [];
  FakeDistributor(this.package);

  Future<Object?> handle(MethodCall call) async {
    final a = call.arguments is Map ? call.arguments as Map : const {};
    switch (call.method) {
      case 'helperApps':
        return [
          if (installed) {'package': package, 'name': 'ntfy'},
        ];
      case 'helperChosen':
        return chosen;
      case 'helperEndpoints':
        return endpoints;
      case 'helperRegister':
        if (a['package'] != package || !installed) return false;
        chosen = package;
        events.add('register ${a['instance']}');
        if (answers) {
          endpoints[a['instance'] as String] =
              'https://push.example.org/up${_n++}?up=1';
        }
        return true;
      case 'helperUnregisterOne':
        final prefs = await SharedPreferences.getInstance();
        bookAtDrop.add(prefs.getString(kHelperSlotsKey) ?? '');
        dropped.add(a['instance'] as String);
        endpoints.remove(a['instance']);
        events.add('drop ${a['instance']}');
        return true;
      case 'helperUnregister':
        dropped.addAll(endpoints.keys);
        endpoints.clear();
        chosen = null;
        events.add('unregister');
        return true;
    }
    return null;
  }
}

// our relay as the engine reaches it: what it holds per id or stand-in
// key, and what it was asked
class FakeEngine implements KnockEngine {
  List<KnockAddress> live = [];
  String check = 'yes';
  int checks = 0;
  String lastExclude = '';
  final List<List<Map<String, dynamic>>> sent = [];
  final Map<String, String> relay = {};
  final Map<String, int> made = {};
  // every forget asked for, with its signed time
  final List<(String, int)> forgets = [];
  bool up = true;
  Set<String> dups = {};
  // names the relay answers no for, every time
  Set<String> refuse = {};
  // the hidden list the last register call carried
  List<String> hiddenInCall = [];

  @override
  Future<String> knockAddresses(String excludeJson) async {
    lastExclude = excludeJson;
    return jsonEncode([
      for (final a in live) {'i': a.address, 'g': a.group},
    ]);
  }

  @override
  Future<String> knockCheck() async {
    checks++;
    return check;
  }

  @override
  Future<String> knockRegister(String itemsJson) async {
    if (!up) return 'error: tor not started';
    final call = jsonDecode(itemsJson) as Map<String, dynamic>;
    hiddenInCall = [for (final h in call['hidden'] as List) '$h'];
    final items = [
      for (final i in call['items'] as List) i as Map<String, dynamic>,
    ];
    sent.add(items);
    final done = <String>[];
    final dup = <String>[];
    final unknown = <String>[];
    final refused = <String>[];
    final known = {for (final a in live) a.address};
    for (final i in items) {
      final name = i['i'] as String? ?? 's${i['s']}';
      final key = i['i'] as String? ?? i['k'] as String;
      final forget = (i['e'] as String).isEmpty;
      if (i['i'] != null && !known.contains(i['i'])) {
        unknown.add(name);
        continue;
      }
      if (forget) forgets.add((key, i['t'] as int? ?? 0));
      if (dups.remove(name)) {
        dup.add(name);
        continue;
      }
      if (refuse.contains(name)) {
        refused.add(name);
        continue;
      }
      if (forget) {
        relay.remove(key);
      } else {
        relay[key] = i['e'] as String;
      }
      made[key] = i['t'] as int? ?? 0;
      done.add(name);
    }
    return jsonEncode({
      'done': done,
      'dup': dup,
      'unknown': unknown,
      'refused': refused,
    });
  }
}

// an id that is not resting on any day of the two months the tests span
String steady(String base) {
  for (var n = 0; ; n++) {
    final id = '$base.$n';
    var ok = true;
    for (var d = 0; d < 60 && ok; d++) {
      ok = !restsNow(id, 1800000000000 + d * 24 * 60 * 60 * 1000);
    }
    if (ok) return id;
  }
}

final c = [for (var i = 0; i < 10; i++) steady('c$i')];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeDistributor ntfy;
  late FakeEngine engine;
  late HelperDelivery helper;
  var hidden = <String>[];
  var now = 1800000000000;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ntfy = FakeDistributor('io.heckel.ntfy');
    engine = FakeEngine();
    now = 1800000000000;
    hidden = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ch, ntfy.handle);
    helper = HelperDelivery(
      engine: engine,
      push: HelperPush(_ch),
      hidden: () => hidden,
      rnd: Random(1),
      nowMs: () => now,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ch, null);
  });

  // rounds until nothing is left, or [max]
  Future<int> rounds({int max = 64}) async {
    var n = 0;
    for (var i = 0; i < max; i++) {
      await helper.sync();
      n++;
      if (!helper.more) break;
    }
    return n;
  }

  group('the gate', () {
    test('hidden until our relay says it knocks, asked once a day', () async {
      expect(await helper.relayKnocks(), isFalse);
      expect(engine.checks, 0);
      expect(await helper.relayKnocks(ask: true), isTrue);
      expect(await helper.relayKnocks(), isTrue);
      expect(await helper.relayKnocks(ask: true), isTrue);
      expect(engine.checks, 1);
      now += kRelayAskEveryMs;
      engine.check = 'no';
      expect(await helper.relayKnocks(ask: true), isFalse);
      expect(engine.checks, 2);
    });

    test('an old relay keeps it hidden', () async {
      engine.check = 'no';
      expect(await helper.relayKnocks(ask: true), isFalse);
      expect(await helper.relayKnocks(), isFalse);
    });

    test('a relay that could not be asked keeps the last answer', () async {
      expect(await helper.relayKnocks(ask: true), isTrue);
      now += kRelayAskEveryMs + 1;
      engine.check = 'error: tor not started';
      expect(await helper.relayKnocks(ask: true), isTrue);
      SharedPreferences.setMockInitialValues({});
      expect(await helper.relayKnocks(ask: true), isFalse);
    });
  });

  group('set up and registrations', () {
    final contacts = [
      for (var i = 0; i < 6; i++) KnockAddress(c[i], 'everyday:${i % 4}'),
    ];
    const fc = KnockAddress('fc', 'firstcontact:aa');

    test('sixteen endpoints, every address and stand-in registered once, '
        'no endpoint shared across groups', () async {
      engine.live = [...contacts, fc];
      expect(await helper.setUp(ntfy.package, wait: Duration.zero), isTrue);
      expect(ntfy.endpoints.length, kHelperSlots);
      await rounds();
      expect(engine.relay.length, kHelperSlots);
      final groupOf = {for (final a in engine.live) a.address: a.group};
      final byEndpoint = <String, Set<String>>{};
      for (final e in engine.relay.entries) {
        (byEndpoint[e.value] ??= {}).add(groupOf[e.key] ?? 'stand-in:${e.key}');
      }
      expect(byEndpoint.length, kHelperSlots);
      for (final g in byEndpoint.values) {
        expect(g.length, 1);
      }
      // nothing changed: nothing is sent
      final before = engine.sent.length;
      expect(await helper.sync(), 0);
      expect(engine.sent.length, before);
    });

    test('one group a round, new groups first, and a round never mixes '
        'groups', () async {
      engine.live = [...contacts, fc];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      final groupOf = {for (final a in engine.live) a.address: a.group};
      await rounds();
      expect(engine.sent.length, greaterThan(5));
      for (final batch in engine.sent) {
        final groups = {
          for (final i in batch) groupOf[i['i']] ?? 'stand-in ${i['s']}',
        };
        expect(groups.length, 1, reason: '$batch');
      }
      // a contact who arrives later goes in the next round, before renewals
      now += kRefreshMinMs + kRefreshSpanMs;
      engine.live = [...engine.live, KnockAddress(c[9], 'room:bb')];
      await helper.sync();
      expect(engine.sent.last.any((i) => i['i'] == c[9]), isTrue);
    });

    test('renewals fall on days of their own', () async {
      engine.live = [...contacts, fc];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await rounds();
      final prefs = await SharedPreferences.getInstance();
      final synced = jsonDecode(prefs.getString(kHelperSyncedKey)!) as Map;
      final dues = {for (final v in synced.values) (v as List)[2] as int};
      expect(dues.length, greaterThan(synced.length ~/ 2));
      for (final d in dues) {
        expect(
          d - now,
          inInclusiveRange(kRefreshMinMs, kRefreshMinMs + kRefreshSpanMs),
        );
      }
      // four days on, only some are due
      now += kRefreshMinMs + kRefreshSpanMs ~/ 2;
      final before = engine.sent.length;
      await rounds();
      final again = {
        for (final b in engine.sent.skip(before))
          for (final i in b) i['i'] ?? 's${i['s']}',
      };
      expect(again.length, lessThan(synced.length));
      expect(again, isNotEmpty);
    });

    test('a batch is not signed in one second, and a resend is always '
        'later than the one before', () async {
      engine.live = [...contacts, fc];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await rounds();
      final ts = [
        for (final b in engine.sent)
          for (final i in b) i['t'] as int,
      ];
      final nowS = now ~/ 1000;
      expect(ts.every((t) => t <= nowS && t >= nowS - kSignedJitterS), isTrue);
      expect(ts.toSet().length, greaterThan(ts.length ~/ 2));
      now += 60 * 1000;
      final s = SlotBook.read(
        (await SharedPreferences.getInstance()).getString(kHelperSlotsKey),
      ).slotOf(c[0])!;
      ntfy.endpoints['kryfo-$s.0'] = 'https://push.example.org/upNew';
      await rounds();
      final again = engine.sent.last.where((i) => i['i'] == c[0]).single;
      expect(again['t'] as int, greaterThan(nowS));
    });

    test('the hidden chats\' peers go to the engine to be left out, in the '
        'register call too', () async {
      hidden = ['peer-h'];
      engine.live = [...contacts];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await helper.sync();
      expect(jsonDecode(engine.lastExclude), ['peer-h']);
      expect(engine.hiddenInCall, ['peer-h']);
    });

    test('a registration the relay refuses waits and lets the others renew, '
        'and the screen hears of it once it lasts', () async {
      engine.live = [...contacts];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await rounds();
      final first = {
        for (final a in contacts) a.address: engine.made[a.address],
      };
      now += 7 * 24 * 60 * 60 * 1000;
      final room = KnockAddress(steady('room1'), 'room:r1');
      engine.live = [...contacts, room];
      engine.refuse = {room.address};
      for (var i = 0; i < 200; i++) {
        await helper.sync();
        now += 15 * 60 * 1000;
      }
      for (final a in contacts) {
        expect(
          engine.made[a.address],
          isNot(first[a.address]),
          reason: a.address,
        );
      }
      final tries = engine.sent.where(
        (b) => b.any((it) => it['i'] == room.address),
      );
      expect(tries.length, lessThan(15));
      expect(await helper.refusedLasting(), isTrue);
      engine.refuse = {};
      for (var i = 0; i < 200 && await helper.refusedLasting(); i++) {
        await helper.sync();
        now += 15 * 60 * 1000;
      }
      expect(await helper.refusedLasting(), isFalse);
      expect(engine.relay.containsKey(room.address), isTrue);
    });

    test('the relay says not newer: tried again later, newer', () async {
      engine.live = [contacts.first];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      engine.dups = {c[0]};
      await rounds();
      expect(engine.relay.containsKey(c[0]), isFalse);
      final firstT =
          engine.sent.expand((b) => b).where((i) => i['i'] == c[0]).single['t']
              as int;
      now += kDupRetryMs ~/ 2;
      await rounds();
      expect(engine.relay.containsKey(c[0]), isFalse);
      now += kDupRetryMs;
      await rounds();
      expect(engine.relay.containsKey(c[0]), isTrue);
      expect(engine.made[c[0]]!, greaterThan(firstT));
    });

    test('a helper app that gives no endpoint fails the set-up', () async {
      ntfy.answers = false;
      expect(await helper.setUp(ntfy.package, wait: Duration.zero), isFalse);
    });

    test(
      'a slot the helper app dropped is asked again, not in a loop',
      () async {
        engine.live = [...contacts];
        await helper.setUp(ntfy.package, wait: Duration.zero);
        ntfy.endpoints.remove('kryfo-3.0');
        final before = ntfy.events.length;
        ntfy.answers = false;
        await helper.sync();
        await helper.sync();
        await helper.sync();
        final asked = ntfy.events
            .skip(before)
            .where((e) => e == 'register kryfo-3.0')
            .length;
        expect(asked, 1);
        now += kAskAgainMs;
        await helper.sync();
        expect(ntfy.events.where((e) => e == 'register kryfo-3.0').length, 3);
      },
    );

    test('off tor nothing is marked sent, and it goes later', () async {
      engine.live = [...contacts];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      engine.up = false;
      expect(await helper.sync(), 0);
      engine.up = true;
      await rounds();
      expect(engine.relay.length, kHelperSlots);
    });

    test('a room that ends: its slot is let go before the book moves on, '
        'and comes back on a new endpoint', () async {
      engine.live = [...contacts, const KnockAddress('r1', 'room:a')];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await rounds();
      final roomEndpoint = engine.relay['r1'];
      final s = SlotBook.read(
        (await SharedPreferences.getInstance()).getString(kHelperSlotsKey),
      ).slotOf('r1')!;
      engine.live = [...contacts];
      await rounds();
      expect(ntfy.dropped, ['kryfo-$s.0']);
      // the helper app let go while the book still held the old generation
      expect(SlotBook.read(ntfy.bookAtDrop.single).gen[s] ?? 0, 0);
      expect(ntfy.endpoints.values, isNot(contains(roomEndpoint)));
      expect(ntfy.endpoints.length, kHelperSlots);
      final fresh = ntfy.endpoints.entries
          .where((e) => e.key.endsWith('.1'))
          .single
          .value;
      expect(engine.relay.values, contains(fresh));
      // and the room's own registration is left to lapse: no forget is
      // signed for an address that is gone
      expect(engine.forgets, isEmpty);
    });

    test('a chat hidden is not forgotten: its registration lapses', () async {
      engine.live = [...contacts];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await rounds();
      engine.live = [...contacts.skip(1)];
      now += kRefreshMinMs + kRefreshSpanMs;
      await rounds();
      expect(engine.forgets, isEmpty);
      expect(
        engine.sent.expand((b) => b).where((i) => i['i'] == c[0]).length,
        1,
      );
    });

    test('a contact resting is not registered, and comes back after', () async {
      // an id resting now, and not a month later
      var id = '';
      for (var n = 0; id.isEmpty; n++) {
        final x = 'rest$n';
        if (restsNow(x, now) &&
            !restsNow(x, now + kRestWindowMs + 24 * 60 * 60 * 1000)) {
          id = x;
        }
      }
      engine.live = [KnockAddress(id, 'everyday:0'), ...contacts];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await rounds();
      expect(engine.relay.containsKey(id), isFalse);
      now += kRestWindowMs + 24 * 60 * 60 * 1000;
      await rounds();
      expect(engine.relay.containsKey(id), isTrue);
    });

    test('leaving the mode: the helper app lets go at once, the relay '
        'forgets one at a time, each signed after its registration', () async {
      engine.live = [...contacts, fc];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await rounds();
      final before = Set.of(ntfy.endpoints.values);
      final held = engine.relay.length;
      final made = Map.of(engine.made);
      await helper.stop();
      expect(ntfy.endpoints, isEmpty);
      expect(await helper.forgetsLeft(), isTrue);
      final sentBefore = engine.sent.length;
      var n = 0;
      while (await helper.forgetsLeft() && n < 100) {
        await helper.forgetRound();
        n++;
      }
      expect(engine.relay, isEmpty);
      final forgets = engine.sent.skip(sentBefore).toList();
      expect(forgets.every((b) => b.length == 1), isTrue);
      expect(forgets.length, held);
      for (final (key, t) in engine.forgets) {
        expect(t, greaterThan(made[key]!), reason: key);
      }
      await helper.setUp(ntfy.package, wait: Duration.zero);
      expect(before.intersection(Set.of(ntfy.endpoints.values)), isEmpty);
    });

    test('set up again with forgets still queued: what is registered again '
        'is never forgotten', () async {
      engine.live = [...contacts];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await rounds();
      await helper.stop();
      expect(await helper.forgetsLeft(), isTrue);
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await rounds();
      for (var i = 0; i < 40 && await helper.forgetsLeft(); i++) {
        await helper.forgetRound();
      }
      for (final a in contacts) {
        expect(engine.relay.containsKey(a.address), isTrue, reason: a.address);
      }
      expect(
        engine.forgets.where((f) => contacts.any((a) => a.address == f.$1)),
        isEmpty,
      );
    });

    test('a phone moving away drops its forgets: nothing is sent', () async {
      engine.live = [...contacts];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await rounds();
      final sent = engine.sent.length;
      await helper.stop();
      await helper.dropForgets();
      expect(await helper.forgetsLeft(), isFalse);
      expect(engine.sent.length, sent);
      expect(ntfy.endpoints, isEmpty);
    });

    test('the tries of a forget are kept across a restart', () async {
      engine.live = [...contacts];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await rounds();
      await helper.stop();
      engine.live = [];
      final queued =
          jsonDecode(
                (await SharedPreferences.getInstance()).getString(
                  kHelperForgetKey,
                )!,
              )
              as List;
      var rounds2 = 0;
      while (await helper.forgetsLeft() && rounds2 < 500) {
        // a new process every round
        helper = HelperDelivery(
          engine: engine,
          push: HelperPush(_ch),
          rnd: Random(rounds2),
          nowMs: () => now,
        );
        await helper.forgetRound();
        rounds2++;
      }
      expect(await helper.forgetsLeft(), isFalse);
      expect(rounds2, lessThanOrEqualTo(queued.length * kForgetTries));
    });

    test('a forget for an address no longer listened on is given up after '
        'a few; with tor down nothing is counted', () async {
      engine.live = [...contacts];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await rounds();
      await helper.stop();
      engine.up = false;
      for (var i = 0; i < 20; i++) {
        await helper.forgetRound();
      }
      expect(await helper.forgetsLeft(), isTrue);
      engine.up = true;
      engine.live = [];
      for (var i = 0; i < 200 && await helper.forgetsLeft(); i++) {
        await helper.forgetRound();
      }
      expect(await helper.forgetsLeft(), isFalse);
    });

    test('a forget the relay holds newer for is done; one it refuses is '
        'given up after a few', () async {
      engine.live = [...contacts];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await rounds();
      await helper.stop();
      engine.dups = {for (final a in contacts) a.address};
      engine.refuse = {for (var s = 0; s < kHelperSlots; s++) 's$s'};
      var n = 0;
      while (await helper.forgetsLeft() && n < 500) {
        await helper.forgetRound();
        n++;
      }
      expect(await helper.forgetsLeft(), isFalse);
      expect(n, lessThan(contacts.length + kHelperSlots * kForgetTries + 1));
    });

    test('a stand-in forget the relay refuses is given up; one it holds '
        'newer for is done', () async {
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await rounds();
      // every slot gets an address: each stand-in is to be forgotten
      engine.live = [
        for (var i = 0; i < 16; i++) KnockAddress(steady('x$i'), 'room:r$i'),
        ...contacts,
      ];
      engine.refuse = {for (var s = 0; s < 8; s++) 's$s'};
      engine.dups = {for (var s = 8; s < kHelperSlots; s++) 's$s'};
      for (var i = 0; i < 200; i++) {
        await helper.sync();
      }
      final book = SlotBook.read(
        (await SharedPreferences.getInstance()).getString(kHelperSlotsKey),
      );
      for (final s in book.carrying) {
        expect(book.standIn[s], isNull, reason: 'slot $s');
      }
    });

    test('the hourly ask again holds across a restart', () async {
      engine.live = [...contacts];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      ntfy.endpoints.remove('kryfo-3.0');
      ntfy.answers = false;
      await helper.sync();
      final again = HelperDelivery(
        engine: engine,
        push: HelperPush(_ch),
        rnd: Random(2),
        nowMs: () => now,
      );
      await again.sync();
      expect(ntfy.events.where((e) => e == 'register kryfo-3.0').length, 2);
    });

    test('a helper app uninstalled is noticed', () async {
      expect(await helper.helperThere(), isNull);
      await helper.setUp(ntfy.package, wait: Duration.zero);
      expect(await helper.helperThere(), isTrue);
      ntfy.installed = false;
      expect(await helper.helperThere(), isFalse);
    });

    test('two syncs at once send once', () async {
      engine.live = [...contacts];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await Future.wait([helper.sync(), helper.sync()]);
      expect(engine.sent.length, 1);
    });
  });
}
