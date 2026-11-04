// SPDX-License-Identifier: GPL-3.0-or-later
// files dragged onto a chat on a computer. each one goes the way a file
// picked with the paperclip goes: the same checks, the same cleaner and its
// question about a picture it cannot clean, the same copy into the sealed
// media folder. the dropped file itself is only read, never moved or shred
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../l10n/l10n.dart';
import '../l10n/numbers.dart' show whole;
import '../lock_state.dart' show lockState;
import '../theme.dart';
import '../widgets/motion.dart' show motionStill;
import 'desktop_mode.dart' show onDesktop;

/// the most files one drop sends, as the gallery's send preview takes
const kDragInMost = 10;

/// what of a drop can go as files: plain files that are there, in the
/// order dropped. a folder, a link to one, a gone path and a device are
/// left out
List<String> draggedFiles(List<String> paths) => [
  for (final path in paths)
    if (FileSystemEntity.typeSync(path) == FileSystemEntityType.file) path,
];

/// a chat that takes dropped files on a computer. the phone gets [child]
class DragInZone extends StatefulWidget {
  const DragInZone({
    super.key,
    required this.child,
    required this.enabled,
    required this.send,
    required this.couldNotRead,
  });

  final Widget child;

  /// the composer is there: a chat that cannot send takes no drop
  final bool enabled;

  /// one file sent from its path under the name it had, as a pick is
  final Future<void> Function(String path, String name) send;

  /// the chat's own words for a file it could not read
  final String Function() couldNotRead;

  @override
  State<DragInZone> createState() => _DragInZoneState();
}

class _DragInZoneState extends State<DragInZone> {
  bool _over = false;
  bool _sending = false;

  bool get _open => widget.enabled && !_sending && !lockState.locked;

  Future<void> _drop(List<String> paths) async {
    if (!_open) return;
    final files = draggedFiles(paths);
    if (files.isEmpty) {
      showHaloToast(context, widget.couldNotRead());
      return;
    }
    if (files.length > kDragInMost) {
      showHaloToast(context, l10n.mediaSendUpTo(whole(kDragInMost)));
      return;
    }
    // one at a time, each with its own questions, as the picker gives them
    setState(() => _sending = true);
    try {
      for (final f in files) {
        if (!mounted || lockState.locked) break;
        await widget.send(f, p.basename(f));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!onDesktop) return widget.child;
    final still = motionStill(context);
    return DropTarget(
      enabled: _open,
      onDrop: _drop,
      onHover: (on) {
        if (mounted) setState(() => _over = on);
      },
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _over && _open ? 1 : 0,
                duration: Duration(milliseconds: still ? 0 : 150),
                child: const _DropShade(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// the chat under a wash, an accent ring and one line: let go to send
class _DropShade extends StatelessWidget {
  const _DropShade();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('drop-shade'),
    color: HaloColors.surface.withValues(alpha: 0.88),
    padding: const EdgeInsets.all(16),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HaloColors.amber, width: 1.5),
        color: HaloColors.amberSoft,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.file_download_outlined,
              size: 36,
              color: HaloColors.amber,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.chatDropHereToSend,
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 16,
                weight: FontWeight.w600,
                color: HaloColors.text,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
