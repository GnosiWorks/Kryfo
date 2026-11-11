// SPDX-License-Identifier: GPL-3.0-or-later
// check my connection: only codes and counts go in the report, the ways
// that failed are kept from the engine's own steps, and the sheet shows
// and copies the very same words
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/bridge_mode.dart';
import 'package:kryfo/conn_check.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show AppState, AppStateBridges, AppStateRoute, HaloEngine, useEngineForTest;
import 'package:kryfo/screens/conn_check_sheet.dart';
import 'package:kryfo/screens/dev_about_sheet.dart'
    show devChatOffered, devChatPageForTest;

import 'dev_chat_fakes.dart' show devOpen, devClose, devWorld;
import 'package:kryfo/widgets/motion.dart' show TorStatus;

class _Engine implements HaloEngine {
  @override
  Map<String, dynamic> transportState() => const {};
  @override
  void networkChanged({bool online = true}) {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

BridgeStatus _st(String json) => BridgeStatus.parse(json);

// everything an engine could ever put in its fields that must never go out
const _secrets = [
  '203.0.113.7',
  'obfs4 192.0.2.1:443',
  'cert=AAAA',
  'abcdefghijklmnopqrstuvwxyz234567abcdefghijklmnopqrstuvwx.onion',
  'nos.lol',
];

String _report({
  String bridge = '',
  Map<String, dynamic> tx = const {},
  ConnTrail? trail,
  String mode = 'private',
  TorStatus tor = TorStatus.reachable,
  bool decoy = false,
}) => connReport(
  now: DateTime.utc(2026, 11, 11, 23, 59),
  version: '0.6.1',
  platform: 'android',
  sendMode: mode,
  tor: tor,
  pct: 40,
  canSend: true,
  online: true,
  bridgeRaw: bridge,
  tx: tx,
  trail: trail ?? ConnTrail(),
  decoy: decoy,
);

void main() {
  group('codes', () {
    test('only short plain codes pass, anything else is other', () {
      expect(codeOf('obfs4'), 'obfs4');
      expect(codeOf('no_internet'), 'no_internet');
      expect(codeOf(''), '-');
      for (final s in _secrets) {
        expect(codeOf(s), 'other', reason: s);
      }
    });

    test('a connect time goes in wide steps', () {
      expect(bootBucket(null), 'not yet');
      expect(bootBucket(const Duration(seconds: 4)), 'under 10 s');
      expect(bootBucket(const Duration(seconds: 29)), '10 to 30 s');
      expect(bootBucket(const Duration(seconds: 45)), '30 s to 1 min');
      expect(bootBucket(const Duration(seconds: 61)), '1 to 2 min');
      expect(bootBucket(const Duration(minutes: 4)), '2 to 5 min');
      expect(bootBucket(const Duration(minutes: 14)), '5 to 15 min');
      expect(bootBucket(const Duration(hours: 1)), 'over 15 min');
    });
  });

  group('trail', () {
    test('a way left before it connected failed, with its code', () {
      final t = ConnTrail();
      t.noteBridge(
        _st(
          '{"mode":"auto","phase":"trying","method":"direct",'
          '"error_code":"timeout"}',
        ),
        _st('{"mode":"auto","phase":"trying","method":"obfs4"}'),
      );
      t.noteBridge(
        _st('{"mode":"auto","phase":"trying","method":"obfs4"}'),
        _st('{"mode":"auto","phase":"trying","method":"snowflake"}'),
      );
      t.noteBridge(
        _st('{"mode":"auto","phase":"trying","method":"snowflake"}'),
        _st('{"mode":"auto","phase":"connected","method":"snowflake"}'),
      );
      expect(t.steps, [
        (method: 'direct', why: 'timeout'),
        (method: 'obfs4', why: 'no_answer'),
      ]);
    });

    test('a connected way that moves on is no failure', () {
      final t = ConnTrail();
      t.noteBridge(
        _st('{"mode":"auto","phase":"connected","method":"direct"}'),
        _st('{"mode":"auto","phase":"trying","method":"obfs4"}'),
      );
      expect(t.steps, isEmpty);
    });

    test('giving up counts, repeats fold, the oldest go', () {
      final t = ConnTrail();
      final trying = _st('{"mode":"auto","phase":"trying","method":"meek"}');
      final gone = _st(
        '{"mode":"auto","phase":"exhausted","method":"meek",'
        '"error_code":"blocked"}',
      );
      t.noteBridge(trying, gone);
      t.noteBridge(gone, trying);
      t.noteBridge(trying, gone);
      expect(t.steps, [(method: 'meek', why: 'blocked')]);
      for (var i = 0; i < 20; i++) {
        t.noteBridge(
          _st('{"phase":"trying","method":"m$i"}'),
          _st('{"phase":"trying","method":"n$i"}'),
        );
      }
      expect(t.steps.length, ConnTrail.kMostSteps);
      expect(t.steps.last.method, 'm19');
    });

    test('a method that is no code goes as other', () {
      final t = ConnTrail();
      t.noteBridge(
        _st('{"phase":"trying","method":"obfs4 192.0.2.1:443 cert=x"}'),
        _st('{"phase":"trying","method":"snowflake"}'),
      );
      expect(t.steps.single.method, 'other');
    });

    test('a connect is timed from the first try to ready', () {
      final t = ConnTrail();
      final t0 = DateTime(2026, 11, 11, 10);
      t.tryStarted(t0);
      t.tryStarted(t0.add(const Duration(seconds: 20)));
      t.ready(t0.add(const Duration(seconds: 50)));
      expect(t.lastBoot, const Duration(seconds: 50));
      // ready again without a try keeps the last one
      t.ready(t0.add(const Duration(minutes: 9)));
      expect(t.lastBoot, const Duration(seconds: 50));
    });

    test('the app feeds the trail from the engine\'s status and tor', () {
      useEngineForTest(_Engine());
      connTrail.clear();
      final app = AppState()
        ..sendModeForTest = 'private'
        ..bridgeSetupForTest = const BridgeSetup();
      final t0 = DateTime(2026, 11, 11, 10);
      app.takeTorStatus('starting|5|0|0|0', now: t0);
      app.takeBridgeStatus(
        '{"mode":"auto","phase":"trying","method":"direct",'
        '"error_code":"timeout"}',
      );
      app.takeBridgeStatus(
        '{"mode":"auto","phase":"trying","method":"snowflake"}',
      );
      app.takeTorStatus(
        'reachable|100|0|1|0',
        now: t0.add(const Duration(seconds: 75)),
      );
      expect(connTrail.steps, [(method: 'direct', why: 'timeout')]);
      expect(bootBucket(connTrail.lastBoot), '1 to 2 min');
      connTrail.clear();
    });
  });

  group('report', () {
    test('says the route, the steps and the counts, and nothing else', () {
      final t = ConnTrail()
        ..noteBridge(
          _st('{"phase":"trying","method":"direct","error_code":"timeout"}'),
          _st('{"phase":"trying","method":"snowflake"}'),
        )
        ..tryStarted(DateTime(2026))
        ..ready(DateTime(2026).add(const Duration(seconds: 40)));
      final r = _report(
        bridge:
            '{"mode":"auto","phase":"connected","method":"snowflake",'
            '"source":"builtin","network":"ok","vpn":false,'
            '"last_ok_method":"snowflake"}',
        tx: {
          'relays': [
            {'url': 'wss://nos.lol', 'fails': 0},
            {'url': 'wss://relay.example', 'fails': 2},
            {'url': 'wss://x.onion', 'benched': true, 'bench_for_s': 60},
          ],
          'bounce_counts': {'network': 3, 'stall': 1},
          'published_once': true,
        },
        trail: t,
      );
      expect(r, '''Kryfo connection check
Date: 2026-11-11
App: 0.6.1, android
Route: Tor
Internet: ok, VPN no
Tor: reachable
Connect took: 30 s to 1 min
Can send: yes
Bridges: auto, phase connected
Way in now: snowflake
Did not get through: direct (timeout)
Error now: -
Worked before: snowflake
Relays: 1 ok, 1 failing, 1 resting
Reconnects: 4 (network 3, stall 1)
Address published: yes''');
    });

    test('nothing an engine field holds beyond a code gets out', () {
      final bad = _secrets.first;
      final r = _report(
        bridge:
            '{"mode":"$bad","phase":"${_secrets[1]}","method":"${_secrets[2]}",'
            '"error_code":"${_secrets[3]}","network":"Berlin",'
            '"snowflake":"${_secrets[4]}","last_ok_method":"${_secrets[1]}",'
            '"lines":["${_secrets[1]}"],"ip":"$bad"}',
        tx: {
          'relays': [
            {'url': 'wss://${_secrets[4]}', 'fails': 0},
            {'url': 'ws://${_secrets[3]}', 'fails': 0},
          ],
          'bounce_counts': {_secrets[0]: 2},
          'onion': _secrets[3],
        },
      );
      for (final s in [..._secrets, 'Berlin', 'berlin']) {
        expect(r, isNot(contains(s)), reason: s);
      }
      expect(r, contains('Bridges: other, phase other'));
      expect(r, contains('Internet: -, VPN no'));
    });

    test('a decoy says automatic and the phase, no ways', () {
      final t = ConnTrail()
        ..noteBridge(
          _st('{"phase":"trying","method":"direct"}'),
          _st('{"phase":"trying","method":"obfs4"}'),
        );
      final r = _report(
        bridge: '{"mode":"own","phase":"trying","method":"obfs4"}',
        trail: t,
        decoy: true,
      );
      expect(r, contains('Bridges: auto, phase trying'));
      expect(r, isNot(contains('obfs4')));
      expect(r, isNot(contains('direct')));
      expect(r, isNot(contains('Did not get through')));
    });

    test('fast has no tor lines', () {
      final r = _report(mode: 'balanced', bridge: '{"mode":"auto"}');
      expect(r, contains('Route: Fast'));
      expect(r, isNot(contains('Tor:')));
      expect(r, isNot(contains('Bridges:')));
      expect(r, isNot(contains('Connect took')));
    });

    test('a starting tor says how far', () {
      expect(_report(tor: TorStatus.starting), contains('Tor: starting, 40%'));
    });
  });

  group('sheet', () {
    testWidgets('shows the report word for word and copies the same', (
      t,
    ) async {
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      var round = 0;
      String report() => 'Kryfo connection check\nRound: ${++round}';
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => showConnCheck(c, report: report),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.text(l10n.connCheckTitle), findsOneWidget);
      expect(find.text(l10n.connCheckLine), findsOneWidget);
      expect(find.text('Kryfo connection check\nRound: 1'), findsOneWidget);
      // the developer chat only where the settings row offers it
      expect(
        find.text(l10n.connCheckSend),
        devChatOffered ? findsOneWidget : findsNothing,
      );

      await t.tap(find.text(l10n.commonCopy));
      await t.pump();
      expect(copied, 'Kryfo connection check\nRound: 1');

      await t.tap(find.text(l10n.connCheckAgain));
      await t.pumpAndSettle();
      expect(find.text('Kryfo connection check\nRound: 2'), findsOneWidget);
      await t.tap(find.text(l10n.commonCopy));
      await t.pump();
      expect(copied, 'Kryfo connection check\nRound: 2');
      await t.pump(const Duration(seconds: 5));
    });
  });

  testWidgets('send to Marios opens his chat with the report, unsent', (
    t,
  ) async {
    await devWorld();
    expect(devChatOffered, isTrue);
    String? opened;
    devChatPageForTest = (id, words) {
      opened = words;
      return const Scaffold(body: Text('dev chat'));
    };
    addTearDown(() => devChatPageForTest = null);
    await devOpen(
      t,
      Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () => showConnCheck(c, report: () => 'Kryfo check'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text(l10n.connCheckSend));
    await t.pumpAndSettle();
    expect(find.text('dev chat'), findsOneWidget);
    expect(opened, 'Kryfo check');
    await devClose(t);
  });
}
