// SPDX-License-Identifier: GPL-3.0-or-later
// the registry's yes is kept even when the handle page is gone before it
// arrives: a handle let go is forgotten, so the next check does not claim
// it again, and a handle taken is remembered, so it can be let go later.
import 'dart:async';

import 'package:flutter/material.dart' hide Curve;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/handle_repoint.dart' show kHandleClaimedKey;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show HaloEngine, appState, useEngineForTest;
import 'package:kryfo/screens/handle_screen.dart';
import 'package:kryfo/secure_store.dart';
import 'package:kryfo/signal_session.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart'
    show Curve;
import 'package:kryfo/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dev_chat_fakes.dart' show devWorld;
import 'mem_db.dart';

// the registry answers only when the test says so
class _Registry implements HaloEngine {
  final claim = Completer<String>();
  final release = Completer<String>();
  final asked = <String>[];
  @override
  Future<String> handleCheck(String h) async => 'free';
  @override
  Future<String> handleClaim(String h, String invite, String bio) {
    asked.add('claim $h');
    return claim.future;
  }

  @override
  Future<String> handleRelease(String h) {
    asked.add('release $h');
    return release.future;
  }

  // no first-contact address: the invite is the plain one
  @override
  String firstContactPk(int counter) => '';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('the engine was asked for ${i.memberName}');
}

Widget _app() => MaterialApp(
  theme: buildHaloTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (ctx) => Center(
      child: TextButton(
        onPressed: () => Navigator.of(
          ctx,
        ).push(MaterialPageRoute<void>(builder: (_) => const HandleScreen())),
        child: const Text('open'),
      ),
    ),
  ),
);

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1000, 2400);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final m = t.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() => m.setMockMethodCallHandler(SystemChannels.platform, null));
}

Future<void> _rest(WidgetTester t, [int seconds = 2]) async {
  for (var i = 0; i < seconds; i++) {
    await t.pump(const Duration(seconds: 1));
  }
}

void main() {
  late _Registry reg;

  // the invite a claim sends is built from this phone's own keys
  setUpAll(() async {
    final me = Curve.generateKeyPair();
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    appState.sendModeForTest = 'balanced';
  });

  // made inside the test, so its answers land in the test's own clock
  void registry() => useEngineForTest(reg = _Registry());

  testWidgets('a handle deleted while the page goes back is forgotten', (
    t,
  ) async {
    _phone(t);
    registry();
    await devWorld();
    await appState.setMyHandle('wren', invite: 'halo:old');
    addTearDown(() => appState.setMyHandle(null));
    await t.pumpWidget(_app());
    await t.tap(find.text('open'));
    await _rest(t);
    await t.tap(find.text(l10n.handleDeleteThisHandle));
    await _rest(t);
    await t.tap(find.text(l10n.handleDeleteYes));
    await _rest(t);
    expect(reg.asked, ['release wren']);
    // back, before the registry answers
    t.state<NavigatorState>(find.byType(Navigator)).pop();
    await _rest(t);
    expect(find.byType(HandleScreen), findsNothing);
    reg.release.complete('ok');
    await _rest(t);
    expect(appState.myHandle, isNull);
    expect(await secureStore.read(key: 'my_handle'), isNull);
    expect(await secureStore.read(key: kHandleClaimedKey), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a handle claimed while the page is taken away is kept', (
    t,
  ) async {
    _phone(t);
    registry();
    await devWorld();
    addTearDown(() => appState.setMyHandle(null));
    await t.pumpWidget(_app());
    await t.tap(find.text('open'));
    await _rest(t);
    await t.enterText(find.byType(TextField).first, 'wren');
    await t.pump();
    await _rest(t);
    await t.enterText(find.byType(TextField).at(1), 'hello');
    await t.pump();
    await t.ensureVisible(find.text(l10n.handleClaimThisHandle));
    await t.tap(find.text(l10n.handleClaimThisHandle));
    await t.pump();
    expect(reg.asked, ['claim wren']);
    // the lock renews the navigator: the page is gone mid-request
    await t.pumpWidget(const SizedBox());
    reg.claim.complete('ok');
    await _rest(t);
    expect(appState.myHandle, 'wren');
    expect(await secureStore.read(key: 'my_handle'), 'wren');
    expect(await secureStore.read(key: 'my_handle_bio'), 'hello');
    expect(await secureStore.read(key: kHandleClaimedKey), isNotNull);
  });
}
