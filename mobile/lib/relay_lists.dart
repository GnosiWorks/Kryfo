// SPDX-License-Identifier: GPL-3.0-or-later
// the relay lists per route, as the engine takes them: the main list, then
// the backups after a |

/// private on our two servers alone, the public relays only while our first
/// one is down. off unless a build says --dart-define=KRYFO_PRIVATE_OWN=1
const bool kPrivateOwnRelays =
    String.fromEnvironment('KRYFO_PRIVATE_OWN', defaultValue: '0') == '1' ||
    String.fromEnvironment('KRYFO_PRIVATE_OWN', defaultValue: '0') == 'true';

const kFirstRelay = 'wss://relay.kryfo.app';
const kSecondRelay = 'wss://relay2.kryfo.app';
const kFirstOnion =
    'ws://z4waup3c6j6gknkjba72cqjjuffhgg6gtgqfu3vetzcvgoluvr42srid.onion';
const kSecondOnion =
    'ws://cvwpee5zgbargtxd5wtbtnc6lkbgzxj5byfig3e53ic4t7su7r45n4yd.onion';

// one list. two copies drift, and the drift is invisible until someone
// cannot receive on one route
const kPublicRelays = [
  'wss://nos.lol',
  'wss://relay.primal.net',
  'wss://nostr.mom',
  'wss://nostr.oxtr.dev',
];

/// the public relays private falls back on. only ones every older version
/// writes to, or what a 0.5 or 0.6.0 contact sent while our first server
/// was down is not where we read
const kPrivateBackups = ['wss://relay.primal.net', 'wss://nostr.oxtr.dev'];

/// the list for route [route] ('private' or 'balanced')
String relayListFor(String route, {bool privateOwn = kPrivateOwnRelays}) {
  final public = kPublicRelays.join(',');
  if (route == 'balanced') return '$kFirstRelay,$kSecondRelay|$public';
  // our first server's clearnet name rides along over tor: a friend on an
  // older relay mode publishes only there, and it is the way in when its
  // onion stops answering
  final ours = '$kFirstOnion,$kSecondOnion,$kFirstRelay';
  if (privateOwn) return '$ours|${kPrivateBackups.join(',')}';
  return '$ours,$public';
}
