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
  var _n = 0;
  bool installed = true;
  bool answers = true;
  String? chosen;
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
        if (answers) {
          endpoints[a['instance'] as String] =
              'https://push.example.org/up${_n++}?up=1';
        }
        return true;
      case 'helperUnregisterOne':
        dropped.add(a['instance'] as String);
        endpoints.remove(a['instance']);
        return true;
      case 'helperUnregister':
        dropped.addAll(endpoints.keys);
        endpoints.clear();
        chosen = null;
        return true;
    }
    return null;
  }
}

// our relay as the engine reaches it: what it holds per address or stand-in
// key, and what it was asked
class FakeEngine implements KnockEngine {
  List<KnockAddress> live = [];
  String check = 'yes';
  int checks = 0;
  final List<List<Map<String, dynamic>>> sent = [];
  final Map<String, String> relay = {};
  bool up = true;

  @override
  Future<String> knockAddresses() async => jsonEncode([
    for (final a in live) {'a': a.address, 'g': a.group},
  ]);

  @override
  Future<String> knockCheck() async {
    checks++;
    return check;
  }

  @override
  Future<String> knockRegister(String itemsJson) async {
    if (!up) return 'error: only over tor';
    final items = [
      for (final i in jsonDecode(itemsJson) as List) i as Map<String, dynamic>,
    ];
    sent.add(items);
    final done = <String>[];
    final known = {for (final a in live) a.address};
    for (final i in items) {
      final name = i['a'] as String? ?? 's${i['s']}';
      final key = i['a'] as String? ?? i['k'] as String;
      if (i['a'] != null && !known.contains(i['a'])) continue;
      if ((i['e'] as String).isEmpty) {
        relay.remove(key);
      } else {
        relay[key] = i['e'] as String;
      }
      done.add(name);
    }
    return jsonEncode({'done': done});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeDistributor ntfy;
  late FakeEngine engine;
  late HelperDelivery helper;
  var now = 1800000000000;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ntfy = FakeDistributor('io.heckel.ntfy');
    engine = FakeEngine();
    now = 1800000000000;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ch, ntfy.handle);
    helper = HelperDelivery(
      engine: engine,
      push: HelperPush(_ch),
      rnd: Random(1),
      nowMs: () => now,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ch, null);
  });

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
    const fc = KnockAddress('fc', 'firstcontact:fc');

    test('sixteen endpoints, every address and stand-in registered once, '
        'no endpoint shared across groups', () async {
      engine.live = [...contacts, fc];
      expect(await helper.setUp(ntfy.package, wait: Duration.zero), isTrue);
      expect(ntfy.endpoints.length, kHelperSlots);
      final took = await helper.sync();
      expect(took, kHelperSlots);
      expect(engine.relay.length, kHelperSlots);
      // every endpoint carries one group at most
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
      expect(await helper.sync(), 0);
      expect(engine.sent.length, 1);
      // a new contact: only that, and the stand-in on its slot forgotten
      engine.live = [...engine.live, const KnockAddress('c9', 'everyday:3')];
      await helper.sync();
      final last = engine.sent.last;
      expect(last.where((i) => i['a'] == 'c9').length, 1);
      expect(last.where((i) => i['e'] == '').length, 1);
      expect(last.length, 2);
      expect(engine.relay.length, kHelperSlots);
      // five days on, everything again
      now += kRefreshMs;
      expect(await helper.sync(), kHelperSlots);
    });

    test('a batch is not signed in one second, and a resend is always '
        'later than the one before', () async {
      engine.live = [...contacts, fc];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await helper.sync();
      final first = engine.sent.single;
      final ts = [for (final i in first) i['t'] as int];
      final nowS = now ~/ 1000;
      expect(ts.every((t) => t <= nowS && t >= nowS - kSignedJitterS), isTrue);
      expect(ts.toSet().length, greaterThan(ts.length ~/ 2));
      // a minute later the helper app hands out a new endpoint for one
      // slot: its registration is newer than the last, whatever the jitter
      now += 60 * 1000;
      final s = SlotBook.read(
        (await SharedPreferences.getInstance()).getString(kHelperSlotsKey),
      ).slotOf('c0')!;
      ntfy.endpoints['kryfo-$s.0'] = 'https://push.example.org/upNew';
      await helper.sync();
      final again = engine.sent.last.where((i) => i['a'] == 'c0').single;
      expect(again['t'] as int, greaterThan(nowS));
    });

    test('a helper app that gives no endpoint fails the set-up', () async {
      ntfy.answers = false;
      expect(await helper.setUp(ntfy.package, wait: Duration.zero), isFalse);
    });

    test('off tor nothing is marked sent, and it goes later', () async {
      engine.live = [...contacts];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      engine.up = false;
      expect(await helper.sync(), 0);
      engine.up = true;
      expect(await helper.sync(), kHelperSlots);
    });

    test('a room that ends: its slot is let go and comes back on a new '
        'endpoint', () async {
      engine.live = [...contacts, const KnockAddress('r1', 'room:a')];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await helper.sync();
      final roomEndpoint = engine.relay['r1'];
      engine.live = [...contacts];
      await helper.sync();
      expect(ntfy.dropped, hasLength(1));
      expect(ntfy.endpoints.length, kHelperSlots);
      expect(ntfy.endpoints.values, isNot(contains(roomEndpoint)));
      // the slot's new endpoint carries a stand-in at once
      final fresh = ntfy.endpoints.entries
          .where((e) => e.key.endsWith('.1'))
          .single
          .value;
      expect(engine.relay.values, contains(fresh));
    });

    test('leaving the mode: the relay forgets, the helper app lets go, and '
        'the next set-up is on new endpoints', () async {
      engine.live = [...contacts, fc];
      await helper.setUp(ntfy.package, wait: Duration.zero);
      await helper.sync();
      final before = Set.of(ntfy.endpoints.values);
      await helper.stop();
      expect(engine.relay, isEmpty);
      expect(ntfy.endpoints, isEmpty);
      await helper.setUp(ntfy.package, wait: Duration.zero);
      expect(before.intersection(Set.of(ntfy.endpoints.values)), isEmpty);
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
