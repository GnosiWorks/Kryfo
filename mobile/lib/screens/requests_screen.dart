// SPDX-License-Identifier: GPL-3.0-or-later
// message requests from people not in your contacts. unknown senders land
// here first. tap one to open the conversation, read what they sent, then
// accept / decline / block from inside the chat.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show db, appState;
import '../theme.dart';
import '../widgets/stagger_in.dart';
import '../widgets/kryfo_avatar.dart';
import '../widgets/intro_chip.dart';
import '../vouch_text.dart';
import '../widgets/notice_banner.dart';
import '../widgets/confirm_sheet.dart';
import 'chat_screen.dart';
import 'shield_sheet.dart';
import '../widgets/motion.dart' show haloRoute;

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
  List<Map<String, Object?>> _pending = [];
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

  Future<void> _load() async {
    final rows = await db.pendingRequests();
    final previews = <String, String>{};
    final introducers = <String, _Introducer>{};
    final flags = <String, ShieldFlag>{};
    final clean = <String>{};
    for (final r in rows) {
      final id = r['halo_id'] as String;
      final shieldRow = await db.shieldFor(id);
      final flag = ShieldFlag.fromRow(shieldRow);
      if (flag != null) flags[id] = flag;
      // the shield ran and found nothing: worth a line here, since this is
      // the screen where a stranger is judged
      if (flag == null && ShieldFlag.cleanRow(shieldRow)) clean.add(id);
      final msgs = await db.messagesFor(id);
      if (msgs.isNotEmpty) {
        final last = msgs.last;
        final text = (last['plaintext'] as String?) ?? '';
        previews[id] = text.isEmpty ? 'Sent an attachment' : text;
      } else {
        previews[id] = 'Wants to connect';
      }
      // an introduced row names the friends who vouched. only vouchers we
      // still hold as contacts come back, so a deleted one just drops off.
      final vs = await db.vouchesFor(id);
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
      _pending = rows;
      _previews
        ..clear()
        ..addAll(previews);
      _introducers
        ..clear()
        ..addAll(introducers);
      _flags
        ..clear()
        ..addAll(flags);
      _clean
        ..clear()
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

  // the three answers live here, on the list. opening a chat to decline
  // someone was backwards.
  // one answer per card at a time: a double tap on accept ran the accept
  // twice, two acks out and the held messages opened twice
  final Set<String> _answering = {};

  Future<void> _accept(String id) async {
    if (!_answering.add(id)) return;
    HapticFeedback.selectionClick();
    await db.acceptRequest(id);
    await appState.afterAccept(id);
    _answering.remove(id);
    if (mounted) showHaloToast(context, 'Accepted');
    await _load();
  }

  Future<void> _decline(String id) async {
    if (!_answering.add(id)) return;
    HapticFeedback.selectionClick();
    await db.declineRequest(id);
    _answering.remove(id);
    await appState.refreshContacts();
    await _load();
  }

  Future<void> _block(String id) async {
    final ok = await showConfirmSheet(
      context,
      title: 'Block $id?',
      line:
          'Nothing more from them reaches you. Their request and its '
          'messages go.',
      yes: 'Block',
    );
    if (!ok || !mounted || !_answering.add(id)) return;
    // the sheet says their messages go: decline drops them, block shuts
    // the door
    await db.declineRequest(id);
    await appState.block(id);
    await db.clearUnread(id);
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
      showHaloToast(context, c == ShieldChoice.block ? 'blocked' : 'deleted');
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        leading: BackButton(color: HaloColors.text),
        title: Text(
          'Requests',
          style: HaloType.serif(size: 18, color: HaloColors.text),
        ),
      ),
      body: _loading
          ? const SizedBox.shrink()
          : _pending.isEmpty
          ? _empty()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _pending.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final row = _pending[i];
                final id = row['halo_id'] as String;
                return _RequestCard(
                  key: ValueKey('req_$id'),
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
                );
              },
            ),
    );
  }

  Widget _empty() {
    return Center(
      child: StaggerIn(
        index: 0,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _BreathingInbox(),
              const SizedBox(height: 14),
              Text(
                'No requests',
                style: HaloType.serif(size: 18, color: HaloColors.text2),
              ),
              const SizedBox(height: 6),
              Text(
                'Messages from people you have not added show up here first.',
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 13,
                  color: HaloColors.text3,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// staggered fade-and-rise as each card comes in. tap opens the conversation.
// an introduced row carries the vouching friend as an amber chip.
class _RequestCard extends StatefulWidget {
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
    super.key,
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
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _in;
  double _s = 1.0;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(
      duration: const Duration(milliseconds: 360),
      vsync: this,
    );
    Future.delayed(Duration(milliseconds: 60 * widget.order), () {
      if (mounted) _in.forward();
    });
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _in, curve: Curves.easeOut);
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(fade),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _s = 0.98),
          onTapUp: (_) => setState(() => _s = 1.0),
          onTapCancel: () => setState(() => _s = 1.0),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _s,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
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
                    tag: 'face-${widget.haloId}',
                    child: KryfoAvatar(
                      seed: widget.haloId,
                      size: 44,
                      choice: widget.avatar,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.haloId,
                          style: HaloType.mono(
                            size: 12,
                            color: HaloColors.text,
                            weight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.introducer != null) ...[
                          const SizedBox(height: 6),
                          IntroducedBy(
                            label: widget.introducer!.label,
                            seed: widget.introducer!.seed,
                            avatar: widget.introducer!.avatar,
                            verified: widget.introducer!.verified,
                            delay: Duration(
                              milliseconds: 60 * widget.order + 180,
                            ),
                          ),
                        ],
                        if (widget.flag != null) ...[
                          const SizedBox(height: 7),
                          NoticeBanner(
                            glyph: NoticeGlyph.shield,
                            text: widget.flag!.headline,
                            color: HaloColors.rose,
                            delay: Duration(
                              milliseconds: 60 * widget.order + 220,
                            ),
                            onTap: widget.onShield,
                          ),
                        ] else if (widget.clean) ...[
                          const SizedBox(height: 7),
                          NoticeBanner(
                            glyph: NoticeGlyph.shield,
                            text:
                                'Looks safe · nothing suspicious in their first message',
                            color: HaloColors.green,
                            delay: Duration(
                              milliseconds: 60 * widget.order + 220,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          widget.preview,
                          style: HaloType.sans(
                            size: 13,
                            color: HaloColors.text2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _Answer(
                              label: 'Accept',
                              filled: true,
                              onTap: widget.onAccept,
                            ),
                            const SizedBox(width: 8),
                            _Answer(label: 'Decline', onTap: widget.onDecline),
                            const SizedBox(width: 8),
                            _Answer(
                              label: 'Block',
                              color: HaloColors.rose,
                              onTap: widget.onBlock,
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
          ),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
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

// soft amber ring breathing behind the empty inbox - same quiet-waiting
// feel as the home empty state.
class _BreathingInbox extends StatefulWidget {
  const _BreathingInbox();

  @override
  State<_BreathingInbox> createState() => _BreathingInboxState();
}

class _BreathingInboxState extends State<_BreathingInbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) {
              final t = Curves.easeOut.transform(_pulse.value);
              return Container(
                width: 46 + 20 * t,
                height: 46 + 20 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: HaloColors.amber.withValues(alpha: 0.30 * (1 - t)),
                    width: 1.2,
                  ),
                ),
              );
            },
          ),
          Icon(Icons.inbox_outlined, size: 34, color: HaloColors.text3),
        ],
      ),
    );
  }
}
