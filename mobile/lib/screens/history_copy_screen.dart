// SPDX-License-Identifier: GPL-3.0-or-later
// the history copy as the person follows it, on the phone and on the new
// device alike: its size first, how far it is, and how it ended. a chat
// with less than the phone holds is named with what came of it; what the
// phone could not send and the chats that stayed there are said too. an
// end is said calmly, never sounded as an alarm
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../devices/history_export.dart' show HistoryChatRef;
import '../devices/history_link.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart' show decimal, whole;
import '../theme.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/motion.dart' show motionStill;
import '../widgets/onion_loader.dart';
import '../widgets/page_head.dart';
import '../widgets/swap.dart';

/// the copy's size as the person reads it
String historyCopySize(int bytes) {
  const mb = 1024 * 1024;
  if (bytes >= 1024 * mb) {
    return l10n.restoreGb(decimal(bytes / (1024 * mb), 1));
  }
  return l10n.restoreMb(whole((bytes / mb).ceil().clamp(1, 1 << 30)));
}

/// the title and the line for a stage
({String title, String line}) historyCopyWords(HistoryCopyStage s) =>
    switch (s.step) {
      HistoryCopyStep.making => (
        title: l10n.historyCopyMaking,
        line: l10n.historyCopyMakingLine,
      ),
      HistoryCopyStep.waiting => (
        title: l10n.historyCopyWaiting,
        line: l10n.historyCopyWaitingLine,
      ),
      HistoryCopyStep.copying => (
        title: l10n.historyCopyGoing,
        line: l10n.historyCopyGoingLine,
      ),
      HistoryCopyStep.paused => (
        title: l10n.historyCopyPaused,
        line: l10n.historyCopyPausedLine,
      ),
      HistoryCopyStep.whole when s.rowsOnly => (
        title: l10n.historyCopyRows,
        line: l10n.historyCopyRowsLine,
      ),
      HistoryCopyStep.whole => (
        title: l10n.historyCopyWhole,
        line: l10n.historyCopyWholeLine,
      ),
      HistoryCopyStep.gaps => (
        title: l10n.historyCopyGaps,
        line: s.gaps.isEmpty
            ? l10n.historyCopyLeftWhy
            : l10n.historyCopyGapsLine,
      ),
      HistoryCopyStep.ended => (
        title: l10n.historyCopyEnded,
        line: l10n.historyCopyEndedLine,
      ),
      HistoryCopyStep.failed => (
        title: l10n.historyCopyFailed,
        line: l10n.historyCopyFailedLine,
      ),
    };

class HistoryCopyScreen extends StatelessWidget {
  const HistoryCopyScreen({
    super.key,
    required this.stage,
    required this.nameOf,
    this.onSeen,
  });

  final ValueListenable<HistoryCopyStage?> stage;

  /// a chat's name as this device shows it
  final Future<String> Function(HistoryChatRef chat) nameOf;

