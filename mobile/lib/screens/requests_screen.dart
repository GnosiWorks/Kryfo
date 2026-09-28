// SPDX-License-Identifier: GPL-3.0-or-later
// message requests from people not in your contacts. accept, decline or
// block on the card, or tap it to read the conversation first. an answered
// card folds away and the ones under it glide up.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../lock_guard.dart' show lockGuard;
import '../main.dart' show session, appState;
import '../theme.dart';
import '../widgets/breathing_ring.dart';
import '../widgets/burn_fade.dart' show FadeFold;
import '../widgets/press_scale.dart';
import '../widgets/row_motion.dart';
import '../widgets/stagger_in.dart';
import '../widgets/swap.dart';
import '../widgets/kryfo_avatar.dart';
import '../widgets/intro_chip.dart';
import '../vouch_text.dart';
import '../widgets/notice_banner.dart';
import '../widgets/confirm_sheet.dart';
import 'chat_screen.dart';
import 'shield_sheet.dart';
import '../widgets/motion.dart' show haloRoute;
import '../l10n/l10n.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});
  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

// who vouched for a request row, as we know them. the line is phrased
// already; the face and check belong to the first voucher.
class _Introducer {
  final String label;
  final String seed;
  final int? avatar;
  final bool verified;
  const _Introducer(this.label, this.seed, this.avatar, this.verified);
}

class _RequestsScreenState extends State<RequestsScreen> {
  // the cards drawn: the pending ones, and any answered one still folding
  late final RowSet<Map<String, Object?>> _rows = RowSet(
    keyOf: (r) => r['halo_id'] as String,
    onGone: () {
      if (mounted) setState(() {});
    },
  );
  final Map<String, String> _previews = {};
  final Map<String, _Introducer> _introducers = {};
  final Map<String, ShieldFlag> _flags = {};
  final Set<String> _clean = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rows.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // support chats have their own inbox
    final rows = await session.requestsInbox();
    final previews = <String, String>{};
    final introducers = <String, _Introducer>{};
    final flags = <String, ShieldFlag>{};
    final clean = <String>{};
    for (final r in rows) {
      final id = r['halo_id'] as String;
      final shieldRow = await session.shieldFor(id);
      final flag = ShieldFlag.fromRow(shieldRow);
      if (flag != null) flags[id] = flag;
      // the shield ran and found nothing: worth a line here, since this is
      // the screen where a stranger is judged
      if (flag == null && ShieldFlag.cleanRow(shieldRow)) clean.add(id);
      final msgs = await session.messagesFor(id);
      if (msgs.isNotEmpty) {
        final last = msgs.last;
        final text = (last['plaintext'] as String?) ?? '';
        previews[id] = text.isEmpty ? l10n.requestsSentAnAttachment : text;
      } else {
        previews[id] = l10n.requestsWantsToConnect;
      }
      // an introduced row names the friends who vouched. only vouchers we
      // still hold as contacts come back, so a deleted one just drops off.
      final vs = await session.vouchesFor(id);
      if (vs.isNotEmpty) {
        final first = vs.first;
        introducers[id] = _Introducer(
          introducedByLine([
            for (final v in vs)
              (v['nickname'] as String?) ?? v['voucher_id'] as String,
          ]),
          first['voucher_id'] as String,
          (first['avatar'] as num?)?.toInt(),
          vs.length == 1 && (first['verified'] as int? ?? 0) == 1,
        );
      }
    }
    if (!mounted) return;
    setState(() {
      if (_loading) {
        _rows.start(rows);
      } else {
        // under the lock nothing is watched: no fold, no growing
        _rows.update(rows, quiet: lockGuard.isLocked());
      }
      // a card on its way out keeps what it showed while it folds
      final now = {for (final r in rows) r['halo_id'] as String};
      final drawn = {for (final r in _rows.rows) r['halo_id'] as String};
      bool stale(String id) => now.contains(id) || !drawn.contains(id);
      _previews
        ..removeWhere((id, _) => stale(id))
        ..addAll(previews);
      _introducers
        ..removeWhere((id, _) => stale(id))
        ..addAll(introducers);
      _flags
        ..removeWhere((id, _) => stale(id))
        ..addAll(flags);
      _clean
        ..removeWhere(stale)
        ..addAll(clean);
      _loading = false;
    });
  }

  Future<void> _open(Map<String, Object?> row) async {
    final id = row['halo_id'] as String;
    await Navigator.of(context).push(
      haloRoute(
        ChatScreen(
          peerHaloId: id,
          peerOnion: (row['onion'] as String?) ?? '',
          peerXPub: (row['xpub'] as String?) ?? '',
          avatarSeed: id,
          avatarChoice: (row['avatar'] as num?)?.toInt(),
        ),
      ),
    );
    // coming back: the request may have been accepted/declined/blocked in-chat,
    // so refresh the list + the home pin count.
    await appState.refreshContacts();
    await _load();
  }

  // one answer per card at a time: a double tap on accept would send two
  // acks and open the held messages twice
  final Set<String> _answering = {};

  Future<void> _accept(String id) async {
    if (!_answering.add(id)) return;
    HapticFeedback.selectionClick();
    await session.acceptRequest(id);
    await appState.afterAccept(id);
    _answering.remove(id);
    if (mounted) showHaloToast(context, l10n.requestsAccepted);
    await _load();
  }

  Future<void> _decline(String id) async {
    if (!_answering.add(id)) return;
    HapticFeedback.selectionClick();
    await session.declineRequest(id);
    _answering.remove(id);
    await appState.refreshContacts();
    await _load();
  }

  Future<void> _block(String id) async {
    final ok = await showConfirmSheet(
      context,
      title: l10n.requestsBlock(id),
      line: l10n.requestsNothingMoreFromThem,
      yes: l10n.commonBlock,
    );
    if (!ok || !mounted || !_answering.add(id)) return;
    // the sheet says their messages go: decline drops them, block shuts
    // the door
    await session.declineRequest(id);
    await appState.block(id);
    await session.clearUnread(id);
    _answering.remove(id);
    await appState.refreshContacts();
    await _load();
  }

  Future<void> _shield(String id) async {
    final flag = _flags[id];
    if (flag == null) return;
    final c = await showShieldSheet(context, id, flag);
    if (c == null || !mounted) return;
    if (c != ShieldChoice.ignore) {
      showHaloToast(
        context,
        c == ShieldChoice.block ? l10n.requestsBlocked : l10n.requestsDeleted,
      );
    }
    await _load();
  }

  Widget _card(Map<String, Object?> row, int i) {
    final id = row['halo_id'] as String;
    final leaving = _rows.leaving(row);
    return IgnorePointer(
      key: ValueKey('req_$id'),
      ignoring: leaving,
      child: FadeFold(
        leaving: leaving,
        child: GrowIn(
          active: _rows.fresh(row),
          child: StaggerIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RequestCard(
                order: i,
                haloId: id,
                avatar: (row['avatar'] as num?)?.toInt(),
                preview: _previews[id] ?? '',
                introducer: _introducers[id],
                flag: _flags[id],
                clean: _clean.contains(id),
                onShield: () => _shield(id),
                onTap: () => _open(row),
                onAccept: () => _accept(id),
                onDecline: () => _decline(id),
                onBlock: () => _block(id),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows.rows;
    // the cards built this frame have read whether they are new
    WidgetsBinding.instance.addPostFrameCallback((_) => _rows.built());
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        leading: BackButton(color: HaloColors.text),
        title: Text(
          l10n.requestsRequests,
          style: HaloType.serif(size: 18, color: HaloColors.text),
        ),
      ),
      body: _loading
          ? const SizedBox.shrink()
          // the last card folds away, then the empty page fades in
          : FadeSwap(
              child: rows.isEmpty
                  ? KeyedSubtree(key: const ValueKey('none'), child: _empty())
                  : ListView(
                      key: const ValueKey('cards'),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                      children: [
                        for (final (i, row) in rows.indexed) _card(row, i),
                      ],
                    ),
            ),
    );
  }

  Widget _empty() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 44),
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
                  Icons.inbox_outlined,
                  color: HaloColors.amber,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.requestsNoRequests,
              textAlign: TextAlign.center,
              style: HaloType.serif(size: 24, color: HaloColors.text),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.requestsMessagesFromPeopleYou,
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
}

