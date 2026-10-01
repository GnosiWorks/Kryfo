// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../seen_timers.dart';
import '../theme.dart';
import '../tools/age_ffi.dart';
import '../tools/lock_words.dart';
import '../tools/tools_bridge.dart';
import '../widgets/ease_size.dart';
import '../widgets/stroke_icon.dart';
import '../widgets/swap.dart';
import '../widgets/tool_parts.dart';
import 'lock_file_screen.dart';
import '../widgets/secret_field.dart';
import '../l10n/l10n.dart';

final _lockIcon = [
  svgRect(5, 10.5, 14, 10, 2.5),
  'M8 10.5V8a4 4 0 0 1 8 0v2.5',
  'M12 14.5v2.2',
];
final _unlockIcon = [
  svgRect(5, 10.5, 14, 10, 2.5),
  'M8 10.5V8a4 4 0 0 1 7.6-1.7',
];

enum _Stage { form, checking, writing, done }

class OpenLockedScreen extends StatefulWidget {
  final PickedFile file;
  const OpenLockedScreen({super.key, required this.file});

  @override
  State<OpenLockedScreen> createState() => _OpenLockedScreenState();
}

class _OpenLockedScreenState extends State<OpenLockedScreen> {
  final _pw = TextEditingController();
  late PickedFile _file = widget.file;
  // the progress, read while the file is written and the page is seen:
  // away or under the lock nothing ticks, and back it reads at once
  final _timers = SeenTimers();
  late final SeenJob _poll = _timers.until(
    () => _stage == _Stage.writing ? const Duration(milliseconds: 120) : null,
    (_) {
      if (mounted) setState(() => _done = ageProgress());
    },
  );
  var _stage = _Stage.form;
  bool _shown = false;
  int _done = 0;
  AgeError? _error;
  String? _savedAs;

