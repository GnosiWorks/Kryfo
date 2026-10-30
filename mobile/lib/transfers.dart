// SPDX-License-Identifier: GPL-3.0-or-later
// what a file on its way does and when: how fast it moves and how long it
// has left, which files come on their own (automatic download), and the
// files filed before their bytes, which wait for a tap or for wi-fi
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'container.dart';
import 'voice_format.dart' show isVoiceName;
import 'l10n/l10n.dart';
import 'l10n/numbers.dart';
import 'open_file.dart' show nameSaysVideo;
import 'widgets/media_bubbles.dart' show humanFileSize;

// ---- how fast, how long ----

/// a transfer's pace from the share of it done over time. the first
/// seconds of a tor circuit say little, so nothing is said before
/// [settle]; the rate is an average over the last [window]
class TransferPace {
  TransferPace({
    this.window = const Duration(seconds: 12),
    this.settle = const Duration(seconds: 3),
  });

  final Duration window;
  final Duration settle;
  final List<(int, double)> _seen = [];
  int? _first;

  /// [share] of it done at [atMs]. a share that went back (a resend from
  /// the start) starts the pace over
  void add(int atMs, double share) {
    if (_seen.isNotEmpty && share < _seen.last.$2) _seen.clear();
    _first ??= atMs;
    if (_seen.isEmpty) _first = atMs;
    _seen.add((atMs, share));
    final cut = atMs - window.inMilliseconds;
    while (_seen.length > 2 && _seen.first.$1 < cut) {
      _seen.removeAt(0);
    }
  }

  /// seconds left, or null while too little is known
  int? secondsLeft() {
    if (_seen.length < 2) return null;
    final (t0, s0) = _seen.first;
    final (t1, s1) = _seen.last;
    if (t1 - (_first ?? t1) < settle.inMilliseconds) return null;
    if (s1 >= 1) return 0;
    final dt = t1 - t0;
    final ds = s1 - s0;
    if (dt <= 0 || ds <= 0) return null;
    return ((1 - s1) * dt / ds / 1000).ceil();
  }
}

/// how long is left, as a part of a line: under a minute, whole minutes
/// rounded up, whole hours past ninety minutes
String leftText(int secs) {
  if (secs < 60) return l10n.transferLeftSoon;
  final m = (secs / 60).ceil();
  if (m <= 90) return l10n.transferLeftMinutes(whole(m));
  return l10n.transferLeftHours(whole((m / 60).round()));
}

/// "12.4 MB of 40.0 MB", the part done of [total] bytes
String doneOfText(double share, int total) => l10n.transferDoneOf(
  humanFileSize((share.clamp(0.0, 1.0) * total).round()),
  humanFileSize(total),
);

// ---- automatic download ----

/// what an automatic download waits for
enum AutoGet { always, wifi, never }

/// the kinds a person sets apart. a voice note always comes: it is small,
/// and one that waits for a tap is a message unheard
enum GetKind { photo, video, file }

/// a file's kind as the frame's message tells it. null for a voice note
GetKind? getKindOf(String? fileName) {
  if (fileName == null) return GetKind.photo;
  if (isVoiceName(fileName)) return null;
  if (nameSaysVideo(fileName)) return GetKind.video;
  return GetKind.file;
}

/// photos come on any network, videos and files on wi-fi: a file waiting
/// on the service is a file kept there longer, so most come on their own,
/// and mobile data is not spent on the big ones unasked
const kAutoGetDefaults = {
  GetKind.photo: AutoGet.always,
  GetKind.video: AutoGet.wifi,
  GetKind.file: AutoGet.wifi,
};

const kAutoGetKeys = {
  GetKind.photo: 'kryfo.get.photo',
  GetKind.video: 'kryfo.get.video',
  GetKind.file: 'kryfo.get.file',
};

AutoGet _autoGetOf(String? s, GetKind k) =>
    AutoGet.values.where((v) => v.name == s).firstOrNull ??
    kAutoGetDefaults[k]!;

/// each kind's setting, as kept for [c]
Future<Map<GetKind, AutoGet>> loadAutoGet([
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  return {
    for (final k in GetKind.values)
      k: _autoGetOf(prefs.getString(c.key(kAutoGetKeys[k]!)), k),
  };
}

Future<void> saveAutoGet(
  GetKind k,
  AutoGet v, [
  HaloContainer c = HaloContainer.everyday,
]) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(c.key(kAutoGetKeys[k]!), v.name);
}

