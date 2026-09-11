// SPDX-License-Identifier: GPL-3.0-or-later
// one place for a person. the face and the three words, our name for them,
// how far we trust them, the media we shared, and the things you can do to
// the chat. nickname, verification, vouches and media used to live on four
// different sheets.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../contact_status.dart';
import '../main.dart' show appState, db, engine;
import '../theme.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/kryfo_avatar.dart';
import '../widgets/motion.dart' show haloRoute;
import '../widgets/sheet_handle.dart';
import '../widgets/stagger_in.dart';
import 'chat_screen.dart' show MediaGalleryScreen;
import 'key_verification_screen.dart';
import 'vouchers_sheet.dart';
import '../widgets/confirm_sheet.dart';

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
  Map<String, Object?>? _c;
  List<String> _voucherNames = const [];
  List<String> _media = const [];
  Set<String> _secure = const {};
  int _mediaCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      db.getContact(widget.haloId),
      db.vouchesFor(widget.haloId),
      db.mediaFor(widget.haloId),
    ]);
    final c = results[0] as Map<String, Object?>?;
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
                  'your name for them',
                  style: HaloType.serif(size: 20, color: HaloColors.text),
                ),
                const SizedBox(height: 6),
                Text(
                  'stays on this phone. they never see it.',
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
                      child: _Ghost(
                        label: 'clear',
                        onTap: () => Navigator.pop(ctx, ''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _Primary(
                        label: 'save',
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
    await db.setNickname(widget.haloId, t.isEmpty ? null : t);
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
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: staggerAll([
          Center(
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.9, end: 1),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
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
          const SizedBox(height: 26),
          _Row(
            icon: Icons.chat_bubble_outline,
            label: 'message',
            onTap: () => Navigator.of(context).pop(),
          ),
          _Row(
            icon: Icons.verified_user_outlined,
            label: verified
                ? 'safety number · verified'
                : 'verify safety number',
            sub: verified
                ? 'you compared numbers in person'
                : 'compare numbers in person, once',
            onTap: () async {
              await Navigator.of(context).push(
                haloRoute(
                  KeyVerificationScreen(
                    peerHaloId: widget.haloId,
                    peerName: _name,
                    myXpub: engine.myXPubkey(),
                    peerXpub: widget.peerXPub,
                  ),
                ),
              );
              _load();
            },
          ),
          if (_voucherNames.isNotEmpty)
            _Row(
              icon: Icons.people_outline,
              label: 'vouches',
              sub: status,
              onTap: () => showVouchersSheet(context, widget.haloId),
            ),
          _MediaRow(
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
          _Row(
            icon: muted
                ? Icons.notifications_off_outlined
                : Icons.notifications_none,
            label: muted ? 'unmute' : 'mute',
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
          _Row(
            icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
            label: pinned ? 'unpin' : 'pin to top',
            onTap: () async {
              HapticFeedback.selectionClick();
              await db.setContactPinned(widget.haloId, !pinned);
              await appState.refreshContacts();
              _load();
            },
          ),
          _Row(
            icon: Icons.archive_outlined,
            label: 'archive',
            sub: 'out of the list until they write again',
            onTap: () async {
              await appState.archive(widget.haloId);
              if (!context.mounted) return;
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
          _Row(
            icon: Icons.block,
            label: blocked ? 'unblock' : 'block',
            rose: !blocked,
            onTap: () async {
              if (blocked) {
                await appState.unblock(widget.haloId);
                _load();
                return;
              }
              final ok = await showConfirmSheet(
                context,
                title: 'block $_name?',
                line: 'their messages stop arriving. they are not told.',
                yes: 'block',
              );
              if (!ok) return;
              await appState.block(widget.haloId);
              if (!context.mounted) return;
              HapticFeedback.mediumImpact();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
          _Row(
            icon: Icons.delete_outline,
            label: 'delete chat',
            sub: 'messages and contact, gone from this phone',
            rose: true,
            onTap: () async {
              final ok = await showConfirmSheet(
                context,
                title: 'delete this chat?',
                line:
                    'every message and the contact, gone from this phone. nothing '
                    'is sent to them.',
                yes: 'delete',
              );
              if (!ok) return;
              await appState.deleteConversation(widget.haloId);
              await appState.refreshContacts();
              if (!context.mounted) return;
              HapticFeedback.mediumImpact();
              showHaloToast(context, 'deleted');
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final bool rose;
  final VoidCallback onTap;
  const _Row({
    required this.icon,
    required this.label,
    this.sub,
    this.rose = false,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final color = rose ? HaloColors.rose : HaloColors.text;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 19, color: HaloColors.amber),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: HaloType.sans(size: 14.5, color: color)),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub!,
                      style: HaloType.sans(size: 12, color: HaloColors.text2),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: HaloColors.text3),
          ],
        ),
      ),
    );
  }
}

// the last six things you shared, as a strip. tap for all of them.
class _MediaRow extends StatelessWidget {
  final List<String> paths;
  final int count;
  final VoidCallback? onOpen;
  const _MediaRow({required this.paths, required this.count, this.onOpen});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 19,
                  color: HaloColors.amber,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    count == 0 ? 'nothing shared yet' : 'shared media · $count',
                    style: HaloType.sans(
                      size: 14.5,
                      color: count == 0 ? HaloColors.text2 : HaloColors.text,
                    ),
                  ),
                ),
                if (count > 0)
                  Icon(Icons.chevron_right, size: 18, color: HaloColors.text3),
              ],
            ),
            if (paths.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final p in paths.take(6))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(p),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            cacheWidth: 112,
                            errorBuilder: (_, _, _) =>
                                const SizedBox(width: 56, height: 56),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Primary extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Primary({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HaloColors.amber,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        label,
        style: HaloType.sans(
          size: 14,
          weight: FontWeight.w600,
          color: HaloColors.onAmber,
        ),
      ),
    ),
  );
}

class _Ghost extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Ghost({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: HaloColors.line),
      ),
      child: Text(
        label,
        style: HaloType.sans(size: 14, color: HaloColors.text2),
      ),
    ),
  );
}
