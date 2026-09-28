// SPDX-License-Identifier: GPL-3.0-or-later
// what the receive path decides: a name stays with the key first seen for
// it, a group's frames come from its members and its controls from its
// admin, within its cap, and an arriving file gets a name the app draws.
// the last group checks the receive path asks these, in that order.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/arrival_rules.dart';

String _hex(int fill) => List.generate(
  32,
  (i) => ((fill + i) % 256).toRadixString(16).padLeft(2, '0'),
).join();

List<int> _key(int fill) => xIdentity(_hex(fill))!;

String _bundle(List<int> identity) => base64Encode(
  utf8.encode(jsonEncode({'identityKey': base64Encode(identity)})),
);

// the text of one function in lib/main.dart, from its signature to the
// brace that closes it at [indent]
String _body(String src, String signature, {String indent = '  '}) {
  final at = src.indexOf(signature);
  expect(at, isNot(-1), reason: '$signature is in lib/main.dart');
  final end = src.indexOf('\n$indent}\n', at);
  expect(end, isNot(-1));
  return src.substring(at, end);
}

// [first] comes before [then] in [text], both present
void _before(String text, String first, String then) {
  final a = text.indexOf(first);
  final b = text.indexOf(then);
  expect(a, isNot(-1), reason: '$first is there');
  expect(b, isNot(-1), reason: '$then is there');
  expect(a < b, isTrue, reason: '$first comes before $then');
}

