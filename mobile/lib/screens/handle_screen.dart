// SPDX-License-Identifier: GPL-3.0-or-later
// claim a public handle. the one screen that makes someone findable by
// strangers, so it says what that costs first and is off until asked for.
// claiming or deleting fades one page into the other.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../handle_repoint.dart' show handleRefusalLine;
import '../main.dart' show appState, engine, sessionQuiet;
import '../theme.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/copied_mark.dart';
import '../widgets/ease_size.dart';
import '../widgets/halo_bar.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/halo_switch.dart';
import '../widgets/motion.dart' show motionStill;
import '../widgets/press_scale.dart';
import '../widgets/stagger_in.dart';
import '../widgets/swap.dart';
import '../l10n/l10n.dart';

class HandleScreen extends StatefulWidget {
  const HandleScreen({super.key});
  @override
  State<HandleScreen> createState() => _HandleScreenState();
}

class _HandleScreenState extends State<HandleScreen> {
  final _ctrl = TextEditingController();
  final _bio = TextEditingController();
  Timer? _debounce;
  String _state = ''; // '', checking, free, taken, error text
  bool _busy = false;
  String? _claimed;

  @override
  void initState() {
    super.initState();
    _claimed = appState.myHandle;
    if (_claimed != null) {
      _ctrl.text = _claimed!;
      // ask the registry whose it is, so the card below tells the truth
      appState.checkHandle().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _onTyped(String v) {
    _debounce?.cancel();
    final h = v.trim().toLowerCase();
    if (h.isEmpty) {
      setState(() => _state = '');
      return;
    }
    // a name the registry would refuse is never asked about
    if (!_shape.hasMatch(h)) {
      setState(() => _state = 'shape');
      return;
    }
    setState(() => _state = 'checking');
    // wait for typing to stop before asking the registry
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      // a quiet session never reaches the registry: it answers as an
      // unreachable one would
      final r = sessionQuiet ? _unreached : await engine.handleCheck(h);
      if (!mounted) return;
      setState(() => _state = r);
    });
  }

  Future<void> _claim() async {
    final h = _ctrl.text.trim().toLowerCase();
    if (h.isEmpty || _state != 'free') return;
    setState(() => _busy = true);
    // same invite the qr code carries, so the registry only holds what is
    // already public
    final uri = await appState.sessionInvite();
    final r = sessionQuiet
        ? _unreached
        : await engine.handleClaim(h, uri, _bio.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == 'ok') {
      await appState.setMyHandle(h, bio: _bio.text.trim(), invite: uri);
      if (!mounted) return;
      setState(() => _claimed = h);
      showHaloToast(context, l10n.handleYouAre(h));
    } else {
      showHaloToast(context, handleRefusalLine(r, h));
    }
  }

  // the name is on this phone and under another key at the registry.
  // nothing here can release it; all that can be done is stop claiming it.
  Future<void> _forget() async {
    await appState.setMyHandle(null);
    if (!mounted) return;
    setState(() {
      _claimed = null;
      _ctrl.clear();
      _state = '';
    });
  }