// tap opens the conversation. an introduced row carries the vouching friend
// as an amber chip.
class _RequestCard extends StatelessWidget {
  final int order;
  final String haloId;
  final int? avatar;
  final String preview;
  final _Introducer? introducer;
  final ShieldFlag? flag;
  final bool clean;
  final VoidCallback? onShield;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onBlock;
  const _RequestCard({
    required this.order,
    required this.haloId,
    this.avatar,
    required this.preview,
    this.introducer,
    this.flag,
    this.clean = false,
    this.onShield,
    required this.onTap,
    required this.onAccept,
    required this.onDecline,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.98,
      haptic: false,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HaloColors.line, width: 0.5),
        ),
        child: Row(
          children: [
            Hero(
              tag: 'face-$haloId',
              child: KryfoAvatar(seed: haloId, size: 44, choice: avatar),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    haloId,
                    style: HaloType.mono(
                      size: 12,
                      color: HaloColors.text,
                      weight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (introducer != null) ...[
                    const SizedBox(height: 6),
                    IntroducedBy(
                      label: introducer!.label,
                      seed: introducer!.seed,
                      avatar: introducer!.avatar,
                      verified: introducer!.verified,
                      delay: Duration(milliseconds: 60 * order + 180),
                    ),
                  ],
                  if (flag != null) ...[
                    const SizedBox(height: 7),
                    NoticeBanner(
                      glyph: NoticeGlyph.shield,
                      text: flag!.headline,
                      color: HaloColors.rose,
                      delay: Duration(milliseconds: 60 * order + 220),
                      onTap: onShield,
                    ),
                  ] else if (clean) ...[
                    const SizedBox(height: 7),
                    NoticeBanner(
                      glyph: NoticeGlyph.shield,
                      text: l10n.requestsLooksSafeNothingSuspicious,
                      color: HaloColors.green,
                      delay: Duration(milliseconds: 60 * order + 220),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    style: HaloType.sans(size: 13, color: HaloColors.text2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _Answer(
                        label: l10n.commonAccept,
                        filled: true,
                        onTap: onAccept,
                      ),
                      const SizedBox(width: 8),
                      _Answer(label: l10n.requestsDecline, onTap: onDecline),
                      const SizedBox(width: 8),
                      _Answer(
                        label: l10n.commonBlock,
                        color: HaloColors.rose,
                        onTap: onBlock,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 20, color: HaloColors.text3),
          ],
        ),
      ),
    );
  }
}

// one answer on a request card: amber filled for accept, quiet for the rest
class _Answer extends StatelessWidget {
  final String label;
  final bool filled;
  final Color? color;
  final VoidCallback onTap;
  const _Answer({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.color,
  });
  @override
  Widget build(BuildContext context) {
    final c = color ?? (filled ? HaloColors.onAmber : HaloColors.text2);
    // the answer gives its own haptic
    return PressScale(
      onTap: onTap,
      scale: 0.94,
      haptic: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? HaloColors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: filled ? null : Border.all(color: HaloColors.line),
        ),
        child: Text(
          label,
          style: HaloType.sans(size: 12.5, weight: FontWeight.w600, color: c),
        ),
      ),
    );
  }
}
