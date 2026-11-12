// SPDX-License-Identifier: GPL-3.0-or-later
// files sent together, in one bubble: a row each, every row with the same
// glance a file alone gets (a pdf's first page, a text's first lines, a
// sound's player, a video's frame), its own ring while it goes, a tile
// that brings it while it waits, and a retry when it did not go. "Get all"
// brings every one still waiting, one after the other; a paused one goes
// on from where it stopped. nothing here ever comes on its own
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../desktop/desktop_mode.dart' show onDesktop;
import '../file_kind.dart';
import '../l10n/dates.dart' show dayMonthMaybeYear;
import '../l10n/l10n.dart';
import '../l10n/numbers.dart' show whole;
import '../theme.dart';
import '../file_drop.dart' show kFetchKeptFor;
import '../transfers.dart';
import 'file_bubble.dart' show fileNameDir;
import 'file_wait.dart' show FileWaitMark, fileWaitLine;
import 'media_bubbles.dart' show humanFileSize, splitFileName;
import 'motion.dart' show kHouseCurve, motionStill;
import 'press_scale.dart';
import 'spoiler_cover.dart';

/// a file kept on the files service: past this from when it was written it
/// is not there to get any more
const kFileKeptFor = kFetchKeptFor;

/// one row of a set
class FileStackRow {
  // its message's uid, or anything that stays the same for the row
  final String id;
  final String? name;
  // a file of theirs still to come: its uid in [fileWaits]
  final String? waitUid;
  // ours that did not go: a tap sends it again
  final bool failed;
  final VoidCallback? onRetry;
  // when it may still be got, for one that waits
  final DateTime? until;
  // the row as a file alone draws: its glance, ring and player
  final Widget Function() ready;
  final VoidCallback? onLongPress;
  // a photo in the set sent as a spoiler: blurred until tapped
  final bool spoiler;
  const FileStackRow({
    required this.id,
    required this.name,
    required this.ready,
    this.waitUid,
    this.failed = false,
    this.onRetry,
    this.until,
    this.onLongPress,
    this.spoiler = false,
  });
}

class FileStack extends StatelessWidget {
  final List<FileStackRow> rows;
  final bool isOut;
  final void Function(String uid) onGet;
  final void Function(String uid) onPause;
  const FileStack({
    super.key,
    required this.rows,
    required this.isOut,
    required this.onGet,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<Map<String, FileWait>>(
        valueListenable: fileWaits,
        builder: (context, waits, _) {
          final waiting = [
            for (final r in rows)
              if (r.waitUid case final u? when waits[u] != null) (u, waits[u]!),
          ];
          final asks = [
            for (final (u, w) in waiting)
              if (w.state != WaitState.coming) (u, w),
          ];
          final coming = waiting.length - asks.length;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.textScalerOf(context).scale(10) > 12
                  ? 320
                  : 260,
            ),
            // every row as wide as the bubble: when its width moves (its
            // time and tick come in) the rows keep to its start, no strip
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, r) in rows.indexed) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _Row(
                    key: ValueKey(r.id),
                    row: r,
                    wait: r.waitUid == null ? null : waits[r.waitUid],
                    isOut: isOut,
                    onGet: onGet,
                    onPause: onPause,
                  ),
                ],
                if (waiting.length > 1 || (asks.isNotEmpty && coming > 0))
                  _GetAll(
                    total: rows.length,
                    here: rows.length - waiting.length,
                    asks: asks,
                    coming: coming,
                    onGet: onGet,
                  ),
              ],
            ),
          );
        },
      );
}

