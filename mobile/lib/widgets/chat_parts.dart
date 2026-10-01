// SPDX-License-Identifier: GPL-3.0-or-later
// the pieces the 1:1 chat and the group chat draw the same way: a bubble's
// way in, the day and unread markers, the jump to the newest, a reaction
// and the sent tick. one place, so the two chats cannot drift apart.
import 'package:flutter/material.dart';

import '../theme.dart';
import 'count_badge.dart';
import 'motion.dart';
import 'press_scale.dart';

// a new bubble's way in. ours rises from the composer on the end side with
// an amber glow; theirs slides in from the start side. mirrored in a
// right-to-left language, a plain fade when the phone asks for no movement.
// the same widgets stand around the bubble before, during and after, so its
// player or its image keeps its state when the entrance ends.
class BubbleEntrance extends StatefulWidget {
  final bool isOut;
  // only read when the row is first built: a rebuild never starts it again
  final bool active;
  // the amber glow of ours going out, around what [child] covers
  final bool glow;
  final Widget child;
  const BubbleEntrance({
    super.key,
    required this.isOut,
    required this.active,
    required this.child,
    this.glow = true,
  });

  @override
  State<BubbleEntrance> createState() => _BubbleEntranceState();
}

class _BubbleEntranceState extends State<BubbleEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (!widget.active) return;
    _c = AnimationController(vsync: this, duration: kHouseTime)..forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final way = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    final out = widget.isOut;
    return AnimatedBuilder(
      animation: _c ?? kAlwaysCompleteAnimation,
      child: widget.child,
      builder: (_, child) {
        final t = _c?.value ?? 1;
        final m = still ? 1.0 : kHouseCurve.transform(t);
        final fade = Curves.easeOut.transform(
          (t / (still ? 0.55 : 0.6)).clamp(0.0, 1.0),
        );
        final left = 1 - m;
        final glow = still || !out || !widget.glow || t >= 1 ? 0.0 : 1 - t;
        return Opacity(
          opacity: fade,
          child: Transform(
            alignment: out
                ? AlignmentDirectional.bottomEnd
                : AlignmentDirectional.centerStart,
            transform:
                Matrix4.translationValues(
                  (out ? 14 : -14) * way * left,
                  (out ? 30 : 6) * left,
                  0,
                )..scaleByDouble(
                  1 - (out ? 0.18 : 0.04) * left,
                  1 - (out ? 0.18 : 0.04) * left,
                  1,
                  1,
                ),
            child: DecoratedBox(
              decoration: glow == 0
                  ? const BoxDecoration()
                  : BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: HaloColors.amber.withValues(
                            alpha: 0.45 * glow,
                          ),
                          blurRadius: 18 * glow + 2,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

// a day in the thread: the same pill inline as the one that floats at the
// top while scrolling, so the floating one reads as the inline one held
class DayChip extends StatelessWidget {
  final String label;
  const DayChip(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: HaloColors.surface2.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HaloColors.line, width: 0.5),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: HaloType.mono(
          size: 10,
          color: HaloColors.text2,
          weight: FontWeight.w500,
          letter: 0.06,
        ),
      ),
    );
  }
}

// where the unread part of a chat begins
class UnreadDivider extends StatelessWidget {
  final String label;
  const UnreadDivider(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    Widget line(bool towardsStart) => Expanded(
      child: Container(
        height: 0.5,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: towardsStart
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            end: towardsStart
                ? AlignmentDirectional.centerStart
                : AlignmentDirectional.centerEnd,
            colors: [
              HaloColors.amber.withValues(alpha: 0.5),
              HaloColors.amber.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          line(true),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: HaloColors.amberSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: HaloColors.amber.withValues(alpha: 0.45),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 11,
                  color: HaloColors.amber,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  maxLines: 1,
                  style: HaloType.mono(
                    size: 10,
                    color: HaloColors.amber,
                    weight: FontWeight.w500,
                    letter: 0.06,
                  ),
                ),
              ],
            ),
          ),
          line(false),
        ],
      ),
    );
  }
}

