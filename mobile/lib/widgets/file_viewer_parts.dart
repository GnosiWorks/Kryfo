// SPDX-License-Identifier: GPL-3.0-or-later
// what kryfo's file viewers share: the way they open out of the bubble and
// close back into it, the head with the file's tile and name, and the bar
// that sends it on, saves it or, last and said plainly, hands it to
// another app
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../file_kind.dart';
import '../l10n/l10n.dart';
import '../main.dart' show appState, AppStateScreen;
import '../theme.dart';
import 'file_badge.dart';
import 'halo_hero.dart';
import 'message_menu.dart' show AsideNote;
import 'motion.dart' show kHouseCurve, motionStill;
import 'press_scale.dart';
import 'text_ground.dart';

/// the tag a file's tile shares with its viewer's head, so it flies between
/// them. [id] tells the chat's copy from the files tab's
Object fileHeroTag(String path, [Object? id]) => ('file', path, id);

/// one viewer at a time: a second tap while one opens opens nothing more
bool _opening = false;

/// pushes a file viewer over the chat. it rises out of the bubble as its
/// tile flies to the head, and sinks back the same way. [secure] blocks
/// screenshots while it is up, as a photo of a chat that blocks does
Future<void> openFileViewer(
  BuildContext context,
  WidgetBuilder page, {
  bool secure = false,
}) async {
  if (_opening) return;
  _opening = true;
  FocusManager.instance.primaryFocus?.unfocus();
  final still = motionStill(context);
  HapticFeedback.selectionClick();
  if (secure) await appState.forceSecure(true);
  try {
    if (!context.mounted) return;
    final nav = Navigator.of(context);
    _opening = false;
    await nav.push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: Duration(milliseconds: still ? 0 : 300),
        reverseTransitionDuration: Duration(milliseconds: still ? 0 : 240),
        pageBuilder: (ctx, _, _) => TextGround(child: page(ctx)),
        transitionsBuilder: (_, a, _, child) {
          final c = CurvedAnimation(
            parent: a,
            curve: kHouseCurve,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(c),
              child: ScaleTransition(
                scale: Tween(begin: 0.97, end: 1.0).animate(c),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  } finally {
    _opening = false;
    if (secure) await appState.forceSecure(false);
  }
  FocusManager.instance.primaryFocus?.unfocus();
}

/// the viewer's head: close, the file's tile and name, who sent it and how
/// big it is, and whatever the viewer adds at its end
class FileViewerHead extends StatelessWidget {
  final String shown;
  final FileFacts facts;
  final String sub;
  final Object? heroTag;
  final List<Widget> actions;
  const FileViewerHead({
    super.key,
    required this.shown,
    required this.facts,
    required this.sub,
    this.heroTag,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final badge = FileBadge(facts: facts, size: 34);
    final tag = heroTag;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 10),
      decoration: BoxDecoration(
        color: HaloColors.surface,
        border: Border(bottom: BorderSide(color: HaloColors.line)),
      ),
      child: Row(
        children: [
          ViewerIconButton(
            icon: Icons.close_rounded,
            label: l10n.commonClose,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 6),
          tag == null ? badge : HaloHero(tag: tag, child: badge),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shown,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HaloType.sans(
                    size: 15,
                    weight: FontWeight.w600,
                    color: HaloColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HaloType.mono(size: 10.5, color: HaloColors.text),
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// a round icon button of the viewers' heads
class ViewerIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool on;
  const ViewerIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.on = false,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    return Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: PressScale(
          scale: 0.9,
          onTap: onTap,
          ring: const BorderRadius.all(Radius.circular(22)),
          child: AnimatedContainer(
            duration: still ? Duration.zero : const Duration(milliseconds: 160),
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? HaloColors.amberSoft : HaloColors.surface2,
            ),
            child: Icon(
              icon,
              size: 20,
              color: onTap == null
                  ? HaloColors.text2
                  : on
                  ? HaloColors.amber
                  : HaloColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// the viewer's foot: on to another chat, a save, and the way out to
/// another app with what that means under it. a row without [onTap] is
/// left out
class FileViewerBar extends StatelessWidget {
  final VoidCallback? onForward;
  final VoidCallback? onSave;
  final VoidCallback? onOpenWith;
  const FileViewerBar({
    super.key,
    this.onForward,
    this.onSave,
    this.onOpenWith,
  });

  @override
  Widget build(BuildContext context) {
    final picks = [
      if (onForward != null)
        (Icons.forward_rounded, l10n.chatForward, onForward!),
      if (onSave != null)
        (Icons.download_rounded, l10n.fileSaveToDevice, onSave!),
      if (onOpenWith != null)
        (Icons.open_in_new_rounded, l10n.fileOpenWith, onOpenWith!),
    ];
    if (picks.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: HaloColors.surface,
        border: Border(top: BorderSide(color: HaloColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (final (icon, label, tap) in picks)
                    Expanded(
                      child: _BarPick(icon: icon, label: label, onTap: tap),
                    ),
                ],
              ),
              if (onOpenWith != null) ...[
                const SizedBox(height: 6),
                const OpenWithNote(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BarPick extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BarPick({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: PressScale(
      scale: 0.94,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 21, color: HaloColors.amber),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: HaloType.sans(size: 12, color: HaloColors.text),
            ),
          ],
        ),
      ),
    ),
  );
}

/// what "Open with…" means, said under it wherever it is offered
class OpenWithNote extends StatelessWidget {
  const OpenWithNote({super.key});

  @override
  Widget build(BuildContext context) => AsideNote(l10n.fileOpenWithNote);
}
