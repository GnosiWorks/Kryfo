// SPDX-License-Identifier: GPL-3.0-or-later
// a poll in a group chat. before a vote: the answers to pick from. after it,
// or once closed: a bar per answer that glides to its share as votes come
// in, and who voted what one tap away. the votes are counted here, on this
// phone, from what the members sent.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../polls.dart';
import '../theme.dart';
import 'confirm_sheet.dart';
import 'halo_bar.dart';
import 'halo_sheet.dart';
import 'kryfo_avatar.dart';
import 'press_scale.dart';
import 'sheet_handle.dart';
import 'stroke_icon.dart';

const pollGlyph = ['M6 19v-6', 'M12 19V5', 'M18 19v-9'];

class PollCard extends StatefulWidget {
  final String question;
  final PollSpec poll;
  final Map<String, PollVote> votes;

  /// who this phone is in the chat (the room key, in a room)
  final String me;

  /// this phone made the poll: it can close it
  final bool mine;
  final bool isOut;

  /// the time and, on ours, the tick; the burn clock on a timed chat
  final Widget? stamp;
  final Widget? burn;
  final ValueChanged<List<int>> onVote;
  final VoidCallback? onClose;
  final String Function(String id) nameOf;

  const PollCard({
    super.key,
    required this.question,
    required this.poll,
    required this.votes,
    required this.me,
    required this.mine,
    required this.isOut,
    required this.onVote,
    required this.nameOf,
    this.onClose,
    this.stamp,
    this.burn,
  });

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  // what this phone picked, shown before the reload brings it back as a vote
  List<int>? _sent;
  // picks on a several-answers poll before its vote button
  final Set<int> _draft = {};

  PollTally get _tally => tallyPoll(widget.poll, widget.votes, widget.me);

  @override
  void didUpdateWidget(PollCard old) {
    super.didUpdateWidget(old);
    final held = _tally.mine;
    if (_sent != null && _same(held, _sent!)) _sent = null;
    if (widget.poll.closed) _sent = null;
  }

  bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _vote(List<int> picks) {
    final clean = cleanChoices(picks, widget.poll);
    setState(() {
      _sent = clean;
      _draft.clear();
    });
    widget.onVote(clean);
  }

