// SPDX-License-Identifier: GPL-3.0-or-later
// after automatic found no way in: the tor project's own ways to a private
// bridge, each one copied in a tap, over the box it gets pasted into
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../open_outside.dart';
import '../theme.dart';
import '../widgets/ease_size.dart';
import '../widgets/motion.dart' show motionStill;
import '../widgets/press_scale.dart';
import '../widgets/swap.dart';

const kGetBridgesBot = '@GetBridgesBot';
const kBridgesSite = 'bridges.torproject.org';
const kBridgesMail = 'bridges@torproject.org';

/// the hint while automatic has failed, nothing otherwise. eases in and
/// out as the status changes under it
class PrivateBridgeHint extends StatelessWidget {
  const PrivateBridgeHint({super.key, required this.show});
  final bool show;

  @override
  Widget build(BuildContext context) => EaseSize(
    child: RiseSwap(
      alignment: Alignment.topCenter,
      child: show
          ? const Padding(
              key: ValueKey('privateBridgeHint'),
              padding: EdgeInsets.only(bottom: 14),
              child: _HintBox(),
            )
          : const SizedBox(key: ValueKey('noHint'), width: double.infinity),
    ),
  );
}

class _HintBox extends StatelessWidget {
  const _HintBox();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 6),
    decoration: BoxDecoration(
      color: HaloColors.violet.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: HaloColors.violet.withValues(alpha: 0.28)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8, bottom: 4),
          child: Text(
            l10n.bridgesPrivateHint,
            style: HaloType.sans(
              size: 13.5,
              color: HaloColors.text,
              height: 1.45,
            ),
          ),
        ),
        const _HintRow(label: 'Telegram', value: kGetBridgesBot),
        _HintRow(
          label: l10n.bridgesPrivateWebsite,
          value: kBridgesSite,
          link: Uri.https(kBridgesSite, '/'),
        ),
        _HintRow(
          label: l10n.bridgesPrivateEmail,
          value: kBridgesMail,
          note: l10n.bridgesPrivateEmailFrom,
        ),
      ],
    ),
  );
}

class _HintRow extends StatefulWidget {
  const _HintRow({
    required this.label,
    required this.value,
    this.link,
    this.note,
  });
  final String label;
  final String value;
  // the value opens this in the browser
  final Uri? link;
  final String? note;

  @override
  State<_HintRow> createState() => _HintRowState();
}

class _HintRowState extends State<_HintRow> {
  bool _copied = false;
  Timer? _back;

  @override
  void dispose() {
    _back?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    HapticFeedback.selectionClick();
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    setState(() => _copied = true);
    showHaloToast(context, l10n.bridgesPrivateCopied(widget.value));
    _back?.cancel();
    _back = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _open() async {
    final u = widget.link;
    if (u == null) return;
    HapticFeedback.selectionClick();
    await openOutside(u);
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.link != null;
    // an address reads left to right in any language
    final value = Text(
      widget.value,
      textDirection: TextDirection.ltr,
      style: HaloType.mono(
        size: 12.5,
        weight: FontWeight.w600,
        color: link ? HaloColors.violetText : HaloColors.text,
      ).copyWith(decoration: link ? TextDecoration.underline : null),
    );
    final still = motionStill(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: HaloType.sans(
                    size: 12,
                    weight: FontWeight.w600,
                    color: HaloColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                link
                    ? PressScale(
                        scale: 0.97,
                        onTap: _open,
                        label: l10n.bridgesPrivateOpen(widget.value),
                        child: ExcludeSemantics(child: value),
                      )
                    : value,
                if (widget.note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      widget.note!,
                      style: HaloType.sans(
                        size: 12,
                        color: HaloColors.text,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _copy,
            tooltip: l10n.bridgesPrivateCopy(widget.value),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: AnimatedSwitcher(
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(scale: a, child: c),
              ),
              child: Icon(
                _copied ? Icons.check_rounded : Icons.content_copy_rounded,
                key: ValueKey(_copied),
                size: 18,
                color: _copied ? HaloColors.green : HaloColors.violet,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
