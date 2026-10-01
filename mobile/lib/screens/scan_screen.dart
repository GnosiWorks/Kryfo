// SPDX-License-Identifier: GPL-3.0-or-later
// in-app qr scanner: nothing leaves the app, and a non-kryfo qr in frame
// gets a hint

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import '../theme.dart';
import '../l10n/l10n.dart';
import '../lock_guard.dart' show lockGuard;
import '../widgets/halo_buttons.dart';
import '../widgets/motion.dart' show houseSpring, motionStill;
import '../widgets/press_scale.dart';

// stands in for the camera reader in tests
@visibleForTesting
Widget Function(
  void Function(CameraController?, Exception?) onCreated,
  void Function(Code) onScan,
)?
scanReaderForTest;

// a camera error that a trip to the app's settings can fix
bool cameraDenied(Object? e) =>
    e is CameraException &&
    (e.code.contains('Access') || e.code.toLowerCase().contains('permission'));

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // zxing-cpp under the hood. the controller arrives via onControllerCreated
  // and is only used for the torch.
  CameraController? _cam;
  bool _handled = false;
  bool _torchOn = false;
  bool _detectedSuccess = false;
  String? _hint;
  Timer? _hintOff;
  // the camera would not open: what to say, and whether settings can fix it
  String? _error;
  bool _denied = false;
  // a phone with no camera has nothing to try again
  bool _again = true;
  // left for the app's settings while the error showed
  bool _away = false;
  // off for a frame on a retry, so a new reader asks for the camera again
  bool _reader = true;
  late final AnimationController _scanAnim;

  // the lock closes the scanner: its camera never runs under the pin pad
  VoidCallback? _unguard;
  void _closeForLock() {
    _unguard = null;
    if (!mounted) return;
    final r = ModalRoute.of(context);
    if (r != null && r.isActive) Navigator.of(context).removeRoute(r);
  }

  bool get _inFront => mounted && (ModalRoute.of(context)?.isCurrent ?? false);

  @override
  void initState() {
    super.initState();
    _unguard = lockGuard.closeOnLock(_closeForLock);
    WidgetsBinding.instance.addObserver(this);
    _scanAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _checkCameras();
  }

  // the reader waits forever on a phone with no camera
  Future<void> _checkCameras() async {
    if (scanReaderForTest != null) return;
    try {
      if ((await availableCameras()).isEmpty) {
        _fail(l10n.cameraNoCameraOnThis, denied: false, again: false);
      }
    } catch (_) {}
  }

  void _onCreated(CameraController? c, Exception? e) {
    _cam = c;
    if (c != null || e == null) return;
    final denied = cameraDenied(e);
    _fail(
      denied ? l10n.cameraCameraPermissionIsOff : l10n.cameraCameraNotAvailable,
      denied: denied,
    );
  }

  void _fail(String why, {required bool denied, bool again = true}) {
    if (!mounted || _handled) return;
    _scanAnim.stop();
    _hintOff?.cancel();
    setState(() {
      _error = why;
      _denied = denied;
      _again = again;
      _away = false;
      _hint = null;
    });
  }

  // the old reader lets go of the camera a frame before the new one asks
  void _retry() {
    if (_error == null) return;
    setState(() {
      _error = null;
      _reader = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _reader = true);
      if (!motionStill(context)) _scanAnim.repeat(reverse: true);
    });
  }

  // back from the app's settings: try the camera again. the permission
  // prompt itself only makes the app inactive, so it never loops here
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_error == null || !_denied) return;
    if (state == AppLifecycleState.paused) _away = true;
    if (state == AppLifecycleState.resumed && _away) _retry();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // the line sweeps only while the camera looks, and never with less
    // movement: the corners already say where to aim
    if (MediaQuery.disableAnimationsOf(context)) {
      _scanAnim.stop();
    } else if (!_scanAnim.isAnimating && !_detectedSuccess && _error == null) {
      _scanAnim.repeat(reverse: true);
    }
  }

  void _onScan(Code code) {
    if (_handled || !_inFront) return;
    final raw = code.text;
    if (raw == null || raw.isEmpty) return;
    if (!raw.startsWith('kryfo://')) {
      // the warning stays while that code is in frame and goes a little
      // after it leaves
      _hintOff?.cancel();
      _hintOff = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _hint = null);
      });
      if (_hint == null) {
        HapticFeedback.selectionClick();
        setState(() => _hint = l10n.scanThatSNotA);
      }
      return;
    }
    _handled = true;
    _scanAnim.stop();
    _hintOff?.cancel();
    HapticFeedback.mediumImpact();
    setState(() {
      _detectedSuccess = true;
      _hint = null;
    });
    // short success pulse before popping
    Future.delayed(const Duration(milliseconds: 380), () {
      if (!mounted || !_inFront) return;
      Navigator.of(context).pop(raw);
    });
  }

  @override
  void dispose() {
    _unguard?.call();
    _hintOff?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _scanAnim.dispose();
    super.dispose();
  }

  // the camera would not open: what is wrong and the way out, in place of the
  // aiming hint
  Widget _failCard() {
    return Container(
      key: const ValueKey('failed'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.7,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.no_photography_outlined,
            color: HaloColors.amber,
            size: 24,
          ),
          const SizedBox(height: 10),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: HaloType.sans(size: 13.5, color: Colors.white, height: 1.4),
          ),
          if (_denied || _again) const SizedBox(height: 14),
          if (_denied) ...[
            HaloPrimaryButton(
              label: l10n.cameraOpenSettings,
              onTap: openAppSettings,
            ),
            const SizedBox(height: 8),
            _ChromeGhost(label: l10n.commonTryAgain, onTap: _retry),
          ] else if (_again)
            HaloPrimaryButton(label: l10n.commonTryAgain, onTap: _retry),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boxSize = (size.width * 0.7).clamp(220.0, 320.0);
    return Scaffold(
      backgroundColor: HaloColors.ink,
      body: Stack(
        children: [
          if (!_reader)
            const SizedBox.shrink()
          else
            scanReaderForTest?.call(_onCreated, _onScan) ??
                ReaderWidget(
                  mayOpen: () => !lockGuard.isLocked(),
                  onScan: _onScan,
                  onControllerCreated: _onCreated,
                  showScannerOverlay: false,
                  showFlashlight: false,
                  showGallery: false,
                  showToggleCamera: false,
                  // decode almost the whole frame: the default 50% crop
                  // misses a qr that fills the screen. tryHarder and
                  // tryInverted read it on the first pass in poorer light.
                  cropPercent: 0.9,
                  tryHarder: true,
                  tryInverted: true,
                  scanDelay: const Duration(milliseconds: 500),
                ),
          // dim mask with an even-odd cutout, so the eye goes to the
          // viewfinder
          IgnorePointer(
            child: CustomPaint(
              size: size,
              painter: _MaskPainter(boxSize: boxSize),
            ),
          ),
          // viewfinder frame (corner brackets + animated scan line)
          Center(
            child: ScanFrame(
              size: boxSize,
              success: _detectedSuccess,
              failed: _error != null,
              scanAnim: _scanAnim,
            ),
          ),
          // top bar - back + title + torch
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 12, 6),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: l10n.commonBack,
                      icon: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        l10n.scanScanAKryfoQr,
                        style: HaloType.pageTitle().copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.scanFlash,
                      onPressed: () async {
                        final cam = _cam;
                        if (cam == null) return;
                        final on = !_torchOn;
                        try {
                          await cam.setFlashMode(
                            on ? FlashMode.torch : FlashMode.off,
                          );
                          setState(() => _torchOn = on);
                        } catch (_) {
                          // no flash unit - leave the icon as-is
                        }
                      },
                      icon: Icon(
                        _torchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: _torchOn ? HaloColors.amber : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // bottom helper text - switches to a transient warning when a
          // non-kryfo qr appears in frame.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: AnimatedSwitcher(
                  duration: motionStill(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  child: _error != null
                      ? _failCard()
                      : Container(
                          key: ValueKey(_hint ?? 'default'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _hint != null
                                  ? HaloColors.amber.withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.08),
                              width: 0.7,
                            ),
                          ),
                          child: Text(
                            _hint ?? l10n.scanPointAtAKryfo,
                            textAlign: TextAlign.center,
                            style: HaloType.sans(
                              size: 12.5,
                              color: _hint != null
                                  ? HaloColors.amber
                                  : Colors.white,
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

// renders the dimmed mask with a transparent rounded rect in the middle
// where the camera shows through. used as a fixed overlay.
class _MaskPainter extends CustomPainter {
  final double boxSize;
  _MaskPainter({required this.boxSize});

  @override
  void paint(Canvas canvas, Size size) {
    final mask = Paint()..color = Colors.black.withValues(alpha: 0.62);
    final outer = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: boxSize,
      height: boxSize,
    );
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(22)));
    final combined = Path.combine(PathOperation.difference, outer, hole);
    canvas.drawPath(combined, mask);
  }

  @override
  bool shouldRepaint(_MaskPainter oldDelegate) =>
      oldDelegate.boxSize != boxSize;
}

// the viewfinder frame, closing in on the house spring as the scanner opens
class ScanFrame extends StatefulWidget {
  final double size;
  final bool success;
  // the camera would not open: dim corners, nothing sweeps
  final bool failed;
  final Animation<double> scanAnim;
  const ScanFrame({
    super.key,
    required this.size,
    required this.success,
    this.failed = false,
    required this.scanAnim,
  });

  @override
  State<ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<ScanFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController.unbounded(
    vsync: this,
  );
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _in.value = 1;
      return;
    }
    // the spring stops within a hair of its end: the end itself after
    _in.animateWith(houseSpring(0, 1)).then((_) {
      if (mounted) _in.value = 1;
    });
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _in,
      builder: (_, child) {
        final v = _in.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(scale: 1.14 - 0.14 * v, child: child),
        );
      },
      child: _Viewfinder(
        size: widget.size,
        success: widget.success,
        failed: widget.failed,
        scanAnim: widget.scanAnim,
        still: MediaQuery.disableAnimationsOf(context),
      ),
    );
  }
}

