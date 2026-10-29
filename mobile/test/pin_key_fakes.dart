// SPDX-License-Identifier: GPL-3.0-or-later
// a pin key in memory and an engine that keeps v3 rules in dart: an entry
// moved under the pin key opens only with the same key's answer for that
// pin, an old one opens without it, and a check moves what it opened
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:kryfo/lock_state.dart';
import 'package:kryfo/pin_key.dart';

/// what the engine hands the pin key for [pin]: 64 hex, as from the engine
String fakeX(String pin) => sha256.convert(utf8.encode('x:$pin')).toString();

/// the phone's pin key: answers that depend on the key and on x, counted.
/// it can be made to fail, hang, refuse to be made, or lose the key
class FakeKeys implements PinKeystore {
  FakeKeys({
    this.exists = false,
    this.level = 2,
    this.unlocked = 1,
    this.screenLock = true,
  });
  bool exists;
  int level;
  int unlocked;
  bool screenLock;
  // which key: a new one answers differently
  int id = 1;
  final calls = <String>[];
  int get macs => calls.where((c) => c == 'mac').length;
  // every mac and kcv fails with this while set
  KeyFail? fail;
  // macs never answer while set
  Completer<void>? hang;
  bool refuseMake = false;
  // a keystore that keeps keys in software only: makes none, and says so
  // once it was asked
  bool soft = false;
  bool softSeen = false;
  bool infoSilent = false;
  // the next info says no key once, as a busy keystore may
  bool infoFalseOnce = false;

  String _m(String x) => sha256.convert(utf8.encode('$id:$x')).toString();
  String get kc => _m('kcv');

  @override
  Future<PinKeyInfo?> info() async {
    calls.add('info');
    if (infoSilent) return null;
    final there = exists && !infoFalseOnce;
    infoFalseOnce = false;
    return PinKeyInfo(
      exists: there,
      unlocked: exists ? unlocked : 0,
      level: level,
      screenLock: screenLock,
      sdk: 35,
      hardware: there || !softSeen,
    );
  }

  @override
  Future<PinKeyInfo?> make() async {
    calls.add('make');
    if (refuseMake) return null;
    if (soft) {
      softSeen = true;
      return const PinKeyInfo(exists: false, hardware: false);
    }
    exists = true;
    return PinKeyInfo(
      exists: true,
      unlocked: unlocked,
      level: level,
      screenLock: screenLock,
      sdk: 35,
      kc: kc,
    );
  }

  @override
  Future<KeyAnswer> mac(String x) async {
    calls.add('mac');
    final h = hang;
    if (h != null) await h.future;
    if (!exists) return const KeyAnswer.failed(KeyFail.gone);
    final f = fail;
    if (f != null) return KeyAnswer.failed(f);
    return KeyAnswer.ok(_m(x));
  }

  @override
  Future<KeyAnswer> kcv() async {
    calls.add('kcv');
    if (!exists) return const KeyAnswer.failed(KeyFail.gone);
    final f = fail;
    if (f != null) return KeyAnswer.failed(f);
    return KeyAnswer.ok(kc);
  }

  @override
  Future<void> drop() async {
    calls.add('drop');
    exists = false;
    id++;
  }

  // another key under the same name, as a broken keystore might leave
  void replace() => id++;
}

/// the engine's v3 rules in dart: a table is {"v", "n", "k"?, "e": {index:
/// {"p", "k", "c", "w", "g", "m"?}}}, g the key an entry is under (2 the
/// pin's own, 3 the pin key's) and m the pin key's answer it needs
class KeyEngine implements PinEngine {
  final List<String> calls = [];
  // a check waits here while set, after it asked the pin key
  Completer<void>? gate;
  // the next check finds its handle gone, as after a slow pin key
  bool handleGone = false;

  static String legacyHash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static bool _old(String pin, Object? s, Object? h) =>
      s is String &&
      h is String &&
      s != '' &&
      h != '' &&
      legacyHash(pin, s) == h;

  Map<String, dynamic> _t(String s) => jsonDecode(s) as Map<String, dynamic>;

  static bool _opens(Map v, String pin, String m) =>
      v['p'] == pin && (v['g'] != 3 || (m != '' && v['m'] == m));

  @override
  Future<Map<String, dynamic>> calibrate() async {
    calls.add('calibrate');
    return {'n': 15, 'ms': 120};
  }

  @override
  Future<String> newTable(int logN) async {
    calls.add('new');
    return jsonEncode({'v': 2, 'n': logN, 'e': <String, dynamic>{}});
  }

