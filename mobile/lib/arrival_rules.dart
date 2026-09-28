// SPDX-License-Identifier: GPL-3.0-or-later
// what the receive path decides on its own, with no io: which key a name is
// bound to, who writes into a group and who changes it, and what an
// arriving file is called. main.dart asks these; tests ask them directly.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

bool sameKey(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// an x key as signal writes it, null when it is not one
List<int>? xIdentity(String xHex) {
  if (xHex.length != 64) return null;
  final out = <int>[0x05];
  for (var i = 0; i < 64; i += 2) {
    final b = int.tryParse(xHex.substring(i, i + 2), radix: 16);
    if (b == null) return null;
    out.add(b);
  }
  return out;
}

/// the identity key a card's prekey bundle carries, null when it does not
/// read
List<int>? bundleIdentity(String bundleB64) {
  try {
    final j = jsonDecode(utf8.decode(base64Decode(bundleB64))) as Map;
    return base64Decode(j['identityKey'] as String);
  } catch (_) {
    return null;
  }
}

/// the key a contact row holds for someone. a key that does not read still
/// binds the row: it matches nothing
List<int>? rowIdentity(Map<String, Object?>? row) {
  if (row == null) return null;
  final x = row['xpub'] as String?;
  if (x != null && x.isNotEmpty) {
    return xIdentity(x.toLowerCase()) ?? utf8.encode('x $x');
  }
  final bundle = row['peer_bundle'] as String?;
  if (bundle != null && bundle.isNotEmpty) {
    return bundleIdentity(bundle) ?? utf8.encode('b $bundle');
  }
  return null;
}

/// whether a name bound here to [bound] is given with another key. a name
/// with no key yet, or a claim that gives none, is not
bool boundToOtherKey(List<int>? bound, List<int>? key) =>
    bound != null && key != null && !sameKey(bound, key);

/// a prekey message opens under a name only with the key that name is
/// bound to. another key, or a name with none yet, arrives as a first
/// contact and is checked there
bool prekeyOpensUnder(List<int>? bound, List<int> key) =>
    bound != null && sameKey(bound, key);

/// a first contact's session runs on [key]. the x key it gives for itself,
/// when it gives one, is that key
bool firstContactKeyHolds(List<int>? key, String? xHex) {
  if (key == null) return false;
  if (xHex == null || xHex.isEmpty) return true;
  return sameKey(xIdentity(xHex.toLowerCase()) ?? const [], key);
}

/// where someone lands who writes under a name bound here to another key:
/// an id of their own, from their key, that is never three words
String unboundIdOf(List<int> identityKey) =>
    sha256.convert(identityKey).toString().substring(0, 16);

/// where a first contact that gives the name [claimed] with [key] is
/// filed: under that name when it is bound to no key or to this one, else
/// under its own id (unboundIdOf). [claimedBound] and [ownBound] are the
/// keys the two ids are bound to here. null when its own id is bound to
/// yet another key
String? firstContactFiledAt(
  String claimed,
  List<int> key, {
  List<int>? claimedBound,
  List<int>? ownBound,
}) {
  if (!boundToOtherKey(claimedBound, key)) return claimed;
  if (boundToOtherKey(ownBound, key)) return null;
  return unboundIdOf(key);
}

/// a group's messages, polls and slices come from its members
bool groupFrameFromMember(String sender, Iterable<String> members) =>
    members.contains(sender);

/// whether a group control is taken. add, remove, rename and a create over
/// a group or room here come from its admin alone: a room's admin is its
/// creator's key, and a group with no admin takes none. leave speaks only
/// for its sender. join is taken off a room's drop box, never here
bool groupControlTaken(
  String type, {
  required String sender,
  required bool exists,
  required String? adminId,
}) {
  final fromAdmin = exists && adminId != null && sender == adminId;
  return switch (type) {
    'leave' => true,
    'create' => !exists || fromAdmin,
    'add' || 'remove' || 'rename' => fromAdmin,
    _ => false,
  };
}

/// whether a group or room of [n] people fits: the app's [cap], and a
/// room's own [roomCap] when it has one
bool fitsMemberCap(int n, {required int cap, int? roomCap}) =>
    n <= cap && (roomCap == null || n <= roomCap);

/// a sliced file is filed under its own message id
bool sliceOfItsMessage(String? uid, String mediaId) =>
    uid == null || uid == mediaId;

String safeLeaf(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

final _leafRandom = Random.secure();

/// the name an arriving picture or file gets in the media folder. the app
/// draws it: never a message id, and never the shape of the names our own
/// files get (`f_<uid>_<name>`, `<uid>.jpg`). a file keeps the sender's
/// name at the end, so it keeps its type
String arrivalLeaf({String? fileName, Random? random}) {
  final r = random ?? _leafRandom;
  final hex = [
    for (var i = 0; i < 16; i++)
      r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
  return fileName == null ? 'in_$hex.jpg' : 'in_${hex}_${safeLeaf(fileName)}';
}
