// SPDX-License-Identifier: GPL-3.0-or-later
// claim a public handle. the one screen that makes someone findable by
// strangers, so it says what that costs first and is off until asked for.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show appState, engine, sessionQuiet;
import '../theme.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/halo_bar.dart';
import '../widgets/halo_switch.dart';
import '../widgets/stagger_in.dart';
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
    // same invite the qr code carries - the registry only ever holds what
    // was already public.
    final uri = await appState.sessionInvite();
    final r = sessionQuiet
        ? _unreached
        : await engine.handleClaim(h, uri, _bio.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == 'ok') {
      await appState.setMyHandle(h, bio: _bio.text.trim());
      if (!mounted) return;
      setState(() => _claimed = h);
      showHaloToast(context, l10n.handleYouAre(h));
    } else {
      showHaloToast(context, _refused(r, h));
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
      showHaloToast(context, _refused(r, h));
    }
  }

  static const _unreached = 'error: bad answer from the registry';

  // the engine and the registry answer in fixed english words
  String _refused(String r, String h) {
    if (r.contains('is taken') || r.contains('not available')) {
      return l10n.handleThatHandleIsTaken;
    }
    if (r.contains('not yours')) return l10n.handleIsNotYoursOn(h);
    return l10n.handleRegistryFailed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        title: Text(l10n.handlePublicHandle, style: HaloType.serif(size: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: staggerAll([
          if (_claimed != null && appState.handleForeign) ...[
            _ForeignCard(handle: _claimed!, onForget: _forget),
            const SizedBox(height: 22),
          ] else if (_claimed != null) ...[
            _ClaimedCard(handle: _claimed!, onRelease: _busy ? null : _release),
            const SizedBox(height: 14),
            _ListingCard(handle: _claimed!),
            const SizedBox(height: 22),
          ] else ...[
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
            _Field(
              ctrl: _bio,
              hint: l10n.handleALineAboutYou,
              max: 200,
              lines: 2,
            ),
            const SizedBox(height: 22),
            const _RiskBlock(),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: (_state == 'free' && !_busy) ? _claim : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _state == 'free'
                      ? HaloColors.amber
                      : HaloColors.surface2,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _state == 'free'
                        ? Colors.transparent
                        : HaloColors.line,
                  ),
                ),
                child: Text(
                  _busy ? l10n.handleClaiming : l10n.handleClaimThisHandle,
                  style: HaloType.mono(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: _state == 'free' ? HaloColors.ink : HaloColors.text3,
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
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
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
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

class _ClaimedCard extends StatelessWidget {
  final String handle;
  final VoidCallback? onRelease;
  const _ClaimedCard({required this.handle, this.onRelease});

  @override
  Widget build(BuildContext context) {
    final url = 'https://relay.kryfo.app/@$handle';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
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
              Text(
                ltr('@$handle'),
                style: HaloType.serif(size: 20, color: HaloColors.text),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.handleAnyoneWithThisLink,
            style: HaloType.sans(size: 13, color: HaloColors.text2),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              copySensitive(url);
              showHaloToast(context, l10n.handleLinkCopied);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      style: HaloType.mono(size: 11, color: HaloColors.text2),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.copy, size: 14, color: HaloColors.text3),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onRelease,
            behavior: HitTestBehavior.opaque,
            child: Text(
              l10n.handleDeleteThisHandle,
              style: HaloType.mono(size: 11.5, color: HaloColors.rose),
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
    } else {
      txt = state.replaceFirst('error: ', '');
      c = HaloColors.amber;
    }
    return SizedBox(
      height: 16,
      child: Text(txt, style: HaloType.mono(size: 11, color: c)),
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

class _Field extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HaloColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prefix != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 14, end: 2),
              child: Text(
                prefix!,
                style: HaloType.mono(size: 14, color: HaloColors.text3),
              ),
            ),
          Expanded(
            child: TextField(
              textDirection: TextDirection.ltr,
              controller: ctrl,
              onChanged: onChanged,
              maxLength: max,
              minLines: lines,
              maxLines: lines,
              style: HaloType.mono(size: 14, color: HaloColors.text),
              decoration: InputDecoration(
                border: InputBorder.none,
                counterText: '',
                hintText: hint,
                hintStyle: HaloType.mono(size: 14, color: HaloColors.text3),
              ),
            ),
          ),
        ],
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
          GestureDetector(
            behavior: HitTestBehavior.opaque,
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
