// SPDX-License-Identifier: GPL-3.0-or-later
// a first message's way out and its schedules: the onion's ack is no
// filing, so the first-contact copy goes beside it until they add us back;
// an opener with no receipt goes again a few times while the relays keep
// it; a kept one fits inside a stranger's shelf; the invite address is
// listened on again until an answer says ok, and a counter that does not
// read is read again rather than taken as 0
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/first_contact.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloEngine,
        readFcCounter,
        useDatabasesForTest,
        useEngineForTest;
import 'package:kryfo/session.dart';
import 'package:kryfo/wipe.dart' show wipeForget;
import 'package:kryfo/router.dart';
import 'package:kryfo/screens/settings_screen.dart' show reportCodes;
import 'package:kryfo/stranger_gate.dart' show kShelfBytes, kShelfPlaces;
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

// what each route was handed, in order
class _Wire {
  final went = <String>[];
  var onion = 'ok';
  var first = 'ok';
  var relay = 'ok';
  String? xPub = 'x-them';
  // the first-contact copy, when it is held back
  Completer<String>? firstWaits;
  var both = 0;
  final copies = <Future<void>>[];

  // the send, and the copy that goes behind its ok
  Future<String> sendAll({
    required bool backPaired,
    String? fc = 'fc-them',
  }) async {
    final r = await send(backPaired: backPaired, fc: fc);
    await Future.wait(copies);
    return r;
  }

  Future<String> send({
    required bool backPaired,
    String onionAt = 'o-them',
    String? fc = 'fc-them',
    String cipher = 'c1',
    bool pairRead = false,
  }) => routeText(
    pairRead: pairRead,
    bothWent: () => both++,
    copied: copies.add,
    backPaired: backPaired,
    onion: onionAt,
    viaOnion: () async {
      went.add('onion $cipher');
      return onion;
    },
    xPub: () async => xPub,
    fc: fc,
    viaFirst: (x, f) async {
      went.add('fc $x $f $cipher');
      return firstWaits?.future ?? first;
    },
    viaRelay: (x) async {
      went.add('relay $x $cipher');
      return relay;
    },
  );
}

class _Engine implements HaloEngine {
  final asked = <int>[];
  final answers = <String>[];
  var relays = 2;

  @override
  Future<String> subscribeFirstContact(int counter) async {
    asked.add(counter);
    return answers.isEmpty ? 'ok' : answers.removeAt(0);
  }

  @override
  int firstContactRelays() => relays;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('engine: ${i.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a text on its way', () {
    test('an onion ack still sends the first-contact copy of the same '
        'cipher', () async {
      final w = _Wire();
      expect(await w.sendAll(backPaired: false), 'ok');
      expect(w.went, ['onion c1', 'fc x-them fc-them c1']);
      expect(w.both, 1);
    });

    test('the ok does not wait on the copy', () async {
      final w = _Wire()..firstWaits = Completer<String>();
      expect(await w.send(backPaired: false), 'ok');
      expect(w.both, 0);
      w.firstWaits!.complete('ok');
      await Future.wait(w.copies);
      expect(w.both, 1);
    });

    test('a copy that does not go leaves the onion\'s ok, and says '
        'why', () async {
      firstFails.clear();
      final w = _Wire()..first = 'error: no relays accepted';
      expect(await w.sendAll(backPaired: false), 'ok');
      expect(w.went, ['onion c1', 'fc x-them fc-them c1']);
      expect(firstFails.codes, ['copy']);
      expect(w.both, 0);
    });

    test('once they added us back, the pair lane alone', () async {
      final w = _Wire();
      expect(await w.send(backPaired: true), 'ok');
      expect(w.went, ['relay x-them c1']);
    });

    test('a dead onion goes by the first-contact address', () async {
      final w = _Wire()..onion = 'error: timeout';
      expect(await w.send(backPaired: false), 'ok');
      expect(w.went, ['onion c1', 'fc x-them fc-them c1']);
      expect(w.copies, isEmpty);
    });

    test('a first-contact address that does not take it is not followed '
        'by the pair address', () async {
      final w = _Wire()
        ..onion = 'error: timeout'
        ..first = 'error: no relays accepted';
      expect(await w.send(backPaired: false), 'error: no relays accepted');
      expect(w.went, ['onion c1', 'fc x-them fc-them c1']);
    });

    test('with no first-contact address the pair address only parks '
        'it', () async {
      final w = _Wire()..onion = 'error: timeout';
      expect(await w.send(backPaired: false, fc: null), 'parked');
      expect(w.went, ['onion c1', 'relay x-them c1']);
      final quiet = _Wire();
      expect(await quiet.send(backPaired: false, fc: null), 'ok');
      expect(quiet.went, ['onion c1']);
    });

    test(
      'someone met on a card, with no first-contact address, is reached '
      'on the pair address: as the copy behind the onion\'s ok, or alone',
      () async {
        final w = _Wire();
        expect(await w.send(backPaired: false, fc: null, pairRead: true), 'ok');
        await Future.wait(w.copies);
        expect(w.went, ['onion c1', 'relay x-them c1']);
        final dead = _Wire()..onion = 'error: timeout';
        expect(
          await dead.send(backPaired: false, fc: null, pairRead: true),
          'ok',
        );
        expect(dead.went, ['onion c1', 'relay x-them c1']);
      },
    );

    test('no key and no onion is no transport', () async {
      final w = _Wire()..xPub = null;
      expect(
        await w.send(backPaired: false, onionAt: ''),
        'error: no transport',
      );
      expect(w.went, isEmpty);
    });
  });

