// SPDX-License-Identifier: GPL-3.0-or-later
// the developer chat's first send: the name it goes out under, held in
// memory until then, and the one start every kind of message asks for
// before anything of it is saved. nothing here reaches the network

import 'package:flutter/foundation.dart';

import 'dev_lane.dart' show DevRefusal, DevSealRefused;

// how a first send's start came out
enum DevStart {
  // started, now or before: the message goes on
  ok,
  // the pinned key did not check out: nothing is saved or sent
  keyFailed,
  // nothing to start: the chat is gone, or there is no key to talk to
  none,
}

// an encrypt for the dev chat found a key that is not the pinned one
class DevKeyCheckFailed implements Exception {
  const DevKeyCheckFailed();

  @override
  String toString() => 'dev chat: the pinned key did not check out';
}

// a start or a seal that stopped at the key check, whoever threw it. the
// chat says its line for these, and only for these
bool devKeyFailed(Object e) =>
    e is DevKeyCheckFailed ||
    (e is DevSealRefused && e.why == DevRefusal.keyCheck);

// what a media send answers when its seal stopped at the key check
const kDevKeyFailed = 'error: dev key';

// what can be written to the developer before he answers, on both sides
const kDevCap = 5;

typedef DevBegin = Future<DevStart> Function({required bool anon});

// a start that stands in for the app's own
@visibleForTesting
DevBegin? devBeginForTest;

// the start a chat asks for: the app's own, unless a test stands in
DevBegin devBeginOf(DevBegin app) => devBeginForTest ?? app;

// anonymous, chosen and not sent yet, per session and chat. kept while the
// app runs, so leaving the chat never puts the three words back unasked
final _chosen = <String>{};

// a chat deleted before its first send comes back with the three words
void forgetDevChoices() => _chosen.clear();

// the chat before its first message and at it. the choice makes no keys
// and writes nothing; the first message of any kind starts the chat with
// it, once, however many messages ask at the same moment, and from then
// on it is fixed
class DevOpening extends ChangeNotifier {
  DevOpening({
    required this.memo,
    required bool started,
    required bool anon,
    required DevBegin begin,
  }) : _started = started,
       _anon = started ? anon : _chosen.contains(memo),
       _begin = begin;

  // where the choice waits for the first send
  final String memo;
  final DevBegin _begin;
  bool _started;
  bool _anon;
  Future<DevStart>? _running;

  bool get started => _started;
  // written anonymously, or about to be
  bool get anon => _anon;
  // the start is on its way: the choice holds still for it
  bool get busy => _running != null;

  bool choose({required bool anon}) {
    if (_started || busy || anon == _anon) return false;
    _anon = anon;
    if (anon) {
      _chosen.add(memo);
    } else {
      _chosen.remove(memo);
    }
    notifyListeners();
    return true;
  }

  // started somewhere else: another screen of the same chat
  void sync({required bool started, required bool anon}) {
    if (!started || _started) return;
    _started = true;
    _anon = anon;
    _chosen.remove(memo);
    notifyListeners();
  }

  Future<DevStart> ensure() {
    if (_started) return Future.value(DevStart.ok);
    final running = _running;
    if (running != null) return running;
    final r = _running = _start();
    notifyListeners();
    return r;
  }

  Future<DevStart> _start() async {
    DevStart r;
    try {
      r = await _begin(anon: _anon);
    } catch (e) {
      // a start that broke half way sends nothing
      r = devKeyFailed(e) ? DevStart.keyFailed : DevStart.none;
    } finally {
      _running = null;
    }
    if (r == DevStart.ok) {
      _started = true;
      _chosen.remove(memo);
    }
    notifyListeners();
    return r;
  }
}
