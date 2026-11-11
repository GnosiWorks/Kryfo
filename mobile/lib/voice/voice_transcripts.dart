// SPDX-License-Identifier: GPL-3.0-or-later
// voice note transcripts: the speech model download, the transcriber, the
// settings and what each chat kept, in one place shared by every chat and
// the settings page. everything happens on the phone: the model comes once
// over tor from the pinned mirror, and nothing else reaches the network.
// with the switch off nothing here is built and no screen shows any of it.

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../desktop/desktop_mode.dart' show onDesktop;
import '../engine_strings.dart';
import '../l10n/app_locale.dart' show currentLanguage;
import '../lock_state.dart' show lockState;
import '../main.dart' show appState, session, sessionQuiet;
import '../native_libs.dart';
import '../translate/downloads.dart';
import '../translate/engine_bridge.dart' show FetchStatus;
import '../transfers.dart' show unmeteredNow;
import '../translate/hub_live.dart' show translationHubIfOn;
import 'transcript_store.dart';
import 'voice_audio.dart';
import 'voice_ffi.dart';
import 'voice_memory.dart';
import 'voice_models.dart';
import 'voice_text.dart';

const kVoiceTranscripts = true;

/// the one model there is
const kVoiceModelId = 'base';

/// its size as pinned in engine/voice/models.json, until the engine says
const kVoiceModelSize = 59707625;

/// one transcription as a chat sees it: the words as they come, then all
/// of it. [cancel] stops it, and nothing comes after
abstract class TxJob {
  Stream<VoiceSegment> get segments;
  Future<VoiceResult> get done;
  void cancel();
}

/// makes a job for the note at [path], heard in [lang] (a whisper code) on
/// [threads] threads: throws a [VoiceError] when the library, the model or
/// the audio is not there
typedef TxRunner =
    Future<TxJob> Function(String path, String lang, int threads);

class VoiceTranscripts extends ChangeNotifier {
  VoiceTranscripts({
    required this.models,
    required this.library,
    VoiceTxStore? store,
    ModelDownloads? downloads,
    TxRunner? runner,
    String Function()? scope,
    String Function()? appLang,
    Future<HansChars> Function()? hans,
    MemRoom? Function()? room,
    int Function()? threads,
    VoidCallback? beforeRun,
    this.watchEvery = const Duration(seconds: 1),
  }) : store = store ?? MemoryVoiceTxStore(),
       room = room ?? (() => null),
       threads = threads ?? voiceThreads,
       beforeRun = beforeRun ?? (() {}),
       scope = scope ?? (() => ''),
       appLang = appLang ?? (() => currentLanguage),
       _hans = hans ?? HansChars.load {
    this.downloads =
        downloads ??
        ModelDownloads(
          backend: VoiceModelBackend(models),
          onWifi: () async => true,
          wifiOnly: () => false,
          quiet: models.quiet,
        );
    this.downloads.addListener(notifyListeners);
    _runner = runner ?? _liveRunner;
  }

  /// a test's stand-in; the live one is made only while the switch is on
  @visibleForTesting
  static VoiceTranscripts? instance;

  final VoiceModels models;

  /// the transcriber, null when the build has no library
  final VoiceLibrary? Function() library;

  final VoiceTxStore store;
  late final ModelDownloads downloads;
  late final TxRunner _runner;

  // whose settings these are: an identity switch reads them again
  final String Function() scope;

  /// the app's language, which the person's own notes are heard in
  final String Function() appLang;

  // chinese words into simplified characters
  final Future<HansChars> Function() _hans;

  /// the phone's free memory now (voice_memory.dart), null: not known
  final MemRoom? Function() room;

  /// the threads a run takes with room to spare
  final int Function() threads;

  /// lets go of what can be made again (decoded pictures) before a run
  final VoidCallback beforeRun;

  /// how often a run looks at free memory
  final Duration watchEvery;

  /// the language a note is heard in: no detection, which costs a whole
  /// pass of the model. a note of theirs in the language the chat's words
  /// are in, when [theirs] knows it; the app's otherwise
  String langFor({required bool mine, String? theirs}) =>
      noteLang(mine: mine, theirs: theirs, app: appLang());

  VoiceTxSettings _settings = const VoiceTxSettings();
  VoiceTxSettings get settings => _settings;
  String? _loadedFor;
  Future<void>? _loading;

