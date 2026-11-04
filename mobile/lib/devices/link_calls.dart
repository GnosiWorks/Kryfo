// SPDX-License-Identifier: GPL-3.0-or-later
// the engine's link calls (engine/dev_link.go): one link at a time on each
// side, json in and out. the engine runs the rendezvous and the door
// itself; the app reads its state and answers what only it can (the
// person's yes, the phone's signature, the new device's bundles)
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../engine_strings.dart' show engineTakeSecret;
import '../native_libs.dart';

/// where the link calls go: the engine, or a stand-in in tests
abstract class LinkCalls {
  Map<String, dynamic> call(String op, Map<String, Object?> args);
}

typedef _LinkRunC = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _LinkRun = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

/// the engine's HaloDevLink, bound here and nowhere else
class EngineLinkCalls implements LinkCalls {
  EngineLinkCalls([DynamicLibrary? lib]) {
    final l = lib ?? haloLibrary();
    _run = l.lookupFunction<_LinkRunC, _LinkRun>('HaloDevLink');
  }

  late final _LinkRun _run;

  @override
  Map<String, dynamic> call(String op, Map<String, Object?> args) {
    final o = op.toNativeUtf8();
    final a = jsonEncode(args).toNativeUtf8();
    try {
      // an answer may carry the history stream's key: zeroed once read
      return jsonDecode(engineTakeSecret(_run(o, a))) as Map<String, dynamic>;
    } finally {
      calloc.free(o);
      calloc.free(a);
    }
  }
}