  @override
  void initState() {
    super.initState();
    // every keystroke has to rebuild, not only the ones that clear an error:
    // the Open file button picks its handler at build time from whether this
    // field is empty.
    _pw.addListener(_typed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timers.watch(context);
  }

  @override
  void dispose() {
    _timers.dispose();
    if (_stage == _Stage.writing) ageCancel();
    if (_stage == _Stage.checking) ageOpenDrop();
    // the listener goes first: clear() notifies, and a notify after the
    // element is defunct asserts inside setState.
    _pw.removeListener(_typed);
    _pw
      ..clear()
      ..dispose();
    super.dispose();
  }

  void _typed() {
    if (!mounted) return;
    setState(() => _error = null);
  }

  Future<void> _change() async {
    final f = await ToolsBridge.instance.pick('any');
    if (f != null && mounted) {
      setState(() {
        _file = f;
        _error = null;
      });
    }
  }

  void _fail(AgeError e) {
    if (!mounted) return;
    // a wrong password is felt, as a wrong pin is
    if (e != AgeError.cancelled) HapticFeedback.heavyImpact();
    setState(() {
      _stage = _Stage.form;
      _error = e == AgeError.cancelled ? null : e;
    });
  }

  Future<void> _open() async {
    if (_stage != _Stage.form || _pw.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    final pass = _pw.text;
    setState(() {
      _stage = _Stage.checking;
      _error = null;
      _done = 0;
    });
    final inFd = await ToolsBridge.instance.openForRead(_file.uri);
    if (inFd < 0) return _fail(AgeError.io);
    final bad = await ageOpenBegin(inFd, pass);
    if (bad != null) return _fail(bad);
    if (!mounted) {
      ageOpenDrop();
      return;
    }

    final name = openedName(_file.name);
    final target = await ToolsBridge.instance.createDocument(
      name,
      'application/octet-stream',
    );
    if (target == null) {
      ageOpenDrop();
      return _fail(AgeError.cancelled);
    }
    final outFd = await ToolsBridge.instance.openCreated(target);
    if (outFd < 0) {
      ageOpenDrop();
      await ToolsBridge.instance.dropCreated(target);
      return _fail(AgeError.io);
    }
    if (mounted) setState(() => _stage = _Stage.writing);
    _poll.poke();
    final err = await ageOpenFinish(outFd);
    if (err != null) {
      await ToolsBridge.instance.dropCreated(target);
      return _fail(err);
    }
    if (!mounted) return;
    setState(() {
      _stage = _Stage.done;
      _savedAs = name;
      _pw.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final busy = _stage == _Stage.checking || _stage == _Stage.writing;
    return PopScope(
      canPop: !busy,
      onPopInvokedWithResult: (done, _) {
        if (!done && _stage == _Stage.writing) ageCancel();
      },
      child: Scaffold(
        backgroundColor: HaloColors.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ToolBar(
                title: _stage == _Stage.done
                    ? l10n.openLockedOpened
                    : l10n.openLockedOpenALockedFile,
              ),
              Expanded(
                // each stage fades in over the last
                child: FadeSwap(
                  child: KeyedSubtree(
                    key: ValueKey(_stage),
                    child: switch (_stage) {
                      _Stage.checking => WorkingView(
                        title: l10n.openLockedCheckingThePassword,
                        done: 0,
                        total: 0,
                      ),
                      _Stage.writing => WorkingView(
                        title: l10n.openLockedOpening,
                        done: _done,
                        total: _file.size,
                      ),
                      _Stage.done => _OpenedView(
                        name: _savedAs ?? l10n.openLockedFile,
                      ),
                      _Stage.form => _form(),
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                child: EaseSize(
                  child: FadeSwap(
                    child: KeyedSubtree(
                      key: ValueKey(_stage),
                      child: switch (_stage) {
                        _Stage.checking => const SizedBox(height: 50),
                        _Stage.writing => ToolWideButton(
                          label: l10n.commonStop,
                          filled: false,
                          onTap: ageCancel,
                        ),
                        _Stage.done => ToolWideButton(
                          label: l10n.commonDone,
                          filled: false,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        _Stage.form => ToolWideButton(
                          icon: _unlockIcon,
                          label: l10n.openLockedOpenFile,
                          filled: true,
                          onTap: _pw.text.isEmpty ? null : _open,
                        ),
                      },
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

  Widget _form() {
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
                  l10n.openLockedTypeThePassword,
                  style: HaloType.serif(size: 26, color: HaloColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.openLockedItOpensOnThis,
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
            name: _file.name ?? l10n.openLockedLockedFile,
            detail: _file.size > 0
                ? l10n.openLockedFromFiles(prettySize(_file.size))
                : l10n.openLockedFromFiles2,
            icon: _lockIcon,
            tint: HaloColors.green,
            onChange: _change,
          ),
          const SizedBox(height: 18),
          SecretField(
            label: l10n.openLockedPassword,
            controller: _pw,
            shown: _shown,
            onToggle: () => setState(() => _shown = !_shown),
            action: TextInputAction.done,
            onSubmit: _open,
          ),
          const SizedBox(height: 16),
          EaseSize(
            child: FadeSwap(
              child: _error != null
                  ? Semantics(
                      key: ValueKey(_error),
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: HaloColors.rose.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: HaloColors.rose.withValues(alpha: 0.28),
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ageErrorTitle(_error!),
                              style: HaloType.sans(
                                size: 14,
                                weight: FontWeight.w600,
                                color: HaloColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ageErrorBody(_error!),
                              style: HaloType.sans(
                                size: 12.5,
                                height: 1.5,
                                color: HaloColors.warm,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      key: const ValueKey('note'),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        l10n.openLockedThePasswordIsChecked,
                        style: HaloType.sans(
                          size: 12.5,
                          height: 1.5,
                          color: HaloColors.warm,
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

class _OpenedView extends StatelessWidget {
  final String name;
  const _OpenedView({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LockSnap(open: true),
            const SizedBox(height: 16),
            Text(
              l10n.openLockedOpened2,
              style: HaloType.serif(
                size: 30,
                letter: -0.02,
                color: HaloColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.openLockedSavedWhereYouChose,
              style: HaloType.serif(
                size: 20,
                weight: FontWeight.w300,
                italic: true,
                color: HaloColors.amber,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              name,
              textAlign: TextAlign.center,
              style: HaloType.mono(size: 12, color: HaloColors.warm),
            ),
          ],
        ),
      ),
    );
  }
}
