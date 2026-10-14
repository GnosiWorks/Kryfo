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
  // ids the engine can still sign a forget for
  Set<String> seen = {};
  String check = 'yes';
  int checks = 0;
  String lastExclude = '';
  final List<List<Map<String, dynamic>>> sent = [];
  final Map<String, String> relay = {};
  final Map<String, int> made = {};
  bool up = true;
  Set<String> dups = {};

  @override
  Future<String> knockAddresses(String excludeJson) async {
    lastExclude = excludeJson;
    seen.addAll(live.map((a) => a.address));
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
    final items = [
      for (final i in jsonDecode(itemsJson) as List) i as Map<String, dynamic>,
    ];
    sent.add(items);
    final done = <String>[];
    final dup = <String>[];
    final known = {for (final a in live) a.address};
    for (final i in items) {
      final name = i['i'] as String? ?? 's${i['s']}';
      final key = i['i'] as String? ?? i['k'] as String;
      final forget = (i['e'] as String).isEmpty;
      if (i['i'] != null && !(forget ? seen : known).contains(i['i'])) {
        continue;
      }
      if (dups.remove(name)) {
        dup.add(name);
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
    return jsonEncode({'done': done, 'dup': dup});
  }
}

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
      for (var i = 0; i < 6; i++) KnockAddress('c$i', 'everyday:${i % 4}'),
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
      engine.live = [...engine.live, const KnockAddress('c9', 'room:bb')];
      await helper.sync();
      expect(engine.sent.last.any((i) => i['i'] == 'c9'), isTrue);
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
      ).slotOf('c0')!;
      ntfy.endpoints['kryfo-$s.0'] = 'https://push.example.org/upNew';
      await rounds();
      final again = engine.sent.last.where((i) => i['i'] == 'c0').single;
      expect(again['t'] as int, greaterThan(nowS));
    });

    test('the hidden chats\' peers go to the engine to be left out', () async {
      hidden = ['peer-h'];
      engine.live = [...contacts];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await helper.sync();
      expect(jsonDecode(engine.lastExclude), ['peer-h']);
    });

    test('the relay says not newer: tried again later, newer', () async {
      engine.live = [contacts.first];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      engine.dups = {'c0'};
      await rounds();
      expect(engine.relay.containsKey('c0'), isFalse);
      final firstT =
          engine.sent.expand((b) => b).where((i) => i['i'] == 'c0').single['t']
              as int;
      now += kDupRetryMs ~/ 2;
      await rounds();
      expect(engine.relay.containsKey('c0'), isFalse);
      now += kDupRetryMs;
      await rounds();
      expect(engine.relay.containsKey('c0'), isTrue);
      expect(engine.made['c0']!, greaterThan(firstT));
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
      // and the room's own registration is forgotten
      expect(engine.relay.containsKey('r1'), isFalse);
    });

    test('leaving the mode: the helper app lets go at once, the relay '
        'forgets one round at a time, at times of their own', () async {
      engine.live = [...contacts, fc];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await rounds();
      final before = Set.of(ntfy.endpoints.values);
      final held = engine.relay.length;
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
      final ts = {for (final b in forgets) b.single['t'] as int};
      expect(ts.length, greaterThan(held ~/ 2));
      await helper.setUp(ntfy.package, wait: Duration.zero);
      expect(before.intersection(Set.of(ntfy.endpoints.values)), isEmpty);
    });

    test('a phone moving away forgets everything at once', () async {
      engine.live = [...contacts];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await rounds();
      await helper.stop();
      await helper.forgetRound(all: true);
      expect(engine.relay, isEmpty);
      expect(await helper.forgetsLeft(), isFalse);
    });

    test('a forget the engine cannot sign is given up after a few', () async {
      engine.live = [...contacts];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await rounds();
      await helper.stop();
      engine.seen = {};
      for (var i = 0; i < 100 && await helper.forgetsLeft(); i++) {
        await helper.forgetRound();
      }
      expect(await helper.forgetsLeft(), isFalse);
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
