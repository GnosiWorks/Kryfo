// SPDX-License-Identifier: GPL-3.0-or-later
// the phone's pin key (PinKey.kt): an hmac key the keystore keeps. every pin
// check has it sign one value, so the pin table guesses only on this phone.
// behind a seam so a test can count the calls and make it fail or hang.
import 'dart:io';

import 'package:flutter/services.dart';

/// why the keystore gave no answer: busy (or slow, or odd), the phone counts
/// as locked to it, or it has no such key
enum KeyFail { busy, locked, gone }

class KeyAnswer {
  const KeyAnswer.ok(String this.m) : fail = null;
  const KeyAnswer.failed(KeyFail this.fail) : m = null;

  /// 32 bytes, hex
  final String? m;
  final KeyFail? fail;
  bool get ok => m != null;
}

/// the key as the phone describes it
class PinKeyInfo {
  const PinKeyInfo({
    required this.exists,
    this.unlocked = 0,
    this.level = 0,
    this.screenLock = true,
    this.sdk = 0,
    this.kc,
    this.supported = true,
  });

  /// a phone with no keystore for this, or no android at all
  const PinKeyInfo.none()
    : exists = false,
      unlocked = 0,
      level = 0,
      screenLock = true,
      sdk = 0,
      kc = null,
      supported = false;

  final bool exists;

  /// 1 when it works only while the phone is unlocked (made on 15 or later)
  final int unlocked;

  /// 0 software, 1 secure hardware, 2 strongbox
  final int level;

  /// the phone has a secure screen lock
  final bool screenLock;
  final int sdk;

  /// the check value, from a key just made
  final String? kc;
  final bool supported;

  static const software = 0;
}

abstract class PinKeystore {
  /// null when it did not answer
  Future<PinKeyInfo?> info();

  /// a new key, tested, never over one that is there. null when the phone
  /// refused or was busy
  Future<PinKeyInfo?> make();

  /// x, 64 hex, signed
  Future<KeyAnswer> mac(String x);

  /// the check value: tells this key from any other
  Future<KeyAnswer> kcv();

  /// the wipe and the lock turned off only
  Future<void> drop();
}

KeyFail _failOf(Object? e) => switch (e) {
  'locked' => KeyFail.locked,
  'gone' => KeyFail.gone,
  _ => KeyFail.busy,
};

class PlatformPinKeystore implements PinKeystore {
  const PlatformPinKeystore();
  static const _ch = MethodChannel('halo/platform');

  Future<Map<Object?, Object?>?> _call(String m, [Object? a]) async {
    try {
      return await _ch.invokeMethod<Map<Object?, Object?>>(m, a);
    } catch (_) {
      // a process whose screen has not attached the channel yet: asked
      // again later
      return null;
    }
  }

  static PinKeyInfo? _info(Map<Object?, Object?>? r) {
    if (r == null || r['e'] != null) return null;
    int n(String k) => (r[k] as num?)?.toInt() ?? 0;
    return PinKeyInfo(
      exists: r['k'] == true,
      unlocked: n('u'),
      level: n('l'),
      screenLock: r['s'] != false,
      sdk: n('v'),
      kc: r['kc'] as String?,
    );
  }

  static KeyAnswer _answer(Map<Object?, Object?>? r) {
    final m = r?['m'];
    if (m is String) return KeyAnswer.ok(m);
    return KeyAnswer.failed(_failOf(r?['e']));
  }

  @override
  Future<PinKeyInfo?> info() async {
    if (!Platform.isAndroid) return const PinKeyInfo.none();
    return _info(await _call('pinKeyInfo'));
  }

  @override
  Future<PinKeyInfo?> make() async {
    if (!Platform.isAndroid) return null;
    return _info(await _call('pinKeyMake'));
  }

  @override
  Future<KeyAnswer> mac(String x) async {
    if (!Platform.isAndroid) return const KeyAnswer.failed(KeyFail.gone);
    return _answer(await _call('pinKeyMac', {'x': x}));
  }

  @override
  Future<KeyAnswer> kcv() async {
    if (!Platform.isAndroid) return const KeyAnswer.failed(KeyFail.gone);
    return _answer(await _call('pinKeyKcv'));
  }

  @override
  Future<void> drop() async {
    if (Platform.isAndroid) await _call('pinKeyDrop');
  }
}

/// an answer that can be the keystore's for x: 32 bytes, not zeros, not x
bool keyAnswerFits(String m, String x) =>
    RegExp(r'^[0-9a-f]{64}$').hasMatch(m) &&
    m != '0' * 64 &&
    m != x.toLowerCase();
