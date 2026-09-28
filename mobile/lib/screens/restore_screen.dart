// SPDX-License-Identifier: GPL-3.0-or-later
// pick the backup file, type the passphrase, see what is about to come back,
// then restore. every failure names its cause. recovery is the encrypted
// file plus its passphrase; there is no word list. a step done turns its
// number into a tick.
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
import '../widgets/ease_size.dart';
import '../widgets/halo_bar.dart';
import '../widgets/press_scale.dart';
import '../widgets/stagger_in.dart';
import '../widgets/swap.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../backup_stream.dart' show isBackupV2;
import '../widgets/halo_sheet.dart';
import '../widgets/motion.dart' show haloRoute, kHouseCurve, motionStill;
import '../widgets/sheet_handle.dart';
import 'pin_flow_screen.dart';
import '../l10n/l10n.dart';
import '../l10n/dates.dart';
import '../l10n/numbers.dart';
import '../dlog.dart';

class RestoreScreen extends StatefulWidget {
  // called after a restore instead of the 'reopen kryfo' notice, so
  // onboarding can go straight to the home shell
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
    final result = await lockState.hold(() => FilePicker.pickFile());
    if (result == null || result.path == null) return;
    final path = result.path!;
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
            setState(() => _error = l10n.restoreThatFileIsNot);
          }
          return;
        }
        blob = (await File(path).readAsString()).trim();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = l10n.restoreThisFileIsDamaged);
      }
      return;
    } finally {
      await shredPicked([result]);
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
      setState(() => _error = l10n.restoreTypeThePassphraseThe);
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
        _error = l10n.restoreThisFileIsDamaged;
        _busy = false;
      });
    }
  }

  Future<void> _restore() async {
    final blob = _blob;
    final path = _path;
    final s = _summary;
    if ((blob == null && path == null) || s == null) return;
    // what comes back, what does not, and plainly: the old phone stops
    // receiving the moment this one sends
    final go = await _moveSheet(s);
    if (!go || !mounted) return;
    if (appState.onboardingComplete) {
      final ok = await showConfirmSheet(
        context,
        title: l10n.restoreReplaceTheAccountOn,
        line: l10n.restoreWhatIsHereNow,
        yes: l10n.restoreReplaceIt,
      );
      if (!ok) return;
    }
    // a handle is proved with the key that is about to go, so it is released
    // first, while the key is still here. left behind, its public page would
    // hand out an invite no one holds.
    final mine = appState.myHandle;
    final sameIdentity = s.haloId == appState.sessionId;
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
      } catch (e) {
        // read as not released: the sheet below says so
        dlog('restore: handle release (${e.runtimeType})');
      }
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
          title: l10n.restoreCouldNotBeReleased(mine),
          line: l10n.restoreTheRegistryDidNot(mine),
          yes: l10n.restoreRestoreAnyway,
          keep: l10n.restoreNotYet,
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
      // hidden chats came back: they open with a PIN chosen now, and the
      // app lock first if there is none
      if (restoredHidden) {
        await Navigator.of(context).push<bool>(
          haloRoute(const PinFlowScreen(flow: PinFlow.vault, restoring: true)),
        );
        if (!mounted) return;
      }
      if (widget.onRestored != null) {
        widget.onRestored!();
        return;
      }
      await showNoticeSheet(
        context,
        title: l10n.restoreRestored,
        line: l10n.restoreKryfoWillCloseNow(s.haloId),
        ok: l10n.restoreReopenKryfo,
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
        _error = l10n.restoreTheRestoreDidNot;
        _busy = false;
      });
    }
  }

  Future<bool> _moveSheet(BackupSummary s) async {
    final big = s.bytes > 50 * 1024 * 1024;
    final when = s.when;
    final name = s.haloId.isEmpty ? l10n.restoreThisIdentity : s.haloId;
    final about = when == null
        ? l10n.restoreThisBackupIsRestoring(name)
        : l10n.restoreThisBackupMadeOn(name, dayMonth(when), hourMinute(when));
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
                  l10n.restoreMoveYourKryfoHere,
                  style: HaloType.serif(size: 21, color: HaloColors.text),
                ),
                const SizedBox(height: 8),
                Text(
                  about,
                  style: HaloType.sans(
                    size: 13.5,
                    color: HaloColors.text2,
                    height: 1.45,
                  ),
                ),
                if (big) ...[
                  const SizedBox(height: 10),
                  Text(
                    l10n.restoreItHoldsOfPhotos(_mb(s.bytes)),
                    style: HaloType.sans(
                      size: 13.5,
                      color: HaloColors.amber,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _head(l10n.restoreWhatFollows),
                _item(l10n.restoreYourNameYourCode),
                _item(l10n.restoreEveryConversationBackTo),
                _item(
                  s.files > 0
                      ? l10n.restoreYourPhotosVoiceNotesCount(s.files)
                      : l10n.restoreYourPhotosVoiceNotes,
                ),
                _item(l10n.restoreYourOnionAddressSo),
                _item(l10n.restoreAnythingSentToYou),
                _item(l10n.restoreYourSupporterBadgeIf),
                if (s.hiddenChats != null) _item(l10n.restoreHiddenFollow),
                const SizedBox(height: 16),
                _head(l10n.restoreWhatDoesnT),
                _item(l10n.restoreTheOldPhoneStops, strong: true),
                if (s.moved != true)
                  _item(l10n.restoreIfThePhoneThis, strong: true),
                _item(l10n.restoreNotificationsNeedSettingUp),
                const SizedBox(height: 22),
                _Primary(
                  label: l10n.restoreMoveItHere,
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
                        l10n.restoreNotNow,
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
          padding: const EdgeInsetsDirectional.only(top: 7, end: 10),
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
    final moving = _busy && !_releasing && s != null;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          l10n.restoreRestore,
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
          children: staggerAllIn(context, [
            Text(
              l10n.restoreFromABackupFile,
              style: HaloType.serif(size: 26, color: HaloColors.text),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.restoreABackupBringsBack,
              style: HaloType.sans(
                size: 13,
                color: HaloColors.text2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            _Step(
              n: '1',
              label: l10n.restoreTheFile,
              done: _hasFile,
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
                        child: RiseSwap(
                          child: Text(
                            _fileName ?? l10n.restorePickTheBackupFile,
                            key: ValueKey(_fileName),
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            EaseSize(
              duration: const Duration(milliseconds: 220),
              child: !_hasFile
                  ? const SizedBox(width: double.infinity)
                  : _Step(
                      n: '2',
                      label: l10n.restoreThePassphrase,
                      done: s != null,
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
                          // never offered to the phone's autofill service
                          autofillHints: null,
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
                            hintText: l10n.restoreTheOneTheFile,
                            hintStyle: HaloType.mono(
                              size: 12.5,
                              color: HaloColors.text3,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            EaseSize(
              duration: const Duration(milliseconds: 220),
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
            EaseSize(
              duration: const Duration(milliseconds: 240),
              child: s == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: _Step(
                        n: '3',
                        label: l10n.restoreWhatComesBack,
                        child: _SummaryCard(summary: s),
                      ),
                    ),
            ),
            const SizedBox(height: 22),
            if (s == null)
              _Primary(
                label: _busy ? l10n.restoreChecking : l10n.restoreCheckTheFile,
                onTap: _busy || !_hasFile ? null : _check,
              )
            else
              _Primary(
                label: _releasing
                    ? l10n.restoreReleasingYourHandle
                    : _busy
                    ? (_path != null && _progress > 0
                          ? l10n.restoreMoving(percent(_progress))
                          : l10n.restoreRestoring)
                    : l10n.restoreRestore,
                // the percent changes in place, not rising each time
                phase: _releasing
                    ? 'release'
                    : _busy
                    ? (_path != null && _progress > 0 ? 'moving' : 'busy')
                    : 'restore',
                onTap: _busy ? null : _restore,
              ),
            // the move, as far as it has got
            EaseSize(
              child: !moving || _path == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: HaloBar(value: _progress, height: 3),
                    ),
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
                      l10n.restoreNotThisOne,
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
  final bool done;
  final Widget child;
  const _Step({
    required this.n,
    required this.label,
    required this.child,
    this.done = false,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          _StepMark(n: n, done: done),
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

// a step's number, or its tick once done: the tick pops in on the house
// spring. simply swaps with less movement
class _StepMark extends StatelessWidget {
  final String n;
  final bool done;
  const _StepMark({required this.n, required this.done});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 14,
      child: AnimatedSwitcher(
        duration: motionStill(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
        transitionBuilder: (c, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(
              begin: 0.4,
              end: 1.0,
            ).animate(CurvedAnimation(parent: a, curve: kHouseCurve)),
            child: c,
          ),
        ),
        child: done
            ? Icon(
                Icons.check_rounded,
                key: const ValueKey('done'),
                size: 14,
                color: HaloColors.green,
              )
            : Text(
                '0$n',
                key: const ValueKey('n'),
                style: HaloType.mono(
                  size: 10,
                  color: HaloColors.amber,
                  letter: 0.2,
                  weight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final BackupSummary summary;
  const _SummaryCard({required this.summary});
  @override
  Widget build(BuildContext context) {
    final w = summary.when;
    final date = w == null
        ? l10n.restoreDateUnknown
        : '${dayMonthYear(w)}, ${hourMinute(w)}';
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
            summary.haloId.isEmpty ? l10n.restoreAnIdentity : summary.haloId,
            style: HaloType.mono(
              size: 16,
              weight: FontWeight.w600,
              color: HaloColors.amber,
            ),
          ),
          const SizedBox(height: 10),
          _line(l10n.restoreMade, date),
          _line(l10n.restoreContacts, '${summary.contacts}'),
          _line(l10n.restoreMessages, '${summary.messages}'),
          if (summary.hiddenChats case final n?)
            _line(l10n.restoreHiddenChats, '$n'),
          if (summary.files > 0)
            _line(
              l10n.restoreAttachments,
              '${whole(summary.files)} · ${_mb(summary.bytes)}',
            ),
          const SizedBox(height: 8),
          Text(
            l10n.restoreMessagesSentOrReceived,
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
        Expanded(
          child: Text(
            v,
            style: HaloType.mono(size: 12.5, color: HaloColors.text, letter: 0),
          ),
        ),
      ],
    ),
  );
}

class _Primary extends StatelessWidget {
  final String label;
  // what the label says, for when it changes: a new phase rises in
  final String? phase;
  final VoidCallback? onTap;
  const _Primary({required this.label, required this.onTap, this.phase});
  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 160),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? HaloColors.amber : HaloColors.surface3,
          borderRadius: BorderRadius.circular(13),
        ),
        child: RiseSwap(
          alignment: Alignment.center,
          child: Text(
            label,
            key: ValueKey(phase ?? label),
            style: HaloType.sans(
              size: 14,
              weight: FontWeight.w600,
              color: on ? HaloColors.onAmber : HaloColors.text3,
            ),
          ),
        ),
      ),
    );
  }
}

String _mb(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return l10n.restoreGb(decimal((bytes / (1024 * 1024 * 1024)), 1));
  }
  return l10n.restoreMb(whole((bytes / (1024 * 1024)).round()));
}
