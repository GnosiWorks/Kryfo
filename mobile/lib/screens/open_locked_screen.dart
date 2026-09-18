// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../tools/age_ffi.dart';
import '../tools/lock_words.dart';
import '../tools/tools_bridge.dart';
import '../widgets/stroke_icon.dart';
import '../widgets/tool_parts.dart';
import 'lock_file_screen.dart';

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
  Timer? _poll;
  var _stage = _Stage.form;
  bool _shown = false;
  int _done = 0;
  AgeError? _error;
  String? _savedAs;

  @override
  void initState() {
    super.initState();
    _pw.addListener(() {
      if (_error != null) setState(() => _error = null);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    if (_stage == _Stage.writing) ageCancel();
    if (_stage == _Stage.checking) ageOpenDrop();
    _pw
      ..clear()
      ..dispose();
    super.dispose();
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
    _poll = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (mounted) setState(() => _done = ageProgress());
    });
    final err = await ageOpenFinish(outFd);
    _poll?.cancel();
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
                title: _stage == _Stage.done ? 'Opened' : 'Open a locked file',
              ),
              Expanded(
                child: switch (_stage) {
                  _Stage.checking => const WorkingView(
                    title: 'Checking the password',
                    done: 0,
                    total: 0,
                  ),
                  _Stage.writing => WorkingView(
                    title: 'Opening',
                    done: _done,
                    total: _file.size,
                  ),
                  _Stage.done => _OpenedView(name: _savedAs ?? 'File'),
                  _Stage.form => _form(),
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                child: switch (_stage) {
                  _Stage.checking => const SizedBox(height: 50),
                  _Stage.writing => const ToolWideButton(
                    label: 'Stop',
                    filled: false,
                    onTap: ageCancel,
                  ),
                  _Stage.done => ToolWideButton(
                    label: 'Done',
                    filled: false,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  _Stage.form => ToolWideButton(
                    icon: _unlockIcon,
                    label: 'Open file',
                    filled: true,
                    onTap: _pw.text.isEmpty ? null : _open,
                  ),
                },
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
                  'Type the password.',
                  style: HaloType.serif(size: 26, color: HaloColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  'It opens on this phone.',
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
            name: _file.name ?? 'Locked file',
            detail: _file.size > 0
                ? '${prettySize(_file.size)} · from Files'
                : 'From Files',
            icon: _lockIcon,
            tint: HaloColors.green,
            onChange: _change,
          ),
          const SizedBox(height: 18),
          SecretField(
            label: 'Password',
            controller: _pw,
            shown: _shown,
            onToggle: () => setState(() => _shown = !_shown),
            action: TextInputAction.done,
            onSubmit: _open,
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Semantics(
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
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'The password is checked first. Only then does Kryfo ask where to put the opened file, and it goes straight there.',
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

class _OpenedView extends StatelessWidget {
  final String name;
  const _OpenedView({required this.name});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                    _unlockIcon,
                    size: 36,
                    stroke: 1.8,
                    color: HaloColors.green,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Opened.',
              style: HaloType.serif(
                size: 30,
                letter: -0.02,
                color: HaloColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Saved where you chose.',
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
