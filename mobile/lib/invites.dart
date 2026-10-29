// SPDX-License-Identifier: GPL-3.0-or-later
// v4 invites (identity v4 2.1-2.3): KIN4 frames made here, signed by the
// shim after its own parse, read back through the shim's parser. a row per
// invite with its keys; the main one lives a year and is made again at six
// months, a one-time one lives seven days and goes on its first opener. the
// developer's main invite never expires (DECIDED 2026-10-28)

import 'dart:convert';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'identities.dart';
import 'signal_ffi/kryfo_signal.dart';
import 'signal_session.dart';

/// what an invite is for
const kInviteMain = 'main';
const kInviteOneTime = 'one_time';
const kInviteRoster = 'roster';

/// lives, in hours (question 13)
const kOneTimeHours = 7 * 24;
const kMainHours = 365 * 24;
const kMainReissueHours = 183 * 24;

/// the skew a reader allows both ways, and the grace an owner gives an
/// expired invite's first contacts
const kSkewHours = 24;

/// the link a v4 invite travels in
const kInviteLinkPrefix = 'kryfo://share?v=4&i=';

/// unix hours, as KIN4 counts time
int unixHours([int? nowMs]) =>
    (nowMs ?? DateTime.now().millisecondsSinceEpoch) ~/ 3600000;

/// the main identity's face on its invites: the onion service key, the
/// legacy ed key F and a signature by F (the engine holds it)
class InviteFace {
  const InviteFace({
    required this.onionKey,
    required this.face,
    required this.sign,
  });
  final Uint8List onionKey;
  final Uint8List face;
  // F's ed25519 signature over [msg]
  final Uint8List Function(Uint8List msg) sign;
}

/// one invite of mine, as its row keeps it
class InviteRow {
  const InviteRow({
    required this.ident,
    required this.id,
    required this.kind,
    required this.issued,
    required this.expires,
    required this.link,
    this.qr,
    this.usedAt,
    this.retiredAt,
    this.spkId,
    this.kyberId,
    this.ecId,
    this.neverExpires = false,
  });

  final int ident;
  // 16 bytes, hex
  final String id;
  final String kind;
  // unix hours
  final int issued;
  final int expires;
  // the signed KIN4 with its bundle, and the main one's without (the qr)
  final Uint8List link;
  final Uint8List? qr;
  final int? usedAt;
  final int? retiredAt;
  final int? spkId;
  final int? kyberId;
  final int? ecId;
  final bool neverExpires;

  bool get oneTime => kind == kInviteOneTime;

  /// whether a first contact naming it is still opened at [nowH]: before
  /// its expiry and a day of grace, unused when one-time, and always for
  /// one that never expires
  bool openAt(int nowH) =>
      usedAt == null &&
      retiredAt == null &&
      (neverExpires || nowH <= expires + kSkewHours);

  static InviteRow of(Map<String, Object?> r) => InviteRow(
    ident: r['ident'] as int,
    id: r['id'] as String,
    kind: r['kind'] as String,
    issued: r['issued'] as int,
    expires: r['expires'] as int,
    link: Uint8List.fromList(r['link'] as List<int>),
    qr: r['qr'] == null ? null : Uint8List.fromList(r['qr'] as List<int>),
    usedAt: r['used_at'] as int?,
    retiredAt: r['retired_at'] as int?,
    spkId: r['spk_id'] as int?,
    kyberId: r['kyber_id'] as int?,
    ecId: r['ec_id'] as int?,
    neverExpires: (r['never_expires'] as int? ?? 0) == 1,
  );
}

class _Out {
  final _b = BytesBuilder(copy: false);
  void bytes(List<int> v) => _b.add(v);
  void u8(int v) => _b.addByte(v);
  void u16(int v) => _b.add([(v >> 8) & 0xff, v & 0xff]);
  void u32(int v) =>
      _b.add([(v >> 24) & 0xff, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff]);
  Uint8List done() => _b.toBytes();
}

void _need(List<int> v, int n, String what) {
  if (v.length != n) throw ArgumentError('$what is $n bytes');
}

