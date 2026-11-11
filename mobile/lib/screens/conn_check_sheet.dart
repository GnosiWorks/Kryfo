// SPDX-License-Identifier: GPL-3.0-or-later
// "check my connection": the report word for word as it would go, and the
// person's own copy or send. nothing is sent from here
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_version.dart' show kAppVersion;
import '../conn_check.dart';
import '../dlog.dart';
import '../l10n/l10n.dart';
import '../main.dart' hide live;
import '../theme.dart';
import '../widgets/copied_mark.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/press_scale.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/stagger_in.dart';
import '../widgets/swap.dart';
import 'dev_about_sheet.dart' show devChatOffered, writeToMarios;

/// the report as it stands now
String connReportNow() {
  var bridge = '';
  var tx = const <String, dynamic>{};
  try {
    bridge = engine.bridgeStatus();
    tx = engine.transportState();
  } catch (e) {
    dlog('conn check: ${e.runtimeType}');
  }
  return connReport(
    now: DateTime.now(),
    version: kAppVersion,
    platform: Platform.operatingSystem,
    sendMode: appState.sendMode,
    tor: appState.shownTorStatus,
    pct: appState.bootstrapPct,
    canSend: appState.linkUp,
    online: appState.online,
    bridgeRaw: bridge,
    tx: tx,
    trail: connTrail,
    decoy: appState.inDecoyView,
  );
}

Future<void> showConnCheck(BuildContext context, {String Function()? report}) =>
    showHaloSheet<void>(
      context,
      builder: (_) => ConnCheckSheet(report: report ?? connReportNow),
    );

class ConnCheckSheet extends StatefulWidget {
  const ConnCheckSheet({super.key, required this.report});
  final String Function() report;

  @override
  State<ConnCheckSheet> createState() => _ConnCheckSheetState();
}

class _ConnCheckSheetState extends State<ConnCheckSheet> {
  late String _text = widget.report();
  int _copies = 0;
  // bumped by check again, so the same words still rise in
  int _round = 0;

  void _again() {
    HapticFeedback.selectionClick();
    setState(() {
      _text = widget.report();
      _round++;
    });
  }

  Future<void> _copy() async {
    HapticFeedback.selectionClick();
    await Clipboard.setData(ClipboardData(text: _text));
    if (!mounted) return;
    setState(() => _copies++);
    showHaloToast(context, l10n.commonCopied);
  }

  // the chat opens with the report in its composer, for the person to send
  Future<void> _send() async {
    final nav = Navigator.of(context);
    final text = _text;
    nav.pop();
    await writeToMarios(nav.context, text: text);
  }

  @override
  Widget build(BuildContext context) {
    final send = devChatOffered && !linkedRole;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 18),
            ...staggerAllIn(context, [
              Text(
                l10n.connCheckTitle,
                style: HaloType.serif(
                  size: 20,
                  italic: true,
                  color: HaloColors.text,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  l10n.connCheckLine,
                  style: HaloType.sans(
                    size: 13,
                    color: HaloColors.text,
                    height: 1.5,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: HaloColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: HaloColors.line),
                  ),
                  // the report reads left to right in every language
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: RiseSwap(
                      alignment: Alignment.topLeft,
                      child: SelectableText(
                        _text,
                        key: ValueKey(_round),
                        style: HaloType.mono(
                          size: 12,
                          color: HaloColors.text,
                        ).copyWith(height: 1.55),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.connCheckEnglish,
                  style: HaloType.sans(
                    size: 12,
                    color: HaloColors.text2,
                    height: 1.4,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _CopyButton(copies: _copies, onTap: _copy),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TextAction(label: l10n.connCheckAgain, onTap: _again),
                  if (send)
                    _TextAction(label: l10n.connCheckSend, onTap: _send),
                ],
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Flexible(
    child: PressScale(
      label: label,
      scale: 0.94,
      haptic: false,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(
          label,
          semanticsLabel: '',
          textAlign: TextAlign.center,
          style: HaloType.sans(
            size: 13,
            weight: FontWeight.w600,
            color: HaloColors.violetText,
          ),
        ),
      ),
    ),
  );
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.copies, required this.onTap});
  final int copies;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PressScale(
    label: l10n.commonCopy,
    scale: 0.97,
    haptic: false,
    onTap: onTap,
    child: Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HaloColors.violet,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CopiedMark(
            copies: copies,
            size: 15,
            color: HaloColors.ink,
            done: HaloColors.ink,
          ),
          const SizedBox(width: 6),
          Text(
            l10n.commonCopy,
            semanticsLabel: '',
            style: HaloType.sans(
              size: 14,
              weight: FontWeight.w600,
              color: HaloColors.ink,
            ),
          ),
        ],
      ),
    ),
  );
}
