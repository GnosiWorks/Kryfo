// SPDX-License-Identifier: GPL-3.0-or-later
// the developer chat's own parts: its header, the note above the composer
// that says what Marios will see before anything is sent, the pill that
// writes anonymously instead, and the sheet that says who sees what
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import 'dev_avatar.dart';
import 'halo_sheet.dart';
import 'motion.dart';
import 'pins.dart' show PinHeaderButton;
import 'sheet_handle.dart';
import 'stagger_in.dart';

// the three words, or a name made for this chat
IconData devNameGlyph(bool anon) =>
    anon ? Icons.masks_outlined : Icons.visibility_outlined;

// above the composer until the first message: what Marios will see, one
// tap to write anonymously instead, and one to go back. it rises with the
// composer when the chat opens; the chat folds it away at the first send
class DevNote extends StatefulWidget {
  const DevNote({
    super.key,
    required this.anon,
    required this.onChoose,
    required this.onWho,
    this.busy = false,
  });

  final bool anon;
  // the start is on its way: the choice holds still
  final bool busy;
  final ValueChanged<bool> onChoose;
  final VoidCallback onWho;

  @override
  State<DevNote> createState() => _DevNoteState();
}

class _DevNoteState extends State<DevNote> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final CurvedAnimation _size = CurvedAnimation(
    parent: _in,
    curve: Curves.easeOutCubic,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_in.isAnimating || _in.isCompleted) return;
    if (motionStill(context)) {
      _in.value = 1;
    } else {
      _in.forward();
    }
  }

  @override
  void dispose() {
    _size.dispose();
    _in.dispose();
    super.dispose();
  }

  void _choose(bool anon) {
    if (widget.busy || anon == widget.anon) return;
    HapticFeedback.selectionClick();
    widget.onChoose(anon);
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final swap = still ? Duration.zero : const Duration(milliseconds: 160);
    final anon = widget.anon;
    final card = Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsetsDirectional.fromSTEB(13, 10, 6, 10),
      decoration: BoxDecoration(
        color: HaloColors.amber.withValues(alpha: 0.07),
        border: Border.all(
          color: HaloColors.amber.withValues(alpha: 0.22),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: AnimatedSwitcher(
                  duration: swap,
                  transitionBuilder: (child, a) =>
                      FadeTransition(opacity: a, child: child),
                  child: Icon(
                    devNameGlyph(anon),
                    key: ValueKey(anon),
                    size: 17,
                    color: HaloColors.amber,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  // said to a screen reader as it changes
                  child: Semantics(
                    liveRegion: true,
                    child: AnimatedSwitcher(
                      duration: swap,
                      layoutBuilder: (current, previous) => Stack(
                        alignment: AlignmentDirectional.topStart,
                        children: [...previous, ?current],
                      ),
                      transitionBuilder: (child, a) =>
                          FadeTransition(opacity: a, child: child),
                      child: Text(
                        anon ? l10n.devNoteAnon : l10n.devNoteWords,
                        key: ValueKey(anon),
                        style: HaloType.sans(
                          size: 13,
                          color: HaloColors.text,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.devWhoSeesWhat,
                onPressed: widget.onWho,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
                icon: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: HaloColors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 26, end: 7),
            // the way back at the start, the pill at the end. when both do
            // not fit on one line the pill goes above it
            child: OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              spacing: 8,
              overflowSpacing: 4,
              overflowDirection: VerticalDirection.up,
              overflowAlignment: OverflowBarAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: swap,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: AlignmentDirectional.centerStart,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, a) =>
                      FadeTransition(opacity: a, child: child),
                  child: anon
                      ? _Back(
                          key: const ValueKey('back'),
                          onTap: widget.busy ? null : () => _choose(false),
                        )
                      : const SizedBox(key: ValueKey('none'), height: 1),
                ),
                _Pill(on: anon, busy: widget.busy, onTap: () => _choose(!anon)),
              ],
            ),
          ),
        ],
      ),
    );
    return SizeTransition(
      sizeFactor: _size,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _in,
        child: AnimatedBuilder(
          animation: _in,
          child: card,
          builder: (_, child) => Transform.translate(
            offset: Offset(
              0,
              still ? 0 : 10 * (1 - kHouseCurve.transform(_in.value)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// "Use my three words": back to the everyday name, before anything is sent
class _Back extends StatelessWidget {
  const _Back({super.key, required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Text(
            l10n.devUseMyWords,
            style: HaloType.sans(
              size: 12.5,
              weight: FontWeight.w500,
              color: HaloColors.amber,
              height: 1.25,
            ),
          ),
        ),
      ),
    );
  }
}

// "Write anonymously" that fills, takes a check and reads "Anonymous"
class _Pill extends StatelessWidget {
  const _Pill({required this.on, required this.busy, required this.onTap});
  final bool on;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final fill = still ? Duration.zero : const Duration(milliseconds: 180);
    final fg = on ? HaloColors.onAmber : HaloColors.amber;
    final check = on
        ? Padding(
            padding: const EdgeInsetsDirectional.only(end: 5),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: still ? 1 : 0.4, end: 1),
              duration: still ? Duration.zero : kHouseTime,
              curve: kHouseCurve,
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: Icon(Icons.check_rounded, size: 15, color: fg),
            ),
          )
        : const SizedBox.shrink();
    return Semantics(
      button: true,
      toggled: on,
      enabled: !busy,
      child: AnimatedOpacity(
        opacity: busy ? 0.55 : 1,
        duration: fill,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: busy ? null : onTap,
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: fill,
              curve: Curves.easeOut,
              constraints: const BoxConstraints(minHeight: 32),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: on ? HaloColors.amber : HaloColors.amberSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: HaloColors.amber.withValues(alpha: on ? 1 : 0.45),
                  width: 0.8,
                ),
                boxShadow: on && !still
                    ? [
                        BoxShadow(
                          color: HaloColors.amber.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // the check grows in as the pill fills
                  if (still)
                    check
                  else
                    AnimatedSize(
                      duration: fill,
                      curve: kHouseCurve,
                      child: check,
                    ),
                  // a long language at a big font wraps inside the pill
                  Flexible(
                    child: AnimatedDefaultTextStyle(
                      duration: fill,
                      style: HaloType.sans(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: fg,
                        height: 1.2,
                      ),
                      child: Text(
                        on ? l10n.devAnonymous : l10n.devWriteAnonymously,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showDevWhoSheet(BuildContext context) {
  HapticFeedback.selectionClick();
  return showHaloSheet<void>(context, builder: (_) => const DevWhoSheet());
}

// who sees what, in the chat's own words: the two ways to write, and that
// nothing leaves before the first message
class DevWhoSheet extends StatelessWidget {
  const DevWhoSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 10),
            ...staggerAllIn(context, [
              Text(
                l10n.devWhoSeesWhat,
                style: HaloType.serif(size: 21, color: HaloColors.text),
              ),
              const SizedBox(height: 18),
              _WhoLine(glyph: devNameGlyph(false), line: l10n.devWhoWords),
              const SizedBox(height: 14),
              _WhoLine(glyph: devNameGlyph(true), line: l10n.devWhoAnon),
              const SizedBox(height: 14),
              _WhoLine(
                glyph: Icons.lock_clock_outlined,
                line: l10n.devWhoNothingYet,
              ),
              const SizedBox(height: 18),
              Text(
                l10n.devWhoChoiceStays,
                style: HaloType.mono(
                  size: 11,
                  color: HaloColors.amber,
                  letter: 0.2,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _WhoLine extends StatelessWidget {
  const _WhoLine({required this.glyph, required this.line});
  final IconData glyph;
  final String line;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HaloColors.amberSoft,
          ),
          child: Icon(glyph, size: 16, color: HaloColors.amber),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              line,
              style: HaloType.sans(
                size: 13.5,
                color: HaloColors.text,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// "Anonymous", the way the chat started. one look in the header and sheet
class DevAnonChip extends StatelessWidget {
  const DevAnonChip({super.key, this.size = 10});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 2, 8, 2),
      decoration: BoxDecoration(
        color: HaloColors.amberSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: HaloColors.amber.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(devNameGlyph(true), size: size + 2, color: HaloColors.amber),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              l10n.devAnonymous,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HaloType.mono(size: size, color: HaloColors.amber),
            ),
          ),
        ],
      ),
    );
  }
}

// the dev chat's header: his ring, flown in from the row, the one title
// every language has for him, and the key built into the app. a tap opens
// his sheet. no nickname, no contact page, no safety number, no block
class DevChatHead extends StatelessWidget {
  const DevChatHead({
    super.key,
    required this.anon,
    required this.onBack,
    required this.onAbout,
    required this.onSearch,
    required this.onMore,
    this.pinnedCount = 0,
    required this.onPinned,
  });

  // started anonymously
  final bool anon;
  final VoidCallback onBack;
  final VoidCallback onAbout;
  final VoidCallback onSearch;
  final VoidCallback onMore;
  final int pinnedCount;
  final VoidCallback onPinned;

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final pins = pinnedCount > 0
        ? PinHeaderButton(count: pinnedCount, onTap: onPinned)
        : const SizedBox.shrink();
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 8, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.commonBack,
            icon: Icon(Icons.chevron_left, color: HaloColors.text2, size: 26),
            onPressed: onBack,
          ),
          Expanded(
            child: Semantics(
              button: true,
              label: l10n.devRowTitle,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onAbout,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    // the ring flies in from the row
                    const Hero(tag: kDevFaceHero, child: DevAvatar(size: 36)),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.devRowTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HaloType.serif(
                              size: 16.5,
                              color: HaloColors.text,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              DevTick(size: 11, cut: HaloColors.surface),
                              const SizedBox(width: 5),
                              // the key built in, and after an anonymous
                              // start the chip in its place
                              Flexible(
                                child: AnimatedSwitcher(
                                  duration: still
                                      ? Duration.zero
                                      : const Duration(milliseconds: 240),
                                  switchInCurve: kHouseCurve,
                                  layoutBuilder: (current, previous) => Stack(
                                    alignment: AlignmentDirectional.centerStart,
                                    children: [...previous, ?current],
                                  ),
                                  transitionBuilder: (child, a) =>
                                      FadeTransition(
                                        opacity: a,
                                        child: still
                                            ? child
                                            : ScaleTransition(
                                                alignment: AlignmentDirectional
                                                    .centerStart
                                                    .resolve(
                                                      Directionality.of(
                                                        context,
                                                      ),
                                                    ),
                                                scale: Tween(
                                                  begin: 0.85,
                                                  end: 1.0,
                                                ).animate(a),
                                                child: child,
                                              ),
                                      ),
                                  child: anon
                                      ? const DevAnonChip(
                                          key: ValueKey('anon'),
                                          size: 9.5,
                                        )
                                      : Text(
                                          l10n.devPinned,
                                          key: const ValueKey('words'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: HaloType.mono(
                                            size: 10,
                                            color: HaloColors.amber,
                                            letter: 0,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // his chat seldom pins: the button comes when a pin does
          if (still)
            pins
          else
            AnimatedSize(duration: kHouseTime, curve: kHouseCurve, child: pins),
          IconButton(
            tooltip: l10n.chatSearchThisChat,
            icon: Icon(Icons.search_rounded, color: HaloColors.text2, size: 21),
            onPressed: onSearch,
          ),
          IconButton(
            tooltip: l10n.devChatOptions,
            icon: Icon(Icons.more_vert, color: HaloColors.text2, size: 21),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}
