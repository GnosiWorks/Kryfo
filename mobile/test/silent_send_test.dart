// SPDX-License-Identifier: GPL-3.0-or-later
// hold send for silent send: the flag rides the encrypted envelope and its
// retries, an envelope from an older app (no flag) rings, the arrival posts
// a silent one quietly. the held button lifts its card; letting go on the
// row or a tap on it sends quietly, a tap elsewhere puts it away, nothing to
// send gives no card
import 'dart:io';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/lock_state.dart' show lockState;
import 'package:kryfo/main.dart'
    show AppState, releaseChat, useDatabasesForTest, AppStateReceive;
import 'package:kryfo/message_envelope.dart';
import 'package:kryfo/outbox.dart' show wrapRedelivery;
import 'package:kryfo/router.dart';
import 'package:kryfo/session.dart';
import 'package:kryfo/theme.dart';
import 'package:kryfo/widgets/send_hold.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _x = 'quiet-fern-stone';
const _me = SenderInfo(haloId: 'me', edPub: 'e', onion: 'o', xPub: 'x');

void main() {
  group('the wire', () {
    test('the flag goes and comes back', () async {
      final w = await wrapMessage('hi', msgUid: 'u1', silent: true);
      expect(w, contains('"$kSilentWire":1'));
      expect(unwrapMessage(w).silent, isTrue);
      final loud = await wrapMessage('hi', msgUid: 'u2');
      expect(loud, isNot(contains('"$kSilentWire"')));
      expect(unwrapMessage(loud).silent, isFalse);
    });

    test('an envelope from an older app has no flag and rings', () {
      final old = '$kEnvelopePrefix{"m":"hi","u":"u3","w":1}';
      expect(unwrapMessage(old).silent, isFalse);
    });

    test('a retry from the outbox keeps it', () async {
      Map<String, Object?> row(int silent) => {
        'plaintext': 'hi',
        'msg_uid': 'u4',
        'sent_at': 5,
        'silent': silent,
      };
      expect(
        unwrapMessage(await wrapRedelivery(row(1), sender: _me)).silent,
        isTrue,
      );
      expect(
        unwrapMessage(await wrapRedelivery(row(0), sender: _me)).silent,
        isFalse,
      );
      // a row from before the column rings
      expect(
        unwrapMessage(
          await wrapRedelivery({...row(0)}..remove('silent'), sender: _me),
        ).silent,
        isFalse,
      );
    });
  });

  group('the arrival', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    late Directory docs;
    late ArrivalIo io;
    late AppState app;
    var n = 0;

    setUp(() async {
      docs = Directory.systemTemp.createTempSync('silent_send');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => docs.path,
          );
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      lockState.openForTest();
      final live = ArrivalRows(HaloContainer.everyday)
        ..person(_x, onion: 'o-$_x', xpub: 'x-$_x');
      io = ArrivalIo();
      final router = VaultRouter(ArrivalStore(), ArrivalSeal());
      await router.load();
      app = AppState(io: io, router: router)..myId = 'me';
      useDatabasesForTest(live, Session(live));
    });

    tearDown(() {
      releaseChat(_x);
      docs.deleteSync(recursive: true);
    });

    Future<void> text(String uid, {bool silent = false}) async {
      final c = 'c${n++}';
      io.opens[c] = (
        _x,
        await wrapMessage(
          'psst',
          msgUid: uid,
          silent: silent,
          sender: asSender(_x),
        ),
      );
      await app.receiveOnion([c]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    test('one sent without sound is posted quietly, still in the '
        'shade', () async {
      await text('m1', silent: true);
      await text('m2');
      expect(io.rang, [_x, _x]);
      expect(io.silents, [true, false]);
    });
  });

  group('the held button', () {
    Widget app({VoidCallback? onSilent, bool still = false}) => MaterialApp(
      theme: buildHaloTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (ctx, c) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(disableAnimations: still),
        child: c!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SendHold(
              onSilent: onSilent,
              child: const SizedBox(
                key: ValueKey('send'),
                width: 40,
                height: 40,
                child: ColoredBox(color: Colors.amber),
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('held, the card lifts; a tap on the row sends quietly', (
      t,
    ) async {
      var quiet = 0;
      await t.pumpWidget(app(onSilent: () => quiet++));
      await t.longPress(find.byKey(const ValueKey('send')));
      await t.pumpAndSettle();
      expect(find.text(l10n.composerSendSilent), findsOneWidget);
      // the card sits over the button
      expect(
        t.getRect(find.text(l10n.composerSendSilent)).bottom,
        lessThan(t.getRect(find.byKey(const ValueKey('send'))).top),
      );
      await t.tap(find.text(l10n.composerSendSilent));
      await t.pumpAndSettle();
      expect(quiet, 1);
      expect(find.text(l10n.composerSendSilent), findsNothing);
    });

    testWidgets('letting go on the row sends quietly', (t) async {
      var quiet = 0;
      await t.pumpWidget(app(onSilent: () => quiet++));
      final g = await t.startGesture(
        t.getCenter(find.byKey(const ValueKey('send'))),
      );
      await t.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await t.pumpAndSettle();
      await g.moveTo(t.getCenter(find.text(l10n.composerSendSilent)));
      await t.pump();
      await g.up();
      await t.pumpAndSettle();
      expect(quiet, 1);
      expect(find.text(l10n.composerSendSilent), findsNothing);
    });

    testWidgets('a tap elsewhere puts it away; nothing to send, no card', (
      t,
    ) async {
      var quiet = 0;
      await t.pumpWidget(app(onSilent: () => quiet++));
      await t.longPress(find.byKey(const ValueKey('send')));
      await t.pumpAndSettle();
      await t.tapAt(const Offset(20, 20));
      await t.pumpAndSettle();
      expect(find.text(l10n.composerSendSilent), findsNothing);
      expect(quiet, 0);
      await t.pumpWidget(app());
      await t.longPress(find.byKey(const ValueKey('send')));
      await t.pumpAndSettle();
      expect(find.text(l10n.composerSendSilent), findsNothing);
    });

    testWidgets('a screen reader hears the hint and can open it', (t) async {
      final sem = t.ensureSemantics();
      await t.pumpWidget(app(onSilent: () {}));
      final node = t.getSemantics(find.byType(SendHold));
      expect(node.getSemanticsData().customSemanticsActionIds, isNotNull);
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.longPress),
        isTrue,
      );
      sem.dispose();
    });

    testWidgets('reduced motion: the card only fades in', (t) async {
      await t.pumpWidget(app(onSilent: () {}, still: true));
      await t.longPress(find.byKey(const ValueKey('send')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 40));
      final card = find.text(l10n.composerSendSilent);
      final y = t.getTopLeft(card).dy;
      await t.pumpAndSettle();
      expect(t.getTopLeft(card).dy, y);
    });
  });
}