// the viewfinder frame: amber corner brackets + a moving horizontal
// scan line + a brief success flash when a kryfo qr is detected.
class _Viewfinder extends StatelessWidget {
  final double size;
  final bool success;
  final bool failed;
  final Animation<double> scanAnim;
  final bool still;
  const _Viewfinder({
    required this.size,
    required this.success,
    required this.failed,
    required this.scanAnim,
    required this.still,
  });

  @override
  Widget build(BuildContext context) {
    final accent = success
        ? HaloColors.green
        : failed
        ? HaloColors.line2
        : HaloColors.amber;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // corner brackets - 4 L-shapes. placed by side, not by reading
          // direction: each one is drawn for the corner it sits in
          Positioned(left: 0, top: 0, child: _corner(accent, true, true)),
          Positioned(right: 0, top: 0, child: _corner(accent, false, true)),
          Positioned(left: 0, bottom: 0, child: _corner(accent, true, false)),
          Positioned(right: 0, bottom: 0, child: _corner(accent, false, false)),
          // scan line (hidden once success)
          if (!success && !failed && !still)
            AnimatedBuilder(
              animation: scanAnim,
              builder: (_, _) {
                final y = scanAnim.value * (size - 4);
                return Positioned(
                  top: y,
                  left: 14,
                  right: 14,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0),
                          accent.withValues(alpha: 0.95),
                          accent.withValues(alpha: 0),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.45),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          // success overlay - amber/green wash + checkmark
          AnimatedOpacity(
            opacity: success ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 260),
            child: Container(
              decoration: BoxDecoration(
                color: HaloColors.green.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: HaloColors.green, width: 2),
              ),
              alignment: Alignment.center,
              child: AnimatedScale(
                scale: success || still ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HaloColors.green,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: HaloColors.ink,
                    size: 38,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _corner(Color c, bool isLeft, bool isTop) {
    const len = 26.0;
    const w = 3.0;
    return SizedBox(
      width: len,
      height: len,
      child: CustomPaint(painter: _CornerPainter(c, isLeft, isTop, len, w)),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final bool isLeft;
  final bool isTop;
  final double len;
  final double thickness;
  _CornerPainter(this.color, this.isLeft, this.isTop, this.len, this.thickness);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final hx = isLeft ? 0.0 : len;
    final hy = isTop ? 0.0 : len;
    final endX = isLeft ? len : 0.0;
    final endY = isTop ? len : 0.0;
    canvas.drawLine(Offset(hx, hy), Offset(endX, hy), paint);
    canvas.drawLine(Offset(hx, hy), Offset(hx, endY), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}

// the quiet second button on the always-dark card: white like the rest of
// the scanner chrome, so it reads in the light theme too
class _ChromeGhost extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ChromeGhost({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      label: label,
      onTap: onTap,
      scale: 0.96,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: ExcludeSemantics(
          child: Text(
            label,
            style: HaloType.sans(size: 14, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
