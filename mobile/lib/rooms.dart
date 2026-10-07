import 'dart:convert';

import 'bidi_safe.dart';
import 'dlog.dart';
import 'l10n/l10n.dart';
import 'l10n/numbers.dart';
// SPDX-License-Identifier: GPL-3.0-or-later
// burner room helpers with no io in them: the link, the short tag a room
// key is shown as, the countdown wording and its colour thresholds, and
// what a frame loses before it leaves.

const roomExpiryOptions = <Duration>[
  Duration(hours: 1),
  Duration(hours: 24),
  Duration(days: 7),
];
const roomDefaultExpiry = Duration(hours: 24);
const roomCapOptions = <int>[5, 10, 25];
const roomDefaultCap = 10;

String expiryLabel(Duration d) {
  if (d.inDays >= 1 && d.inHours % 24 == 0) {
    return d.inDays == 1 ? l10n.rooms24h : l10n.roomsD(whole(d.inDays));
  }
  return l10n.roomsH(whole(d.inHours));
}

// "disappears in 24 hours" for the banner. plain words, not a timer. a
// joiner sees what is actually left, which can be minutes.
String expiryWords(Duration d) {
  if (d.inDays >= 1 && d.inHours % 24 == 0) {
    return d.inDays == 1 ? l10n.rooms24Hours : l10n.roomsDays(d.inDays);
  }
  if (d.inDays >= 1) return l10n.roomsDays(d.inDays);
  if (d.inHours >= 1) {
    final exact = d.inMinutes % 60 == 0;
    if (d.inHours == 1) return exact ? l10n.roomsAnHour : l10n.roomsAboutAnHour;
    return exact ? l10n.roomsHours(d.inHours) : l10n.roomsAboutHours(d.inHours);
  }
  if (d.inMinutes >= 2) return l10n.roomsMinutes(d.inMinutes);
  return l10n.roomsAMinute;
}

// what the header and the list row show. days and hours while there is
// time, minutes under an hour, seconds only in the last five minutes.
String countdownLabel(Duration left) {
  if (left.isNegative) return l10n.roomsExpired;
  if (left.inDays >= 1) {
    final h = left.inHours % 24;
    return h == 0
        ? l10n.roomsD(whole(left.inDays))
        : l10n.roomsDH(whole(left.inDays), whole(h));
  }
  if (left.inHours >= 1) {
    final m = left.inMinutes % 60;
    return m == 0
        ? l10n.roomsH(whole(left.inHours))
        : l10n.roomsHM(whole(left.inHours), whole(m));
  }
  if (left.inMinutes >= 5) return l10n.roomsM(whole(left.inMinutes));
  return '${whole(left.inMinutes)}:${twoDigits(left.inSeconds % 60)}';
}

enum CountdownTone { calm, amber, rose }

CountdownTone countdownTone(Duration left) {
  if (left.inMinutes < 5) return CountdownTone.rose;
  if (left.inHours < 1) return CountdownTone.amber;
  return CountdownTone.calm;
}

// how often the header needs a fresh number
Duration countdownTick(Duration left) => left.inMinutes < 5
    ? const Duration(seconds: 1)
    : const Duration(minutes: 1);

// how long a joiner waits for the creator's roster before the room says it
// is not answering: two relay publishes at their longest (55 s each, one
// each way) and the creator's phone taking the join in between. a roster
// that comes later still lets the joiner in
const kRoomJoinWait = Duration(minutes: 2);

enum RoomJoin { live, waiting, silent }

/// where a join stands. [joiningAt] is when the join went out, null once
/// the creator's roster named this phone's key
RoomJoin roomJoinState(int? joiningAt, int now) {
  if (joiningAt == null || joiningAt <= 0) return RoomJoin.live;
  final waited = now - joiningAt;
  return waited >= 0 && waited < kRoomJoinWait.inMilliseconds
      ? RoomJoin.waiting
      : RoomJoin.silent;
}

// a room key on screen. six characters is enough to tell two people apart
// inside one small room, and it says nothing about who they are.
String roomTag(String pub) => pub.length >= 6 ? pub.substring(0, 6) : pub;

bool looksLikeRoomKey(String id) =>
    id.length == 64 && RegExp(r'^[0-9a-f]+$').hasMatch(id);

// what a room frame may not carry: the onion, the signing key, the push
// endpoint, the badge and the roster's keys
const _roomStripped = ['o', 'e', 'p', 'bg', 'rp'];

