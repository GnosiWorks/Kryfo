// SPDX-License-Identifier: GPL-3.0-or-later
// choosing chats to hide: everyday chats and groups, each with a round check.
// the chosen ones leave the list the way an archived chat leaves home.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/kryfo_avatar.dart';
import '../widgets/motion.dart' show houseSpring;
import '../widgets/press_scale.dart';

// a chat the picker offers: a person's or a group's
class HideChoice {
  const HideChoice({
    required this.id,
    required this.name,
    this.group = false,
    this.avatar,
    this.members = 0,
  });

  final String id;
  final String name;
  final bool group;
  // a person's chosen face, null to draw one from the id
  final int? avatar;
  final int members;

  String get key => '${group ? 'g' : 'p'}:$id';
}

// the list and its button. onHide moves the chosen chats and says how many
// went; when it throws the list stays as it was
class HidePicker extends StatefulWidget {
  const HidePicker({
    super.key,
    required this.chats,
    required this.onHide,
    required this.onDone,
    this.line,
    this.onBusy,
  });

  final List<HideChoice> chats;
  final Future<int> Function(List<String> people, List<String> groups) onHide;
  final ValueChanged<int> onDone;
  final String? line;
  final ValueChanged<bool>? onBusy;

  @override
  State<HidePicker> createState() => _HidePickerState();
}

class _HidePickerState extends State<HidePicker> {
  // read once: a list that refreshes while rows leave would cut them short
  late final List<HideChoice> _chats = [...widget.chats];
  final Set<String> _chosen = {};
  final Set<String> _gone = {};
  bool _busy = false;
  String? _error;

  static const _exit = Duration(milliseconds: 260);

  bool get _still => MediaQuery.of(context).disableAnimations;

  void _busyNow(bool b) {
    setState(() => _busy = b);
    widget.onBusy?.call(b);
  }

  void _toggle(HideChoice c) {
    if (_busy) return;
    setState(() {
      _error = null;
      _chosen.contains(c.key) ? _chosen.remove(c.key) : _chosen.add(c.key);
    });
  }

  Future<void> _hide() async {
    if (_busy) return;
    final picked = [
      for (final c in _chats)
        if (_chosen.contains(c.key)) c,
    ];
    if (picked.isEmpty) {
      widget.onDone(0);
      return;
    }
    HapticFeedback.mediumImpact();
    _busyNow(true);
    setState(() => _error = null);
    final int n;
    try {
      n = await widget.onHide(
        [
          for (final c in picked)
            if (!c.group) c.id,
        ],
        [
          for (final c in picked)
            if (c.group) c.id,
        ],
      );
    } catch (_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _error = l10n.flowNotSet);
      _busyNow(false);
      return;
    }
    if (!mounted) return;
    setState(() => _gone.addAll(picked.map((c) => c.key)));
    if (!_still) await Future<void>.delayed(_exit);
    if (!mounted) return;
    _busyNow(false);
    widget.onDone(n);
  }

  @override
  Widget build(BuildContext context) {
    final still = _still;
    final n = _chosen.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          child: Text(
            l10n.flowVaultPickTitle,
            style: HaloType.serif(size: 28, color: HaloColors.text),
          ),
        ),
        if (_error == null && widget.line == null)
          const SizedBox(height: 12)
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: AnimatedSwitcher(
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: Text(
                _error ?? widget.line ?? '',
                key: ValueKey(_error),
                style: HaloType.sans(
                  size: 13.5,
                  color: _error != null ? HaloColors.rose : HaloColors.text2,
                  height: 1.45,
                ),
              ),
            ),
          ),
        Expanded(
          child: _chats.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      l10n.flowVaultPickEmpty,
                      textAlign: TextAlign.center,
                      style: HaloType.serif(
                        size: 18,
                        italic: true,
                        color: HaloColors.text2,
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    for (final c in _chats)
                      _Leaving(
                        key: ValueKey(c.key),
                        gone: _gone.contains(c.key),
                        duration: _exit,
                        child: _PickRow(
                          c: c,
                          on: _chosen.contains(c.key),
                          dim: _busy && _chosen.contains(c.key),
                          onTap: _busy ? null : () => _toggle(c),
                        ),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: _CountButton(
            count: n,
            busy: _busy,
            onTap: _busy ? null : _hide,
          ),
        ),
      ],
    );
  }
}

