// SPDX-License-Identifier: GPL-3.0-or-later
// the tray at the foot of the sending sheet: every pick as a card in the
// order chosen, a cross that takes one out, a hold that renames a file, a
// spoiler on a photo, the total and an honest guess of the time it takes
// over tor. cards slide in as they are picked and the rest close up when
// one goes; with reduced motion they simply appear and go
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../file_kind.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart' show whole;
import '../theme.dart';
import '../transfers.dart' show torTimeLine;
import 'file_badge.dart';
import 'file_bubble.dart' show fileNameDir;
import 'media_bubbles.dart' show humanFileSize;
import 'motion.dart' show motionStill;
import 'pictures_gate.dart' show PicturesGate;
import 'press_scale.dart';

/// the house spring with its damping at critical: it settles as fast as
/// the house one, with no swing past the end a card could show
class CalmSpring extends Curve {
  const CalmSpring();
  // how far along the critically damped spring the curve ends
  static const _a = 6.8;
  static final _end = 1 - (1 + _a) * math.exp(-_a);

  @override
  double transformInternal(double t) =>
      (1 - (1 + _a * t) * math.exp(-_a * t)) / _end;
}

const kCalmSpring = CalmSpring();

/// one card of the tray
class TrayCard {
  final Object key;
  final String name;
  final int size;
  // a photo or a video that goes as one: its picture on the card
  final bool photo;
  final bool video;
  final String path;
  final bool spoiler;
  // past what one file may be
  final bool tooBig;
  const TrayCard({
    required this.key,
    required this.name,
    required this.size,
    required this.path,
    this.photo = false,
    this.video = false,
    this.spoiler = false,
    this.tooBig = false,
  });
}

class SendTray extends StatefulWidget {
  /// how long the cards take to lift off when they are sent
  static const liftTime = Duration(milliseconds: 260);

  final List<TrayCard> cards;
  // sent: the cards rise and fade toward the chat as the sheet goes
  final bool lifting;
  // the most one file may be, for the line under the send
  final int most;
  final void Function(Object key) onRemove;
  final void Function(Object key) onRename;
  // null: no phone on the other end blurs a spoiler, so none is offered
  final void Function(Object key)? onSpoiler;
  const SendTray({
    super.key,
    required this.cards,
    required this.most,
    required this.onRemove,
    required this.onRename,
    required this.onSpoiler,
    this.lifting = false,
  });

  @override
  State<SendTray> createState() => _SendTrayState();
}

/// whether the send lane cleans a card's file, read from its bytes as the
/// lane reads it
@visibleForTesting
Future<bool> Function(String path, String name) trayCleans = sendLaneCleans;

class _SendTrayState extends State<SendTray> {
  // cards on their way out, still drawn while they close up
  final Map<Object, TrayCard> _leaving = {};
  // where each card that left stood, so it closes up in its place
  final Map<Object, int> _leftAt = {};
  // what the lane does with each card's file, by its path, once read
  final Map<String, bool> _cleans = {};
  final Set<String> _reading = {};

  @override
  void initState() {
    super.initState();
    _readCleans();
  }

  void _readCleans() {
    for (final c in widget.cards) {
      final k = c.path;
      if (_cleans.containsKey(k) || !_reading.add(k)) continue;
      trayCleans(c.path, c.name).catchError((_) => false).then((v) {
        _reading.remove(k);
        if (mounted) setState(() => _cleans[k] = v);
      });
    }
  }

  // "every file is cleaned" only once each card's bytes said so
  bool get _everyCleaned =>
      widget.cards.isNotEmpty &&
      widget.cards.every((c) => _cleans[c.path] == true);

  @override
  void didUpdateWidget(SendTray old) {
    super.didUpdateWidget(old);
    _readCleans();
    final now = {for (final c in widget.cards) c.key};
    for (final (i, c) in old.cards.indexed) {
      if (!now.contains(c.key) && !_leaving.containsKey(c.key)) {
        _leaving[c.key] = c;
        _leftAt[c.key] = i;
      }
    }
    // a card picked again comes back as new
    _leaving.removeWhere((k, _) => now.contains(k));
  }

