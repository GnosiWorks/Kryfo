// SPDX-License-Identifier: GPL-3.0-or-later
// files dragged onto a chat's row in the list on a computer: they wait in
// that chat's row above its composer (attach_tray.dart) and the chat opens,
// so nothing goes before the person sees it and presses enter. the row
// lights while files are held over it. the phone gets the row as it is
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lock_state.dart' show lockState;
import '../theme.dart';
import '../widgets/motion.dart' show motionStill;
import 'attach_tray.dart' show DeskTrays;
import 'desktop_mode.dart' show onDesktop;
import 'drag_in.dart' show draggedFiles;

class RowDrop extends StatefulWidget {
  /// the chat's tray key: its container and its peer or group
  final String trayKey;

  /// the most one file may be in this chat
  final Future<int> Function() most;

  /// opens the chat
  final VoidCallback open;
  final Widget child;
  const RowDrop({
    super.key,
    required this.trayKey,
    required this.most,
    required this.open,
    required this.child,
  });

  @override
  State<RowDrop> createState() => _RowDropState();
}

class _RowDropState extends State<RowDrop> {
  bool _over = false;

  Future<void> _drop(List<String> paths) async {
    if (lockState.locked) return;
    final files = draggedFiles(paths);
    if (files.isEmpty) return;
    HapticFeedback.selectionClick();
    await DeskTrays.of(widget.trayKey).add(files, most: widget.most);
    if (!mounted || lockState.locked) return;
    widget.open();
  }

  @override
  Widget build(BuildContext context) {
    if (!onDesktop) return widget.child;
    final still = motionStill(context);
    return DropTarget(
      enabled: !lockState.locked,
      onDrop: (paths) {
        setState(() => _over = false);
        _drop(paths);
      },
      onHover: (on) {
        if (mounted) setState(() => _over = on);
      },
      child: AnimatedContainer(
        duration: still ? Duration.zero : const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _over ? HaloColors.amberSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _over ? HaloColors.amber : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
