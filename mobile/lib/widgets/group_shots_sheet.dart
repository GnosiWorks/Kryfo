// SPDX-License-Identifier: GPL-3.0-or-later
// the admin's list of members whose app cannot block screenshots in groups
// yet. it follows the group while open: someone who updates folds away,
// and once nobody is left it closes. a tap on someone hands them back for
// the remove confirm
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import 'burn_fade.dart' show FadeFold;
import 'halo_sheet.dart';
import 'kryfo_avatar.dart';
import 'press_scale.dart';
import 'row_motion.dart';
import 'sheet_handle.dart';
import 'stagger_in.dart';

/// one member the group waits for
class ShotsWaiter {
  const ShotsWaiter({
    required this.id,
    required this.name,
    this.face,
    this.named = false,
    this.blocked = false,
  });
  final String id;
  final String name;
  final int? face;
  // [name] is your name for them, not their id
  final bool named;
  // blocked by this phone: nothing of theirs comes in, a word of theirs
  // neither
  final bool blocked;
}

/// the list, as [waiting] says it while the sheet is open. the id of the
/// one tapped, or null
Future<String?> showShotsWaiting(
  BuildContext context,
  ValueListenable<List<ShotsWaiter>> waiting,
) => showHaloSheet<String>(
  context,
  scroll: true,
  builder: (_) => _ShotsWaitingSheet(waiting: waiting),
);

class _ShotsWaitingSheet extends StatefulWidget {
  const _ShotsWaitingSheet({required this.waiting});
  final ValueListenable<List<ShotsWaiter>> waiting;

  @override
  State<_ShotsWaitingSheet> createState() => _ShotsWaitingSheetState();
}

class _ShotsWaitingSheetState extends State<_ShotsWaitingSheet> {
  late final RowSet<ShotsWaiter> _rows = RowSet(
    keyOf: (w) => w.id,
    onGone: () {
      if (mounted) setState(() {});
    },
  );
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _rows.start(widget.waiting.value);
    widget.waiting.addListener(_moved);
  }

  @override
  void dispose() {
    widget.waiting.removeListener(_moved);
    _rows.dispose();
    super.dispose();
  }

  void _moved() {
    if (!mounted) return;
    final now = widget.waiting.value;
    setState(() => _rows.update(now));
    // the last one updated: nothing left to wait for
    if (now.isEmpty && !_closing) {
      _closing = true;
      Future.delayed(const Duration(milliseconds: 420), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows.rows;
    WidgetsBinding.instance.addPostFrameCallback((_) => _rows.built());
    final maxH = MediaQuery.sizeOf(context).height * 0.82;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 4),
            child: Semantics(
              header: true,
              child: Text(
                l10n.groupShotsWaitingTitle,
                style: HaloType.serif(
                  size: 18,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 2, 20, 8),
            child: Text(
              l10n.groupShotsWaitingHint,
              style: HaloType.sans(
                size: 13,
                color: HaloColors.text2,
                height: 1.4,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(
                0,
                4,
                0,
                14 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                for (final (i, w) in rows.indexed)
                  IgnorePointer(
                    key: ValueKey(w.id),
                    ignoring: _rows.leaving(w),
                    child: FadeFold(
                      leaving: _rows.leaving(w),
                      child: StaggerIn(index: i, child: _row(w)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(ShotsWaiter w) {
    final line = w.blocked
        ? l10n.groupShotsBlockedByYou
        : l10n.groupShotsNeedsUpdate;
    void tap() {
      HapticFeedback.selectionClick();
      Navigator.of(context).pop(w.id);
    }

    return Semantics(
      button: true,
      label: '${w.name}, $line',
      tooltip: l10n.groupInfoRemoveFromGroup,
      excludeSemantics: true,
      onTap: tap,
      child: PressScale(
        scale: 0.98,
        haptic: false,
        onTap: tap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 9, 14, 9),
          child: Row(
            children: [
              KryfoAvatar(seed: w.id, size: 38, choice: w.face),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: w.named
                          ? HaloType.sans(
                              size: 14,
                              weight: FontWeight.w500,
                              color: HaloColors.text,
                            )
                          : HaloType.mono(
                              size: 12,
                              weight: FontWeight.w500,
                              color: HaloColors.text,
                            ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line,
                      style: HaloType.sans(
                        size: 12.5,
                        color: w.blocked
                            ? HaloColors.roseText
                            : HaloColors.text2,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.remove_circle_outline,
                size: 18,
                color: HaloColors.text3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
