// SPDX-License-Identifier: GPL-3.0-or-later
// a language pack's download, shared by the settings page and the chat's
// sheet. the engine fetches over tor and checks the pins; this side starts
// and polls it, and only from a tap
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'catalog.dart';
import 'engine_bridge.dart';

enum DlPhase {
  // not looked at yet
  unknown,
  // not on the phone
  absent,
  // wi-fi only is on and the phone is not on wi-fi
  wifiNeeded,
  // asked, the engine not answered yet
  starting,
  running,
  // stopped or cut part way: the next start picks up from there
  paused,
  failed,
  installed,
}

enum DlFail {
  // tor is not up: nothing is fetched another way
  noTor,
  // the host or the circuit: a retry may do
  network,
  // a file did not match its pin and was thrown away
  badFile,
  // this build's engine cannot download
  noEngine,
}

@immutable
class DlState {
  final DlPhase phase;
  final int done;
  final int total;
  final DlFail? fail;
  // what its files take now, whole or in part
  final int onDisk;
  const DlState(
    this.phase, {
    this.done = 0,
    this.total = 0,
    this.fail,
    this.onDisk = 0,
  });

  bool get busy => phase == DlPhase.starting || phase == DlPhase.running;
  double? get share => total > 0 ? (done / total).clamp(0.0, 1.0) : null;

  DlState copyWith({
    DlPhase? phase,
    int? done,
    int? total,
    DlFail? fail,
    int? onDisk,
  }) => DlState(
    phase ?? this.phase,
    done: done ?? this.done,
    total: total ?? this.total,
    fail: fail,
    onDisk: onDisk ?? this.onDisk,
  );

  @override
  bool operator ==(Object other) =>
      other is DlState &&
      other.phase == phase &&
      other.done == done &&
      other.total == total &&
      other.fail == fail &&
      other.onDisk == onDisk;
  @override
  int get hashCode => Object.hash(phase, done, total, fail, onDisk);
  @override
  String toString() => 'DlState($phase $done/$total $fail disk $onDisk)';
}

// where packs are kept and how they are fetched; the engine on a phone, a
// stand-in in tests
abstract class ModelBackend {
  // "ok", or "error: ..."
  Future<String> start(String lang, String host);
  FetchStatus progress(String lang);
  void cancel(String lang);
  Future<bool> installed(String lang);
  Future<int> onDisk(String lang);
  Future<String> remove(String lang);
}

class EngineModelBackend implements ModelBackend {
  final TranslateEngine engine;
  final Future<String> Function() dir;
  final TranslateCatalog Function() catalog;
  EngineModelBackend(this.engine, this.dir, this.catalog);

  // the storage folder may not be there to ask (a test, a broken plugin):
  // that reads as nothing on the phone and a download that cannot start
  @override
  Future<String> start(String lang, String host) async {
    try {
      return await engine.fetch(lang, await dir(), host);
    } catch (e) {
      return 'error: storage: ${e.runtimeType}';
    }
  }

  @override
  FetchStatus progress(String lang) => engine.progress(lang);
  @override
  void cancel(String lang) => engine.cancel(lang);