  // the settings for this identity, and whether the model is on the phone
  Future<void> ready() {
    final now = scope();
    if (_loadedFor == now && _loading != null) return _loading!;
    _loadedFor = now;
    return _loading = () async {
      try {
        _settings = await store.load();
      } catch (_) {
        _settings = const VoiceTxSettings();
      }
      // made after the vault opened, no switch heard: catch up before a read
      await dropAll();
      try {
        for (final m in await models.models()) {
          if (m.id == kVoiceModelId) _size = m.size;
        }
        await downloads.refresh(kVoiceModelId);
      } catch (_) {}
      notifyListeners();
    }();
  }

  /// offered under voice notes at all
  bool get on => _settings.on;

  bool? _lib;

  /// the build carries the transcriber
  bool get hasLibrary => _lib ??= library() != null;

  bool get modelReady => downloads.installed(kVoiceModelId);

  /// the model's size, as the download sheet says it
  int get modelSize => _size ?? kVoiceModelSize;
  int? _size;

  Future<void> saveSettings(VoiceTxSettings s) async {
    _settings = s;
    notifyListeners();
    await store.save(s);
  }

  // off deletes every saved transcript
  Future<void> setOn(bool on) async {
    if (on == _settings.on) return;
    await saveSettings(
      _settings.copyWith(on: on, offs: on ? null : _settings.offs + 1),
    );
    if (!on) {
      _stopAll();
      await dropAll();
    }
  }

  // transcripts of the times it was turned off, gone from every container
  // open now
  Future<void> dropAll() async {
    if (_settings.offs == 0) return;
    try {
      await store.dropAll(_settings.offs);
    } catch (_) {}
  }

  // the app locked: every open chat drops what it holds in memory, and no
  // note is transcribed until it opens again
  bool _locked = false;
  bool get locked => _locked;
  int _wipes = 0;
  int get wipes => _wipes;

  void lockedOut() {
    _locked = true;
    _wipes++;
    _stopAll();
    notifyListeners();
  }

  void unlocked() {
    if (!_locked) return;
    _locked = false;
    notifyListeners();
  }

  VoidCallback followLock(Listenable lock, bool Function() isLocked) {
    var was = isLocked();
    if (was) lockedOut();
    void heard() {
      final now = isLocked();
      if (now == was) return;
      was = now;
      now ? lockedOut() : unlocked();
    }

    lock.addListener(heard);
    return () => lock.removeListener(heard);
  }

  // the screens changed session (a vault shut, the decoy opened): what the
  // chats hold goes, runs stop, and a vault that opens drops what it kept
  // before an off
  VoidCallback followSessions(Listenable state, int Function() rev) {
    var last = rev();
    void heard() {
      final now = rev();
      if (now == last) return;
      last = now;
      _wipes++;
      _stopAll();
      notifyListeners();
      unawaited(dropAll());
    }

    state.addListener(heard);
    return () => state.removeListener(heard);
  }

  Future<Map<String, KeptTranscript>> kept(String chatId) async {
    try {
      return await store.kept(chatId);
    } catch (_) {
      return const {};
    }
  }

  Future<void> keep(String chatId, String uid, KeptTranscript t) async {
    if (!on || locked) return;
    try {
      await store.keep(chatId, uid, t);
    } catch (_) {}
  }

  Future<void> setOpen(String chatId, String uid, bool open) async {
    try {
      await store.setOpen(chatId, uid, open);
    } catch (_) {}
  }

  Future<void> unkeep(String chatId, String uid) async {
    try {
      await store.unkeep(chatId, uid);
    } catch (_) {}
  }

  // one note at a time: two long ones never take the cores together
  Future<void> _turn = Future.value();
  final Set<_Queued> _jobs = {};

