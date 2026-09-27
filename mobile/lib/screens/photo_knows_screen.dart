// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../meta/meta_reader.dart';
import '../theme.dart';
import '../tools/cleaner.dart';
import '../tools/geo.dart';
import '../tools/geo_assets.dart';
import '../tools/photo_story.dart';
import '../tools/tools_bridge.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/motion.dart';
import '../widgets/offline_map.dart';
import '../widgets/press_scale.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/ease_size.dart';
import '../widgets/stroke_icon.dart';
import '../widgets/swap.dart';
import '../widgets/tool_parts.dart';
import 'clean_screen.dart';
import '../l10n/l10n.dart';
import '../widgets/halo_bar.dart';

const _pin = [
  'M12 21s-6-5.3-6-10a6 6 0 0 1 12 0c0 4.7-6 10-6 10z',
  'M12 13.2a2.2 2.2 0 1 0 0-4.4 2.2 2.2 0 0 0 0 4.4z',
];
final _phone = [svgRect(7, 3, 10, 18, 2.5), 'M11 17.5h2'];
final _clock = [svgCircle(12, 12, 8.5), 'M12 7.5V12l3 2'];
const _list = ['M5 7h14', 'M5 12h14', 'M5 17h9'];
const _chevron = ['M9 5l7 7-7 7'];
const _hidden = [
  'M3 3l18 18',
  'M10.6 5.7A9.5 9.5 0 0 1 12 5.5c6 0 9.5 6.5 9.5 6.5a15 15 0 0 1-3 3.7',
  'M6.5 7.5A15 15 0 0 0 2.5 12s3.5 6.5 9.5 6.5a9 9 0 0 0 3.6-.8',
];
const _sparkle = [
  'M12 3l1.8 4.6L18.5 9l-4.7 1.5L12 15l-1.8-4.5L5.5 9l4.7-1.4z',
  'M18.5 15.5l.8 2 2 .7-2 .8-.8 2-.7-2-2-.8 2-.7z',
];

class PhotoKnowsScreen extends StatefulWidget {
  final PickedFile file;
  const PhotoKnowsScreen({super.key, required this.file});

  @override
  State<PhotoKnowsScreen> createState() => _PhotoKnowsScreenState();
}

