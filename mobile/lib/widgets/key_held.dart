// SPDX-License-Identifier: GPL-3.0-or-later
// a contact verified under one key who holds another now: nothing goes to
// them until the new number is checked or the new key accepted. the notice,
// the mark that stands for it on a row, and the two ways out of it
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dlog.dart';
import '../l10n/l10n.dart';
import '../main.dart' show appState, session;
import '../screens/key_verification_screen.dart';
import '../theme.dart';
import 'confirm_sheet.dart';
import 'halo_sheet.dart';
import 'motion.dart' show haloRoute, motionStill;
import 'press_scale.dart';
import 'sheet_handle.dart';

// whether the open session holds them, for the screens. a read that fails
// shows nothing: the seal reads again, and waits on a read that fails
Future<bool> keyHeldShown(String peer) async {
  try {
    return await session.keyHeld(peer);
  } catch (e) {
    dlog('key hold: not shown (${e.runtimeType})');
    return false;
  }
}

// everyone the open session holds, for a list. none when it cannot be read
Future<Set<String>> keysHeldShown() async {
  try {
    return await session.heldPeers();
  } catch (e) {
    dlog('key hold: none shown (${e.runtimeType})');
    return const {};
  }
}

// the new key taken as it is, once asked. true when it was
Future<bool> acceptNewKeyAsked(
  BuildContext context,
  String peer,
  String name,
) async {
  final ok = await showConfirmSheet(
    context,
    title: l10n.chatAcceptNewKeyTitle,
    line: l10n.chatAcceptNewKeyLine(name),
    yes: l10n.chatAcceptNewKey,
    rose: false,
  );
  if (!ok) return false;
  await appState.acceptNewKey(peer);
  HapticFeedback.mediumImpact();
  unawaited(appState.refreshContacts());
  unawaited(appState.drainOutbox());
  return true;
}

// the safety number page, with the key their row holds
Future<void> checkTheNumber(
  BuildContext context,
  String peer,
  String name,
) async {
  final row = await session.getContact(peer);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    haloRoute(
      KeyVerificationScreen(
        peerHaloId: peer,
        peerName: name,
        myXpub: appState.sessionXPub,
        peerXpub: (row?['xpub'] as String?) ?? '',
        initialVerified: (row?['verified'] as int? ?? 0) == 1,
      ),
    ),
  );
  // checked there: what waited for it goes now
  unawaited(appState.drainOutbox());
}

enum _Way { check, accept }

// the notice on a sheet, for a row that only carries the mark. true when
// they are no longer held after it
Future<bool> showKeyHeldSheet(
  BuildContext context,
  String peer,
  String name,
) async {
  final way = await showHaloSheet<_Way>(
    context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          KeyHeldCard(
            peerName: name,
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            onCheck: () => Navigator.pop(ctx, _Way.check),
            onAccept: () => Navigator.pop(ctx, _Way.accept),
          ),
        ],
      ),
    ),
  );
  if (way == null || !context.mounted) return false;
  if (way == _Way.accept) {
    if (!await acceptNewKeyAsked(context, peer, name)) return false;
  } else {
    await checkTheNumber(context, peer, name);
  }
  return !await keyHeldShown(peer);
}

// the notice itself: what happened, what it means, and the two ways out
class KeyHeldCard extends StatelessWidget {
  final String peerName;
  final VoidCallback onCheck;
  final VoidCallback onAccept;
  final EdgeInsetsGeometry margin;
  const KeyHeldCard({
    super.key,
    required this.peerName,
    required this.onCheck,
    required this.onAccept,
    this.margin = const EdgeInsets.fromLTRB(14, 8, 14, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: HaloColors.amber.withValues(alpha: 0.10),
        border: Border.all(color: HaloColors.amber.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.gpp_maybe_outlined, size: 16, color: HaloColors.amber),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.chatSecurityCodeChanged,
                  style: HaloType.serif(size: 14.5, color: HaloColors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.chatKeyHeldLine(peerName),
            style: HaloType.sans(size: 13, color: HaloColors.text, height: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _Btn(
                  label: l10n.chatAcceptNewKey,
                  fg: HaloColors.text,
                  bg: HaloColors.surface2,
                  onTap: onAccept,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _Btn(
                  label: l10n.chatCheckTheNumber,
                  fg: HaloColors.onAmber,
                  bg: HaloColors.amber,
                  onTap: onCheck,
                  bold: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  final VoidCallback onTap;
  final bool bold;
  const _Btn({
    required this.label,
    required this.fg,
    required this.bg,
    required this.onTap,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: 0.96,
      haptic: false,
      label: label,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: bg == HaloColors.surface2
              ? Border.all(color: HaloColors.line, width: 0.5)
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: HaloType.sans(
              size: 13,
              color: fg,
            ).copyWith(fontWeight: bold ? FontWeight.w600 : FontWeight.w400),
          ),
        ),
      ),
    );
  }
}

// the mark on a row: a person there is held. it comes and goes with a fade
// and a small rise, or at once with less motion
class KeyHeldMark extends StatelessWidget {
  final bool on;
  const KeyHeldMark({super.key, required this.on});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return AnimatedSwitcher(
      duration: still ? Duration.zero : const Duration(milliseconds: 220),
      reverseDuration: still
          ? Duration.zero
          : const Duration(milliseconds: 140),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SizeTransition(
          sizeFactor: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
          axisAlignment: -1,
          child: child,
        ),
      ),
      child: on
          ? Padding(
              key: const ValueKey(true),
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.gpp_maybe_outlined,
                    size: 12,
                    color: HaloColors.amber,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      l10n.chatSecurityCodeChanged,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.sans(size: 11.5, color: HaloColors.amber),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox(key: ValueKey(false), width: 0, height: 0),
    );
  }
}