/// a bundle block on the frame's identity, device 1 (a phone: DECIDED
/// 2026-10-28), with an ec prekey when [ec] is given
Uint8List bundleBlock({
  required int registrationId,
  required LsPreKey spk,
  required LsPreKey kyber,
  LsPreKey? ec,
}) {
  _need(spk.public, 33, 'a signed prekey');
  _need(kyber.public, 1569, 'a kyber prekey');
  final o = _Out()
    ..u32(registrationId)
    ..u8(1)
    ..u8(ec == null ? 0 : 2)
    ..u32(spk.id)
    ..bytes(spk.public)
    ..bytes(spk.signature)
    ..u32(kyber.id)
    ..bytes(kyber.public)
    ..bytes(kyber.signature);
  if (ec != null) {
    _need(ec.public, 33, 'an ec prekey');
    o
      ..u32(ec.id)
      ..bytes(ec.public);
  }
  return o.done();
}

/// "kryfo-face-v4:" || I || the invite id: what a face signs (2.1, 3.1)
Uint8List faceText(List<int> identity, List<int> inviteId) =>
    Uint8List.fromList([
      ...utf8.encode('kryfo-face-v4:'),
      ...identity,
      ...inviteId,
    ]);

/// a KIN4 body without its signature, laid out as 2.1 has it
Uint8List kin4Body({
  required bool oneTime,
  required int issued,
  required int expires,
  required List<int> id,
  required List<int> identity,
  required List<int> firstContact,
  List<int>? onion,
  (List<int>, List<int>)? face,
  List<int>? block,
}) {
  _need(id, 16, 'an invite id');
  _need(identity, 33, 'an identity key');
  _need(firstContact, 32, 'a first-contact key');
  final flags =
      (oneTime ? kLsInviteOneTime : 0) |
      (block != null ? kLsInviteBundle : 0) |
      (onion != null ? kLsInviteOnion : 0) |
      (face != null ? kLsInviteFace : 0);
  final o = _Out()
    ..bytes(ascii.encode('KIN4'))
    ..u8(1)
    ..u16(flags)
    ..u32(issued)
    ..u32(expires)
    ..bytes(id)
    ..bytes(identity)
    ..bytes(firstContact);
  if (onion != null) {
    _need(onion, 32, 'an onion key');
    o.bytes(onion);
  }
  if (face != null) {
    _need(face.$1, 32, 'a face key');
    _need(face.$2, 64, 'a face signature');
    o
      ..bytes(face.$1)
      ..bytes(face.$2);
  }
  if (block != null) o.bytes(block);
  return o.done();
}

/// a KHL1 body without its signature (3.3): the invite id answered (all
/// zero for a v3 link), the owner's identity key and my signed one-time
/// invite
Uint8List khl1Body({
  required List<int> answers,
  required List<int> owner,
  required List<int> invite,
}) {
  _need(answers, 16, 'an invite id');
  _need(owner, 33, 'an identity key');
  return (_Out()
        ..bytes(ascii.encode('KHL1'))
        ..u8(1)
        ..bytes(answers)
        ..bytes(owner)
        ..bytes(invite))
      .done();
}

