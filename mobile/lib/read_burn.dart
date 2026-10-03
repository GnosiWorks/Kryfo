// SPDX-License-Identifier: GPL-3.0-or-later
// a timed message that came in starts its clock when it is first read: the
// chat in view with the app in front, no lock, decoy, sheet or page over it,
// and its bubble on screen, or the person acting on it. a row the list built
// just past the edge is not read.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dlog.dart';
import 'l10n/l10n.dart';
import 'l10n/numbers.dart';
import 'seen_timers.dart';
import 'widgets/row_anchor.dart';

/// the longest a timed message that came in waits to be read: a day after
/// it came its clock starts, read or not
const kBurnWaitMost = Duration(hours: 24);

/// when the clock of a timed message that came at [arrived] starts at the
/// latest. an arrival ahead of this phone's clock counts as now
int burnStartBy(int arrived, int now) =>
    math.min(arrived, now) + kBurnWaitMost.inMilliseconds;

/// how far ahead of this phone's clock an arrival may be and still wait as
/// one stamped now: a row filed while a sweep runs is a few ms past its
/// now. one further ahead came under a clock set back since
const kBurnSkew = Duration(minutes: 1);

/// the wait to the next burn tick, as burnWait gives it, or sooner when a
/// row still waiting starts counting first. [starts] are their start times
/// (burnStartBy). one due already and not lit yet gets the next whole
/// second, as a countdown does: a wait of nothing would wake the screen
/// over and over
Duration? burnWaitStarts(
  int now, {
  required bool ghosts,
  int? soonest,
  required Iterable<int> starts,
}) {
  int? next;
  var due = false;
  for (final s in starts) {
    if (s <= now) {
      due = true;
    } else if (next == null || s < next) {
      next = s;
    }
  }
  final wait = burnWait(now, ghosts: ghosts || due, soonest: soonest);
  if (next == null) return wait;
  final start = Duration(milliseconds: next - now);
  return wait == null || start < wait ? start : wait;
}

/// a row that came in timed and has not been read: its clock waits, or ran
/// unread from [kBurnWaitMost] on (burn_unseen). shown only in its own chat,
/// where reading it starts the clock, never in a gallery, a media strip,
/// the pins sheet, search, saved messages, the chat list line or a quote
bool burnWaitsRow(Map<String, Object?> r) =>
    r['direction'] == 'in' &&
    r['burn_secs'] != null &&
    (r['burn_at'] == null || r['burn_unseen'] == 1);

/// [burnWaitsRow] as sql, for a query that leaves those rows out before its
/// limit. [m] names the messages table
String burnWaitsSql([String m = 'messages']) =>
    "($m.direction = 'in' AND $m.burn_secs IS NOT NULL "
    'AND ($m.burn_at IS NULL OR $m.burn_unseen = 1))';

/// what is left on a timed message's clock, as both chats show it: a fresh
/// 5 minute clock reads 5m 00s, 61 seconds 1m 01s
String burnLeft(int ms) {
  var s = (ms / 1000).round();
  if (s <= 0) return l10n.chat0s;
  final h = s ~/ 3600;
  s -= h * 3600;
  final m = s ~/ 60;
  s -= m * 60;
  if (h > 0) return l10n.chatHM(whole(h), twoDigits(m));
  if (m > 0) return l10n.chatMS(whole(m), twoDigits(s));
  return l10n.chatS2(whole(s));
}

/// [ro] shows inside its scroll view: half of it, or half the view for a
/// row taller than that
bool rowInView(RenderObject ro) {
  final viewport = RenderAbstractViewport.maybeOf(ro);
  if (ro is! RenderBox || viewport is! RenderBox) return false;
  final row = ro;
  final view = viewport as RenderBox;
  if (!row.attached || !row.hasSize || !view.hasSize) return false;
  final box = MatrixUtils.transformRect(
    row.getTransformTo(view),
    Offset.zero & row.size,
  );
  final shown = box.intersect(Offset.zero & view.size);
  if (shown.width <= 0 || shown.height <= 0) return false;
  return shown.height >= math.min(box.height, view.size.height) / 2;
}