// the button with the count on it. with nothing chosen it reads quieter, and
// hides nothing
class _CountButton extends StatelessWidget {
  const _CountButton({
    required this.count,
    required this.busy,
    required this.onTap,
  });
  final int count;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final some = count > 0;
    final d = still ? Duration.zero : const Duration(milliseconds: 180);
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: PressScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: d,
          curve: Curves.easeOutCubic,
          height: 50,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: some ? HaloColors.amber : HaloColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: some ? HaloColors.amber : HaloColors.line,
            ),
          ),
          child: AnimatedOpacity(
            opacity: busy ? 0.5 : 1,
            duration: d,
            child: AnimatedSwitcher(
              duration: d,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
              child: Text(
                l10n.flowVaultPickButton(count),
                key: ValueKey(count),
                style: HaloType.sans(
                  size: 15,
                  weight: FontWeight.w600,
                  color: some ? HaloColors.onAmber : HaloColors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.c,
    required this.on,
    required this.dim,
    required this.onTap,
  });
  final HideChoice c;
  final bool on;
  // chosen and on its way: the move is under way
  final bool dim;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return MergeSemantics(
      child: Semantics(
        checked: on,
        child: PressScale(
          onTap: onTap,
          scale: 0.98,
          child: AnimatedOpacity(
            opacity: dim ? 0.45 : 1,
            duration: still ? Duration.zero : const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 9, 22, 9),
              child: Row(
                children: [
                  c.group
                      ? _GroupFace(name: c.name)
                      : KryfoAvatar(seed: c.id, size: 40, choice: c.avatar),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HaloType.sans(
                            size: 14.5,
                            weight: FontWeight.w500,
                            color: HaloColors.text,
                          ),
                        ),
                        if (c.group) ...[
                          const SizedBox(height: 2),
                          Text(
                            l10n.homeMembers(c.members),
                            style: HaloType.mono(
                              size: 10,
                              color: HaloColors.text3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _RoundCheck(on: on),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// a group's face as home draws it: a square tile with its first letter
class _GroupFace extends StatelessWidget {
  const _GroupFace({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: HaloColors.amberSoft,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(
        color: HaloColors.amber.withValues(alpha: 0.35),
        width: 0.6,
      ),
    ),
    child: Text(
      name.isEmpty ? '·' : name.characters.first.toUpperCase(),
      style: HaloType.serif(size: 19, italic: true, color: HaloColors.amber),
    ),
  );
}

// a ring that fills on the house spring, with a little overshoot
class _RoundCheck extends StatefulWidget {
  const _RoundCheck({required this.on});
  final bool on;

  @override
  State<_RoundCheck> createState() => _RoundCheckState();
}

class _RoundCheckState extends State<_RoundCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController.unbounded(
    vsync: this,
    value: widget.on ? 1 : 0,
  );

  @override
  void didUpdateWidget(_RoundCheck old) {
    super.didUpdateWidget(old);
    if (old.on == widget.on) return;
    final to = widget.on ? 1.0 : 0.0;
    if (MediaQuery.of(context).disableAnimations) {
      _fill.value = to;
    } else {
      // the spring stops within a hair of its end: the end itself after
      _fill.animateWith(houseSpring(_fill.value, to, _fill.velocity)).then((_) {
        if (mounted) _fill.value = to;
      });
    }
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fill,
      builder: (_, _) {
        final v = _fill.value;
        final t = v.clamp(0.0, 1.0);
        return SizedBox(
          width: 24,
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Color.lerp(HaloColors.line2, HaloColors.amber, t)!,
                    width: 1.5,
                  ),
                ),
              ),
              Transform.scale(
                scale: v.clamp(0.0, 1.25),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HaloColors.amber,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: HaloColors.onAmber,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// a chosen row on its way out: it slides towards the start and folds away,
// as an archived chat leaves home. with reduced motion it is simply gone
class _Leaving extends StatefulWidget {
  const _Leaving({
    super.key,
    required this.gone,
    required this.duration,
    required this.child,
  });
  final bool gone;
  final Duration duration;
  final Widget child;

  @override
  State<_Leaving> createState() => _LeavingState();
}

class _LeavingState extends State<_Leaving>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.gone ? 1 : 0,
  );
  late final _slide = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.7, curve: Curves.easeInCubic),
  );
  late final _fold = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.35, 1, curve: Curves.easeInOutCubic),
  );

  @override
  void didUpdateWidget(_Leaving old) {
    super.didUpdateWidget(old);
    if (old.gone == widget.gone) return;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = widget.gone ? 1 : 0;
    } else {
      widget.gone ? _c.forward() : _c.reverse();
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    _fold.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = Directionality.of(context) == TextDirection.rtl ? 1.0 : -1.0;
    return SizeTransition(
      sizeFactor: ReverseAnimation(_fold),
      axisAlignment: -1,
      child: FadeTransition(
        opacity: ReverseAnimation(_slide),
        child: SlideTransition(
          position: Tween(
            begin: Offset.zero,
            end: Offset(0.6 * start, 0),
          ).animate(_slide),
          child: widget.child,
        ),
      ),
    );
  }
}

// hide more chats, from inside the vault: the picker on a page of its own
class HidePickerScreen extends StatefulWidget {
  const HidePickerScreen({
    super.key,
    required this.chats,
    required this.onHide,
  });
  final List<HideChoice> chats;
  final Future<int> Function(List<String> people, List<String> groups) onHide;

  @override
  State<HidePickerScreen> createState() => _HidePickerScreenState();
}

class _HidePickerScreenState extends State<HidePickerScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      backgroundColor: HaloColors.ink,
      appBar: AppBar(
        backgroundColor: HaloColors.ink,
        elevation: 0,
        // the page scrolls under it on a small screen: no tint comes in
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
      ),
      body: SafeArea(
        child: HidePicker(
          chats: widget.chats,
          onHide: widget.onHide,
          onBusy: (b) => setState(() => _busy = b),
          onDone: (_) => Navigator.of(context).pop(),
        ),
      ),
    ),
  );
}