/// [wrapped] with every trace of who sent it gone and the room key [pub] in
/// its place. null when it cannot be done, and the send has to be dropped:
/// the frame it could not rewrite still carries the real onion, the kryfo
/// id and the push endpoint, which is the one thing a burner room exists to
/// withhold. the message itself ('m', 'st', 'u', 'q' and the rest) stays.
/// [number] is the frame's place on its sender's lane, see [roomFramePlace]
String? roomFrame(String wrapped, String pub, {int? number}) {
  const prefix = 'halo/1:';
  if (!wrapped.startsWith(prefix)) {
    dlog('room: frame is not halo/1, not sending it');
    return null;
  }
  try {
    final j =
        jsonDecode(wrapped.substring(prefix.length)) as Map<String, dynamic>;
    j['h'] = pub;
    j['x'] = pub;
    for (final k in _roomStripped) {
      j.remove(k);
    }
    if (number != null) j['rn'] = number;
    final out = '$prefix${jsonEncode(j)}';
    // read it back: the fields have to be gone, whatever the encoder did
    final check = jsonDecode(out.substring(prefix.length)) as Map;
    for (final k in _roomStripped) {
      if (check.containsKey(k)) {
        dlog('room: $k survived the strip, not sending it');
        return null;
      }
    }
    return out;
  } catch (e) {
    dlog('room: could not strip the frame, not sending it');
    return null;
  }
}

/// what a catch-up needs of a room frame to put it back in order: the
/// number its sender gave it, counting up from one in each room, and
/// whether it is a leave or a removal, which takes keys off the roster.
/// a frame with no number, from an older version, keeps where it came
({int? number, bool shrinks}) roomFramePlace(String content) {
  const prefix = 'halo/1:';
  if (!content.startsWith(prefix)) return (number: null, shrinks: false);
  try {
    final j = jsonDecode(content.substring(prefix.length));
    if (j is! Map) return (number: null, shrinks: false);
    final n = j['rn'];
    final gc = j['gc'];
    final t = gc is Map ? gc['t'] : null;
    return (
      number: n is int && n > 0 ? n : null,
      shrinks: t == 'leave' || t == 'remove',
    );
  } catch (_) {
    return (number: null, shrinks: false);
  }
}

class RoomLink {
  final String roomId;
  final String name;
  final int expiresAt; // ms since epoch
  final String creatorPub;
  final String fcPk;
  final int? cap;
  const RoomLink({
    required this.roomId,
    required this.name,
    required this.expiresAt,
    required this.creatorPub,
    required this.fcPk,
    this.cap,
  });

  String encode() {
    final q = <String, String>{
      'id': roomId,
      'n': name,
      'exp': '$expiresAt',
      'pub': creatorPub,
      'fc': fcPk,
      if (cap != null) 'cap': '$cap',
    };
    return Uri(scheme: 'kryfo', host: 'room', queryParameters: q).toString();
  }

  static RoomLink? parse(String raw) {
    raw = raw.trim();
    if (!raw.startsWith('kryfo://room')) return null;
    try {
      final u = Uri.parse(raw);
      final id = u.queryParameters['id'];
      final pub = u.queryParameters['pub'];
      final fc = u.queryParameters['fc'];
      final exp = int.tryParse(u.queryParameters['exp'] ?? '');
      if (id == null ||
          id.isEmpty ||
          pub == null ||
          fc == null ||
          exp == null) {
        return null;
      }
      if (!looksLikeRoomKey(pub) || fc.length != 64) return null;
      final name = unmarked(u.queryParameters['n'] ?? '').trim();
      return RoomLink(
        roomId: id,
        name: name.isEmpty ? l10n.homeRoom : name,
        expiresAt: exp,
        creatorPub: pub,
        fcPk: fc,
        cap: int.tryParse(u.queryParameters['cap'] ?? ''),
      );
    } catch (_) {
      return null;
    }
  }
}

// a kryfo link inside whatever it arrived in. people paste the whole
// message, "join us kryfo://room?...", and both parsers want the link alone.
final _kryfoLink = RegExp(r'kryfo://(?:room|share)\?[^\s]+');

/// the first kryfo link in [text], or null
String? firstKryfoLink(String text) => _kryfoLink.firstMatch(text)?.group(0);

/// every kryfo link in [text] with where it sits, for drawing them tappable
Iterable<RegExpMatch> kryfoLinksIn(String text) => _kryfoLink.allMatches(text);