  @override
  Future<bool> installed(String lang) async {
    try {
      return await engine.installed(lang, await dir());
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> remove(String lang) async {
    try {
      return await engine.remove(lang, await dir());
    } catch (e) {
      return 'error: storage: ${e.runtimeType}';
    }
  }

  @override
  Future<int> onDisk(String lang) async {
    final b = catalog().bundle(lang);
    if (b == null) return 0;
    var n = 0;
    try {
      final root = await dir();
      for (final d in b.dirs) {
        final at = Directory(p.join(root, d));
        if (!await at.exists()) continue;
        await for (final f in at.list()) {
          if (f is File) n += await f.length();
        }
      }
    } catch (_) {}
    return n;
  }
}

class ModelDownloads extends ChangeNotifier {
  final ModelBackend backend;
  // whether the phone is on wi-fi now
  final Future<bool> Function() onWifi;
  final bool Function() wifiOnly;
  final String Function() host;
  // a quiet session (the decoy): the phone's packs do not show in it, and a
  // download there fetches nothing and stops as a cut one would
  final bool Function() quiet;
  final Duration poll;
  ModelDownloads({
    required this.backend,
    required this.onWifi,
    required this.wifiOnly,
    required this.host,
    this.quiet = _loud,
    this.poll = const Duration(milliseconds: 500),
  });

  static bool _loud() => false;

  final Map<String, DlState> _st = {};
  final Map<String, DlState> _quiet = {};
  final Map<String, Timer> _timers = {};
  bool _gone = false;

  DlState of(String lang) =>
      (quiet() ? _quiet[lang] : _st[lang]) ?? const DlState(DlPhase.unknown);
  bool installed(String lang) => of(lang).phase == DlPhase.installed;

  DlState _real(String lang) => _st[lang] ?? const DlState(DlPhase.unknown);

  void _set(String lang, DlState s) {
    if (_gone || _st[lang] == s) return;
    _st[lang] = s;
    notifyListeners();
  }

  void _setQuiet(String lang, DlState s) {
    if (_gone || _quiet[lang] == s) return;
    _quiet[lang] = s;
    notifyListeners();
  }

  // looks at what is on the phone, unless a download is going
  Future<DlState> refresh(String lang) async {
    if (quiet()) {
      if (_quiet[lang] == null) _setQuiet(lang, const DlState(DlPhase.absent));
      return of(lang);
    }
    if (_real(lang).busy) return _real(lang);
    final ok = await backend.installed(lang);
    final disk = await backend.onDisk(lang);
    if (_real(lang).busy) return _real(lang);
    final was = _real(lang);
    _set(
      lang,
      ok
          ? DlState(DlPhase.installed, onDisk: disk)
          : was.phase == DlPhase.failed || was.phase == DlPhase.wifiNeeded
          ? was.copyWith(onDisk: disk, fail: was.fail)
          : disk > 0
          ? DlState(
              DlPhase.paused,
              done: was.done,
              total: was.total,
              onDisk: disk,
            )
          : const DlState(DlPhase.absent),
    );
    return _real(lang);
  }

  // [anyNetwork]: the person said to go now, wi-fi or not
  Future<void> start(String lang, {bool anyNetwork = false}) async {
    if (quiet()) return _startQuiet(lang, anyNetwork);
    if (_real(lang).busy || _real(lang).phase == DlPhase.installed) return;
    final was = _real(lang);
    if (wifiOnly() && !anyNetwork && !await onWifi()) {
      _set(lang, was.copyWith(phase: DlPhase.wifiNeeded));
      return;
    }
    _set(lang, was.copyWith(phase: DlPhase.starting));
    final out = await backend.start(lang, host());
    if (out != 'ok') {
      _set(
        lang,
        _real(lang).copyWith(phase: DlPhase.failed, fail: _startFail(out)),
      );
      return;
    }
    _timers[lang]?.cancel();
    _timers[lang] = Timer.periodic(poll, (_) => _tick(lang));
    _tick(lang);
  }

  Future<void> _startQuiet(String lang, bool anyNetwork) async {
    final was = _quiet[lang] ?? const DlState(DlPhase.absent);
    if (was.busy) return;
    if (wifiOnly() && !anyNetwork && !await onWifi()) {
      _setQuiet(lang, was.copyWith(phase: DlPhase.wifiNeeded));
      return;
    }
    _setQuiet(lang, was.copyWith(phase: DlPhase.starting));
    await Future<void>.delayed(poll * 4);
    if (_quiet[lang]?.phase != DlPhase.starting) return;
    _setQuiet(lang, was.copyWith(phase: DlPhase.failed, fail: DlFail.network));
  }

  static DlFail _startFail(String out) {
    if (out.startsWith('error: tor')) return DlFail.noTor;
    if (out.startsWith('error: engine')) return DlFail.noEngine;
    return DlFail.network;
  }

  void _tick(String lang) {
    final s = backend.progress(lang);
    final now = _real(lang);
    switch (s.state) {
      case 'running':
        _set(
          lang,
          now.copyWith(phase: DlPhase.running, done: s.done, total: s.total),
        );
      case 'done':
        _stop(lang);
        _set(lang, now.copyWith(phase: DlPhase.running, done: s.total));
        unawaited(_finished(lang));
      case 'cancelled':
        _stop(lang);
        _set(lang, now.copyWith(phase: DlPhase.paused));
        unawaited(_measure(lang));
      case 'failed':
        _stop(lang);
        _set(
          lang,
          now.copyWith(
            phase: DlPhase.failed,
            fail: s.kind == 'hash' ? DlFail.badFile : DlFail.network,
          ),
        );
        unawaited(_measure(lang));
      // idle: the engine has not taken it up yet
    }
  }

  void _stop(String lang) => _timers.remove(lang)?.cancel();

  Future<void> _finished(String lang) async {
    final disk = await backend.onDisk(lang);
    _set(lang, DlState(DlPhase.installed, onDisk: disk));
  }

  Future<void> _measure(String lang) async {
    final disk = await backend.onDisk(lang);
    _set(lang, _real(lang).copyWith(onDisk: disk, fail: _real(lang).fail));
  }

  void cancel(String lang) {
    if (quiet()) {
      final q = _quiet[lang];
      if (q != null && q.busy) {
        _setQuiet(lang, q.copyWith(phase: DlPhase.absent));
      }
      return;
    }
    if (!_real(lang).busy) return;
    backend.cancel(lang);
    // the poll sees it stop; a start not answered yet is let run out
  }

  Future<bool> remove(String lang) async {
    if (quiet()) {
      _setQuiet(lang, const DlState(DlPhase.absent));
      return true;
    }
    if (_real(lang).busy) return false;
    final out = await backend.remove(lang);
    if (out != 'ok') return false;
    _set(lang, const DlState(DlPhase.absent));
    return true;
  }

  @override
  void dispose() {
    _gone = true;
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}
