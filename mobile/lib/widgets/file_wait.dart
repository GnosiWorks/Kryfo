// SPDX-License-Identifier: GPL-3.0-or-later
// a file whose message is here before it is: what it is, how big, and what
// it waits for. a tap brings it now, a tap while it comes pauses it, and
// a paused one goes on from where it stopped. it fills a ring as it comes
// and gives its place to the file once it is in
import 'package:flutter/material.dart';

import '../file_kind.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../transfers.dart';
import 'file_bubble.dart' show fileNameDir;
import 'media_bubbles.dart' show humanFileSize, splitFileName;
import 'motion.dart' show kHouseCurve, motionStill;
import 'press_scale.dart';

/// the bubble's line under the name: its size and what it waits for, or
/// how far it is
@visibleForTesting
String fileWaitLine(FileWait w, {required bool unmetered, int? left}) {
  final size = humanFileSize(w.size);
  switch (w.state) {
    case WaitState.coming:
      final done = doneOfText(w.share, w.size);
      return l10n.transferReceiving(
        left == null ? done : l10n.transferDoneLeft(done, leftText(left)),
      );
    case WaitState.paused:
      return l10n.transferPausedAt(doneOfText(w.share, w.size));
    case WaitState.asks:
      final waitsForWifi = w.rule == AutoGet.wifi && !unmetered;
      return l10n.transferSizeLine(
        size,
        waitsForWifi ? l10n.transferOnWifi : l10n.transferTapToDownload,
      );
  }
}

class WaitingFileCard extends StatefulWidget {
  final String uid;
  // null for a photo
  final String? fileName;
  final FileWait wait;
  final VoidCallback onGet;
  final VoidCallback onPause;
  const WaitingFileCard({
    super.key,
    required this.uid,
    required this.fileName,
    required this.wait,
    required this.onGet,
    required this.onPause,
  });

  @override
  State<WaitingFileCard> createState() => _WaitingFileCardState();
}

class _WaitingFileCardState extends State<WaitingFileCard> {
  bool _unmetered = true;

  @override
  void initState() {
    super.initState();
    _readNet();
  }

  @override
  void didUpdateWidget(WaitingFileCard old) {
    super.didUpdateWidget(old);
    if (old.wait.state != widget.wait.state) _readNet();
  }

  Future<void> _readNet() async {
    final u = await unmeteredNow();
    if (mounted && u != _unmetered) setState(() => _unmetered = u);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.wait;
    final still = motionStill(context);
    final name = widget.fileName;
    final title = name == null
        ? l10n.appPhoto
        : safeFileName(name, facts: FileFacts(kindOfName(name), extOf(name)));
    final (stem, ext) = splitFileName(title);
    final line = fileWaitLine(
      w,
      unmetered: _unmetered,
      left: fileWaitLeft(widget.uid),
    );
    final coming = w.state == WaitState.coming;
    return Semantics(
      container: true,
      button: true,
      label: [title, line].join(', '),
      hint: switch (w.state) {
        WaitState.coming => l10n.transferPauseDownload,
        WaitState.paused => l10n.transferResume,
        WaitState.asks => l10n.transferDownload,
      },
      excludeSemantics: true,
      onTap: coming ? widget.onPause : widget.onGet,
      child: PressScale(
        scale: 0.97,
        onTap: coming ? widget.onPause : widget.onGet,
        // a file's sits in its bubble; a photo's has none around it
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: name == null
              ? const EdgeInsets.fromLTRB(10, 10, 12, 10)
              : EdgeInsets.zero,
          decoration: name == null
              ? BoxDecoration(
                  color: HaloColors.surface3,
                  borderRadius: BorderRadius.circular(14),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FileWaitMark(wait: w),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
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
                            style: HaloType.sans(
                              size: 14,
                              color: HaloColors.text,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (ext.isNotEmpty)
                          Text(
                            ext,
                            maxLines: 1,
                            textDirection: TextDirection.ltr,
                            style: HaloType.sans(
                              size: 14,
                              color: HaloColors.text,
                              weight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: still
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      layoutBuilder: (c, prev) => Stack(
                        alignment: AlignmentDirectional.centerStart,
                        children: [...prev, ?c],
                      ),
                      child: Text(
                        line,
                        key: ValueKey(w.state),
                        style: HaloType.mono(
                          size: 10.5,
                          color: coming
                              ? HaloColors.amberText
                              : HaloColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// the round mark of a file still to come: an arrow that brings it, a ring
/// that fills as it comes with a pause in it, a play mark that goes on
class FileWaitMark extends StatelessWidget {
  final FileWait wait;
  const FileWaitMark({super.key, required this.wait});

  @override
  Widget build(BuildContext context) {
    final w = wait;
    final still = motionStill(context);
    final coming = w.state == WaitState.coming;
    final Widget mark = coming
        ? Icon(
            Icons.pause_rounded,
            key: const ValueKey('pause'),
            size: 20,
            color: HaloColors.amber,
          )
        : Icon(
            w.state == WaitState.paused
                ? Icons.play_arrow_rounded
                : Icons.arrow_downward_rounded,
            key: ValueKey(w.state),
            size: 20,
            color: HaloColors.amber,
          );
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // one that asks is an open ring with an arrow; the soft fill
          // comes in once it moves
          AnimatedContainer(
            duration: still ? Duration.zero : const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: w.state == WaitState.asks
                  ? Colors.transparent
                  : HaloColors.amberSoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: w.state == WaitState.asks
                    ? HaloColors.amber
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          // the ring eases in and fills as the file comes
          AnimatedOpacity(
            opacity: w.state == WaitState.asks ? 0 : 1,
            duration: still ? Duration.zero : const Duration(milliseconds: 200),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: w.share.clamp(0.03, 1.0)),
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: v,
                  strokeWidth: 2.2,
                  color: HaloColors.amber,
                  backgroundColor: HaloColors.line,
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: still ? Duration.zero : const Duration(milliseconds: 220),
            switchInCurve: kHouseCurve,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(
                scale: Tween(begin: 0.6, end: 1.0).animate(a),
                child: c,
              ),
            ),
            child: mark,
          ),
        ],
      ),
    );
  }
}

/// the waiting card for [uid] while its file is still to come, following
/// it as it changes; [child] once it is in
class FileWaitOr extends StatelessWidget {
  final String? uid;
  final String? fileName;
  final void Function(String uid) onGet;
  final void Function(String uid) onPause;
  final Widget Function() child;
  const FileWaitOr({
    super.key,
    required this.uid,
    required this.fileName,
    required this.onGet,
    required this.onPause,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final id = uid;
    if (id == null) return child();
    return ValueListenableBuilder<Map<String, FileWait>>(
      valueListenable: fileWaits,
      builder: (context, waits, _) {
        final w = waits[id];
        return AnimatedSwitcher(
          duration: motionStill(context)
              ? Duration.zero
              : const Duration(milliseconds: 260),
          switchInCurve: kHouseCurve,
          child: w == null
              ? KeyedSubtree(key: const ValueKey('in'), child: child())
              : WaitingFileCard(
                  key: const ValueKey('wait'),
                  uid: id,
                  fileName: fileName,
                  wait: w,
                  onGet: () => onGet(id),
                  onPause: () => onPause(id),
                ),
        );
      },
    );
  }
}
