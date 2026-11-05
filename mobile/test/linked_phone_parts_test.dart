// SPDX-License-Identifier: GPL-3.0-or-later
// a linked device runs none of its phone's parts: its tor is a client with
// no onion of its own, and it has no decoy, vault, invite, handle claim,
// room or push registration. a phone is as it was
import 'dart:io';

import 'package:flutter/material.dart' hide LockState;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/delivery_mode.dart';
import 'package:kryfo/devices/device_state.dart' show linkedDevicesForTest;
import 'package:kryfo/invite_share.dart' show readyInvite;
import 'package:kryfo/l10n/l10n.dart';
import 'package:kryfo/main.dart'
    show
        AppState,
        HaloEngine,
        kTorClientAddr,
        linkedRoleForTest,
        onionOfStart,
        useEngineForTest,
        AppStateDelivery,
        AppStateGroups,
        AppStateRooms,
        AppStateRoute,
        AppStateSession,
        AppStateVault;
import 'package:kryfo/rooms.dart';
import 'package:kryfo/screens/pin_flow_screen.dart' show PinsHost;
import 'package:kryfo/screens/new_group_screen.dart' show openNewGroup;
import 'package:kryfo/screens/pins_screen.dart';
import 'package:kryfo/store.dart' show playBuildForTest;
import 'package:kryfo/widgets/motion.dart' show TorStatus;
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_flow_fakes.dart';

class _Engine implements HaloEngine {
  final calls = <String>[];
  @override
  String setTransportMode(String mode) => 'ok';
  @override
  String nostrInit(String relaysCSV) => 'ok';
  @override
  Map<String, dynamic> transportState() => const {};
  @override
  dynamic noSuchMethod(Invocation i) {
    calls.add(i.memberName.toString());
    return super.noSuchMethod(i);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Engine eng;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    eng = _Engine();
    useEngineForTest(eng);
    linkedDevicesForTest = true;
    linkedRoleForTest = false;
  });
  tearDown(() {
    linkedRoleForTest = false;
    linkedDevicesForTest = false;
    playBuildForTest = null;
  });

  test('a start on a client hands back no onion, a phone its own', () {
    expect(onionOfStart(kTorClientAddr), '');
    expect(onionOfStart('abcdefghijklmnop.onion'), 'abcdefghijklmnop.onion');
    expect(onionOfStart('error: tor start: x'), 'error: tor start: x');
  });

  test('every start the app makes reads its onion through onionOfStart', () {
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      expect(
        RegExp(r'(myOnion|_myAddr) = addr;').hasMatch(src),
        isFalse,
        reason: '${f.path} takes a start result as an onion',
      );
    }
  });

  test('a client at 100% shows all the way there; a phone still finishing '
      'its address', () {
    final app = AppState()..sendModeForTest = 'private';
    app.takeTorStatus('bootstrapped|100|0|1|1');
    expect(app.shownTorStatus, TorStatus.bootstrapped);
    expect(app.linkView.status, TorStatus.bootstrapped);
    linkedRoleForTest = true;
    expect(app.shownTorStatus, TorStatus.reachable);
    expect(app.linkView.status, TorStatus.reachable);
    // what sends goes by tor's own word, which stays
    expect(app.torStatus, TorStatus.bootstrapped);
    expect(app.torUsable, isTrue);
    app.takeTorStatus('starting|40|0|0|2');
    expect(app.shownTorStatus, TorStatus.starting);
  });

  test('no decoy and no vault on a linked device', () async {
    expect(const PinsHost().decoyAndVault, isTrue);
    linkedRoleForTest = true;
    expect(const PinsHost().decoyAndVault, isFalse);
    final app = AppState();
    expect(await app.setDecoyPin(decoyPin), isFalse);
    await expectLater(app.createVault(vaultPin), throwsStateError);
    expect(eng.calls, isEmpty);
  });

  testWidgets('the pins page shows no decoy or hidden chats there', (t) async {
    phone(t);
    final lock = await makeLock(appOnly);
    Future<void> open() async {
      await t.pumpWidget(
        app(
          PinsScreen(
            lock: lock.state,
            host: FakeHost(lock: lock.state),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text(l10n.pinsAdvanced));
      await t.pumpAndSettle();
    }

    await open();
    expect(find.text(l10n.pinsDecoyPin), findsOneWidget);
    expect(find.text(l10n.pinsHiddenChats), findsOneWidget);
    linkedRoleForTest = true;
    await t.pumpWidget(const SizedBox());
    await open();
    expect(find.text(l10n.pinsWipePin), findsOneWidget);
    expect(find.text(l10n.pinsDecoyPin), findsNothing);
    expect(find.text(l10n.pinsHiddenChats), findsNothing);
    expect(find.text(l10n.pinsHowThisWorks), findsNothing);
  });

  test('no invite, no room on a linked device', () async {
    linkedRoleForTest = true;
    final t0 = DateTime.now();
    expect(await readyInvite(wait: const Duration(seconds: 5)), isNull);
    expect(DateTime.now().difference(t0), lessThan(const Duration(seconds: 1)));
    final app = AppState();
    final link = RoomLink(
      roomId: 'room-one',
      name: 'Night shift',
      expiresAt: DateTime.now()
          .add(const Duration(hours: 2))
          .millisecondsSinceEpoch,
      creatorPub: 'a' * 64,
      fcPk: 'b' * 64,
    );
    expect(await app.joinRoom(link), l10n.linkedLinkOnPhone);
    await expectLater(
      app.createRoom('Night shift', expiry: const Duration(hours: 2)),
      throwsStateError,
    );
    expect(eng.calls, isEmpty);
  });

  test('no new group on a linked device: a phone takes no group from a '
      'device', () async {
    linkedRoleForTest = true;
    final app = AppState();
    await expectLater(
      app.createGroupAndAnnounce('Night shift', ['other-kryfo-id']),
      throwsStateError,
    );
    expect(eng.calls, isEmpty);
  });

  testWidgets('the new group way in opens nothing on a linked device', (
    t,
  ) async {
    phone(t);
    var added = 0;
    await t.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  openNewGroup(context, onAdd: () async => added++),
              child: const Text('new group'),
            ),
          ),
        ),
      ),
    );
    // a phone with nobody to pick is asked to add someone first
    await t.tap(find.text('new group'));
    await t.pumpAndSettle();
    expect(find.text(l10n.newGroupNeedsContacts), findsOneWidget);
    await t.tap(find.text(l10n.homeNotNow));
    await t.pumpAndSettle();
    linkedRoleForTest = true;
    await t.tap(find.text('new group'));
    await t.pumpAndSettle();
    expect(find.text(l10n.newGroupNeedsContacts), findsNothing);
    expect(added, 0);
  });

  test('no helper app or google push offered on a linked device', () {
    playBuildForTest = true;
    final app = AppState()
      ..sendModeForTest = 'private'
      ..deliveryModeForTest = DeliveryMode.helper
      ..googleAvailableForTest = true;
    expect(app.helperOffered, isTrue);
    expect(app.googleOffered, isTrue);
    linkedRoleForTest = true;
    expect(app.helperOffered, isFalse);
    expect(app.googleOffered, isFalse);
  });
}
