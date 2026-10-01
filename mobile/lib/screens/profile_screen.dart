// SPDX-License-Identifier: GPL-3.0-or-later
// profile screen: avatar, kryfo id, the supporter badge when a tier is set,
// and the gear into settings.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'avatar_picker_screen.dart';
import '../main.dart' show appState, session, showAddContact;
import '../supporter.dart';
import '../widgets/kryfo_avatar.dart';
import 'settings_screen.dart';
import 'donate_screen.dart';
import 'my_kryfo_screen.dart';
import '../widgets/ease_size.dart';
import '../widgets/motion.dart' show haloRoute, kHouseCurve, kHouseTime;
import '../widgets/copied_mark.dart';
import '../widgets/halo_rows.dart';
import '../widgets/press_scale.dart';
import '../widgets/unfold.dart';
import '../l10n/l10n.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onOpenSupport;
  const ProfileScreen({super.key, this.onOpenSupport});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  SupporterTier _tier = SupporterTier.none;
  bool _showSelf = false;
  bool _share = false;
  // bumped on each copy, so its row shows a tick for a moment
  int _idCopies = 0;
  int _onionCopies = 0;

  late final AnimationController _intro;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    // the badge glows a few times when it is shown, then rests
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _loadBadge();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_intro.isAnimating || _intro.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadBadge() async {
    final t = await loadSupporterTier(session.container);
    final self = await loadShowBadgeSelf(session.container);
    final share = await loadShareBadge(session.container);
    if (!mounted) return;
    setState(() {
      _tier = t;
      _showSelf = self;
      _share = share;
    });
    _glow();
  }

  void _glow() {
    if (_tier == SupporterTier.none || !mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    // three breaths out and back, ending where it started
    _pulse.repeat(reverse: true, count: 6);
  }

  void _copy(String text, String what, {bool onion = false}) {
    copySensitive(text);
    HapticFeedback.selectionClick();
    setState(() => onion ? _onionCopies++ : _idCopies++);
    showHaloToast(context, l10n.profileCopied(what));
  }

  // a child that fades and slides up, delayed by [order] so sections stagger
  Widget _reveal(int order, Widget child) {
    final start = (order * 0.12).clamp(0.0, 0.8);
    final anim = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, c) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * 16),
          child: c,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = appState.sessionId;
    final hasBadge = _tier != SupporterTier.none;

    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          l10n.profileProfile,
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
        actions: [
          IconButton(
            tooltip: l10n.commonSettings,
            icon: Icon(Icons.settings_outlined, color: HaloColors.text2),
            onPressed: () =>
                Navigator.of(context).push(haloRoute(SettingsScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _reveal(0, _head(id, hasBadge)),
              const SizedBox(height: 26),

              _reveal(1, _Section(l10n.profileIdentity)),
              _reveal(
                1,
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CopyRow(
                        onTap: () => _copy(id, l10n.profileKryfoId),
                        copies: _idCopies,
                        child: Text(
                          id.isEmpty ? '...' : id,
                          style: HaloType.mono(
                            size: 16,
                            color: HaloColors.amber,
                          ),
                        ),
                      ),
                      if (appState.sessionOnion.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(height: 0.5, color: HaloColors.line),
                        ),
                        _CopyRow(
                          onTap: () => _copy(
                            appState.sessionOnion,
                            l10n.profileOnionAddress,
                            onion: true,
                          ),
                          copies: _onionCopies,
                          child: Text(
                            appState.sessionOnion,
                            style: HaloType.mono(
                              size: 10.5,
                              color: HaloColors.text2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // a tier read after the intro grows in rather than
              // pushing the sections under it down at once
              Unfold(
                open: hasBadge,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _reveal(2, _Section(l10n.profileSupporterBadge)),
                    _reveal(
                      2,
                      HaloGroup(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                _badgePill(_tier, glow: true),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l10n.profileYouAreAThank(tierKey(_tier)),
                                    style: HaloType.sans(
                                      size: 13,
                                      color: HaloColors.text2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // the switch flips at once; the save follows
                          HaloRow(
                            icon: Icons.verified_outlined,
                            label: l10n.profileShowMyBadge,
                            hint: l10n.profileOnMyOwnScreens,
                            toggled: _showSelf,
                            onTap: () {
                              final v = !_showSelf;
                              setState(() => _showSelf = v);
                              if (v) _glow();
                              saveShowBadgeSelf(v, session.container);
                            },
                          ),
                          HaloRow(
                            icon: Icons.people_outline,
                            label: l10n.profileLetContactsSeeIt,
                            hint: l10n.profileOffByDefault,
                            toggled: _share,
                            onTap: () {
                              final v = !_share;
                              setState(() => _share = v);
                              saveShareBadge(v, session.container);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              _reveal(3, _Section(l10n.profileShareConnect)),
              // the same rows as settings: one surface, a tile per row
              _reveal(
                3,
                HaloGroup(
                  children: [
                    HaloRow(
                      icon: Icons.qr_code_2_outlined,
                      label: l10n.profileMyKryfoCode,
                      onTap: () => Navigator.of(
                        context,
                      ).push(haloRoute(const MyKryfoScreen())),
                    ),
                    HaloRow(
                      icon: Icons.person_add_outlined,
                      label: l10n.profileAddContact,
                      onTap: () => showAddContact(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _reveal(
                4,
                _Section(
                  hasBadge ? l10n.profileGiveAgain : l10n.profileSupportKryfo,
                ),
              ),
              _reveal(
                4,
                _SupportCard(
                  label: hasBadge
                      ? l10n.profileKryfoRunsOnWhat
                      : l10n.profileKeepKryfoIndependent,
                  onTap:
                      widget.onOpenSupport ??
                      () => Navigator.of(
                        context,
                      ).push(haloRoute(const DonateScreen())),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // the face, on a soft amber glow, and the name under it
  Widget _head(String id, bool hasBadge) {
    return Column(
      children: [
        ScaleTransition(
          scale: CurvedAnimation(
            parent: _intro,
            curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
          ),
          child: PressScale(
            label: l10n.profileChangeYourFace,
            scale: 0.95,
            onTap: () async {
              await Navigator.of(
                context,
              ).push(haloRoute(const AvatarPickerScreen()));
              if (mounted) setState(() {});
            },
            child: SizedBox(
              width: 150,
              height: 132,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 150,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          HaloColors.amber.withValues(alpha: 0.16),
                          HaloColors.amber.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: HaloColors.amber.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: KryfoAvatar(
                      seed: id.isEmpty ? 'kryfo' : id,
                      size: 96,
                      choice: appState.myAvatar,
                    ),
                  ),
                  PositionedDirectional(
                    end: 26,
                    bottom: 14,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: HaloColors.amber,
                        border: Border.all(
                          color: HaloColors.surface,
                          width: 2.5,
                        ),
                      ),
                      child: Icon(Icons.edit, size: 13, color: HaloColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // the three words are the name
            Flexible(
              child: Text(
                id,
                textAlign: TextAlign.center,
                style: HaloType.mono(size: 16, color: HaloColors.amber),
              ),
            ),
            // the pill pops in on the house curve and out again
            EaseSize(
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : kHouseTime,
                switchInCurve: kHouseCurve,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(scale: a, child: c),
                ),
                child: hasBadge && _showSelf
                    ? Padding(
                        key: const ValueKey('pill'),
                        padding: const EdgeInsetsDirectional.only(start: 8),
                        child: _badgePill(_tier, glow: true),
                      )
                    : const SizedBox.shrink(key: ValueKey('none')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _badgePill(SupporterTier t, {bool glow = false}) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: HaloColors.amberSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HaloColors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tierGlyph(t),
            style: TextStyle(color: HaloColors.amber, fontSize: 10),
          ),
          const SizedBox(width: 4),
          Text(
            tierLabel(t),
            style: HaloType.mono(size: 10, color: HaloColors.amber),
          ),
        ],
      ),
    );
    if (!glow) return pill;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) {
        final g = 0.25 + (_pulse.value * 0.45);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: HaloColors.amber.withValues(alpha: g * 0.5),
                blurRadius: 8 + (_pulse.value * 8),
                spreadRadius: -2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: pill,
    );
  }
}

// one copyable line: the whole row takes the tap, tints while pressed and
// shows a tick once it has copied
class _CopyRow extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final int copies;
  const _CopyRow({
    required this.child,
    required this.onTap,
    required this.copies,
  });
  @override
  State<_CopyRow> createState() => _CopyRowState();
}

class _CopyRowState extends State<_CopyRow> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: still
              ? Duration.zero
              : Duration(milliseconds: _down ? 60 : 220),
          curve: Curves.easeOut,
          color: HaloColors.amber.withValues(alpha: _down ? 0.07 : 0),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(child: widget.child),
              const SizedBox(width: 10),
              CopiedMark(copies: widget.copies),
            ],
          ),
        ),
      ),
    );
  }
}

// a section's surface
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HaloColors.line, width: 0.5),
      ),
      child: child,
    );
  }
}

// the way to support, warmer than the rows around it
class _SupportCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SupportCard({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: 0.98,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              HaloColors.amber.withValues(alpha: 0.16),
              HaloColors.amber.withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(
            color: HaloColors.amber.withValues(alpha: 0.45),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [HaloColors.amber, HaloColors.amberDeep],
                ),
              ),
              child: Text(
                '\u2726',
                style: TextStyle(color: HaloColors.onAmber, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: HaloType.sans(
                  size: 14.5,
                  weight: FontWeight.w600,
                  color: HaloColors.text,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: HaloColors.amber, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  const _Section(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(2, 0, 0, 10),
      child: Text(
        label,
        style: HaloType.mono(size: 10, color: HaloColors.text3),
      ),
    );
  }
}