  @override
  Future<Map<String, dynamic>> check(
    String pin,
    String table,
    String legacy, {
    PinMac? mac,
    String key = '',
  }) async {
    calls.add('check');
    final m = mac == null ? '' : await mac(fakeX(pin));
    final g = gate;
    if (g != null) await g.future;
    if (handleGone) {
      handleGone = false;
      throw PinKeyBusy();
    }
    final t = _t(table);
    final e = Map<String, dynamic>.from(t['e'] as Map);
    final l = jsonDecode(legacy) as Map<String, dynamic>;
    int? old, neu;
    for (final kv in e.entries) {
      final v = kv.value as Map;
      if (!_opens(v, pin, m)) continue;
      if (v['g'] == 3) {
        neu = int.parse(kv.key);
      } else {
        old = int.parse(kv.key);
      }
    }
    final at = neu ?? old;
    final v = at == null ? null : e['$at'] as Map;
    final la = _old(pin, l['as'], l['ah']);
    final lw = _old(pin, l['ws'], l['wh']);
    final r = <String, dynamic>{
      'i': at ?? -1,
      'k': v?['k'] ?? 0,
      'c': v?['c'] ?? '',
      'u': v?['w'] ?? '',
      'la': la,
      'lw': lw,
      'g': neu != null ? 3 : (old != null ? 2 : 0),
    };
    if (m == '') return r;
    String? mv;
    int? target;
    Map<String, dynamic>? entry;
    if (neu == null && old != null) {
      mv = 'e';
      target = old;
      entry = {...v!, 'g': 3, 'm': m};
    } else if (at == null && la && !lw && l['am'] is Map) {
      mv = 'a';
      target = (l['am']['i'] as num).toInt();
      entry = {'p': pin, 'k': l['am']['k'], 'c': l['am']['c'], 'w': ''};
    } else if (at == null && lw && !la && l['wm'] is Map) {
      mv = 'w';
      target = (l['wm']['i'] as num).toInt();
      entry = {'p': pin, 'k': l['wm']['k'], 'c': l['wm']['c'], 'w': ''};
    }
    if (mv == null) return r;
    final wasV3 = t['v'] == 3;
    if (!wasV3 && key == '') return r;
    r['mv'] = mv;
    r['r'] = {
      ...t,
      'v': 3,
      if (!wasV3) 'k': jsonDecode(key),
      'e': {
        ...e,
        '$target': {...entry!, 'g': 3, 'm': m},
      },
    };
    return r;
  }

  bool _clashes(Map e, int index, String pin, String m, Map l) {
    for (final kv in e.entries) {
      if (kv.key != '$index' && _opens(kv.value as Map, pin, m)) return true;
    }
    return _old(pin, l['as'], l['ah']) || _old(pin, l['ws'], l['wh']);
  }

  Map<String, dynamic> _write(
    Map<String, dynamic> t,
    Map<String, dynamic> e,
    int index,
    Map<String, dynamic> entry,
    String m,
    String key,
  ) {
    final v3 = t['v'] == 3;
    if (m == '' && v3) throw PinKeyBusy();
    if (m != '' && !v3 && key == '') throw StateError('error: bad key info');
    e['$index'] = {...entry, 'g': m == '' ? 2 : 3, if (m != '') 'm': m};
    return {
      ...t,
      'v': m == '' && !v3 ? 2 : 3,
      if (m != '' && !v3) 'k': jsonDecode(key),
      'e': e,
    };
  }

  @override
  Future<Map<String, dynamic>> setup(
    String pin,
    String table,
    String legacy,
    int index,
    int kind,
    String container,
    String wrapPlain, {
    PinMac? mac,
    String key = '',
  }) async {
    calls.add('setup');
    final m = mac == null ? '' : await mac(fakeX(pin));
    final t = _t(table);
    final e = Map<String, dynamic>.from(t['e'] as Map);
    final l = jsonDecode(legacy) as Map<String, dynamic>;
    if (m == '' && t['v'] == 3) throw PinKeyBusy();
    if (_clashes(e, index, pin, m, l)) throw PinCollision();
    return {
      't': _write(
        t,
        e,
        index,
        {'p': pin, 'k': kind, 'c': container, 'w': wrapPlain},
        m,
        key,
      ),
    };
  }

  @override
  Future<Map<String, dynamic>> rewrap(
    String oldPin,
    String newPin,
    String table,
    String legacy,
    int index, {
    PinMac? mac,
    String key = '',
  }) async {
    calls.add('rewrap');
    final mo = mac == null ? '' : await mac(fakeX(oldPin));
    final mn = mac == null ? '' : await mac(fakeX(newPin));
    final t = _t(table);
    if ((mo == '' || mn == '') && t['v'] == 3) throw PinKeyBusy();
    final e = Map<String, dynamic>.from(t['e'] as Map);
    final l = jsonDecode(legacy) as Map<String, dynamic>;
    final at = e['$index'] as Map?;
    if (at == null || !_opens(at, oldPin, mo)) {
      throw StateError('error: wrong pin');
    }
    if ((at['w'] ?? '') == '') throw StateError('error: nothing wrapped');
    if (_clashes(e, index, newPin, mn, l)) throw PinCollision();
    return {
      't': _write(
        t,
        e,
        index,
        {...Map<String, dynamic>.from(at), 'p': newPin},
        mn,
        key,
      ),
    };
  }

  @override
  Future<String> upgrade(String table) async {
    calls.add('upgrade');
    final t = _t(table);
    return jsonEncode({...t, 'v': (t['v'] as num) < 2 ? 2 : t['v']});
  }

  @override
  Future<String> clear(String table, int index) async {
    calls.add('clear');
    final t = _t(table);
    final e = Map<String, dynamic>.from(t['e'] as Map)..remove('$index');
    return jsonEncode({...t, 'e': e});
  }
}
