// SPDX-License-Identifier: GPL-3.0-or-later
// every gate of a typing frame, alone: one that fails is enough for
// nothing to go, or for nothing to show
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/router.dart';
import 'package:kryfo/typing.dart';

TypingSendFacts send({
  bool switchOn = true,
  bool decoy = false,
  bool held = false,
  bool locked = false,
  bool inFront = true,
  bool onScreen = true,
  bool oneToOne = true,
  bool accepted = true,
  bool backPaired = true,
  bool blocked = false,
  bool peerCan = true,
  bool hasOnion = true,
  bool privateRoute = true,
  bool torUsable = true,
  bool linkUp = true,
  bool userEdit = true,
  bool nonEmpty = true,
}) => TypingSendFacts(
  switchOn: switchOn,
  decoy: decoy,
  held: held,
  locked: locked,
  inFront: inFront,
  onScreen: onScreen,
  oneToOne: oneToOne,
  accepted: accepted,
  backPaired: backPaired,
  blocked: blocked,
  peerCan: peerCan,
  hasOnion: hasOnion,
  privateRoute: privateRoute,
  torUsable: torUsable,
  linkUp: linkUp,
  userEdit: userEdit,
  nonEmpty: nonEmpty,
);

TypingShowFacts show({
  bool viaOnion = true,
  bool switchOn = true,
  bool privateRoute = true,
  bool decoy = false,
  bool locked = false,
  bool inFront = true,
  RouteTo route = RouteTo.everyday,
  bool contact = true,
  bool blocked = false,
  bool dev = false,
  bool group = false,
  int? written = 20,
  int floor = 10,
}) => TypingShowFacts(
  viaOnion: viaOnion,
  switchOn: switchOn,
  privateRoute: privateRoute,
  decoy: decoy,
  locked: locked,
  inFront: inFront,
  route: route,
  contact: contact,
  blocked: blocked,
  dev: dev,
  group: group,
  written: written,
  floor: floor,
);

void main() {
  test('with every gate open a frame goes', () {
    expect(typingMaySend(send()), isTrue);
  });

  final noSend = <String, TypingSendFacts>{
    'the switch is off': send(switchOn: false),
    'a decoy is on screen': send(decoy: true),
    'the everyday identity is held or wiped': send(held: true),
    'the app is locked': send(locked: true),
    'the app is in the back': send(inFront: false),
    'the chat is not on screen': send(onScreen: false),
    'a group, room, notes or the developer\'s chat': send(oneToOne: false),
    'a request': send(accepted: false),
    'they have not added this phone back': send(backPaired: false),
    'blocked either way': send(blocked: true),
    'their phone does not know typing': send(peerCan: false),
    'no onion of theirs': send(hasOnion: false),
    'the relay or fast route': send(privateRoute: false),
    'tor does not carry': send(torUsable: false),
    'no network': send(linkUp: false),
    'words the app put there': send(userEdit: false),
    'an empty field': send(nonEmpty: false),
  };
  for (final e in noSend.entries) {
    test('nothing goes when ${e.key}', () {
      expect(typingMaySend(e.value), isFalse);
    });
  }

  test('a contact\'s frame shows, in an everyday chat or an open vault', () {
    expect(typingMayShow(show()), isTrue);
    expect(typingMayShow(show(route: RouteTo.vault)), isTrue);
  });

  final noShow = <String, TypingShowFacts>{
    'it came on a relay': show(viaOnion: false),
    'my switch is off': show(switchOn: false),
    'my route is not the onion': show(privateRoute: false),
    'a decoy is on screen': show(decoy: true),
    'the app is locked': show(locked: true),
    'the app is in the back': show(inFront: false),
    'its chat is sealed in a shut vault': show(route: RouteTo.sealed),
    'its sender is dropped': show(route: RouteTo.dropped),
    'a request, a stranger or a kept opener': show(contact: false),
    'they are blocked': show(blocked: true),
    'the developer\'s chat': show(dev: true),
    'a group': show(group: true),
    'it has no time': show(written: null),
    'it was written before their last message': show(written: 10),
  };
  for (final e in noShow.entries) {
    test('nothing shows when ${e.key}', () {
      expect(typingMayShow(e.value), isFalse);
    });
  }
}
