// SPDX-License-Identifier: GPL-3.0-or-later
// makes an encrypted backup file and hands it to the system save dialog, or
// to the share sheet when that is refused.

import '../lock_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../backup.dart';
import '../main.dart' hide live;
import '../theme.dart';
import '../widgets/fit_column.dart';
import '../widgets/stagger_in.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';

class BackupScreen extends StatefulWidget {
  // from the hidden chats setup: a copy to keep that holds the chats just
  // hidden, never a move
  final bool withHiddenChats;
  const BackupScreen({super.key, this.withHiddenChats = false});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  @override
  void initState() {
    super.initState();
    appState.forceSecure(true);
  }

  // the file holds the hidden chats: they are open, or were just set up. a
  // decoy's never does. a session change closes this screen, so it is read
  // once
  late final bool _hidden = backupShape(
    quiet: sessionQuiet,
    open: sessionBackupHasHidden,
    setup: widget.withHiddenChats,
    move: false,
  ).hidden;

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
      final move = _move && !widget.withHiddenChats;
      await createBackupFile(
        pw,
        path,
        move: move,
        withHiddenChats: widget.withHiddenChats,
        onProgress: (a, b) {
          if (mounted && b > 0) setState(() => _progress = a / b);
        },
      );
      var out = (handed: false, shared: false);
      try {
        out = await _handOver(path, name);
      } finally {
        // a shared file is read by the other app after share() returns,
        // so that one is left for the boot sweep. every other way out
        // shreds the copy here
        if (!out.shared) await shredFile(path);
      }
      if (move && out.handed) {
        // the file is out of our hands: from here this phone is retired,
        // and the next screen says so. one never handed over, the screen
        // gone under a lock, retires nothing
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

  // the system save dialog first, the share sheet when that is refused.
  // neither reads the file into memory. shared when the share sheet took
  // it: that app reads the file after we return, so the copy is left for
  // the boot sweep.
  Future<({bool handed, bool shared})> _handOver(
    String path,
    String name,
  ) async {
    const none = (handed: false, shared: false);
    if (!mounted) return none;
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
    if (saved) {
      if (mounted) showHaloToast(context, l10n.backupBackupSavedKeepThe);
      return (handed: true, shared: false);
    }
    if (!mounted) return none;
    await _share(path);
    return (handed: true, shared: true);
  }

  Future<void> _share(String path) async {
    await lockState.hold(
      () => SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          subject: l10n.backupKryfoBackup,
          text: l10n.backupYourEncryptedKryfoBackup,
        ),
      ),
    );
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
        // fits or scrolls: on a short screen a plain column leaves the
        // button painted outside what can be tapped
        child: FitColumn(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: staggerAllIn(context, [
            // a setup's backup holds the chats it just hid: never a move
            if (!widget.withHiddenChats) ...[
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
            ],
            _About(
              move: _move && !widget.withHiddenChats,
              canMove: !widget.withHiddenChats,
              hidden: _hidden,
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
      // never offered to the phone's autofill service
      autofillHints: null,
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
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 200),
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

// what the file holds, for a copy and for a move. both are laid out and the
// other one fades in over it, so nothing below moves when the choice
// changes. outside the hidden chats the last line reads the same whether
// there are any or not
class _About extends StatelessWidget {
  const _About({
    required this.move,
    required this.canMove,
    required this.hidden,
  });
  final bool move;
  // no move to choose: the copy alone, with no room kept for the other
  final bool canMove;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    Widget page(bool forMove) {
      final on = forMove == move;
      return ExcludeSemantics(
        excluding: !on,
        child: AnimatedOpacity(
          opacity: on ? 1 : 0,
          duration: still ? Duration.zero : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                forMove
                    ? l10n.backupOneEncryptedFileYour
                    : l10n.backupOneEncryptedFileYourIdentityYour,
                style: HaloType.sans(
                  size: 13.5,
                  color: HaloColors.text2,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 2, end: 8),
                    child: Icon(
                      Icons.visibility_off_outlined,
                      size: 16,
                      color: HaloColors.violet,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      hidden
                          ? l10n.backupHiddenIncluded
                          : forMove
                          ? l10n.backupMoveHiddenStay
                          : l10n.backupHiddenNotIn,
                      style: HaloType.sans(
                        size: 13.5,
                        color: HaloColors.text,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (!canMove) return page(false);
    return Stack(children: [page(false), page(true)]);
  }
}
