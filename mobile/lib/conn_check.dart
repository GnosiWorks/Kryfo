// SPDX-License-Identifier: GPL-3.0-or-later
// "check my connection": what tor's way in looks like here, as plain text
// the person reads and shares themselves. only codes and counts: never an
// address, a place, a bridge line, a relay's name or anything of the phone.
// the ways that did not get through are kept in memory for this run only
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'bridge_mode.dart' show BridgeStatus;
import 'widgets/motion.dart' show TorStatus;

/// one way in that did not get through, and the engine's code for why
typedef ConnStep = ({String method, String why});

/// what this run saw on the way in: the ways that failed, and how long the
/// last connect took. memory only, gone with the process
class ConnTrail {
  static const kMostSteps = 8;

  final _steps = <ConnStep>[];
  Duration? _lastBoot;
  DateTime? _tryFrom;

  List<ConnStep> get steps => List.unmodifiable(_steps);
  Duration? get lastBoot => _lastBoot;

  /// the engine's status moved from [was] to [now]. a way left before it
  /// connected, or the last one given up on, failed
  void noteBridge(BridgeStatus was, BridgeStatus now) {
    // no way at all now: a decoy's view, or a route that is not tor. the
    // way before did not fail, it was put down
    if (now.method.isEmpty ||
        now.phase == 'not_tor_mode' ||
        was.phase == 'not_tor_mode') {
      return;
    }
    final m = was.method;
    if (m.isNotEmpty && m != now.method && was.phase != 'connected') {
      _add(m, was.errorCode.isEmpty ? 'no_answer' : was.errorCode);
    }
    if (now.exhausted && !was.exhausted && now.method.isNotEmpty) {
      _add(now.method, now.errorCode.isEmpty ? 'exhausted' : now.errorCode);
    }
  }

  void _add(String method, String why) {
    final s = (method: codeOf(method), why: codeOf(why));
    if (_steps.isNotEmpty && _steps.last == s) return;
    _steps.add(s);
    if (_steps.length > kMostSteps) _steps.removeAt(0);
  }

  /// tor started trying at [at], unless a try already runs
  void tryStarted(DateTime at) => _tryFrom ??= at;

  /// tor carries now: the try that ran took this long
  void ready(DateTime at) {
    final from = _tryFrom;
    _tryFrom = null;
    if (from == null) return;
    final d = at.difference(from);
    if (!d.isNegative) _lastBoot = d;
  }

  @visibleForTesting
  void clear() {
    _steps.clear();
    _lastBoot = null;
    _tryFrom = null;
  }
}

final connTrail = ConnTrail();

/// an engine code as it may go out: short, lowercase letters, digits, _
/// and -. anything else is no code and goes as "other"
String codeOf(String s) {
  final t = s.trim().toLowerCase();
  if (t.isEmpty) return '-';
  return RegExp(r'^[a-z0-9_-]{1,24}$').hasMatch(t) ? t : 'other';
}

/// how long a connect took, in steps wide enough to say nothing of when
String bootBucket(Duration? d) {
  if (d == null) return 'not yet';
  final s = d.inSeconds;
  if (s < 10) return 'under 10 s';
  if (s < 30) return '10 to 30 s';
  if (s < 60) return '30 s to 1 min';
  if (s < 120) return '1 to 2 min';
  if (s < 300) return '2 to 5 min';
  if (s < 900) return '5 to 15 min';
  return 'over 15 min';
}

String _torWord(TorStatus t) => switch (t) {
  TorStatus.off => 'off',
  TorStatus.starting => 'starting',
  TorStatus.bootstrapped => 'connected, publishing',
  TorStatus.publishing => 'connected, publishing',
  TorStatus.reachable => 'reachable',
};

Map<String, dynamic> _json(String raw) {
  try {
    final m = jsonDecode(raw);
    return m is Map<String, dynamic> ? m : const {};
  } catch (_) {
    return const {};
  }
}

String _yes(bool b) => b ? 'yes' : 'no';

String _netWord(Object? n) =>
    const {'ok', 'limited', 'none'}.contains(n) ? n as String : '-';

