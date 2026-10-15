// SPDX-License-Identifier: GPL-3.0-or-later
// an album full screen: it opens out of the tile that was tapped, swipes
// through the album in its order with a count at the top, zooms a photo by
// pinch or double tap, and plays a video where it is. a swipe down or the
// close button takes it back into its tile; with no movement asked for it
// fades instead.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dlog.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../main.dart' show appState;
import '../open_file.dart';
import '../theme.dart';
import 'album_grid.dart' show albumFlight, albumHeroTag;
import 'decode_px.dart';
import 'halo_hero.dart';
import 'motion.dart' show houseSpring, kHouseCurve, kText2, motionStill;
import 'photo_viewer.dart' show PhotoTileFade;
import 'video_viewer.dart' show ViewerRound, ViewerScrubber, ViewerTime;
import '../lock_guard.dart' show lockGuard;

class AlbumItem {
  final String path;
  final bool video;
  final String? fileName;
  const AlbumItem(this.path, {this.video = false, this.fileName});
}

const _channel = MethodChannel('kryfo/video');

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
        pageBuilder: (_, anim, _) =>
            AlbumViewer(items: items, start: at, route: anim, flight: !still),
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
  late final PageController _pages = PageController(
    initialPage: widget.start,
  );
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
    return AnimatedBuilder(
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
    final image = ResizeImage.resizeIfNeeded(
      screenPx(context, times: 2),
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
              child: Image(
                image: image,
                gaplessPlayback: true,
                frameBuilder: (_, child, frame, sync) =>
                    PhotoTileFade(shown: sync || frame != null, child: child),
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

class _VideoPageState extends State<_VideoPage> with WidgetsBindingObserver {
  int? _id;
  bool _opening = false;
  bool _failed = false;
  bool _started = false;
  bool _playing = false;
  bool _done = false;
  bool _controls = true;
  double _aspect = 16 / 9;
  Duration _length = Duration.zero;
  Duration _pos = Duration.zero;
  double? _scrub;
  Timer? _poll;
  Timer? _hide;
  VoidCallback? _unguard;
  late VideoInfo? _info = videoInfoNow(widget.item.path);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.route.addStatusListener(_routeStatus);
    if (_info case final i?) {
      _aspect = i.aspect;
      _length = i.length;
    } else {
      videoInfoFor(widget.item.path).then((i) {
        if (!mounted || i == null) return;
        setState(() {
          _info = i;
          if (_id == null) _aspect = i.aspect;
          if (_length == Duration.zero) _length = i.length;
        });
      });
    }
    if (widget.active) _open();
  }

  @override
  void didUpdateWidget(_VideoPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _open();
    } else if (!widget.active && old.active && _playing) {
      _pause();
    }
  }

  @override
  void dispose() {
    _unguard?.call();
    WidgetsBinding.instance.removeObserver(this);
    widget.route.removeStatusListener(_routeStatus);
    _poll?.cancel();
    _hide?.cancel();
    final id = _id;
    if (id != null) _channel.invokeMethod('close', {'id': id});
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _playing) _pause();
  }

  void _routeStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && widget.active && !_started) {
      _play();
    }
  }

  Future<void> _open() async {
    if (_id != null) {
      if (widget.route.status == AnimationStatus.completed) _play();
      return;
    }
    if (_opening || _failed) return;
    _opening = true;
    Map<String, dynamic>? m;
    try {
      m = await _channel.invokeMapMethod<String, dynamic>('open', {
        'path': widget.item.path,
      });
    } catch (e) {
      dlog('album video: not opened (${e.runtimeType})');
    }
    _opening = false;
    if (!mounted) {
      final id = (m?['id'] as num?)?.toInt();
      if (id != null) _channel.invokeMethod('close', {'id': id});
      return;
    }
    if (m == null) {
      setState(() => _failed = true);
      return;
    }
    final w = (m['w'] as num?)?.toInt() ?? 0;
    final h = (m['h'] as num?)?.toInt() ?? 0;
    setState(() {
      _id = (m!['id'] as num).toInt();
      if (w > 0 && h > 0) _aspect = w / h;
      final ms = (m['ms'] as num?)?.toInt() ?? 0;
      if (ms > 0) _length = Duration(milliseconds: ms);
    });
    if (widget.active && widget.route.status == AnimationStatus.completed) {
      _play();
    }
  }

  Future<void> _play() async {
    final id = _id;
    if (id == null || lockGuard.isLocked() || !widget.active) return;
    await _channel.invokeMethod('play', {'id': id});
    if (!mounted) return;
    setState(() {
      _started = true;
      _playing = true;
      _done = false;
    });
    _unguard ??= lockGuard.closeOnLock(() {
      _unguard = null;
      if (mounted && _playing) _pause();
    });
    _poll ??= Timer.periodic(const Duration(milliseconds: 200), (_) => _read());
    _hideSoon();
  }

  Future<void> _pause() async {
    final id = _id;
    if (id == null) return;
    _poll?.cancel();
    _poll = null;
    await _channel.invokeMethod('pause', {'id': id});
    if (!mounted) return;
    setState(() {
      _playing = false;
      _controls = true;
    });
    widget.onChrome(true);
    _hide?.cancel();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    _playing ? _pause() : _play();
  }

  Future<void> _read() async {
    final id = _id;
    if (id == null || _scrub != null) return;
    final m = await _channel.invokeMapMethod<String, dynamic>('state', {
      'id': id,
    });
    if (!mounted || m == null || _scrub != null) return;
    final done = m['done'] == true;
    if (done) {
      _poll?.cancel();
      _poll = null;
    }
    setState(() {
      _pos = Duration(milliseconds: (m['ms'] as num?)?.toInt() ?? 0);
      _playing = m['playing'] == true;
      if (done && !_done) {
        _done = true;
        _controls = true;
        _pos = _length;
      }
    });
    if (done) widget.onChrome(true);
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

  void _seekTo(double f) {
    final id = _id;
    if (id == null) return;
    _channel.invokeMethod('seek', {
      'id': id,
      'ms': (f * _length.inMilliseconds).round(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final jpeg = _info?.jpeg;
    final id = _id;
    final visible = _controls || !_playing;
    final len = _length.inMilliseconds;
    final at = _scrub ?? (len <= 0 ? 0.0 : _pos.inMilliseconds / len);
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
                    l10n.videoViewerCannotPlay,
                    textAlign: TextAlign.center,
                    style: HaloType.sans(size: 14, color: Colors.white),
                  )
                : AspectRatio(
                    aspectRatio: _aspect,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (jpeg != null)
                          Image.memory(
                            jpeg,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          )
                        else
                          const ColoredBox(color: Colors.black),
                        if (id != null && _started) Texture(textureId: id),
                      ],
                    ),
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
                    onTap: _id == null ? _open : _toggle,
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
                                setState(() => _scrub = f);
                                _seekTo(f);
                              },
                              onChange: (f) {
                                setState(() => _scrub = f);
                                _seekTo(f);
                              },
                              onEnd: () {
                                final f = _scrub;
                                setState(() {
                                  if (f != null) {
                                    _pos = Duration(
                                      milliseconds: (f * len).round(),
                                    );
                                    _done = false;
                                  }
                                  _scrub = null;
                                });
                                if (_playing) _hideSoon();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          ViewerTime(_length),
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
