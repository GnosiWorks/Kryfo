// SPDX-License-Identifier: GPL-3.0-or-later
// lock_layer.dart - the app lock, drawn above the whole app. it sits in the
// app's builder, over the navigator itself, so every screen, sheet, dialog,
// menu, toast and flight the app will ever draw is under it. while it is up
// the app underneath is not painted, cannot be touched, cannot take focus,
// is not in the accessibility tree and has its animations stopped. nothing
// the app does underneath can reach the pin pad, by where the pad is, not by
// a check somebody has to remember.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

class LockLayer extends StatefulWidget {
  const LockLayer({
    super.key,
    required this.app,
    required this.lock,
    required this.loaded,
    required this.locked,
    required this.pad,
    this.onLockUp,
    this.onLifted,
  });

  // the navigator, with everything the app draws
  final Widget app;
  // tells when loaded or locked change
  final Listenable lock;
  final bool Function() loaded;
  final bool Function() locked;
  // the pin pad: a fresh one each time the lock goes up
  final WidgetBuilder pad;
  // the lock is going up: stop what runs outside the tree
  final VoidCallback? onLockUp;
  // the lock lifted: what waited for it happens (or is dropped)
  final VoidCallback? onLifted;

  @override
  State<LockLayer> createState() => _LockLayerState();
}

class _LockLayerState extends State<LockLayer>
    with SingleTickerProviderStateMixin {
  // the app is off screen: the lock is up, or not read yet
  bool _hidden = true;
  // the pad is on the pane (the ink alone before the lock is read)
  bool _pad = false;
  int _padGen = 0;
  bool _fading = false;
  late final AnimationController _fade = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 220),
  );
  // fingers on the glass, so a touch that began before the lock ends there
  final Set<int> _down = {};

  @override
  void initState() {
    super.initState();
    widget.lock.addListener(_changed);
    // where it starts: at app start the lock is not read yet, so hidden
    _hidden = !widget.loaded() || widget.locked();
    _pad = widget.loaded() && widget.locked();
    if (_pad) _padGen++;
    _fade.value = _hidden ? 1 : 0;
    lockBack.locked = _hidden;
  }

  @override
  void didUpdateWidget(LockLayer old) {
    super.didUpdateWidget(old);
    if (old.lock != widget.lock) {
      old.lock.removeListener(_changed);
      widget.lock.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.lock.removeListener(_changed);
    _fade.dispose();
    super.dispose();
  }

  // runs in the lock's listener, not in build: at paused and hidden there
  // are no frames, and what the lock stops has to stop now
  void _changed() {
    final loaded = widget.loaded();
    final locked = widget.locked();
    final hide = !loaded || locked;
    final pad = loaded && locked;
    if (hide && !_hidden) {
      _goUp();
      // a fresh pad each time, even over one still fading out after a pin
      if (pad) _padGen++;
    } else if (pad && !_pad) {
      // read at a cold start: the pad takes the ink's place
      _padGen++;
    }
    if (hide) _pad = pad;
    if (!hide && _hidden) {
      _lift();
      return;
    }
    if (mounted) setState(() {});
  }

  void _goUp() {
    for (final p in List.of(_down)) {
      GestureBinding.instance.cancelPointer(p);
    }
    _down.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onLockUp?.call();
    lockBack.locked = true;
    _fade.stop();
    _fade.value = 1;
    _fading = false;
    _hidden = true;
    // the screen reader's tree and focus change now, not at the next
    // frame after the app comes back
    SchedulerBinding.instance.scheduleForcedFrame();
  }

  void _lift() {
    _hidden = false;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _pad = false;
      _fade.value = 0;
    } else {
      _fading = true;
      _fade.reverse(from: 1).whenCompleteOrCancel(() {
        if (!mounted || _hidden) return;
        setState(() {
          _fading = false;
          _pad = false;
        });
      });
    }
    setState(() {});
    lockBack.locked = false;
    widget.onLifted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final pane = _hidden || _fading;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _down.add(e.pointer),
      onPointerUp: (e) => _down.remove(e.pointer),
      onPointerCancel: (e) => _down.remove(e.pointer),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // the same wrappers always, only their flags change: the
          // navigator under them is never rebuilt from scratch
          ExcludeFocus(
            excluding: _hidden,
            child: TickerMode(
              enabled: !_hidden,
              child: Offstage(offstage: _hidden, child: widget.app),
            ),
          ),
          if (pane)
            IgnorePointer(
              ignoring: _fading,
              child: ExcludeSemantics(
                excluding: _fading,
                child: FadeTransition(
                  opacity: _fade,
                  // the pane is not the app: its own messenger, no hero
                  // controller, and its navigation never tells android
                  // anything about back
                  child: NotificationListener<NavigationNotification>(
                    onNotification: (_) => true,
                    child: ScaffoldMessenger(
                      child: HeroControllerScope.none(
                        child: Overlay.wrap(
                          child: _pad
                              ? KeyedSubtree(
                                  key: ValueKey(_padGen),
                                  child: widget.pad(context),
                                )
                              : ColoredBox(color: HaloColors.ink),
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

// back, while the lock is up, goes nowhere. android sends it to dart only
// while dart says it has somewhere to go back to, so while locked it says
// so, and afterwards it says what the app's navigator last said.
class LockBack with WidgetsBindingObserver {
  bool _locked = true;
  bool _rootCanPop = false;

  set locked(bool v) {
    if (_locked == v) return;
    _locked = v;
    _tell();
  }

  bool get locked => _locked;

  void _tell() {
    final life = SchedulerBinding.instance.lifecycleState;
    if (life == null || life == AppLifecycleState.detached) return;
    SystemNavigator.setFrameworkHandlesBack(_locked || _rootCanPop);
  }

  // MaterialApp.onNavigationNotification: what the app's navigator says
  bool navigation(NavigationNotification n) {
    _rootCanPop = n.canHandlePop;
    _tell();
    return true;
  }

  // asked before the app's own handler (registered first, in main)
  @override
  Future<bool> didPopRoute() async => _locked;

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) => _locked;
}

final lockBack = LockBack();
