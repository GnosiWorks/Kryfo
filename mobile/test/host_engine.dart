// SPDX-License-Identifier: GPL-3.0-or-later
// the engine built for this computer (tool/host_engine.sh), loaded into the
// test's process so the app's own lookups find it there, as they find
// libhalo.so on a phone. false when it is not built
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

typedef _OpenC = Pointer<Void> Function(Pointer<Utf8>, Int32);
typedef _Open = Pointer<Void> Function(Pointer<Utf8>, int);

const _now = 0x2;
const _global = 0x100;

bool loadHostEngine([String? path]) {
  if (!Platform.isLinux) return false;
  final at =
      path ??
      Platform.environment['KRYFO_HOST_ENGINE'] ??
      p.absolute('../engine/build/host/libhalo.so');
  if (!File(at).existsSync()) return false;
  final open = DynamicLibrary.process().lookupFunction<_OpenC, _Open>('dlopen');
  final name = at.toNativeUtf8();
  try {
    return open(name, _now | _global) != nullptr;
  } finally {
    calloc.free(name);
  }
}