class _PhotoKnowsScreenState extends State<PhotoKnowsScreen>
    with SingleTickerProviderStateMixin {
  // made with the page, so a page left before a result has one to dispose
  late final AnimationController _reveal;
  StreamSubscription<CopyProgress>? _sub;
  CopyProgress? _progress;
  String? _inPath;
  int _bytes = 0;
  MetaReport? _report;
  PhotoStory? _story;
  GeoData? _geo;
  String? _failure;
  bool _handedOn = false;
  bool _gone = false;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _sub = ToolsBridge.instance.progress.listen((p) {
      if (mounted && _report == null) setState(() => _progress = p);
    });
    _run();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void dispose() {
    _gone = true;
    if (_inPath == null) ToolsBridge.instance.cancelCopy();
    _sub?.cancel();
    _reveal.dispose();
    if (!_handedOn) _dropInput();
    super.dispose();
  }

  void _dropInput() {
    final p = _inPath;
    if (p == null) return;
    try {
      File(p).parent.deleteSync(recursive: true);
    } on FileSystemException {
      // the sweep takes it
    }
  }

  Future<void> _run() async {
    try {
      final path = await ToolsBridge.instance.copyIn(widget.file.uri);
      _inPath = path;
      if (_gone) {
        _dropInput();
        return;
      }
      final report = await readFileOffUi(path);
      GeoData? geo;
      if (report.gps != null) {
        try {
          geo = await loadGeo();
        } catch (_) {
          geo = null;
        }
      }
      if (_gone) return;
      setState(() {
        _bytes = File(path).lengthSync();
        _report = report;
        _geo = geo;
        _story = storyOf(report, world: geo?.world, places: geo?.places);
      });
      if (_still) {
        _reveal.value = 1;
      } else {
        // a clean file ends on its ticks landing: felt, once
        final clean = !(_story?.canClean ?? true);
        _reveal.forward().then((_) {
          if (clean && !_gone) HapticFeedback.lightImpact();
        });
      }
    } on ToolsFailure catch (e) {
      if (_gone || e.code == 'cancelled') return;
      setState(() => _failure = e.code);
    } catch (_) {
      if (_gone) return;
      setState(() => _failure = 'read');
    }
  }

  void _clean() {
    final path = _inPath;
    if (path == null) return;
    _handedOn = true;
    Navigator.of(context).pushReplacement(
      haloRoute(CleanScreen(file: widget.file, localPath: path)),
    );
  }

  void _showAll() {
    final lines = _story?.everything ?? const <String>[];
    showHaloSheet<void>(
      context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: SheetHandle()),
            const SizedBox(height: 12),
            Text(
              l10n.photoKnowsEverythingInside,
              style: HaloType.serif(size: 23, color: HaloColors.text),
            ),
            const SizedBox(height: 14),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Text(
                  l,
                  style: HaloType.sans(
                    size: 13.5,
                    height: 1.45,
                    color: HaloColors.warm,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    final report = _report;
    final video = report?.kind == MetaKind.mp4;
    final name =
        widget.file.name ??
        (video ? l10n.photoKnowsVideo : l10n.photoKnowsPhoto);
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ToolBar(
              title: video
                  ? l10n.photoKnowsWhatThisVideoKnows
                  : l10n.photoKnowsWhatThisPhotoKnows,
              sub: report == null ? name : '$name · ${prettySize(_bytes)}',
              leading: _inPath == null || report == null
                  ? null
                  : ToolThumb(path: _inPath!, video: video, size: 38),
            ),
            Expanded(
              // the reading fades into what was found
              child: FadeSwap(
                child: KeyedSubtree(
                  key: ValueKey(
                    _failure != null
                        ? 'failed'
                        : story == null
                        ? 'reading'
                        : 'found',
                  ),
                  child: _failure != null
                      ? _Message(
                          head: failureTitle(_failure!),
                          body: failureBody(_failure!),
                        )
                      : story == null
                      ? _Reading(progress: _progress, size: widget.file.size)
                      : _Body(
                          story: story,
                          report: report!,
                          geo: _geo,
                          reveal: _reveal,
                          onMore: _showAll,
                          path: _inPath,
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EaseSize(
                    child: FadeSwap(
                      child: KeyedSubtree(
                        key: ValueKey(
                          _failure != null
                              ? 'failed'
                              : story == null
                              ? 'reading'
                              : story.canClean
                              ? 'clean'
                              : 'done',
                        ),
                        child: _buttons(story),
                      ),
                    ),
                  ),
                  Text(
                    video
                        ? l10n.photoKnowsReadOnThisPhone
                        : l10n.photoKnowsReadOnThisPhoneThePhoto,
                    textAlign: TextAlign.center,
                    style: HaloType.mono(
                      size: 9.5,
                      letter: 0.12,
                      color: HaloColors.warm,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buttons(PhotoStory? story) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (story != null && story.canClean) ...[
          ToolWideButton(
            icon: _sparkle,
            label: l10n.photoKnowsRemoveAllOfIt,
            filled: true,
            onTap: _clean,
          ),
          const SizedBox(height: 4),
        ],
        // with nothing to remove, the way out is the button
        if (story != null && !story.canClean)
          ToolWideButton(
            label: l10n.commonDone,
            filled: true,
            onTap: () => Navigator.of(context).maybePop(),
          )
        else if (_failure != null)
          ToolWideButton(
            label: l10n.commonBack,
            filled: true,
            onTap: () => Navigator.of(context).maybePop(),
          )
        else
          PressScale(
            label: story == null ? l10n.commonStop : l10n.photoKnowsKeepItAsIt,
            onTap: () => Navigator.of(context).maybePop(),
            scale: 0.96,
            child: SizedBox(
              height: 44,
              child: Center(
                child: ExcludeSemantics(
                  child: Text(
                    story == null ? l10n.commonStop : l10n.photoKnowsKeepItAsIt,
                    style: HaloType.sans(size: 13.5, color: HaloColors.warm),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Reading extends StatelessWidget {
  final CopyProgress? progress;
  final int size;
  const _Reading({this.progress, required this.size});

  @override
  Widget build(BuildContext context) {
    final total = (progress?.total ?? -1) > 0 ? progress!.total : size;
    final done = progress?.done ?? 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.photoKnowsReadingTheFile,
              style: HaloType.serif(size: 24, color: HaloColors.text),
            ),
            const SizedBox(height: 8),
            Text(
              total > 0 && done > 0
                  ? l10n.photoKnowsOf(prettySize(done), prettySize(total))
                  : l10n.photoKnowsEverythingStaysOnThis,
              style: HaloType.sans(size: 13.5, color: HaloColors.warm),
            ),
            const SizedBox(height: 22),
            HaloBar(
              value: total > 0 && done > 0
                  ? (done / total).clamp(0.0, 1.0)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String head;
  final String body;
  const _Message({required this.head, required this.body});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              head,
              textAlign: TextAlign.center,
              style: HaloType.serif(
                size: 24,
                height: 1.2,
                color: HaloColors.text,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              body,
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

class _Rise extends StatelessWidget {
  final double t;
  final Widget child;
  const _Rise({required this.t, required this.child});

  @override
  Widget build(BuildContext context) {
    final k = Curves.easeOutCubic.transform(t);
    return Opacity(
      opacity: k,
      child: Transform.translate(offset: Offset(0, 12 * (1 - k)), child: child),
    );
  }
}

class _Body extends StatelessWidget {
  final PhotoStory story;
  final MetaReport report;
  final GeoData? geo;
  final Animation<double> reveal;
  final VoidCallback onMore;
  final String? path;
  const _Body({
    required this.story,
    required this.report,
    required this.geo,
    required this.reveal,
    required this.onMore,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    final fix = report.gps;
    final place = story.rows
        .where((r) => r.kind == StoryRowKind.place)
        .map((r) => r.title)
        .firstOrNull;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fix != null && geo != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              height: 250,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: HaloColors.ink,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: HaloColors.line, width: 0.5),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: OfflineMap(
                      world: geo!.world,
                      places: geo!.places,
                      lat: fix.lat,
                      lon: fix.lon,
                      reveal: reveal,
                      label: l10n.photoKnowsMapWithAPin(place ?? ''),
                    ),
                  ),
                  PositionedDirectional(
                    top: 12,
                    end: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: HaloColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BreathDot(
                            color: HaloColors.green,
                            size: 5,
                            breaths: 3,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.photoKnowsDrawnOffline,
                            style: HaloType.mono(
                              size: 9.5,
                              letter: 0.1,
                              weight: FontWeight.w500,
                              color: HaloColors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: 12,
                    bottom: 12,
                    child: AnimatedBuilder(
                      animation: reveal,
                      builder: (_, child) => _Rise(
                        t: _span(reveal.value, 0.7, 0.9),
                        child: child!,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: HaloColors.ink.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: HaloColors.line2,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          coordsLine(fix.lat, fix.lon),
                          style: HaloType.mono(
                            size: 11,
                            color: HaloColors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          AnimatedBuilder(
            animation: reveal,
            builder: (_, _) {
              final t = reveal.value;
              final late = fix != null && geo != null ? 0.72 : 0.0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Rise(
                    t: _span(t, late, late + 0.16),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            story.head,
                            style: HaloType.serif(
                              size: 23,
                              height: 1.1,
                              color: HaloColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            story.tail,
                            style: HaloType.serif(
                              size: 23,
                              height: 1.15,
                              weight: FontWeight.w300,
                              italic: true,
                              color: HaloColors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (story.rows.isEmpty && !report.gpsBlank)
                    _NothingFound(
                      path: path,
                      video: report.kind == MetaKind.mp4,
                      t: t,
                    ),
                  if (story.rows.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: HaloColors.surface2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: HaloColors.line, width: 0.5),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < story.rows.length; i++)
                            _Rise(
                              t: _span(
                                t,
                                late + 0.05 + i * 0.04,
                                late + 0.2 + i * 0.04,
                              ),
                              child: _StoryRowView(
                                row: story.rows[i],
                                first: i == 0,
                                onTap: story.rows[i].kind == StoryRowKind.more
                                    ? onMore
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// a file with nothing in it: the picture, a tick landing on it, and what
// was looked for, each found not there
class _NothingFound extends StatelessWidget {
  final String? path;
  final bool video;
  final double t;
  const _NothingFound({
    required this.path,
    required this.video,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final fields = [
      l10n.cleanerLocation,
      l10n.cleanerTimeTaken,
      l10n.cleanerPhoneModel,
      l10n.cleanerSerialNumber,
      l10n.cleanerOwnerName,
      l10n.cleanerHiddenThumbnail,
    ];
    final pop = Curves.easeOutBack.transform(_span(t, 0.28, 0.5));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rise(
            t: _span(t, 0.1, 0.32),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (path != null)
                    ToolThumb(path: path!, video: video, size: 104)
                  else
                    const SizedBox(width: 104, height: 104),
                  PositionedDirectional(
                    end: -10,
                    bottom: -10,
                    child: Transform.scale(
                      scale: pop,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: HaloColors.green,
                          border: Border.all(
                            color: HaloColors.surface,
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 22,
                          color: HaloColors.surface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          _Rise(
            t: _span(t, 0.36, 0.52),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: HaloColors.surface2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HaloColors.line, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    child: Text(
                      l10n.photoKnowsLookedFor,
                      style: HaloType.mono(size: 11, color: HaloColors.amber),
                    ),
                  ),
                  for (var i = 0; i < fields.length; i++)
                    _Checked(
                      label: fields[i],
                      t: _span(t, 0.46 + i * 0.06, 0.62 + i * 0.06),
                    ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Checked extends StatelessWidget {
  final String label;
  final double t;
  const _Checked({required this.label, required this.t});

  @override
  Widget build(BuildContext context) {
    final k = Curves.easeOutCubic.transform(t);
    final tick = Curves.easeOutBack.transform(t);
    return Opacity(
      opacity: k,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: HaloType.sans(size: 13.5, color: HaloColors.text),
              ),
            ),
            Text(
              l10n.photoKnowsNotInIt,
              style: HaloType.mono(size: 10.5, color: HaloColors.green),
            ),
            const SizedBox(width: 6),
            Transform.scale(
              scale: tick,
              child: Icon(
                Icons.check_rounded,
                size: 16,
                color: HaloColors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryRowView extends StatelessWidget {
  final StoryRow row;
  final bool first;
  final VoidCallback? onTap;
  const _StoryRowView({required this.row, required this.first, this.onTap});

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = switch (row.kind) {
      StoryRowKind.place => (_pin, HaloColors.amber),
      StoryRowKind.hidden => (_hidden, HaloColors.amber),
      StoryRowKind.device => (_phone, HaloColors.violet),
      StoryRowKind.time => (_clock, HaloColors.rose),
      StoryRowKind.more => (_list, HaloColors.warm),
    };
    final body = Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(top: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Center(child: StrokeIcon(icon, size: 20, color: tint)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  style: HaloType.sans(
                    size: 13.5,
                    weight: FontWeight.w500,
                    color: HaloColors.text,
                  ),
                ),
                if (row.mono != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    row.mono!,
                    style: HaloType.mono(size: 10.5, color: HaloColors.warm),
                  ),
                ],
                if (row.sub != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    row.sub!,
                    maxLines: row.kind == StoryRowKind.more ? 1 : null,
                    overflow: row.kind == StoryRowKind.more
                        ? TextOverflow.ellipsis
                        : null,
                    style: HaloType.sans(
                      size: 11.5,
                      height: 1.4,
                      color: HaloColors.warm,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            StrokeIcon(
              _chevron,
              size: 16,
              color: HaloColors.warm,
              pointing: true,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return body;
    return PressScale(
      label: l10n.photoKnowsShowEverything(row.title),
      onTap: onTap,
      scale: 0.98,
      child: ExcludeSemantics(child: body),
    );
  }
}
