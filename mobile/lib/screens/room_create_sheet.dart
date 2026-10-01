// SPDX-License-Identifier: GPL-3.0-or-later
// make a burner room: a name, how long it lives, whether it has a cap. one
// sheet, one button. the link comes right after.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show appState, AppState;
import '../rooms.dart';
import '../theme.dart';
import '../widgets/notice_banner.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/halo_switch.dart';
import '../widgets/ease_size.dart';
import '../widgets/press_scale.dart';
import '../l10n/l10n.dart';

// returns the new room's group id, or null if the sheet was dismissed
Future<String?> showRoomCreateSheet(BuildContext context) {
  return showHaloSheet<String>(
    context,
    scroll: true,
    builder: (_) => const _RoomCreateSheet(),
  );
}

class _RoomCreateSheet extends StatefulWidget {
  const _RoomCreateSheet();
  @override
  State<_RoomCreateSheet> createState() => _RoomCreateSheetState();
}

class _RoomCreateSheetState extends State<_RoomCreateSheet> {
  final _nameCtrl = TextEditingController();
  Duration _expiry = roomDefaultExpiry;
  bool _capOn = false;
  int _cap = roomDefaultCap;
  bool _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_creating) return;
    HapticFeedback.mediumImpact();
    setState(() => _creating = true);
    try {
      final id = await appState.createRoom(
        _nameCtrl.text,
        expiry: _expiry,
        cap: _capOn ? _cap : null,
      );
      if (mounted) Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      showHaloToast(context, l10n.roomCreateCouldNotCreateThe);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    // the keyboard moves the insets every frame: the sheet rides on it
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              const SizedBox(height: 18),
              Text(
                l10n.roomCreateBurnerRoom,
                style: HaloType.serif(
                  size: 22,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.roomCreateARoomThatEnds,
                style: HaloType.sans(
                  size: 12,
                  color: HaloColors.text2,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                maxLength: 32,
                style: HaloType.sans(size: 16, color: HaloColors.text),
                cursorColor: HaloColors.violet,
                decoration: InputDecoration(
                  hintText: l10n.roomCreateRoomName,
                  hintStyle: HaloType.serif(
                    size: 16,
                    italic: true,
                    color: HaloColors.text3,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: HaloColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.roomCreateEndsAfter,
                style: HaloType.mono(
                  size: 10,
                  color: HaloColors.text3,
                  letter: 0.14,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final d in roomExpiryOptions) ...[
                    _Chip(
                      label: expiryLabel(d),
                      on: _expiry == d,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _expiry = d);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.roomCreateMemberCap,
                          style: HaloType.sans(
                            size: 13,
                            color: HaloColors.text,
                          ),
                        ),
                        Text(
                          _capOn
                              ? l10n.roomCreateNoOnePastThe(_cap)
                              : l10n.roomCreateOffUpTo(
                                  AppState.kGroupMemberCap,
                                ),
                          style: HaloType.mono(
                            size: 9.5,
                            color: HaloColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  HaloSwitch(
                    value: _capOn,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _capOn = v);
                    },
                  ),
                ],
              ),
              EaseSize(
                duration: const Duration(milliseconds: 220),
                child: _capOn
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            for (final n in roomCapOptions) ...[
                              _Chip(
                                label: '$n',
                                on: _cap == n,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _cap = n);
                                },
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              ),
              const SizedBox(height: 14),
              NoticeBanner(
                glyph: NoticeGlyph.clock,
                text: l10n.roomCreateThisRoomAndEverything(
                  expiryWords(_expiry),
                ),
                color: HaloColors.violet,
              ),
              const SizedBox(height: 14),
              _GoButton(
                label: _creating
                    ? l10n.roomCreateCreating
                    : l10n.roomCreateCreateRoom,
                enabled: !_creating,
                onTap: _create,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// a mono chip, the kind timers and counts wear here
class _Chip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        scale: 0.94,
        // the sheet clicks for the pick itself
        haptic: false,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on
                ? HaloColors.violet.withValues(alpha: 0.16)
                : HaloColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: on ? HaloColors.violet : HaloColors.line,
              width: on ? 1 : 0.5,
            ),
          ),
          child: Text(
            label,
            style: HaloType.mono(
              size: 12,
              color: on ? HaloColors.violet : HaloColors.text2,
            ),
          ),
        ),
      ),
    );
  }
}

// the violet button. its words fade over to creating while the room is made
class _GoButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _GoButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: 0.97,
      // the create itself gives the impact
      haptic: false,
      label: label,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? HaloColors.violet : HaloColors.surface3,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            label,
            key: ValueKey(label),
            semanticsLabel: '',
            style: HaloType.sans(
              size: 15,
              weight: FontWeight.w600,
              color: enabled ? HaloColors.ink : HaloColors.text2,
            ),
          ),
        ),
      ),
    );
  }
}