/// [body] signed under [context] by [ss]'s identity, then read back through
/// the shim's parser: what goes out is what a reader takes
Uint8List signedFrame(SignalSession ss, LsSigContext context, Uint8List body) {
  final sig = ss.lib.sign(ss.identity, context, body);
  return Uint8List.fromList([...body, ...sig]);
}

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List _unhex(String h) => Uint8List.fromList([
  for (var i = 0; i + 1 < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
]);

/// a new invite of [ss]'s identity: its keys, its first-contact key and its
/// row, in one go. [fcPkOf] is the engine's public half of a first-contact
/// key (an error string for one that does not lift). [face] for the main
/// identity's main invite only
Future<InviteRow> makeInvite(
  Database db,
  SignalSession ss, {
  required String kind,
  required String Function(Uint8List sk) fcPkOf,
  InviteFace? face,
  bool neverExpires = false,
  int? nowMs,
  Random? random,
}) async {
  final r = random ?? Random.secure();
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final oneTime = kind == kInviteOneTime;
  if (face != null && (kind == kInviteRoster || ss.ident != kMainIdent)) {
    throw ArgumentError('only the main identity shows its face');
  }
  late Uint8List id;
  do {
    id = Uint8List.fromList(List.generate(16, (_) => r.nextInt(256)));
  } while (id.every((b) => b == 0));
  final idHex = _hex(id);
  final issued = unixHours(now);
  final expires = issued + (oneTime ? kOneTimeHours : kMainHours);
  final sk = await makeFcKey(
    db,
    ss.ident,
    idHex,
    (sk) => !fcPkOf(sk).startsWith('error'),
  );
  final fc = _unhex(fcPkOf(sk));
  final keys = await ss.makeInviteKeys(idHex, ec: oneTime, now: now);
  final identity = ss.identity.public;
  (List<int>, List<int>)? f;
  if (face != null) f = (face.face, face.sign(faceText(identity, id)));
  final block = bundleBlock(
    registrationId: ss.registrationId,
    spk: keys.spk,
    kyber: keys.kyber,
    ec: keys.ec,
  );
  Uint8List frame(List<int>? withBlock) => signedFrame(
    ss,
    LsSigContext.invite,
    kin4Body(
      oneTime: oneTime,
      issued: issued,
      expires: expires,
      id: id,
      identity: identity,
      firstContact: fc,
      onion: face?.onionKey,
      face: f,
      block: withBlock,
    ),
  );
  final link = frame(block);
  // the qr form: the same invite without its bundle, signed on its own
  final qr = kind == kInviteMain ? frame(null) : null;
  // both read as a reader reads them
  ss.lib.parseInvite(link);
  if (qr != null) ss.lib.parseInvite(qr);
  final row = InviteRow(
    ident: ss.ident,
    id: idHex,
    kind: kind,
    issued: issued,
    expires: expires,
    link: link,
    qr: qr,
    spkId: keys.spk.id,
    kyberId: keys.kyber.id,
    ecId: keys.ec?.id,
    neverExpires: neverExpires,
  );
  await db.insert('invites', {
    'ident': row.ident,
    'id': row.id,
    'kind': row.kind,
    'issued': row.issued,
    'expires': row.expires,
    'link': row.link,
    'qr': row.qr,
    'spk_id': row.spkId,
    'kyber_id': row.kyberId,
    'ec_id': row.ecId,
    'never_expires': neverExpires ? 1 : 0,
  });
  return row;
}

/// [ident]'s invites, every kind or one
Future<List<InviteRow>> invitesOf(
  DatabaseExecutor db,
  int ident, {
  String? kind,
}) async => [
  for (final r in await db.query(
    'invites',
    where: kind == null ? 'ident = ?' : 'ident = ? AND kind = ?',
    whereArgs: kind == null ? [ident] : [ident, kind],
    orderBy: 'issued',
  ))
    InviteRow.of(r),
];

/// the invite of [ident] with id [idHex], null with none
Future<InviteRow?> inviteOf(
  DatabaseExecutor db,
  int ident,
  String idHex,
) async {
  final rows = await db.query(
    'invites',
    where: 'ident = ? AND id = ?',
    whereArgs: [ident, idHex],
    limit: 1,
  );
  return rows.isEmpty ? null : InviteRow.of(rows.first);
}

/// the main invite handed out now: the newest live one
Future<InviteRow?> currentMainInvite(DatabaseExecutor db, int ident) async {
  final all = await invitesOf(db, ident, kind: kInviteMain);
  for (final r in all.reversed) {
    if (r.retiredAt == null) return r;
  }
  return null;
}

/// a one-time invite took its first opener: its keys and its address go,
/// so a forwarded copy reaches nothing (2.3)
Future<void> spendOneTime(
  Database db,
  SignalSession ss,
  InviteRow row, {
  int? nowMs,
}) async {
  if (!row.oneTime) return;
  await ss.dropInviteKeys(
    spkId: row.spkId,
    kyberId: row.kyberId,
    ecId: row.ecId,
  );
  await db.update(
    'invites',
    {'used_at': nowMs ?? DateTime.now().millisecondsSinceEpoch},
    where: 'ident = ? AND id = ?',
    whereArgs: [row.ident, row.id],
  );
  await db.delete(
    'fc_keys',
    where: 'ident = ? AND invite_id = ?',
    whereArgs: [row.ident, row.id],
  );
}

/// an invite past its expiry and a day of grace, or a one-time one used:
/// its keys, its first-contact key and its row go (R23). never one that
/// never expires
Future<void> dropInvite(Database db, SignalSession ss, InviteRow row) async {
  if (row.neverExpires) return;
  await ss.dropInviteKeys(
    spkId: row.spkId,
    kyberId: row.kyberId,
    ecId: row.ecId,
  );
  await db.delete(
    'fc_keys',
    where: 'ident = ? AND invite_id = ?',
    whereArgs: [row.ident, row.id],
  );
  await db.delete(
    'invites',
    where: 'ident = ? AND id = ?',
    whereArgs: [row.ident, row.id],
  );
}

/// what keeping [ss]'s invites did
class InviteUpkeep {
  InviteUpkeep();
  // the main invite made now, when one was
  InviteRow? made;
  // invites whose keys and address went
  final dropped = <String>[];
  // the legacy v3 invite's keys went with them
  bool legacyGone = false;
}

/// the invites of [ss]'s identity kept as 2.3 says: a main one made when
/// there is none, made again at six months (the old one is answered until
/// it expires), and every invite past its expiry and a day of grace gone
/// with its keys. the v3 invite's keys (signed 1, kyber 1, ec 999999)
/// count as the first main invite's predecessor: they go once a v4 main
/// invite has stood for a year and a day. [dev]: the developer's phone,
/// whose main invite is made once and never replaced or dropped
Future<InviteUpkeep> keepInvites(
  Database db,
  SignalSession ss, {
  required String Function(Uint8List sk) fcPkOf,
  InviteFace? face,
  bool dev = false,
  int? nowMs,
}) async {
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final h = unixHours(now);
  final out = InviteUpkeep();
  final mains = await invitesOf(db, ss.ident, kind: kInviteMain);
  final live = mains.where((r) => r.retiredAt == null).toList();
  final made = await _mainMade(db, ss.ident);
  if (dev) {
    // made once (11 step 4), never replaced, never dropped: a phone that
    // made it and lost it makes none, so the pinned card is never silently
    // replaced
    if (mains.isEmpty && !made) {
      out.made = await makeInvite(
        db,
        ss,
        kind: kInviteMain,
        fcPkOf: fcPkOf,
        face: face,
        neverExpires: true,
        nowMs: now,
      );
    }
  } else if (live.isEmpty ||
      (!live.last.neverExpires && h >= live.last.issued + kMainReissueHours)) {
    out.made = await makeInvite(
      db,
      ss,
      kind: kInviteMain,
      fcPkOf: fcPkOf,
      face: face,
      nowMs: now,
    );
    // the one it replaces is answered until it expires, and no longer
    // handed out
    for (final r in live) {
      await db.update(
        'invites',
        {'retired_at': now},
        where: 'ident = ? AND id = ?',
        whereArgs: [r.ident, r.id],
      );
    }
  }
  if (out.made != null && !made) await _noteMainMade(db, ss.ident, now);
  for (final r in await invitesOf(db, ss.ident)) {
    if (r.neverExpires) continue;
    final gone = r.usedAt != null || h > r.expires + kSkewHours;
    if (!gone) continue;
    await dropInvite(db, ss, r);
    out.dropped.add(r.id);
  }
  // the v3 invite's keys: the first v4 main invite's predecessor
  if (!dev && ss.ident == kMainIdent) {
    final first = mains.isEmpty ? out.made : mains.first;
    if (first != null &&
        !first.neverExpires &&
        h > first.issued + kMainHours + kSkewHours) {
      out.legacyGone = await ss.dropLegacyInviteKeys();
    }
  }
  return out;
}

// 11 step 4 ran: a main v4 invite was made once. kept in the store's
// meta, which every later migration and the phone's own backup keep
String _mainMadeKey(int ident) =>
    ident == kMainIdent ? 'kin4_main_made' : 'i$ident:kin4_main_made';

Future<bool> _mainMade(DatabaseExecutor db, int ident) async => (await db.query(
  'signal_meta',
  where: 'k = ?',
  whereArgs: [_mainMadeKey(ident)],
  limit: 1,
)).isNotEmpty;

Future<void> _noteMainMade(DatabaseExecutor db, int ident, int at) => db.insert(
  'signal_meta',
  {'k': _mainMadeKey(ident), 'v': '$at'},
  conflictAlgorithm: ConflictAlgorithm.ignore,
);

/// why a reader turns an invite away (2.3, 3.4)
enum InviteFault {
  // does not parse, a key in another form, a signature that does not hold
  damaged,
  // issued more than a day ahead of this phone's clock
  notYet,
  // expired more than a day ago
  expired,
}

class InviteRefused implements Exception {
  const InviteRefused(this.fault);
  final InviteFault fault;
  @override
  String toString() => 'InviteRefused(${fault.name})';
}

/// [bytes] as a reader takes them: the shim's parse and every signature,
/// then the times with a day of skew both ways. [timeless] reads the
/// pinned developer card, carried as the dev chat carries it, without them
LsInvite readInvite(
  KryfoSignal lib,
  List<int> bytes, {
  int? nowMs,
  bool timeless = false,
}) {
  final LsInvite inv;
  try {
    inv = lib.parseInvite(bytes);
  } on LsError {
    throw const InviteRefused(InviteFault.damaged);
  }
  if (timeless) return inv;
  final h = unixHours(nowMs);
  if (inv.issued > h + kSkewHours) {
    throw const InviteRefused(InviteFault.notYet);
  }
  if (inv.expires + kSkewHours < h) {
    throw const InviteRefused(InviteFault.expired);
  }
  return inv;
}

/// the link of a signed KIN4
String inviteLink(List<int> kin4) =>
    kInviteLinkPrefix + base64Url.encode(kin4).replaceAll('=', '');

/// the KIN4 a v4 link carries, null for anything else. one link, the two
/// parts once each, base64url without padding
Uint8List? inviteOfLink(String raw) {
  raw = raw.trim();
  if (!raw.startsWith('kryfo://share?') || raw.contains(RegExp(r'\s'))) {
    return null;
  }
  try {
    final uri = Uri.parse(raw);
    final all = uri.queryParametersAll;
    if (all.length != 2 || all.values.any((v) => v.length != 1)) return null;
    if (uri.queryParameters['v'] != '4') return null;
    final i = uri.queryParameters['i'];
    if (i == null || i.isEmpty || i.contains('=')) return null;
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(i)) return null;
    final pad = (4 - i.length % 4) % 4;
    if (pad == 3) return null;
    final b = base64Url.decode(i + '=' * pad);
    // one encoding per invite: the link it gives back is the one read
    if (inviteLink(b) != '$kInviteLinkPrefix$i') return null;
    return b;
  } catch (_) {
    return null;
  }
}

