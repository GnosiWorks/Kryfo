// SPDX-License-Identifier: GPL-3.0-or-later
// a sticker in a chat: no bubble, the sticker alone with its time in a small
// pill at the bottom end. one this version does not have is a tile with its
// emoji, and the row keeps its value, so it draws the day the pack has it.
import 'package:flutter/material.dart';

import '../dlog.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/motion.dart' show houseSpring;
import '../widgets/press_scale.dart';
import '../widgets/stroke_icon.dart';
import 'sticker_flight.dart';
import 'sticker_pack.dart';
import 'sticker_sheet.dart' show stickerGlyph;
import 'sticker_view.dart';
import 'sticker_wire.dart';

const kStickerBubble = 168.0;
const kStickerTile = 120.0;
const kStickerThumb = 28.0;

// the arrival's scale, found by tests next to PressScale's own
const kStickerPopKey = ValueKey('sticker-pop');

/// the sticker [w] names, if one of this version's packs has it
Sticker? stickerFor(StickerLibrary? lib, StickerWire w) => lib?.sticker(w.ref);

/// what a screen reader says for a sticker
String stickerSaid(String emoji) =>
    emoji.isEmpty ? l10n.stickerLabel : l10n.stickerA11y(emoji);

class StickerBubble extends StatefulWidget {
  const StickerBubble({
    super.key,
    required this.wire,
    required this.emoji,
    required this.isOut,
    this.seed = '',
    this.stamp,
    this.quote,
    this.budget,
    this.order = 0,
    this.arriving = false,
    this.landing,
    this.onTap,
  });

  final StickerWire wire;
  // the row's text: our emoji for it, the sender's one emoji, or ''
  final String emoji;
  final bool isOut;
  // the message uid: where in its loop it starts, so two copies differ
  final String seed;
  // the time and ticks; null shows none
  final Widget? stamp;
  // the message it replies to, above it
  final Widget? quote;
  final StickerBudget? budget;
  final int order;
  // just arrived or just sent: it pops in, or fades under reduced motion
  final bool arriving;
  // on its way from the picker: hidden until the flight is down
  final StickerLanding? landing;
  final VoidCallback? onTap;

  @override
  State<StickerBubble> createState() => _StickerBubbleState();
}

