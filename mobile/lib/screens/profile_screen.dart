// SPDX-License-Identifier: GPL-3.0-or-later
// profile screen. telegram-style: big avatar, kryfo id, display name,
// supporter badge block (only if a tier is set), gear into settings.
// staggered fade-up reveal, avatar scale-in, badge glow pulse.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'avatar_picker_screen.dart';
import '../main.dart' show appState, showAddContact;
import '../supporter.dart';
import '../widgets/kryfo_avatar.dart';
import 'settings_screen.dart';
import 'donate_screen.dart';
import 'my_kryfo_screen.dart';
import '../widgets/motion.dart' show haloRoute;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  SupporterTier _tier = SupporterTier.none;
  bool _showSelf = false;
  bool _share = false;

  late final AnimationController _intro;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _loadBadge();
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadBadge() async {
    final t = await loadSupporterTier();
    final self = await loadShowBadgeSelf();
    final share = await loadShareBadge();
    if (!mounted) return;
    setState(() {
      _tier = t;
      _showSelf = self;
      _share = share;
    });
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    showHaloToast(context, '$what copied');
  }

  // a child that fades + slides up, delayed by [order] so sections stagger.
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

  Future<void> _editDisplayName() async {
    final ctrl = TextEditingController(text: appState.displayName);
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HaloColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'display name',
              style: HaloType.serif(size: 18, color: HaloColors.text),
            ),
            const SizedBox(height: 6),
            Text(
              'a name you choose for yourself. it never leaves this phone - contacts always see the name they gave you, never this one. that way nobody can impersonate someone just by renaming themselves.',
              style: HaloType.sans(
                size: 12,
                color: HaloColors.text2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 32,
              style: HaloType.serif(
                size: 20,
                italic: true,
                color: HaloColors.text,
              ),
              cursorColor: HaloColors.amber,
              decoration: InputDecoration(
                hintText: 'your name',
                counterText: '',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: HaloColors.line, width: 0.5),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: HaloColors.amber, width: 0.8),
                ),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                  child: Text(
                    'save',
                    style: HaloType.sans(
                      size: 14,
                      weight: FontWeight.w600,
                      color: HaloColors.amber,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (name == null) return;
    await appState.setDisplayName(name);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final id = appState.myId;
    final name = appState.displayName;
    final hasBadge = _tier != SupporterTier.none;

    return Scaffold(
      backgroundColor: HaloColors.ink,
      appBar: AppBar(
        backgroundColor: HaloColors.ink,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          'profile',
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: HaloColors.text2),
            onPressed: () =>
                Navigator.of(context).push(haloRoute(SettingsScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _reveal(
                0,
                Center(
                  child: Column(
                    children: [
                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _intro,
                          curve: const Interval(
                            0.0,
                            0.7,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            await Navigator.of(
                              context,
                            ).push(haloRoute(const AvatarPickerScreen()));
                            if (mounted) setState(() {});
                          },
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              KryfoAvatar(
                                seed: id.isEmpty ? 'kryfo' : id,
                                size: 96,
                                choice: appState.myAvatar,
                              ),
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: HaloColors.amber,
                                  border: Border.all(
                                    color: HaloColors.surface,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.edit,
                                  size: 12,
                                  color: HaloColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _editDisplayName,
                              child: Text(
                                name.isEmpty ? 'no name set' : name,
                                style: HaloType.serif(
                                  size: 22,
                                  color: name.isEmpty
                                      ? HaloColors.text3
                                      : HaloColors.text,
                                ),
                              ),
                            ),
                          ),
                          if (hasBadge && _showSelf) ...[
                            const SizedBox(width: 8),
                            _badgePill(_tier, glow: true),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _reveal(1, const _Section('identity')),
              _reveal(
                1,
                Container(
                  decoration: BoxDecoration(
                    color: HaloColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HaloColors.line, width: 0.5),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PressRow(
                        onTap: () => _copy(id, 'kryfo id'),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                id.isEmpty ? '...' : id,
                                style: HaloType.mono(
                                  size: 16,
                                  color: HaloColors.amber,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.copy_outlined,
                              color: Color(0xFF6B625A),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                      if (appState.myOnion.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Divider(color: HaloColors.line, height: 1),
                        const SizedBox(height: 12),
                        _PressRow(
                          onTap: () => _copy(appState.myOnion, 'onion address'),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  appState.myOnion,
                                  style: HaloType.mono(
                                    size: 10,
                                    color: HaloColors.text2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.copy_outlined,
                                color: Color(0xFF6B625A),
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (hasBadge) ...[
                _reveal(2, const _Section('supporter badge')),
                _reveal(
                  2,
                  Container(
                    decoration: BoxDecoration(
                      color: HaloColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HaloColors.line, width: 0.5),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _badgePill(_tier, glow: true),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'you are a ${tierName(_tier)}. thank you.',
                                style: HaloType.sans(
                                  size: 13,
                                  color: HaloColors.text2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _toggleRow(
                          'show my badge',
                          'on my own screens',
                          _showSelf,
                          (v) async {
                            await saveShowBadgeSelf(v);
                            setState(() => _showSelf = v);
                          },
                        ),
                        const SizedBox(height: 10),
                        _toggleRow(
                          'let contacts see it',
                          'off by default',
                          _share,
                          (v) async {
                            await saveShareBadge(v);
                            setState(() => _share = v);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              _reveal(3, const _Section('share & connect')),
              const SizedBox(height: 8),
              _reveal(
                3,
                _PressRow(
                  onTap: () => Navigator.of(
                    context,
                  ).push(haloRoute(const MyKryfoScreen())),
                  child: Container(
                    decoration: BoxDecoration(
                      color: HaloColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HaloColors.line, width: 0.5),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.qr_code_2_outlined,
                          color: HaloColors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'my kryfo code',
                            style: HaloType.sans(
                              size: 14,
                              color: HaloColors.text,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: HaloColors.text3,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _reveal(
                3,
                _PressRow(
                  onTap: () => showAddContact(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: HaloColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HaloColors.line, width: 0.5),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_add_outlined,
                          color: HaloColors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'add contact',
                            style: HaloType.sans(
                              size: 14,
                              color: HaloColors.text,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: HaloColors.text3,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _reveal(3, _Section(hasBadge ? 'give again' : 'support kryfo')),
              _reveal(
                3,
                _PressRow(
                  onTap: () => Navigator.of(
                    context,
                  ).push(haloRoute(const DonateScreen())),
                  child: Container(
                    decoration: BoxDecoration(
                      color: HaloColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HaloColors.line, width: 0.5),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          '\u2726',
                          style: TextStyle(
                            color: HaloColors.amber,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            hasBadge
                                ? 'kryfo runs on what people give'
                                : 'keep kryfo independent',
                            style: HaloType.sans(
                              size: 14,
                              color: HaloColors.text,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: HaloColors.text3,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgePill(SupporterTier t, {bool glow = false}) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x24F59E0B),
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
            tierName(t),
            style: HaloType.mono(size: 8, color: HaloColors.amber),
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

  Widget _toggleRow(
    String label,
    String sub,
    bool value,
    Future<void> Function(bool) onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: HaloType.sans(size: 13, color: HaloColors.text),
              ),
              const SizedBox(height: 2),
              Text(sub, style: HaloType.mono(size: 9, color: HaloColors.text3)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: (v) => onChanged(v),
          activeColor: const Color(0xFF1A0F04),
          activeTrackColor: HaloColors.amber,
          inactiveThumbColor: HaloColors.text3,
          inactiveTrackColor: HaloColors.surface3,
        ),
      ],
    );
  }
}

// tap target that scales down slightly on press for tactile feel.
class _PressRow extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressRow({required this.child, required this.onTap});
  @override
  State<_PressRow> createState() => _PressRowState();
}

class _PressRowState extends State<_PressRow> {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
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
      padding: const EdgeInsets.fromLTRB(2, 0, 0, 10),
      child: Text(
        label,
        style: HaloType.mono(size: 10, color: HaloColors.text3),
      ),
    );
  }
}
