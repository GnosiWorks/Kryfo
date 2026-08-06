// SPDX-License-Identifier: GPL-3.0-or-later
// bridges. a direct tor connection is recognisable, and in the places where
// kryfo matters most that is enough to get it blocked. a bridge is an entry
// point that is not published anywhere, reached through obfs4, which makes
// the traffic look like nothing in particular.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../theme.dart';

class BridgesScreen extends StatefulWidget {
  const BridgesScreen({super.key});

  @override
  State<BridgesScreen> createState() => _BridgesScreenState();
}

class _BridgesScreenState extends State<BridgesScreen> {
  late final TextEditingController _ctrl;
  late bool _on;
  bool _busy = false;
  String? _result;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: appState.bridgeLines);
    _on = appState.bridgesOn;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final lines = _ctrl.text.trim();
    final r = await appState.applyBridges(lines, _on && lines.isNotEmpty);
    // tor reads its config once, so a change means a restart. that costs a
    // fresh bootstrap, which is worth saying out loud rather than leaving
    // someone staring at a spinner.
    engine.restartTor();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = r;
    });
    showHaloToast(context, 'reconnecting through tor, this takes a minute');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.ink,
      appBar: AppBar(
        backgroundColor: HaloColors.ink,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          'bridges',
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Text(
            'some networks block tor outright. a bridge is an entry point that '
            'is not published in any public list, so it cannot be blocked the '
            'same way. kryfo reaches it through obfs4, which makes the traffic '
            'look like nothing worth inspecting.',
            style: HaloType.sans(size: 13, color: HaloColors.text2),
          ),
          const SizedBox(height: 22),

          _Toggle(
            value: _on,
            label: 'use bridges',
            detail: _on
                ? 'slower to connect, harder to block'
                : 'direct to tor · fastest, and fine almost everywhere',
            onChanged: (v) => setState(() => _on = v),
          ),

          const SizedBox(height: 24),
          Text(
            'your bridge lines',
            style: HaloType.mono(
              size: 11,
              color: HaloColors.text2,
              weight: FontWeight.w600,
              letter: 0.14,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: HaloColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HaloColors.line),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: _ctrl,
              maxLines: 6,
              minLines: 4,
              style: HaloType.mono(size: 11.5, color: HaloColors.text),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'obfs4 1.2.3.4:443 FINGERPRINT cert=... iat-mode=0',
                hintStyle: HaloType.mono(size: 11, color: HaloColors.text3),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'one per line. get them from bridges.torproject.org, or by '
            'emailing bridges@torproject.org from a gmail or riseup address. '
            'ask for obfs4 - kryfo does not speak the others yet.',
            style: HaloType.sans(size: 12, color: HaloColors.text2),
          ),

          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final d = await Clipboard.getData('text/plain');
              final t = d?.text?.trim();
              if (t == null || t.isEmpty) return;
              setState(() {
                _ctrl.text = _ctrl.text.trim().isEmpty
                    ? t
                    : '${_ctrl.text.trim()}\n$t';
              });
              HapticFeedback.selectionClick();
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'paste from clipboard',
                style: HaloType.mono(
                  size: 12,
                  color: HaloColors.amber,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),

          if (_result != null) ...[
            const SizedBox(height: 14),
            Text(
              _result!,
              style: HaloType.mono(size: 11.5, color: HaloColors.text2),
            ),
          ],

          const SizedBox(height: 26),
          GestureDetector(
            onTap: _busy ? null : _save,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _busy ? HaloColors.surface2 : HaloColors.amber,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _busy ? 'applying...' : 'save and reconnect',
                style: HaloType.mono(
                  size: 13,
                  color: _busy ? HaloColors.text2 : HaloColors.onAmber,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: HaloColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HaloColors.line),
            ),
            child: Text(
              'saving restarts tor, so the first connection afterwards takes '
              'longer than usual. bridges also slow everything down a little. '
              'if your network does not block tor, leave this off.',
              style: HaloType.sans(size: 12, color: HaloColors.text2),
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.value,
    required this.label,
    required this.detail,
    required this.onChanged,
  });
  final bool value;
  final String label;
  final String detail;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value
                ? HaloColors.amber.withValues(alpha: 0.4)
                : HaloColors.line,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: HaloType.sans(size: 14, color: HaloColors.text),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: HaloType.sans(size: 12, color: HaloColors.text2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: HaloColors.onAmber,
              activeTrackColor: HaloColors.amber,
            ),
          ],
        ),
      ),
    );
  }
}
