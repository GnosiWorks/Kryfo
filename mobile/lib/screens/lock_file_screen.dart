// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../tools/age_ffi.dart';
import '../tools/lock_words.dart';
import '../tools/tools_bridge.dart';
import '../widgets/halo_switch.dart';
import '../widgets/press_scale.dart';
import '../widgets/stroke_icon.dart';
import '../widgets/tool_parts.dart';
import '../l10n/l10n.dart';

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
const _eyeOn = [
  'M2.5 12s3.5-6.5 9.5-6.5 9.5 6.5 9.5 6.5-3.5 6.5-9.5 6.5S2.5 12 2.5 12z',
  'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
];
const _eyeOff = [
  'M3 3l18 18',
  'M10.6 5.7A9.5 9.5 0 0 1 12 5.5c6 0 9.5 6.5 9.5 6.5a15 15 0 0 1-3 3.7',
  'M6.5 7.5A15 15 0 0 0 2.5 12s3.5 6.5 9.5 6.5a9 9 0 0 0 3.6-.8',
];

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

class SecretField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool shown;
  final VoidCallback onToggle;
  final TextInputAction action;
  final VoidCallback? onSubmit;
  const SecretField({
    super.key,
    required this.label,
    required this.controller,
    required this.shown,
    required this.onToggle,
    this.action = TextInputAction.next,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: ExcludeSemantics(
            child: Text(
              label,
              style: HaloType.sans(size: 12, color: HaloColors.warm),
            ),
          ),
        ),
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: HaloColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HaloColors.line2, width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: MergeSemantics(
                  child: Semantics(
                    label: label,
                    child: TextField(
                      controller: controller,
                      obscureText: !shown,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: action,
                      onSubmitted: (_) => onSubmit?.call(),
                      cursorColor: HaloColors.amber,
                      style: shown
                          ? HaloType.mono(size: 14, color: HaloColors.text)
                          : HaloType.sans(size: 14.5, color: HaloColors.text),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              PressScale(
                label: shown
                    ? l10n.lockFileHidePassword
                    : l10n.lockFileShowPassword,
                onTap: onToggle,
                child: SizedBox(
                  width: 46,
                  height: 48,
                  child: Center(
                    child: StrokeIcon(
                      shown ? _eyeOff : _eyeOn,
                      size: 19,
                      color: HaloColors.warm,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
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
            Text(
              title,
              textAlign: TextAlign.center,
              style: HaloType.serif(size: 24, color: HaloColors.text),
            ),
            const SizedBox(height: 8),
            Text(
              known
                  ? l10n.lockFileOf(prettySize(done), prettySize(total))
                  : l10n.lockFileEverythingStaysOnThis,
              style: HaloType.sans(size: 13.5, color: HaloColors.warm),
            ),
            const SizedBox(height: 22),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: known ? (done / total).clamp(0.0, 1.0) : null,
                minHeight: 4,
                backgroundColor: HaloColors.surface3,
                valueColor: AlwaysStoppedAnimation(HaloColors.amber),
              ),
            ),
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
  Timer? _poll;
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
  void dispose() {
    _poll?.cancel();
    if (_working) ageCancel();
    // same reason as the open screen: clear() notifies, and a notify after
    // the element is defunct asserts inside setState.
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
        setState(() {
          _working = false;
          _error = AgeError.io;
        });
      }
      return;
    }
    _poll = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (mounted) setState(() => _done = ageProgress());
    });
    final err = await ageLock(inFd, out.fd, pass);
    _poll?.cancel();
    if (err != null) {
      try {
        File(out.path).parent.deleteSync(recursive: true);
      } on FileSystemException {
        // the sweep takes it
      }
    }
    if (!mounted) return;
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                child: _working
                    ? ToolWideButton(
                        label: l10n.commonStop,
                        filled: false,
                        onTap: ageCancel,
                      )
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
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                  child: Text(
                    gradeLine(grade),
                    style: HaloType.sans(
                      size: 12,
                      height: 1.35,
                      color: gradeColor,
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
          if (differ)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 7, 4, 0),
              child: Text(
                l10n.lockFileTheTwoDoNot,
                style: HaloType.sans(size: 12, color: HaloColors.amber),
              ),
            ),
          const SizedBox(height: 14),
          MergeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
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
                              ? l10n.lockFileItWillBeCalled
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
          if (_error != null)
            _Note(
              tint: HaloColors.rose,
              text: '${ageErrorTitle(_error!)} ${ageErrorBody(_error!)}',
            )
          else
            _Note(
              tint: HaloColors.amber,
              text: l10n.lockFileAnyoneWithThePassword,
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final Color tint;
  final String text;
  const _Note({required this.tint, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
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
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final plain = name.endsWith('.age')
        ? name.substring(0, name.length - 4)
        : name;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 12),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: still ? 1 : 0, end: 1),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            builder: (_, t, child) => Transform.scale(
              scale: 0.7 + 0.3 * t,
              child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
            ),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: HaloColors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: HaloColors.green, width: 2),
              ),
              child: Center(
                child: StrokeIcon(
                  _lockIcon,
                  size: 36,
                  stroke: 1.8,
                  color: HaloColors.green,
                ),
              ),
            ),
          ),
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
                SelectableText(
                  '\$ age -d "$name" > "$plain"',
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
