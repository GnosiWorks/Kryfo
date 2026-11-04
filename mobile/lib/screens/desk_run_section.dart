// SPDX-License-Identifier: GPL-3.0-or-later
// the computer's part of getting messages, where the phone has its delivery
// modes and battery tips: keep running in the tray, start with the computer
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../desktop/desktop_mode.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/halo_rows.dart' show HaloGroup, HaloRow;
import '../widgets/swap.dart' show RiseSwap;
import '../widgets/unfold.dart';

class DeskRunSection extends StatefulWidget {
  const DeskRunSection({super.key, required this.run, this.edge = 16});
  final DesktopRunView run;

  /// the room on each side
  final double edge;

  @override
  State<DeskRunSection> createState() => _DeskRunSectionState();
}

class _DeskRunSectionState extends State<DeskRunSection> {
  // a switch moves as it is clicked, and goes back if the computer says no
  bool? _trayTo;
  bool? _startTo;

  @override
  void initState() {
    super.initState();
    widget.run.addListener(_changed);
    unawaited(widget.run.refresh());
  }

  @override
  void dispose() {
    widget.run.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _tray() async {
    if (_trayTo != null) return;
    final to = !widget.run.trayOn;
    HapticFeedback.selectionClick();
    setState(() => _trayTo = to);
    try {
      await widget.run.setTray(to);
    } finally {
      if (mounted) setState(() => _trayTo = null);
    }
  }

  Future<void> _start() async {
    final now = widget.run.start;
    if (_startTo != null || now == null) return;
    final to = now == StartAnswer.off;
    HapticFeedback.selectionClick();
    setState(() => _startTo = to);
    try {
      await widget.run.setStart(to);
    } finally {
      if (mounted) setState(() => _startTo = null);
    }
  }

  Widget _line(String? text, {Color? color}) => Unfold(
    open: text != null,
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 0),
      child: RiseSwap(
        child: Text(
          text ?? '',
          key: ValueKey(text),
          style: HaloType.sans(
            size: 12.5,
            height: 1.45,
            color: color ?? HaloColors.warm,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final trayOn = _trayTo ?? run.trayOn;
    final start = run.start;
    final startOn = _startTo ?? start == StartAnswer.on;
    final String? trayLine = !trayOn
        ? l10n.desktopTrayOffLine
        : _trayTo == null && run.trayShown == false
        ? l10n.desktopTrayNoneLine
        : null;
    final String? startLine = _startTo != null
        ? null
        : run.startRefused
        ? l10n.desktopStartRefused
        : start == StartAnswer.heldOff
        ? l10n.desktopStartHeldOff
        : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(widget.edge, 4, widget.edge, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HaloGroup(
            children: [
              HaloRow(
                key: const ValueKey('trayRow'),
                icon: Icons.move_to_inbox_outlined,
                label: l10n.desktopTrayRow,
                hint: l10n.desktopTrayHint,
                toggled: trayOn,
                onTap: _tray,
              ),
              if (run.canStart)
                HaloRow(
                  key: const ValueKey('startRow'),
                  icon: Icons.power_settings_new_rounded,
                  label: l10n.desktopStartRow,
                  hint: l10n.desktopStartHint,
                  toggled: startOn,
                  pending: start == null,
                  onTap: _start,
                ),
            ],
          ),
          _line(trayLine),
          _line(startLine, color: HaloColors.amberText),
        ],
      ),
    );
  }
}
