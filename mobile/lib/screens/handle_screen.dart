// SPDX-License-Identifier: GPL-3.0-or-later
//
// claim a public handle. this is the one screen that makes someone findable
// by strangers, so it says what that costs before it offers the button, and
// it is off until they ask for it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show appState, engine, buildHaloUriV3, showHaloToast;
import '../theme.dart';

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
    if (_claimed != null) _ctrl.text = _claimed!;
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
    // the registry is one request away and someone types fast. wait for them
    // to stop before asking.
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final r = engine.handleCheck(h);
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
    final uri = await buildHaloUriV3(
      appState.myId,
      appState.myOnion,
      appState.fcCounter,
    );
    final r = engine.handleClaim(h, uri, _bio.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == 'ok') {
      await appState.setMyHandle(h);
      if (!mounted) return;
      setState(() => _claimed = h);
      showHaloToast(context, 'you are @$h');
    } else {
      showHaloToast(context, r.replaceFirst('error: ', ''));
    }
  }

  Future<void> _release() async {
    final h = _claimed;
    if (h == null) return;
    setState(() => _busy = true);
    final r = engine.handleRelease(h);
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
      showHaloToast(context, 'handle deleted · the page is gone');
    } else {
      showHaloToast(context, r.replaceFirst('error: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        title: Text('public handle', style: HaloType.serif(size: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          if (_claimed != null) ...[
            _ClaimedCard(handle: _claimed!, onRelease: _busy ? null : _release),
            const SizedBox(height: 22),
          ] else ...[
            Text(
              'optional. your three words keep working either way.',
              style: HaloType.sans(size: 13.5, color: HaloColors.text2),
            ),
            const SizedBox(height: 20),
            _Field(
              ctrl: _ctrl,
              hint: 'wren',
              prefix: '@',
              onChanged: _onTyped,
              max: 20,
            ),
            const SizedBox(height: 8),
            _Availability(state: _state),
            const SizedBox(height: 18),
            _Field(
              ctrl: _bio,
              hint: 'a line about you · optional',
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
                  _busy ? 'claiming…' : 'claim this handle',
                  style: HaloType.mono(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: _state == 'free' ? HaloColors.ink : HaloColors.text3,
                  ),
                ),
              ),
            ),
          ],
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
                '@$handle',
                style: HaloType.serif(size: 20, color: HaloColors.text),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'anyone with this link can start a private chat with you. it '
            'carries your invite and nothing else.',
            style: HaloType.sans(size: 13, color: HaloColors.text2),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Clipboard.setData(ClipboardData(text: url));
              showHaloToast(context, 'link copied');
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
              'delete this handle',
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
      txt = 'checking…';
      c = HaloColors.text3;
    } else if (state == 'free') {
      txt = '✓ available';
      c = HaloColors.green;
    } else if (state == 'taken') {
      txt = 'already taken';
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
            'what a handle does',
            style: HaloType.mono(
              size: 11,
              color: HaloColors.amber,
              weight: FontWeight.w600,
              letter: 0.1,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'anyone who knows it can ask to message you, which is the point '
            'of having one. the page holds your invite and the line you '
            'wrote, nothing else, and keeps no record of who reads it. you '
            'can delete it whenever you like.',
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
              padding: const EdgeInsets.only(top: 14, right: 2),
              child: Text(
                prefix!,
                style: HaloType.mono(size: 14, color: HaloColors.text3),
              ),
            ),
          Expanded(
            child: TextField(
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
