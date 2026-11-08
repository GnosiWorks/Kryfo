// SPDX-License-Identifier: GPL-3.0-or-later
// the device sessions the app's send and receive loops use: on a linked
// device a contact's phone, and its own phone, are devices it opens and
// seals to. built as a phone's store they were refused, so nothing from
// device 1 ever opened there: no contact's opener, no own sync, no removal
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/device_sessions.dart';
import 'package:kryfo/identities.dart' show kMainIdent;
import 'package:kryfo/main.dart'
    show appDeviceSessionsForTest, linkedRoleForTest;
import 'package:kryfo/signal_session.dart';
import 'package:kryfo/wire_pad.dart' show unpad;

import 'mem_db.dart';
import 'signal_kit.dart';

void main() {
  setUpAll(() async {
    final me = testKeyPair();
    await signalSession.bootstrap(
      database: MemDb(),
      xPubBytes: me.publicKey.serialize().sublist(1),
      xPrivBytes: me.privateKey.serialize(),
    );
  });

  tearDown(() => linkedRoleForTest = false);

  // a phone (a contact's, or this desk's own) opens a pair to the desk as
  // device [desk] and seals [text] on it; the desk opens it with the app's
  // own sessions
  Future<String> phoneToDesk(DeviceSessions ds, int desk, String text) async {
    final phone = await testStore();
    final phoneDs = DeviceSessions(phone);
    // the desk's bundle is its owner's: the identity of the phone it is
    // linked to, with the desk's own key inside
    final owner = await testStore();
    final block = phone.lib.parseDeviceBundle(
      await ds.makeBundle(desk),
      owner.identity.public,
    );
    await phoneDs.build(
      'desk',
      desk,
      block,
      signalSession.identity.public,
      signalSession.registrationId,
    );
    final wire = base64Decode(
      await phoneDs.seal('desk', desk, text, signalSession.identity.public),
    );
    final plain = await ds.open(
      'phone',
      1,
      wire[0],
      Uint8List.sublistView(wire, 1),
      phone.identity.public,
      reg: phone.registrationId,
    );
    return unpad(utf8.decode(plain));
  }

  test('a linked desk opens what a phone sends it', () async {
    linkedRoleForTest = true;
    final ds = await appDeviceSessionsForTest(kMainIdent);
    expect(ds.linked, isTrue);
    expect(await phoneToDesk(ds, 2, '{"as":"x"}'), '{"as":"x"}');
  });

  test('the role is read again: a phone store never takes device 1', () async {
    linkedRoleForTest = false;
    final phone = await appDeviceSessionsForTest(kMainIdent);
    expect(phone.linked, isFalse);
    await expectLater(phone.has('someone', 1), completion(isFalse));
    // the same identity's sessions once it is a linked device are built
    // again, not the phone's held from before
    linkedRoleForTest = true;
    final desk = await appDeviceSessionsForTest(kMainIdent);
    expect(desk.linked, isTrue);
    expect(identical(desk, phone), isFalse);
  });
}
