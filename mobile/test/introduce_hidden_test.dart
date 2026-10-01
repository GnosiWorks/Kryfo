// SPDX-License-Identifier: GPL-3.0-or-later
// an introduction reads each card where its chat is kept, so a hidden chat
// is introduced like any other while the vault is open. what the sheet says
// afterwards is in the language on screen
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/container.dart';
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart' show AppState, useDatabasesForTest;
import 'package:kryfo/router.dart';
import 'package:kryfo/screens/introduce_sheet.dart' show introduceOutcome;
import 'package:kryfo/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arrival_fakes.dart';

const _x = 'plain-friend-here';
const _h = 'hidden-wreck-tone';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => setL10nLocale(const Locale('en')));

  test('a hidden chat is introduced while the vault is open', () async {
    final live = ArrivalRows(HaloContainer.everyday)
      ..person(_x, onion: 'o-$_x', xpub: 'x-$_x');
    final vault = ArrivalRows(HaloContainer.vault)
      ..person(_h, onion: 'o-$_h', xpub: 'x-$_h');
    final store = ArrivalStore();
    await store.putHidden(
      _h,
      kHiddenPeer,
      peerCard(RouterCard(_h, 'o-$_h', 'x-$_h', backPaired: true)),
      1,
    );
    final router = VaultRouter(store, ArrivalSeal());
    await router.load();
    final io = ArrivalIo();
    final app = AppState(io: io, router: router)..myId = 'me';
    useDatabasesForTest(live, await Session.withVault(live, vault));
    expect(await app.introduce(_h, _x), (toFirst: true, toSecond: true));
    expect(io.sent, hasLength(2));
    // each card went to the other side
    expect(io.sent.where((s) => s.$2.contains('x-$_h')), hasLength(1));
    expect(io.sent.where((s) => s.$2.contains('x-$_x')), hasLength(1));
  });

  test('a full introduction says so in the language on screen', () {
    const both = (toFirst: true, toSecond: true);
    expect(
      introduceOutcome(both, 'B', 'C'),
      "B and C now have each other's card",
    );
    setL10nLocale(const Locale('de'));
    final said = introduceOutcome(both, 'B', 'C');
    expect(said, l10n.introduceIntroduced('B', 'C'));
    expect(said, isNot(contains('introduced')));
    expect(said, contains('B'));
    expect(said, contains('C'));
  });

  test('half an introduction and none say what happened', () {
    expect(
      introduceOutcome((toFirst: true, toSecond: false), 'B', 'C'),
      l10n.introduceGotItButCould('B', 'C'),
    );
    expect(
      introduceOutcome((toFirst: false, toSecond: true), 'B', 'C'),
      l10n.introduceGotItButCouldNotBe('C', 'B'),
    );
    expect(
      introduceOutcome((toFirst: false, toSecond: false), 'B', 'C'),
      l10n.introduceCouldNotReachEither,
    );
  });
}
