// SPDX-License-Identifier: GPL-3.0-or-later
// bergamot through engine/translate/native/kryfo_translate.h, in its own
// library. one long-lived isolate keeps each model open, since opening one
// reads about 50 MB
import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import '../engine_strings.dart';
import 'translator.dart';

const kTranslateLib = 'libkryfo_translate.so';

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
  });

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
    made = _Worker.spawn(lib, gone);
    return _port = made;
  }

  @override
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    final block = await blockFor(from, to);
    if (block != null) throw TranslateUnavailable(block);
    final cfg = config(from, to);
    if (cfg == null) throw const TranslateUnavailable(TranslateBlock.noLib);
    final out = await (await _worker()).ask('$from-$to', cfg, text);
    if (out is String) return out;
    throw StateError('translate: ${out is Map ? out['err'] : 'no answer'}');
  }

  @override
  Future<void> close() async {
    final port = _port;
    _port = null;
    if (port == null) return;
    try {
      (await port).port.send(null);
    } catch (_) {}
  }
}

class _Worker {
  final SendPort port;
  final Set<Completer<Object?>> _waiting = {};
  bool _dead = false;
  _Worker._(this.port);

  static Future<_Worker> spawn(String lib, void Function() gone) async {
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
      await Isolate.spawn(_run, (hello.sendPort, lib), onExit: exit.sendPort);
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

  Future<Object?> ask(String key, String cfg, String text) async {
    final done = Completer<Object?>();
    if (_dead) return const {'err': 'worker gone'};
    final reply = RawReceivePort((Object? m) {
      if (!done.isCompleted) done.complete(m);
    });
    _waiting.add(done);
    try {
      port.send((reply.sendPort, key, cfg, text));
      return await done.future;
    } finally {
      _waiting.remove(done);
      reply.close();
    }
  }
}

// the worker: models by direction, opened on first use, all closed on null
void _run((SendPort, String) args) {
  final (hello, name) = args;
  final inbox = ReceivePort();
  hello.send(inbox.sendPort);
  final lib = DynamicLibrary.open(name);
  final open = lib.lookupFunction<_OpenC, _OpenC>('kt_open');
  final tr = lib.lookupFunction<_TrC, _TrD>('kt_translate');
  final free = lib.lookupFunction<_FreeC, _FreeD>('kt_free');
  final close = lib.lookupFunction<_CloseC, _CloseD>('kt_close');
  final models = <String, Pointer<Void>>{};

  String take(Pointer<Utf8> p) => nativeTakeSecret(p, free);

  inbox.listen((m) {
    if (m == null) {
      for (final h in models.values) {
        close(h);
      }
      models.clear();
      inbox.close();
      Isolate.exit();
    }
    final (reply, key, cfg, text) = m as (SendPort, String, String, String);
    final err = calloc<Pointer<Utf8>>();
    try {
      var h = models[key];
      if (h == null) {
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
        models[key] = h;
      }
      final t = text.toNativeUtf8();
      final ins = calloc<Pointer<Utf8>>()..value = t;
      final outs = calloc<Pointer<Utf8>>();
      try {
        if (tr(h, ins, 1, outs, err) != 0) {
          reply.send({'err': take(err.value)});
          return;
        }
        reply.send(take(outs.value));
      } finally {
        freeSecret(t);
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
