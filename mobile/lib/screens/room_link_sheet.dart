// SPDX-License-Identifier: GPL-3.0-or-later
// the way into a burner room: a qr and a link. anyone holding it can join
// until the room ends, so the sheet says that plainly.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../rooms.dart';
import '../theme.dart';
import '../widgets/room_countdown.dart';
import '../dlog.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/sheet_handle.dart';
import 'package:share_plus/share_plus.dart';
import '../lock_state.dart';
import '../main.dart' show appState, db;
import '../widgets/motion.dart';
import '../widgets/kryfo_avatar.dart';
import 'chat_screen.dart';

Future<void> showRoomLinkSheet(BuildContext context, RoomLink link) {
  return showHaloSheet<void>(
    context,
    scroll: true,
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
    // debug builds only: lets a second device join off logcat while testing
    dlog('room link: ${widget.link.encode()}');
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  // to someone already in kryfo: their chat opens with the link in the
  // box, and it goes when you press send. said plainly first, because a
  // room is where nobody knows who anyone is, and this is the exception.
  Future<void> _toContact(String uri) async {
    final contacts = appState.contacts.where((c) => !c.blocked).toList();
    final nav = Navigator.of(context);
    final who = await showHaloSheet<String>(
      context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: SheetHandle()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Send the room to',
                style: HaloType.serif(size: 19, color: HaloColors.text),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'They will know this room came from you. Inside it they are '
                'a key like everyone else.',
                style: HaloType.sans(
                  size: 12.5,
                  color: HaloColors.text2,
                  height: 1.45,
                ),
              ),
            ),
            if (contacts.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
                child: Text(
                  'No contacts yet',
                  style: HaloType.sans(size: 13, color: HaloColors.text2),
                ),
              )
            else
              for (final c in contacts)
                InkWell(
                  onTap: () => Navigator.pop(ctx, c.haloId),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        KryfoAvatar(
                          seed: c.avatarSeed,
                          size: 32,
                          choice: c.avatar,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            c.nickname ?? c.haloId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HaloType.sans(
                              size: 14,
                              weight: FontWeight.w500,
                              color: HaloColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (who == null) return;
    final row = await db.getContact(who);
    if (row == null) return;
    nav.pop(); // the link sheet
    nav.push(
      haloRoute(
        ChatScreen(
          peerHaloId: who,
          peerOnion: (row['onion'] as String?) ?? '',
          peerXPub: (row['xpub'] as String?) ?? '',
          avatarSeed: who,
          avatarChoice: (row['avatar'] as num?)?.toInt(),
          initialText: uri,
        ),
      ),
    );
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
            const SheetHandle(),
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
                if (DateTime.now().millisecondsSinceEpoch <
                    widget.link.expiresAt)
                  Text(
                    'Ends in ',
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
              'Anyone with this can join until the room ends. They come in '
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
                showHaloToast(context, 'Room link copied');
              },
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Quiet(
                  label: 'Send to a contact',
                  onTap: () => _toContact(uri),
                ),
                const SizedBox(width: 18),
                _Quiet(
                  label: 'Share',
                  onTap: () => lockState.hold(
                    () => SharePlus.instance.share(ShareParams(text: uri)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Quiet extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Quiet({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      child: Text(
        label,
        style: HaloType.sans(
          size: 13,
          weight: FontWeight.w600,
          color: HaloColors.violet,
        ),
      ),
    ),
  );
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
            'Copy room link',
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
