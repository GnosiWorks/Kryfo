// SPDX-License-Identifier: GPL-3.0-or-later
// note to self out to a file: text or markdown, locked with a passphrase
// unless the person turns that off past a warning, then handed to the save
// window the way a backup is
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backup.dart' show kBackupMinPassphrase, sessionBackupHasHidden;
import '../bidi_safe.dart' show unmarked;
import '../dlog.dart';
import '../l10n/l10n.dart';
import '../lock_guard.dart' show LockDropped;
import '../lock_state.dart';
import '../main.dart' hide live;
import '../notes_export.dart';
import '../open_file.dart' show ShareEnd, shareFileOut;
import '../theme.dart';
import '../tools/age_ffi.dart';
import '../tools/lock_words.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/ease_size.dart';
import '../widgets/fit_column.dart';
import '../widgets/halo_bar.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/halo_switch.dart';
import '../widgets/press_scale.dart';
import '../widgets/secret_field.dart';
import '../widgets/stagger_in.dart';
import '../widgets/swap.dart';
import 'backup_screen.dart'
    show ChoiceCard, SaveAnswer, SaveState, saveDocumentOut, shredMade;
import 'lock_file_screen.dart' show ageErrorBody, ageErrorTitle;
import 'notes_screen.dart' show kNotesPeerId;

/// the open notes, everyday or a decoy's: never while hidden chats are open
bool notesExportHere() => !lockState.inVault && !sessionBackupHasHidden;

class NotesExportScreen extends StatefulWidget {
  const NotesExportScreen({super.key});
  @override
  State<NotesExportScreen> createState() => _NotesExportScreenState();
}

