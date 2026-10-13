// SPDX-License-Identifier: GPL-3.0-or-later
// makes an encrypted backup file and hands it to the system save dialog, or
// to the share sheet when that is refused.

import 'dart:async';

import '../bidi_safe.dart' show unmarked;
import '../lock_guard.dart';
import '../lock_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../open_file.dart' show shareFileOut;
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

// a test's backup, in place of the engine's
@visibleForTesting
Future<void> Function(String path, void Function(int done, int total) progress)?
backupForTest;

class BackupScreen extends StatefulWidget {
  // from the hidden chats setup: a copy to keep that holds the chats just
  // hidden, never a move
  final bool withHiddenChats;
  const BackupScreen({super.key, this.withHiddenChats = false});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
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
  // the file is being written. the save dialog only opens after
  bool _writing = false;
  // the made file while it waits to be saved or shared, and the words it
  // was made with: other words make it stale
  ({String path, String name, bool move, String p1, String p2})? _made;
  // the save dialog is up or the copy after it runs
  bool _saving = false;
  // the last hand-over did not go: a calm line and two ways on
  bool _notSaved = false;
  // both fields show what was typed, or neither
  bool _shown = false;
  // the two ways on, brought into view when they come
  final _ways = GlobalKey();

  @override
  void initState() {
    super.initState();
    appState.forceSecure(true);
    _p1.addListener(_edited);
    _p2.addListener(_edited);
  }

