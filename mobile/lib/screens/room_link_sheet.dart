// SPDX-License-Identifier: GPL-3.0-or-later
// the way into a burner room: a qr and a link. anyone holding it can join
// until the room ends, so the sheet says that plainly.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../rooms.dart';
import '../theme.dart';
import '../widgets/room_countdown.dart';

Future<void> showRoomLinkSheet(BuildContext context, RoomLink link) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: HaloColors.surface2,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _RoomLinkSheet(link: link),
  );
}

class _RoomLinkSheet extends StatefulWidget {
  final RoomLink link;
  const _RoomLinkSheet({required this.link});
  @override
  State<_RoomLinkSheet> createState() => _RoomLinkSheetState();
}

class _RoomLinkSheetState extends State<_RoomLinkSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uri = widget.link.encode();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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
              widget.link.name,
              style: HaloType.serif(
                size: 20,
                italic: true,
                color: HaloColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'ends in ',
                  style: HaloType.mono(size: 10, color: HaloColors.text3),
                ),
                RoomCountdown(expiresAt: widget.link.expiresAt, size: 10),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: ScaleTransition(
                scale: CurvedAnimation(parent: _in, curve: Curves.easeOutBack),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HaloColors.text,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: uri,
                    version: QrVersions.auto,
                    size: 208,
                    backgroundColor: HaloColors.text,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: HaloColors.ink,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: HaloColors.ink,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'anyone with this can join until the room ends. they come in '
              'under a key made for this room, and see nothing sent before '
              'they arrived.',
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 12,
                color: HaloColors.text2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _CopyButton(
              onTap: () {
                copySensitive(uri);
                HapticFeedback.selectionClick();
                showHaloToast(context, 'room link copied');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CopyButton({required this.onTap});
  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HaloColors.violet,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'copy room link',
            style: HaloType.sans(
              size: 14,
              weight: FontWeight.w600,
              color: HaloColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
