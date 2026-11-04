// desktop_drop 0.8.4, cut down for kryfo: see pubspec.yaml. files dragged
// onto the window from the system, as paths
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// what the window's drop target says, at a point in the window's logical
/// pixels
sealed class DropEvent {
  const DropEvent(this.at);
  final Offset at;
}

/// files are held over the window at [at]
final class DropOver extends DropEvent {
  const DropOver(super.at);
}

/// the drag left the window, or was given up
final class DropGone extends DropEvent {
  const DropGone() : super(Offset.zero);
}

/// files let go at [at]: their paths, local files only
final class DropDone extends DropEvent {
  const DropDone(super.at, this.paths);
  final List<String> paths;
}

/// the window's one channel, its events handed to every listener
class DesktopDrop {
  DesktopDrop._();
  static final instance = DesktopDrop._();

  static const channel = MethodChannel('desktop_drop');

  final _listeners = <void Function(DropEvent)>[];
  bool _inited = false;

  void _init() {
    if (_inited) return;
    _inited = true;
    channel.setMethodCallHandler((call) async {
      final e = eventOf(call);
      if (e == null) return;
      for (final l in List.of(_listeners)) {
        l(e);
      }
    });
  }

  /// windows hands over physical pixels, gtk logical ones
  @visibleForTesting
  static double Function() scale = () =>
      defaultTargetPlatform == TargetPlatform.windows
          ? WidgetsBinding
                  .instance.platformDispatcher.implicitView?.devicePixelRatio ??
              1
          : 1;

  static Offset _point(Object? x, Object? y) {
    final s = scale();
    return Offset((x as num).toDouble() / s, (y as num).toDouble() / s);
  }

  /// the call as an event; null for one this side does not know
  @visibleForTesting
  static DropEvent? eventOf(MethodCall call) {
    final a = call.arguments;
    switch (call.method) {
      case 'updated':
        final l = a as List;
        return DropOver(_point(l[0], l[1]));
      case 'exited':
        return const DropGone();
      case 'dropped':
        final l = a as List;
        final paths = [
          for (final p in l[0] as List)
            if (p is String && p.isNotEmpty) p,
        ];
        return DropDone(_point(l[1], l[2]), paths);
    }
    return null;
  }

  void addListener(void Function(DropEvent) l) {
    _init();
    _listeners.add(l);
  }

  void removeListener(void Function(DropEvent) l) => _listeners.remove(l);
}

/// a part of the window files can be dropped on. it takes a drop only when
/// a hit test at the point reaches it: a sheet, a dialog or another page
/// over it takes the point first
class DropTarget extends StatefulWidget {
  const DropTarget({
    super.key,
    required this.child,
    required this.onDrop,
    this.onHover,
    this.enabled = true,
  });

  final Widget child;

  /// files let go over this target
  final void Function(List<String> paths) onDrop;

  /// true while files are held over this target, false when they leave
  final ValueChanged<bool>? onHover;

  final bool enabled;

  @override
  State<DropTarget> createState() => _DropTargetState();
}

class _DropTargetState extends State<DropTarget> {
  final _box = GlobalKey();
  bool _over = false;

  @override
  void initState() {
    super.initState();
    DesktopDrop.instance.addListener(_on);
  }

  @override
  void didUpdateWidget(DropTarget old) {
    super.didUpdateWidget(old);
    if (!widget.enabled) _hover(false);
  }

  @override
  void dispose() {
    DesktopDrop.instance.removeListener(_on);
    super.dispose();
  }

  void _hover(bool on) {
    if (_over == on) return;
    _over = on;
    widget.onHover?.call(on);
  }

  // the point reaches this target, nothing over it in the way
  bool _reaches(Offset at) {
    final box = _box.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final view = View.maybeOf(context);
    if (view == null) return false;
    final hit = HitTestResult();
    WidgetsBinding.instance.hitTestInView(hit, at, view.viewId);
    return hit.path.any((e) => identical(e.target, box));
  }

  void _on(DropEvent e) {
    if (!mounted) return;
    switch (e) {
      case DropOver():
        _hover(widget.enabled && _reaches(e.at));
      case DropGone():
        _hover(false);
      case DropDone():
        _hover(false);
        if (widget.enabled && e.paths.isNotEmpty && _reaches(e.at)) {
          widget.onDrop(e.paths);
        }
    }
  }

  @override
  Widget build(BuildContext context) => _HitBox(key: _box, child: widget.child);
}

// a box in the hit path wherever its child is, or its own empty room
class _HitBox extends SingleChildRenderObjectWidget {
  const _HitBox({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHitBox();
}

class _RenderHitBox extends RenderProxyBoxWithHitTestBehavior {
  _RenderHitBox() : super(behavior: HitTestBehavior.translucent);
}