class ReadBurns {
  ReadBurns({
    required this.anchors,
    required this.allowed,
    required this.reading,
    required this.waiting,
    required this.light,
    int Function()? clock,
  }) : _clock = clock ?? _wall;

  static int _wall() => DateTime.now().millisecondsSinceEpoch;

  /// how often a chat with rows waiting looks again
  static const beat = Duration(milliseconds: 500);

  /// after a failed write it waits this long, doubling to [restMost]
  static const restLeast = Duration(seconds: 2);
  static const restMost = Duration(minutes: 1);

  final RowAnchors anchors;
  // a clock may start at all: no lock and no decoy over the chat
  final bool Function() allowed;
  // the chat can be read: in view, the app in front, nothing over it
  final bool Function() reading;
  // the ids of the rows whose clock waits
  final Iterable<String> Function() waiting;
  // the rows read just now; their clocks are written before this completes.
  // gives the clock of each row lit, older ones it lit along with them too
  final Future<Map<String, int>> Function(List<String> ids) light;
  final int Function() _clock;

  final Set<String> _going = {};
  // asked once and nothing came back: gone from the database, the screen
  // drops it on its next load
  final Set<String> _spent = {};
  SeenJob? _beat;
  bool _asked = false;
  bool _gone = false;
  int _fails = 0;
  int _restUntil = 0;

  Iterable<String> get _open =>
      waiting().where((id) => !_going.contains(id) && !_spent.contains(id));

  /// looks again every [beat] while a row waits, so a row that comes into
  /// view with no scroll or rebuild, a photo sizing in say, is still read.
  /// back in view, it looks at once
  void keepTime(SeenTimers timers) {
    _beat = timers.until(_nextBeat, (back) => back ? look() : check());
  }

  Duration? _nextBeat() {
    if (_gone || _open.isEmpty) return null;
    final rest = _restUntil - _clock();
    return rest > beat.inMilliseconds ? Duration(milliseconds: rest) : beat;
  }

  /// looks once this frame is laid out. cheap to call often
  void look() {
    if (_asked || _gone || _clock() < _restUntil || _open.isEmpty) return;
    _beat?.poke();
    _asked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _asked = false;
      check();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// the waiting rows on screen now start their clocks
  void check() {
    if (_gone || _clock() < _restUntil || !reading()) return;
    _go([
      for (final id in _open)
        if (_shown(id)) id,
    ]);
  }

  /// the person acted on row [id]: opened it, played it, held it or swiped
  /// to answer it. that is reading it, however little of it shows
  void touched(String? id) {
    if (id == null || _gone || !allowed()) return;
    if (!_open.contains(id)) return;
    _go([id]);
  }

  void _go(List<String> due) {
    if (due.isEmpty) return;
    _going.addAll(due);
    unawaited(
      light(due)
          .then((lit) {
            _fails = 0;
            _restUntil = 0;
            _spent.addAll(due.where((id) => !lit.containsKey(id)));
          })
          .catchError((Object e) {
            // a database that will not write is not asked twice a second
            final rest = math.min(
              restLeast.inMilliseconds << math.min(_fails, 5),
              restMost.inMilliseconds,
            );
            _fails++;
            _restUntil = _clock() + rest;
            dlog('read burn: not lit, again in ${rest ~/ 1000}s ($e)');
          })
          .whenComplete(() {
            _going.removeAll(due);
            // the beat stood down while they were out
            if (!_gone) _beat?.poke();
          }),
    );
  }

  bool _shown(String id) {
    final c = anchors.of(id);
    if (c == null || !c.mounted) return false;
    final ro = c.findRenderObject();
    return ro != null && rowInView(ro);
  }

  void dispose() => _gone = true;
}
