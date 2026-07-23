// SPDX-License-Identifier: GPL-3.0-or-later
// message requests from people not in your contacts. unknown senders land
// here first. tap one to open the conversation, read what they sent, then
// accept / decline / block from inside the chat.
import 'package:flutter/material.dart';
import '../main.dart' show db, appState;
import '../theme.dart';
import '../widgets/kryfo_avatar.dart';
import 'chat_screen.dart';
import '../widgets/motion.dart' show haloRoute;

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});
  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  List<Map<String, Object?>> _pending = [];
  final Map<String, String> _previews = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await db.pendingRequests();
    final previews = <String, String>{};
    for (final r in rows) {
      final id = r['halo_id'] as String;
      final msgs = await db.messagesFor(id);
      if (msgs.isNotEmpty) {
        final last = msgs.last;
        final text = (last['plaintext'] as String?) ?? '';
        previews[id] = text.isEmpty ? 'sent an attachment' : text;
      } else {
        previews[id] = 'wants to connect';
      }
    }
    if (!mounted) return;
    setState(() {
      _pending = rows;
      _previews
        ..clear()
        ..addAll(previews);
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
        ),
      ),
    );
    // coming back: the request may have been accepted/declined/blocked in-chat,
    // so refresh the list + the home pin count.
    await appState.refreshContacts();
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
          'requests',
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
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final row = _pending[i];
                final id = row['halo_id'] as String;
                return _RequestCard(
                  key: ValueKey('req_$id'),
                  order: i,
                  haloId: id,
                  preview: _previews[id] ?? '',
                  onTap: () => _open(row),
                );
              },
            ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BreathingInbox(),
            const SizedBox(height: 14),
            Text(
              'no requests',
              style: HaloType.serif(size: 18, color: HaloColors.text2),
            ),
            const SizedBox(height: 6),
            Text(
              'messages from people you have not added show up here first.',
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
    );
  }
}

// staggered fade-and-rise as each card comes in. tap opens the conversation.
class _RequestCard extends StatefulWidget {
  final int order;
  final String haloId;
  final String preview;
  final VoidCallback onTap;
  const _RequestCard({
    super.key,
    required this.order,
    required this.haloId,
    required this.preview,
    required this.onTap,
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
                  KryfoAvatar(seed: widget.haloId, size: 44),
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
            builder: (_, __) {
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
