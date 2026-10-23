// SPDX-License-Identifier: GPL-3.0-or-later
// translation's calls into the engine (engine/translate_ffi.go). an engine
// without them, or none in a test, reads as not there: a download says it
// cannot start
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import '../engine_strings.dart';
import 'catalog.dart';

typedef _S0 = Pointer<Utf8> Function();
typedef _S1 = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _S2 = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _S3 =
    Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

DynamicLibrary _halo() => Platform.isAndroid
    ? DynamicLibrary.open('libhalo.so')
    : DynamicLibrary.process();

// one call with string arguments; null when the engine has no such call
String? _call(DynamicLibrary lib, String symbol, List<String> args) {
  final ps = [for (final a in args) a.toNativeUtf8()];
  try {
    return switch (ps.length) {
      0 => engineTake(lib.lookupFunction<_S0, _S0>(symbol)()),
      1 => engineTake(lib.lookupFunction<_S1, _S1>(symbol)(ps[0])),
      2 => engineTake(lib.lookupFunction<_S2, _S2>(symbol)(ps[0], ps[1])),
      _ => engineTake(
        lib.lookupFunction<_S3, _S3>(symbol)(ps[0], ps[1], ps[2]),
      ),
    };
  } on ArgumentError {
    return null;
  } finally {
    for (final p in ps) {
      freeSecret(p);
    }
  }
}

// a download as the engine reports it
class FetchStatus {
  // idle, running, done, failed, cancelled
  final String state;
  final int done;
  final int total;
  // for a failure: "hash" or "net"
  final String kind;
  final String err;
  const FetchStatus(
    this.state, {
    this.done = 0,
    this.total = 0,
    this.kind = '',
    this.err = '',
  });

  static FetchStatus parse(String s) {
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      return FetchStatus(
        j['state'] as String? ?? 'idle',
        done: (j['done'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        kind: j['kind'] as String? ?? '',
        err: j['err'] as String? ?? '',
      );
    } catch (_) {
      return const FetchStatus('failed', kind: 'net', err: 'bad answer');
    }
  }
}

abstract class TranslateEngine {
  TranslateCatalog? catalog();
  // "ok", or "error: ..."
  Future<String> fetch(String lang, String dir);
  FetchStatus progress(String lang);
  void cancel(String lang);
  Future<bool> installed(String lang, String dir);
  Future<String> remove(String lang, String dir);
  // the bergamot config for a direction, or null
  String? config(String from, String to, String dir);
}

class FfiTranslateEngine implements TranslateEngine {
  DynamicLibrary? _lib;
  bool _tried = false;
  // a call the engine lacks is not looked up again
  final Set<String> _missing = {};

  DynamicLibrary? get _l {
    if (!_tried) {
      _tried = true;
      try {
        _lib = _halo();
      } catch (_) {
        _lib = null;
      }
    }
    return _lib;
  }

  String? _ask(String symbol, List<String> args) {
    final lib = _l;
    if (lib == null || _missing.contains(symbol)) return null;
    final out = _call(lib, symbol, args);
    if (out == null) _missing.add(symbol);
    return out;
  }

  @override
  TranslateCatalog? catalog() {
    final s = _ask('HaloTranslateCatalog', const []);
    return s == null ? null : TranslateCatalog.parse(s);
  }

  @override
  Future<String> fetch(String lang, String dir) async =>
      _ask('HaloTranslateFetch', [lang, dir]) ??
      'error: engine has no downloads';

  @override
  FetchStatus progress(String lang) {
    final s = _ask('HaloTranslateProgress', [lang]);
    return s == null ? const FetchStatus('idle') : FetchStatus.parse(s);
  }

  @override
  void cancel(String lang) => _ask('HaloTranslateCancel', [lang]);

  // reads every byte of the models, so off the ui thread
  bool _has(String symbol) {
    final lib = _l;
    if (lib == null || _missing.contains(symbol)) return false;
    if (lib.providesSymbol(symbol)) return true;
    _missing.add(symbol);
    return false;
  }

  @override
  Future<bool> installed(String lang, String dir) async {
    if (!_has('HaloTranslateInstalled')) return false;
    final out = await Isolate.run(
      () => _call(_halo(), 'HaloTranslateInstalled', [lang, dir]),
    );
    if (out == null) _missing.add('HaloTranslateInstalled');
    return out == 'yes';
  }

  @override
  Future<String> remove(String lang, String dir) async =>
      _ask('HaloTranslateRemove', [lang, dir]) ?? 'error: engine';

  @override
  String? config(String from, String to, String dir) {
    final s = _ask('HaloTranslateConfig', [from, to, dir]);
    return s == null || s.startsWith('error') ? null : s;
  }
}
