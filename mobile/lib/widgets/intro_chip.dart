// SPDX-License-Identifier: GPL-3.0-or-later
// "introduced by alice and bob" - the amber chip on a request row that our
// contacts vouched for. the face is the first voucher's, the names are what
// we call them locally, the check means we verified that one. pops in a beat
// after the row so it reads as a second thought, not part of the card.
import 'package:flutter/material.dart';
import '../theme.dart';
import 'kryfo_avatar.dart';

class IntroducedBy extends StatefulWidget {
  // the whole line, already phrased ("introduced by alice and 2 others")
  final String label;
  final String seed;
  final int? avatar;
  final bool verified;
  final Duration delay;
  final double size;
  const IntroducedBy({
    super.key,
    required this.label,
    required this.seed,
    this.avatar,
    this.verified = false,
    this.delay = Duration.zero,
    this.size = 12,
  });

  @override
  State<IntroducedBy> createState() => _IntroducedByState();
}

class _IntroducedByState extends State<IntroducedBy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _pop.forward();
    });
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final face = widget.size * 1.5;
    final scale = CurvedAnimation(parent: _pop, curve: Curves.easeOutBack);
    final fade = CurvedAnimation(
      parent: _pop,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: scale,
        alignment: Alignment.centerLeft,
        child: Container(
          padding: EdgeInsets.fromLTRB(3, 3, widget.size * 0.8, 3),
          decoration: BoxDecoration(
            color: HaloColors.amberSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: HaloColors.amber.withValues(alpha: 0.35),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              KryfoAvatar(seed: widget.seed, size: face, choice: widget.avatar),
              SizedBox(width: widget.size * 0.5),
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HaloType.sans(
                    size: widget.size,
                    weight: FontWeight.w500,
                    color: HaloColors.amber,
                    height: 1.2,
                  ),
                ),
              ),
              if (widget.verified) ...[
                SizedBox(width: widget.size * 0.3),
                Icon(
                  Icons.check_rounded,
                  size: widget.size + 1,
                  color: HaloColors.green,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