  void _tap(int i, List<int> mine, bool results) {
    if (widget.poll.closed) {
      _showVoters();
      return;
    }
    if (!widget.poll.multi) {
      if (mine.length == 1 && mine.first == i) {
        HapticFeedback.lightImpact();
        return;
      }
      HapticFeedback.selectionClick();
      _vote([i]);
      return;
    }
    if (results) {
      // several answers, already voted: a tap adds or takes away that one
      HapticFeedback.selectionClick();
      final next = {...mine};
      if (!next.remove(i)) next.add(i);
      _vote(next.toList());
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      if (!_draft.remove(i)) _draft.add(i);
    });
  }

  Future<void> _close() async {
    final yes = await showConfirmSheet(
      context,
      title: l10n.pollCloseTitle,
      line: l10n.pollCloseLine,
      yes: l10n.pollCloseYes,
      rose: false,
    );
    if (!yes) return;
    HapticFeedback.mediumImpact();
    widget.onClose?.call();
  }

  void _showVoters() {
    final t = _tally;
    showHaloSheet<void>(
      context,
      builder: (ctx) => _VotersSheet(
        question: widget.question,
        poll: widget.poll,
        tally: t,
        me: widget.me,
        nameOf: widget.nameOf,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _tally;
    final mine = _sent ?? t.mine;
    final closed = widget.poll.closed;
    // the creator sees the count once there is one; with none yet it can
    // vote like everyone else
    final results = closed || mine.isNotEmpty || (widget.mine && t.voters > 0);
    final still = MediaQuery.of(context).disableAnimations;
    final w = MediaQuery.of(context).size.width;
    final width = (w * 0.78).clamp(220.0, 320.0);
    final isOut = widget.isOut;
    final bg = isOut
        ? Color.alphaBlend(
            HaloColors.amber.withValues(alpha: 0.10),
            HaloColors.surface2,
          )
        : HaloColors.surface2;
    final leaders = closed ? t.leaders : const <int>{};
    final kind = closed
        ? l10n.pollKindClosed
        : widget.poll.multi
        ? l10n.pollKindMulti
        : l10n.pollKind;
    // shares from the votes this phone holds, plus its own pick on the way
    final counts = [...t.counts];
    var voters = t.voters;
    if (_sent != null) {
      final before = t.mine;
      for (final c in before) {
        counts[c]--;
      }
      for (final c in _sent!) {
        counts[c]++;
      }
      if (before.isEmpty && _sent!.isNotEmpty) voters++;
      if (before.isNotEmpty && _sent!.isEmpty) voters--;
    }
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadiusDirectional.only(
          topStart: const Radius.circular(16),
          topEnd: const Radius.circular(16),
          bottomStart: Radius.circular(isOut ? 16 : 5),
          bottomEnd: Radius.circular(isOut ? 5 : 16),
        ),
        border: Border.all(
          color: isOut
              ? HaloColors.amber.withValues(alpha: 0.45)
              : HaloColors.line,
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              StrokeIcon(
                pollGlyph,
                size: 13,
                color: closed ? HaloColors.text : HaloColors.amber,
                stroke: 2.2,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: still ? 0 : 220),
                  child: Text(
                    kind,
                    key: ValueKey(kind),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.mono(
                      size: 10,
                      weight: FontWeight.w700,
                      color: closed ? HaloColors.text : HaloColors.amber,
                      letter: 0.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            widget.question,
            style: HaloType.serif(
              size: 17,
              color: HaloColors.text,
              height: 1.25,
            ),
          ),
          if (!results) ...[
            const SizedBox(height: 3),
            Text(
              widget.poll.multi ? l10n.pollPickSeveral : l10n.pollPickOne,
              style: HaloType.sans(size: 11.5, color: HaloColors.text2),
            ),
          ],
          const SizedBox(height: 10),
          AnimatedSize(
            duration: Duration(milliseconds: still ? 0 : 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: still ? 0 : 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
              child: Column(
                key: ValueKey(results),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < widget.poll.options.length; i++)
                    results
                        ? _ResultRow(
                            text: widget.poll.options[i],
                            share: voters == 0 ? 0 : counts[i] / voters,
                            mine: mine.contains(i),
                            leader: leaders.contains(i),
                            multi: widget.poll.multi,
                            onTap: () => _tap(i, mine, true),
                          )
                        : _PickRow(
                            text: widget.poll.options[i],
                            on: _draft.contains(i),
                            multi: widget.poll.multi,
                            onTap: () => _tap(i, mine, false),
                          ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: Duration(milliseconds: still ? 0 : 200),
            curve: Curves.easeOutCubic,
            child: !results && _draft.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: PressScale(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _vote(_draft.toList());
                      },
                      label: l10n.pollVote,
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: HaloColors.amber,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          l10n.pollVote,
                          style: HaloType.sans(
                            size: 13.5,
                            weight: FontWeight.w600,
                            color: HaloColors.onAmber,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: voters > 0 ? _showVoters : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (voters > 0) ...[
                          _Faces(ids: widget.votes.keys.take(3).toList()),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: AnimatedSwitcher(
                            duration: Duration(milliseconds: still ? 0 : 200),
                            transitionBuilder: (c, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(
                                position: Tween(
                                  begin: const Offset(0, 0.35),
                                  end: Offset.zero,
                                ).animate(a),
                                child: c,
                              ),
                            ),
                            child: Text(
                              l10n.pollVotes(voters),
                              key: ValueKey(voters),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HaloType.mono(
                                size: 10,
                                color: voters > 0
                                    ? HaloColors.amber
                                    : HaloColors.text2,
                                letter: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ?widget.burn,
              if (widget.burn != null) const SizedBox(width: 6),
              ?widget.stamp,
            ],
          ),
          if (!closed && (mine.isNotEmpty || widget.mine))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  if (mine.isNotEmpty)
                    _Link(
                      text: l10n.pollTakeBack,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _vote(const []);
                      },
                    ),
                  const Spacer(),
                  if (widget.mine && widget.onClose != null)
                    _Link(text: l10n.pollClose, onTap: _close, strong: true),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool strong;
  const _Link({required this.text, required this.onTap, this.strong = false});
  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      haptic: false,
      label: text,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          text,
          semanticsLabel: '',
          style: HaloType.sans(
            size: 12,
            weight: strong ? FontWeight.w600 : FontWeight.w400,
            color: strong ? HaloColors.amber : HaloColors.text2,
          ),
        ),
      ),
    );
  }
}

// before a vote: an answer to pick
class _PickRow extends StatelessWidget {
  final String text;
  final bool on;
  final bool multi;
  final VoidCallback onTap;
  const _PickRow({
    required this.text,
    required this.on,
    required this.multi,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Semantics(
        button: true,
        selected: on,
        inMutuallyExclusiveGroup: !multi,
        label: text,
        excludeSemantics: true,
        onTap: onTap,
        child: PressScale(
          scale: 0.98,
          haptic: false,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsetsDirectional.fromSTEB(11, 10, 12, 10),
            decoration: BoxDecoration(
              color: on
                  ? HaloColors.amber.withValues(alpha: 0.10)
                  : HaloColors.surface3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: on ? HaloColors.amber : HaloColors.line,
                width: on ? 1.1 : 0.5,
              ),
            ),
            child: Row(
              children: [
                _Mark(on: on, multi: multi, ring: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: HaloType.sans(
                      size: 14,
                      color: HaloColors.text,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// after a vote: the answer, its share, and a bar that glides to it
class _ResultRow extends StatelessWidget {
  final String text;
  final double share;
  final bool mine;
  final bool leader;
  final bool multi;
  final VoidCallback onTap;
  const _ResultRow({
    required this.text,
    required this.share,
    required this.mine,
    required this.leader,
    required this.multi,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final pct = percent(share);
    return Semantics(
      button: true,
      selected: mine,
      label: l10n.pollOptionA11y(text, pct),
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        scale: 0.99,
        haptic: false,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 18,
                    child: _Mark(on: mine, multi: multi, ring: false),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: HaloType.sans(
                        size: 14,
                        weight: leader || mine
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: HaloColors.text,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: Duration(milliseconds: still ? 0 : 220),
                    child: Text(
                      pct,
                      key: ValueKey(pct),
                      style: HaloType.mono(
                        size: 11,
                        color: mine || leader
                            ? HaloColors.amber
                            : HaloColors.text2,
                        letter: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 26),
                child: HaloBar(
                  value: share,
                  height: 5,
                  grow: true,
                  duration: const Duration(milliseconds: 520),
                  color: mine || leader
                      ? HaloColors.amber
                      : HaloColors.amber.withValues(alpha: 0.42),
                  track: HaloColors.ink.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// a ring to pick in, or the tick of a pick: round for one answer, a
// rounded square for several
class _Mark extends StatelessWidget {
  final bool on;
  final bool multi;
  final bool ring;
  const _Mark({required this.on, required this.multi, required this.ring});
  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final shape = multi
        ? BoxDecoration(borderRadius: BorderRadius.circular(5))
        : const BoxDecoration(shape: BoxShape.circle);
    return SizedBox(
      width: 18,
      height: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (ring)
            Container(
              width: 18,
              height: 18,
              decoration: shape.copyWith(
                border: Border.all(
                  color: on ? HaloColors.amber : HaloColors.line2,
                  width: 1.4,
                ),
              ),
            ),
          AnimatedScale(
            scale: on ? 1 : 0,
            duration: Duration(milliseconds: still ? 0 : 300),
            curve: Curves.easeOutBack,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: shape.copyWith(color: HaloColors.amber),
              child: StrokeIcon(
                const ['M6 12.5l4 4l8-9'],
                size: 13,
                color: HaloColors.onAmber,
                stroke: 2.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// the first few who voted, their faces overlapping
class _Faces extends StatelessWidget {
  final List<String> ids;
  const _Faces({required this.ids});
  @override
  Widget build(BuildContext context) {
    const s = 18.0;
    const step = 12.0;
    return SizedBox(
      width: s + step * (ids.length - 1),
      height: s,
      child: Stack(
        children: [
          for (var i = 0; i < ids.length; i++)
            PositionedDirectional(
              start: step * i,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: HaloColors.surface2, width: 1.5),
                ),
                child: KryfoAvatar(seed: ids[i], size: s - 3),
              ),
            ),
        ],
      ),
    );
  }
}

class _VotersSheet extends StatelessWidget {
  final String question;
  final PollSpec poll;
  final PollTally tally;
  final String me;
  final String Function(String id) nameOf;
  const _VotersSheet({
    required this.question,
    required this.poll,
    required this.tally,
    required this.me,
    required this.nameOf,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 10),
            Text(
              l10n.pollWhoVoted,
              style: HaloType.serif(size: 20, color: HaloColors.text),
            ),
            const SizedBox(height: 4),
            Text(
              question,
              style: HaloType.sans(
                size: 13,
                color: HaloColors.text2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < poll.options.length; i++) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: HaloColors.surface3,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: HaloColors.line, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            poll.options[i],
                            style: HaloType.sans(
                              size: 14,
                              weight: FontWeight.w600,
                              color: HaloColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${whole(tally.counts[i])} · ${percent(tally.share(i))}',
                          style: HaloType.mono(
                            size: 10.5,
                            color: HaloColors.amber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    HaloBar(
                      value: tally.share(i),
                      height: 4,
                      grow: true,
                      track: HaloColors.ink.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 10),
                    if (tally.who[i].isEmpty)
                      Text(
                        l10n.pollNobody,
                        style: HaloType.sans(
                          size: 12.5,
                          color: HaloColors.text2,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final id in tally.who[i])
                            Container(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                3,
                                3,
                                10,
                                3,
                              ),
                              decoration: BoxDecoration(
                                color: HaloColors.surface2,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  KryfoAvatar(seed: id, size: 22),
                                  const SizedBox(width: 6),
                                  Text(
                                    id == me ? l10n.pollYou : nameOf(id),
                                    style: HaloType.sans(
                                      size: 12.5,
                                      color: HaloColors.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
