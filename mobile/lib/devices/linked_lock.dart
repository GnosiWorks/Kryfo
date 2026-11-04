// SPDX-License-Identifier: GPL-3.0-or-later
// a linked device's own end (linked devices step 7, job 9): when a person
// last used it and the highest clock it has seen, readable before any
// unlock and kept under a mac whose key is in the secret store. a device
// not used for 30 days by its clock, one whose clock went back, and one
// whose lock state does not read wipes itself before anything else, then
// tells its phone. a thief can set the clock back; a clock that goes back
// counts as expired, so that buys nothing
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show Hmac, sha256;

import 'own_devices.dart' show kUnusedDays;

/// what ends a linked device: its phone removed it, it was not used for
/// 30 days, its clock went back, its lock state did not read, or the
/// person unlinked it there
enum LinkedEnd { removed, unused, clock, broken, self }

/// the word a linked device's 'ou' carries for [e], null for a removal
/// (the phone did that itself)
String? linkedEndWord(LinkedEnd e) => switch (e) {
  LinkedEnd.removed => null,
  LinkedEnd.unused => 'unused',
  LinkedEnd.clock => 'clock',
  LinkedEnd.broken => 'broken',
  LinkedEnd.self => 'self',
};

/// unused this long by its own clock, a linked device wipes
const kLinkedUnused = Duration(days: kUnusedDays);

/// how far back a clock may step (a network time fix) before it counts as
/// set back
const kClockSlack = Duration(minutes: 10);

/// the secret store's name for the lock state's mac key
const kLinkedLockKey = 'linked_lock_key';

/// the file the lock state is kept in, in the app's support folder
const kLinkedLockFile = 'linked_lock';

const _label = 'kryfo-linked-lock-v1';

class LinkedLock {
  LinkedLock({
    required this.dir,
    required this.readKey,
    required this.writeKey,
    int Function()? clock,
    Random? random,
  }) : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch),
       _rand = random ?? Random.secure();

  /// where [kLinkedLockFile] is
  final Future<String> Function() dir;
  final Future<String?> Function(String name) readKey;
  final Future<void> Function(String name, String value) writeKey;
  final int Function() _clock;
  final Random _rand;

  Future<File> _file() async => File('${await dir()}/$kLinkedLockFile');

  /// the link is done: a fresh key, used now
  Future<void> start() async {
    final key = Uint8List.fromList([
      for (var i = 0; i < 32; i++) _rand.nextInt(256),
    ]);
    await writeKey(kLinkedLockKey, base64Encode(key));
    final now = _clock();
    await _write(key, now, now);
  }

  /// a person used the device (lifted its lock, or opened it with none)
  Future<void> used() async {
    final s = await _read();
    if (s == null) return;
    final now = _clock();
    // a clock behind the highest seen is not a use: the check says so
    if (now < s.high - kClockSlack.inMilliseconds) return;
    await _write(s.key, now, max(s.high, now));
  }

  /// at every start and on a timer: null while all is well (the highest
  /// clock kept), else why the device ends
  Future<LinkedEnd?> check() async {
    final s = await _read();
    if (s == null) return LinkedEnd.broken;
    final now = _clock();
    if (now < s.high - kClockSlack.inMilliseconds) return LinkedEnd.clock;
    if (now - s.used > kLinkedUnused.inMilliseconds) return LinkedEnd.unused;
    if (now > s.high) await _write(s.key, s.used, now);
    return null;
  }

  Future<({Uint8List key, int used, int high})?> _read() async {
    try {
      final k = await readKey(kLinkedLockKey);
      if (k == null) return null;
      final key = base64Decode(k);
      if (key.length != 32) return null;
      final f = await _file();
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString()) as Map;
      final u = j['u'], h = j['h'], m = j['m'];
      if (u is! int || h is! int || m is! String) return null;
      if (!_same(base64Decode(m), _mac(key, u, h))) return null;
      return (key: Uint8List.fromList(key), used: u, high: h);
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(Uint8List key, int used, int high) async {
    final f = await _file();
    final tmp = File('${f.path}.new');
    await tmp.writeAsString(
      jsonEncode({
        'u': used,
        'h': high,
        'm': base64Encode(_mac(key, used, high)),
      }),
      flush: true,
    );
    await tmp.rename(f.path);
  }

  List<int> _mac(List<int> key, int used, int high) =>
      Hmac(sha256, key).convert(utf8.encode('$_label|$used|$high')).bytes;

  bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var d = 0;
    for (var i = 0; i < a.length; i++) {
      d |= a[i] ^ b[i];
    }
    return d == 0;
  }
}
