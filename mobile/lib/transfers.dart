// SPDX-License-Identifier: GPL-3.0-or-later
// what a file on its way does and when: how fast it moves and how long it
// has left, which files come on their own (automatic download), and the
// files filed before their bytes, which wait for a tap or for wi-fi
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'container.dart';
import 'desktop/desktop_mode.dart' show onDesktop;
import 'voice_format.dart' show isVoiceName;
import 'l10n/l10n.dart';
import 'l10n/numbers.dart';
import 'open_file.dart' show nameSaysVideo;
import 'widgets/media_bubbles.dart' show humanFileSize;
import 'zip_glance.dart' show ZipGlance;

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
  // the time left last said: a stall holds it and a small rise leaves it,
  // so the words neither come and go nor step across a minute and back
  int? _said;

  /// [share] of it done at [atMs]. a share that went back (a resend from
  /// the start) starts the pace over
  void add(int atMs, double share) {
    if (_seen.isNotEmpty && share < _seen.last.$2) {
      _seen.clear();
      _said = null;
    }
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
    final now = _guess();
    final said = _said;
    if (now == null) return said;
    if (said != null && now > said && now <= said * 1.25 + 5) return said;
    return _said = now;
  }

  int? _guess() {
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

/// a file's kind as the frame's message tells it. null for a voice note.
/// a video counts as one only under the name the gallery and the camera
/// give it (madeVideoName): one sent as a file, or among files sent
/// together ([inSet]), is a file, and a file never comes on its own
GetKind? getKindOf(String? fileName, {bool inSet = false}) {
  if (fileName == null) return GetKind.photo;
  if (isVoiceName(fileName)) return null;
  if (!inSet && nameSaysVideo(fileName) && _madeVideo.hasMatch(fileName)) {
    return GetKind.video;
  }
  return GetKind.file;
}

final _madeVideo = RegExp(r'^video_[0-9a-f]{8}\.[A-Za-z0-9]{2,5}$');

/// photos come on any network, videos on wi-fi, and a file never comes on
/// its own: it always waits for a tap, whatever was set before
const kAutoGetDefaults = {
  GetKind.photo: AutoGet.always,
  GetKind.video: AutoGet.wifi,
  GetKind.file: AutoGet.never,
};

/// the kinds a person may set: a file is not one of them
const kAutoGetChoices = [GetKind.photo, GetKind.video];

const kAutoGetKeys = {
  GetKind.photo: 'kryfo.get.photo',
  GetKind.video: 'kryfo.get.video',
  GetKind.file: 'kryfo.get.file',
};

AutoGet _autoGetOf(String? s, GetKind k) => k == GetKind.file
    ? AutoGet.never
    : AutoGet.values.where((v) => v.name == s).firstOrNull ??
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
  // a file waits for a tap, always
  if (kind == GetKind.file) return false;
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
    return unmeteredIn(await Connectivity().checkConnectivity());
  } catch (_) {
    return false;
  }
}

/// [r] is wi-fi or a cable. a computer's full tunnel vpn reads as vpn alone,
/// and the line under it is wi-fi or a cable all but always: a computer
/// counts a vpn or a link it cannot name too. a mobile modem stays metered
bool unmeteredIn(List<ConnectivityResult> r) {
  if (r.contains(ConnectivityResult.wifi) ||
      r.contains(ConnectivityResult.ethernet)) {
    return true;
  }
  if (!onDesktop || r.contains(ConnectivityResult.mobile)) return false;
  return r.contains(ConnectivityResult.vpn) ||
      r.contains(ConnectivityResult.other);
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
  // a zip's contents as its sender read them, shown before it comes
  final ZipGlance? glance;
  const FileWait({
    required this.size,
    required this.state,
    required this.rule,
    this.share = 0,
    this.glance,
  });

  FileWait copyWith({WaitState? state, double? share}) => FileWait(
    size: size,
    state: state ?? this.state,
    rule: rule,
    share: share ?? this.share,
    glance: glance,
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
