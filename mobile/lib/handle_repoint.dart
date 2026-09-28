// SPDX-License-Identifier: GPL-3.0-or-later
// when the phone tells the registry where its handle points: only when the
// invite changed since the last claim the registry took, and after start at
// a random moment of its own. the handle page learns whose the handle is
// with a read, and claims only when the registry holds something else.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'handle_lookup.dart' show kHandleRegistry;
import 'l10n/l10n.dart';

// what the last claim the registry took pointed at, as a hash
const kHandleClaimedKey = 'my_handle_claimed';

/// the mark of a claim: the handle and the invite it points at
String claimMark(String handle, String invite) =>
    sha256.convert(utf8.encode('$handle\n$invite')).toString();

/// how long after start a changed invite waits: a few seconds to a minute
Duration repointDelay(Random r) => Duration(seconds: 5 + r.nextInt(56));

/// the line a refused claim or release shows. the engine answers in a few
/// fixed words, never the registry's own, and each has a fixed line
String handleRefusalLine(String r, String h) => switch (r) {
  'error: taken' => l10n.handleThatHandleIsTaken,
  'error: not yours' => l10n.handleIsNotYoursOn(h),
  'error: clock' => l10n.handleCheckClock,
  _ => l10n.handleRegistryFailed,
};

enum HandleAtRegistry { mine, stale, foreign, missing, unknown }

/// what a lookup answer says of our handle: held by our key at our invite,
/// by our key at another invite, by another key, by nobody, or no answer
HandleAtRegistry judgeHandle(
  String body,
  String handle, {
  required String myKey,
  required String myInvite,
}) {
  if (body.startsWith('error')) {
    return body.contains('status 404')
        ? HandleAtRegistry.missing
        : HandleAtRegistry.unknown;
  }
  try {
    final j = jsonDecode(body);
    if (j is! Map) return HandleAtRegistry.unknown;
    final names = j['names'];
    final key = names is Map ? names[handle] : null;
    if (key is! String || myKey.isEmpty) return HandleAtRegistry.unknown;
    if (key.toLowerCase() != myKey.toLowerCase()) {
      return HandleAtRegistry.foreign;
    }
    return j['invite'] == myInvite
        ? HandleAtRegistry.mine
        : HandleAtRegistry.stale;
  } catch (_) {
    return HandleAtRegistry.unknown;
  }
}

class HandleRepoint {
  HandleRepoint({
    required this.invite,
    required this.claim,
    required this.lookup,
    required this.myKey,
    required this.read,
    required this.write,
  });

  // the invite as it is now, the engine's claim and read, our key's hex,
  // and secure storage by key (null removes)
  final Future<String> Function() invite;
  final Future<String> Function(String h, String invite, String bio) claim;
  final Future<String> Function(String url) lookup;
  final String Function() myKey;
  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String? value) write;

  /// claims [h] when the invite is not the one the registry last took, or
  /// always with [force]. null when nothing was sent, else the engine's answer
  Future<String?> repoint(String h, {bool force = false}) async {
    final inv = await invite();
    final mark = claimMark(h, inv);
    if (!force && await read(kHandleClaimedKey) == mark) return null;
    final bio = await read('my_handle_bio') ?? '';
    final r = await claim(h, inv, bio);
    if (r == 'ok') await write(kHandleClaimedKey, mark);
    return r;
  }

  /// asks the registry whose [h] is. one that lost it, or holds an older
  /// invite of ours, is claimed again straight away
  Future<HandleAtRegistry> check(String h) async {
    final inv = await invite();
    final body = await lookup(
      '$kHandleRegistry/.well-known/kryfo.json?name=$h',
    );
    final seen = judgeHandle(body, h, myKey: myKey(), myInvite: inv);
    switch (seen) {
      case HandleAtRegistry.mine:
        await write(kHandleClaimedKey, claimMark(h, inv));
        return seen;
      case HandleAtRegistry.stale:
      case HandleAtRegistry.missing:
        final r = await repoint(h, force: true);
        if (r == 'ok') return HandleAtRegistry.mine;
        if (r != null && r.contains('taken')) return HandleAtRegistry.foreign;
        return HandleAtRegistry.unknown;
      case HandleAtRegistry.foreign:
      case HandleAtRegistry.unknown:
        return seen;
    }
  }

  /// a claim the handle screen made and the registry took
  Future<void> claimed(String h, String inv) =>
      write(kHandleClaimedKey, claimMark(h, inv));

  /// the handle is gone from this phone
  Future<void> forget() => write(kHandleClaimedKey, null);
}
