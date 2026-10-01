// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/breathing_ring.dart';
import '../widgets/burn_fade.dart';
import '../widgets/press_scale.dart';
import '../widgets/swap.dart';
import '../main.dart' hide live;
import '../stickers/sticker_bubble.dart' show StickerLine;
import '../stickers/sticker_wire.dart' show StickerWire;
import '../theme.dart';
import '../devchat/dev_key.dart' show isDevChat;
import '../rooms.dart' show looksLikeRoomKey, roomTag;
import '../widgets/decode_px.dart';
import '../widgets/photo_viewer.dart' show PhotoTileFade;
import 'chat_door.dart';
import '../widgets/motion.dart' show kHouseCurve, motionStill;
import '../widgets/page_head.dart' show PageBar;
import '../widgets/stagger_in.dart';
import '../l10n/l10n.dart';
import '../l10n/dates.dart';

// every saved message across all chats, newest first. tap a card to jump to
// that message in its chat; tap the bookmark to unsave: it empties, and the
// card folds away.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});
  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<Map<String, Object?>> _rows = [];
  Map<String, String> _names = {};
  Map<String, String> _groups = {};
  bool _loaded = false;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await session.savedMessages();
    final cs = await session.contacts();
    final names = <String, String>{};
    for (final c in cs) {
      final id = c['halo_id'] as String;
      names[id] = (c['nickname'] as String?) ?? id;
    }
    // the groups' names, when a group's message is among them
    final inGroups = rows.any((r) => (r['group_id'] as String?) != null);
    final groups = {
      if (inGroups)
        for (final g in await session.loadGroups())
          g['group_id'] as String: (g['name'] as String?) ?? '',
    };
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _names = names;
      _groups = groups;
      _loaded = true;
    });
  }

  // the chat the message was saved in: its group, the developer chat or
  // the person's own, landing on the message
  Future<void> _open(Map<String, Object?> r) async {
    final ok = await openChatAt(
      context,
      groupId: r['group_id'] as String?,
      peer: r['peer_id'] as String?,
      uid: r['msg_uid'] as String?,
    );
    if (!ok && mounted) showHaloToast(context, l10n.savedChatGone);
  }

  String _who(String peer) {
    if (isDevChat(peer)) return l10n.devRowTitle;
    final n = _names[peer];
    if (n != null) return n;
    return looksLikeRoomKey(peer) ? roomTag(peer) : peer;
  }

  // unsaved rows fade and fold (FadeFold) before the list reloads
  final Set<String> _leaving = {};

  Future<void> _unsave(String uid) async {
    if (!_leaving.add(uid)) return;
    HapticFeedback.selectionClick();
    setState(() {});
    await session.setSaved(uid, false);
    await Future.delayed(FadeFold.gone);
    await _load();
    _leaving.remove(uid);
  }

  String _preview(Map<String, Object?> r) {
    if (r['sticker'] != null) return l10n.stickerLabel;
    final fn = r['file_name'] as String?;
    if (fn == 'voice.wav') return l10n.savedVoiceNote;
    if (fn != null) return fn;
    if ((r['media_path'] as String?) != null) return l10n.savedPhoto;
    return (r['plaintext'] as String?) ?? '';
  }

  bool _isVoice(Map<String, Object?> r) => r['file_name'] == 'voice.wav';
  bool _isPhoto(Map<String, Object?> r) =>
      r['file_name'] == null && (r['media_path'] as String?) != null;

  // stable accent per author, same palette as the group roster
  Color _authorColor(String id) {
    final palette = [
      HaloColors.green,
      HaloColors.rose,
      HaloColors.violet,
      HaloColors.amber,
    ];
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return palette[h % palette.length];
  }

  String _time(int ms) {
    if (ms == 0) return '';
    return hourMinute(DateTime.fromMillisecondsSinceEpoch(ms));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            PageBar(title: l10n.savedSaved, controller: _scroll),
            Expanded(
              child: !_loaded
                  ? const SizedBox.shrink()
                  // the last one unsaved, the empty page fades in
                  : FadeSwap(
                      child: _rows.isEmpty
                          ? KeyedSubtree(
                              key: const ValueKey('none'),
                              child: _empty(),
                            )
                          : ListView.builder(
                              key: const ValueKey('cards'),
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: _rows.length,
                              itemBuilder: (_, i) => StaggerIn(
                                key: ValueKey(_rows[i]['msg_uid'] ?? i),
                                index: i,
                                child: FadeFold(
                                  leaving: _leaving.contains(
                                    _rows[i]['msg_uid'],
                                  ),
                                  child: _card(_rows[i]),
                                ),
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: staggerAll([
            BreathingRing(
              size: 98,
              core: 66,
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: HaloColors.amberSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.bookmark_border,
                  color: HaloColors.amber,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.savedNothingSavedYet,
              textAlign: TextAlign.center,
              style: HaloType.serif(size: 24, color: HaloColors.text),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.savedLongPressAnyMessage,
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 12.5,
                color: HaloColors.text2,
                height: 1.55,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _card(Map<String, Object?> r) {
    final peer = r['peer_id'] as String? ?? '';
    final gid = r['group_id'] as String?;
    final group = gid == null || gid.isEmpty ? null : _groups[gid];
    // a group's message names the group too: the sender alone reads as
    // their own chat
    final who = group == null || group.isEmpty
        ? _who(peer)
        : '${_who(peer)} · $group';
    final uid = r['msg_uid'] as String?;
    final ms = r['sent_at'] as int? ?? 0;
    final accent = _authorColor(peer);
    final isVoice = _isVoice(r);
    final isPhoto = _isPhoto(r);
    final sticker = StickerWire.parse(r['sticker']);
    return PressScale(
      onTap: () => _open(r),
      child: Stack(
        children: [
          _cardBody(r, who, ms, accent, isVoice, isPhoto, sticker),
          // a finger's worth around the mark, in the card's corner, so a
          // near miss unsaves rather than opening the chat
          PositionedDirectional(
            top: 0,
            end: 0,
            child: PressScale(
              label: l10n.savedSaved,
              scale: 0.85,
              haptic: false,
              onTap: uid == null ? null : () => _unsave(uid),
              child: SizedBox(
                width: 44,
                height: 40,
                child: Center(child: _Bookmark(on: !_leaving.contains(uid))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardBody(
    Map<String, Object?> r,
    String who,
    int ms,
    Color accent,
    bool isVoice,
    bool isPhoto,
    StickerWire? sticker,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 13, 12),
      decoration: BoxDecoration(
        color: HaloColors.surface3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HaloColors.line2, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  who,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HaloType.mono(size: 10, color: accent),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _time(ms),
                style: HaloType.mono(size: 10, color: HaloColors.text3),
              ),
              const Spacer(),
              // room for the mark, which is drawn over the corner
              const SizedBox(width: 17, height: 17),
            ],
          ),
          const SizedBox(height: 10),
          if (sticker != null)
            StickerLine(
              sticker,
              style: HaloType.sans(size: 14, color: HaloColors.text),
            )
          else if (isVoice)
            _mediaRow(Icons.graphic_eq, l10n.savedVoiceNote)
          else if (isPhoto)
            _photoRow(r)
          else
            Text(
              _preview(r),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              // in the direction it was written, as in its chat
              textDirection: writtenDir(_preview(r)),
              textAlign: startOf(context),
              style: HaloType.sans(
                size: 14,
                color: HaloColors.text,
                height: 1.45,
              ),
            ),
          const SizedBox(height: 11),
          Row(
            children: [
              Icon(
                Icons.subdirectory_arrow_right,
                size: 12,
                color: HaloColors.text3,
              ),
              const SizedBox(width: 5),
              Text(
                l10n.savedViewInChat,
                style: HaloType.mono(size: 10, color: HaloColors.text3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mediaRow(IconData glyph, String label) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: HaloColors.amberSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(glyph, size: 15, color: HaloColors.amber),
      ),
      const SizedBox(width: 9),
      Text(
        label,
        style: HaloType.serif(size: 14, color: HaloColors.text2, italic: true),
      ),
    ],
  );

  // the photo itself, fading up once decoded, and its caption beside it
  Widget _photoRow(Map<String, Object?> r) {
    final caption = ((r['plaintext'] as String?) ?? '').trim();
    final missing = Container(
      width: 44,
      height: 44,
      color: HaloColors.surface2,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, size: 18, color: HaloColors.text2),
    );
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.file(
            File(r['media_path'] as String),
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            cacheWidth: decodePx(context, 44),
            frameBuilder: (_, child, frame, sync) =>
                PhotoTileFade(shown: sync || frame != null, child: child),
            errorBuilder: (_, _, _) => missing,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            caption.isEmpty ? l10n.savedPhoto2 : caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textDirection: caption.isEmpty ? null : writtenDir(caption),
            textAlign: startOf(context),
            style: HaloType.sans(
              size: 13,
              color: caption.isEmpty ? HaloColors.text2 : HaloColors.text,
            ),
          ),
        ),
      ],
    );
  }
}

// the bookmark on a card: unsaved, it empties with a small pop before the
// card folds. simply swaps with less movement
class _Bookmark extends StatelessWidget {
  final bool on;
  const _Bookmark({required this.on});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return AnimatedSwitcher(
      duration: still ? Duration.zero : const Duration(milliseconds: 260),
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(
            begin: 0.5,
            end: 1.0,
          ).animate(CurvedAnimation(parent: a, curve: kHouseCurve)),
          child: c,
        ),
      ),
      child: Icon(
        on ? Icons.bookmark : Icons.bookmark_border,
        key: ValueKey(on),
        size: 17,
        color: on ? HaloColors.amber : HaloColors.text3,
      ),
    );
  }
}
