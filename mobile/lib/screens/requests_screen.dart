// SPDX-License-Identifier: GPL-3.0-or-later
// message requests from people not in your contacts. unknown senders land
// here instead of the main list. accept moves them in, block hides them.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show db, appState;
import '../theme.dart';
import '../widgets/halo_avatar.dart';

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

  Future<void> _accept(String id) async {
    HapticFeedback.selectionClick();
    await db.acceptRequest(id);
    await appState.refreshContacts();
    await _load();
  }

  Future<void> _block(String id) async {
    HapticFeedback.selectionClick();
    await db.setBlocked(id, true);
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
                final id = _pending[i]['halo_id'] as String;
                return _RequestCard(
                  key: ValueKey('req_$id'),
                  order: i,
                  haloId: id,
                  preview: _previews[id] ?? '',
                  onAccept: () => _accept(id),
                  onBlock: () => _block(id),
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
            Icon(Icons.inbox_outlined, size: 40, color: HaloColors.text3),
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

// staggered fade-and-rise as each card comes in.
class _RequestCard extends StatefulWidget {
  final int order;
  final String haloId;
  final String preview;
  final VoidCallback onAccept;
  final VoidCallback onBlock;
  const _RequestCard({
    super.key,
    required this.order,
    required this.haloId,
    required this.preview,
    required this.onAccept,
    required this.onBlock,
  });
  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _in;

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
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HaloColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HaloColors.line, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HaloAvatar(seed: widget.haloId, size: 40),
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
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'accept',
                      filled: true,
                      onTap: widget.onAccept,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      label: 'block',
                      filled: false,
                      onTap: widget.onBlock,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });
  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  double _s = 1.0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _s = 0.95),
      onTapUp: (_) => setState(() => _s = 1.0),
      onTapCancel: () => setState(() => _s = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _s,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.filled ? HaloColors.amber : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: widget.filled
                ? null
                : Border.all(color: HaloColors.line2, width: 1),
          ),
          child: Text(
            widget.label,
            style: HaloType.sans(
              size: 13,
              weight: FontWeight.w600,
              color: widget.filled ? const Color(0xFF1A0F04) : HaloColors.text2,
            ),
          ),
        ),
      ),
    );
  }
}
