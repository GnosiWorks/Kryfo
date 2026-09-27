// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../main.dart' show appState;
import '../widgets/breathing_ring.dart';
import '../widgets/burn_fade.dart' show FadeFold;
import '../widgets/kryfo_avatar.dart';
import '../widgets/press_scale.dart';
import '../widgets/stagger_in.dart';
import '../widgets/swap.dart';
import '../l10n/l10n.dart';

// blocked contacts. blocking never notifies the other side. an unblocked
// row folds away before the list is read again
class BlockedScreen extends StatefulWidget {
  const BlockedScreen({super.key});

  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  List<({String haloId, String? nickname})> _blocked = [];
  bool _loading = true;
  final Set<String> _leaving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await appState.blockedContacts();
    if (mounted) {
      setState(() {
        _blocked = list;
        _loading = false;
      });
    }
  }

  Future<void> _unblock(String haloId) async {
    if (!_leaving.add(haloId)) return;
    setState(() {});
    await appState.unblock(haloId);
    await Future.delayed(FadeFold.gone);
    await _load();
    _leaving.remove(haloId);
  }

  // the face they have in the chat list, when there is one
  int? _face(String haloId) {
    for (final c in appState.contacts) {
      if (c.haloId == haloId) return c.avatar;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.commonBack,
                    icon: Icon(
                      Icons.chevron_left,
                      color: HaloColors.text2,
                      size: 26,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    l10n.blockedBlocked,
                    style: HaloType.serif(size: 22, color: HaloColors.text),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const SizedBox()
                  // the last one unblocked, the empty page fades in
                  : FadeSwap(
                      child: _blocked.isEmpty
                          ? KeyedSubtree(
                              key: const ValueKey('none'),
                              child: _empty(),
                            )
                          : ListView(
                              key: const ValueKey('rows'),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              children: [
                                for (final (i, c) in _blocked.indexed)
                                  StaggerIn(
                                    key: ValueKey(c.haloId),
                                    index: i,
                                    child: IgnorePointer(
                                      ignoring: _leaving.contains(c.haloId),
                                      child: FadeFold(
                                        leaving: _leaving.contains(c.haloId),
                                        child: _row(c),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(({String haloId, String? nickname}) c) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 16, 10),
      child: Row(
        children: [
          KryfoAvatar(seed: c.haloId, size: 38, choice: _face(c.haloId)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.nickname ?? c.haloId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HaloType.sans(size: 14, weight: FontWeight.w500),
                ),
                if (c.nickname != null)
                  Text(
                    c.haloId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.mono(size: 10, color: HaloColors.text3),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          PressScale(
            label: l10n.commonUnblock,
            scale: 0.94,
            onTap: () {
              HapticFeedback.lightImpact();
              _unblock(c.haloId);
            },
            haptic: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: HaloColors.amber.withValues(alpha: 0.45),
                ),
              ),
              child: ExcludeSemantics(
                child: Text(
                  l10n.commonUnblock,
                  style: HaloType.sans(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: HaloColors.amber,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: staggerAll([
            BreathingRing(
              size: 98,
              core: 66,
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: HaloColors.amberSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.do_not_disturb_on_outlined,
                  color: HaloColors.amber,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.blockedNoOneIsBlocked,
              textAlign: TextAlign.center,
              style: HaloType.serif(
                size: 20,
                italic: true,
                color: HaloColors.text2,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