  /// the note at [path] transcribed in [lang], after the ones asked before
  /// it. notes on sounds ("[BLANK_AUDIO]") are dropped, and chinese comes
  /// in simplified characters
  TxJob transcribe(String path, String lang) {
    final q = _Queued();
    _jobs.add(q);
    final before = _turn;
    final mine = Completer<void>();
    _turn = mine.future;
    () async {
      try {
        await before;
        if (q.stopped) return;
        if (lang == 'zh') {
          try {
            q.hans = await _hans();
          } catch (_) {}
          if (q.stopped) return;
        }
        // room first: a run that would not fit says so instead of getting
        // the app killed
        beforeRun();
        final n = voiceRunThreads(threads(), room());
        if (n == 0) {
          q.fail(const VoiceError(VoiceError.memory));
          return;
        }
        final TxJob job;
        try {
          job = await _runner(path, lang, n);
        } catch (e) {
          q.fail(e is VoiceError ? e : const VoiceError(VoiceError.run));
          return;
        }
        if (q.stopped) {
          job.cancel();
          return;
        }
        // and while it runs: free memory under the reserve stops it. not
        // known (windows): nothing to watch
        final watch = room() == null
            ? null
            : Timer.periodic(watchEvery, (_) {
                if (memRunOut(room())) q.outOfRoom();
              });
        try {
          await q.follow(job);
        } finally {
          watch?.cancel();
        }
        // the cpu is free once the run's isolate is gone
        if (job is _RunJob) await job.run.finished;
      } finally {
        _jobs.remove(q);
        mine.complete();
      }
    }();
    return q;
  }

  void _stopAll() {
    for (final q in _jobs.toList()) {
      q.cancel();
    }
  }

  Future<TxJob> _liveRunner(String path, String lang, int threads) async {
    final lib = library();
    if (lib == null) throw const VoiceError(VoiceError.library);
    // a name the start-up sweep shreds if the app dies in between
    final tmp = (await getTemporaryDirectory()).path;
    final scratch = p.join(tmp, 'vn_tx_${_hex(8)}.wav');
    // the model's pin check reads all of it: the note is read meanwhile
    final (model, audio) = await (
      models.pathOf(kVoiceModelId),
      voiceAudioOfFile(path, scratch),
    ).wait;
    if (model == null) throw const VoiceError(VoiceError.model);
    if (audio == null || audio.frames == 0) {
      throw const VoiceError(VoiceError.audio);
    }
    return _RunJob(
      lib.transcribe(model: model, audio: audio, lang: lang, threads: threads),
    );
  }

  @override
  void dispose() {
    _stopAll();
    downloads.removeListener(notifyListeners);
    super.dispose();
  }
}