  /// the page showed how the copy ended
  final VoidCallback? onSeen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageBar(title: l10n.historyCopyTitle),
            Expanded(
              child: ValueListenableBuilder<HistoryCopyStage?>(
                valueListenable: stage,
                builder: (context, v, _) {
                  final s = v ?? const HistoryCopyStage(HistoryCopyStep.making);
                  if (historyCopyOver(s.step)) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => onSeen?.call(),
                    );
                  }
                  return FadeSwap(
                    child: KeyedSubtree(
                      key: ValueKey(s.step),
                      child: _CopyPage(stage: s, nameOf: nameOf),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyPage extends StatelessWidget {
  const _CopyPage({required this.stage, required this.nameOf});
  final HistoryCopyStage stage;
  final Future<String> Function(HistoryChatRef chat) nameOf;

  @override
  Widget build(BuildContext context) {
    final s = stage;
    final w = historyCopyWords(s);
    final over = historyCopyOver(s.step);
    final good = s.step == HistoryCopyStep.whole;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Center(
              child: over
                  ? _Mark(good: good)
                  : OnionLoader(size: 88, color: HaloColors.amber),
            ),
            const SizedBox(height: 24),
            Semantics(
              liveRegion: true,
              header: true,
              child: Text(
                w.title,
                textAlign: TextAlign.center,
                style: HaloType.serif(size: 24, color: HaloColors.text),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              w.line,
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 14,
                color: HaloColors.text2,
                height: 1.45,
              ),
            ),
            if (s.bytes > 0 && !over) ...[
              const SizedBox(height: 22),
              _Bar(share: s.share),
              const SizedBox(height: 10),
              Text(
                l10n.historyCopySize(historyCopySize(s.bytes)),
                textAlign: TextAlign.center,
                style: HaloType.sans(size: 13, color: HaloColors.text2),
              ),
            ],
            for (final g in s.gaps)
              _ChatLine(
                chat: g.chat,
                nameOf: nameOf,
                lines: [
                  if (g.got.messages != g.want.messages)
                    l10n.historyCopyGapMessages(
                      whole(g.got.messages),
                      whole(g.want.messages),
                    ),
                  if (g.got.media != g.want.media)
                    l10n.historyCopyGapFiles(
                      whole(g.got.media),
                      whole(g.want.media),
                    ),
                ],
              ),
            for (final l in s.left)
              _ChatLine(
                chat: l.chat,
                nameOf: nameOf,
                lines: [
                  l10n.historyCopyLeft(l.rows + l.files),
                  l10n.historyCopyLeftWhy,
                ],
              ),
            if (s.leftChats > 0)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  l10n.historyCopyLeftChats(s.leftChats),
                  textAlign: TextAlign.center,
                  style: HaloType.sans(size: 14, color: HaloColors.text),
                ),
              ),
            if (s.stays.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                l10n.historyCopyStays,
                style: HaloType.sans(
                  size: 13,
                  weight: FontWeight.w600,
                  color: HaloColors.text2,
                ),
              ),
              for (final st in s.stays)
                _ChatLine(chat: st.chat, nameOf: nameOf, lines: [st.line]),
            ],
            if (over) ...[
              const SizedBox(height: 28),
              HaloPrimaryButton(
                label: l10n.commonDone,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.good});
  final bool good;

  @override
  Widget build(BuildContext context) {
    final tint = HaloColors.amber;
    final still = motionStill(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? 1 : 0.6, end: 1),
      duration: still ? Duration.zero : const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tint.withValues(alpha: 0.14),
          border: Border.all(color: tint.withValues(alpha: 0.4)),
        ),
        alignment: Alignment.center,
        child: ExcludeSemantics(
          child: Icon(
            good ? Icons.check_rounded : Icons.history_rounded,
            size: 36,
            color: HaloColors.amberText,
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.share});
  final double share;

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return Semantics(
      value: '${(share * 100).round()} %',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: share),
          duration: still ? Duration.zero : const Duration(milliseconds: 300),
          builder: (context, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: 6,
            color: HaloColors.amber,
            backgroundColor: HaloColors.surface3,
          ),
        ),
      ),
    );
  }
}

class _ChatLine extends StatelessWidget {
  const _ChatLine({
    required this.chat,
    required this.nameOf,
    required this.lines,
  });
  final HistoryChatRef chat;
  final Future<String> Function(HistoryChatRef chat) nameOf;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HaloColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String>(
              future: nameOf(chat),
              builder: (context, n) => Text(
                n.data ?? '',
                style: HaloType.sans(
                  size: 15,
                  weight: FontWeight.w600,
                  color: HaloColors.text,
                ),
              ),
            ),
            for (final l in lines) ...[
              const SizedBox(height: 4),
              Text(l, style: HaloType.sans(size: 14, color: HaloColors.text2)),
            ],
          ],
        ),
      ),
    );
  }
}