void main() {
  group('a name and its key', () {
    test('a prekey opens under a name only with the key bound to it', () {
      expect(prekeyOpensUnder(_key(1), _key(1)), isTrue);
      expect(prekeyOpensUnder(_key(1), _key(2)), isFalse);
      // a name with no key yet takes no prekey: it goes the first-contact way
      expect(prekeyOpensUnder(null, _key(2)), isFalse);
    });

    test('a card with a contact\'s name and another key is not taken', () {
      final contact = {'xpub': _hex(1), 'peer_bundle': null};
      expect(
        boundToOtherKey(rowIdentity(contact), bundleIdentity(_bundle(_key(2)))),
        isTrue,
      );
      expect(boundToOtherKey(rowIdentity(contact), _key(2)), isTrue);
      // the same key reads as the contact it is
      expect(
        boundToOtherKey(rowIdentity(contact), bundleIdentity(_bundle(_key(1)))),
        isFalse,
      );
      // a row with only a bundle binds its name to the bundle's key
      final carded = {'xpub': '', 'peer_bundle': _bundle(_key(3))};
      expect(boundToOtherKey(rowIdentity(carded), _key(2)), isTrue);
      expect(boundToOtherKey(rowIdentity(carded), _key(3)), isFalse);
      // a key that does not read still binds its row
      expect(
        boundToOtherKey(rowIdentity({'xpub': 'not a key'}), _key(2)),
        isTrue,
      );
      // no row, or a claim that gives no key, binds nothing
      expect(boundToOtherKey(rowIdentity(null), _key(2)), isFalse);
      expect(boundToOtherKey(_key(1), null), isFalse);
    });

    test('a first contact giving a name bound to another key is filed on '
        'an id of its own', () {
      const alice = 'amber-river-stone';
      final own = unboundIdOf(_key(2));
      expect(firstContactFiledAt(alice, _key(2), claimedBound: _key(1)), own);
      expect(own, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(unboundIdOf(_key(2)), own);
      expect(unboundIdOf(_key(3)), isNot(own));
      // its own id bound to yet another key: not filed at all
      expect(
        firstContactFiledAt(
          alice,
          _key(2),
          claimedBound: _key(1),
          ownBound: _key(3),
        ),
        isNull,
      );
      // the name with its own key, or a name with none yet, stays the name
      expect(firstContactFiledAt(alice, _key(1), claimedBound: _key(1)), alice);
      expect(firstContactFiledAt(alice, _key(2)), alice);
    });

    test('the x key a first contact gives is the key its session runs on', () {
      expect(firstContactKeyHolds(_key(1), _hex(1)), isTrue);
      expect(firstContactKeyHolds(_key(1), _hex(1).toUpperCase()), isTrue);
      expect(firstContactKeyHolds(_key(1), null), isTrue);
      expect(firstContactKeyHolds(_key(1), _hex(2)), isFalse);
      expect(firstContactKeyHolds(_key(1), 'zz'), isFalse);
      expect(firstContactKeyHolds(null, _hex(1)), isFalse);
    });
  });

  group('groups', () {
    test('a group frame is kept only from a member', () {
      const members = ['admin', 'member'];
      expect(groupFrameFromMember('member', members), isTrue);
      expect(groupFrameFromMember('admin', members), isTrue);
      expect(groupFrameFromMember('outsider', members), isFalse);
    });

    test('add, remove and rename come from the admin alone, leave from '
        'its sender', () {
      for (final type in ['add', 'remove', 'rename']) {
        bool taken(String sender, {bool exists = true, String? admin}) =>
            groupControlTaken(
              type,
              sender: sender,
              exists: exists,
              adminId: admin,
            );
        expect(taken('admin', admin: 'admin'), isTrue, reason: type);
        expect(taken('member', admin: 'admin'), isFalse, reason: type);
        // a group with no admin takes none
        expect(taken('member'), isFalse, reason: type);
        expect(taken('admin', exists: false, admin: 'admin'), isFalse);
      }
      expect(
        groupControlTaken(
          'leave',
          sender: 'member',
          exists: true,
          adminId: 'a',
        ),
        isTrue,
      );
      expect(
        groupControlTaken('join', sender: 'a', exists: true, adminId: 'a'),
        isFalse,
      );
    });

    test('a create over a group or room here comes from its admin alone', () {
      expect(
        groupControlTaken('create', sender: 'a', exists: true, adminId: 'a'),
        isTrue,
      );
      expect(
        groupControlTaken('create', sender: 'm', exists: true, adminId: 'a'),
        isFalse,
      );
      expect(
        groupControlTaken('create', sender: 'm', exists: true, adminId: null),
        isFalse,
      );
      // a new group: its sender becomes its admin
      expect(
        groupControlTaken('create', sender: 'm', exists: false, adminId: null),
        isTrue,
      );
    });

    test('a roster fits the app\'s cap and a room\'s own', () {
      expect(fitsMemberCap(50, cap: 50), isTrue);
      expect(fitsMemberCap(51, cap: 50), isFalse);
      expect(fitsMemberCap(3, cap: 50, roomCap: 3), isTrue);
      expect(fitsMemberCap(4, cap: 50, roomCap: 3), isFalse);
    });
  });

  group('arriving files', () {
    test('an arriving picture or file is named by the app, not by its '
        'uid', () {
      final pic = arrivalLeaf();
      expect(pic, matches(RegExp(r'^in_[0-9a-f]{32}\.jpg$')));
      final doc = arrivalLeaf(fileName: 'report.pdf');
      expect(doc, matches(RegExp(r'^in_[0-9a-f]{32}_report\.pdf$')));
      // never the shape of our own files, never twice the same
      expect(pic, isNot(startsWith('f_')));
      expect(arrivalLeaf(), isNot(pic));
      expect(arrivalLeaf(fileName: 'report.pdf'), isNot(doc));
      // a sender's name stays one leaf in the media folder
      expect(arrivalLeaf(fileName: '../../x'), isNot(contains('/')));
      expect(arrivalLeaf(random: Random(7)), arrivalLeaf(random: Random(7)));
    });

    test('a sliced file is filed under its own message id', () {
      expect(sliceOfItsMessage('uid1', 'uid1'), isTrue);
      expect(sliceOfItsMessage(null, 'uid1'), isTrue);
      expect(sliceOfItsMessage('uid2', 'uid1'), isFalse);
    });
  });

  group('the receive path asks these', () {
    final src = File('lib/main.dart').readAsStringSync();

    test('a prekey opens only under its bound name', () {
      final body = _body(src, 'Future<String?> signalDecrypt(', indent: '');
      _before(body, '_storedIdentity(addr)', 'cipher.decrypt(pkm)');
      _before(body, 'prekeyOpensUnder(', 'cipher.decrypt(pkm)');
    });

    test('a first contact is filed where its key allows', () {
      final body = _body(src, 'Future<String?> backPairFromCipher(');
      _before(body, 'firstContactKeyHolds(', 'storeSession(realAddr');
      _before(body, 'firstContactFiledAt(', 'storeSession(realAddr');
      _before(body, 'firstContactFiledAt(', 'upsertContact(');
      expect(body, contains('SignalProtocolAddress(at, 1)'));
      expect(body, isNot(contains('SignalProtocolAddress(h, 1)')));
      expect(body, contains("ShieldHit('other_key', h)"));
      expect(body, contains('_applyIncomingPayload(at, env'));
    });

    test('a card or handle names someone only with their key', () {
      final body = _body(
        src,
        'Future<(String, bool)> handleHaloUriAdded(',
        indent: '',
      );
      expect(body, contains('idOf: engine.idFromEdPub'));
      _before(body, 'boundToOtherKey(', 'processPeerBundle(');
      _before(body, 'boundToOtherKey(', 'upsertContact(');
    });

    test('a group frame is checked before anything is kept', () {
      final body = _body(src, 'Future<void> _applyIncomingPayload(');
      _before(body, 'groupFrameFromMember(', 'putMediaChunk(');
      _before(body, 'groupFrameFromMember(', 'saveMessage(');
      _before(body, 'groupFrameFromMember(', 'setContactBadge(');
      final roster = body.substring(body.indexOf('env.roster != null'));
      _before(roster, '_fitsCap(', 'syncGroupMembers(');
    });

    test('dedup comes before any file is written, under an app name', () {
      final body = _body(src, 'Future<void> _applyIncomingPayload(');
      _before(body, 'sliceOfItsMessage(', 'putMediaChunk(');
      _before(body, 'messageExists(uid)', 'saveMediaBytes(');
      _before(body, 'messageExists(uid)', 'saveFileBytes(');
      _before(body, '_inflightUids.add(mid)', 'saveSlices(');
      expect(body, isNot(contains('fileUid')));
      for (final sig in [
        'Future<File> receivedFileFor(',
        'Future<File> receivedImageFor(',
      ]) {
        final f = _body(src, sig, indent: '');
        expect(f, contains('arrivalLeaf('));
        expect(f, isNot(contains(r'f_${')));
      }
    });

    test('a group control is taken from its admin, within its cap', () {
      final body = _body(src, 'Future<void> _applyGroupControl(');
      _before(body, 'groupControlTaken(', 'switch (gc.type)');
      _before(body, '_fitsCap(', 'createGroup(');
      final add = body.substring(body.indexOf("case 'add':"));
      _before(add, '_fitsCap(', 'addGroupMember(');
    });
  });
}
