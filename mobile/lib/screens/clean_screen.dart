// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../meta/meta_reader.dart';
import '../theme.dart';
import '../tools/cleaner.dart';
import '../tools/tools_bridge.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/press_scale.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/stroke_icon.dart';
import '../widgets/tool_parts.dart';
import '../l10n/l10n.dart';

const _share = [
  'M12 15V4',
  'M8 8l4-4 4 4',
  'M5 13v5a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-5',
];
const _down = ['M12 4v11', 'M8 11l4 4 4-4', 'M5 19h14'];
const _trash = [
  'M5 7h14',
  'M9 7V5h6v2',
  'M7 7l1 12a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1l1-12',
];
const _pin = ['M12 21s-6-5.3-6-10a6 6 0 0 1 12 0c0 4.7-6 10-6 10z'];
const _note = ['M12 6.5v7', 'M12 17v.5'];
const _tick = ['M5 12.5l4.5 4.5L19 7.5'];

String failureTitle(Object f) => switch (f) {
  CleanFailure.unknownKind => l10n.cleanKryfoCanTClean,
  CleanFailure.motion => l10n.cleanThisIsAMotion,
  CleanFailure.tooLarge => l10n.cleanThisPictureIsToo,
  CleanFailure.unreadable => l10n.cleanThisFileIsDamaged,
  CleanFailure.notClean => l10n.cleanKryfoCouldNotMake,
  CleanFailure.disk || 'full' => l10n.cleanNotEnoughRoomOn,
  _ => l10n.cleanKryfoCouldNotOpen,
};

String failureBody(Object f) => switch (f) {
  CleanFailure.unknownKind => l10n.cleanItCleansJpegPng,
  CleanFailure.motion => l10n.cleanItHoldsAShort,
  CleanFailure.tooLarge => l10n.cleanPicturesOver64Mb,
  CleanFailure.unreadable => l10n.cleanKryfoCouldNotRead,
  CleanFailure.notClean => l10n.cleanSomethingInsideIsOf,
  CleanFailure.disk || 'full' => l10n.cleanFreeSomeSpaceAnd,
  _ => l10n.cleanTheAppThatShared,
};

class CleanScreen extends StatefulWidget {
  final PickedFile file;
  final String? localPath;
  const CleanScreen({super.key, required this.file, this.localPath});

  @override
  State<CleanScreen> createState() => _CleanScreenState();
}