// the round button that takes a scrolled-up chat back to its newest
// message, with how many arrived since. pops in on the house spring
class JumpDownButton extends StatelessWidget {
  final bool shown;
  final int count;
  final String label;
  final VoidCallback onTap;
  const JumpDownButton({
    super.key,
    required this.shown,
    required this.count,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return IgnorePointer(
      ignoring: !shown,
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: Duration(milliseconds: shown ? 180 : 140),
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: shown || still ? 1 : 0.6,
          duration: still
              ? Duration.zero
              : shown
              ? kHouseTime
              : const Duration(milliseconds: 160),
          curve: shown ? kHouseCurve : Curves.easeInCubic,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              PressScale(
                label: label,
                scale: 0.9,
                onTap: onTap,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HaloColors.surface2,
                    border: Border.all(
                      color: HaloColors.amber.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: HaloColors.amber.withValues(alpha: 0.14),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: HaloColors.amber,
                    size: 24,
                  ),
                ),
              ),
              PositionedDirectional(
                top: -5,
                end: -5,
                child: IgnorePointer(
                  child: CountBadge(
                    count: count,
                    fontSize: 9,
                    minWidth: 18,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    ring: HaloColors.surface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// one emoji under a bubble, with how many picked it. it springs on when it
// is new and its count rolls when that changes; only once per reaction, so a
// reload does not spring every chip in the chat again
class ReactionChip extends StatefulWidget {
  final String emoji;
  final int count;
  // this phone picked it: its count reads amber
  final bool mine;
  // the reaction's own id, so a chip that already played stays still
  final String popKey;
  // a tap puts the same emoji on from this phone, or takes it off
  final VoidCallback? onTap;
  const ReactionChip({
    super.key,
    required this.emoji,
    required this.count,
    required this.popKey,
    this.mine = false,
    this.onTap,
  });

  static final Set<String> _popped = {};

  @override
  State<ReactionChip> createState() => _ReactionChipState();
}

class _ReactionChipState extends State<ReactionChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  @override
  void initState() {
    super.initState();
    final seen = ReactionChip._popped;
    if (seen.contains(widget.popKey)) {
      _c.value = 1;
      return;
    }
    seen.add(widget.popKey);
    // insertion ordered: the oldest goes first, so this never grows unbounded
    if (seen.length > 600) seen.remove(seen.first);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static final _pop = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.18,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 62,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.18,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 38,
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        // the colour under the chat, so it reads as a tab cut below the
        // bubble rather than a smudge on top of it
        color: HaloColors.ink,
        borderRadius: BorderRadius.circular(11),
        border: widget.mine
            ? Border.all(
                color: HaloColors.amber.withValues(alpha: 0.45),
                width: 0.5,
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.emoji, style: const TextStyle(fontSize: 13, height: 1.2)),
          if (widget.count > 1) ...[
            const SizedBox(width: 3),
            CountRoll(
              count: widget.count,
              style: HaloType.mono(
                size: 10,
                color: widget.mine ? HaloColors.amber : HaloColors.text2,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
    final shown = FadeTransition(
      opacity: CurvedAnimation(
        parent: _c,
        curve: const Interval(0, 0.5, curve: Curves.easeOut),
      ),
      child: still
          ? chip
          : ScaleTransition(scale: _pop.animate(_c), child: chip),
    );
    final tap = widget.onTap;
    if (tap == null) return shown;
    return PressScale(scale: 0.9, onTap: tap, child: shown);
  }
}

// a number that rolls to its next value instead of swapping: up when it
// grows, down when it shrinks. a plain fade under reduced motion
class CountRoll extends StatefulWidget {
  final int count;
  final TextStyle style;
  const CountRoll({super.key, required this.count, required this.style});

  @override
  State<CountRoll> createState() => _CountRollState();
}

class _CountRollState extends State<CountRoll> {
  bool _up = true;

  @override
  void didUpdateWidget(CountRoll old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count) _up = widget.count > old.count;
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final text = '${widget.count}';
    return AnimatedSwitcher(
      duration: Duration(milliseconds: still ? 120 : 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, a) {
        if (still) return FadeTransition(opacity: a, child: child);
        final incoming = child.key == ValueKey(text);
        return ClipRect(
          child: SlideTransition(
            position: Tween(
              begin: Offset(0, (incoming == _up) ? 0.9 : -0.9),
              end: Offset.zero,
            ).animate(a),
            child: FadeTransition(opacity: a, child: child),
          ),
        );
      },
      child: Text(text, key: ValueKey(text), style: widget.style),
    );
  }
}

// the sent tick, and the word delivered once a receipt lands. the word
// grows out of the tick, which gives one small nod, when the receipt comes
// while the chat is open; a bubble built with it already there draws still
class SentTick extends StatefulWidget {
  final bool delivered;
  final String deliveredLabel;
  final Color color;
  final TextStyle labelStyle;
  const SentTick({
    super.key,
    required this.delivered,
    required this.deliveredLabel,
    required this.color,
    required this.labelStyle,
  });

  @override
  State<SentTick> createState() => _SentTickState();
}

class _SentTickState extends State<SentTick>
    with SingleTickerProviderStateMixin {
  late final AnimationController _nod = AnimationController(
    vsync: this,
    duration: kHouseTime,
    value: 1,
  );

  @override
  void didUpdateWidget(SentTick old) {
    super.didUpdateWidget(old);
    if (widget.delivered && !old.delivered && !motionStill(context)) {
      _nod.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _nod.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final label = AnimatedSwitcher(
      duration: Duration(milliseconds: still ? 120 : 220),
      switchInCurve: Curves.easeOut,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: still
            ? child
            : SlideTransition(
                position: Tween(
                  begin: Offset(rtl ? 0.25 : -0.25, 0),
                  end: Offset.zero,
                ).animate(a),
                child: child,
              ),
      ),
      child: widget.delivered
          ? Padding(
              key: const ValueKey('delivered'),
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Text(
                widget.deliveredLabel,
                maxLines: 1,
                style: widget.labelStyle,
              ),
            )
          : const SizedBox.shrink(key: ValueKey('sent')),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _nod,
          builder: (_, child) => Transform.scale(
            scale: 1.35 - 0.35 * kHouseCurve.transform(_nod.value),
            child: child,
          ),
          child: Text(
            '✓',
            style: TextStyle(
              fontSize: 11,
              color: widget.color,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
        // an AnimatedSize given no time trips over its own layout: still, it
        // is left out
        if (still)
          label
        else
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: AlignmentDirectional.centerStart,
            child: label,
          ),
      ],
    );
  }
}

// swaps what sits under or inside a bubble (the sending pill, the time and
// tick) by growing the new one in as the old one folds, so the thread does
// not jump when a message goes out. instant when the phone asks for no
// movement. [child] is keyed by what it shows
class GrowSwap extends StatelessWidget {
  final Widget child;
  final AlignmentGeometry alignment;
  const GrowSwap({
    super.key,
    required this.child,
    this.alignment = AlignmentDirectional.centerEnd,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: motionStill(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) =>
          Stack(alignment: alignment, children: [...previous, ?current]),
      transitionBuilder: (child, a) => SizeTransition(
        sizeFactor: a,
        axisAlignment: -1,
        child: FadeTransition(opacity: a, child: child),
      ),
      child: child,
    );
  }
}

// swaps what sits in a corner over a picture or a sticker (its time and
// tick, a failed or waiting mark): the new one fades and grows in from the
// corner as the old one fades out, a fade alone when the phone asks for no
// movement. [child] is keyed by what it shows
class CornerSwap extends StatelessWidget {
  final Widget child;
  const CornerSwap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return AnimatedSwitcher(
      duration: Duration(milliseconds: still ? 150 : 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (top, gone) => Stack(
        alignment: AlignmentDirectional.bottomEnd,
        children: [...gone, ?top],
      ),
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: still
            ? c
            : ScaleTransition(
                scale: Tween(begin: 0.85, end: 1.0).animate(a),
                alignment: AlignmentDirectional.bottomEnd.resolve(
                  Directionality.of(context),
                ),
                child: c,
              ),
      ),
      child: child,
    );
  }
}

// a message's words with each hit of an in-chat search marked like a
// highlighter: amber on its own tint in their bubble, amber on ink in ours,
// where amber text alone would vanish. the same in both chats
List<TextSpan> searchLit(String text, String query, {required bool onAmber}) {
  final q = query.toLowerCase();
  if (q.isEmpty) return [TextSpan(text: text)];
  final lower = text.toLowerCase();
  final lit = TextStyle(
    color: HaloColors.amber,
    backgroundColor: onAmber
        ? HaloColors.onAmber
        : HaloColors.amber.withValues(alpha: 0.22),
    fontWeight: FontWeight.w600,
  );
  final spans = <TextSpan>[];
  var start = 0;
  while (true) {
    final hit = lower.indexOf(q, start);
    // a hit that lowercasing moved off the text's own length is left plain
    if (hit < 0 || hit + q.length > text.length) {
      spans.add(TextSpan(text: text.substring(start)));
      break;
    }
    if (hit > start) spans.add(TextSpan(text: text.substring(start, hit)));
    spans.add(TextSpan(text: text.substring(hit, hit + q.length), style: lit));
    start = hit + q.length;
  }
  return spans;
}

// the ring and glow around the bubble that holds the current hit of an
// in-chat search
BoxBorder? searchRing(bool current) =>
    current ? Border.all(color: HaloColors.amber, width: 1) : null;

List<BoxShadow>? searchGlow(bool current) => current
    ? [
        BoxShadow(
          color: HaloColors.amber.withValues(alpha: 0.28),
          blurRadius: 22,
          spreadRadius: -4,
          offset: const Offset(0, 6),
        ),
      ]
    : null;
