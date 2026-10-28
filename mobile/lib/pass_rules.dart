// SPDX-License-Identifier: GPL-3.0-or-later
// a hidden chats passphrase, as the engine takes it: every decimal digit as
// its ascii one and every space as a plain one (engine/pin.go does the same
// and nfc on top), so a phrase typed on another keyboard tomorrow still
// opens. no control characters, at most 256 bytes.
import 'dart:convert';
import 'dart:math';

/// the shortest passphrase, as for backups
const kPassMin = 12;

/// the longest, in utf-8 bytes
const kPassMaxBytes = 256;

// the zero of every unicode decimal digit run (unicode 15, as the engine's
// go has it). each run is 0 to 9 in order
const _digitZeros = <int>[
  0x0030, 0x0660, 0x06F0, 0x07C0, 0x0966, 0x09E6, 0x0A66, 0x0AE6, 0x0B66, //
  0x0BE6, 0x0C66, 0x0CE6, 0x0D66, 0x0DE6, 0x0E50, 0x0ED0, 0x0F20, 0x1040,
  0x1090, 0x17E0, 0x1810, 0x1946, 0x19D0, 0x1A80, 0x1A90, 0x1B50, 0x1BB0,
  0x1C40, 0x1C50, 0xA620, 0xA8D0, 0xA900, 0xA9D0, 0xA9F0, 0xAA50, 0xABF0,
  0xFF10, 0x104A0, 0x10D30, 0x11066, 0x110F0, 0x11136, 0x111D0, 0x112F0,
  0x11450, 0x114D0, 0x11650, 0x116C0, 0x11730, 0x118E0, 0x11950, 0x11C50,
  0x11D50, 0x11DA0, 0x11F50, 0x16A60, 0x16AC0, 0x16B50, 0x1D7CE, 0x1D7D8,
  0x1D7E2, 0x1D7EC, 0x1D7F6, 0x1E140, 0x1E2F0, 0x1E4F0, 0x1E950, 0x1FBF0,
];

// every space separator but the plain one
const _spaces = <int>{
  0x00A0, 0x1680, 0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006, //
  0x2007, 0x2008, 0x2009, 0x200A, 0x202F, 0x205F, 0x3000,
};

int? _digit(int r) {
  for (final z in _digitZeros) {
    if (r >= z && r < z + 10) return r - z;
  }
  return null;
}

/// digits and spaces folded. nothing trimmed
String passFold(String s) {
  final out = StringBuffer();
  for (final r in s.runes) {
    final d = _digit(r);
    if (d != null) {
      out.writeCharCode(0x30 + d);
    } else if (_spaces.contains(r)) {
      out.writeCharCode(0x20);
    } else {
      out.writeCharCode(r);
    }
  }
  return out.toString();
}

bool _control(int r) => r < 0x20 || (r >= 0x7F && r < 0xA0);

/// whether the engine takes it: not empty, no nul or other control
/// character, short enough
bool passUsable(String s) =>
    s.isNotEmpty &&
    !s.runes.any(_control) &&
    utf8.encode(passFold(s)).length <= kPassMaxBytes;

/// what typing [s] may add to the field: control characters never go in
String passTyped(String s) =>
    String.fromCharCodes(s.runes.where((r) => !_control(r)));

/// characters, as a person counts them
int passLength(String s) => s.runes.length;

/// 0 weak, 1 fair, 2 strong: a rough count of guesses from the kinds of
/// character used and the length, less for runs of one character
int passStrength(String s) {
  final f = passFold(s);
  final rs = f.runes.toList();
  if (rs.isEmpty) return 0;
  var pool = 0;
  if (rs.any((r) => r >= 0x30 && r <= 0x39)) pool += 10;
  if (rs.any((r) => r >= 0x61 && r <= 0x7A)) pool += 26;
  if (rs.any((r) => r >= 0x41 && r <= 0x5A)) pool += 26;
  if (rs.any((r) => r < 0x80 && !_alnum(r))) pool += 33;
  if (rs.any((r) => r >= 0x80)) pool += 100;
  final distinct = rs.toSet().length;
  // a phrase of few different characters guesses as if it were shorter
  final useful = min(rs.length, distinct * 2);
  final bits = useful * log(max(pool, 2)) / ln2;
  if (bits >= 72) return 2;
  if (bits >= 48) return 1;
  return 0;
}

bool _alnum(int r) =>
    (r >= 0x30 && r <= 0x39) ||
    (r >= 0x41 && r <= 0x5A) ||
    (r >= 0x61 && r <= 0x7A);