class _CleanScreenState extends State<CleanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  StreamSubscription<CopyProgress>? _sub;
  CopyProgress? _progress;
  CleanResult? _result;
  Object? _failure;
  late bool _copying = widget.localPath == null;
  bool _busy = false;
  bool _gone = false;
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void initState() {
    super.initState();
    _sub = ToolsBridge.instance.progress.listen((p) {
      if (mounted && _copying) setState(() => _progress = p);
    });
    _run();
  }

  @override
  void dispose() {
    _gone = true;
    if (_copying) ToolsBridge.instance.cancelCopy();
    _sub?.cancel();
    _reveal.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    String? inPath;
    try {
      inPath =
          widget.localPath ??
          await ToolsBridge.instance.copyIn(widget.file.uri);
      if (_gone) return;
      setState(() => _copying = false);
      final cache = await getTemporaryDirectory();
      final r = await cleanFile(
        inPath,
        '${cache.path}/tools_out',
        originalName: widget.file.name,
      );
      if (_gone) return;
      setState(() {
        _result = r.failure == null ? r : null;
        _failure = r.failure;
      });
      if (r.failure == null) {
        if (_still) {
          _reveal.value = 1;
        } else {
          _reveal.forward();
        }
      }
    } on ToolsFailure catch (e) {
      if (_gone) return;
      if (e.code == 'cancelled') return;
      setState(() {
        _copying = false;
        _failure = e.code;
      });
    } catch (_) {
      if (_gone) return;
      setState(() {
        _copying = false;
        _failure = 'read';
      });
    } finally {
      if (inPath != null) {
        try {
          File(inPath).parent.deleteSync(recursive: true);
        } on FileSystemException {
          // the sweep takes it
        }
      }
    }
  }

  Future<void> _shareIt() async {
    final r = _result;
    if (r == null || _busy) return;
    setState(() => _busy = true);
    final ok = await ToolsBridge.instance.shareOut(r.path!, r.mime!);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) _say(l10n.cleanNoAppOnThis);
  }

  Future<void> _saveIt() async {
    final r = _result;
    if (r == null || _busy) return;
    setState(() => _busy = true);
    final how = await ToolsBridge.instance.saveToGallery(
      r.path!,
      r.name!,
      r.mime!,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (how == 'kept') return;
    if (how != 'saved') {
      _say(l10n.cleanCouldNotSaveIt);
      return;
    }
    final outcome = await showHaloSheet<String>(
      context,
      builder: (_) => _SavedSheet(file: widget.file, result: r),
    );
    if (!mounted) return;
    if (outcome == 'deleted') {
      _say(l10n.cleanTheOriginalIsGone);
    }
    if (outcome == 'failed') {
      _say(l10n.cleanAndroidWouldNotDelete);
    }
  }

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: HaloColors.surface3,
          behavior: SnackBarBehavior.floating,
          content: Text(
            text,
            style: HaloType.sans(size: 13.5, color: HaloColors.text),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ToolBar(title: l10n.cleanCleanCopy),
            Expanded(
              child: _failure != null
                  ? _Failed(failure: _failure!)
                  : r == null
                  ? _Working(
                      copying: _copying,
                      progress: _progress,
                      size: widget.file.size,
                    )
                  : _Done(result: r, reveal: _reveal),
            ),
            if (r != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ToolWideButton(
                      icon: _share,
                      label: l10n.cleanShareCleanCopy,
                      filled: true,
                      onTap: _busy ? null : _shareIt,
                    ),
                    const SizedBox(height: 10),
                    ToolWideButton(
                      icon: _down,
                      label: l10n.cleanSaveToGallery,
                      filled: false,
                      onTap: _busy ? null : _saveIt,
                    ),
                  ],
                ),
              )
            else if (_failure != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                child: ToolWideButton(
                  label: l10n.commonBack,
                  filled: false,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              )
            else if (_copying)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                child: ToolWideButton(
                  label: l10n.commonStop,
                  filled: false,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Working extends StatelessWidget {
  final bool copying;
  final CopyProgress? progress;
  final int size;
  const _Working({required this.copying, this.progress, required this.size});

  @override
  Widget build(BuildContext context) {
    final total = (progress?.total ?? -1) > 0 ? progress!.total : size;
    final done = progress?.done ?? 0;
    final frac = copying && total > 0 ? (done / total).clamp(0.0, 1.0) : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              copying ? l10n.cleanReadingTheFile : l10n.cleanCleaning,
              style: HaloType.serif(size: 24, color: HaloColors.text),
            ),
            const SizedBox(height: 8),
            Text(
              copying && total > 0
                  ? l10n.cleanOf(prettySize(done), prettySize(total))
                  : l10n.cleanEverythingStaysOnThis,
              style: HaloType.sans(size: 13.5, color: HaloColors.warm),
            ),
            const SizedBox(height: 22),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: frac,
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

class _Failed extends StatelessWidget {
  final Object failure;
  const _Failed({required this.failure});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              failureTitle(failure),
              textAlign: TextAlign.center,
              style: HaloType.serif(
                size: 24,
                height: 1.2,
                color: HaloColors.text,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              failureBody(failure),
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 14,
                height: 1.55,
                color: HaloColors.warm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _span(double t, double from, double to) =>
    ((t - from) / (to - from)).clamp(0.0, 1.0);

class _Done extends StatelessWidget {
  final CleanResult result;
  final Animation<double> reveal;
  const _Done({required this.result, required this.reveal});

  @override
  Widget build(BuildContext context) {
    final lines = removedLines(result.before);
    final video = result.before.kind == MetaKind.mp4;
    return AnimatedBuilder(
      animation: reveal,
      builder: (context, _) {
        final t = reveal.value;
        final titles = Curves.easeOutCubic.transform(_span(t, 0.30, 0.55));
        final card = Curves.easeOutCubic.transform(_span(t, 0.42, 0.68));
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
          child: Column(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: CustomPaint(
                  painter: _CheckPainter(
                    ring: Curves.easeInOutCubic.transform(_span(t, 0, 0.42)),
                    tick: Curves.easeOut.transform(_span(t, 0.38, 0.6)),
                    color: HaloColors.green,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Opacity(
                opacity: titles,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - titles)),
                  child: Column(
                    children: [
                      Text(
                        lines.isEmpty
                            ? l10n.cleanAlreadyClean
                            : l10n.cleanClean,
                        style: HaloType.serif(
                          size: 30,
                          letter: -0.02,
                          color: HaloColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lines.isEmpty
                            ? l10n.cleanThereWasNothingTo
                            : l10n.cleanNothingLeftToFind,
                        style: HaloType.serif(
                          size: 20,
                          weight: FontWeight.w300,
                          italic: true,
                          color: HaloColors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Opacity(
                opacity: card,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - card)),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: HaloColors.surface2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: HaloColors.line, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Row(
                            children: [
                              ToolThumb(
                                path: result.path!,
                                video: video,
                                size: 46,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      result.name!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: HaloType.sans(
                                        size: 13.5,
                                        weight: FontWeight.w500,
                                        color: HaloColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      video
                                          ? l10n.cleanSameVideoSameQuality
                                          : l10n.cleanSamePictureSameQuality,
                                      style: HaloType.sans(
                                        size: 11.5,
                                        color: HaloColors.warm,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                prettySize(result.bytes),
                                style: HaloType.mono(
                                  size: 10.5,
                                  color: HaloColors.warm,
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (var i = 0; i < lines.length; i++)
                          _RemovedRow(
                            line: lines[i],
                            t: _span(
                              t,
                              0.62 + i * 0.05,
                              math.min(1.0, 0.82 + i * 0.05),
                            ),
                          ),
                      ],
                    ),
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

class _RemovedRow extends StatelessWidget {
  final RemovedLine line;
  final double t;
  const _RemovedRow({required this.line, required this.t});

  @override
  Widget build(BuildContext context) {
    final struck = Curves.easeInOutCubic.transform(t);
    return Semantics(
      label: l10n.cleanRemoved(line.label),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Stack(
                  children: [
                    Text(
                      line.detail == null
                          ? line.label
                          : '${line.label}  ${line.detail}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.sans(
                        size: 13.5,
                        color: Color.lerp(
                          HaloColors.text,
                          HaloColors.warm,
                          struck,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: struck,
                          child: Container(
                            height: 1.5,
                            color: HaloColors.amber,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Opacity(
              opacity: struck,
              child: Text(
                l10n.cleanRemoved2,
                style: HaloType.mono(
                  size: 10.5,
                  letter: 0.08,
                  color: HaloColors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double ring;
  final double tick;
  final Color color;
  const _CheckPainter({
    required this.ring,
    required this.tick,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.42;
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawCircle(
      c,
      r * 0.92,
      Paint()..color = color.withValues(alpha: 0.10 * tick),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * ring,
      false,
      pen..strokeWidth = 2.2,
    );
    if (tick <= 0) return;
    final a = c + Offset(-r * 0.42, r * 0.02);
    final b = c + Offset(-r * 0.10, r * 0.34);
    final d = c + Offset(r * 0.46, -r * 0.30);
    final first = (b - a).distance, second = (d - b).distance;
    final drawn = (first + second) * tick;
    final path = Path()..moveTo(a.dx, a.dy);
    if (drawn <= first) {
      final p = Offset.lerp(a, b, drawn / first)!;
      path.lineTo(p.dx, p.dy);
    } else {
      path.lineTo(b.dx, b.dy);
      final p = Offset.lerp(b, d, (drawn - first) / second)!;
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, pen..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.ring != ring || old.tick != tick || old.color != color;
}

class _SavedSheet extends StatefulWidget {
  final PickedFile file;
  final CleanResult result;
  const _SavedSheet({required this.file, required this.result});

  @override
  State<_SavedSheet> createState() => _SavedSheetState();
}

class _SavedSheetState extends State<_SavedSheet> {
  bool _asking = false;

  Future<void> _delete() async {
    final target = widget.file.deleteUri;
    if (_asking || target == null) return;
    setState(() => _asking = true);
    final how = await ToolsBridge.instance.deleteOriginal(target);
    if (!mounted) return;
    if (how == 'kept') {
      setState(() => _asking = false);
      return;
    }
    Navigator.of(context).pop(how == 'deleted' ? 'deleted' : 'failed');
  }

  @override
  Widget build(BuildContext context) {
    final before = widget.result.before;
    final video = before.kind == MetaKind.mp4;
    final hadPlace = before.gps != null || before.gpsBlank;
    final canDelete = widget.file.canDelete;
    final what = hadPlace
        ? l10n.cleanWithTheLocationInside
        : l10n.cleanWithEverythingItKnew;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: SheetHandle()),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Tile(
                label: l10n.cleanOriginal,
                tint: HaloColors.rose,
                badge: hadPlace ? _pin : _note,
                child: ToolThumb(
                  path: widget.result.path!,
                  video: video,
                  size: 84,
                ),
              ),
              const SizedBox(width: 10),
              _Tile(
                label: l10n.cleanClean2,
                tint: HaloColors.green,
                badge: _tick,
                child: ToolThumb(
                  path: widget.result.path!,
                  video: video,
                  size: 84,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            l10n.cleanSavedToYourGallery,
            textAlign: TextAlign.center,
            style: HaloType.serif(size: 23, color: HaloColors.text),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              canDelete
                  ? l10n.cleanTheOriginalIsStill(what)
                  : l10n.cleanTheOriginalIsStillWhereIt(what),
              textAlign: TextAlign.center,
              style: HaloType.sans(
                size: 13.5,
                height: 1.55,
                color: HaloColors.warm,
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (canDelete) ...[
            Opacity(
              opacity: _asking ? 0.55 : 1,
              child: PressScale(
                label: l10n.cleanDeleteTheOriginal,
                onTap: _asking ? null : _delete,
                scale: 0.96,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: HaloColors.rose.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: HaloColors.rose.withValues(alpha: 0.35),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StrokeIcon(_trash, size: 19, color: HaloColors.rose),
                      const SizedBox(width: 9),
                      ExcludeSemantics(
                        child: Text(
                          l10n.cleanDeleteTheOriginal,
                          style: HaloType.sans(
                            size: 14.5,
                            weight: FontWeight.w600,
                            color: HaloColors.rose,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          PressScale(
            label: canDelete ? l10n.cleanKeepBoth : l10n.commonDone,
            onTap: () => Navigator.of(context).pop('kept'),
            scale: 0.96,
            child: SizedBox(
              height: 46,
              child: Center(
                child: ExcludeSemantics(
                  child: Text(
                    canDelete ? l10n.cleanKeepBoth : l10n.commonDone,
                    style: HaloType.sans(size: 14, color: HaloColors.warm),
                  ),
                ),
              ),
            ),
          ),
          if (canDelete) ...[
            const SizedBox(height: 6),
            Text(
              l10n.cleanAndroidWillAskYou,
              textAlign: TextAlign.center,
              style: HaloType.mono(
                size: 9.5,
                letter: 0.1,
                color: HaloColors.warm,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final Color tint;
  final List<String> badge;
  final Widget child;
  const _Tile({
    required this.label,
    required this.tint,
    required this.badge,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HaloColors.line2, width: 0.5),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Center(
                child: StrokeIcon(
                  badge,
                  size: 14,
                  stroke: 2,
                  color: HaloColors.amberInk,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              color: HaloColors.ink.withValues(alpha: 0.8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: HaloType.mono(size: 8.5, letter: 0.08, color: tint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
