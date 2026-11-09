// SPDX-License-Identifier: GPL-3.0-or-later
// bergamot through engine/translate/native/kryfo_translate.h, in its own
// library. one isolate keeps the recent models open while translations
// come, since opening one reads about 50 MB, and goes when they stop
import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../engine_strings.dart';
import 'model_cache.dart';
import 'translator.dart';

const kTranslateLib = 'libkryfo_translate.so';

// models open at once: a pivot and one more. a 32-bit phone has little
// memory and address space to spare, so there a pivot alone
final int kMaxOpenModels = sizeOf<IntPtr>() == 4 ? 2 : 3;

// each open model holds its weights and workspace, so they go this long
// after the last translation
const kModelIdle = Duration(minutes: 2);

typedef _OpenC = Pointer<Void> Function(Pointer<Utf8>, Pointer<Pointer<Utf8>>);
typedef _TrC =
    Int32 Function(
      Pointer<Void>,
      Pointer<Pointer<Utf8>>,
      Int32,
      Pointer<Pointer<Utf8>>,
      Pointer<Pointer<Utf8>>,
    );
typedef _TrD =
    int Function(
      Pointer<Void>,
      Pointer<Pointer<Utf8>>,
      int,
      Pointer<Pointer<Utf8>>,
      Pointer<Pointer<Utf8>>,
    );
typedef _FreeC = Void Function(Pointer<Utf8>);
typedef _FreeD = void Function(Pointer<Utf8>);
typedef _CloseC = Void Function(Pointer<Void>);
typedef _CloseD = void Function(Pointer<Void>);

class BergamotTranslator implements Translator {
  // the model config for a direction (the engine writes it), null when
  // there is none
  final String? Function(String from, String to) config;
  // whether a direction's pack is on the phone
  final bool Function(String from, String to) installed;
  final String lib;
  BergamotTranslator({
    required this.config,
    required this.installed,
    this.lib = kTranslateLib,
    this.probe = libraryOpens,
    int? maxOpen,
    Duration idleAfter = kModelIdle,
  }) : maxOpen = maxOpen ?? kMaxOpenModels {
    _idle = ModelIdle(idleAfter, _shut);
  }

  final int maxOpen;

  late final ModelIdle _idle;
  @visibleForTesting
  ModelIdle get idle => _idle;

  // whether the library opens here; a test hands in its own
  final bool Function(String lib) probe;

  bool? _hasLib;
  bool get hasLib => _hasLib ??= probe(lib);

