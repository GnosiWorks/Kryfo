// SPDX-License-Identifier: GPL-3.0-or-later
// a small stored zip for the tests that tell an app installer from other
// zips: local entries, a central directory and its end record
import 'dart:convert';
import 'dart:typed_data';

List<int> _u16(int v) => [v & 0xFF, v >> 8 & 0xFF];
List<int> _u32(int v) => [..._u16(v & 0xFFFF), ..._u16(v >> 16 & 0xFFFF)];

Uint8List zipOf(Map<String, List<int>> entries, {List<int> gap = const []}) {
  final out = <int>[];
  final dir = <int>[];
  for (final e in entries.entries) {
    final name = utf8.encode(e.key);
    final at = out.length;
    out
      ..addAll(_u32(0x04034b50))
      ..addAll(_u16(20))
      ..addAll(_u16(0))
      ..addAll(_u16(0))
      ..addAll(_u32(0))
      ..addAll(_u32(0))
      ..addAll(_u32(e.value.length))
      ..addAll(_u32(e.value.length))
      ..addAll(_u16(name.length))
      ..addAll(_u16(0))
      ..addAll(name)
      ..addAll(e.value);
    dir
      ..addAll(_u32(0x02014b50))
      ..addAll(_u16(20))
      ..addAll(_u16(20))
      ..addAll(_u16(0))
      ..addAll(_u16(0))
      ..addAll(_u32(0))
      ..addAll(_u32(0))
      ..addAll(_u32(e.value.length))
      ..addAll(_u32(e.value.length))
      ..addAll(_u16(name.length))
      ..addAll(_u16(0))
      ..addAll(_u16(0))
      ..addAll(_u16(0))
      ..addAll(_u16(0))
      ..addAll(_u32(0))
      ..addAll(_u32(at))
      ..addAll(name);
  }
  // an apk's signing block sits between the entries and the directory
  out.addAll(gap);
  final dirAt = out.length;
  out
    ..addAll(dir)
    ..addAll(_u32(0x06054b50))
    ..addAll(_u16(0))
    ..addAll(_u16(0))
    ..addAll(_u16(entries.length))
    ..addAll(_u16(entries.length))
    ..addAll(_u32(dir.length))
    ..addAll(_u32(dirAt))
    ..addAll(_u16(0));
  return Uint8List.fromList(out);
}

/// an app as a zip: what the package installer reads first
Uint8List apkBytes({String first = 'AndroidManifest.xml'}) => zipOf({
  first: [1, 2, 3],
  if (first != 'AndroidManifest.xml') 'AndroidManifest.xml': [1, 2, 3],
  'classes.dex': [4, 5, 6],
  'resources.arsc': [7, 8, 9],
}, gap: List.filled(4096, 0x41));
