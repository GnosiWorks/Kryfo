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
import '../widgets/ease_size.dart';
import '../widgets/fit_column.dart';
import '../widgets/halo_bar.dart';
import '../widgets/motion.dart' show houseSpring;
import '../widgets/halo_buttons.dart';
import '../widgets/press_scale.dart';
import '../widgets/secret_field.dart';
import '../widgets/stagger_in.dart';
import '../widgets/swap.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../dlog.dart';

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
  // both fields show what was typed, or neither
  bool _shown = false;

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
      dlog('backup: not made (${e.runtimeType})');
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _error = backupFailLine(e);
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
        title: Text(l10n.backupBackUpKryfo, style: HaloType.pageTitle()),
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
            SecretField(
              label: l10n.backupPassphrase,
              controller: _p1,
              shown: _shown,
              onToggle: () => setState(() => _shown = !_shown),
            ),
            const SizedBox(height: 12),
            SecretField(
              label: l10n.backupConfirmPassphrase,
              controller: _p2,
              shown: _shown,
              onToggle: () => setState(() => _shown = !_shown),
              action: TextInputAction.done,
              onSubmit: _busy ? null : _create,
            ),
            const SizedBox(height: 12),
            EaseSize(
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : RiseSwap(
                      child: Text(
                        _error!,
                        key: ValueKey(_error),
                        style: HaloType.sans(size: 12, color: HaloColors.rose),
                      ),
                    ),
            ),
            const Spacer(),
            HaloPrimaryButton(
              label: _busy
                  ? (_progress > 0
                        ? l10n.backupWriting(percent(_progress))
                        : l10n.backupCreating)
                  : (_move
                        ? l10n.backupMakeTheFileAnd
                        : l10n.backupCreateBackup),
              // the percent itself changes in place
              phase: '${(_busy, _progress > 0, _move)}',
              busy: _busy,
              onTap: _create,
            ),
            // the file, as far as it is written
            EaseSize(
              child: !_busy || _progress <= 0
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: HaloBar(value: _progress, height: 3),
                    ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

// one of the two ways: the whole card takes the tap, and the picked one
// fills its ring on the house spring
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
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      selected: on,
      inMutuallyExclusiveGroup: true,
      child: PressScale(
        scale: 0.98,
        onTap: onTap,
        child: AnimatedContainer(
          duration: still ? Duration.zero : const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: on ? HaloColors.amberSoft : HaloColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: on ? HaloColors.amber : HaloColors.line,
              width: on ? 1 : 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: _Ring(on: on),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// a ring that fills on the house spring, with a little overshoot
class _Ring extends StatefulWidget {
  const _Ring({required this.on});
  final bool on;

  @override
  State<_Ring> createState() => _RingState();
}

class _RingState extends State<_Ring> with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController.unbounded(
    vsync: this,
    value: widget.on ? 1 : 0,
  );

  @override
  void didUpdateWidget(_Ring old) {
    super.didUpdateWidget(old);
    if (old.on == widget.on) return;
    final to = widget.on ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
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
        return SizedBox.square(
          dimension: 20,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Color.lerp(
                      HaloColors.line2,
                      HaloColors.amber,
                      v.clamp(0.0, 1.0),
                    )!,
                    width: 1.4,
                  ),
                ),
              ),
              Transform.scale(
                scale: v.clamp(0.0, 1.25),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HaloColors.amber,
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

// what a backup that failed says. the engine's and the system's own words
// are for the log; only the hidden chats closing has something to do
@visibleForTesting
String backupFailLine(Object e) {
  if (e is BackupError && e.message == l10n.backupHiddenGone) {
    return e.message;
  }
  return l10n.backupNotMade;
}
