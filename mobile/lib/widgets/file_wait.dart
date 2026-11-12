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

/// the mark of a file still to come: a rounded square with an arrow that
/// brings it, which rounds into a ring that fills as it comes, with a pause
/// in it, and a play mark that goes on
class FileWaitMark extends StatelessWidget {
  final FileWait wait;
  const FileWaitMark({super.key, required this.wait});

  static const size = 42.0;

  @override
  Widget build(BuildContext context) {
    final w = wait;
    final still = motionStill(context);
    final asks = w.state == WaitState.asks;
    final Widget mark = Icon(
      switch (w.state) {
        WaitState.coming => Icons.pause_rounded,
        WaitState.paused => Icons.play_arrow_rounded,
        WaitState.asks => Icons.download_rounded,
      },
      key: ValueKey(w.state),
      size: asks ? 19 : 20,
      color: HaloColors.amber,
    );
    final morph = still ? Duration.zero : const Duration(milliseconds: 240);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // the tile that asks rounds into the ring's soft disc on a tap
          AnimatedContainer(
            key: const ValueKey('tile'),
            duration: morph,
            curve: kHouseCurve,
            decoration: BoxDecoration(
              // a faint wash, no outline (mario 2026-11-12)
              color: asks
                  ? HaloColors.amber.withValues(alpha: 0.14)
                  : HaloColors.amberSoft,
              borderRadius: BorderRadius.circular(asks ? 11 : size / 2),
            ),
          ),
          // the ring eases in and fills as the file comes
          AnimatedOpacity(
            opacity: asks ? 0 : 1,
            duration: still ? Duration.zero : const Duration(milliseconds: 200),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: w.share.clamp(0.03, 1.0)),
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => SizedBox(
                width: size - 2,
                height: size - 2,
                child: CircularProgressIndicator(
                  value: v,
                  strokeWidth: 2.4,
                  strokeCap: StrokeCap.round,
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