class _NotesExportScreenState extends State<NotesExportScreen> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  NotesFormat _format = NotesFormat.text;
  bool _lock = true;
  bool _shown = false;
  int _count = 0;
  bool _files = false;
  bool _busy = false;
  bool _writing = false;
  bool _stop = false;
  double _progress = 0;
  String? _error;
  // the made file while it waits to be saved or shared. another choice or
  // new words make it stale
  ({String path, String name})? _made;
  // the export run the file was made in: a lock since has taken it
  int _madeRun = 0;
  bool _gone = false;
  bool _saving = false;
  // kryfo stopped waiting for the last save: android may still read the file
  bool _lost = false;
  bool _notSaved = false;
  final _ways = GlobalKey();

  @override
  void initState() {
    super.initState();
    appState.forceSecure(true);
    _p1.addListener(_typed);
    _p2.addListener(_typed);
    notesExportRun.addListener(_runMoved);
    unawaited(_count0());
  }

  // a lock took the waiting file with it. one being made stops on its own,
  // one being saved is seen to when the save ends
  void _runMoved() {
    if (!mounted || _made == null || _saving) return;
    setState(() {
      _made = null;
      _notSaved = false;
      _gone = true;
      _busy = false;
    });
  }

  Future<void> _count0() async {
    if (!notesExportHere()) return;
    final notes = await session.messagesFor(kNotesPeerId);
    final files = noteFiles(notes).isNotEmpty;
    if (mounted) {
      setState(() {
        _count = notes.length;
        _files = files;
      });
    }
  }

  // words typed after a file was made make a new one
  void _typed() {
    if (!mounted) return;
    setState(() {
      _error = null;
      if (!_busy && (_p1.text.isNotEmpty || _p2.text.isNotEmpty)) _drop();
    });
  }

  @override
  void dispose() {
    appState.forceSecure(false);
    notesExportRun.removeListener(_runMoved);
    _stop = true;
    // one still being saved is let go when that ends
    final made = _made;
    if (made != null && !_saving) {
      _made = null;
      unawaited(shredMade(made.path, lost: _lost));
    }
    _p1.removeListener(_typed);
    _p2.removeListener(_typed);
    _p1
      ..clear()
      ..dispose();
    _p2
      ..clear()
      ..dispose();
    super.dispose();
  }

  // the made file goes: another format or the other way was picked
  void _drop() {
    final made = _made;
    if (made == null || _saving) return;
    _made = null;
    unawaited(shredMade(made.path, lost: _lost));
    _notSaved = false;
  }

  void _pick(NotesFormat f) {
    if (_busy || f == _format) return;
    setState(() {
      _drop();
      _format = f;
    });
  }

  Future<void> _toggleLock(bool on) async {
    if (_busy || on == _lock) return;
    if (!on) {
      final ok = await showConfirmSheet(
        context,
        title: l10n.notesExportPlainTitle,
        line: l10n.notesExportPlainLine,
        yes: l10n.notesExportPlainYes,
        keep: l10n.notesExportKeepLock,
        rose: false,
      );
      if (!ok || !mounted) return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _drop();
      _lock = on;
      _error = null;
    });
  }

  void _suggest() {
    String words;
    try {
      words = suggestPassphrase();
    } catch (_) {
      words = '';
    }
    if (words.isEmpty) {
      showHaloToast(context, l10n.lockFileCouldNotMakeOne);
      return;
    }
    setState(() {
      _p1.text = words;
      _p2.text = words;
      _shown = true;
    });
    showHaloToast(context, l10n.lockFileWriteItDownBefore);
  }

  Future<void> _export() async {
    if (_busy) return;
    final pass = _lock ? _p1.text : null;
    if (pass != null) {
      if (pass.runes.length < kBackupMinPassphrase) {
        setState(() => _error = l10n.backupPassphraseMustBeAt);
        return;
      }
      if (pass != _p2.text) {
        setState(() => _error = l10n.backupPassphrasesDonTMatch);
        return;
      }
    }
    // the session changed under the screen: nothing of it is read
    if (!notesExportHere()) {
      Navigator.of(context).pop();
      return;
    }
    FocusScope.of(context).unfocus();
    _drop();
    final run = notesExportRun.value;
    setState(() {
      _gone = false;
      _error = null;
      _busy = true;
      _writing = true;
      _stop = false;
      _progress = 0;
    });
    ({String path, String name}) made;
    try {
      final notes = await session.messagesFor(kNotesPeerId);
      made = await makeNotesExport(
        notes,
        format: _format,
        passphrase: pass,
        dir: await notesOutDir(),
        stopped: () => _stop,
        progress: (v) {
          if (mounted) setState(() => _progress = v);
        },
        run: run,
      );
    } on NotesExportStopped {
      if (mounted) {
        setState(() {
          _busy = false;
          _writing = false;
          _gone = notesExportRun.value != run;
        });
      }
      return;
    } catch (e) {
      final age = e is NotesExportFailed ? e.age : null;
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _error = e is NotesExportTooLarge
              ? l10n.notesExportTooLarge
              : age == AgeError.needsMemory
              ? '${ageErrorTitle(age!)} ${ageErrorBody(age)}'
              : l10n.notesExportFailed;
          _busy = false;
          _writing = false;
        });
      }
      return;
    }
    if (!mounted) {
      // the lock took the screen before the file was offered
      await shredFile(made.path);
      return;
    }
    _p1.clear();
    _p2.clear();
    if (notesExportRun.value != run) {
      // a lock came as it ended: nothing of it is offered
      await shredFile(made.path);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _writing = false;
        _gone = true;
      });
      return;
    }
    _made = made;
    _madeRun = run;
    setState(() => _writing = false);
    await _handOver(save: true);
  }

  // the save window first, the share sheet when it is backed out of or
  // missing, as a backup is. a save that failed, or whose answer never came,
  // says so and offers both again
  Future<void> _handOver({required bool save}) async {
    final made = _made;
    if (made == null || _saving) return;
    setState(() {
      _busy = true;
      _saving = true;
      _notSaved = false;
      _error = null;
    });
    SaveAnswer answer = (state: SaveState.cancelled, where: null, lost: false);
    var shared = false;
    var dropped = false;
    var gone = false;
    // a lock while the window was asked for took the file: nothing to hand
    Future<void> there() async {
      if (notesExportRun.value != _madeRun || !await File(made.path).exists()) {
        throw const _Gone();
      }
    }

    try {
      if (save) {
        await lockState.hold(() async {
          await there();
          answer = await saveDocumentOut(made.path, made.name);
          _lost = answer.lost;
          // a lock or a switch only unlinks it while android may read it
          if (_lost) notesExportHanded(made.path);
          return answer;
        });
      }
      if ((!save || answer.state == SaveState.cancelled) && mounted) {
        // only an app picked from the sheet has it: one closed keeps the file
        shared =
            await lockState.hold(() async {
              await there();
              return shareFileOut(
                made.path,
                name: made.name,
                subject: l10n.notesExportSubject,
                // plaintext never outlives the lock in the cache
                quiet: !made.name.endsWith('.age'),
              );
            }) ==
            ShareEnd.picked;
      }
    } on LockDropped {
      dropped = true;
    } on _Gone {
      gone = true;
    } catch (e) {
      dlog('notes export: not handed over (${e.runtimeType})');
    }
    _saving = false;
    final checked = answer.state == SaveState.saved;
    final out = checked || answer.state == SaveState.unchecked || shared;
    if (out || dropped || !mounted) {
      // saved, or the share sheet has a copy of its own: this one goes
      _made = null;
      unawaited(shredMade(made.path, lost: _lost));
      if (!mounted) return;
      if (out && !dropped) {
        final where = unmarked(answer.where ?? '').trim();
        if (checked) {
          showHaloToast(
            context,
            where.isEmpty
                ? l10n.notesExportSaved
                : l10n.notesExportSavedIn(where),
          );
        } else if (!shared) {
          showHaloToast(context, l10n.notesExportSavedUnchecked);
        }
      }
      Navigator.of(context).pop();
      return;
    }
    if (gone) {
      _made = null;
      unawaited(shredMade(made.path, lost: _lost));
      setState(() {
        _busy = false;
        _gone = true;
      });
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _busy = false;
      _notSaved = true;
    });
    // on a short screen the buttons sit below the fold
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

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: !_writing,
      onPopInvokedWithResult: (done, _) {
        if (!done && _writing) setState(() => _stop = true);
      },
      child: Scaffold(
        backgroundColor: HaloColors.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: BackButton(color: HaloColors.text2),
          title: Text(l10n.notesExportNotes, style: HaloType.pageTitle()),
        ),
        body: SafeArea(
          child: FitColumn(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: staggerAllIn(context, [
              // the count rises in once the notes are read
              RiseSwap(
                child: Text(
                  _count == 0
                      ? ''
                      : [
                          l10n.notesExportCount(_count),
                          if (_files) l10n.notesExportZip,
                        ].join(' '),
                  key: ValueKey(_count),
                  style: HaloType.sans(
                    size: 13.5,
                    color: HaloColors.text2,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ChoiceCard(
                on: _format == NotesFormat.text,
                title: l10n.notesExportText,
                line: l10n.notesExportTextLine,
                onTap: () => _pick(NotesFormat.text),
              ),
              const SizedBox(height: 8),
              ChoiceCard(
                on: _format == NotesFormat.markdown,
                title: l10n.notesExportMarkdown,
                line: l10n.notesExportMarkdownLine,
                onTap: () => _pick(NotesFormat.markdown),
              ),
              const SizedBox(height: 20),
              // the whole row turns it, as the switch does
              MergeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _busy ? null : () => _toggleLock(!_lock),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.notesExportLock,
                              style: HaloType.sans(
                                size: 14.5,
                                weight: FontWeight.w600,
                                color: HaloColors.text,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              l10n.notesExportLockLine,
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
                      HaloSwitch(
                        value: _lock,
                        onChanged: _busy ? null : _toggleLock,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // the fields, or the plain file's warning, fade over each other
              EaseSize(
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                child: FadeSwap(
                  child: _lock
                      ? KeyedSubtree(
                          key: const ValueKey('lock'),
                          child: _fields(),
                        )
                      : _Warn(
                          key: const ValueKey('plain'),
                          text: l10n.notesExportPlainLine,
                        ),
                ),
              ),
              const SizedBox(height: 12),
              EaseSize(
                child: _error == null
                    ? const SizedBox(width: double.infinity)
                    : RiseSwap(
                        child: Text(
                          _error!,
                          key: ValueKey(_error),
                          style: HaloType.sans(
                            size: 12,
                            color: HaloColors.rose,
                          ),
                        ),
                      ),
              ),
              const Spacer(),
              EaseSize(
                child: RiseSwap(
                  alignment: Alignment.topCenter,
                  child: !_notSaved && !_gone
                      ? const SizedBox(
                          key: ValueKey(false),
                          width: double.infinity,
                        )
                      : Padding(
                          key: ValueKey(_gone ? 'gone' : 'not saved'),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: Text(
                              _gone
                                  ? l10n.notesExportGone
                                  : l10n.notesExportNotSaved,
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
                    ? l10n.notesExportWorking
                    : l10n.notesExport,
                phase: '${(_busy, _saving, _notSaved)}',
                busy: _busy,
                onTap: _count == 0
                    ? null
                    : _notSaved
                    ? () => _handOver(save: true)
                    : _export,
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
              EaseSize(
                child: !_writing || _progress <= 0
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
      ),
    );
  }

  Widget _fields() {
    final text = _p1.text;
    final short = text.isNotEmpty && text.runes.length < kBackupMinPassphrase;
    final grade = gradePassword(text);
    final differ =
        _p2.text.isNotEmpty && text != _p2.text && !short && text.isNotEmpty;
    final color = switch (grade) {
      _ when short => HaloColors.amber,
      PassGrade.strong => HaloColors.green,
      PassGrade.none => HaloColors.text2,
      _ => HaloColors.amber,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SecretField(
          label: l10n.backupPassphrase,
          controller: _p1,
          shown: _shown,
          enabled: !_busy,
          onToggle: () => setState(() => _shown = !_shown),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 0, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: RiseSwap(
                  child: Text(
                    short
                        ? l10n.lockWordsTooShortAtLeast(kBackupMinPassphrase)
                        : gradeLine(grade),
                    key: ValueKey((short, grade)),
                    style: HaloType.sans(size: 12, height: 1.35, color: color),
                  ),
                ),
              ),
              // a long language wraps it rather than run off the edge
              Flexible(
                child: PressScale(
                  label: l10n.lockFileSuggestFourWords,
                  onTap: _busy ? null : _suggest,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 10),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        widthFactor: 1,
                        heightFactor: 1,
                        child: ExcludeSemantics(
                          child: Text(
                            l10n.lockFileSuggestFourWords,
                            textAlign: TextAlign.end,
                            style: HaloType.sans(
                              size: 12.5,
                              weight: FontWeight.w600,
                              color: HaloColors.amber,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SecretField(
          label: l10n.backupConfirmPassphrase,
          controller: _p2,
          shown: _shown,
          enabled: !_busy,
          onToggle: () => setState(() => _shown = !_shown),
          action: TextInputAction.done,
          onSubmit: _busy ? null : _export,
        ),
        EaseSize(
          child: !differ
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(4, 7, 4, 0),
                  child: Text(
                    l10n.lockFileTheTwoDoNot,
                    style: HaloType.sans(size: 12, color: HaloColors.amber),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Gone implements Exception {
  const _Gone();
}

// the plain file's warning: calm, in amber, where the fields were
class _Warn extends StatelessWidget {
  const _Warn({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: HaloColors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: HaloColors.amber.withValues(alpha: 0.28),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_open_rounded, size: 18, color: HaloColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: HaloType.sans(
                size: 13,
                height: 1.45,
                color: HaloColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
