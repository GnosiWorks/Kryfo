// SPDX-License-Identifier: GPL-3.0-or-later
// the identities a container holds, as rows. 0 is the main one: the words,
// the onion and the face, made from the key the identity table keeps. any
// other has a random key of its own and nothing else: no words, no onion,
// no handle. nothing is derived from one key to another, so a row leaked
// says nothing of the others. in 0.6 every contact is on the main one;
// others are made by test builds only

import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:sqflite_sqlcipher/sqflite.dart';

/// the main identity
const kMainIdent = 0;

/// what an identity is for
const kIdentFace = 'face';
const kIdentContact = 'contact';
const kIdentGroup = 'group';
const kIdentPool = 'pool';
const kIdentKinds = {kIdentFace, kIdentContact, kIdentGroup, kIdentPool};

/// the addresses of a pair: 3 from the two keys alone, 4 with a seed
const kConvClassic = 3;
const kConvSeeded = 4;

/// a registration id as libsignal_protocol_dart made them: 1 to 16380
int newRegistrationId([Random? r]) => (r ?? Random.secure()).nextInt(16380) + 1;

/// one identity's row
class IdentityRow {
  const IdentityRow({
    required this.id,
    required this.kind,
    required this.xPriv,
    required this.regId,
    required this.createdAt,
    this.retiredAt,
    this.name,
    this.photo,
    this.about,
  });

  final int id;
  final String kind;
  final Uint8List xPriv;
  final int regId;
  final int createdAt;
  final int? retiredAt;
  final String? name;
  final int? photo;
  final String? about;

  static IdentityRow of(Map<String, Object?> r) => IdentityRow(
    id: r['id'] as int,
    kind: r['kind'] as String,
    xPriv: Uint8List.fromList(r['x_priv'] as List<int>),
    regId: r['reg_id'] as int,
    createdAt: r['created_at'] as int,
    retiredAt: r['retired_at'] as int?,
    name: r['name'] as String?,
    photo: r['photo'] as int?,
    about: r['about'] as String?,
  );
}

/// [id]'s row, null when the container has none
Future<IdentityRow?> identityRow(DatabaseExecutor db, int id) async {
  final rows = await db.query(
    'identities',
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );
  return rows.isEmpty ? null : IdentityRow.of(rows.first);
}

/// every identity, retired ones too, by id
Future<List<IdentityRow>> identityRows(DatabaseExecutor db) async => [
  for (final r in await db.query('identities', orderBy: 'id'))
    IdentityRow.of(r),
];

