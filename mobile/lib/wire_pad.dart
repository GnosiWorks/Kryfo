// SPDX-License-Identifier: GPL-3.0-or-later
// every frame is filled out to one of a few sizes inside its encryption, so
// its length on the wire says nothing about what it holds. the filler is a
// "pz" field of zeros put first in the json: versions without it read past
// a field they do not know. a frame always fills the same way, so a copy
// sent again is still the same bytes.

import 'dart:convert';

const kPadField = 'pz';

// plaintext bytes a signal seal is filled to. each is the most that keeps
// a plain message and an opener on one gift wrap size (3949, 8729, 27841,
// 55149 and 76993 bytes) and one count of tor cells. the fourth holds a
// media slice, the last is the most a relay takes
const kSealSizes = [847, 2767, 10447, 21135, 30399];

// past the last size only the onion takes it: whole multiples of that
// size, up to the longest line the door reads
const kSealOnionMost = 98143;

// the same five gift wraps for a frame that is the rumor itself (a room
// frame, a bundle frame): its length as the rumor's json escapes it. past
// the last no relay takes it, and it is left as it is
const kRumorSizes = [1200, 3760, 14000, 28340, 40604];

const _prefix = 'halo/1:';
const _zero = 0x30;

// the size a slice of a file in several is filled to at least, so the last
// one looks like the rest
const _sliceSize = 3;

/// [plain] filled to the next seal size, as signal seals it
String padSeal(String plain) => _pad(plain, _sealTarget, utf8Length);

/// [frame] filled to the next rumor size, for a frame no signal seal covers
String padRumor(String frame) => _pad(frame, _rumorTarget, rumorLength);

/// [s] with the filler taken out again, as it was before [padSeal] or
/// [padRumor]. anything else comes back as it is
String unpad(String s) {
  final at = s.startsWith('$_prefix{')
      ? _prefix.length + 1
      : s.startsWith('{')
      ? 1
      : -1;
  if (at < 0 || !s.startsWith('"$kPadField":"', at)) return s;
  var i = at + kPadField.length + 5;
  while (i < s.length && s.codeUnitAt(i) == _zero) {
    i++;
  }
  if (i + 1 >= s.length || s.codeUnitAt(i) != 0x22) return s;
  final next = s.codeUnitAt(i + 1);
  if (next == 0x2c) return s.substring(0, at) + s.substring(i + 2);
  if (next == 0x7d) return s.substring(0, at) + s.substring(i + 1);
  return s;
}

int utf8Length(String s) {
  var n = 0;
  for (final r in s.runes) {
    n += r < 0x80
        ? 1
        : r < 0x800
        ? 2
        : r < 0x10000
        ? 3
        : 4;
  }
  return n;
}

/// [s] as a nostr event's json writes it, quotes left out
int rumorLength(String s) {
  var n = 0;
  for (final b in utf8.encode(s)) {
    n += switch (b) {
      0x22 || 0x5c => 2,
      >= 0x20 => 1,
      0x08 || 0x09 || 0x0a || 0x0c || 0x0d => 2,
      _ => 6,
    };
  }
  return n;
}

int? _sealTarget(int need, bool slice) {
  for (final s in kSealSizes.skip(slice ? _sliceSize : 0)) {
    if (need <= s) return s;
  }
  final step = kSealSizes.last + 1;
  final t = (need + step) ~/ step * step - 1;
  if (t <= kSealOnionMost) return t;
  return need <= kSealOnionMost ? kSealOnionMost : null;
}

int? _rumorTarget(int need, bool slice) {
  for (final s in kRumorSizes.skip(slice ? _sliceSize : 0)) {
    if (need <= s) return s;
  }
  return null;
}

// a slice of media sent in several: the only frames that carry 'ct'
bool _isSlice(String s, int at) {
  if (!s.contains('"ct":')) return false;
  try {
    final j = jsonDecode(s.substring(at - 1));
    if (j is! Map) return false;
    final ct = j['ct'];
    return ct is int && ct > 1 && j['mid'] is String;
  } catch (_) {
    return false;
  }
}

String _pad(
  String frame,
  int? Function(int need, bool slice) target,
  int Function(String) len,
) {
  final s = unpad(frame);
  final at = s.startsWith('$_prefix{')
      ? _prefix.length + 1
      : s.startsWith('{')
      ? 1
      : -1;
  if (at < 0 || s.length <= at) return s;
  final last = s.codeUnitAt(at) == 0x7d;
  final empty = '"$kPadField":""${last ? '' : ','}';
  final base = len(s) + len(empty);
  final t = target(base, _isSlice(s, at));
  if (t == null) return s;
  final fill = String.fromCharCodes(List.filled(t - base, _zero));
  return '${s.substring(0, at)}"$kPadField":"$fill"${last ? '' : ','}'
      '${s.substring(at)}';
}
