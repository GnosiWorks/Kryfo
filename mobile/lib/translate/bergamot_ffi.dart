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
  });

  bool? _hasLib;
  bool get hasLib => _hasLib ??= _probe(lib);

  static bool _probe(String name) {
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

  Future<SendPort>? _port;

  Future<SendPort> _worker() => _port ??= () async {
    final hello = ReceivePort();
    await Isolate.spawn(_run, (hello.sendPort, lib));
    final port = await hello.first as SendPort;
    hello.close();
    return port;
  }();

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
    final port = await _worker();
    final reply = ReceivePort();
    port.send((reply.sendPort, '$from-$to', cfg, text));
    final out = await reply.first;
    reply.close();
    if (out is String) return out;
    throw StateError('translate: $out');
  }

  @override
  Future<void> close() async {
    final port = _port;
    _port = null;
    if (port != null) (await port).send(null);
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
    } finally {
      calloc.free(err);
    }
  });
}