class _Row extends StatefulWidget {
  final FileStackRow row;
  final FileWait? wait;
  final bool isOut;
  final void Function(String uid) onGet;
  final void Function(String uid) onPause;
  const _Row({
    super.key,
    required this.row,
    required this.wait,
    required this.isOut,
    required this.onGet,
    required this.onPause,
  });

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> with SingleTickerProviderStateMixin {
  // a gentle shake, once, when the row turns failed
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  @override
  void didUpdateWidget(_Row old) {
    super.didUpdateWidget(old);
    if (!old.row.failed && widget.row.failed) {
      HapticFeedback.lightImpact();
      if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
        _shake.forward(from: 0);
      }
    }
    // it came in: the light tap that says so
    if (old.wait != null && widget.wait == null) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final w = widget.wait;
    final still = motionStill(context);
    final Widget child;
    if (w != null && r.waitUid != null) {
      child = _WaitRow(
        key: const ValueKey('wait'),
        uid: r.waitUid!,
        name: r.name,
        wait: w,
        until: r.until,
        onGet: () => widget.onGet(r.waitUid!),
        onPause: () => widget.onPause(r.waitUid!),
      );
    } else if (r.failed) {
      child = _FailedRow(
        key: const ValueKey('failed'),
        name: r.name,
        isOut: widget.isOut,
        onRetry: r.onRetry,
      );
    } else {
      child = KeyedSubtree(
        key: const ValueKey('here'),
        child: r.spoiler
            ? SpoilerCover(
                uid: r.id,
                on: true,
                radius: BorderRadius.circular(12),
                child: r.ready(),
              )
            : r.ready(),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: r.onLongPress,
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, c) {
          final t = _shake.value;
          // three small swings that settle
          final dx = t == 0 || t == 1
              ? 0.0
              : 5 * (1 - t) * math.sin(t * 6 * math.pi);
          return Transform.translate(offset: Offset(dx, 0), child: c);
        },
        child: AnimatedSwitcher(
          duration: still ? Duration.zero : const Duration(milliseconds: 240),
          switchInCurve: kHouseCurve,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (c, prev) => Stack(
            alignment: AlignmentDirectional.topStart,
            children: [...prev, ?c],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// the name with its extension always in view, and a line under it
class _NameLines extends StatelessWidget {
  final String title;
  final Widget line;
  final Color color;
  const _NameLines({
    required this.title,
    required this.line,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final (stem, ext) = splitFileName(title);
    final style = HaloType.sans(
      size: 14,
      color: color,
      weight: FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: fileNameDir(stem),
          children: [
            Flexible(
              child: Text(
                stem,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: fileNameDir(stem),
                textWidthBasis: TextWidthBasis.longestLine,
                style: style,
              ),
            ),
            if (ext.isNotEmpty)
              Text(
                ext,
                maxLines: 1,
                textDirection: TextDirection.ltr,
                style: style,
              ),
          ],
        ),
        const SizedBox(height: 3),
        line,
      ],
    );
  }
}

String _titleOf(String? name) => name == null
    ? l10n.mediaBubblesFile
    : safeFileName(name, facts: FileFacts(kindOfName(name), extOf(name)));

/// the line of a file that waits: its size, what a tap does, and until when
/// it can still be got
String fileWaitRowLine(FileWait w, {DateTime? until, int? left}) {
  final line = fileWaitLine(w, unmetered: true, left: left);
  if (w.state != WaitState.asks || until == null) return line;
  return '$line · ${l10n.fileUntil(dayMonthMaybeYear(until))}';
}

class _WaitRow extends StatelessWidget {
  final String uid;
  final String? name;
  final FileWait wait;
  final DateTime? until;
  final VoidCallback onGet;
  final VoidCallback onPause;
  const _WaitRow({
    super.key,
    required this.uid,
    required this.name,
    required this.wait,
    required this.until,
    required this.onGet,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final coming = wait.state == WaitState.coming;
    final title = _titleOf(name);
    final line = fileWaitRowLine(wait, until: until, left: fileWaitLeft(uid));
    final tap = coming ? onPause : onGet;
    return Semantics(
      container: true,
      button: true,
      label: '$title, $line',
      hint: switch (wait.state) {
        WaitState.coming => l10n.transferPauseDownload,
        WaitState.paused => l10n.transferResume,
        WaitState.asks => l10n.transferDownload,
      },
      excludeSemantics: true,
      onTap: tap,
      child: PressScale(
        scale: 0.97,
        onTap: tap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FileWaitMark(wait: wait),
            const SizedBox(width: 10),
            Flexible(
              child: _NameLines(
                title: title,
                color: HaloColors.text,
                line: AnimatedSwitcher(
                  duration: still
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  layoutBuilder: (c, prev) => Stack(
                    alignment: AlignmentDirectional.centerStart,
                    children: [...prev, ?c],
                  ),
                  child: Text(
                    line,
                    key: ValueKey(wait.state),
                    maxLines: 3,
                    style: HaloType.mono(
                      size: 10,
                      color: coming ? HaloColors.amberText : HaloColors.text,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedRow extends StatelessWidget {
  final String? name;
  final bool isOut;
  final VoidCallback? onRetry;
  const _FailedRow({
    super.key,
    required this.name,
    required this.isOut,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final ink = isOut ? HaloColors.onAmber : HaloColors.text;
    final title = _titleOf(name);
    final line = onDesktop
        ? l10n.chatFailedTapToRetryDesk
        : l10n.chatFailedTapToRetry;
    return Semantics(
      container: true,
      button: onRetry != null,
      label: '$title, $line',
      excludeSemantics: true,
      onTap: onRetry,
      child: PressScale(
        scale: 0.97,
        onTap: onRetry,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: ink, width: 2),
              ),
              child: Icon(Icons.refresh_rounded, size: 19, color: ink),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: _NameLines(
                title: title,
                color: ink,
                line: Text(
                  line,
                  maxLines: 2,
                  style: HaloType.mono(size: 10, color: ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// brings every file of the set still waiting, one after the other, and
/// counts them in as they land
class _GetAll extends StatelessWidget {
  final int total;
  final int here;
  final List<(String, FileWait)> asks;
  final int coming;
  final void Function(String uid) onGet;
  const _GetAll({
    required this.total,
    required this.here,
    required this.asks,
    required this.coming,
    required this.onGet,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    var left = 0;
    for (final (_, w) in asks) {
      left += (w.size * (1 - w.share.clamp(0.0, 1.0))).round();
    }
    final busy = asks.isEmpty;
    final label = busy ? null : l10n.fileSetGetAll(humanFileSize(left));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: HaloColors.line)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: AnimatedSwitcher(
            duration: still ? Duration.zero : const Duration(milliseconds: 200),
            switchInCurve: kHouseCurve,
            // at the start of the row, under the files, as the mockup has it
            layoutBuilder: (c, prev) => Stack(
              alignment: AlignmentDirectional.centerStart,
              children: [...prev, ?c],
            ),
            child: busy
                ? _Counting(
                    key: const ValueKey('counting'),
                    here: here,
                    total: total,
                  )
                : Semantics(
                    key: const ValueKey('all'),
                    button: true,
                    label: label,
                    excludeSemantics: true,
                    child: PressScale(
                      scale: 0.95,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        for (final (u, _) in asks) {
                          onGet(u);
                        }
                      },
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: HaloColors.surface3,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.download_rounded,
                              size: 16,
                              color: HaloColors.amber,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                label!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HaloType.sans(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: HaloColors.amberText,
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
      ),
    );
  }
}

/// "Getting 2 of 4", the count rolling up as each lands
class _Counting extends StatelessWidget {
  final int here;
  final int total;
  const _Counting({super.key, required this.here, required this.total});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return Semantics(
      liveRegion: true,
      label: l10n.fileSetGetting(whole(here), whole(total)),
      excludeSemantics: true,
      child: SizedBox(
        height: 34,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: here.toDouble()),
            duration: still ? Duration.zero : const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              l10n.fileSetGetting(whole(v.round()), whole(total)),
              style: HaloType.mono(size: 11, color: HaloColors.amberText),
            ),
          ),
        ),
      ),
    );
  }
}