  group('an opener with no receipt', () {
    const sent = 1000000;
    const min = 60000;
    test('goes again at ten minutes, an hour, six hours and a day, each '
        'from the last time it went', () {
      expect(openerAgainAt(sentAt: sent, tries: 0), sent + 10 * min);
      final at1 = sent + 12 * min;
      expect(
        openerAgainAt(sentAt: sent, lastAt: at1, tries: 1),
        at1 + 60 * min,
      );
      expect(
        openerAgainAt(sentAt: sent, lastAt: at1, tries: 2),
        at1 + 360 * min,
      );
      expect(
        openerAgainAt(sentAt: sent, lastAt: at1, tries: 3),
        at1 + 1440 * min,
      );
      expect(openerAgainAt(sentAt: sent, lastAt: at1, tries: 4), isNull);
    });

    test('never past the relays\' two weeks', () {
      final late = sent + const Duration(days: 13, hours: 12).inMilliseconds;
      expect(openerAgainAt(sentAt: sent, lastAt: late, tries: 3), isNull);
    });

    test('shows as sent and not delivered yet only before they add us '
        'back', () {
      bool w({
        bool out = true,
        bool sent = true,
        bool d = false,
        bool p = false,
      }) => waitsForReceipt(out: out, sent: sent, delivered: d, backPaired: p);
      expect(w(), isTrue);
      expect(w(d: true), isFalse);
      expect(w(p: true), isFalse);
      expect(w(sent: false), isFalse);
      expect(w(out: false), isFalse);
    });
  });

  group('a kept opener', () {
    test('fits inside a stranger shelf\'s limits', () {
      expect(kFirstKeptPerSender, kShelfPlaces);
      expect(kFirstKeptBytes, kShelfBytes);
      expect(
        firstKeepFits(rows: 0, mine: 0, bytes: 0, size: kShelfBytes),
        isTrue,
      );
      expect(
        firstKeepFits(rows: 0, mine: 0, bytes: 1, size: kShelfBytes),
        isFalse,
      );
      expect(
        firstKeepFits(rows: 3, mine: kShelfPlaces, bytes: 0, size: 1),
        isFalse,
      );
      expect(
        firstKeepFits(rows: kFirstKeptMost, mine: 0, bytes: 0, size: 1),
        isFalse,
      );
    });

    test('those from someone not named here share a few places, and never '
        'crowd out anyone named', () {
      bool fits(int mine, {required bool named}) =>
          firstKeepFits(rows: 30, mine: mine, bytes: 0, size: 1, named: named);
      expect(fits(kFirstKeptUnnamed - 1, named: false), isTrue);
      expect(fits(kFirstKeptUnnamed, named: false), isFalse);
      expect(fits(kFirstKeptUnnamed, named: true), isTrue);
      expect(kFirstKeptMost - kFirstKeptUnnamed, greaterThan(2 * kShelfPlaces));
    });

    test('is tried again later each time, six hours apart at most', () {
      expect(firstRetryGap(0), const Duration(minutes: 1));
      expect(firstRetryGap(3), const Duration(minutes: 8));
      expect(firstRetryGap(11), const Duration(hours: 6));
      expect(firstRetryGap(40), const Duration(hours: 6));
    });
  });