/// the report, as it is shown and as it goes, word for word. [bridgeRaw]
/// is the engine's bridge status, [tx] its transport state; only the
/// fields named here are read from them. a decoy shows automatic and the
/// phase only, as its transport page does
String connReport({
  required DateTime now,
  required String version,
  required String platform,
  required String sendMode,
  required TorStatus tor,
  required int pct,
  required bool canSend,
  required bool online,
  required String bridgeRaw,
  required Map<String, dynamic> tx,
  required ConnTrail trail,
  bool decoy = false,
}) {
  final b = _json(bridgeRaw);
  String s(String k) => b[k] is String ? codeOf(b[k] as String) : '-';
  bool f(String k) => b[k] == true;
  final onion = sendMode == 'private';
  final day = now.toUtc().toIso8601String().substring(0, 10);
  final out = <String>[
    'Kryfo connection check',
    'Date: $day',
    'App: ${RegExp(r'^[0-9][0-9a-z.+-]{0,23}$').hasMatch(version) ? version : 'other'}, '
        '${codeOf(platform)}',
    'Route: ${onion ? 'Tor' : 'Fast'}',
    'Internet: ${online ? _netWord(b['network']) : 'none'}, '
        'VPN ${_yes(f('vpn'))}'
        '${f('tor_vpn') ? ', Tor VPN' : ''}',
  ];
  if (onion) {
    out.add(
      'Tor: ${_torWord(tor)}'
      '${tor == TorStatus.starting ? ', $pct%' : ''}',
    );
    out.add('Connect took: ${bootBucket(trail.lastBoot)}');
  }
  out.add('Can send: ${_yes(canSend)}');
  if (onion) {
    out.add('Bridges: ${decoy ? 'auto' : s('mode')}, phase ${s('phase')}');
    if (!decoy) {
      final attempts = b['attempts'] is num ? (b['attempts'] as num) : 0;
      out.add(
        'Way in now: ${s('method')}'
        '${attempts > 0 ? ', step ${(b['attempt'] as num?)?.toInt() ?? 0} '
                  'of ${attempts.toInt()}' : ''}',
      );
      if (f('blocked')) out.add('Tor looked blocked: yes');
      if (f('limited')) out.add('Network limited: yes');
      if (b['snowflake'] is String && (b['snowflake'] as String).isNotEmpty) {
        out.add('Snowflake: ${s('snowflake')}');
      }
      final failed = trail.steps;
      out.add(
        'Did not get through: '
        '${failed.isEmpty ? 'none' : [for (final x in failed) '${x.method} (${x.why})'].join(', ')}',
      );
      out.add('Error now: ${s('error_code')}');
      final lastOk = b['last_ok_method'];
      if (lastOk is String && lastOk.isNotEmpty) {
        out.add('Worked before: ${codeOf(lastOk)}');
      }
    }
  }
  final relays = tx['relays'] is List ? tx['relays'] as List : const [];
  var ok = 0, failing = 0, benched = 0;
  for (final r in relays) {
    if (r is! Map) continue;
    if (r['benched'] == true) {
      benched++;
    } else if ((r['fails'] as num? ?? 0) > 0) {
      failing++;
    } else {
      ok++;
    }
  }
  out.add('Relays: $ok ok, $failing failing, $benched resting');
  final counts = tx['bounce_counts'];
  if (counts is Map) {
    final kinds = [
      for (final e in counts.entries)
        if (e.key is String && e.value is int && (e.value as int) > 0)
          (why: codeOf(e.key as String), n: e.value as int),
    ]..sort((a, b) => b.n != a.n ? b.n - a.n : a.why.compareTo(b.why));
    final all = kinds.fold<int>(0, (t, k) => t + k.n);
    out.add(
      'Reconnects: $all'
      '${kinds.isEmpty ? '' : ' (${[for (final k in kinds) '${k.why} ${k.n}'].join(', ')})'}',
    );
  }
  if (onion) {
    final published =
        (tx['hsdir_uploads'] as num? ?? 0) > 0 || tx['published_once'] == true;
    out.add('Address published: ${_yes(published)}');
  }
  return out.join('\n');
}
