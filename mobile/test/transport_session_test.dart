// SPDX-License-Identifier: GPL-3.0-or-later
// the transport screen shows the session's own traffic. a decoy shows what
// a new install would: no subscriptions, nothing sent or received, no
// message in and no night's record of the everyday side. with hidden chats
// shut, their subscriptions are not counted and an arrival sealed for them
// moves no time; with them open, everything counts
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/delivery_mode.dart' show kLastCheckRelaysKey;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show AppState, HaloEngine, useDatabasesForTest, useEngineForTest;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/screens/transport_screen.dart';
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';
import 'dev_chat_fakes.dart';

const _h = 'hidden-wreck-tone';
const _v = 'visible-plain-row';

// the everyday identity's engine, busy with its contacts
class _Engine implements HaloEngine {
  @override
  Map<String, dynamic> transportState() => {
    'relays': [
      {'url': 'wss://relay.example', 'fails': 0},
    ],
    'sub_count': 37,
    'secs_since_recv': 4,
    'secs_since_send': 9,
    'hsdir_uploads': 3,
    'publishing_secs': 600,
  };
  @override
  Map<String, dynamic> memStats() => {
    'lastEvRecv': DateTime.now().millisecondsSinceEpoch ~/ 1000 - 30,
  };
  @override
  String lastReconnect() => '';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// the value on the line that [label] names
String _valueOf(WidgetTester t, String label) {
  final row = find
      .ancestor(of: find.text(label), matching: find.byType(Row))
      .first;
  return t
      .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
      .map((x) => x.data ?? '')
      .firstWhere((s) => s != label);
}

// a phone with a vault: the hidden chat with H on the router's list, and a
// visible contact V
class _World {
  final live = ArrivalRows(HaloContainer.everyday);
  final vault = ArrivalRows(HaloContainer.vault);
  final store = ArrivalStore();
  final io = ArrivalIo();
  late AppState app;
  var _n = 0;

  static Future<_World> make() async {
    final w = _World();
    w.live.person(_v, onion: 'o-$_v', xpub: 'x-$_v');
    w.vault.person(_h, onion: 'o-$_h', xpub: 'x-$_h');
    await w.store.putHidden(
      _h,
      kHiddenPeer,
      peerCard(RouterCard(_h, 'o-$_h', 'x-$_h', backPaired: true)),
      1,
    );
    await w.store.putMeta('pub', 'pub-A');
    final router = VaultRouter(w.store, ArrivalSeal());
    await router.load();
    w.app = AppState(io: w.io, router: router)..myId = 'me';
    useDatabasesForTest(w.live, Session(w.live));
    return w;
  }

  Future<void> from(String who, String plain) async {
    final c = 'c${_n++}';
    io.opens[c] = (who, plain);
    await app.receiveOnion([c]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory docs;

  setUpAll(() {
    docs = Directory.systemTemp.createTempSync('transport_session');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
  });

  tearDownAll(() => docs.deleteSync(recursive: true));

  void everydayRecord() {
    final now = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      // what the everyday side's heartbeat and check-ins left
      'hb.drain': now - 3 * 60000,
      'hb.listen': now - 5000,
      'hb.jobs': 41,
      'hb.jobAt': now - 600000,
      kLastCheckRelaysKey: '[{"host":"relay.example","ms":900}]',
    });
    FlutterSecureStorage.setMockInitialValues({});
  }

  testWidgets('a decoy shows the traffic of a new install', (t) async {
    everydayRecord();
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('halo/platform'),
      (_) async => null,
    );
    useEngineForTest(_Engine());
    await devWorld(container: HaloContainer.decoy);
    await devOpen(t, const TransportScreen(), size: const Size(1000, 12000));
    await t.pump(const Duration(seconds: 1));
    expect(
      {
        for (final l in [
          l10n.transportRelaySubscriptions,
          l10n.transportLastSent,
          l10n.transportLastReceived,
          l10n.transportLastMessageIn,
          l10n.transportLastRelayArrival,
          l10n.transportCatchUpByRelay,
          l10n.transportJobRuns,
        ])
          l: _valueOf(t, l),
      },
      {
        l10n.transportRelaySubscriptions: '0',
        l10n.transportLastSent: l10n.transportNever,
        l10n.transportLastReceived: l10n.transportNever,
        l10n.transportLastMessageIn: l10n.transportNever,
        l10n.transportLastRelayArrival: l10n.transportNothingYetThisProcess,
        l10n.transportCatchUpByRelay: l10n.transportNoneYet,
        l10n.transportJobRuns: l10n.transportNoneYet,
      },
    );
    await devClose(t);
  });

  testWidgets('the everyday session shows the engine\'s traffic', (t) async {
    everydayRecord();
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('halo/platform'),
      (_) async => null,
    );
    useEngineForTest(_Engine());
    await devWorld();
    await devOpen(t, const TransportScreen(), size: const Size(1000, 12000));
    await t.pump(const Duration(seconds: 1));
    expect(_valueOf(t, l10n.transportRelaySubscriptions), '37');
    expect(_valueOf(t, l10n.transportJobRuns), contains('41'));
    expect(
      _valueOf(t, l10n.transportLastMessageIn),
      isNot(l10n.transportNever),
    );
    await devClose(t);
  });

  group('with hidden chats shut', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('their subscriptions are not counted', () async {
      final w = await _World.make();
      final tx = <String, dynamic>{
        'sub_count': 3,
        'subs': ['x-$_v', 'x-$_h', 'x-other'],
        'secs_since_recv': 5,
        'secs_since_send': 6,
      };
      expect(w.app.shownTraffic(tx).subs, 2);
      expect(w.app.shownTraffic({...tx}..remove('subs')).subs, 2);
      // open, they are the session's own
      useDatabasesForTest(w.live, await Session.withVault(w.live, w.vault));
      expect(w.app.shownTraffic(tx).subs, 3);
    });

    test('an arrival sealed for them moves no time', () async {
      final w = await _World.make();
      await w.from(
        _h,
        await wrapMessage('sealed', msgUid: 'h1', sender: asSender(_h)),
      );
      expect(w.store.inbox, hasLength(1));
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      const tx = <String, dynamic>{'sub_count': 1, 'secs_since_recv': 0};
      expect(w.app.shownTraffic(tx).secsSinceRecv, -1);
      expect(w.app.shownRelayIn({'lastEvRecv': now}), 0);
      // one the everyday side shows moves them again
      await w.from(
        _v,
        await wrapMessage('hi', msgUid: 'v1', sender: asSender(_v)),
      );
      expect(w.app.shownTraffic(tx).secsSinceRecv, 0);
      expect(w.app.shownRelayIn({'lastEvRecv': now + 1}), now + 1);
    });
  });
}
