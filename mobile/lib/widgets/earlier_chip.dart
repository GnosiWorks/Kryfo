// SPDX-License-Identifier: GPL-3.0-or-later
// a message that came in written well before the bottom of the chat goes
// up the thread, where nobody reading the bottom sees it. a calm line above
// the composer says how many did, and a tap takes the reader to the first
// of them. it goes once each has been on screen
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../read_burn.dart' show rowInView;
import '../theme.dart';
import 'motion.dart';
import 'press_scale.dart';
import 'row_anchor.dart';

/// how far before the bottom of the chat one has to land to be shown
const kEarlierMargin = Duration(minutes: 2);

/// one written at [written] went up the thread from a bottom at [bottom]
bool cameEarlier(int written, int bottom) =>
    written < bottom - kEarlierMargin.inMilliseconds;

/// the rows that came up the thread and were not on screen yet, by their
/// row ids, oldest arrival first
class EarlierArrivals {
  final List<String> _ids = [];

  int get count => _ids.length;
  String? get first => _ids.firstOrNull;

  // false when it was held already
  bool add(String id) {
    if (_ids.contains(id)) return false;
    _ids.add(id);
    return true;
  }

  void drop(String id) => _ids.remove(id);

  void clear() => _ids.clear();

  /// lets go of each one on screen now. true when any went
  bool seenIn(RowAnchors anchors) {
    final before = _ids.length;
    _ids.removeWhere((id) {
      final ctx = anchors.of(id);
      final ro = ctx == null || !ctx.mounted ? null : ctx.findRenderObject();
      return ro is RenderBox && ro.attached && rowInView(ro);
    });
    return _ids.length != before;
  }
}

/// the line itself, at the bottom of the thread. [lifted] while the jump
/// button sits there too, so the two never overlap
class EarlierChip extends StatefulWidget {
  final int count;
  final bool lifted;
  final VoidCallback onTap;
  const EarlierChip({
    super.key,
    required this.count,
    required this.lifted,
    required this.onTap,
  });

  @override
  State<EarlierChip> createState() => _EarlierChipState();
}

class _EarlierChipState extends State<EarlierChip> {
  // the last count shown, kept while the line leaves
  int _shownCount = 0;

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final shown = widget.count > 0;
    if (shown) _shownCount = widget.count;
    final words = l10n.chatEarlierMessagesArrived(_shownCount);
    return AnimatedPadding(
      duration: still ? Duration.zero : kHouseTime,
      curve: kHouseCurve,
      padding: EdgeInsets.only(bottom: widget.lifted ? 60 : 12),
      child: IgnorePointer(
        ignoring: !shown,
        child: AnimatedOpacity(
          opacity: shown ? 1 : 0,
          duration: Duration(milliseconds: shown ? 200 : 140),
          curve: Curves.easeOut,
          child: AnimatedSlide(
            offset: shown || still ? Offset.zero : const Offset(0, 0.4),
            duration: still
                ? Duration.zero
                : shown
                ? kHouseTime
                : const Duration(milliseconds: 160),
            curve: shown ? kHouseCurve : Curves.easeInCubic,
            child: _shownCount == 0
                ? const SizedBox.shrink()
                : PressScale(
                    key: const ValueKey('earlier-chip'),
                    label: words,
                    scale: 0.94,
                    onTap: widget.onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: HaloColors.surface2,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: HaloColors.amber.withValues(alpha: 0.45),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_upward_rounded,
                            size: 13,
                            color: HaloColors.amber,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              words,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HaloType.sans(
                                size: 12.5,
                                color: HaloColors.text,
                                weight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
