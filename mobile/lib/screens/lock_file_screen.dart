// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../seen_timers.dart';
import '../theme.dart';
import '../tools/age_ffi.dart';
import '../tools/lock_words.dart';
import '../tools/tools_bridge.dart';
import '../widgets/ease_size.dart';
import '../widgets/halo_switch.dart';
import '../widgets/press_scale.dart';
import '../widgets/secret_field.dart';
import '../widgets/stroke_icon.dart';
import '../widgets/swap.dart';
import '../widgets/tool_parts.dart';
import '../l10n/l10n.dart';
import '../widgets/halo_bar.dart';

final _fileIcon = [
  'M7 3.5h7l4 4V19a1.5 1.5 0 0 1-1.5 1.5h-9.5A1.5 1.5 0 0 1 5.5 19V5A1.5 1.5 0 0 1 7 3.5z',
  'M14 3.5V8h4',
];
final _lockIcon = [
  svgRect(5, 10.5, 14, 10, 2.5),
  'M8 10.5V8a4 4 0 0 1 8 0v2.5',
  'M12 14.5v2.2',
];
const _warnIcon = ['M12 4l9 15.5H3z', 'M12 10v4.5', 'M12 17v.3'];
const _shareIcon = [
  'M18 8a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
  'M6 14.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
  'M18 21a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
  'M8.2 10.8l7.6-4.1',
  'M8.2 13.2l7.6 4.1',
];
const _saveIcon = ['M12 4v11', 'M7.5 10.5L12 15l4.5-4.5', 'M5 19.5h14'];
String ageErrorTitle(AgeError e) => switch (e) {
  AgeError.wrongPassword => l10n.lockFileThatPasswordDoesNot,
  AgeError.corrupt => l10n.lockFileThisFileIsDamaged,
  AgeError.lockedToKey => l10n.lockFileThisFileWasLocked,
  AgeError.notAge => l10n.lockFileThisIsNotA,
  AgeError.needsMemory => l10n.lockFileNotEnoughFreeMemory,
  AgeError.cancelled => l10n.lockFileStopped,
  AgeError.emptyPassword => l10n.lockFileItNeedsAPassword,
  AgeError.io => l10n.lockFileKryfoCouldNotRead,
};

String ageErrorBody(AgeError e) => switch (e) {
  AgeError.wrongPassword => l10n.lockFileCheckCapitalsAndSpaces,
  AgeError.corrupt => l10n.lockFileItMayHaveBeen,
  AgeError.lockedToKey => l10n.lockFileItOpensWithThe,
  AgeError.notAge => l10n.lockFileKryfoOpensFilesLocked,
  AgeError.needsMemory => l10n.lockFileCloseAFewApps,
  AgeError.cancelled => l10n.lockFileNothingWasSaved,
  AgeError.emptyPassword => l10n.lockFileTypeOneOrLet,
  AgeError.io => l10n.lockFileTheAppThatHolds,
};