  void _gone(Object key) {
    if (!mounted) return;
    setState(() {
      _leaving.remove(key);
      _leftAt.remove(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final drawn = <(TrayCard, bool)>[for (final c in widget.cards) (c, false)];
    if (!still) {
      for (final e in _leaving.entries) {
        drawn.insert((_leftAt[e.key] ?? drawn.length).clamp(0, drawn.length), (
          e.value,
          true,
        ));
      }
    }
    var total = 0;
    for (final c in widget.cards) {
      total += c.size;
    }
    final n = widget.cards.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: l10n.trayToSend(n, whole(n)),
                style: HaloType.sans(
                  size: 14,
                  weight: FontWeight.w600,
                  color: HaloColors.text,
                ),
              ),
              TextSpan(
                text: ' · ${humanFileSize(total)}',
                style: HaloType.mono(size: 11, color: HaloColors.text),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 112,
          child: AnimatedSlide(
            offset: widget.lifting ? const Offset(0, -1.6) : Offset.zero,
            duration: SendTray.liftTime,
            curve: Curves.easeInCubic,
            child: AnimatedScale(
              scale: widget.lifting ? 0.92 : 1,
              duration: SendTray.liftTime,
              curve: Curves.easeInCubic,
              child: AnimatedOpacity(
                opacity: widget.lifting ? 0 : 1,
                duration: SendTray.liftTime,
                curve: const Interval(0.45, 1, curve: Curves.easeIn),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  children: [
                    for (final (c, leaving) in drawn)
                      _Slot(
                        key: ValueKey(c.key),
                        leaving: leaving,
                        onGone: () => _gone(c.key),
                        child: _Card(
                          card: c,
                          onRemove: leaving
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  widget.onRemove(c.key);
                                },
                          onRename: leaving || c.photo || c.video
                              ? null
                              : () => widget.onRename(c.key),
                          onSpoiler:
                              leaving || !c.photo || widget.onSpoiler == null
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  widget.onSpoiler!(c.key);
                                },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: still ? Duration.zero : const Duration(milliseconds: 180),
          layoutBuilder: (now, before) => Stack(
            alignment: AlignmentDirectional.topStart,
            children: [...before, ?now],
          ),
          child: Text(
            _everyCleaned ? l10n.trayHint : l10n.trayHintSome,
            key: ValueKey(_everyCleaned),
            style: HaloType.sans(size: 12.5, color: HaloColors.text),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${torTimeLine(total)} · ${l10n.trayMost(humanFileSize(widget.most))}',
          style: HaloType.mono(size: 10.5, color: HaloColors.text),
        ),
      ],
    );
  }
}

/// a card's place in the row: it opens to its width as it comes, and closes
/// up as it goes so the rest slide over
class _Slot extends StatefulWidget {
  final Widget child;
  final bool leaving;
  final VoidCallback onGone;
  const _Slot({
    super.key,
    required this.child,
    required this.leaving,
    required this.onGone,
  });

  @override
  State<_Slot> createState() => _SlotState();
}

class _SlotState extends State<_Slot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.leaving) {
      _c.value = 1;
      _leave();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.leaving && _c.value == 0 && !_c.isAnimating) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    }
  }

  @override
  void didUpdateWidget(_Slot old) {
    super.didUpdateWidget(old);
    if (widget.leaving && !old.leaving) _leave();
  }

  void _leave() {
    _c.reverse().whenComplete(() {
      if (mounted) widget.onGone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _c,
      curve: kCalmSpring,
      reverseCurve: Curves.easeInCubic,
    );
    return SizeTransition(
      sizeFactor: curve,
      axis: Axis.horizontal,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _c,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(curve),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final TrayCard card;
  final VoidCallback? onRemove;
  final VoidCallback? onRename;
  final VoidCallback? onSpoiler;
  const _Card({
    required this.card,
    required this.onRemove,
    required this.onRename,
    required this.onSpoiler,
  });

  @override
  Widget build(BuildContext context) {
    final c = card;
    final facts = FileFacts(kindOfName(c.name), extOf(safeFileName(c.name)));
    final shown = safeFileName(c.name, facts: facts);
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    final Widget face;
    if (c.photo) {
      face = Stack(
        fit: StackFit.expand,
        children: [
          // a spoiler is blurred here as it will be in the chat
          TweenAnimationBuilder<double>(
            tween: Tween(end: c.spoiler ? 1 : 0),
            duration: motionStill(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            builder: (_, v, img) => v == 0
                ? img!
                : ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: 12 * v,
                      sigmaY: 12 * v,
                      tileMode: TileMode.decal,
                    ),
                    child: img,
                  ),
            child: PicturesGate(
              shut: ColoredBox(color: HaloColors.surface3),
              child: Image.file(
                File(c.path),
                cacheWidth: 200,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: HaloColors.surface3),
              ),
            ),
          ),
          if (c.spoiler)
            ColoredBox(color: HaloColors.ink.withValues(alpha: 0.3)),
          if (onSpoiler != null)
            PositionedDirectional(
              start: 8,
              bottom: 8,
              child: _SpoilerChip(on: c.spoiler, onTap: onSpoiler),
            ),
        ],
      );
    } else {
      face = Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FileBadge(facts: facts, size: 38),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                shown,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: fileNameDir(shown),
                textScaler: scaler,
                style: HaloType.sans(
                  size: 12,
                  weight: FontWeight.w500,
                  color: HaloColors.text,
                ).copyWith(height: 1.25),
              ),
            ),
            Text(
              c.tooBig ? l10n.trayTooBig : humanFileSize(c.size),
              maxLines: 1,
              textScaler: scaler,
              style: HaloType.mono(
                size: 10,
                color: c.tooBig ? HaloColors.roseText : HaloColors.text,
              ),
            ),
          ],
        ),
      );
    }
    return Semantics(
      container: true,
      label: [shown, humanFileSize(c.size)].join(', '),
      hint: onRename == null ? null : l10n.trayRenameHint,
      onLongPress: onRename,
      child: GestureDetector(
        onLongPress: onRename == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onRename!();
              },
        child: Container(
          width: 96,
          height: 112,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: HaloColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: c.tooBig ? HaloColors.rose : HaloColors.line2,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              face,
              PositionedDirectional(
                top: 6,
                end: 6,
                child: Semantics(
                  container: true,
                  button: true,
                  label: l10n.trayRemove(shown),
                  excludeSemantics: true,
                  child: PressScale(
                    scale: 0.85,
                    haptic: false,
                    onTap: onRemove,
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.photo
                            ? const Color(0xBF12100D)
                            : HaloColors.surface3,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: c.photo
                            ? const Color(0xFFF5F1EA)
                            : HaloColors.text,
                      ),
                    ),
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

class _SpoilerChip extends StatelessWidget {
  final bool on;
  final VoidCallback? onTap;
  const _SpoilerChip({required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return Semantics(
      container: true,
      button: true,
      toggled: on,
      label: l10n.traySpoiler,
      excludeSemantics: true,
      child: PressScale(
        scale: 0.92,
        haptic: false,
        onTap: onTap,
        child: AnimatedContainer(
          duration: still ? Duration.zero : const Duration(milliseconds: 180),
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: on ? HaloColors.amber : const Color(0xBF12100D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 12,
                color: on ? HaloColors.onAmber : const Color(0xFFF5F1EA),
              ),
              const SizedBox(width: 4),
              Text(
                l10n.traySpoiler,
                textScaler: TextScaler.noScaling,
                style: HaloType.sans(
                  size: 11,
                  weight: FontWeight.w600,
                  color: on ? HaloColors.onAmber : const Color(0xFFF5F1EA),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
