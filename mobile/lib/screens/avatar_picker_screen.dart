// SPDX-License-Identifier: GPL-3.0-or-later
//
// pick a face. shape and colour are chosen separately, because scrolling a
// thousand combinations to find the one you wanted is not choosing - the
// twelve shapes were just wearing a hundred outfits each.
//
// every option is drawn on the phone from a number. no image to upload, no
// camera permission, nothing to license. the number rides with your messages
// so the people you talk to see the face you picked.
//
// the editor is split out from the screen because onboarding shows the same
// controls under its own chrome, and two copies would drift.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show appState;
import '../theme.dart';
import '../widgets/avatar_mark.dart';
import '../widgets/kryfo_avatar.dart';

/// the shape / colour / turn controls, with a live preview on top.
/// reports the packed choice, or null for "the initial your id already draws".
class AvatarChoiceEditor extends StatefulWidget {
  final ValueChanged<int?> onChanged;
  final EdgeInsets padding;
  final String caption;
  const AvatarChoiceEditor({
    super.key,
    required this.onChanged,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 32),
    this.caption = 'the people you message see this too',
  });

  @override
  State<AvatarChoiceEditor> createState() => _AvatarChoiceEditorState();
}

class _AvatarChoiceEditorState extends State<AvatarChoiceEditor> {
  // null shape means the initial your id already draws
  int? _shape;
  int _rot = 0;
  int _pal = 0;

  @override
  void initState() {
    super.initState();
    final ch = appState.myAvatar;
    if (ch != null) {
      _rot = ch % rotCount;
      _shape = (ch ~/ rotCount) % markCount;
      _pal = (ch ~/ (rotCount * markCount)) % avatarPaletteCount;
    }
  }

  int? get _choice => _shape == null
      ? null
      : _pal * markCount * rotCount + _shape! * rotCount + _rot;

  void _pick(VoidCallback change) {
    HapticFeedback.selectionClick();
    setState(change);
    widget.onChanged(_choice);
  }

  @override
  Widget build(BuildContext context) {
    final id = appState.myId;
    return ListView(
      padding: widget.padding,
      children: [
        Center(child: KryfoAvatar(seed: id, size: 96, choice: _choice)),
        const SizedBox(height: 10),
        Center(
          child: Text(
            widget.caption,
            textAlign: TextAlign.center,
            style: HaloType.mono(size: 10.5, color: HaloColors.text2),
          ),
        ),
        const SizedBox(height: 26),

        _Label('shape'),
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
        _Label('colour'),
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

        if (_shape != null) ...[
          const SizedBox(height: 26),
          _Label('turn'),
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
                    choice:
                        _pal * markCount * rotCount + _shape! * rotCount + r,
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ],
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
      _choice == null ? 'back to your initial' : 'that one is yours',
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
        title: Text('pick a face', style: HaloType.serif(size: 18)),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'save',
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
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
    );
  }
}
