// SPDX-License-Identifier: GPL-3.0-or-later
// one chat's voice note transcripts: which are open, what each one says,
// and the one being made. what was made is kept beside its note in the
// chat's encrypted database and goes with it; memory goes behind the lock.
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'transcript_store.dart';
import 'voice_ffi.dart' show VoiceError;
import 'voice_transcripts.dart';

enum TxPhase {
  // the link only, words made before or not
  closed,
  // the model runs: the words come as it hears them
  working,
  // the words, or none when the note holds no speech
  shown,
  // nothing to make out, or the run broke
  failed,
}

@immutable
class NoteTx {
  final TxPhase phase;
  final List<TxPiece> pieces;
  // the language the model heard, once it is done
  final String lang;
  const NoteTx(this.phase, {this.pieces = const [], this.lang = ''});

  String get text => pieces.map((p) => p.text).join().trim();

  /// done, and the note held no speech: said so instead of words
  bool get silent => phase == TxPhase.shown && text.isEmpty;
}

/// what an open needs first
enum TxNeed {
  // the speech model is not on the phone: the download sheet
  model,
}

/// what a chat's translation knows a transcript by: never kept on disk, as
/// it is made again from the words in a moment
String txTranslateKey(String uid) => '~vt:$uid';

class ChatTranscripts extends ChangeNotifier {
  final VoiceTranscripts hub;
  final String chatId;

  /// the language the chat's own words are in, when they say: notes of
  /// theirs are heard in it
  final String? Function()? theirLang;
  ChatTranscripts(this.hub, this.chatId, {this.theirLang})
    : _seenWipes = hub.wipes {
    hub.addListener(_hubChanged);
    unawaited(_load());
  }

  int _seenWipes;
  bool _gone = false;

  Map<String, KeptTranscript> _kept = {};
  bool _keptRead = false;
  bool _keptReading = false;
  // made or making now, not kept yet
  final Map<String, NoteTx> _live = {};
  final Map<String, TxJob> _jobs = {};
  // ones that went (burned, deleted, unsent): a run still under way for one
  // is not kept
  final Set<String> _went = {};

  Future<void> _load() async {
    await hub.ready();
    await _readKept();
  }

  Future<void> _readKept() async {
    if (_keptReading || hub.locked || !hub.on || _gone) return;
    _keptReading = true;
    final w = hub.wipes;
    final k = await hub.kept(chatId);
    _keptReading = false;
    if (_gone || hub.wipes != w || hub.locked || !hub.on) return;
    // one made while it was read is newer; one that went meanwhile stays gone
    _kept = {...k, ..._kept}..removeWhere((u, _) => _went.contains(u));
    _keptRead = true;
    notifyListeners();
  }

  void _wipe() {
    for (final j in _jobs.values) {
      j.cancel();
    }
    _jobs.clear();
    _live.clear();
    _kept = {};
    _keptRead = false;
  }

  void _hubChanged() {
    if (_gone) return;
    if (hub.wipes != _seenWipes) {
      _seenWipes = hub.wipes;
      _wipe();
    }
    // turned off: what was kept is deleted, so none of it stays here
    if (!hub.on && (_keptRead || _live.isNotEmpty)) _wipe();
    if (!_keptRead && !hub.locked && hub.on) unawaited(_readKept());
    notifyListeners();
  }

  /// whether a note gets the link at all: transcripts on, the build able
  /// to make them, the app open, and a note the chat knows by its uid
  bool offered(String? uid) =>
      uid != null && hub.on && !hub.locked && hub.hasLibrary;

  NoteTx of(String uid) {
    final live = _live[uid];
    if (live != null) return live;
    final k = _kept[uid];
    if (k == null) return const NoteTx(TxPhase.closed);
    return NoteTx(
      k.open ? TxPhase.shown : TxPhase.closed,
      pieces: k.pieces,
      lang: k.lang,
    );
  }

