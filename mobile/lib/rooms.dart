// SPDX-License-Identifier: GPL-3.0-or-later
// burner room helpers with no io in them: the link, the short tag a room
// key is shown as, the countdown wording and its colour thresholds.

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
    return d.inDays == 1 ? '24h' : '${d.inDays}d';
  }
  return '${d.inHours}h';
}

// "disappears in 24 hours" for the banner. plain words, not a timer. a
// joiner sees what is actually left, which can be minutes.
String expiryWords(Duration d) {
  if (d.inDays >= 1 && d.inHours % 24 == 0) {
    return d.inDays == 1 ? '24 hours' : '${d.inDays} days';
  }
  if (d.inDays >= 1) return '${d.inDays} days';
  if (d.inHours >= 1) {
    final exact = d.inMinutes % 60 == 0;
    if (d.inHours == 1) return exact ? 'an hour' : 'about an hour';
    return exact ? '${d.inHours} hours' : 'about ${d.inHours} hours';
  }
  if (d.inMinutes >= 2) return '${d.inMinutes} minutes';
  return 'a minute';
}

// what the header and the list row show. days and hours while there is
// time, minutes under an hour, seconds only in the last five minutes.
String countdownLabel(Duration left) {
  if (left.isNegative) return 'expired';
  if (left.inDays >= 1) {
    final h = left.inHours % 24;
    return h == 0 ? '${left.inDays}d' : '${left.inDays}d ${h}h';
  }
  if (left.inHours >= 1) {
    final m = left.inMinutes % 60;
    return m == 0 ? '${left.inHours}h' : '${left.inHours}h ${m}m';
  }
  if (left.inMinutes >= 5) return '${left.inMinutes}m';
  final s = (left.inSeconds % 60).toString().padLeft(2, '0');
  return '${left.inMinutes}:$s';
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

// a room key on screen. six characters is enough to tell two people apart
// inside one small room, and it says nothing about who they are.
String roomTag(String pub) => pub.length >= 6 ? pub.substring(0, 6) : pub;

bool looksLikeRoomKey(String id) =>
    id.length == 64 && RegExp(r'^[0-9a-f]+$').hasMatch(id);

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
      final name = (u.queryParameters['n'] ?? '').trim();
      return RoomLink(
        roomId: id,
        name: name.isEmpty ? 'room' : name,
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
