// SPDX-License-Identifier: GPL-3.0-or-later
// where the engine's calls are found. android loads libhalo.so by name, the
// linux runner links it into the process. on windows the runner loads
// halo.dll by full path, and dart opens it the same way: a lookup through
// DynamicLibrary.process() there opens the process for reading first, which
// kryfo.exe's own dacl refuses
import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;

DynamicLibrary haloLibrary() {
  if (Platform.isAndroid) return DynamicLibrary.open('libhalo.so');
  if (Platform.isWindows) return besideExe('halo.dll');
  return DynamicLibrary.process();
}

/// a dll in kryfo.exe's own folder, already loaded by the runner
DynamicLibrary besideExe(String name) =>
    DynamicLibrary.open(p.join(p.dirname(Platform.resolvedExecutable), name));