  /// the words to copy: only while they show
  String? shownText(String uid) {
    final n = of(uid);
    return n.phase == TxPhase.shown && n.text.isNotEmpty ? n.text : null;
  }

  /// the link's tap: words made before open at once, model or not; new
  /// ones need the model, and say so. [mine]: a note the person sent, heard
  /// in the app's language
  Future<TxNeed?> open(String uid, String path, {bool mine = false}) async {
    if (!offered(uid) || _went.contains(uid)) return null;
    final now = of(uid);
    if (now.phase == TxPhase.working || now.phase == TxPhase.shown) {
      return null;
    }
    final k = _kept[uid];
    if (k != null) {
      _kept[uid] = k.opened(true);
      notifyListeners();
      unawaited(hub.setOpen(chatId, uid, true));
      return null;
    }
    if (!hub.modelReady) return TxNeed.model;
    _run(uid, path, mine);
    return null;
  }

  /// folded back; the words stay for the next tap
  void hide(String uid) {
    final k = _kept[uid];
    if (_live[uid]?.phase == TxPhase.failed) {
      _live.remove(uid);
      notifyListeners();
      return;
    }
    if (k == null) return;
    _kept[uid] = k.opened(false);
    notifyListeners();
    unawaited(hub.setOpen(chatId, uid, false));
  }

  /// after a failed run
  Future<TxNeed?> retry(String uid, String path, {bool mine = false}) async {
    if (_live[uid]?.phase == TxPhase.failed) _live.remove(uid);
    return open(uid, path, mine: mine);
  }

  void _run(String uid, String path, bool mine) {
    final w = hub.wipes;
    bool still() =>
        !_gone && hub.wipes == w && !hub.locked && !_went.contains(uid);
    _live[uid] = const NoteTx(TxPhase.working);
    notifyListeners();
    String? theirs;
    if (!mine) {
      try {
        theirs = theirLang?.call();
      } catch (_) {}
    }
    final job = hub.transcribe(path, hub.langFor(mine: mine, theirs: theirs));
    _jobs[uid] = job;
    final got = <TxPiece>[];
    job.segments.listen((s) {
      if (!still() || _jobs[uid] != job) return;
      got.add(TxPiece(s.start.inMilliseconds, s.end.inMilliseconds, s.text));
      _live[uid] = NoteTx(TxPhase.working, pieces: List.unmodifiable(got));
      notifyListeners();
    });
    job.done.then(
      (r) {
        if (_jobs[uid] == job) _jobs.remove(uid);
        if (!still()) return;
        final pieces = [
          for (final s in r.segments)
            TxPiece(s.start.inMilliseconds, s.end.inMilliseconds, s.text),
        ];
        final t = KeptTranscript(
          lang: r.lang,
          model: kVoiceModelId,
          pieces: pieces,
        );
        _live.remove(uid);
        // no words is an answer too: kept, so the note says it at once
        _kept[uid] = t;
        unawaited(hub.keep(chatId, uid, t));
        notifyListeners();
      },
      onError: (Object e) {
        if (_jobs[uid] == job) _jobs.remove(uid);
        if (!still()) return;
        // a stop is no failure: back to the link
        if (e is VoiceError && e.code == VoiceError.cancelled) {
          _live.remove(uid);
        } else {
          _live[uid] = const NoteTx(TxPhase.failed);
        }
        notifyListeners();
      },
    );
  }

  /// a note that burned, was deleted or unsent: its transcript goes from
  /// memory now (its row goes with the message), and a run for it stops
  void forget(String uid) {
    _went.add(uid);
    _jobs.remove(uid)?.cancel();
    final had = _live.remove(uid) != null || _kept.remove(uid) != null;
    unawaited(hub.unkeep(chatId, uid));
    if (had && !_gone) notifyListeners();
  }

  @override
  void dispose() {
    _gone = true;
    for (final j in _jobs.values) {
      j.cancel();
    }
    _jobs.clear();
    _live.clear();
    _kept = {};
    hub.removeListener(_hubChanged);
    super.dispose();
  }
}
