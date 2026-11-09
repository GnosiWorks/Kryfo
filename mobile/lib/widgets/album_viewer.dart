// SPDX-License-Identifier: GPL-3.0-or-later
// an album full screen: it opens out of the tile that was tapped, swipes
// through the album in its order with a count at the top, zooms a photo by
// pinch or double tap, and plays a video where it is. a swipe down or the
// close button takes it back into its tile; with no movement asked for it
// fades instead. on a computer the arrow keys and the round buttons at its
// sides go back and forth, as a mouse cannot swipe.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../desktop/desktop_mode.dart' show onDesktop;
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../main.dart' show appState, AppStateScreen;
import '../open_file.dart';
import '../picture_lock.dart' show picturesShut;
import '../theme.dart';
import 'album_grid.dart' show albumFlight, albumHeroTag;
import 'decode_px.dart';
import 'halo_hero.dart';
import 'motion.dart' show houseSpring, kHouseCurve, kText2, motionStill;
import 'sealed_picture.dart';
import 'text_ground.dart';
import 'video_frame.dart';
import 'video_viewer.dart' show ViewerRound, ViewerScrubber, ViewerTime;
import '../lock_guard.dart' show lockGuard;
import '../video_playback.dart';

class AlbumItem {
  final String path;
  final bool video;
  final String? fileName;
  const AlbumItem(this.path, {this.video = false, this.fileName});
}

// an album on its way up: a second tap opens nothing more
bool _opening = false;

/// opens [items] at [start]. [secure] blocks screenshots while it is up; a
/// video in it does too, as the video player does
Future<void> openAlbum(
  BuildContext context,
  List<AlbumItem> items, {
  int start = 0,
  bool secure = false,
}) async {
  if (_opening || items.isEmpty) return;
  FocusManager.instance.primaryFocus?.unfocus();
  final at = start.clamp(0, items.length - 1);
  final still = motionStill(context);
  final first = items[at];
  _opening = true;
  try {
    // decoded before the flight, so it knows where it lands
    if (!first.video) {
      final done = Completer<void>();
      final wait = Timer(const Duration(milliseconds: 300), () {
        if (!done.isCompleted) done.complete();
      });
      precacheImage(
        ResizeImage.resizeIfNeeded(
          screenPx(context, times: 2),
          null,
          FileImage(File(first.path)),
        ),
        context,
        onError: (_, _) {},
      ).whenComplete(() {
        wait.cancel();
        if (!done.isCompleted) done.complete();
      });
      await done.future;
    }
  } finally {
    _opening = false;
  }
  if (!context.mounted) return;
  final hold = secure || items.any((i) => i.video);
  if (hold) await appState.forceSecure(true);
  try {
    if (!context.mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: Duration(milliseconds: still ? 200 : 280),
        reverseTransitionDuration: Duration(milliseconds: still ? 180 : 240),
        // no flight with no movement asked for: the page fades in and out
        transitionsBuilder: (_, anim, _, child) =>
            still ? FadeTransition(opacity: anim, child: child) : child,
        pageBuilder: (_, anim, _) => TextGround(
          child: AlbumViewer(
            items: items,
            start: at,
            route: anim,
            flight: !still,
          ),
        ),
      ),
    );
  } finally {
    if (hold) await appState.forceSecure(false);
  }
  FocusManager.instance.primaryFocus?.unfocus();
}

class AlbumViewer extends StatefulWidget {
  final List<AlbumItem> items;
  final int start;
  final Animation<double> route;
  // the item flies out of its tile and back
  final bool flight;
  const AlbumViewer({
    super.key,
    required this.items,
    required this.start,
    required this.route,
    this.flight = true,
  });

  @override
  State<AlbumViewer> createState() => AlbumViewerState();
}

