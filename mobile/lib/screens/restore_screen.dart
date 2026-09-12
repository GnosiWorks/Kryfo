// SPDX-License-Identifier: GPL-3.0-or-later
// restore_screen.dart - the screen someone reaches on their worst day. pick
// the backup file, type the passphrase, see exactly what is about to come
// back, then restore. every failure names its cause. nothing here ever
// mentions a word list, because there is none: recovery is the encrypted
// file plus its passphrase.
import 'dart:io';
import '../lock_state.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backup.dart';
import '../main.dart' show appState;
import '../picked.dart';
import '../theme.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/press_scale.dart';
import '../widgets/stagger_in.dart';

class RestoreScreen extends StatefulWidget {
  // when non-null, called after a successful restore instead of the
  // 'reopen kryfo' notice. used from onboarding to skip the restart and go
  // straight to the home shell.
  final VoidCallback? onRestored;
  const RestoreScreen({super.key, this.onRestored});
  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  String? _fileName;
  String? _blob;
  final _passCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  BackupSummary? _summary;

  Future<void> _pick() async {
    setState(() {
      _error = null;
      _summary = null;
    });
    final result = await lockState.hold(() => FilePicker.pickFiles());
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    String blob;
    try {
      blob = await File(path).readAsString();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'This file is damaged and cannot be read');
      }
      return;
    } finally {
      await shredPicked(result);
    }
    if (!mounted) return;
    if (!(blob.startsWith('kryfo-backup:') ||
        blob.startsWith('halo-backup:'))) {
      setState(() => _error = 'That file is not a kryfo backup');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _fileName = path.split('/').last;
      _blob = blob.trim();
    });
  }

  // decrypt and look, touching nothing yet
  Future<void> _check() async {
    final blob = _blob;
    if (blob == null) return;
    final pw = _passCtrl.text.trim();
    if (pw.isEmpty) {
      setState(() => _error = 'Type the passphrase the file was made with');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = await inspectBackup(blob, pw);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _summary = s;
        _busy = false;
      });
    } on RestoreError catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _error = e.line;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'This file is damaged and cannot be read';
        _busy = false;
      });
    }
  }

  Future<void> _restore() async {
    final blob = _blob;
    final s = _summary;
    if (blob == null || s == null) return;
    if (appState.onboardingComplete) {
      final ok = await showConfirmSheet(
        context,
        title: 'Replace the account on this phone?',
        line:
            'What is here now, its identity, contacts and messages, goes. '
            'The file takes its place. This cannot be undone.',
        yes: 'Replace it',
      );
      if (!ok) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await restoreBackupBlob(blob, _passCtrl.text.trim());
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      if (widget.onRestored != null) {
        widget.onRestored!();
        return;
      }
      await showNoticeSheet(
        context,
        title: 'Restored',
        line: 'Kryfo will close now. Tap the icon to reopen as ${s.haloId}.',
        ok: 'Reopen kryfo',
      );
      // exit so the next launch boots fresh from the restored db
      Future.delayed(const Duration(milliseconds: 200), () => exit(0));
      if (mounted) Navigator.of(context).pop();
    } on RestoreError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.line;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'The restore did not finish. Nothing was changed';
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          'Restore',
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
          children: staggerAll([
            Text(
              'From a backup file',
              style: HaloType.serif(size: 26, color: HaloColors.text),
            ),
            const SizedBox(height: 8),
            Text(
              'A backup brings back your identity and your contacts, and the '
              'messages that were on the phone when the file was made. '
              'Anything said since is not in it.',
              style: HaloType.sans(
                size: 13,
                color: HaloColors.text2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            _Step(
              n: '1',
              label: 'The file',
              child: PressScale(
                onTap: _busy ? null : _pick,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: HaloColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _blob != null ? HaloColors.amber : HaloColors.line,
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 18,
                        color: HaloColors.amber,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _fileName ?? 'Pick the backup file',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HaloType.sans(
                            size: 13.5,
                            color: _fileName == null
                                ? HaloColors.text2
                                : HaloColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _blob == null
                  ? const SizedBox(width: double.infinity)
                  : _Step(
                      n: '2',
                      label: 'The passphrase',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: HaloColors.surface2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: HaloColors.line,
                            width: 0.6,
                          ),
                        ),
                        child: TextField(
                          controller: _passCtrl,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          enabled: !_busy && s == null,
                          onSubmitted: (_) => _check(),
                          style: HaloType.mono(
                            size: 14,
                            color: HaloColors.text,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'The one the file was made with',
                            hintStyle: HaloType.mono(
                              size: 12.5,
                              color: HaloColors.text3,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _error!,
                        style: HaloType.sans(size: 13, color: HaloColors.rose),
                      ),
                    ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: s == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: _Step(
                        n: '3',
                        label: 'What comes back',
                        child: _SummaryCard(summary: s),
                      ),
                    ),
            ),
            const SizedBox(height: 22),
            if (s == null)
              _Primary(
                label: _busy ? 'checking…' : 'Check the file',
                onTap: _busy || _blob == null ? null : _check,
              )
            else
              _Primary(
                label: _busy ? 'restoring…' : 'restore',
                onTap: _busy ? null : _restore,
              ),
            if (s != null) ...[
              const SizedBox(height: 6),
              Center(
                child: GestureDetector(
                  onTap: _busy
                      ? null
                      : () => setState(() {
                          _summary = null;
                          _passCtrl.clear();
                        }),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Not this one',
                      style: HaloType.sans(size: 13, color: HaloColors.text2),
                    ),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String label;
  final Widget child;
  const _Step({required this.n, required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            '0$n',
            style: HaloType.mono(
              size: 10,
              color: HaloColors.amber,
              letter: 0.2,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: HaloType.mono(
              size: 10,
              color: HaloColors.text2,
              letter: 0.1,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  final BackupSummary summary;
  const _SummaryCard({required this.summary});
  @override
  Widget build(BuildContext context) {
    final w = summary.when;
    final date = w == null
        ? 'Date unknown'
        : '${w.day} ${_month(w.month)} ${w.year}, '
              '${w.hour.toString().padLeft(2, '0')}:${w.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HaloColors.amber.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.haloId.isEmpty ? 'An identity' : summary.haloId,
            style: HaloType.mono(
              size: 16,
              weight: FontWeight.w600,
              color: HaloColors.amber,
            ),
          ),
          const SizedBox(height: 10),
          _line('made', date),
          _line('contacts', '${summary.contacts}'),
          _line('messages', '${summary.messages}'),
          const SizedBox(height: 8),
          Text(
            'Messages sent or received after that date are not in this file.',
            style: HaloType.sans(
              size: 12,
              color: HaloColors.text2,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            k,
            style: HaloType.mono(size: 10.5, color: HaloColors.text3),
          ),
        ),
        Text(v, style: HaloType.sans(size: 13.5, color: HaloColors.text)),
      ],
    ),
  );

  static String _month(int m) => const [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ][m - 1];
}

class _Primary extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _Primary({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? HaloColors.amber : HaloColors.surface3,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          label,
          style: HaloType.sans(
            size: 14,
            weight: FontWeight.w600,
            color: on ? HaloColors.onAmber : HaloColors.text3,
          ),
        ),
      ),
    );
  }
}
