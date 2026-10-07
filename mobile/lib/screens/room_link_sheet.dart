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
import '../main.dart' show appState, session;
import '../widgets/motion.dart';
import '../widgets/kryfo_avatar.dart';
import '../widgets/copied_mark.dart';
import '../widgets/press_scale.dart';
import '../widgets/qr_wipe.dart';
import '../widgets/stagger_in.dart';
import 'chat_screen.dart';
import '../l10n/l10n.dart';
import '../l10n/marked.dart';

Future<void> showRoomLinkSheet(BuildContext context, RoomLink link) {
  // no field in it: the sheet's own ceiling and scrolling are what it needs
  return showHaloSheet<void>(
    context,
    builder: (_) => _RoomLinkSheet(link: link),
  );
}

class _RoomLinkSheet extends StatefulWidget {
  final RoomLink link;
  const _RoomLinkSheet({required this.link});
  @override
  State<_RoomLinkSheet> createState() => _RoomLinkSheetState();
}

class _RoomLinkSheetState extends State<_RoomLinkSheet> {
  // bumped on each copy, for the tick on the button
  int _copies = 0;

  @override
  void initState() {
    super.initState();
    // debug builds only: lets a second device join off logcat while testing
    dlog('room link: ${widget.link.encode()}');
  }

  // to someone already in kryfo: their chat opens with the link in the box.
  // said plainly first, since in a room nobody knows who anyone is and this
  // is the exception.
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
                l10n.roomLinkSendTheRoomTo,
                style: HaloType.serif(size: 19, color: HaloColors.text),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                l10n.roomLinkTheyWillKnowThis,
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
                  l10n.roomLinkNoContactsYet,
                  style: HaloType.sans(size: 13, color: HaloColors.text2),
                ),
              )
            else
              for (final (i, c) in contacts.indexed)
                StaggerIn(
                  index: i,
                  child: PressScale(
                    scale: 0.98,
                    label: c.nickname ?? c.haloId,
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
                              semanticsLabel: '',
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
                ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (who == null) return;
    final row = await session.getContact(who);
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
            DateTime.now().millisecondsSinceEpoch < widget.link.expiresAt
                ? SlotLine(
                    msg: l10n.roomLinkEndsIn,
                    slot: RoomCountdown(
                      expiresAt: widget.link.expiresAt,
                      size: 10,
                    ),
                    style: HaloType.mono(size: 10, color: HaloColors.text3),
                  )
                : Row(
                    children: [
                      RoomCountdown(expiresAt: widget.link.expiresAt, size: 10),
                    ],
                  ),
            const SizedBox(height: 18),
            // the code assembles corner to corner once the sheet is up
            Center(
              child: QrWipe(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  // dark on light in both themes: some scanners refuse
                  // an inverted code
                  decoration: BoxDecoration(
                    color: HaloColors.qrPaper,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: uri,
                    version: QrVersions.auto,
                    size: 208,
                    backgroundColor: HaloColors.qrPaper,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: HaloColors.qrInk,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: HaloColors.qrInk,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.roomLinkAnyoneWithThisCan,
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 12,
                color: HaloColors.text2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _CopyButton(
              copies: _copies,
              onTap: () {
                copySensitive(uri);
                HapticFeedback.selectionClick();
                setState(() => _copies++);
                showHaloToast(context, l10n.roomLinkRoomLinkCopied);
              },
            ),
            const SizedBox(height: 4),
            // wraps rather than overflows in a long language
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              children: [
                _Quiet(
                  label: l10n.roomLinkSendToAContact,
                  onTap: () => _toContact(uri),
                ),
                _Quiet(
                  label: l10n.commonShare,
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
  Widget build(BuildContext context) => PressScale(
    label: label,
    scale: 0.94,
    haptic: false,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      child: Text(
        label,
        semanticsLabel: '',
        style: HaloType.sans(
          size: 13,
          weight: FontWeight.w600,
          color: HaloColors.violet,
        ),
      ),
    ),
  );
}

// the one violet button: a tick takes the copy glyph's place for a moment
// after each copy
class _CopyButton extends StatelessWidget {
  final int copies;
  final VoidCallback onTap;
  const _CopyButton({required this.copies, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return PressScale(
      label: l10n.roomLinkCopyRoomLink,
      scale: 0.97,
      haptic: false,
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HaloColors.violet,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CopiedMark(
              copies: copies,
              size: 15,
              color: HaloColors.ink,
              done: HaloColors.ink,
            ),
            const SizedBox(width: 6),
            Text(
              l10n.roomLinkCopyRoomLink,
              semanticsLabel: '',
              style: HaloType.sans(
                size: 14,
                weight: FontWeight.w600,
                color: HaloColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
