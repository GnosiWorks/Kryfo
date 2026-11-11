// SPDX-License-Identifier: GPL-3.0-or-later
// a photo sent as a spoiler: blurred under a quiet veil on both ends until
// it is tapped, then the blur lifts. what was seen is kept for this run
// only, and the lock takes it: after it, every spoiler is blurred again
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../picture_lock.dart' show picturesShut;
import '../theme.dart';
import 'motion.dart' show motionStill;

final Set<String> _seen = {};
bool _watching = false;

/// [uid]'s spoiler was tapped open this run
bool spoilerSeen(String? uid) => uid != null && _seen.contains(uid);

@visibleForTesting
void forgetSpoilersForTest() => _seen.clear();

void _watch() {
  if (_watching) return;
  _watching = true;
  picturesShut.addListener(() {
    if (picturesShut.value) _seen.clear();
  });
}

class SpoilerCover extends StatefulWidget {
  // the message it belongs to: what is kept as seen
  final String? uid;
  final bool on;
  final Widget child;
  // the corners of what it covers
  final BorderRadius radius;
  const SpoilerCover({
    super.key,
    required this.uid,
    required this.on,
    required this.child,
    this.radius = BorderRadius.zero,
  });

  @override
  State<SpoilerCover> createState() => _SpoilerCoverState();
}

class _SpoilerCoverState extends State<SpoilerCover> {
  late bool _hidden = widget.on && !spoilerSeen(widget.uid);

  @override
  void initState() {
    super.initState();
    _watch();
    picturesShut.addListener(_lock);
  }

  @override
  void didUpdateWidget(SpoilerCover old) {
    super.didUpdateWidget(old);
    if (old.uid != widget.uid || old.on != widget.on) {
      _hidden = widget.on && !spoilerSeen(widget.uid);
    }
  }

  @override
  void dispose() {
    picturesShut.removeListener(_lock);
    super.dispose();
  }

  void _lock() {
    if (picturesShut.value && widget.on && mounted) {
      setState(() => _hidden = true);
    }
  }

  void _show() {
    HapticFeedback.lightImpact();
    final u = widget.uid;
    if (u != null) _seen.add(u);
    setState(() => _hidden = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.on) return widget.child;
    final still = motionStill(context);
    final cover = TweenAnimationBuilder<double>(
      tween: Tween(end: _hidden ? 1 : 0),
      duration: still ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Stack(
        fit: StackFit.passthrough,
        children: [
          v == 0
              ? child!
              : ClipRRect(
                  borderRadius: widget.radius,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: 24 * v,
                      sigmaY: 24 * v,
                      tileMode: TileMode.decal,
                    ),
                    child: child,
                  ),
                ),
          if (v > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: v,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x5912100D),
                      borderRadius: widget.radius,
                    ),
                    child: Center(child: _Chip()),
                  ),
                ),
              ),
            ),
        ],
      ),
      child: widget.child,
    );
    if (!_hidden) return cover;
    return Semantics(
      button: true,
      label: l10n.spoilerLabel,
      hint: l10n.spoilerTapToSee,
      excludeSemantics: true,
      onTap: _show,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _show,
        child: cover,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xD112100D),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.visibility_off_rounded,
          size: 14,
          color: Color(0xFFF5F1EA),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            l10n.spoilerTapToSee,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(maxScaleFactor: 1.3),
            style: HaloType.sans(
              size: 12.5,
              weight: FontWeight.w600,
              color: const Color(0xFFF5F1EA),
            ),
          ),
        ),
      ],
    ),
  );
}