/// a file of [kind] comes on its own now. [unmetered]: wi-fi or a cable
bool autoGets(Map<GetKind, AutoGet> set, GetKind? kind, bool unmetered) {
  if (kind == null) return true;
  return switch (set[kind] ?? kAutoGetDefaults[kind]!) {
    AutoGet.always => true,
    AutoGet.wifi => unmetered,
    AutoGet.never => false,
  };
}

/// wi-fi or a cable now. a test sets its own answer
Future<bool> Function() unmeteredNow = _unmetered;

Future<bool> _unmetered() async {
  try {
    final r = await Connectivity().checkConnectivity();
    return r.contains(ConnectivityResult.wifi) ||
        r.contains(ConnectivityResult.ethernet);
  } catch (_) {
    return false;
  }
}

// ---- files filed before their bytes ----

/// how a filed file that is not here yet stands
enum WaitState {
  // waits for a tap, or for wi-fi
  asks,
  // on its way
  coming,
  // stopped by the person: only a tap goes on
  paused,
}

class FileWait {
  final int size;
  final WaitState state;
  // its kind says what its line is: on wi-fi, or a tap
  final AutoGet rule;
  // 0..1 of it in, while it comes
  final double share;
  const FileWait({
    required this.size,
    required this.state,
    required this.rule,
    this.share = 0,
  });

  FileWait copyWith({WaitState? state, double? share}) => FileWait(
    size: size,
    state: state ?? this.state,
    rule: rule,
    share: share ?? this.share,
  );
}

/// msgUid -> the file still to come under it. the bubbles draw these in
/// place of the file
final ValueNotifier<Map<String, FileWait>> fileWaits = ValueNotifier(const {});

final Map<String, TransferPace> _waitPace = {};

// the waiting files whose fetch runs now, and when a byte of each last
// came. only these move: a wait left coming by a fetch that stopped,
// backs off or never started holds nothing
final Map<String, int> _waitMoving = {};

/// a wait with no byte for this long has stalled and moves nothing
const kWaitStall = Duration(seconds: 75);

void setFileWait(String uid, FileWait? w) {
  final now = {...fileWaits.value};
  if (w == null) {
    if (now.remove(uid) == null) return;
    _waitPace.remove(uid);
    _waitMoving.remove(uid);
  } else {
    now[uid] = w;
  }
  fileWaits.value = now;
}

/// [uid]'s fetch starts or ends
void fileWaitFetching(String uid, bool on) {
  if (on) {
    _waitMoving[uid] = DateTime.now().millisecondsSinceEpoch;
  } else if (_waitMoving.remove(uid) == null) {
    return;
  }
  // the note hears it
  fileWaits.value = {...fileWaits.value};
}

/// [uid]'s fetch runs and a byte came within [kWaitStall]
bool fileWaitMoves(String uid, [int? atMs]) {
  final t = _waitMoving[uid];
  if (t == null) return false;
  final now = atMs ?? DateTime.now().millisecondsSinceEpoch;
  return now - t < kWaitStall.inMilliseconds;
}

/// the waits of [among] whose rows are gone leave: the registry was read
/// again from the databases. one set since the read began stays
void keepOnlyWaits(Set<String> uids, Set<String> among) {
  final gone = [
    for (final u in fileWaits.value.keys)
      if (among.contains(u) && !uids.contains(u)) u,
  ];
  if (gone.isEmpty) return;
  final now = {...fileWaits.value};
  for (final u in gone) {
    now.remove(u);
    _waitPace.remove(u);
    _waitMoving.remove(u);
  }
  fileWaits.value = now;
}

/// a waiting file coming in: its bubble's ring follows it
void fileWaitShare(String uid, double share) {
  final w = fileWaits.value[uid];
  if (w == null) return;
  final at = DateTime.now().millisecondsSinceEpoch;
  (_waitPace[uid] ??= TransferPace()).add(at, share);
  if (share > w.share && _waitMoving.containsKey(uid)) _waitMoving[uid] = at;
  if (w.state == WaitState.coming && w.share == share) return;
  setFileWait(uid, w.copyWith(state: WaitState.coming, share: share));
}

/// seconds left for a waiting file on its way, null while unknown
int? fileWaitLeft(String uid) => _waitPace[uid]?.secondsLeft();

FileWait? fileWaitOf(String? uid) => uid == null ? null : fileWaits.value[uid];
