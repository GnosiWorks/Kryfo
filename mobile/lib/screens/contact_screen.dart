// SPDX-License-Identifier: GPL-3.0-or-later
// one place for a person. the face and the three words, our name for them,
// how far we trust them, the media we shared, and the things you can do to
// the chat.
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
import '../widgets/ease_size.dart';
import '../widgets/shared_media.dart';
import '../widgets/swap.dart';
import 'home_screen.dart' show ContactPreview;
import 'chat_screen.dart' show MediaGalleryScreen;
import 'key_verification_screen.dart';
import 'vouchers_sheet.dart';
import '../widgets/confirm_sheet.dart';
import '../l10n/l10n.dart';

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
  // the first read is in: until then the list's own row stands in
  bool _loaded = false;
  // what the chat list already knows about them, for the first frame
  late final ContactPreview? _seen = appState.contacts
      .where((c) => c.haloId == widget.haloId)
      .firstOrNull;
  // a switch moves on the tap; the write follows behind it
  bool? _mutedNow;
  bool? _pinnedNow;

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
      _loaded = true;
    });
  }

  bool _flag(String k) {
    final c = _c;
    if (c != null) return (c[k] as int? ?? 0) == 1;
    final s = _seen;
    return switch (k) {
      'verified' => s?.verified ?? false,
      'blocked' => s?.blocked ?? false,
      'muted' => s?.muted ?? false,
      'pinned' => s?.pinned ?? false,
      _ => false,
    };
  }

  String? get _nickname =>
      _c != null ? _c!['nickname'] as String? : _seen?.nickname;
  String get _name => _nickname ?? widget.haloId;

  Future<void> _setMuted(bool on) async {
    HapticFeedback.selectionClick();
    setState(() => _mutedNow = on);
    if (on) {
      await appState.mute(widget.haloId);
    } else {
      await appState.unmute(widget.haloId);
    }
    await _load();
    if (mounted) setState(() => _mutedNow = null);
  }

  Future<void> _setPinned(bool on) async {
    HapticFeedback.selectionClick();
    setState(() => _pinnedNow = on);
    await session.setContactPinned(widget.haloId, on);
    await appState.refreshContacts();
    await _load();
    if (mounted) setState(() => _pinnedNow = null);
  }

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
    final muted = _mutedNow ?? _flag('muted');
    final pinned = _pinnedNow ?? _flag('pinned');
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
                          initialVerified: verified,
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
                  if (_nickname != null) ...[
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
          // the cards ease in once there is something to put on them
          EaseSize(
            child: FadeSwap(
              child: _loaded
                  ? _Stats(
                      key: const ValueKey('stats'),
                      verified: verified,
                      vouches: _voucherNames.length,
                      since: _since,
                      onVouches: () =>
                          showVouchersSheet(context, widget.haloId),
                    )
                  : const SizedBox(
                      key: ValueKey('no-stats'),
                      width: double.infinity,
                    ),
            ),
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
          SharedMediaSection(
            paths: _media,
            count: _mediaCount,
            loaded: _loaded,
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
                label: l10n.contactMute,
                toggled: muted,
                onTap: () => _setMuted(!muted),
              ),
              HaloRow(
                icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
                label: l10n.contactPinToTop,
                toggled: pinned,
                onTap: () => _setPinned(!pinned),
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
    super.key,
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