  Future<void> _release() async {
    final h = _claimed;
    if (h == null) return;
    // the name goes back to the registry for anyone to take: asked first
    final sure = await showConfirmSheet(
      context,
      title: l10n.handleDeleteTitle(h),
      line: l10n.handleDeleteLine,
      yes: l10n.handleDeleteYes,
    );
    if (!sure || !mounted || _claimed != h) return;
    setState(() => _busy = true);
    final r = sessionQuiet ? _unreached : await engine.handleRelease(h);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == 'ok') {
      await appState.setMyHandle(null);
      if (!mounted) return;
      setState(() {
        _claimed = null;
        _ctrl.clear();
        _state = '';
      });
      showHaloToast(context, l10n.handleHandleDeletedThePage);
    } else {
      showHaloToast(context, handleRefusalLine(r, h));
    }
  }

  static const _unreached = 'error: bad answer from the registry';
  static final _shape = RegExp(r'^[a-z0-9_]{3,20}$');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        title: Text(
          l10n.handlePublicHandle,
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          FadeSwap(
            child: KeyedSubtree(
              key: ValueKey(
                _claimed == null
                    ? 'claim'
                    : appState.handleForeign
                    ? 'foreign'
                    : 'claimed',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: staggerAll(_page()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _page() {
    final free = _state == 'free';
    if (_claimed != null && appState.handleForeign) {
      return [
        _ForeignCard(handle: _claimed!, onForget: _forget),
        const SizedBox(height: 22),
      ];
    }
    if (_claimed != null) {
      return [
        _ClaimedCard(handle: _claimed!, busy: _busy, onRelease: _release),
        const SizedBox(height: 14),
        _ListingCard(handle: _claimed!),
        const SizedBox(height: 22),
      ];
    }
    return [
      Text(
        l10n.handleOptionalYourThreeWords,
        style: HaloType.sans(size: 13.5, color: HaloColors.text2),
      ),
      const SizedBox(height: 20),
      _Field(
        ctrl: _ctrl,
        hint: l10n.handleWren,
        prefix: '@',
        onChanged: _onTyped,
        max: 20,
      ),
      const SizedBox(height: 8),
      _Availability(state: _state),
      const SizedBox(height: 18),
      _Field(ctrl: _bio, hint: l10n.handleALineAboutYou, max: 200, lines: 2),
      const SizedBox(height: 22),
      const _RiskBlock(),
      const SizedBox(height: 20),
      // fills once the name is free
      HaloPrimaryButton(
        label: _busy ? l10n.handleClaiming : l10n.handleClaimThisHandle,
        busy: _busy,
        onTap: free ? _claim : null,
      ),
    ];
  }
}

// being findable is a second choice after having a handle, off until made.
// on asks for a name to show beside the handle, and says what it costs.
class _ListingCard extends StatefulWidget {
  final String handle;
  const _ListingCard({required this.handle});
  @override
  State<_ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<_ListingCard> {
  bool _busy = false;

  Future<void> _set(bool on) async {
    var name = '';
    if (on) {
      final n = await showInputSheet(
        context,
        title: l10n.handleNameInSearch,
        line: l10n.handleNameInSearchLine,
        hint: l10n.handleNameHint,
        save: l10n.handleShowMe,
        initial: appState.handleName,
        maxLength: 40,
      );
      if (n == null || !mounted) return;
      name = n;
    }
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    final r = await appState.setHandleListing(on, name: name);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == 'ok') {
      HapticFeedback.lightImpact();
      showHaloToast(
        context,
        on ? l10n.handleSearchOn(widget.handle) : l10n.handleSearchOff,
      );
    } else {
      showHaloToast(context, l10n.handleRegistryFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = appState.handleListed;
    final name = appState.handleName;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        color: on
            ? Color.alphaBlend(
                HaloColors.amber.withValues(alpha: 0.07),
                HaloColors.surface2,
              )
            : HaloColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: on ? HaloColors.amber.withValues(alpha: 0.5) : HaloColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.handleShowInSearch,
                      style: HaloType.sans(
                        size: 15,
                        weight: FontWeight.w600,
                        color: HaloColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.handleShowInSearchLine,
                      style: HaloType.sans(
                        size: 12.5,
                        color: HaloColors.text2,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: _busy ? 0.4 : 1,
                child: IgnorePointer(
                  ignoring: _busy,
                  child: HaloSwitch(value: on, onChanged: _set),
                ),
              ),
            ],
          ),
          EaseSize(
            duration: const Duration(milliseconds: 220),
            child: _busy
                ? const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: HaloBar(value: null, height: 3),
                  )
                : on && name.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      l10n.handleShownAs(name),
                      style: HaloType.mono(size: 11, color: HaloColors.amber),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

// the handle and its public page's link. the link copies, with a tick on
// the row that says it did
class _ClaimedCard extends StatefulWidget {
  final String handle;
  final bool busy;
  final VoidCallback onRelease;
  const _ClaimedCard({
    required this.handle,
    required this.busy,
    required this.onRelease,
  });

  @override
  State<_ClaimedCard> createState() => _ClaimedCardState();
}

class _ClaimedCardState extends State<_ClaimedCard> {
  int _copies = 0;

  @override
  Widget build(BuildContext context) {
    final url = 'https://relay.kryfo.app/@${widget.handle}';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HaloColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined, size: 16, color: HaloColors.green),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  ltr('@${widget.handle}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HaloType.serif(size: 20, color: HaloColors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.handleAnyoneWithThisLink,
            style: HaloType.sans(size: 13, color: HaloColors.text2),
          ),
          const SizedBox(height: 14),
          PressScale(
            scale: 0.98,
            onTap: () {
              copySensitive(url);
              setState(() => _copies++);
              showHaloToast(context, l10n.handleLinkCopied);
            },
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: HaloColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: HaloColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      url,
                      textDirection: TextDirection.ltr,
                      style: HaloType.mono(size: 11, color: HaloColors.text2),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  CopiedMark(copies: _copies),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PressScale(
              scale: 0.97,
              onTap: widget.busy ? null : widget.onRelease,
              child: SizedBox(
                height: 44,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: RiseSwap(
                    child: Text(
                      widget.busy
                          ? l10n.handleDeleting
                          : l10n.handleDeleteThisHandle,
                      key: ValueKey(widget.busy),
                      style: HaloType.mono(size: 12, color: HaloColors.rose),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Availability extends StatelessWidget {
  final String state;
  const _Availability({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isEmpty) return const SizedBox(height: 16);
    late final String txt;
    late final Color c;
    if (state == 'checking') {
      txt = l10n.handleChecking;
      c = HaloColors.text3;
    } else if (state == 'free') {
      txt = l10n.handleAvailable;
      c = HaloColors.green;
    } else if (state == 'taken') {
      txt = l10n.handleAlreadyTaken;
      c = HaloColors.rose;
    } else if (state == 'shape') {
      txt = l10n.handleNameRule;
      c = HaloColors.amber;
    } else {
      // a fixed line, whatever the engine or the registry said
      txt = l10n.handleRegistryFailed;
      c = HaloColors.amber;
    }
    // each answer rises in over the last as the name is typed; a longer
    // one makes room for itself
    final line = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 16),
      child: RiseSwap(
        child: Text(
          txt,
          key: ValueKey(txt),
          style: HaloType.mono(size: 11, color: c),
        ),
      ),
    );
    // with less movement the room is simply there
    if (motionStill(context)) return line;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: AlignmentDirectional.topStart,
      child: line,
    );
  }
}

class _RiskBlock extends StatelessWidget {
  const _RiskBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      decoration: BoxDecoration(
        color: HaloColors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HaloColors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.handleWhatAHandleDoes,
            style: HaloType.mono(
              size: 11,
              color: HaloColors.amber,
              weight: FontWeight.w600,
              letter: 0.1,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            l10n.handleAnyoneWhoKnowsIt,
            style: HaloType.sans(size: 12.5, color: HaloColors.text2),
          ),
        ],
      ),
    );
  }
}

// lights up while it is typed in, as the add someone sheet's field does
class _Field extends StatefulWidget {
  final TextEditingController ctrl;
  final String hint;
  final String? prefix;
  final ValueChanged<String>? onChanged;
  final int max;
  final int lines;
  const _Field({
    required this.ctrl,
    required this.hint,
    this.prefix,
    this.onChanged,
    this.max = 40,
    this.lines = 1,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  bool _lit = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _lit = v),
      child: AnimatedContainer(
        duration: motionStill(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _lit
                ? HaloColors.amber.withValues(alpha: 0.7)
                : HaloColors.line,
          ),
        ),
        // the text is latin left to right, so the @ leads it in every language
        child: Row(
          textDirection: TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.prefix != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 14, end: 2),
                child: Text(
                  widget.prefix!,
                  style: HaloType.mono(
                    size: 14,
                    color: _lit ? HaloColors.amber : HaloColors.text3,
                  ),
                ),
              ),
            Expanded(
              child: TextField(
                textDirection: TextDirection.ltr,
                controller: widget.ctrl,
                onChanged: widget.onChanged,
                maxLength: widget.max,
                minLines: widget.lines,
                maxLines: widget.lines,
                cursorColor: HaloColors.amber,
                style: HaloType.mono(size: 14, color: HaloColors.text),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  hintText: widget.hint,
                  hintStyle: HaloType.mono(size: 14, color: HaloColors.text3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// shown in place of the claimed card when the registry holds the name
// under a key that is not this phone's
class _ForeignCard extends StatelessWidget {
  final String handle;
  final VoidCallback onForget;
  const _ForeignCard({required this.handle, required this.onForget});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HaloColors.rose, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.handleIsNotYoursOn(handle),
            style: HaloType.serif(size: 19, color: HaloColors.text),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.handleTheRegistryHoldsIt(handle),
            style: HaloType.sans(
              size: 13,
              color: HaloColors.text2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          PressScale(
            scale: 0.97,
            onTap: onForget,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: HaloColors.line),
              ),
              child: Text(
                l10n.handleForgetItOnThis,
                style: HaloType.sans(
                  size: 13.5,
                  weight: FontWeight.w600,
                  color: HaloColors.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