/// whether [raw] is a v4 invite link at all, read or not
bool isV4Link(String raw) {
  final t = raw.trim();
  if (!t.startsWith('kryfo://share?')) return false;
  try {
    return Uri.parse(t).queryParameters['v'] == '4';
  } catch (_) {
    return false;
  }
}

/// how long a hello's hash is kept, so a copy is taken once (3.3 rule 5)
const kHelloSeenDays = 16;

/// a hello's name in the seen store
String helloHash(List<int> hello) => sha256.convert(hello).toString();

/// a hello of [ss]'s identity answering invite [answers] (all zero for a
/// v3 link) of [owner]: a fresh one-time invite of mine with its bundle,
/// inside a KHL1 signed by me and read back by the shim. the hello and the
/// one-time invite it carries
Future<(Uint8List, InviteRow)> makeHello(
  Database db,
  SignalSession ss, {
  required List<int> answers,
  required List<int> owner,
  required String Function(Uint8List sk) fcPkOf,
  InviteFace? face,
  int? nowMs,
}) async {
  final once = await makeInvite(
    db,
    ss,
    kind: kInviteOneTime,
    fcPkOf: fcPkOf,
    face: face,
    nowMs: nowMs,
  );
  final hello = signedFrame(
    ss,
    LsSigContext.hello,
    khl1Body(answers: answers, owner: owner, invite: once.link),
  );
  ss.lib.parseHello(hello);
  return (hello, once);
}

