// SPDX-License-Identifier: GPL-3.0-or-later
// stand-ins for voice transcripts: a transcriber that says what it is told
// when the test lets it, and a model download moved along by hand. nothing
// here reaches the network, the engine or the speech library
import 'dart:async';

import 'package:kryfo/translate/downloads.dart';
import 'package:kryfo/translate/engine_bridge.dart' show FetchStatus;
import 'package:kryfo/translate/hant.dart' show HantConverter, HantForm;
import 'package:kryfo/voice/transcript_store.dart';
import 'package:kryfo/voice/voice_ffi.dart';
import 'package:kryfo/voice/voice_memory.dart';
import 'package:kryfo/voice/voice_models.dart';
import 'package:kryfo/voice/voice_transcripts.dart';

// one run the test lets go segment by segment, or all at once
class FakeJob implements TxJob {
  final String path;
  FakeJob(this.path);
  final _segs = StreamController<VoiceSegment>();
  final _done = Completer<VoiceResult>();
  final List<VoiceSegment> _got = [];
  bool cancelled = false;

  @override
  Stream<VoiceSegment> get segments => _segs.stream;
  @override
  Future<VoiceResult> get done => _done.future;

  @override
  void cancel() {
    cancelled = true;
    if (!_done.isCompleted) {
      _done.completeError(const VoiceError(VoiceError.cancelled));
      _done.future.ignore();
    }
    if (!_segs.isClosed) _segs.close();
  }

  void say(String text, {int at = 0}) {
    final s = VoiceSegment(
      _got.length,
      Duration(milliseconds: at),
      Duration(milliseconds: at + 1000),
      text,
    );
    _got.add(s);
    _segs.add(s);
  }

  void end([String lang = 'en']) {
    if (_done.isCompleted) return;
    _done.complete(VoiceResult(lang, List.of(_got)));
    _segs.close();
  }

  void fail([int code = VoiceError.run]) {
    if (_done.isCompleted) return;
    _done.completeError(VoiceError(code));
    _done.future.ignore();
    _segs.close();
  }
}

class FakeRunner {
  final List<FakeJob> jobs = [];
  // what each path says when [auto]: said and ended at once
  final Map<String, (String, String)> words = {};
  bool auto = false;
  int? throwCode;
  // the language each run was asked to hear, in order
  final List<String> langs = [];
  // the threads each run was given, in order
  final List<int> threads = [];

  Future<TxJob> call(String path, String lang, int threads) async {
    langs.add(lang);
    this.threads.add(threads);
    if (throwCode != null) throw VoiceError(throwCode!);
    final j = FakeJob(path);
    jobs.add(j);
    final w = words[path];
    if (auto && w != null) {
      scheduleMicrotask(() {
        j.say(w.$1);
        j.end(w.$2);
      });
    }
    return j;
  }
}

class FakeModelBackend implements ModelBackend {
  bool have;
  FakeModelBackend({this.have = false});
  final List<String> started = [];
  FetchStatus status = const FetchStatus('idle');
  String startAnswer = 'ok';

  @override
  Future<String> start(String id) async {
    started.add(id);
    if (startAnswer != 'ok') return startAnswer;
    status = const FetchStatus('running', total: kVoiceModelSize);
    return 'ok';
  }

  @override
  FetchStatus progress(String id) => status;
  @override
  void cancel(String id) => status = const FetchStatus('cancelled');
  @override
  Future<bool> installed(String id) async => have;
  @override
  Future<int> onDisk(String id) async => have ? kVoiceModelSize : 0;
  @override
  Future<String> remove(String id) async {
    have = false;
    return 'ok';
  }

  void finish() {
    have = true;
    status = const FetchStatus(
      'done',
      done: kVoiceModelSize,
      total: kVoiceModelSize,
    );
  }
}

class VoiceFakes {
  final VoiceTranscripts hub;
  final FakeRunner runner;
  final FakeModelBackend backend;
  final VoiceTxStore store;
  VoiceFakes(this.hub, this.runner, this.backend, this.store);
}

VoiceFakes fakeVoiceHub({
  bool installed = true,
  bool lib = true,
  bool quiet = false,
  VoiceTxStore? store,
  String Function()? scope,
  String Function()? appLang,
  MemRoom? Function()? room,
  int threads = 6,
  void Function()? beforeRun,
  Future<HantConverter> Function()? hant,
  HantForm Function()? reader,
}) {
  final runner = FakeRunner();
  final backend = FakeModelBackend(have: installed);
  store ??= MemoryVoiceTxStore();
  final models = VoiceModels(
    call: (_, _) async => 'error: none',
    dir: () async => '/data/user/0/app/files/voice',
    quiet: () => quiet,
  );
  final hub = VoiceTranscripts(
    models: models,
    library: () => lib ? const VoiceLibrary.unchecked('none') : null,
    store: store,
    downloads: ModelDownloads(
      backend: backend,
      onWifi: () async => true,
      wifiOnly: () => false,
      poll: const Duration(milliseconds: 50),
      quiet: () => quiet,
    ),
    runner: runner.call,
    scope: scope,
    appLang: appLang ?? () => 'en',
    room: room,
    threads: () => threads,
    beforeRun: beforeRun,
    watchEvery: const Duration(milliseconds: 20),
    hant: hant,
    reader: reader ?? () => HantForm.none,
  );
  return VoiceFakes(hub, runner, backend, store);
}
