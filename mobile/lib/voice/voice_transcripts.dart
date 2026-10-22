// SPDX-License-Identifier: GPL-3.0-or-later
// voice note transcripts: the speech model download and the transcriber.
// off until the bubble, its strings and the storage rules are in; while
// off nothing here is built and no screen asks for it.

import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../engine_strings.dart';
import '../main.dart' show sessionQuiet;
import 'voice_ffi.dart';
import 'voice_models.dart';

// off until the transcript ui ships
const kVoiceTranscripts = false;

class VoiceTranscripts {
  VoiceTranscripts({required this.models, required this.library});

  /// a test's stand-in; the live one is made only while the switch is on
  @visibleForTesting
  static VoiceTranscripts? instance;

  final VoiceModels models;

  /// the transcriber, null when the build has no library
  final VoiceLibrary? Function() library;
}

/// the transcripts while the switch is on, or a test's. null: nothing of
/// them is built
VoiceTranscripts? voiceTranscriptsIfOn() =>
    VoiceTranscripts.instance ??
    (kVoiceTranscripts ? VoiceTranscripts.instance = _live() : null);

// the models are the phone's, not an identity's: one copy whoever reads
Future<String> voiceModelsDir() async =>
    p.join((await getApplicationSupportDirectory()).path, 'voice');

VoiceTranscripts _live() {
  VoiceLibrary? lib;
  var tried = false;
  return VoiceTranscripts(
    models: VoiceModels(
      call: _engineCall,
      dir: voiceModelsDir,
      quiet: () => sessionQuiet,
    ),
    library: () {
      if (!tried) lib = VoiceLibrary.open();
      tried = true;
      return lib;
    },
  );
}

typedef _S0 = Pointer<Utf8> Function();
typedef _S1 = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _S2 = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _S3 =
    Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

// the check reads the whole model, so every call runs off the ui isolate
Future<String> _engineCall(String symbol, List<String> args) => Isolate.run(() {
  final lib = Platform.isAndroid
      ? DynamicLibrary.open('libhalo.so')
      : DynamicLibrary.process();
  final a = [for (final s in args) s.toNativeUtf8()];
  try {
    return engineTake(switch (a.length) {
      0 => lib.lookupFunction<_S0, _S0>(symbol)(),
      1 => lib.lookupFunction<_S1, _S1>(symbol)(a[0]),
      2 => lib.lookupFunction<_S2, _S2>(symbol)(a[0], a[1]),
      3 => lib.lookupFunction<_S3, _S3>(symbol)(a[0], a[1], a[2]),
      _ => throw ArgumentError('$symbol: ${a.length} arguments'),
    });
  } finally {
    for (final x in a) {
      malloc.free(x);
    }
  }
});
