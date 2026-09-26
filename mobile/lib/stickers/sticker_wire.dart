// SPDX-License-Identifier: GPL-3.0-or-later
// a sticker on the wire: 'st' in the envelope, "pack:id:since". it names a
// sticker and nothing else; each phone draws it from its own pack. 'm'
// beside it is the sticker's emoji, which is what an app without stickers
// shows.
import 'sticker_pack.dart';

class StickerWire {
  final StickerRef ref;
  // the pack version that brought this sticker in: a constant of the
  // sticker, never the sender's installed version
  final int since;
  const StickerWire(this.ref, this.since);

  static final _re = RegExp(
    r'^([a-z][a-z0-9]{0,15}):([1-9][0-9]{0,3}):([1-9][0-9]{0,2})$',
  );

  /// null unless [v] is exactly "pack:id:since"
  static StickerWire? parse(Object? v) {
    if (v is! String) return null;
    final m = _re.firstMatch(v);
    if (m == null) return null;
    return StickerWire(
      StickerRef(m.group(1)!, int.parse(m.group(2)!)),
      int.parse(m.group(3)!),
    );
  }

  static StickerWire of(StickerPack pack, Sticker s) =>
      StickerWire(StickerRef(pack.name, s.id), s.since);

  String get value => '${ref.pack}:${ref.id}:$since';

  @override
  bool operator ==(Object other) =>
      other is StickerWire && other.ref == ref && other.since == since;

  @override
  int get hashCode => Object.hash(ref, since);

  @override
  String toString() => value;
}

/// the text a received sticker's row keeps. a sticker in our pack: our own
/// emoji for it, never the sender's words. one we do not have: the sender's
/// 'm' only if it is exactly one emoji, else nothing.
String stickerText(StickerWire w, String sent, StickerPack? pack) {
  final s = pack != null && pack.name == w.ref.pack
      ? pack.sticker(w.ref.id)
      : null;
  if (s != null) return s.emoji;
  return isOneEmoji(sent) ? sent : '';
}

/// whether [s] is exactly one emoji: a pictograph with its presentation
/// selector, skin tone or tags, a flag, a keycap, or a zwj sequence of them.
/// no letters, digits or words get through.
bool isOneEmoji(String s) {
  // the longest real sequences are about a dozen code points
  if (s.isEmpty || s.length > 40) return false;
  final r = s.runes.toList();
  var i = _emojiElement(r, 0);
  while (i > 0 && i < r.length && r[i] == 0x200D) {
    i = _emojiElement(r, i + 1);
  }
  return i == r.length;
}

// one element of an emoji from [i]: the index after it, or -1
int _emojiElement(List<int> r, int i) {
  if (i >= r.length) return -1;
  final c = r[i];
  if (_regional(c)) {
    return i + 1 < r.length && _regional(r[i + 1]) ? i + 2 : -1;
  }
  if (c == 0x23 || c == 0x2A || (c >= 0x30 && c <= 0x39)) {
    var j = i + 1;
    if (j < r.length && r[j] == 0xFE0F) j++;
    return j < r.length && r[j] == 0x20E3 ? j + 1 : -1;
  }
  if (!_pictograph(c)) return -1;
  var j = i + 1;
  if (j < r.length && r[j] == 0xFE0F) j++;
  if (j < r.length && _skinTone(r[j])) j++;
  // a subdivision flag: tag letters, closed by the cancel tag
  if (j < r.length && _tag(r[j])) {
    while (j < r.length && _tag(r[j])) {
      j++;
    }
    if (j >= r.length || r[j] != 0xE007F) return -1;
    j++;
  }
  return j;
}

bool _regional(int c) => c >= 0x1F1E6 && c <= 0x1F1FF;
bool _skinTone(int c) => c >= 0x1F3FB && c <= 0x1F3FF;
bool _tag(int c) => c >= 0xE0020 && c <= 0xE007E;

// the code points emoji are made of, outside the big pictograph planes
const _pictographRanges = <(int, int)>[
  (0x00A9, 0x00A9),
  (0x00AE, 0x00AE),
  (0x203C, 0x203C),
  (0x2049, 0x2049),
  (0x2122, 0x2122),
  (0x2139, 0x2139),
  (0x2194, 0x2199),
  (0x21A9, 0x21AA),
  (0x231A, 0x231B),
  (0x2328, 0x2328),
  (0x23CF, 0x23CF),
  (0x23E9, 0x23F3),
  (0x23F8, 0x23FA),
  (0x24C2, 0x24C2),
  (0x25AA, 0x25AB),
  (0x25B6, 0x25B6),
  (0x25C0, 0x25C0),
  (0x25FB, 0x25FE),
  (0x2600, 0x27BF),
  (0x2934, 0x2935),
  (0x2B05, 0x2B07),
  (0x2B1B, 0x2B1C),
  (0x2B50, 0x2B50),
  (0x2B55, 0x2B55),
  (0x3030, 0x3030),
  (0x303D, 0x303D),
  (0x3297, 0x3297),
  (0x3299, 0x3299),
];

bool _pictograph(int c) {
  if (c >= 0x1F000 && c <= 0x1FAFF) return !_regional(c) && !_skinTone(c);
  for (final (lo, hi) in _pictographRanges) {
    if (c < lo) return false;
    if (c <= hi) return true;
  }
  return false;
}
