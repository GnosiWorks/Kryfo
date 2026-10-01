// SPDX-License-Identifier: GPL-3.0-or-later
// pick a face: shape, colour and turn chosen separately. every option is
// drawn on the phone from a number, and the number rides with your messages.
// the editor is its own widget because onboarding shows the same controls.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show appState;
import '../theme.dart';
import '../widgets/stagger_in.dart';
import '../widgets/avatar_mark.dart';
import '../widgets/kryfo_avatar.dart';
import '../widgets/motion.dart' show kHouseCurve, motionStill;
import '../widgets/press_scale.dart';
import '../l10n/l10n.dart';

/// the shape, colour and turn controls under a live preview. reports the
/// packed choice, or null for the initial your id already draws.
class AvatarChoiceEditor extends StatefulWidget {
  final ValueChanged<int?> onChanged;
  final EdgeInsets padding;
  // null is the usual line, looked up when it is drawn
  final String? caption;
  // scrolls with the editor, so a large text size never pushes it off
  final Widget? header;
  const AvatarChoiceEditor({
    super.key,
    required this.onChanged,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 32),
    this.caption,
    this.header,
  });

  @override
  State<AvatarChoiceEditor> createState() => _AvatarChoiceEditorState();
}

class _AvatarChoiceEditorState extends State<AvatarChoiceEditor> {
  // null shape means the initial your id already draws
  int? _shape;
  // the shape the turn row keeps drawing while it folds away
  int _lastShape = 0;
  int _rot = 0;
  int _pal = 0;

  @override
  void initState() {
    super.initState();
    final ch = appState.myAvatar;
    if (ch != null) {
      _rot = ch % rotCount;
      _shape = (ch ~/ rotCount) % markCount;
      _lastShape = _shape!;
      _pal = (ch ~/ (rotCount * markCount)) % avatarPaletteCount;
    }
  }

  int? get _choice => _shape == null
      ? null
      : _pal * markCount * rotCount + _shape! * rotCount + _rot;

  void _pick(VoidCallback change) {
    HapticFeedback.selectionClick();
    setState(change);
    if (_shape != null) _lastShape = _shape!;
    widget.onChanged(_choice);
  }

  // a new face pops in over the last on the house curve; with less
  // movement it only fades
  Widget _preview(String id, bool still) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: still ? 160 : 300),
      switchInCurve: kHouseCurve,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => still
          ? FadeTransition(opacity: anim, child: child)
          : FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween(begin: 0.82, end: 1.0).animate(anim),
                child: child,
              ),
            ),
      child: KryfoAvatar(
        key: ValueKey(_choice),
        seed: id,
        size: 96,
        choice: _choice,
      ),
    );
  }

  Widget _turnRow(String id) {
    final shape = _shape ?? _lastShape;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        _Label(l10n.avatarPickerTurn),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var r = 0; r < rotCount; r++) ...[
              _Swatch(
                selected: _rot == r,
                onTap: () => _pick(() => _rot = r),
                child: KryfoAvatar(
                  seed: id,
                  size: 50,
                  choice: _pal * markCount * rotCount + shape * rotCount + r,
                ),
              ),
              const SizedBox(width: 12),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = appState.sessionId;
    final still = motionStill(context);
    return ListView(
      padding: widget.padding,
      children: [
        ?widget.header,
        ...staggerAll([
          Center(child: _preview(id, still)),
          const SizedBox(height: 10),
          Center(
            child: Text(
              widget.caption ?? l10n.avatarPickerThePeopleYouMessage,
              textAlign: TextAlign.center,
              style: HaloType.mono(size: 10.5, color: HaloColors.text2),
            ),
          ),
          const SizedBox(height: 26),

          _Label(l10n.avatarPickerShape),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Swatch(
                selected: _shape == null,
                onTap: () => _pick(() => _shape = null),
                child: KryfoAvatar(seed: id, size: 50),
              ),
              for (var m = 0; m < markCount; m++)
                _Swatch(
                  selected: _shape == m,
                  onTap: () => _pick(() => _shape = m),
                  child: KryfoAvatar(
                    seed: id,
                    size: 50,
                    choice: _pal * markCount * rotCount + m * rotCount + _rot,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 26),
          _Label(l10n.avatarPickerColour),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var p = 0; p < avatarPaletteCount; p++)
                _Swatch(
                  selected: _pal == p,
                  onTap: () => _pick(() => _pal = p),
                  child: KryfoAvatar(
                    seed: id,
                    size: 50,
                    choice:
                        p * markCount * rotCount +
                        (_shape ?? 0) * rotCount +
                        _rot,
                  ),
                ),
            ],
          ),

          // the turn row opens and folds with the page instead of jumping it
          if (still)
            _shape != null ? _turnRow(id) : const SizedBox.shrink()
          else
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 260),
              sizeCurve: Curves.easeOutCubic,
              firstCurve: Curves.easeOutCubic,
              secondCurve: Curves.easeOutCubic,
              alignment: AlignmentDirectional.topStart,
              crossFadeState: _shape == null
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: _turnRow(id),
            ),
        ]),
      ],
    );
  }
}

class AvatarPickerScreen extends StatefulWidget {
  const AvatarPickerScreen({super.key});
  @override
  State<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends State<AvatarPickerScreen> {
  late int? _choice = appState.myAvatar;

  Future<void> _save() async {
    await appState.setMyAvatar(_choice);
    if (!mounted) return;
    showHaloToast(
      context,
      _choice == null
          ? l10n.avatarPickerBackToYourInitial
          : l10n.avatarPickerThatOneIsYours,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        title: Text(l10n.avatarPickerPickAFace, style: HaloType.pageTitle()),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              l10n.commonSave,
              style: HaloType.mono(
                size: 12.5,
                color: HaloColors.amber,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: AvatarChoiceEditor(onChanged: (c) => _choice = c),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: HaloType.mono(
      size: 11,
      color: HaloColors.text2,
      letter: 0.14,
      weight: FontWeight.w600,
    ),
  );
}

class _Swatch extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  const _Swatch({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: PressScale(
        onTap: onTap,
        scale: 0.92,
        // the pick already clicks
        haptic: false,
        child: AnimatedContainer(
          duration: motionStill(context)
              ? Duration.zero
              : const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? HaloColors.amber : Colors.transparent,
              width: 2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
