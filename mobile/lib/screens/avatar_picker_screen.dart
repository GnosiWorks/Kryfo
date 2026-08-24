// SPDX-License-Identifier: GPL-3.0-or-later
//
// pick a face. every option is drawn on the phone from a number, so there is
// no image to upload, no camera permission to grant, and nothing about the
// choice ever leaves the device. the one you start on is the one your kryfo
// id already produces, so doing nothing is a real answer.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show appState, showHaloToast;
import '../theme.dart';
import '../widgets/kryfo_avatar.dart';

class AvatarPickerScreen extends StatefulWidget {
  const AvatarPickerScreen({super.key});
  @override
  State<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends State<AvatarPickerScreen> {
  static const _perPage = 24;
  int _page = 0;
  int? _sel;

  @override
  void initState() {
    super.initState();
    _sel = appState.myAvatar;
    if (_sel != null) _page = _sel! ~/ _perPage;
  }

  Future<void> _save() async {
    await appState.setMyAvatar(_sel);
    if (!mounted) return;
    showHaloToast(
      context,
      _sel == null ? 'back to your initial' : 'that one is yours',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final total = avatarChoiceCount;
    final pages = (total / _perPage).ceil();
    final start = _page * _perPage;
    final id = appState.myId;

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
      body: Column(
        children: [
          const SizedBox(height: 6),
          KryfoAvatar(seed: id, size: 84, choice: _sel),
          const SizedBox(height: 12),
          Text(
            '$total to choose from · drawn on this phone',
            style: HaloType.mono(size: 10.5, color: HaloColors.text2),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
              ),
              itemCount: _perPage + (_page == 0 ? 1 : 0),
              itemBuilder: (_, i) {
                // the first tile on the first page hands the initial back,
                // so the original avatar is never lost behind a choice.
                if (_page == 0 && i == 0) {
                  return _Tile(
                    selected: _sel == null,
                    onTap: () => setState(() => _sel = null),
                    child: KryfoAvatar(seed: id, size: 60),
                  );
                }
                final idx = start + i - (_page == 0 ? 1 : 0);
                if (idx >= total) return const SizedBox.shrink();
                return _Tile(
                  selected: _sel == idx,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _sel = idx);
                  },
                  child: KryfoAvatar(seed: id, size: 60, choice: idx),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                _Nav(
                  icon: Icons.chevron_left,
                  on: _page > 0,
                  onTap: () => setState(() => _page--),
                ),
                Expanded(
                  child: Text(
                    '${_page + 1} / $pages',
                    textAlign: TextAlign.center,
                    style: HaloType.mono(size: 11, color: HaloColors.text2),
                  ),
                ),
                _Nav(
                  icon: Icons.chevron_right,
                  on: _page < pages - 1,
                  onTap: () => setState(() => _page++),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  const _Tile({
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
        child: Center(child: child),
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  final IconData icon;
  final bool on;
  final VoidCallback onTap;
  const _Nav({required this.icon, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: on ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: HaloColors.surface2,
          border: Border.all(color: HaloColors.line),
        ),
        child: Icon(
          icon,
          size: 18,
          color: on ? HaloColors.text2 : HaloColors.line2,
        ),
      ),
    );
  }
}