class FileCard extends StatelessWidget {
  final String name;
  final String detail;
  final VoidCallback? onChange;
  final List<String>? icon;
  final Color? tint;
  const FileCard({
    super.key,
    required this.name,
    required this.detail,
    this.onChange,
    this.icon,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final c = tint ?? HaloColors.violet;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HaloColors.line, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: StrokeIcon(icon ?? _fileIcon, size: 21, color: c),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HaloType.sans(
                    size: 14,
                    weight: FontWeight.w500,
                    color: HaloColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HaloType.sans(size: 11.5, color: HaloColors.warm),
                ),
              ],
            ),
          ),
          if (onChange != null)
            PressScale(
              label: l10n.lockFileChangeFile,
              onTap: onChange,
              child: SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Center(
                    child: ExcludeSemantics(
                      child: Text(
                        l10n.lockFileChange,
                        style: HaloType.sans(
                          size: 13,
                          weight: FontWeight.w600,
                          color: HaloColors.amber,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class WorkingView extends StatelessWidget {
  final String title;
  final int done;
  final int total;
  const WorkingView({
    super.key,
    required this.title,
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final known = total > 0 && done > 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RiseSwap(
              alignment: Alignment.center,
              child: Text(
                title,
                key: ValueKey(title),
                textAlign: TextAlign.center,
                style: HaloType.serif(size: 24, color: HaloColors.text),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              known
                  ? l10n.lockFileOf(prettySize(done), prettySize(total))
                  : l10n.lockFileEverythingStaysOnThis,
              style: HaloType.sans(size: 13.5, color: HaloColors.warm),
            ),
            const SizedBox(height: 22),
            HaloBar(value: known ? (done / total).clamp(0.0, 1.0) : null),
          ],
        ),
      ),
    );
  }
}

class LockFileScreen extends StatefulWidget {
  final PickedFile file;
  const LockFileScreen({super.key, required this.file});

  @override
  State<LockFileScreen> createState() => _LockFileScreenState();
}

class _LockFileScreenState extends State<LockFileScreen> {
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  late PickedFile _file = widget.file;
  // the progress, read while the file is worked on and the page is seen:
  // away or under the lock nothing ticks, and back it reads at once
  final _timers = SeenTimers();
  late final SeenJob _poll = _timers.until(
    () => _working ? const Duration(milliseconds: 120) : null,
    (_) {
      if (mounted) setState(() => _done = ageProgress());
    },
  );
  bool _shown = false;
  bool _hideName = false;
  bool _working = false;
  bool _busy = false;
  int _done = 0;
  AgeError? _error;
  String? _outPath;
  String? _outName;
  int _outBytes = 0;

  @override
  void initState() {
    super.initState();
    _pw1.addListener(_typed);
    _pw2.addListener(_typed);
  }

  void _typed() {
    if (!mounted) return;
    setState(() => _error = null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timers.watch(context);
  }

  @override
  void dispose() {
    _timers.dispose();
    if (_working) ageCancel();
    // the listeners go first: clear() notifies, and a notify after the
    // element is defunct asserts inside setState.
    _pw1.removeListener(_typed);
    _pw2.removeListener(_typed);
    _pw1
      ..clear()
      ..dispose();
    _pw2
      ..clear()
      ..dispose();
    super.dispose();
  }

  Future<void> _change() async {
    final f = await ToolsBridge.instance.pick('any');
    if (f != null && mounted) setState(() => _file = f);
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
      _pw1.text = words;
      _pw2.text = words;
      _shown = true;
    });
    showHaloToast(context, l10n.lockFileWriteItDownBefore);
  }

  bool get _ready =>
      gradePassword(_pw1.text).index >= PassGrade.weak.index &&
      _pw1.text == _pw2.text;

  Future<void> _lock() async {
    if (!_ready || _working) return;
    FocusScope.of(context).unfocus();
    final pass = _pw1.text;
    final name = lockedName(_file.name, hide: _hideName);
    setState(() {
      _working = true;
      _done = 0;
      _error = null;
    });
    final inFd = await ToolsBridge.instance.openForRead(_file.uri);
    final out = inFd < 0 ? null : await ToolsBridge.instance.openCacheOut(name);
    if (inFd < 0 || out == null) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _working = false;
          _error = AgeError.io;
        });
      }
      return;
    }
    _poll.poke();
    final err = await ageLock(inFd, out.fd, pass);
    if (err != null) {
      try {
        File(out.path).parent.deleteSync(recursive: true);
      } on FileSystemException {
        // the sweep takes it
      }
    }
    if (!mounted) return;
    // a refusal is felt, as a wrong pin is
    if (err != null && err != AgeError.cancelled) HapticFeedback.heavyImpact();
    setState(() {
      _working = false;
      if (err == null) {
        _outPath = out.path;
        _outName = name;
        _outBytes = File(out.path).lengthSync();
        _pw1.clear();
        _pw2.clear();
      } else if (err != AgeError.cancelled) {
        _error = err;
      }
    });
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await ToolsBridge.instance.shareOut(
      _outPath!,
      'application/octet-stream',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) showHaloToast(context, l10n.lockFileNoAppOnThis);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final how = await ToolsBridge.instance.saveToFiles(
      _outPath!,
      _outName!,
      'application/octet-stream',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (how == 'saved') showHaloToast(context, l10n.lockFileSaved);
    if (how == 'failed') {
      showHaloToast(context, l10n.lockFileCouldNotSaveIt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _outPath != null;
    return PopScope(
      canPop: !_working,
      onPopInvokedWithResult: (done, _) {
        if (!done && _working) ageCancel();
      },
      child: Scaffold(
        backgroundColor: HaloColors.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ToolBar(
                title: locked ? l10n.lockFileLocked : l10n.lockFileLockAFile,
              ),
              Expanded(
                // each stage fades in over the last
                child: FadeSwap(
                  child: KeyedSubtree(
                    key: ValueKey(
                      _working
                          ? 'work'
                          : locked
                          ? 'locked'
                          : 'form',
                    ),
                    child: _working
                        ? WorkingView(
                            title: _done == 0
                                ? l10n.lockFileMixingThePassword
                                : l10n.lockFileLocking,
                            done: _done,
                            total: _file.size,
                          )
                        : locked
                        ? _LockedView(name: _outName!, bytes: _outBytes)
                        : _form(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                child: EaseSize(
                  child: FadeSwap(
                    child: KeyedSubtree(
                      key: ValueKey(
                        _working
                            ? 'work'
                            : locked
                            ? 'locked'
                            : 'form',
                      ),
                      child: _buttons(locked),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buttons(bool locked) => _working
      ? ToolWideButton(label: l10n.commonStop, filled: false, onTap: ageCancel)
      : locked
      ? Row(
          children: [
            Expanded(
              child: ToolWideButton(
                icon: _shareIcon,
                label: l10n.commonShare,
                filled: true,
                height: 52,
                onTap: _busy ? null : _share,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ToolWideButton(
                icon: _saveIcon,
                label: l10n.lockFileSaveToFiles,
                filled: false,
                height: 52,
                onTap: _busy ? null : _save,
              ),
            ),
          ],
        )
      : ToolWideButton(
          icon: _lockIcon,
          label: l10n.lockFileLockFile,
          filled: true,
          onTap: _ready ? _lock : null,
        );

  Widget _form() {
    final grade = gradePassword(_pw1.text);
    final differ =
        _pw2.text.isNotEmpty && _pw1.text != _pw2.text && grade.index >= 2;
    final gradeColor = switch (grade) {
      PassGrade.strong => HaloColors.green,
      PassGrade.none => HaloColors.warm,
      _ => HaloColors.amber,
    };
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.lockFileOnePassword,
                  style: HaloType.serif(size: 26, color: HaloColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.lockFileNothingElseOpensIt,
                  style: HaloType.serif(
                    size: 22,
                    weight: FontWeight.w300,
                    italic: true,
                    color: HaloColors.amber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FileCard(
            name: _file.name ?? l10n.lockFileFile,
            detail: _file.size > 0
                ? l10n.lockFileFromFiles(prettySize(_file.size))
                : l10n.lockFileFromFiles2,
            onChange: _change,
          ),
          const SizedBox(height: 18),
          SecretField(
            label: l10n.lockFilePassword,
            controller: _pw1,
            shown: _shown,
            onToggle: () => setState(() => _shown = !_shown),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 7, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: RiseSwap(
                    child: Text(
                      gradeLine(grade),
                      key: ValueKey(grade),
                      style: HaloType.sans(
                        size: 12,
                        height: 1.35,
                        color: gradeColor,
                      ),
                    ),
                  ),
                ),
                PressScale(
                  label: l10n.lockFileSuggestFourWords,
                  onTap: _suggest,
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: ExcludeSemantics(
                        child: Text(
                          l10n.lockFileSuggestFourWords,
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
              ],
            ),
          ),
          const SizedBox(height: 6),
          SecretField(
            label: l10n.lockFileTypeItAgain,
            controller: _pw2,
            shown: _shown,
            onToggle: () => setState(() => _shown = !_shown),
            action: TextInputAction.done,
          ),
          EaseSize(
            child: !differ
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(4, 7, 4, 0),
                    child: Text(
                      l10n.lockFileTheTwoDoNot,
                      style: HaloType.sans(size: 12, color: HaloColors.amber),
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          MergeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.lockFileHideTheFileName,
                          style: HaloType.sans(
                            size: 14,
                            weight: FontWeight.w500,
                            color: HaloColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _hideName
                              ? l10n.lockFileItWillBeCalled(neutralLockedName)
                              : l10n.lockFileTheNameAloneCan,
                          style: HaloType.sans(
                            size: 12,
                            height: 1.35,
                            color: HaloColors.warm,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                HaloSwitch(
                  value: _hideName,
                  onChanged: (v) => setState(() => _hideName = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          EaseSize(
            child: FadeSwap(
              child: _error != null
                  ? _Note(
                      key: ValueKey(_error),
                      tint: HaloColors.rose,
                      text:
                          '${ageErrorTitle(_error!)} ${ageErrorBody(_error!)}',
                    )
                  : _Note(
                      key: const ValueKey('note'),
                      tint: HaloColors.amber,
                      text: l10n.lockFileAnyoneWithThePassword,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final Color tint;
  final String text;
  const _Note({super.key, required this.tint, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.28), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: StrokeIcon(_warnIcon, size: 18, color: tint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: HaloType.sans(
                size: 12.5,
                height: 1.5,
                color: HaloColors.warm,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedView extends StatelessWidget {
  final String name;
  final int bytes;
  const _LockedView({required this.name, required this.bytes});

  @override
  Widget build(BuildContext context) {
    final plain = name.endsWith('.age')
        ? name.substring(0, name.length - 4)
        : name;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
      child: Column(
        children: [
          const LockSnap(),
          const SizedBox(height: 16),
          Text(
            l10n.lockFileLocked2,
            style: HaloType.serif(
              size: 30,
              letter: -0.02,
              color: HaloColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.lockFileOnlyThePasswordOpens,
            style: HaloType.serif(
              size: 20,
              weight: FontWeight.w300,
              italic: true,
              color: HaloColors.amber,
            ),
          ),
          const SizedBox(height: 22),
          FileCard(
            name: name,
            detail: l10n.lockFileSafeToEmailOr(prettySize(bytes)),
            icon: _lockIcon,
            tint: HaloColors.green,
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: HaloColors.ink,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: HaloColors.line, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.lockFileNoKryfoOnThe,
                  style: HaloType.sans(size: 12.5, color: HaloColors.warm),
                ),
                const SizedBox(height: 8),
                // a shell line reads left to right in every language
                SelectableText(
                  '\$ age -d "$name" > "$plain"',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  style: HaloType.mono(size: 11.5, color: HaloColors.text),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.lockFileItAsksForThe,
                  style: HaloType.sans(
                    size: 12,
                    height: 1.4,
                    color: HaloColors.warm,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// the padlock on a finished file: it pops in and its shackle snaps shut, or
// springs open on a file just opened. felt once as it lands; simply there
// with less movement
class LockSnap extends StatelessWidget {
  final bool open;
  const LockSnap({super.key, this.open = false});

  static final _body = [svgRect(5, 10.5, 14, 10, 2.5), 'M12 14.5v2.2'];
  static const _shut = ['M8 10.5V8a4 4 0 0 1 8 0v2.5'];
  static const _free = ['M8 10.5V8a4 4 0 0 1 7.6-1.7'];

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final green = HaloColors.green;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 480),
      onEnd: HapticFeedback.lightImpact,
      builder: (_, t, _) {
        final pop = Curves.easeOutBack.transform(
          const Interval(0, 0.55).transform(t),
        );
        final snap = Curves.easeOutBack.transform(
          const Interval(0.4, 1).transform(t),
        );
        // shut, the shackle drops from raised; open, it rises from shut
        final lift = open ? 3 * (1 - snap) : -5 * (1 - snap);
        return Transform.scale(
          scale: 0.7 + 0.3 * pop,
          child: Opacity(
            opacity: pop.clamp(0.0, 1.0),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: green, width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  StrokeIcon(_body, size: 36, stroke: 1.8, color: green),
                  Transform.translate(
                    offset: Offset(0, lift),
                    child: StrokeIcon(
                      open ? _free : _shut,
                      size: 36,
                      stroke: 1.8,
                      color: green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
