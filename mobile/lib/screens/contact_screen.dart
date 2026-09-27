// SPDX-License-Identifier: GPL-3.0-or-later
// one place for a person. the face and the three words, our name for them,
// how far we trust them, the media we shared, and the things you can do to
// the chat.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../contact_status.dart';
import '../lock_state.dart' show lockState;
import '../main.dart' show appState, session;
import '../theme.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/hidden_mark.dart';
import '../widgets/kryfo_avatar.dart';
import '../widgets/motion.dart'
    show haloRoute, kHouseCurve, kHouseTime, motionStill;
import '../widgets/halo_rows.dart';
import '../widgets/page_head.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/stagger_in.dart';
import '../widgets/press_scale.dart';
import 'chat_screen.dart' show MediaGalleryScreen;
import 'key_verification_screen.dart';
import 'vouchers_sheet.dart';
import '../widgets/confirm_sheet.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';

class ContactScreen extends StatefulWidget {
  final String haloId;
  final String avatarSeed;
  final int? face;
  // the key the chat already holds, for the safety number page
  final String peerXPub;
  const ContactScreen({
    super.key,
    required this.haloId,
    required this.avatarSeed,
    required this.peerXPub,
    this.face,
  });
  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _scroll = ScrollController();
  Map<String, Object?>? _c;
  List<String> _voucherNames = const [];
  int? _since;
  List<String> _media = const [];
  Set<String> _secure = const {};
  int _mediaCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      session.getContact(widget.haloId),
      session.vouchesFor(widget.haloId),
      session.mediaFor(widget.haloId),
      session.firstMessageAt(widget.haloId),
    ]);
    final c = results[0] as Map<String, Object?>?;
    final since = results[3] as int?;
    final vs = results[1] as List<Map<String, Object?>>;
    final rows = results[2] as List<Map<String, Object?>>;
    // a file that went missing draws as nothing; no stat per file up front
    final paths = [for (final r in rows) r['media_path'] as String];
    final secure = {
      for (final r in rows)
        if ((r['secure'] as int? ?? 0) == 1) r['media_path'] as String,
    };
    if (!mounted) return;
    setState(() {
      _c = c;
      _voucherNames = [
        for (final v in vs)
          (v['nickname'] as String?) ?? v['voucher_id'] as String,
      ];
      _media = paths;
      _secure = secure;
      _mediaCount = paths.length;
      _since = since;
    });
  }

  bool _flag(String k) => (_c?[k] as int? ?? 0) == 1;
  String get _name => (_c?['nickname'] as String?) ?? widget.haloId;

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: _c?['nickname'] as String? ?? '');
    final v = await showHaloSheet<String>(
      context,
      scroll: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                const SizedBox(height: 12),
                Text(
                  l10n.contactYourNameForThem,
                  style: HaloType.serif(size: 20, color: HaloColors.text),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.contactStaysOnThisPhone,
                  style: HaloType.sans(size: 12.5, color: HaloColors.text2),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: HaloColors.surface3,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HaloColors.line, width: 0.5),
                  ),
                  child: TextField(
                    controller: ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.none,
                    onSubmitted: (s) => Navigator.pop(ctx, s),
                    style: HaloType.sans(size: 15, color: HaloColors.text),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: widget.haloId,
                      hintStyle: HaloType.mono(
                        size: 13,
                        color: HaloColors.text3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: HaloGhostButton(
                        quiet: true,
                        label: l10n.contactClear,
                        onTap: () => Navigator.pop(ctx, ''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: HaloPrimaryButton(
                        label: l10n.commonSave,
                        onTap: () => Navigator.pop(ctx, ctrl.text),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (v == null) return;
    final t = v.trim();
    await session.setNickname(widget.haloId, t.isEmpty ? null : t);
    await appState.refreshContacts();
    HapticFeedback.selectionClick();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final verified = _flag('verified');
    final blocked = _flag('blocked');
    final muted = _flag('muted');
    final pinned = _flag('pinned');
    final accepted = c == null || (c['accepted'] as int? ?? 1) == 1;
    final hidden = session.isHidden(widget.haloId);
    final status = contactStatusLine(
      verified: verified,
      voucherNames: _voucherNames,
      blocked: blocked,
      accepted: accepted,
    );
    final statusColor = blocked
        ? HaloColors.rose
        : verified
        ? HaloColors.green
        : _voucherNames.isNotEmpty
        ? HaloColors.amber
        : HaloColors.text2;
    final note = c?['note'] as String?;
    final still = motionStill(context);
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        // the name comes up here once the big one has scrolled away
        title: HeadTitle(controller: _scroll, title: _name, from: 170),
        bottom: HeadLine(controller: _scroll),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: HaloPrimaryButton(
                  label: l10n.contactMessage,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HaloGhostButton(
                  label: verified
                      ? l10n.contactKeysVerified
                      : l10n.contactVerifyKeys,
                  onTap: () async {
                    await Navigator.of(context).push(
                      haloRoute(
                        KeyVerificationScreen(
                          peerHaloId: widget.haloId,
                          peerName: _name,
                          myXpub: appState.sessionXPub,
                          peerXpub: widget.peerXPub,
                        ),
                      ),
                    );
                    _load();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: staggerAllIn(context, [
          ParallaxHead(
            controller: _scroll,
            child: Center(
              child: Column(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: still ? 1 : 0.9, end: 1),
                    duration: kHouseTime,
                    curve: kHouseCurve,
                    builder: (_, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Hero(
                      tag: 'face-${widget.avatarSeed}',
                      child: KryfoAvatar(
                        seed: widget.avatarSeed,
                        size: 96,
                        choice: widget.face ?? (c?['avatar'] as num?)?.toInt(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _rename,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HaloType.serif(
                              size: 26,
                              weight: FontWeight.w300,
                              color: HaloColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.edit_outlined,
                          size: 15,
                          color: HaloColors.text3,
                        ),
                      ],
                    ),
                  ),
                  if (c?['nickname'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.haloId,
                      style: HaloType.mono(size: 12.5, color: HaloColors.amber),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    status,
                    style: HaloType.mono(
                      size: 11,
                      color: statusColor,
                      letter: 0.04,
                    ),
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      note,
                      textAlign: TextAlign.center,
                      style: HaloType.serif(
                        size: 14,
                        italic: true,
                        color: HaloColors.text2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          _Stats(
            verified: verified,
            vouches: _voucherNames.length,
            since: _since,
            onVouches: () => showVouchersSheet(context, widget.haloId),
          ),
          if (_voucherNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            HaloGroup(
              children: [
                HaloRow(
                  icon: Icons.people_outline,
                  label: l10n.contactVouches,
                  hint: status,
                  onTap: () => showVouchersSheet(context, widget.haloId),
                ),
              ],
            ),
          ],
          _MediaSection(
            paths: _media,
            count: _mediaCount,
            onOpen: _media.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    haloRoute(
                      MediaGalleryScreen(
                        paths: _media,
                        securePaths: _secure,
                        title: _name,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 18),
          // the chat itself: how loud it is, where it sits in the list
          HaloGroup(
            children: [
              HaloRow(
                icon: muted
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_none,
                label: muted ? l10n.contactUnmute : l10n.contactMute,
                onTap: () async {
                  HapticFeedback.selectionClick();
                  if (muted) {
                    await appState.unmute(widget.haloId);
                  } else {
                    await appState.mute(widget.haloId);
                  }
                  _load();
                },
              ),
              HaloRow(
                icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
                label: pinned ? l10n.contactUnpin : l10n.contactPinToTop,
                onTap: () async {
                  HapticFeedback.selectionClick();
                  await session.setContactPinned(widget.haloId, !pinned);
                  await appState.refreshContacts();
                  _load();
                },
              ),
              HaloRow(
                icon: Icons.archive_outlined,
                label: l10n.contactArchive,
                hint: l10n.contactOutOfTheList,
                onTap: () async {
                  await appState.archive(widget.haloId);
                  if (!context.mounted) return;
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
              ),
              // hidden chats open: out of the everyday list, or back in it.
              // its rows move, so the chat is left as an archived one is
              if (lockState.inVault && accepted && !blocked)
                HaloRow(
                  icon: hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  label: hidden ? l10n.chatShowInList : l10n.chatHide,
                  onTap: () async {
                    final moved = await moveHiddenChat(
                      context,
                      widget.haloId,
                      group: false,
                      hide: !hidden,
                    );
                    if (!moved || !context.mounted) return;
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          // what cannot be taken back, apart and in rose
          HaloGroup(
            rose: true,
            children: [
              HaloRow(
                icon: Icons.block,
                label: blocked ? l10n.commonUnblock : l10n.commonBlock,
                rose: !blocked,
                onTap: () async {
                  if (blocked) {
                    await appState.unblock(widget.haloId);
                    _load();
                    return;
                  }
                  final ok = await showConfirmSheet(
                    context,
                    title: l10n.contactBlock(_name),
                    line: l10n.contactTheirMessagesStopArriving,
                    yes: l10n.commonBlock,
                  );
                  if (!ok) return;
                  await appState.block(widget.haloId);
                  if (!context.mounted) return;
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
              ),
              HaloRow(
                icon: Icons.delete_outline,
                label: l10n.contactDeleteChat,
                hint: l10n.contactMessagesAndContactGone,
                rose: true,
                onTap: () async {
                  final ok = await showConfirmSheet(
                    context,
                    title: l10n.contactDeleteThisChat,
                    line: l10n.contactEveryMessageAndThe,
                    yes: l10n.commonDelete,
                  );
                  if (!ok) return;
                  await appState.deleteConversation(widget.haloId);
                  await appState.refreshContacts();
                  if (!context.mounted) return;
                  HapticFeedback.mediumImpact();
                  showHaloToast(context, l10n.contactDeleted);
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

// the three facts about a person: a tick, a count, a duration. a card only
// exists when there is something to say, and a zero is never drawn. the
// vouch count is your own contacts who vouched, never a global number.
class _Stats extends StatelessWidget {
  final bool verified;
  final int vouches;
  final int? since;
  final VoidCallback onVouches;
  const _Stats({
    required this.verified,
    required this.vouches,
    required this.since,
    required this.onVouches,
  });

  static String _age(int ms) {
    final d = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ms),
    );
    if (d.inDays < 1) return l10n.contactToday;
    if (d.inDays < 30) return l10n.contactD(d.inDays);
    if (d.inDays < 365) return l10n.contactMo(d.inDays ~/ 30);
    return l10n.contactY(d.inDays ~/ 365);
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (verified)
        _StatCard(
          label: l10n.contactVerified,
          child: Icon(Icons.check_rounded, size: 24, color: HaloColors.green),
        ),
      if (vouches > 0)
        _StatCard(
          label: l10n.contactVouches,
          onTap: onVouches,
          child: Text(
            '$vouches',
            style: HaloType.serif(size: 24, color: HaloColors.amber),
          ),
        ),
      if (since != null)
        _StatCard(
          label: l10n.contactChatting,
          child: Text(
            _age(since!),
            style: HaloType.serif(size: 24, color: HaloColors.text),
          ),
        ),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  const _StatCard({required this.label, required this.child, this.onTap});
  @override
  Widget build(BuildContext context) {
    return PressScale(
      label: label,
      onTap: onTap,
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HaloColors.line, width: 0.5),
        ),
        child: Column(
          children: [
            // a value a language writes longer ("3 meses") shrinks to fit
            // its card rather than spilling out of it
            SizedBox(
              height: 30,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Center(
                  child: FittedBox(fit: BoxFit.scaleDown, child: child),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: HaloType.mono(
                size: 9.5,
                color: HaloColors.text3,
                letter: 0.12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// what the two of you shared: its count over the first four, the last of
// them saying how many more. a tap on any opens them all
class _MediaSection extends StatelessWidget {
  final List<String> paths;
  final int count;
  final VoidCallback? onOpen;
  const _MediaSection({required this.paths, required this.count, this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 18),
        child: HaloGroup(
          children: [
            HaloRow(
              icon: Icons.photo_library_outlined,
              label: l10n.contactNothingSharedYet,
            ),
          ],
        ),
      );
    }
    final shown = paths.take(4).toList();
    final more = count - 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageSection(l10n.contactSharedMedia(whole(count))),
        PressScale(
          onTap: onOpen,
          scale: 0.98,
          label: l10n.contactSharedMedia(whole(count)),
          child: LayoutBuilder(
            builder: (context, box) {
              const gap = 6.0;
              final side = (box.maxWidth - gap * 3) / 4;
              return Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    SizedBox.square(
                      dimension: side,
                      child: i >= shown.length
                          ? const SizedBox.shrink()
                          : _Tile(
                              path: shown[i],
                              side: side,
                              more: i == 3 && count > 4 ? more : 0,
                            ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String path;
  final double side;
  // shown over the last tile: how many more there are
  final int more;
  const _Tile({required this.path, required this.side, this.more = 0});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: HaloColors.surface2),
          Image.file(
            File(path),
            fit: BoxFit.cover,
            cacheWidth: (side * MediaQuery.devicePixelRatioOf(context)).round(),
            // a photo fades in as it decodes rather than blinking on
            frameBuilder: (_, child, frame, sync) => sync || still
                ? child
                : AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: child,
                  ),
            // a black square would read as a broken app, not a photo whose
            // file is gone
            errorBuilder: (_, _, _) => _MissingTile(size: side),
          ),
          if (more > 0)
            ColoredBox(
              color: HaloColors.ink.withValues(alpha: 0.62),
              child: Center(
                child: Text(
                  '+${whole(more)}',
                  style: HaloType.mono(
                    size: 15,
                    color: HaloColors.amber,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// a photo whose file has gone, drawn so it does not look like a failed load
class _MissingTile extends StatelessWidget {
  final double size;
  const _MissingTile({required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: HaloColors.surface2,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: size * 0.32,
        color: HaloColors.text3,
      ),
    );
  }
}