  static bool libraryOpens(String name) {
    try {
      DynamicLibrary.open(name).lookup('kt_open');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasLibrary() async => hasLib;

  @override
  Future<TranslateBlock?> blockFor(String from, String to) async {
    if (!installed(from, to)) return TranslateBlock.noModel;
    if (!hasLib) return TranslateBlock.noLib;
    return null;
  }

  Future<_Worker>? _port;

  // a worker that dies takes its waiting translations with it, and the
  // next one starts a new worker
  Future<_Worker> _worker() {
    final now = _port;
    if (now != null) return now;
    late final Future<_Worker> made;
    // after made is set, even when the spawn fails at once
    void gone() => scheduleMicrotask(() {
      if (identical(_port, made)) _port = null;
    });
    made = _Worker.spawn(lib, maxOpen, gone);
    return _port = made;
  }

  // directions some translation holds open, with how many hold each
  final Map<String, int> _held = {};
  @visibleForTesting
  Map<String, int> get held => Map.unmodifiable(_held);

  @override
  Future<T> holding<T>(
    List<(String, String)> route,
    Future<T> Function() run,
  ) async {
    final keys = [for (final (f, t) in route) '$f-$t'];
    for (final k in keys) {
      _held[k] = (_held[k] ?? 0) + 1;
    }
    _idle.begin();
    try {
      return await run();
    } finally {
      var freed = false;
      for (final k in keys) {
        final n = (_held[k] ?? 1) - 1;
        if (n > 0) {
          _held[k] = n;
        } else {
          _held.remove(k);
          freed = true;
        }
      }
      // what was kept past the cap for this one can go now
      if (freed) _trim();
      _idle.end();
    }
  }

  void _trim() {
    final port = _port;
    if (port == null) return;
    final keep = [..._held.keys];
    port.then((w) => w.trim(keep), onError: (Object _) {});
  }

  @override
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async => (await translateAll([text], from: from, to: to)).single;

  // one kt_translate call for all of them: one batch is about three times
  // quicker per line than a call each
  @override
  Future<List<String>> translateAll(
    List<String> texts, {
    required String from,
    required String to,
  }) async {
    final block = await blockFor(from, to);
    if (block != null) throw TranslateUnavailable(block);
    final cfg = config(from, to);
    if (cfg == null) throw const TranslateUnavailable(TranslateBlock.noLib);
    if (texts.isEmpty) return const [];
    _idle.begin();
    final Object? out;
    try {
      out = await (await _worker()).ask('$from-$to', cfg, texts, [
        ..._held.keys,
      ]);
    } finally {
      _idle.end();
    }
    if (out is List && out.length == texts.length) {
      return [for (final s in out) s as String];
    }
    throw StateError('translate: ${out is Map ? out['err'] : 'no answer'}');
  }

  // never under a translation: the worker goes once nothing runs
  @override
  Future<void> close() async => _idle.away();

  void _shut() {
    final port = _port;
    _port = null;
    if (port == null) return;
    port.then((w) => w.port.send(null), onError: (Object _) {});
  }
}

class _Worker {
  final SendPort port;
  final Set<Completer<Object?>> _waiting = {};
  bool _dead = false;
  _Worker._(this.port);

  static Future<_Worker> spawn(
    String lib,
    int maxOpen,
    void Function() gone,
  ) async {
    final hello = RawReceivePort();
    final exit = RawReceivePort();
    final ready = Completer<_Worker>();
    _Worker? w;
    void die() {
      hello.close();
      exit.close();
      gone();
      w?._die();
      if (!ready.isCompleted) {
        ready.completeError(StateError('translate: worker gone'));
      }
    }

    hello.handler = (Object? p) {
      hello.close();
      if (ready.isCompleted || p is! SendPort) return;
      ready.complete(w = _Worker._(p));
    };
    exit.handler = (Object? _) => die();
    try {
      await Isolate.spawn(_run, (
        hello.sendPort,
        lib,
        maxOpen,
      ), onExit: exit.sendPort);
    } catch (_) {
      die();
    }
    return ready.future;
  }

  void _die() {
    _dead = true;
    final left = [..._waiting];
    _waiting.clear();
    for (final c in left) {
      c.complete(const {'err': 'worker gone'});
    }
  }

  void trim(List<String> keep) {
    if (_dead) return;
    try {
      port.send(keep);
    } catch (_) {}
  }

  Future<Object?> ask(
    String key,
    String cfg,
    List<String> texts,
    List<String> keep,
  ) async {
    final done = Completer<Object?>();
    if (_dead) return const {'err': 'worker gone'};
    final reply = RawReceivePort((Object? m) {
      if (!done.isCompleted) done.complete(m);
    });
    _waiting.add(done);
    try {
      port.send((reply.sendPort, key, cfg, texts, keep));
      return await done.future;
    } finally {
      _waiting.remove(done);
      reply.close();
    }
  }
}

// the worker: models by direction, opened on first use, the least recently
// used closed past the cap, all closed on null. it handles one message at a
// time, so nothing it closes is translating
void _run((SendPort, String, int) args) {
  final (hello, name, maxOpen) = args;
  final inbox = ReceivePort();
  hello.send(inbox.sendPort);
  final lib = DynamicLibrary.open(name);
  final open = lib.lookupFunction<_OpenC, _OpenC>('kt_open');
  final tr = lib.lookupFunction<_TrC, _TrD>('kt_translate');
  final free = lib.lookupFunction<_FreeC, _FreeD>('kt_free');
  final close = lib.lookupFunction<_CloseC, _CloseD>('kt_close');
  final models = ModelCache<Pointer<Void>>(maxOpen, close);

  String take(Pointer<Utf8> p) => nativeTakeSecret(p, free);

  inbox.listen((m) {
    if (m == null) {
      models.closeAll();
      inbox.close();
      Isolate.exit();
    }
    // a bare list of held directions: a hold let go, trim to the cap
    if (m is List) {
      models.trim(m.cast<String>());
      return;
    }
    final (reply, key, cfg, texts, keep) =
        m as (SendPort, String, String, List<String>, List<String>);
    final err = calloc<Pointer<Utf8>>();
    try {
      var h = models.use(key);
      if (h == null) {
        // closed before the open, so the peak stays at the cap
        models.makeRoom(key, keep);
        final c = cfg.toNativeUtf8();
        try {
          h = open(c, err);
        } finally {
          malloc.free(c);
        }
        if (h == nullptr) {
          reply.send({'err': take(err.value)});
          return;
        }
        models.add(key, h);
      }
      final n = texts.length;
      final ins = calloc<Pointer<Utf8>>(n);
      final outs = calloc<Pointer<Utf8>>(n);
      try {
        for (var i = 0; i < n; i++) {
          ins[i] = texts[i].toNativeUtf8();
        }
        if (tr(h, ins, n, outs, err) != 0) {
          reply.send({'err': take(err.value)});
          return;
        }
        reply.send([for (var i = 0; i < n; i++) take(outs[i])]);
      } finally {
        for (var i = 0; i < n; i++) {
          if (ins[i] != nullptr) freeSecret(ins[i]);
        }
        calloc.free(ins);
        calloc.free(outs);
      }
    } catch (e) {
      // the one asking hears of it; the open models stay
      reply.send({'err': '${e.runtimeType}'});
    } finally {
      calloc.free(err);
    }
  });
}