  group('what a report carries', () {
    test('codes and minutes only, newest first, the last dozen', () {
      final f = FirstFails();
      for (var i = 0; i < 14; i++) {
        f.note('decrypt', at: 0);
      }
      f.note('listen', at: 120000);
      expect(f.codes, hasLength(12));
      expect(f.summary(now: 180000).split(', ').first, 'listen 1m');
      firstFails
        ..clear()
        ..note('key');
      expect(
        reportCodes(),
        '&body=${Uri.encodeComponent('first contact: key 0m')}',
      );
      firstFails.clear();
      expect(reportCodes(), isEmpty);
    });
  });

  group('the invite address', () {
    late _Engine e;
    late AppState app;
    final read = readFcCounter;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({'fc_counter': '3'});
      e = _Engine();
      useEngineForTest(e);
      final router = VaultRouter(ArrivalStore(), ArrivalSeal());
      await router.load();
      app = AppState(io: ArrivalIo(), router: router);
    });

    tearDown(() => readFcCounter = read);

    testWidgets('a listen that fails is tried again, later each time, '
        'until it is ok', (tester) async {
      firstFails.clear();
      e.answers.addAll(['error: derive: no identity', 'error: derive']);
      await app.loadFirstContact();
      expect(e.asked, [3]);
      await tester.pump(const Duration(seconds: 4));
      expect(e.asked, [3]);
      await tester.pump(const Duration(seconds: 2));
      expect(e.asked, [3, 3]);
      await tester.pump(const Duration(seconds: 16));
      expect(e.asked, [3, 3, 3]);
      await tester.pump(const Duration(minutes: 10));
      expect(e.asked, [3, 3, 3]);
      expect(firstFails.codes, ['listen', 'listen']);
    });

    testWidgets('a counter that does not read is read again, and never '
        'taken as 0', (tester) async {
      var fails = 2;
      readFcCounter = () async {
        if (fails-- > 0) throw PlatformException(code: 'keystore');
        return '3';
      };
      await app.loadFirstContact();
      expect(e.asked, isEmpty);
      expect(app.fcCounter, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(e.asked, isEmpty);
      await tester.pump(const Duration(seconds: 10));
      expect(e.asked, [3]);
      expect(app.fcCounter, 3);
      await tester.pump(const Duration(minutes: 10));
      expect(e.asked, [3]);
    });

    testWidgets('a listener on no relay starts again; one on a relay is '
        'left alone', (tester) async {
      await app.loadFirstContact();
      expect(e.asked, [3]);
      app.checkFirstListener();
      expect(e.asked, [3]);
      e.relays = 0;
      app.checkFirstListener();
      expect(e.asked, [3, 3]);
      e.relays = -1;
      app.checkFirstListener();
      expect(e.asked, [3, 3, 3]);
    });

    testWidgets('a quiet session says nothing of first contacts, and starts '
        'nothing of theirs', (tester) async {
      await app.loadFirstContact();
      final everyday = ArrivalRows(HaloContainer.everyday);
      final decoy = ArrivalRows(HaloContainer.decoy);
      useDatabasesForTest(everyday, Session(decoy));
      addTearDown(() => useDatabasesForTest(everyday, Session(everyday)));
      final kept = (
        hash: 'h1',
        cipher: 'c1',
        peer: '',
        at: DateTime.now().millisecondsSinceEpoch,
        tries: 0,
        nextAt: 0,
        reached: null,
      );
      everyday.kept['h1'] = kept;
      firstFails
        ..clear()
        ..note('decrypt');
      expect(reportCodes(), isEmpty);
      e.relays = 0;
      app.checkFirstListener();
      await app.retryFirsts(all: true);
      expect(e.asked, [3]);
      expect(everyday.kept['h1'], kept);
      expect(everyday.calls, isEmpty);
    });

    test('a session change leaves no reasons behind', () {
      firstFails.note('decrypt');
      wipeForget();
      expect(firstFails.codes, isEmpty);
    });
  });
}