/// row 0 for the main key [xPriv]: written with the identity it comes from
/// (saveIdentity), and kept when it is already this key. a new key takes
/// a new registration id unless [regId] names the one its store has
Future<void> putMainIdentity(
  DatabaseExecutor db,
  Uint8List xPriv, {
  int? regId,
  int? photo,
}) async {
  final had = await identityRow(db, kMainIdent);
  if (had != null && _eq(had.xPriv, xPriv)) return;
  await db.insert('identities', {
    'id': kMainIdent,
    'kind': kIdentFace,
    'x_priv': Uint8List.fromList(xPriv),
    'reg_id': regId ?? newRegistrationId(),
    'created_at': DateTime.now().millisecondsSinceEpoch,
    'photo': photo ?? had?.photo,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

/// a new identity of [kind] with a random key from [newKey] (libsignal's,
/// clamped by it) and a random registration id: its id
Future<int> makeIdentity(
  DatabaseExecutor db,
  String kind,
  Uint8List Function() newKey,
) async {
  if (!kIdentKinds.contains(kind) || kind == kIdentFace) {
    throw ArgumentError.value(kind, 'kind');
  }
  var id = 1;
  for (final r in await db.query('identities', columns: ['id'])) {
    if ((r['id'] as int) >= id) id = (r['id'] as int) + 1;
  }
  await db.insert('identities', {
    'id': id,
    'kind': kind,
    'x_priv': newKey(),
    'reg_id': newRegistrationId(),
    'created_at': DateTime.now().millisecondsSinceEpoch,
  });
  return id;
}

/// the profile [id] shows: its own, never another's
Future<void> setIdentityProfile(
  DatabaseExecutor db,
  int id, {
  String? name,
  int? photo,
  String? about,
}) => db.update(
  'identities',
  {'name': name, 'photo': photo, 'about': about},
  where: 'id = ?',
  whereArgs: [id],
);

/// a contact's identity key as the index holds it: 0x05 and the x key, in
/// hex. null for anything that is not a 32-byte key
String? identityKeyHex(String? xHex) {
  if (xHex == null || xHex.length != 64) return null;
  final x = xHex.toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(x)) return null;
  return '05$x';
}

/// my identity for [haloId], the main one when there is no row
Future<int> identOfContact(DatabaseExecutor db, String haloId) async {
  final rows = await db.query(
    'contacts',
    columns: ['ident'],
    where: 'halo_id = ?',
    whereArgs: [haloId],
    limit: 1,
  );
  return rows.isEmpty ? kMainIdent : (rows.first['ident'] as int? ?? 0);
}

/// the contact holding identity key [xHex], null with none
Future<String?> contactOfKey(DatabaseExecutor db, String xHex) async {
  final k = identityKeyHex(xHex);
  if (k == null) return null;
  final rows = await db.query(
    'contacts',
    columns: ['halo_id'],
    where: 'ikey = ?',
    whereArgs: [k],
    limit: 1,
  );
  return rows.isEmpty ? null : rows.first['halo_id'] as String;
}

/// each contact's identity key claimed from its x key, [only] one or all:
/// a key no other row holds is theirs, and its pair is on conv 3 when it
/// has none. a key another row holds already stays with that row: two rows
/// never hold one key
Future<void> claimContactKeys(DatabaseExecutor db, {String? only}) async {
  final rows = await db.query(
    'contacts',
    columns: ['halo_id', 'xpub', 'ikey', 'ident', 'first_seen'],
    where: only == null ? null : 'halo_id = ?',
    whereArgs: only == null ? null : [only],
    orderBy: only == null ? 'first_seen, halo_id' : null,
  );
  for (final r in rows) {
    final id = r['halo_id'];
    if (id is! String) continue;
    final want = identityKeyHex(r['xpub'] as String?);
    final had = r['ikey'] as String?;
    if (want == had) {
      if (want != null) await _pairAt3(db, r['ident'] as int? ?? 0, want);
      continue;
    }
    String? take;
    if (want != null) {
      final held = await db.query(
        'contacts',
        columns: ['halo_id'],
        where: 'ikey = ?',
        whereArgs: [want],
        limit: 1,
      );
      if (held.isEmpty) take = want;
    }
    if (take == had) continue;
    await db.update(
      'contacts',
      {'ikey': take},
      where: 'halo_id = ?',
      whereArgs: [id],
    );
    if (take != null) await _pairAt3(db, r['ident'] as int? ?? 0, take);
  }
}

Future<void> _pairAt3(DatabaseExecutor db, int ident, String key) =>
    db.insert('pairs', {
      'ident': ident,
      'peer': key,
      'their_device': 1,
      'my_device': 1,
      'conv': kConvClassic,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

/// the pair of my [ident] with identity key [peerKeyHex] (0x05 and x, hex):
/// its conv and seed. a pair with no row is on conv 3
Future<({int conv, Uint8List? seed})> pairOf(
  DatabaseExecutor db,
  int ident,
  String peerKeyHex, {
  int theirDevice = 1,
  int myDevice = 1,
}) async {
  final rows = await db.query(
    'pairs',
    columns: ['conv', 'seed'],
    where: 'ident = ? AND peer = ? AND their_device = ? AND my_device = ?',
    whereArgs: [ident, peerKeyHex, theirDevice, myDevice],
    limit: 1,
  );
  if (rows.isEmpty) return (conv: kConvClassic, seed: null);
  final s = rows.first['seed'];
  return (
    conv: rows.first['conv'] as int,
    seed: s == null ? null : Uint8List.fromList(s as List<int>),
  );
}

/// a pair made by a v4 first contact: its addresses mix in [seed]. a pair
/// keeps its conv for life: a heal changes no address
Future<void> putSeededPair(
  DatabaseExecutor db,
  int ident,
  String peerKeyHex,
  Uint8List seed, {
  int theirDevice = 1,
  int myDevice = 1,
}) async {
  if (seed.length != 32) throw ArgumentError('a seed is 32 bytes');
  final had = await db.query(
    'pairs',
    columns: ['conv'],
    where: 'ident = ? AND peer = ? AND their_device = ? AND my_device = ?',
    whereArgs: [ident, peerKeyHex, theirDevice, myDevice],
    limit: 1,
  );
  if (had.isNotEmpty) throw StateError('the pair has its addresses already');
  await db.insert('pairs', {
    'ident': ident,
    'peer': peerKeyHex,
    'their_device': theirDevice,
    'my_device': myDevice,
    'conv': kConvSeeded,
    'seed': Uint8List.fromList(seed),
  });
}

/// a first-contact key for invite [inviteId] of [ident]: 32 random bytes
/// that lift to a secp256k1 key ([lifts], the engine's check). one per
/// invite, retired with it
Future<Uint8List> makeFcKey(
  DatabaseExecutor db,
  int ident,
  String inviteId,
  bool Function(Uint8List sk) lifts,
) async {
  final r = Random.secure();
  for (;;) {
    final sk = Uint8List.fromList(List.generate(32, (_) => r.nextInt(256)));
    if (!lifts(sk)) continue;
    await db.insert('fc_keys', {
      'ident': ident,
      'invite_id': inviteId,
      'sk': sk,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return sk;
  }
}

/// the live first-contact keys of [ident], by invite id
Future<Map<String, Uint8List>> fcKeysOf(DatabaseExecutor db, int ident) async =>
    {
      for (final r in await db.query(
        'fc_keys',
        where: 'ident = ? AND retired_at IS NULL',
        whereArgs: [ident],
      ))
        r['invite_id'] as String: Uint8List.fromList(r['sk'] as List<int>),
    };

/// invite [inviteId]'s first-contact key retires: nothing listens on it
Future<void> retireFcKey(DatabaseExecutor db, int ident, String inviteId) =>
    db.update(
      'fc_keys',
      {'retired_at': DateTime.now().millisecondsSinceEpoch},
      where: 'ident = ? AND invite_id = ?',
      whereArgs: [ident, inviteId],
    );

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