class _StickerBubbleState extends State<StickerBubble>
    with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  late final AnimationController _fade = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 120),
  );
  // the landing it was built with: its key stays on the box after the chat
  // lets go of it
  StickerLanding? _landing;
  bool _shown = true;
  bool _playing = true;
  bool _begun = false;
  // a new one starts at once, an old one after its phase
  late final bool _now;
  double _start = 0;

  @override
  void initState() {
    super.initState();
    _now = widget.arriving || widget.landing != null;
    final l = widget.landing;
    if (l == null) return;
    _landing = l;
    if (l.landed.value) {
      _start = l.at;
    } else {
      _shown = false;
      _fade.value = 0;
      l.landed.addListener(_landed);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_begun) return;
    _begun = true;
    if (!_shown || !widget.arriving) return;
    _fade
      ..value = 0
      ..forward();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    // the loop starts once it has popped
    _playing = false;
    _pop.value = 0.72;
    _pop.animateWith(houseSpring(0.72, 1)).then((_) {
      if (!mounted) return;
      _pop.value = 1;
      setState(() => _playing = true);
    });
  }

  void _landed() {
    final l = _landing;
    if (l == null || !l.landed.value) return;
    l.landed.removeListener(_landed);
    if (!mounted) return;
    setState(() {
      _shown = true;
      _start = l.at;
    });
    _fade
      ..duration = const Duration(milliseconds: 80)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _landing?.landed.removeListener(_landed);
    _pop.dispose();
    _fade.dispose();
    super.dispose();
  }

  int _phase(Sticker s) {
    if (_now || s.loopMs <= 0) return 0;
    return (widget.seed.hashCode & 0x7fffffff) % s.loopMs;
  }

  Widget _sticker(Sticker? s) {
    final stamp = widget.stamp;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox.square(
          key: _landing?.key,
          dimension: kStickerBubble,
          child: s == null || !_shown
              ? null
              : StickerView(
                  sticker: s,
                  size: kStickerBubble,
                  budget: widget.budget,
                  order: widget.order,
                  delay: _phase(s),
                  start: _start,
                  play: _playing,
                  label: stickerSaid(widget.emoji),
                ),
        ),
        if (stamp != null)
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kStickerBubble),
              child: stamp,
            ),
          ),
      ],
    );
  }

  Widget _tile() {
    final stamp = widget.stamp;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.isOut
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        StickerPlaceholder(emoji: widget.emoji),
        if (stamp != null) ...[
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kStickerBubble),
            child: stamp,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.quote;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.isOut
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        ?quote,
        FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            key: kStickerPopKey,
            scale: _pop,
            child: PressScale(
              scale: 0.94,
              onTap: widget.onTap ?? () {},
              child: StickerLibraryBuilder(
                builder: (lib, failed) {
                  final s = stickerFor(lib, widget.wire);
                  // still loading: an empty box the size it will be
                  if (s == null && lib == null && !failed) {
                    return _sticker(null);
                  }
                  if (s == null) return _tile();
                  return _sticker(s);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// builds with the packs. they load once, in a few ms; until then lib is
/// null and failed false
class StickerLibraryBuilder extends StatefulWidget {
  const StickerLibraryBuilder({super.key, required this.builder});
  final Widget Function(StickerLibrary? lib, bool failed) builder;

  @override
  State<StickerLibraryBuilder> createState() => _StickerLibraryBuilderState();
}

class _StickerLibraryBuilderState extends State<StickerLibraryBuilder> {
  StickerLibrary? _lib = StickerLibrary.ready;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (_lib == null) _load();
  }

  Future<void> _load() async {
    try {
      final l = await StickerLibrary.load();
      if (mounted) setState(() => _lib = l);
    } catch (e) {
      dlog('sticker pack: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(_lib, _failed);
}

/// a sticker this version does not have: its emoji if it is one, and words
class StickerPlaceholder extends StatelessWidget {
  const StickerPlaceholder({super.key, required this.emoji});
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final one = isOneEmoji(emoji);
    return Container(
      width: kStickerTile,
      height: kStickerTile,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HaloColors.line2, width: 0.5),
      ),
      // a long translation shrinks rather than spill out of the tile
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: MergeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: stickerSaid(one ? emoji : ''),
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (one) ...[
                        Text(
                          emoji,
                          style: const TextStyle(fontSize: 44, height: 1.1),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        l10n.stickerLabel,
                        style: HaloType.sans(
                          size: 12.5,
                          color: HaloColors.text2,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kStickerTile - 16),
                child: Text(
                  l10n.stickerNewer,
                  textAlign: TextAlign.center,
                  style: HaloType.mono(
                    size: 10,
                    color: HaloColors.text3,
                  ).copyWith(height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// the time and ticks under a sticker, in a pill since there is no bubble to
/// carry them. [alert] (failed, waiting) stands in for all of it.
class StickerStamp extends StatelessWidget {
  const StickerStamp({
    super.key,
    required this.time,
    this.sent = false,
    this.delivered,
    this.burn,
    this.alert,
    this.alertColor,
  });

  final String time;
  final bool sent;
  // the delivered word, once it is
  final String? delivered;
  // what is left of a timed message
  final String? burn;
  final String? alert;
  final Color? alertColor;

  @override
  Widget build(BuildContext context) {
    final style = HaloType.mono(size: 10, color: HaloColors.text2, letter: 0.3);
    final alert = this.alert;
    final burn = this.burn;
    final delivered = this.delivered;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: HaloColors.surface2.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alert != null)
            Flexible(
              child: Text(
                alert,
                style: style.copyWith(color: alertColor ?? HaloColors.text2),
              ),
            )
          else ...[
            if (burn != null) ...[
              Icon(
                Icons.local_fire_department_outlined,
                size: 11,
                color: HaloColors.amber,
              ),
              const SizedBox(width: 2),
              Text(
                burn,
                style: style.copyWith(
                  color: HaloColors.amber,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(time, style: style),
            if (sent) ...[
              const SizedBox(width: 3),
              Text(
                '✓',
                style: TextStyle(
                  fontSize: 10.5,
                  color: HaloColors.text2,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
            if (delivered != null) ...[
              const SizedBox(width: 4),
              Text(
                delivered,
                style: style.copyWith(fontSize: 9, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// a sticker's still, small: quotes, the reply banner, pins, saved
class StickerThumb extends StatelessWidget {
  const StickerThumb(this.wire, {super.key, this.size = kStickerThumb});
  final StickerWire wire;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: StickerLibraryBuilder(
        builder: (lib, failed) {
          final s = stickerFor(lib, wire);
          if (s != null) {
            return StickerView(sticker: s, size: size, play: false);
          }
          return SizedBox.square(
            dimension: size,
            child: lib == null && !failed
                ? null
                : Center(
                    child: StrokeIcon(
                      stickerGlyph,
                      size: size * 0.8,
                      color: HaloColors.text2,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

/// "Sticker" with its still in front of it
class StickerLine extends StatelessWidget {
  const StickerLine(this.wire, {super.key, required this.style});
  final StickerWire wire;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StickerThumb(wire),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            l10n.stickerLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// the message a sticker replies to, as a card above it: there is no bubble
/// for the quote to sit in
class StickerQuoteCard extends StatelessWidget {
  const StickerQuoteCard({
    super.key,
    this.author,
    required this.text,
    this.sticker,
    this.onTap,
  });

  final String? author;
  final String text;
  // the quoted message is a sticker too
  final StickerWire? sticker;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final author = this.author;
    final sticker = this.sticker;
    final words = HaloType.sans(
      size: 12.5,
      color: HaloColors.text2,
      height: 1.25,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        margin: const EdgeInsets.only(bottom: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: HaloColors.surface2.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10),
        ),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: HaloColors.amber),
              const SizedBox(width: 9),
              Flexible(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(0, 6, 10, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (author != null) ...[
                        Text(
                          author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HaloType.mono(
                            size: 10,
                            color: HaloColors.amber,
                            letter: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      if (sticker != null)
                        StickerLine(sticker, style: words)
                      else
                        Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: words,
                        ),
                    ],
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
