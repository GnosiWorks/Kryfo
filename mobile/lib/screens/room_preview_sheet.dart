// SPDX-License-Identifier: GPL-3.0-or-later
// a room link before it is joined: what the link itself says and nothing
// more. the name, that it is a burner room, how long it has left. the sheet
// sends and asks nothing, so a link opened and put away left no trace
// anywhere. the join is the caller's, after join
import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../l10n/marked.dart';
import '../lock_guard.dart';
import '../rooms.dart';
import '../theme.dart';
import '../widgets/confirm_sheet.dart' show ShutOnLock;
import '../widgets/ease_size.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/motion.dart' show motionStill;
import '../widgets/press_scale.dart';
import '../widgets/room_countdown.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/swap.dart';

/// true only when they tapped join. a room that has closed has no join,
/// nor one [ended] before its time.
/// with [shutOnLock] the sheet goes as that lock comes up, and that is a no
Future<bool> showRoomPreviewSheet(
  BuildContext context,
  RoomLink link, {
  LockGuard? shutOnLock,
  bool ended = false,
}) async {
  final r = await showHaloSheet<bool>(
    context,
    builder: (ctx) {
      final body = _RoomPreview(link: link, ended: ended);
      return shutOnLock == null
          ? body
          : ShutOnLock(guard: shutOnLock, child: body);
    },
  );
  return r == true;
}

class _RoomPreview extends StatefulWidget {
  final RoomLink link;
  final bool ended;
  const _RoomPreview({required this.link, this.ended = false});
  @override
  State<_RoomPreview> createState() => _RoomPreviewState();
}

class _RoomPreviewState extends State<_RoomPreview> {
  // the room closing while the sheet is up takes the join away
  Timer? _end;
  late bool _closed = widget.ended || _left <= Duration.zero;

  Duration get _left => Duration(
    milliseconds: widget.link.expiresAt - DateTime.now().millisecondsSinceEpoch,
  );

  @override
  void initState() {
    super.initState();
    if (!_closed) {
      _end = Timer(_left, () {
        if (mounted) setState(() => _closed = true);
      });
    }
  }

  @override
  void dispose() {
    _end?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 20),
            Center(child: _Tile(name: link.name)),
            const SizedBox(height: 14),
            Text(
              link.name,
              textDirection: writtenDir(link.name),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: HaloType.serif(size: 21, color: HaloColors.text),
            ),
            const SizedBox(height: 8),
            // every room link carries its end: every room is a burner room
            const Center(child: _BurnerChip()),
            const SizedBox(height: 10),
            EaseSize(
              child: RiseSwap(
                alignment: Alignment.center,
                child: _closed
                    ? _Closed(key: const ValueKey('closed'))
                    : _Open(key: const ValueKey('open'), link: link),
              ),
            ),
            const SizedBox(height: 18),
            if (_closed)
              _Button(
                label: l10n.appOk,
                filled: false,
                onTap: () => Navigator.pop(context, false),
              )
            else ...[
              _Button(
                label: l10n.kryfoLinkTextJoin2,
                filled: true,
                onTap: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 4),
              PressScale(
                scale: 0.96,
                onTap: () => Navigator.pop(context, false),
                // a full finger's height, like the join above it
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Center(
                    child: Text(
                      l10n.kryfoLinkTextNotNow,
                      style: HaloType.sans(size: 13, color: HaloColors.text2),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// the room's letter on the violet tile rooms wear in the chat list. it
// settles in once as the sheet comes up
class _Tile extends StatelessWidget {
  final String name;
  const _Tile({required this.name});
  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HaloColors.violet.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: HaloColors.violet.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        name.isEmpty ? '·' : name.characters.first.toUpperCase(),
        semanticsLabel: '',
        style: HaloType.serif(size: 30, italic: true, color: HaloColors.violet),
      ),
    );
    if (motionStill(context)) return tile;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.86, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: tile,
    );
  }
}

class _BurnerChip extends StatelessWidget {
  const _BurnerChip();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: HaloColors.violet.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      l10n.kryfoLinkTextBurnerRoom,
      style: HaloType.mono(size: 10, color: HaloColors.violet, letter: 0.3),
    ),
  );
}

class _Open extends StatelessWidget {
  final RoomLink link;
  const _Open({super.key, required this.link});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Center(
        child: SlotLine(
          msg: l10n.kryfoLinkTextClosesIn,
          slot: RoomCountdown(expiresAt: link.expiresAt, size: 11),
          style: HaloType.mono(size: 11, color: HaloColors.text2),
        ),
      ),
      const SizedBox(height: 14),
      Text(
        l10n.kryfoLinkTextYouJoinUnderA,
        textAlign: TextAlign.center,
        style: HaloType.sans(size: 13, color: HaloColors.text2, height: 1.45),
      ),
    ],
  );
}

class _Closed extends StatelessWidget {
  const _Closed({super.key});
  @override
  Widget build(BuildContext context) => Text(
    l10n.kryfoLinkTextThisRoomHasClosed,
    textAlign: TextAlign.center,
    style: HaloType.sans(size: 13.5, color: HaloColors.rose),
  );
}

// violet for the join, an outline for the ok of a closed room
class _Button extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _Button({
    required this.label,
    required this.filled,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => PressScale(
    scale: 0.97,
    label: label,
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? HaloColors.violet : null,
        borderRadius: BorderRadius.circular(14),
        border: filled ? null : Border.all(color: HaloColors.line2),
      ),
      child: Text(
        label,
        semanticsLabel: '',
        textAlign: TextAlign.center,
        style: HaloType.sans(
          size: 15,
          weight: FontWeight.w600,
          color: filled ? HaloColors.ink : HaloColors.text,
        ),
      ),
    ),
  );
}
