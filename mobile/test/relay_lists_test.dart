// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/relay_lists.dart';

const _onion1 =
    'ws://z4waup3c6j6gknkjba72cqjjuffhgg6gtgqfu3vetzcvgoluvr42srid.onion';
const _onion2 =
    'ws://cvwpee5zgbargtxd5wtbtnc6lkbgzxj5byfig3e53ic4t7su7r45n4yd.onion';
const _public =
    'wss://nos.lol,wss://relay.primal.net,wss://nostr.mom,wss://nostr.oxtr.dev';

void main() {
  test('the switch is off unless a build turns it on', () {
    expect(kPrivateOwnRelays, isFalse);
  });

  test('off, both routes keep the lists 0.6.0 shipped', () {
    expect(
      relayListFor('private', privateOwn: false),
      '$_onion1,$_onion2,wss://relay.kryfo.app,$_public',
    );
    expect(relayListFor('private'), relayListFor('private', privateOwn: false));
    expect(
      relayListFor('balanced'),
      'wss://relay.kryfo.app,wss://relay2.kryfo.app|$_public',
    );
  });

  test('on, private lists our servers and the public ones as backups', () {
    final parts = relayListFor('private', privateOwn: true).split('|');
    expect(parts, hasLength(2));
    expect(parts[0].split(','), [_onion1, _onion2, 'wss://relay.kryfo.app']);
    final backups = parts[1].split(',');
    expect(backups, isNotEmpty);
    expect(backups.length, lessThanOrEqualTo(3));
    // only relays every older version writes to
    for (final b in backups) {
      expect(kPublicRelays, contains(b));
    }
    // fast does not move
    expect(
      relayListFor('balanced', privateOwn: true),
      relayListFor('balanced', privateOwn: false),
    );
  });
}