  Future<void> _create() async {
    final pw = _p1.text.trim();
    final pw2 = _p2.text.trim();
    if (pw.isEmpty || pw.length < kBackupMinPassphrase) {
      setState(() => _error = l10n.backupPassphraseMustBeAt);
      return;
    }
    if (pw != pw2) {
      setState(() => _error = l10n.backupPassphrasesDonTMatch);
      return;
    }
    _drop();
    setState(() {
      _error = null;
      _busy = true;
      _writing = true;
    });
    final sayLater = _notMadeLater();
    final String path;
    final String name;
    final move = _move && !widget.withHiddenChats;
    try {
      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      name = 'kryfo-backup-$ts.kryfo';
      path = p.join(tempDir.path, name);
      void onProgress(int a, int b) {
        if (mounted && b > 0) setState(() => _progress = a / b);
      }

      if (backupForTest case final make?) {
        await make(path, onProgress);
      } else {
        await createBackupFile(
          pw,
          path,
          move: move,
          withHiddenChats: widget.withHiddenChats,
          onProgress: onProgress,
        );
      }
    } catch (e) {
      dlog('backup: not made (${e.runtimeType})');
      sayLater();
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _error = backupFailLine(e);
          _busy = false;
          _writing = false;
        });
      }
      return;
    }
    _made = (path: path, name: name, move: move, p1: _p1.text, p2: _p2.text);
    if (!mounted) {
      // the lock took the screen before the file was offered
      _drop();
      sayLater();
      return;
    }
    setState(() => _writing = false);
    await _handOver(save: true, sayLater: sayLater);
  }

  // a backup the lock takes the screen from before it is handed over is
  // said not made, later. where it began: a lock that takes the screen away
  // is told by a new navigator
  VoidCallback _notMadeLater() {
    final rev = navRevision.value;
    final decoy = lockState.inDecoy;
    final hidden = sessionBackupHasHidden;
    _notMadeGen++;
    return () {
      if (!mounted && navRevision.value != rev) {
        unawaited(_sayNotMadeLater(decoy: decoy, hidden: hidden));
      }
    };
  }

  // the made file goes: other words or the other way were picked
  void _drop() {
    final made = _made;
    if (made == null || _saving) return;
    _made = null;
    unawaited(shredFile(made.path));
    if (_notSaved && mounted) setState(() => _notSaved = false);
  }

  void _edited() {
    final made = _made;
    if (made == null || _busy) return;
    if (_p1.text != made.p1 || _p2.text != made.p2) _drop();
  }

  void _choose(bool move) {
    if (_busy || move == _move) return;
    _drop();
    setState(() => _move = move);
  }

  // the system save dialog first, the share sheet when it is backed out of
  // or missing. neither reads the file into memory. a save that failed, or
  // whose answer never came back, says so and offers both again
  Future<void> _handOver({required bool save, VoidCallback? sayLater}) async {
    final made = _made;
    if (made == null || _saving) return;
    final later = sayLater ?? _notMadeLater();
    setState(() {
      _busy = true;
      _saving = true;
      _notSaved = false;
      _error = null;
    });
    var handed = false;
    try {
      var answer = (state: SaveState.cancelled, where: null as String?);
      if (save) {
        answer = await lockState.hold(
          () => saveDocumentOut(made.path, made.name),
        );
      }
      if (answer.state == SaveState.saved) {
        handed = true;
        if (mounted) {
          final where = answer.where == null ? '' : unmarked(answer.where!);
          showHaloToast(
            context,
            where.trim().isEmpty
                ? l10n.backupBackupSavedKeepThe
                : l10n.backupSavedIn(where),
          );
        }
      } else if (answer.state == SaveState.cancelled && mounted) {
        handed = await _share(made.path);
      }
    } catch (e) {
      dlog('backup: not handed over (${e.runtimeType})');
    }
    _saving = false;
    if (handed) {
      // saved, or the share sheet has a copy of its own: this one goes.
      // for a move, from here this phone is retired and the next screen
      // says so
      _made = null;
      await shredFile(made.path);
      if (made.move) await appState.markMoved();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (!mounted) {
      // gone under a lock: nothing handed, nothing retired
      _made = null;
      await shredFile(made.path);
      later();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _busy = false;
      _notSaved = true;
    });
    // on a short screen the buttons sit below the fold: once they have
    // eased in, the page shows them
    final still = MediaQuery.disableAnimationsOf(context);
    await Future<void>.delayed(
      still ? Duration.zero : const Duration(milliseconds: 280),
    );
    final ways = _ways.currentContext;
    if (!mounted || ways == null || !ways.mounted) return;
    await Scrollable.ensureVisible(
      ways,
      alignment: 1,
      duration: still ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  // true only once the copy is made and the sheet is up
  Future<bool> _share(String path) => lockState.hold(
    () => shareFileOut(
      path,
      backup: true,
      subject: l10n.backupKryfoBackup,
      text: l10n.backupYourEncryptedKryfoBackup,
    ),
  );

  @override
  void dispose() {
    appState.forceSecure(false);
    // one still being saved is let go when that ends
    final made = _made;
    if (made != null && !_saving) {
      _made = null;
      unawaited(shredFile(made.path));
    }
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
                onTap: () => _choose(false),
              ),
              const SizedBox(height: 8),
              _Choice(
                on: _move,
                title: l10n.backupMoveToAnotherDevice,
                line: l10n.backupTheFileTakesThis,
                onTap: () => _choose(true),
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
            // not saved: said calmly, with the file still here to try again
            EaseSize(
              child: RiseSwap(
                alignment: Alignment.topCenter,
                child: !_notSaved
                    ? const SizedBox(
                        key: ValueKey(false),
                        width: double.infinity,
                      )
                    : Padding(
                        key: const ValueKey(true),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: Text(
                            l10n.backupNotSaved,
                            textAlign: TextAlign.center,
                            style: HaloType.sans(
                              size: 13,
                              color: HaloColors.text,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            HaloPrimaryButton(
              label: _saving
                  ? l10n.backupSaving
                  : _notSaved
                  ? l10n.commonTryAgain
                  : _busy
                  ? (_progress > 0
                        ? l10n.backupWriting(percent(_progress))
                        : l10n.backupCreating)
                  : (_move
                        ? l10n.backupMakeTheFileAnd
                        : l10n.backupCreateBackup),
              // the percent itself changes in place
              phase: '${(_busy, _progress > 0, _move, _saving, _notSaved)}',
              busy: _busy,
              onTap: _notSaved ? () => _handOver(save: true) : _create,
            ),
            EaseSize(
              child: RiseSwap(
                alignment: Alignment.topCenter,
                child: !_notSaved
                    ? const SizedBox(
                        key: ValueKey(false),
                        width: double.infinity,
                      )
                    : Padding(
                        key: const ValueKey(true),
                        padding: const EdgeInsets.only(top: 10),
                        child: SizedBox(
                          key: _ways,
                          width: double.infinity,
                          child: HaloGhostButton(
                            label: l10n.backupShareInstead,
                            onTap: () => _handOver(save: false),
                          ),
                        ),
                      ),
              ),
            ),
            // the file, as far as it is written
            EaseSize(
              child: !_busy || _saving || _progress <= 0
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: HaloBar(value: _progress, height: 3),
                    ),
            ),
            // the folder stays empty until the file is done and saved
            EaseSize(
              child: RiseSwap(
                alignment: Alignment.topCenter,
                child: !_writing || _progress <= 0
                    ? const SizedBox(
                        key: ValueKey(false),
                        width: double.infinity,
                      )
                    : Padding(
                        key: const ValueKey(true),
                        padding: const EdgeInsets.only(top: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: Text(
                            l10n.backupSaveComesAfter,
                            textAlign: TextAlign.center,
                            style: HaloType.sans(
                              size: 12.5,
                              color: HaloColors.text2,
                              height: 1.4,
                            ),
                          ),
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

// a backup the lock took the screen from before the file was handed over
// is not made. said once the same chats are open again and never elsewhere:
// in the everyday app it would tell of hidden chats. a newer backup drops it
int _notMadeGen = 0;

Future<void> _sayNotMadeLater({
  required bool decoy,
  required bool hidden,
}) async {
  final gen = _notMadeGen;
  bool same() =>
      gen == _notMadeGen &&
      !lockGuard.isLocked() &&
      lockState.inDecoy == decoy &&
      sessionBackupHasHidden == hidden;
  while (gen == _notMadeGen) {
    while (!same()) {
      if (gen != _notMadeGen) return;
      final moved = Completer<void>();
      void on() {
        if (!moved.isCompleted) moved.complete();
      }

      lockState.addListener(on);
      try {
        await moved.future;
      } finally {
        lockState.removeListener(on);
      }
    }
    // the session's navigator is built on the next frame
    await WidgetsBinding.instance.endOfFrame;
    final ctx = rootNavKey.currentState?.overlay?.context;
    if (ctx == null || !ctx.mounted || !same()) continue;
    showHaloToast(ctx, l10n.backupNotMade, still: same);
    return;
  }
}

enum SaveState { saved, cancelled, failed }

// the save dialog's answer, a map from android. a plain yes or no is a
// saved file or a dialog backed out of
({SaveState state, String? where}) _saveAnswer(Object? r) {
  if (r == true) return (state: SaveState.saved, where: null);
  if (r is Map) {
    final where = r['where'];
    return (
      state: switch (r['state']) {
        'saved' => SaveState.saved,
        'cancelled' => SaveState.cancelled,
        _ => SaveState.failed,
      },
      where: where is String ? where : null,
    );
  }
  return (state: SaveState.cancelled, where: null);
}

// how often a missing answer is looked into, and how long a copy may sit
// without a byte moving
const _saveCheck = Duration(seconds: 3);
const _copyStall = Duration(seconds: 30);

// the system save dialog, then android's copy into what was picked.
// android hands the answer back before kryfo is in front again, so one
// still missing a few seconds after, with no copy running, is lost and
// counts as not saved: never a screen left waiting
Future<({SaveState state, String? where})> saveDocumentOut(
  String path,
  String name,
) async {
  const channel = MethodChannel('halo/platform');
  const lostOne = (state: SaveState.failed, where: null);
  final lost = Completer<({SaveState state, String? where})>();
  var strikes = 0;
  var copied = -1;
  var still = Duration.zero;
  var asking = false;
  final watch = Timer.periodic(_saveCheck, (_) async {
    if (asking || lost.isCompleted) return;
    final life = WidgetsBinding.instance.lifecycleState;
    if (life != null && life != AppLifecycleState.resumed) {
      // the dialog is up, or the app is not shown again yet
      strikes = 0;
      return;
    }
    asking = true;
    Object? s;
    try {
      s = await channel.invokeMethod<Object?>('saveDocumentState');
    } catch (_) {
      s = null;
    } finally {
      asking = false;
    }
    if (lost.isCompleted) return;
    if (s is Map && s['stage'] == 'copying') {
      strikes = 0;
      final n = (s['copied'] as num?)?.toInt() ?? 0;
      if (n != copied) {
        copied = n;
        still = Duration.zero;
      } else {
        still += _saveCheck;
        if (still >= _copyStall) lost.complete(lostOne);
      }
      return;
    }
    if (++strikes >= 2) {
      dlog('backup: the save answer never came');
      lost.complete(lostOne);
    }
  });
  try {
    final asked = channel
        .invokeMethod<Object?>('saveDocument', {'path': path, 'name': name})
        .then(_saveAnswer)
        .catchError((Object e) {
          dlog('backup: no save dialog (${e.runtimeType})');
          return (state: SaveState.cancelled, where: null as String?);
        });
    return await Future.any([asked, lost.future]);
  } finally {
    watch.cancel();
  }
}