class AlbumViewerState extends State<AlbumViewer>
    with SingleTickerProviderStateMixin {
  late final PageController _pages = PageController(initialPage: widget.start);
  late int _at = widget.start;
  bool _zoomed = false;
  bool _chrome = true;
  bool _closing = false;
  double _drag = 0;
  bool _pastClose = false;
  late final AnimationController _settle;

  static const _closeAt = 110.0;

  /// the item shown, 0-based
  int get at => _at;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController.unbounded(vsync: this)
      ..addListener(() => setState(() => _drag = _settle.value));
  }

  @override
  void dispose() {
    _settle.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  void _dragUpdate(DragUpdateDetails d) {
    _settle.stop();
    setState(() => _drag += d.delta.dy);
    final past = _drag.abs() > _closeAt;
    if (past != _pastClose) {
      _pastClose = past;
      if (past) HapticFeedback.lightImpact();
    }
  }

  void _dragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dy;
    if (_drag.abs() > _closeAt || v.abs() > 900) {
      _close();
      return;
    }
    _pastClose = false;
    if (motionStill(context)) {
      setState(() => _drag = 0);
      return;
    }
    _settle.value = _drag;
    _settle.animateWith(houseSpring(_drag, 0, v)).then((_) {
      if (mounted) setState(() => _drag = 0);
    });
  }

  void _zoom(bool z) {
    if (z != _zoomed) setState(() => _zoomed = z);
  }

  /// one item on, [by] +1 or -1, in the album's order
  void step(int by) {
    final to = _at + by;
    if (to < 0 || to >= widget.items.length || !_pages.hasClients) return;
    if (motionStill(context)) {
      _pages.jumpToPage(to);
    } else {
      _pages.animateToPage(
        to,
        duration: const Duration(milliseconds: 280),
        curve: kHouseCurve,
      );
    }
  }

  // the arrows as they read: in a right-to-left language the next item is
  // to the left
  Map<ShortcutActivator, VoidCallback> _keys(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return {
      const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
          step(rtl ? -1 : 1),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
          step(rtl ? 1 : -1),
      const SingleActivator(LogicalKeyboardKey.escape): _close,
    };
  }

  // the round buttons at the sides, while the count shows
  List<Widget> _sides(double fade) {
    final n = widget.items.length;
    if (!onDesktop || n < 2) return const [];
    Widget side(bool next) {
      final shown = _chrome && !_zoomed && (next ? _at < n - 1 : _at > 0);
      return PositionedDirectional(
        start: next ? null : 16,
        end: next ? 16 : null,
        top: 0,
        bottom: 0,
        child: Center(
          child: IgnorePointer(
            ignoring: !shown,
            child: AnimatedOpacity(
              opacity: shown ? fade.clamp(0.0, 1.0) : 0,
              duration: motionStill(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: ViewerRound(
                key: ValueKey(next ? 'album next' : 'album previous'),
                size: 44,
                label: next ? l10n.albumNext : l10n.albumPrevious,
                onTap: () => step(next ? 1 : -1),
                child: Icon(
                  next
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                  size: 28,
                  color: Colors.white,
                  // the chevron points the way the album goes
                  textDirection: Directionality.of(context),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return [side(false), side(true)];
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final pulled = (_drag.abs() / 420).clamp(0.0, 1.0);
    final n = widget.items.length;
    final pages = PageView.builder(
      controller: _pages,
      itemCount: n,
      physics: _zoomed
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      onPageChanged: (i) {
        HapticFeedback.selectionClick();
        setState(() {
          _at = i;
          _zoomed = false;
        });
      },
      itemBuilder: (_, i) {
        final item = widget.items[i];
        final Widget page = item.video
            ? _VideoPage(
                key: ValueKey('v${item.path}'),
                item: item,
                active: i == _at,
                route: widget.route,
                onChrome: (on) {
                  if (on != _chrome) setState(() => _chrome = on);
                },
              )
            : _PhotoPage(
                key: ValueKey('p${item.path}'),
                path: item.path,
                onZoom: _zoom,
                onTap: () => setState(() => _chrome = !_chrome),
              );
        // only the page in view flies home: a neighbour half built while
        // a swipe settles must not
        if (!widget.flight || i != _at) return page;
        return HaloHero(
          tag: albumHeroTag(item.path),
          flightShuttleBuilder: (_, a, _, _, _) =>
              albumFlight(a, item.path, video: item.video, radius: 4),
          child: page,
        );
      },
    );
    final viewer = AnimatedBuilder(
      animation: widget.route,
      builder: (context, child) {
        final dark = widget.route.value * (1 - pulled * 0.75);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: dark > 0.5
              ? haloOverlayOnDark
              : haloOverlayStyle(
                  underNav: MediaQuery.viewPaddingOf(context).bottom > 0,
                ),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: _zoomed ? null : _dragUpdate,
            onVerticalDragEnd: _zoomed ? null : _dragEnd,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: dark),
                  ),
                ),
                Positioned.fill(child: child!),
                ..._top(pad, widget.route.value * (1 - pulled)),
                ..._sides(widget.route.value * (1 - pulled)),
              ],
            ),
          ),
        );
      },
      child: Transform.translate(
        offset: Offset(0, _drag),
        child: Transform.scale(scale: 1 - pulled * 0.12, child: pages),
      ),
    );
    if (!onDesktop) return viewer;
    return CallbackShortcuts(
      bindings: _keys(context),
      child: Focus(autofocus: true, child: viewer),
    );
  }

  // the close button and the count, over a wash so they read on white
  List<Widget> _top(EdgeInsets pad, double fade) {
    final n = widget.items.length;
    return [
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: IgnorePointer(
          ignoring: !_chrome,
          child: AnimatedOpacity(
            opacity: _chrome ? fade.clamp(0.0, 1.0) : 0,
            duration: motionStill(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: Container(
              padding: EdgeInsets.fromLTRB(12, pad.top + 8, 12, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.black.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  ViewerRound(
                    size: 44,
                    label: l10n.commonClose,
                    onTap: _close,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: AnimatedSwitcher(
                        duration: motionStill(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 160),
                        switchInCurve: kHouseCurve,
                        child: Text(
                          l10n.albumCounter(whole(_at + 1), whole(n)),
                          key: ValueKey(_at),
                          textAlign: TextAlign.center,
                          style: HaloType.sans(
                            size: 15,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // the close button's width again, so the count is centred
                  const SizedBox(width: 44),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _PhotoPage extends StatefulWidget {
  final String path;
  final ValueChanged<bool> onZoom;
  final VoidCallback onTap;
  const _PhotoPage({
    super.key,
    required this.path,
    required this.onZoom,
    required this.onTap,
  });
  @override
  State<_PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<_PhotoPage>
    with SingleTickerProviderStateMixin {
  final _zoom = TransformationController();
  final _box = GlobalKey();
  bool _zoomed = false;
  Offset? _tapAt;
  late final AnimationController _ease = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  Animation<Matrix4>? _to;

  @override
  void initState() {
    super.initState();
    _ease.addListener(() {
      final to = _to;
      if (to != null) _zoom.value = to.value;
    });
  }

  @override
  void dispose() {
    _ease.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _set(bool z) {
    if (z == _zoomed) return;
    setState(() => _zoomed = z);
    widget.onZoom(z);
  }

  void _zoomTo(Matrix4 m) {
    _set(m.getMaxScaleOnAxis() > 1.01);
    if (motionStill(context)) {
      _zoom.value = m;
      return;
    }
    _to = Matrix4Tween(
      begin: _zoom.value,
      end: m,
    ).animate(CurvedAnimation(parent: _ease, curve: Curves.easeOutCubic));
    _ease.forward(from: 0);
  }

  void _doubleTap() {
    if (_zoomed) {
      _zoomTo(Matrix4.identity());
      return;
    }
    final box = _box.currentContext?.findRenderObject() as RenderBox?;
    final at = _tapAt;
    if (box == null || at == null) return;
    final l = box.globalToLocal(at);
    final p = _zoom.toScene(
      Offset(l.dx.clamp(0.0, box.size.width), l.dy.clamp(0.0, box.size.height)),
    );
    const s = 2.5;
    HapticFeedback.selectionClick();
    _zoomTo(
      Matrix4.identity()
        ..translateByDouble(-p.dx * (s - 1), -p.dy * (s - 1), 0, 1)
        ..scaleByDouble(s, s, 1, 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final px = screenPx(context, times: 2);
    final image = ResizeImage.resizeIfNeeded(
      px,
      null,
      FileImage(File(widget.path)),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // a tap on a zoomed photo brings the whole of it back
      onTap: _zoomed ? () => _zoomTo(Matrix4.identity()) : widget.onTap,
      onDoubleTapDown: (d) => _tapAt = d.globalPosition,
      onDoubleTap: _doubleTap,
      child: SafeArea(
        child: Center(
          child: InteractiveViewer(
            key: _box,
            transformationController: _zoom,
            minScale: 1,
            maxScale: 4,
            panEnabled: _zoomed,
            onInteractionStart: (_) => _ease.stop(),
            onInteractionEnd: (_) =>
                _set(_zoom.value.getMaxScaleOnAxis() > 1.01),
            child: Semantics(
              image: true,
              label: l10n.appPhoto,
              // its blur, the photo fading up over it once decoded
              child: SealedPicture(
                path: widget.path,
                image: image,
                shaped: true,
                decodeWidth: px,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  Icons.image_not_supported_outlined,
                  size: 28,
                  color: kText2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// a video in the album: its first frame until it plays, then the player in
// the same place. it plays once its page is in view and the flight is over,
// and stops when another page is
class _VideoPage extends StatefulWidget {
  final AlbumItem item;
  final bool active;
  final Animation<double> route;
  // the album's own top bar shows with the controls
  final ValueChanged<bool> onChrome;
  const _VideoPage({
    super.key,
    required this.item,
    required this.active,
    required this.route,
    required this.onChrome,
  });
  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  // the one player every screen shares: a page out of view sleeps
  late final VideoPlayback _v = VideoPlayback(
    widget.item.path,
    aspect: videoInfoNow(widget.item.path)?.aspect ?? 16 / 9,
    length: videoInfoNow(widget.item.path)?.length ?? Duration.zero,
  )..wanted = widget.active;
  bool _done = false;
  bool _controls = true;
  double? _scrub;
  Timer? _hide;
  late VideoInfo? _info = videoInfoNow(widget.item.path);

  bool get _playing => _v.playing;
  bool get _failed => _v.failed;
  int? get _id => _v.textureId;

  @override
  void initState() {
    super.initState();
    widget.route.addStatusListener(_routeStatus);
    _v.addListener(_moved);
    picturesShut.addListener(_lockChanged);
    if (_info == null) _askInfo();
    if (widget.active) _open();
  }

  void _askInfo() => videoInfoFor(widget.item.path).then((i) {
    if (mounted && i != null) setState(() => _info = i);
  });

  // the first frame the lock took comes back under the blur after it
  void _lockChanged() {
    if (!picturesShut.value) _askInfo();
  }

  void _moved() {
    if (!mounted) return;
    final ended = _v.done && !_done;
    setState(() {
      _done = _v.done;
      if (ended) _controls = true;
    });
    if (ended) widget.onChrome(true);
  }

  @override
  void didUpdateWidget(_VideoPage old) {
    super.didUpdateWidget(old);
    _v.wanted = widget.active;
    if (widget.active && !old.active) {
      _open();
    } else if (!widget.active && old.active && _playing) {
      _pause();
    }
  }

  @override
  void dispose() {
    widget.route.removeStatusListener(_routeStatus);
    picturesShut.removeListener(_lockChanged);
    _v.removeListener(_moved);
    _v.dispose();
    _hide?.cancel();
    super.dispose();
  }

  void _routeStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && widget.active && !_v.started) {
      _play();
    }
  }

  Future<void> _open() => _v
      .open(
        play: widget.active && widget.route.status == AnimationStatus.completed,
      )
      .then((_) {
        if (mounted && _playing) _hideSoon();
      });

  Future<void> _play() async {
    if (lockGuard.isLocked() || !widget.active) return;
    await _v.play();
    if (mounted && _playing) _hideSoon();
  }

  Future<void> _pause() async {
    await _v.pause();
    if (!mounted) return;
    setState(() => _controls = true);
    widget.onChrome(true);
    _hide?.cancel();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    _playing ? _pause() : _play();
  }

  void _hideSoon() {
    _hide?.cancel();
    _hide = Timer(const Duration(milliseconds: 2600), () {
      if (mounted && _playing && _scrub == null) {
        setState(() => _controls = false);
        widget.onChrome(false);
      }
    });
  }

  void _tap() {
    setState(() => _controls = !_controls);
    widget.onChrome(_controls);
    if (_controls) _hideSoon();
  }

  void _seekTo(double f) => _v.seekShare(f);

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final jpeg = _info?.jpeg;
    final id = _id;
    final visible = _controls || !_playing;
    final len = _v.length.inMilliseconds;
    final at = _scrub ?? _v.share;
    final fade = motionStill(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      onDoubleTap: _failed ? null : _toggle,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: _failed
                ? Text(
                    l10n.videoViewerCannotPlayShown,
                    textAlign: TextAlign.center,
                    style: HaloType.sans(size: 14, color: Colors.white),
                  )
                : VideoFrame(
                    aspect: _v.aspect,
                    turns: _v.turns,
                    // its blur, the first frame fading up over it
                    under: SealedPicture(
                      path: widget.item.path,
                      image: jpeg == null ? null : MemoryImage(jpeg),
                      ground: Colors.black,
                    ),
                    texture: id != null && _v.started
                        ? Texture(textureId: id)
                        : null,
                  ),
          ),
          if (!_failed)
            Center(
              child: IgnorePointer(
                ignoring: _playing,
                child: AnimatedOpacity(
                  opacity: _playing ? 0 : 1,
                  duration: fade,
                  child: ViewerRound(
                    size: 66,
                    label: _done
                        ? l10n.videoViewerPlayAgain
                        : l10n.videoViewerPlay,
                    onTap: _id == null ? _play : _toggle,
                    child: Icon(
                      _done ? Icons.replay_rounded : Icons.play_arrow_rounded,
                      size: 38,
                      color: HaloColors.amber,
                    ),
                  ),
                ),
              ),
            ),
          if (!_failed)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !visible,
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: fade,
                  // the timeline runs left to right in every language
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(8, 28, 16, pad.bottom + 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          ViewerRound(
                            size: 44,
                            plain: true,
                            label: _playing
                                ? l10n.videoViewerPause
                                : l10n.videoViewerPlay,
                            onTap: _id == null ? null : _toggle,
                            child: Icon(
                              _playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 26,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          ViewerTime(
                            Duration(
                              milliseconds: (at * len).round().clamp(
                                0,
                                len.abs(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ViewerScrubber(
                              value: at.clamp(0.0, 1.0),
                              enabled: _id != null && len > 0,
                              onStart: (f) {
                                HapticFeedback.selectionClick();
                                _hide?.cancel();
                                _v.holdReads = true;
                                setState(() => _scrub = f);
                                _seekTo(f);
                              },
                              onChange: (f) {
                                setState(() => _scrub = f);
                                _seekTo(f);
                              },
                              onEnd: () {
                                _v.holdReads = false;
                                setState(() => _scrub = null);
                                if (_playing) _hideSoon();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          ViewerTime(_v.length),
                        ],
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
