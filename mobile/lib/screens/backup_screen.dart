// SPDX-License-Identifier: GPL-3.0-or-later
// backup_screen.dart - creates an encrypted backup blob and hands it
// to the system share sheet so the user can save it to drive, email
// it to themselves, etc.

import '../lock_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../backup.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/fit_column.dart';
import '../widgets/stagger_in.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  @override
  void initState() {
    super.initState();
    appState.forceSecure(true);
  }

  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _busy = false;
  String? _error;
  // a backup to keep, or a move to another device. a move writes the mark
  // that retires this phone once the file is made
  bool _move = false;
  double _progress = 0;

  Future<void> _create() async {
    final pw = _p1.text.trim();
    final pw2 = _p2.text.trim();
    if (pw.isEmpty || pw.length < 6) {
      setState(() => _error = l10n.backupPassphraseMustBeAt);
      return;
    }
    if (pw != pw2) {
      setState(() => _error = l10n.backupPassphrasesDonTMatch);
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final name = 'kryfo-backup-$ts.kryfo';
      final path = p.join(tempDir.path, name);
      await createBackupFile(
        pw,
        path,
        move: _move,
        onProgress: (a, b) {
          if (mounted && b > 0) setState(() => _progress = a / b);
        },
      );
      var shared = false;
      try {
        shared = await _handOver(path, name);
      } finally {
        // a shared file is read by the other app after share() returns,
        // so that one is left for the boot sweep. every other way out
        // shreds the copy here
        if (!shared) await shredFile(path);
      }
      if (_move) {
        // the file is out of our hands: from here this phone is retired,
        // and the next screen says so. the mark is what tells it, not a
        // failing session weeks later
        await appState.markMoved();
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    }
  }

  // the system's save dialog first, streaming the file into wherever the
  // person picks - downloads, a drive, a card - and the share sheet when
  // that is refused. neither reads the file into memory: the save is a
  // stream copy on the platform side, the share hands over a path. true
  // when the share sheet took it, since that app reads the file after we
  // return and the copy has to be left for the boot sweep.
  Future<bool> _handOver(String path, String name) async {
    if (!mounted) return false;
    var saved = false;
    try {
      saved = await lockState.hold(
        () async =>
            await const MethodChannel('halo/platform').invokeMethod<bool>(
              'saveDocument',
              {'path': path, 'name': name},
            ) ??
            false,
      );
    } catch (_) {
      saved = false;
    }
    if (!mounted) return false;
    if (saved) {
      showHaloToast(context, l10n.backupBackupSavedKeepThe);
      return false;
    }
    return _share(path);
  }

  Future<bool> _share(String path) async {
    await lockState.hold(
      () => SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          subject: l10n.backupKryfoBackup,
          text: l10n.backupYourEncryptedKryfoBackup,
        ),
      ),
    );
    return true;
  }

  @override
  void dispose() {
    appState.forceSecure(false);
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: HaloColors.text2),
        title: Text(
          l10n.backupBackUpKryfo,
          style: HaloType.serif(size: 22, color: HaloColors.text, italic: true),
        ),
      ),
      body: SafeArea(
        // the page grew when it learned to move: on a 720px phone a plain
        // column ran past the body and the button, painted where it always
        // was, sat outside what could be tapped. fits or scrolls.
        child: FitColumn(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: staggerAll([
            _Choice(
              on: !_move,
              title: l10n.backupBackUp,
              line: l10n.backupACopyToKeep,
              onTap: () => setState(() => _move = false),
            ),
            const SizedBox(height: 8),
            _Choice(
              on: _move,
              title: l10n.backupMoveToAnotherDevice,
              line: l10n.backupTheFileTakesThis,
              onTap: () => setState(() => _move = true),
            ),
            const SizedBox(height: 16),
            Text(
              _move
                  ? l10n.backupOneEncryptedFileYour
                  : l10n.backupOneEncryptedFileYourIdentityYour,
              style: HaloType.sans(
                size: 13.5,
                color: HaloColors.text2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _PinField(label: l10n.backupPassphrase, controller: _p1),
            const SizedBox(height: 12),
            _PinField(label: l10n.backupConfirmPassphrase, controller: _p2),
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: HaloType.sans(size: 12, color: HaloColors.rose),
              ),
            const Spacer(),
            GestureDetector(
              onTap: _busy ? null : _create,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _busy ? HaloColors.surface3 : HaloColors.amber,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  _busy
                      ? (_progress > 0
                            ? l10n.backupWriting(percent(_progress))
                            : l10n.backupCreating)
                      : (_move
                            ? l10n.backupMakeTheFileAnd
                            : l10n.backupCreateBackup),
                  style: HaloType.sans(
                    size: 14,
                    color: _busy ? HaloColors.text2 : HaloColors.onAmber,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _PinField({required this.label, required this.controller});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      style: HaloType.mono(size: 14, color: HaloColors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: HaloType.sans(size: 12, color: HaloColors.text2),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: HaloColors.line, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: HaloColors.amber, width: 0.8),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final bool on;
  final String title;
  final String line;
  final VoidCallback onTap;
  const _Choice({
    required this.on,
    required this.title,
    required this.line,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: on ? HaloColors.amberSoft : HaloColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: on ? HaloColors.amber : HaloColors.line,
            width: on ? 1 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: HaloType.sans(
                size: 14.5,
                weight: FontWeight.w600,
                color: HaloColors.text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              line,
              style: HaloType.sans(
                size: 12.5,
                color: HaloColors.text2,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