String _hex(int n) {
  final r = Random.secure();
  return [
    for (var i = 0; i < n; i++)
      r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

class _RunJob implements TxJob {
  _RunJob(this.run);
  final VoiceRun run;
  @override
  Stream<VoiceSegment> get segments => run.segments;
  @override
  Future<VoiceResult> get done => run.done;
  @override
  void cancel() => run.cancel();
}

// a job waiting for its turn: the words pass through once it runs, and a
// cancel before then means it never starts
class _Queued implements TxJob {
  final _segs = StreamController<VoiceSegment>();
  final _done = Completer<VoiceResult>();
  TxJob? _job;
  bool stopped = false;
  HansChars? hans;

  // shown as it will be kept: null for a segment of sounds only, or one
  // that says the one before it again (the model stuck in a loop)
  String? _last;
  VoiceSegment? _clean(VoiceSegment s) {
    final t = cleanSegment(s.text, hans: hans);
    if (t.isEmpty || t.trim() == _last) return null;
    _last = t.trim();
    return VoiceSegment(s.index, s.start, s.end, t);
  }

  @override
  Stream<VoiceSegment> get segments => _segs.stream;
  @override
  Future<VoiceResult> get done => _done.future;

  @override
  void cancel() {
    if (stopped) return;
    stopped = true;
    _job?.cancel();
    fail(const VoiceError(VoiceError.cancelled));
  }

  /// the phone ran short of memory: the run stops and says why
  void outOfRoom() {
    if (stopped) return;
    stopped = true;
    _job?.cancel();
    fail(const VoiceError(VoiceError.memory));
  }

  void fail(VoiceError e) {
    if (!_done.isCompleted) {
      _done.completeError(e);
      _done.future.ignore();
    }
    if (!_segs.isClosed) unawaited(_segs.close());
  }

  Future<void> follow(TxJob job) async {
    _job = job;
    final sub = job.segments.listen((s) {
      final c = _clean(s);
      if (c != null && !stopped && !_segs.isClosed) _segs.add(c);
    });
    try {
      final r = await job.done;
      _last = null;
      final kept = [for (final s in r.segments) ?_clean(s)];
      if (!_done.isCompleted) _done.complete(VoiceResult(r.lang, kept));
    } catch (e) {
      fail(e is VoiceError ? e : const VoiceError(VoiceError.run));
    } finally {
      // not waited for: the turn is free once the result is in
      unawaited(sub.cancel());
      if (!_segs.isClosed) unawaited(_segs.close());
    }
  }
}

/// the speech model's download as the translation packs' controls drive
/// one: the engine fetches over tor and checks the pin. its progress is
/// read off the ui isolate, so a poll answers with the one before it
class VoiceModelBackend implements ModelBackend {
  VoiceModelBackend(this.models);
  final VoiceModels models;
  final Map<String, FetchStatus> _last = {};

  @override
  Future<String> start(String id) async {
    try {
      return await models.start(id);
    } catch (e) {
      return 'error: storage: ${e.runtimeType}';
    }
  }

  @override
  FetchStatus progress(String id) {
    unawaited(
      models.progress(id).then((s) {
        _last[id] = FetchStatus(
          s.state,
          done: s.done,
          total: s.total,
          kind: s.kind,
        );
      }, onError: (Object _) {}),
    );
    return _last[id] ?? const FetchStatus('idle');
  }

  @override
  void cancel(String id) => unawaited(models.cancel(id).catchError((_) => ''));

  @override
  Future<bool> installed(String id) async {
    try {
      return await models.installed(id);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<int> onDisk(String id) async {
    try {
      final at = await models.fileOf(id);
      if (at == null) return 0;
      var n = 0;
      for (final f in [File(at), File('$at.part')]) {
        if (await f.exists()) n += await f.length();
      }
      return n;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<String> remove(String id) async {
    _last.remove(id);
    try {
      return await models.remove(id) ? 'ok' : 'error: remove';
    } catch (e) {
      return 'error: storage: ${e.runtimeType}';
    }
  }
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
  final models = VoiceModels(
    call: _engineCall,
    dir: voiceModelsDir,
    quiet: () => sessionQuiet,
  );
  final t = VoiceTranscripts(
    models: models,
    library: () {
      if (!tried) lib = VoiceLibrary.open();
      tried = true;
      return lib;
    },
    store: DbVoiceTxStore(
      () => session.settingsDb(),
      chatDb: (id) => session.chatDb(id),
      open: () => session.openDbs(),
    ),
    // wi-fi only as translation has it: one rule for the phone's downloads
    downloads: ModelDownloads(
      backend: VoiceModelBackend(models),
      onWifi: _onWifi,
      wifiOnly: () => translationHubIfOn()?.settings.wifiOnly ?? true,
      quiet: () => sessionQuiet,
    ),
    scope: () => session.container.id,
    room: readMemRoom,
    // decoded pictures not on screen: drawn again from their files
    beforeRun: () => PaintingBinding.instance.imageCache.clear(),
  );
  t.followSessions(appState, () => appState.sessionRev);
  t.followLock(lockState, () => lockState.locked);
  return t;
}

// a computer: a cable or a vpn counts as wi-fi does for its downloads
Future<bool> _onWifi() async {
  if (onDesktop) return unmeteredNow();
  try {
    return (await Connectivity().checkConnectivity()).contains(
      ConnectivityResult.wifi,
    );
  } catch (_) {
    return false;
  }
}

typedef _S0 = Pointer<Utf8> Function();
typedef _S1 = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _S2 = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

// the check reads the whole model, so every call runs off the ui isolate
Future<String> _engineCall(String symbol, List<String> args) => Isolate.run(() {
  final lib = haloLibrary();
  final a = [for (final s in args) s.toNativeUtf8()];
  try {
    return switch (a.length) {
      0 => engineTake(lib.lookupFunction<_S0, _S0>(symbol)()),
      1 => engineTake(lib.lookupFunction<_S1, _S1>(symbol)(a[0])),
      2 => engineTake(lib.lookupFunction<_S2, _S2>(symbol)(a[0], a[1])),
      _ => throw ArgumentError('$symbol: ${a.length} arguments'),
    };
  } finally {
    for (final x in a) {
      malloc.free(x);
    }
  }
});
