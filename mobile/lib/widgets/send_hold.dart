// SPDX-License-Identifier: GPL-3.0-or-later
// holding send lifts a small card over it: "Send without sound". letting go
// on the row sends that way, so does a tap on it; a tap anywhere else puts
// it away. a right click on a computer opens the same card. the button
// dips while held
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import 'motion.dart' show kHouseCurve, kHouseTime, motionStill;

class SendHold extends StatefulWidget {
  // the send button itself, which keeps its own tap
  final Widget child;
  // null while there is nothing to send: no card then
  final VoidCallback? onSilent;
  const SendHold({super.key, required this.child, required this.onSilent});

  @override
  State<SendHold> createState() => _SendHoldState();
}

class _SendHoldState extends State<SendHold> {
  OverlayEntry? _card;
  final _row = GlobalKey();
  final _over = ValueNotifier<bool>(false);
  bool _held = false;

  @override
  void dispose() {
    _close();
    _over.dispose();
    super.dispose();
  }

  void _close() {
    _card?.remove();
    _card = null;
    _over.value = false;
  }

  void _open() {
    if (widget.onSilent == null || _card != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final box = context.findRenderObject() as RenderBox?;
    if (overlay == null || box == null || !box.hasSize) return;
    HapticFeedback.mediumImpact();
    final at = box.localToGlobal(
      Offset.zero,
      ancestor: overlay.context.findRenderObject(),
    );
    final size = box.size;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final screen = (overlay.context.findRenderObject() as RenderBox).size;
    _card = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // a tap anywhere else puts it away
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            bottom: screen.height - at.dy + 8,
            right: rtl ? null : screen.width - at.dx - size.width,
            left: rtl ? at.dx : null,
            child: _Card(rowKey: _row, over: _over, rtl: rtl, onPick: _pick),
          ),
        ],
      ),
    );
    overlay.insert(_card!);
  }

  void _pick() {
    final go = widget.onSilent;
    _close();
    if (go == null) return;
    HapticFeedback.lightImpact();
    go();
  }

  bool _onRow(Offset global) {
    final r = _row.currentContext?.findRenderObject() as RenderBox?;
    if (r == null || !r.hasSize) return false;
    final local = r.globalToLocal(global);
    return (Offset.zero & r.size).contains(local);
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.onSilent != null;
    final still = motionStill(context);
    return Semantics(
      onLongPressHint: on ? l10n.composerSendHoldHint : null,
      onLongPress: on ? _open : null,
      child: GestureDetector(
        onLongPressStart: on
            ? (_) {
                setState(() => _held = true);
                _open();
              }
            : null,
        onLongPressMoveUpdate: on
            ? (d) => _over.value = _onRow(d.globalPosition)
            : null,
        onLongPressEnd: on
            ? (d) {
                setState(() => _held = false);
                if (_onRow(d.globalPosition)) _pick();
              }
            : null,
        onLongPressCancel: () => setState(() => _held = false),
        // a computer: a right click opens the same card
        onSecondaryTap: on ? _open : null,
        child: AnimatedScale(
          duration: still ? Duration.zero : const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          scale: _held ? 0.94 : 1,
          child: widget.child,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final GlobalKey rowKey;
  final ValueNotifier<bool> over;
  final bool rtl;
  final VoidCallback onPick;
  const _Card({
    required this.rowKey,
    required this.over,
    required this.rtl,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final card = Material(
      type: MaterialType.transparency,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HaloColors.line2, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: HaloColors.ink.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ValueListenableBuilder<bool>(
          valueListenable: over,
          builder: (context, lit, _) => InkWell(
            key: rowKey,
            borderRadius: BorderRadius.circular(10),
            onTap: onPick,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 14, 10),
              decoration: BoxDecoration(
                color: lit
                    ? HaloColors.amber.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 18,
                    color: HaloColors.amberText,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      l10n.composerSendSilent,
                      maxLines: 2,
                      style: HaloType.sans(
                        size: 14,
                        weight: FontWeight.w500,
                        color: HaloColors.text,
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
    // it rises a little and grows from 0.92 with the house spring, from the
    // button's corner; with reduced motion it only fades
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: still ? const Duration(milliseconds: 120) : kHouseTime,
      curve: still ? Curves.easeOut : kHouseCurve,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: still
            ? child
            : Transform.translate(
                offset: Offset(0, 8 * (1 - t)),
                child: Transform.scale(
                  scale: 0.92 + 0.08 * t,
                  alignment: rtl ? Alignment.bottomLeft : Alignment.bottomRight,
                  child: child,
                ),
              ),
      ),
      child: card,
    );
  }
}
