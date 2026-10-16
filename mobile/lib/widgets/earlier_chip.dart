// SPDX-License-Identifier: GPL-3.0-or-later
// a message that came in written well before the bottom of the chat goes
// up the thread, where nobody reading the bottom sees it. a plain line above
// the composer says how many did, and a tap takes the reader to the first
// of them. it goes once each has been on screen
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../read_burn.dart' show rowInView;
import '../theme.dart';
import 'motion.dart';
import 'press_scale.dart';
import 'row_anchor.dart';

/// how far before the bottom of the chat one has to land to be shown
const kEarlierMargin = Duration(minutes: 2);

/// one written at [written] went up the thread from a bottom at [bottom]
bool cameEarlier(int written, int bottom) =>
    written < bottom - kEarlierMargin.inMilliseconds;

/// the rows that came up the thread and were not on screen yet, by their
/// row ids, oldest arrival first
class EarlierArrivals {
  final List<String> _ids = [];

  int get count => _ids.length;
  List<String> get ids => List.unmodifiable(_ids);
  String? get first => _ids.firstOrNull;

  // false when it was held already
  bool add(String id) {
    if (_ids.contains(id)) return false;
    _ids.add(id);
    return true;
  }

  // false when it was not held
  bool drop(String id) => _ids.remove(id);

  void clear() => _ids.clear();

  /// lets go of each one on screen now. true when any went
  bool seenIn(RowAnchors anchors) {
    final before = _ids.length;
    _ids.removeWhere((id) {
      final ctx = anchors.of(id);
      final ro = ctx == null || !ctx.mounted ? null : ctx.findRenderObject();
      return ro is RenderBox && ro.attached && rowInView(ro);
    });
    return _ids.length != before;
  }
}

/// the room the line takes over the thread's own bottom padding, so the
/// newest bubble's time and ticks rest above it rather than under it
double earlierRoom(BuildContext context) {
  final words = MediaQuery.textScalerOf(context).scale(_wordsSize) * 1.2;
  // the line's padding and hairline, then a gap
  return math.max(words, _iconSize) + 2 * _padV + 1 + 8;
}

/// the thread's extra bottom padding while the line shows, eased in and out
/// with it. a reader at the newest rides up with the bubbles; one further
/// up the thread stays on the rows they were reading
class EarlierRoom extends StatefulWidget {
  final bool shown;
  final ScrollController controller;
  // the newest at offset zero, as in a 1:1 chat
  final bool reversed;
  final Widget Function(BuildContext context, double room) builder;
  const EarlierRoom({
    super.key,
    required this.shown,
    required this.controller,
    required this.reversed,
    required this.builder,
  });

  @override
  State<EarlierRoom> createState() => _EarlierRoomState();
}

class _EarlierRoomState extends State<EarlierRoom>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t;
  double _from = 0;
  double _to = 0;
  double _room = 0;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this, duration: kHouseTime)
      ..addListener(_step);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _aim();
  }

  @override
  void didUpdateWidget(EarlierRoom old) {
    super.didUpdateWidget(old);
    _aim();
  }

  void _aim() {
    final to = widget.shown ? earlierRoom(context) : 0.0;
    if (to == _to) return;
    _from = _room;
    _to = to;
    if (motionStill(context)) {
      _t.stop();
      // a frame on: rows held in view through a reload in this frame
      // would take the jump as theirs and hold the newest under the line
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _to == to) setState(() => _move(to));
      });
    } else {
      _t.forward(from: 0);
    }
  }

  void _step() {
    final v = _from + (_to - _from) * kHouseCurve.transform(_t.value);
    if (v == _room) return;
    setState(() => _move(v));
  }

  // before the frame's layout, so the place kept is never a frame late
  void _move(double v) {
    final d = v - _room;
    _room = v;
    final c = widget.controller;
    if (c.positions.length != 1) return;
    final p = c.positions.first;
    if (!p.hasPixels || !p.hasContentDimensions) return;
    final newest = widget.reversed
        ? p.pixels <= p.minScrollExtent + 1
        : p.maxScrollExtent - p.pixels <= 1;
    // the padding sits at the newest end: a reversed list carries everyone
    // with it, a plain one leaves the reader at the newest behind
    if (widget.reversed == newest) return;
    if (!widget.reversed && p.maxScrollExtent <= p.minScrollExtent) {
      // a thread shorter than the screen may only now overflow
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || c.positions.length != 1) return;
        final q = c.positions.first;
        if (q.hasContentDimensions && q.pixels < q.maxScrollExtent) {
          q.jumpTo(q.maxScrollExtent);
        }
      });
      return;
    }
    p.correctBy(math.max(d, p.minScrollExtent - p.pixels));
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _room);
}

const _wordsSize = 12.5;
const _iconSize = 13.0;
const _padV = 7.0;

/// the line itself, at the bottom of the thread. [lifted] while the jump
/// button sits there too, so the two never overlap
class EarlierChip extends StatefulWidget {
  final int count;
  final bool lifted;
  final VoidCallback onTap;
  const EarlierChip({
    super.key,
    required this.count,
    required this.lifted,
    required this.onTap,
  });

  @override
  State<EarlierChip> createState() => _EarlierChipState();
}

class _EarlierChipState extends State<EarlierChip> {
  // the last count shown, kept while the line leaves
  int _shownCount = 0;

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final shown = widget.count > 0;
    if (shown) _shownCount = widget.count;
    final words = l10n.chatEarlierMessagesArrived(_shownCount);
    return AnimatedPadding(
      duration: still ? Duration.zero : kHouseTime,
      curve: kHouseCurve,
      padding: EdgeInsets.only(bottom: widget.lifted ? 60 : 12),
      child: IgnorePointer(
        ignoring: !shown,
        child: AnimatedOpacity(
          opacity: shown ? 1 : 0,
          duration: Duration(milliseconds: shown ? 200 : 140),
          curve: Curves.easeOut,
          child: AnimatedSlide(
            offset: shown || still ? Offset.zero : const Offset(0, 0.4),
            duration: still
                ? Duration.zero
                : shown
                ? kHouseTime
                : const Duration(milliseconds: 160),
            curve: shown ? kHouseCurve : Curves.easeInCubic,
            child: _shownCount == 0
                ? const SizedBox.shrink()
                : PressScale(
                    key: const ValueKey('earlier-chip'),
                    label: words,
                    scale: 0.94,
                    onTap: widget.onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: _padV,
                      ),
                      decoration: BoxDecoration(
                        color: HaloColors.surface2,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: HaloColors.amber.withValues(alpha: 0.45),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_upward_rounded,
                            size: _iconSize,
                            color: HaloColors.amber,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              words,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HaloType.sans(
                                size: _wordsSize,
                                color: HaloColors.text,
                                weight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
