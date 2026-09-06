// SPDX-License-Identifier: GPL-3.0-or-later
// make a burner room: a name, how long it lives, whether it has a cap. one
// sheet, one button. the link comes right after.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show appState;
import '../rooms.dart';
import '../theme.dart';
import '../widgets/notice_banner.dart';

// returns the new room's group id, or null if the sheet was dismissed
Future<String?> showRoomCreateSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HaloColors.surface2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
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
      showHaloToast(context, 'could not create the room');
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: insets),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HaloColors.line2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'burner room',
                style: HaloType.serif(
                  size: 22,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'a room that ends. everyone joins under a key made for it, '
                'and when it ends nothing is left on any phone.',
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
                  hintText: 'room name',
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
                'ends after',
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
                          'member cap',
                          style: HaloType.sans(
                            size: 13,
                            color: HaloColors.text,
                          ),
                        ),
                        Text(
                          _capOn
                              ? 'no one past the first $_cap'
                              : 'off. anyone with the link',
                          style: HaloType.mono(
                            size: 9.5,
                            color: HaloColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _capOn,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _capOn = v);
                    },
                    activeThumbColor: HaloColors.ink,
                    activeTrackColor: HaloColors.violet,
                    inactiveThumbColor: HaloColors.text3,
                    inactiveTrackColor: HaloColors.surface3,
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
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
                text:
                    'this room and everything in it disappears in ${expiryWords(_expiry)}',
                color: HaloColors.violet,
              ),
              const SizedBox(height: 14),
              _GoButton(
                label: _creating ? 'creating...' : 'create room',
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
    return GestureDetector(
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
    );
  }
}

class _GoButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _GoButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });
  @override
  State<_GoButton> createState() => _GoButtonState();
}

class _GoButtonState extends State<_GoButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: widget.enabled ? () => setState(() => _down = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.enabled ? HaloColors.violet : HaloColors.surface3,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            widget.label,
            style: HaloType.sans(
              size: 15,
              weight: FontWeight.w600,
              color: widget.enabled ? HaloColors.ink : HaloColors.text3,
            ),
          ),
        ),
      ),
    );
  }
}
