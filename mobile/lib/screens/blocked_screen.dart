// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../key_number.dart';
import '../main.dart' show appState;
import '../widgets/breathing_ring.dart';
import '../widgets/burn_fade.dart' show FadeFold;
import '../widgets/kryfo_avatar.dart';
import '../widgets/press_scale.dart';
import '../widgets/stagger_in.dart';
import '../widgets/swap.dart';
import '../l10n/l10n.dart';
import '../l10n/dates.dart' show dayMonthMaybeYear;

// blocked contacts, and the keys "this isn't them" blocked, by their key
// number. blocking never notifies the other side. an unblocked row folds
// away before the list is read again
class BlockedScreen extends StatefulWidget {
  const BlockedScreen({super.key});

  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  List<({String haloId, String? nickname})> _blocked = [];
  List<({String x, int at})> _keys = [];
  bool _loading = true;
  final Set<String> _leaving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await appState.blockedContacts();
    final keys = await appState.blockedKeys();
    if (mounted) {
      setState(() {
        _blocked = list;
        _keys = keys;
        _loading = false;
      });
    }
  }

  Future<void> _unblockKey(String x) async {
    final at = 'key:$x';
    if (!_leaving.add(at)) return;
    setState(() {});
    await appState.unblockKey(x);
    await Future.delayed(FadeFold.gone);
    await _load();
    _leaving.remove(at);
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
                  Flexible(
                    child: Text(
                      l10n.blockedBlocked,
                      style: HaloType.pageTitle(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const SizedBox()
                  // the last one unblocked, the empty page fades in
                  : FadeSwap(
                      child: _blocked.isEmpty && _keys.isEmpty
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
                                for (final (i, k) in _keys.indexed)
                                  StaggerIn(
                                    key: ValueKey('key:${k.x}'),
                                    index: _blocked.length + i,
                                    child: IgnorePointer(
                                      ignoring: _leaving.contains('key:${k.x}'),
                                      child: FadeFold(
                                        leaving: _leaving.contains(
                                          'key:${k.x}',
                                        ),
                                        child: _keyRow(k.x, k.at),
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
                    style: HaloType.mono(size: 10, color: HaloColors.text2),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _unblockButton(() => _unblock(c.haloId)),
        ],
      ),
    );
  }

  // a key blocked with no one's name on it: the number it shows as
  Widget _keyRow(String x, int at) {
    final number = keyNumber(_bytes(x)) ?? x;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 16, 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: HaloColors.surface2,
              shape: BoxShape.circle,
              border: Border.all(color: HaloColors.line, width: 0.5),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.key_off_outlined,
              size: 18,
              color: HaloColors.rose,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          l10n.blockedKey,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HaloType.sans(
                            size: 14,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dayMonthMaybeYear(
                          DateTime.fromMillisecondsSinceEpoch(at),
                        ),
                        style: HaloType.sans(size: 12, color: HaloColors.text2),
                      ),
                    ],
                  ),
                  // the same digits in every language, as on a pair code
                  Semantics(
                    label: '${l10n.pairCodeKeyNumber} $number',
                    textDirection: TextDirection.ltr,
                    excludeSemantics: true,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        number,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HaloType.mono(
                          size: 10.5,
                          color: HaloColors.text2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _unblockButton(() => _unblockKey(x)),
        ],
      ),
    );
  }

  static List<int> _bytes(String hex) => [
    for (var i = 0; i + 1 < hex.length; i += 2)
      int.tryParse(hex.substring(i, i + 2), radix: 16) ?? 0,
  ];

  Widget _unblockButton(VoidCallback onTap) {
    return PressScale(
      label: l10n.commonUnblock,
      scale: 0.94,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      haptic: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: HaloColors.amber.withValues(alpha: 0.45)),
        ),
        child: ExcludeSemantics(
          child: Text(
            l10n.commonUnblock,
            style: HaloType.sans(
              size: 12.5,
              weight: FontWeight.w600,
              color: HaloColors.amberText,
            ),
          ),
        ),
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
