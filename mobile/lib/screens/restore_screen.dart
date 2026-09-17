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
import '../main.dart' show appState, engine, shredFile;
import '../picked.dart';
import '../theme.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/press_scale.dart';
import '../widgets/stagger_in.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../backup_stream.dart' show isBackupV2;
import '../widgets/halo_sheet.dart';
import '../widgets/sheet_handle.dart';

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
  // a v1 file is a text blob held in memory; a v2 file is copied to a
  // private temp path and streamed from there. one of the two is set.
  String? _blob;
  String? _path;
  double _progress = 0;
  bool _releasing = false;
  // a file of either kind is picked
  bool get _hasFile => _blob != null || _path != null;
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
    String? blob;
    String? own;
    try {
      if (await isBackupV2(path)) {
        // keep our own copy: the picker's is shredded below, and a v2
        // file is streamed, not read into memory
        final dir = await getApplicationSupportDirectory();
        own = p.join(dir.path, 'restore_in.kryfo');
        await File(path).copy(own);
      } else {
        final head = await File(path).openRead(0, 16).first;
        final text = String.fromCharCodes(head);
        if (!(text.startsWith('kryfo-backup:') ||
            text.startsWith('halo-backup:'))) {
          if (mounted) {
            setState(() => _error = 'That file is not a kryfo backup');
          }
          return;
        }
        blob = (await File(path).readAsString()).trim();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'This file is damaged and cannot be read');
      }
      return;
    } finally {
      await shredPicked(result);
    }
    if (!mounted) return;
    HapticFeedback.selectionClick();
    await _dropOwnCopy();
    setState(() {
      _fileName = path.split('/').last;
      _blob = blob;
      _path = own;
    });
  }

  Future<void> _dropOwnCopy() async {
    final old = _path;
    if (old != null) await shredFile(old);
  }

  // decrypt and look, touching nothing yet
  Future<void> _check() async {
    final blob = _blob;
    final path = _path;
    if (blob == null && path == null) return;
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
      final s = path != null
          ? await inspectBackupFile(path, pw)
          : await inspectBackup(blob!, pw);
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
    final path = _path;
    final s = _summary;
    if ((blob == null && path == null) || s == null) return;
    // the page someone reads on the worst day. what follows, what does
    // not, and the one line that has to be plain: the old phone stops
    // receiving the moment this one sends. not gradually.
    final go = await _moveSheet(s);
    if (!go || !mounted) return;
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
    // a handle is proved with the key that is about to go. once another
    // identity takes this phone nobody can release it or point it anywhere
    // again, and the public page keeps handing out an invite no one holds.
    // so it goes back first, while the key is still here.
    final mine = appState.myHandle;
    final sameIdentity = s.haloId == appState.myId;
    if (mine != null && !sameIdentity) {
      setState(() {
        _busy = true;
        _releasing = true;
        _error = null;
      });
      var r = 'error: timeout';
      try {
        r = await engine
            .handleRelease(mine)
            .timeout(const Duration(seconds: 40), onTimeout: () => r);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _busy = false;
        _releasing = false;
      });
      if (r == 'ok') {
        await appState.setMyHandle(null);
      } else {
        final ok = await showConfirmSheet(
          context,
          title: '@$mine could not be released',
          line:
              'The registry did not answer. If you go on, @$mine stays '
              'pointed at the identity this phone is about to lose. Anyone '
              'who adds it will be writing to nobody, and the name cannot '
              'be claimed again. Better to get online and try once more.',
          yes: 'Restore anyway',
          keep: 'Not yet',
        );
        if (!ok || !mounted) return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    try {
      if (path != null) {
        await restoreBackupFile(
          path,
          _passCtrl.text.trim(),
          onProgress: (a, b) {
            if (mounted && b > 0) setState(() => _progress = a / b);
          },
        );
        await _dropOwnCopy();
      } else {
        await restoreBackupBlob(blob!, _passCtrl.text.trim());
      }
      // the same identity coming back, from a file made before handles
      // were carried: the key still proves the handle, so keep the name
      if (sameIdentity && mine != null) await keepHandleIfDropped(mine);
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

  Future<bool> _moveSheet(BackupSummary s) async {
    final big = s.bytes > 50 * 1024 * 1024;
    final when = s.when;
    final made = when == null
        ? ''
        : ', made on ${when.day} ${_SummaryCard._month(when.month)} at '
              '${when.hour.toString().padLeft(2, '0')}:'
              '${when.minute.toString().padLeft(2, '0')}';
    final name = s.haloId.isEmpty ? 'this identity' : s.haloId;
    final r = await showHaloSheet<bool>(
      context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Center(child: SheetHandle()),
                const SizedBox(height: 18),
                Text(
                  'Move your kryfo here',
                  style: HaloType.serif(size: 21, color: HaloColors.text),
                ),
                const SizedBox(height: 8),
                Text(
                  'This backup is $name$made. Restoring it moves that '
                  'identity to this device.',
                  style: HaloType.sans(
                    size: 13.5,
                    color: HaloColors.text2,
                    height: 1.45,
                  ),
                ),
                if (big) ...[
                  const SizedBox(height: 10),
                  Text(
                    'It holds ${_mb(s.bytes)} of photos, voice notes and '
                    'files. This may take a few minutes. Keep the app open.',
                    style: HaloType.sans(
                      size: 13.5,
                      color: HaloColors.amber,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _head('What follows'),
                _item('Your name, your code, and every contact.'),
                _item('Every conversation, back to the start.'),
                _item(
                  'Your photos, voice notes and files'
                  '${s.files > 0 ? ' · ${s.files}' : ''}.',
                ),
                _item(
                  'Your onion address, so people who reach you directly '
                  'keep reaching you.',
                ),
                _item(
                  'Anything sent to you while the old phone was off, for '
                  'fourteen days after it was sent.',
                ),
                _item('Your supporter badge, if you have one.'),
                const SizedBox(height: 16),
                _head("What doesn't"),
                _item(
                  'The old phone stops receiving the moment you send '
                  'anything from here. Not gradually. The first message you '
                  'send from this device is the last one the old phone can '
                  'follow, and anything that reaches it after that is '
                  "unreadable there and isn't waiting for you here either.",
                  strong: true,
                ),
                if (s.moved != true)
                  _item(
                    'If the phone this file came from is still in use, stop '
                    'using kryfo on it before you carry on. Two phones on one '
                    'kryfo lose messages on both.',
                    strong: true,
                  ),
                _item('Notifications need setting up again on this device.'),
                const SizedBox(height: 22),
                _Primary(
                  label: 'Move it here',
                  onTap: () => Navigator.pop(ctx, true),
                ),
                const SizedBox(height: 6),
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(ctx, false),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Not now',
                        style: HaloType.sans(size: 13, color: HaloColors.text2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return r == true;
  }

  Widget _head(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: HaloType.mono(size: 11, color: HaloColors.text3)),
  );

  Widget _item(String t, {bool strong = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7, right: 10),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: strong ? HaloColors.amber : HaloColors.text3,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: Text(
            t,
            style: HaloType.sans(
              size: 13.5,
              color: strong ? HaloColors.text : HaloColors.text2,
              weight: strong ? FontWeight.w600 : FontWeight.w400,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _passCtrl.dispose();
    _dropOwnCopy();
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
                      color: _hasFile ? HaloColors.amber : HaloColors.line,
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
              child: !_hasFile
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
                label: _busy ? 'Checking…' : 'Check the file',
                onTap: _busy || !_hasFile ? null : _check,
              )
            else
              _Primary(
                label: _releasing
                    ? 'Releasing your handle…'
                    : _busy
                    ? (_path != null && _progress > 0
                          ? 'Moving… ${(_progress * 100).round()}%'
                          : 'Restoring…')
                    : 'Restore',
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
          if (summary.files > 0)
            _line('attachments', '${summary.files} · ${_mb(summary.bytes)}'),
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

String _mb(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  return '${(bytes / (1024 * 1024)).round()} MB';
}