/// why a hello is dropped (3.3); nothing of it is shown or kept
enum HelloFault { shape, invite, answers, seal, used, seen }

/// [bytes] as an owner takes a hello at invite [at] of mine (null: my v3
/// first-contact address, which takes only zero answers), sealed with
/// [sealPk]: the five rules of 3.3. [mine] is my identity key; [sealOf]
/// the hello seal key my identity wants from a sender x key
({LsHello? hello, HelloFault? fault}) checkHello(
  KryfoSignal lib,
  List<int> bytes, {
  required InviteRow? at,
  required List<int> mine,
  required String sealPk,
  required String Function(String senderX) sealOf,
  required bool seen,
  int? nowMs,
}) {
  final LsHello h;
  try {
    // rule 1 and the shape of rule 2: the shim checks the signature, the
    // inner invite's, its bundle and that it is one-time
    h = lib.parseHello(bytes);
  } catch (_) {
    return (hello: null, fault: HelloFault.shape);
  }
  try {
    readInvite(lib, h.inviteBytes, nowMs: nowMs);
  } on InviteRefused {
    return (hello: null, fault: HelloFault.invite);
  }
  final zero = h.answers.every((b) => b == 0);
  // rule 3: one of my invites, live, and mine; zero only on the v3 address
  if (at == null
      ? !zero
      : zero || _hexB(h.answers) != at.id || !at.openAt(unixHours(nowMs))) {
    return (hello: null, fault: HelloFault.answers);
  }
  if (!_eqB(h.owner, mine)) return (hello: null, fault: HelloFault.answers);
  // rule 4: the seal is the hello seal key of the invite's answering key
  // and the sender
  final want = sealOf(_hexB(h.invite.identity.sublist(1)));
  if (want.startsWith('error') || want != sealPk.toLowerCase()) {
    return (hello: null, fault: HelloFault.seal);
  }
  // rule 5
  if (at != null && at.oneTime && at.usedAt != null) {
    return (hello: null, fault: HelloFault.used);
  }
  if (seen) return (hello: null, fault: HelloFault.seen);
  return (hello: h, fault: null);
}

