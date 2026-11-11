// SPDX-License-Identifier: GPL-3.0-or-later
// a message for another chat while Kryfo is in front: a banner drops from
// the top with who and what, a tap opens that chat, a swipe up sends it
// away, four seconds take it. more from the same chat count up in place.
// it says only what the chat's notification would: the rules for what may
// show are decided before it is asked (bannerFits, the arrival's words)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import 'kryfo_avatar.dart';
import 'motion.dart' show motionStill;

/// whether a banner may show for a message at all: Kryfo in front and
/// open, not a decoy, the chat not the one on screen, not muted, and a
/// hidden chat's only inside its open vault (and nothing else in there)
bool bannerFits({
  required bool inFront,
  required bool locked,
  required bool quiet,
  required bool reading,
  required bool muted,
  required bool inVault,
  required bool hiddenChat,
}) =>
    inFront && !locked && !quiet && !reading && !muted && hiddenChat == inVault;

/// what one banner shows. [chat] is the notification payload: a person's
/// id or `group:<id>`. [avatarSeed] null draws no face, for a line that
/// names no one
class BannerNote {
  final String chat;
  final String title;
  final String body;
  final String? avatarSeed;
  final int? avatarChoice;
  final bool group;
  const BannerNote({
    required this.chat,
    required this.title,
    required this.body,
    this.avatarSeed,
    this.avatarChoice,
    this.group = false,
  });
}

/// the root overlay the banner lives in, set at start with the toast's
OverlayState? Function()? bannerOverlay;

/// what a tap on the banner opens, set at start
Future<void> Function(String chat)? bannerOpens;

OverlayEntry? _entry;
final _key = GlobalKey<_BannerState>();

/// shows [note], or counts it into the one up for the same chat
void showInAppBanner(BannerNote note) {
  final shown = _key.currentState;
  if (_entry != null && shown != null && shown.mounted) {
    shown.take(note);
    return;
  }
  final overlay = bannerOverlay?.call();
  if (overlay == null) return;
  _entry?.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Banner(
      key: _key,
      first: note,
      onGone: () {
        if (identical(_entry, entry)) _entry = null;
        entry.remove();
      },
    ),
  );
  _entry = entry;
  overlay.insert(entry);
}

/// the lock is going up, or the session changed: the banner goes at once
void clearInAppBanner() {
  final e = _entry;
  _entry = null;
  e?.remove();
}

@visibleForTesting
bool get bannerUp => _entry != null;

// how long one stays when left alone
const kBannerStays = Duration(seconds: 4);

class _Banner extends StatefulWidget {
  final BannerNote first;
  final VoidCallback onGone;
  const _Banner({super.key, required this.first, required this.onGone});

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late BannerNote _note = widget.first;
  int _count = 1;
  Timer? _timer;
  bool _leaving = false;
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(kBannerStays, leave);
  }

  // another message: the same chat counts up, another chat takes its place
  void take(BannerNote note) {
    if (_leaving) {
      _leaving = false;
      _c.forward();
    }
    setState(() {
      _count = note.chat == _note.chat ? _count + 1 : 1;
      _note = note;
    });
    _timer?.cancel();
    _timer = Timer(kBannerStays, leave);
  }

  void leave() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer?.cancel();
    _c.reverse().whenComplete(() {
      if (mounted && _leaving) widget.onGone();
    });
  }

  void _open() {
    HapticFeedback.lightImpact();
    final chat = _note.chat;
    leave();
    unawaited(bannerOpens?.call(chat));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final still = motionStill(context);
    final n = _note;
    final body = _count > 1 ? l10n.bannerNewMessages(_count) : n.body;
    return Positioned(
      left: 12,
      right: 12,
      top: mq.padding.top + 8,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = _c.value;
          if (still) return Opacity(opacity: t, child: child);
          // in: a drop from above the edge with a little overshoot. out: up
          final e = _leaving
              ? Curves.easeIn.transform(t)
              : Curves.easeOutBack.transform(t);
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - e) * -72 + _drag),
              child: child,
            ),
          );
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _open,
          onVerticalDragUpdate: (d) =>
              setState(() => _drag = (_drag + d.delta.dy).clamp(-120.0, 8.0)),
          onVerticalDragEnd: (d) {
            if (_drag < -24 || d.velocity.pixelsPerSecond.dy < -300) {
              leave();
            } else {
              setState(() => _drag = 0);
            }
          },
          child: Semantics(
            container: true,
            liveRegion: true,
            button: true,
            label: n.avatarSeed == null
                ? l10n.bannerOpen
                : l10n.bannerOpenWith(n.title),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 14, 10),
                decoration: BoxDecoration(
                  color: HaloColors.surface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: HaloColors.amber.withValues(alpha: 0.4),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: HaloColors.ink.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _face(n),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HaloType.sans(
                              size: 13.5,
                              weight: FontWeight.w600,
                              color: HaloColors.text,
                            ),
                          ),
                          if (body.isNotEmpty) const SizedBox(height: 1),
                          // a new count or line rolls in over the last
                          if (body.isNotEmpty)
                            AnimatedSwitcher(
                              duration: Duration(milliseconds: still ? 0 : 200),
                              layoutBuilder: (top, gone) => Stack(
                                alignment: AlignmentDirectional.centerStart,
                                children: [...gone, ?top],
                              ),
                              child: Text(
                                body,
                                key: ValueKey('$_count:$body'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HaloType.sans(
                                  size: 12.5,
                                  color: HaloColors.text,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _face(BannerNote n) {
    final seed = n.avatarSeed;
    if (seed == null) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: HaloColors.amberSoft,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.chat_bubble_outline_rounded,
          size: 17,
          color: HaloColors.amberText,
        ),
      );
    }
    if (n.group) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: HaloColors.amberSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          n.title.isEmpty ? '·' : n.title.characters.first.toUpperCase(),
          style: HaloType.serif(
            size: 18,
            italic: true,
            color: HaloColors.amberText,
          ),
        ),
      );
    }
    return KryfoAvatar(seed: seed, size: 36, choice: n.avatarChoice);
  }
}