/// whether [hash] was seen by [ident] in the last 16 days; older ones go
Future<bool> helloSeen(
  DatabaseExecutor db,
  int ident,
  String hash, {
  int? nowMs,
}) async {
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  await db.delete(
    'hello_seen',
    where: 'at < ?',
    whereArgs: [now - kHelloSeenDays * 24 * 3600 * 1000],
  );
  return (await db.query(
    'hello_seen',
    where: 'ident = ? AND hash = ?',
    whereArgs: [ident, hash],
    limit: 1,
  )).isNotEmpty;
}

Future<void> noteHelloSeen(
  DatabaseExecutor db,
  int ident,
  String hash, {
  int? nowMs,
}) => db.insert('hello_seen', {
  'ident': ident,
  'hash': hash,
  'at': nowMs ?? DateTime.now().millisecondsSinceEpoch,
}, conflictAlgorithm: ConflictAlgorithm.ignore);

/// crossed hellos (3.4b, R22): with my hello to them out and theirs in,
/// the one whose sender key is smaller as bytes is answered. true when
/// theirs is the one to answer
bool answerTheirs(List<int> mine, List<int> theirs) {
  for (var i = 0; i < mine.length && i < theirs.length; i++) {
    if (theirs[i] != mine[i]) return theirs[i] < mine[i];
  }
  return theirs.length < mine.length;
}

String _hexB(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

bool _eqB(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
