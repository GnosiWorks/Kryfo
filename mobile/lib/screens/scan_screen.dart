// SPDX-License-Identifier: GPL-3.0-or-later
// in-app qr scanner: nothing leaves the app, and a non-kryfo qr in frame
// gets a hint. the corners find a kryfo code, follow it, then lock. a
// picture from the gallery is read on the device and goes the same way

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import '../desktop/desktop_mode.dart' show onDesktop;
import '../bridge_mode.dart' show looksLikeBridges;
import '../theme.dart';
import '../l10n/l10n.dart';
import '../lock_guard.dart' show lockGuard;
import '../qr_picture.dart';
import '../scan_corners.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/motion.dart' show houseSpring, motionStill;
import '../widgets/press_scale.dart';
import '../widgets/say.dart' show sayOnce;

/// how a new device's link code starts (engine/devices OfferPrefix)
const kLinkCodePrefix = 'kryfo-link:';

/// the middle of the camera image the reader decodes
const kReaderCrop = 0.9;

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
  // true: bridge lines, a plain one or the tor project's list, in place of
  // a kryfo link
  final bool bridges;
  // true: a new device's link code, in place of a kryfo link
  final bool link;
  const ScanScreen({super.key, this.bridges = false, this.link = false});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // zxing-cpp reads the frames. the controller arrives via onControllerCreated
  // and is only used for the torch.
  CameraController? _cam;
  bool _handled = false;
  bool _torchOn = false;
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
  // the corners and the frames that move them
  late final ScanCorners _corners = ScanCorners(onLock: _locked);
  late final Ticker _ticker = createTicker(_tick);
  Duration _lastTick = Duration.zero;
  // the kryfo code the corners follow, handed on at the lock
  String? _raw;
  Timer? _handOff;
  // a picture is being picked or read
  bool _picking = false;

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
    _checkCameras();
  }

  void _tick(Duration now) {
    final dt = (now - _lastTick).inMicroseconds / 1e6;
    _lastTick = now;
    _corners.advance(dt.clamp(0.0, 0.05));
    if (!_corners.moving) _ticker.stop();
  }

  // frames only while something moves: breathing, a glide, a pulse
  void _wake() {
    if (_ticker.isActive || !_corners.moving) return;
    _lastTick = Duration.zero;
    _ticker.start();
  }

  // the reader waits forever on a phone with no camera
  Future<void> _checkCameras() async {
    if (scanReaderForTest != null) return;
    try {
      if ((await availableCameras()).isEmpty) {
        _fail(
          onDesktop ? l10n.desktopNoCamera : l10n.cameraNoCameraOnThis,
          denied: false,
          again: false,
        );
      }
    } catch (_) {
      // windows has no camera plugin or reader library
      if (onDesktop) _fail(l10n.desktopNoCamera, denied: false, again: false);
    }
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
    _corners.failed = true;
    _ticker.stop();
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
      _corners.failed = false;
      _corners.restart();
      _wake();
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
    // the corners breathe only while the camera looks, and never with less
    // movement
    _corners.reduced = motionStill(context);
    _wake();
  }

  // where the code sits on the screen, from the reader's corner points.
  // null: the read has no position (then the lock is on the window)
  List<Offset>? _quadOf(Code code, Size view) {
    final pos = code.position;
    if (pos == null || pos.imageWidth <= 0 || pos.imageHeight <= 0) {
      return null;
    }
    final crop = readerCrop(pos.imageWidth, pos.imageHeight, kReaderCrop);
    final cam = _cam;
    final android = defaultTargetPlatform == TargetPlatform.android;
    final front = cam?.description.lensDirection == CameraLensDirection.front;
    double? preview;
    try {
      if (cam != null && cam.value.isInitialized) {
        preview = cam.value.aspectRatio;
      }
    } catch (_) {}
    return codeCornersInView(
      corners: [
        Offset(pos.topLeftX.toDouble(), pos.topLeftY.toDouble()),
        Offset(pos.topRightX.toDouble(), pos.topRightY.toDouble()),
        Offset(pos.bottomRightX.toDouble(), pos.bottomRightY.toDouble()),
        Offset(pos.bottomLeftX.toDouble(), pos.bottomLeftY.toDouble()),
      ],
      image: Size(pos.imageWidth.toDouble(), pos.imageHeight.toDouble()),
      view: view,
      cropLeft: crop.left,
      cropTop: crop.top,
      // the phone is held upright: android hands frames as the sensor sees
      turns: android && cam != null
          ? uprightTurns(
              sensor: cam.description.sensorOrientation,
              device: 0,
              front: front,
            )
          : 0,
      mirror: front,
      preview: android ? preview : null,
    );
  }

  bool _fits(String raw) => widget.bridges
      ? looksLikeBridges(raw)
      : widget.link
      ? raw.startsWith(kLinkCodePrefix)
      : raw.startsWith('kryfo://');

  String get _foreign => widget.bridges
      ? l10n.bridgesThatSNotABridge
      : widget.link
      ? l10n.scanLinkNotOne
      : l10n.scanThatSNotA;

  // the corners locked on the code: a light tap, a word for the screen
  // reader, then today's flow takes the code
  void _locked() {
    final raw = _raw;
    if (raw == null || !mounted) return;
    _handled = true;
    _hintOff?.cancel();
    HapticFeedback.lightImpact();
    sayOnce(context, l10n.scanQrFound);
    setState(() => _hint = null);
    _wake();
    _handOff = Timer(const Duration(milliseconds: 220), () {
      if (!mounted || !_inFront) return;
      Navigator.of(context).pop(raw);
    });
  }

  // a picture from the gallery: read here, never sent anywhere
  Future<void> _fromPicture() async {
    if (_handled || _picking) return;
    _picking = true;
    try {
      final bytes = await pickQrPicture();
      if (bytes == null || !mounted || _handled) return;
      final raw = await readQrPicture(bytes);
      if (!mounted || _handled) return;
      if (raw == null) {
        showHaloToast(context, l10n.scanPictureNoCode);
        return;
      }
      if (!_fits(raw)) {
        HapticFeedback.selectionClick();
        showHaloToast(
          context,
          widget.bridges || widget.link ? _foreign : l10n.scanPictureNotKryfo,
        );
        return;
      }
      _raw = raw;
      _corners.read(null);
    } finally {
      _picking = false;
    }
  }

  void _onScan(Code code) {
    if (_handled || !_inFront || _picking) return;
    final raw = code.text;
    if (raw == null || raw.isEmpty) return;
    if (!_fits(raw)) {
      // the warning stays while that code is in frame and goes a little
      // after it leaves
      _hintOff?.cancel();
      _hintOff = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _hint = null);
      });
      if (_hint == null) {
        HapticFeedback.selectionClick();
        setState(() => _hint = _foreign);
      }
      return;
    }
    // another kryfo code came into frame: the corners start over on it
    if (_raw != raw) _corners.restart();
    _raw = raw;
    _corners.read(_quadOf(code, MediaQuery.sizeOf(context)));
    _wake();
  }

  @override
  void dispose() {
    _unguard?.call();
    _hintOff?.cancel();
    _handOff?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _corners.dispose();
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

  String get _pictureLabel =>
      onDesktop ? l10n.scanChoosePicture : l10n.scanFromGallery;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boxSize = (size.width * 0.7).clamp(220.0, 320.0);
    _corners.layout(size, boxSize);
    // the camera under a dark mask, in both themes
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: haloOverlayOnDark,
      child: Scaffold(
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
                    cropPercent: kReaderCrop,
                    tryHarder: true,
                    tryInverted: true,
                    // the corners follow the code: reads come often, and a
                    // read does not pause the next one
                    scanDelay: const Duration(milliseconds: 60),
                    scanDelaySuccess: const Duration(milliseconds: 60),
                  ),
            // dim mask with an even-odd cutout, so the eye goes to the
            // viewfinder
            IgnorePointer(
              child: CustomPaint(
                size: size,
                painter: _MaskPainter(boxSize: boxSize),
              ),
            ),
            Positioned.fill(
              child: ScanFrame(corners: _corners, failed: _error != null),
            ),
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
                          widget.bridges
                              ? l10n.bridgesScanABridgeCode
                              : widget.link
                              ? l10n.scanLinkTitle
                              : l10n.scanScanAKryfoQr,
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
                            // no flash: leave the icon
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
            // the hint, or a short warning while a non-kryfo qr is in frame,
            // and under it the way to a picture
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _hintOrCard(),
                      if (qrPictureHere) ...[
                        const SizedBox(height: 12),
                        _PictureButton(
                          label: _pictureLabel,
                          onTap: _fromPicture,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hintOrCard() {
    return AnimatedSwitcher(
      duration: motionStill(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      child: _error != null
          ? _failCard()
          : Container(
              key: ValueKey(_hint ?? 'default'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                _hint ??
                    (widget.bridges
                        ? l10n.bridgesPointAtTheBridge
                        : widget.link
                        ? l10n.scanLinkPoint
                        : l10n.scanPointAtAKryfo),
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 12.5,
                  color: _hint != null ? HaloColors.amberText : Colors.white,
                ),
              ),
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

// the four corners, closing in on the house spring as the scanner opens.
// they fill the screen: once a code is found they leave the window for it
class ScanFrame extends StatefulWidget {
  final ScanCorners corners;
  // the camera would not open: dim corners, nothing moves
  final bool failed;
  const ScanFrame({super.key, required this.corners, this.failed = false});

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
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _in,
        builder: (_, child) {
          final v = _in.value;
          return Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: Transform.scale(scale: 1.14 - 0.14 * v, child: child),
          );
        },
        child: CustomPaint(
          painter: CornersPainter(
            widget.corners,
            // the app's accent, a darker amber in the light theme
            widget.failed ? HaloColors.line2 : HaloColors.amber,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// the corner arms: each runs along the code's edge, 16% of it, kept
/// between 14 and 26 px (26 on the window, as before)
class CornersPainter extends CustomPainter {
  final ScanCorners corners;
  final Color color;
  CornersPainter(this.corners, this.color) : super(repaint: corners);

  @override
  void paint(Canvas canvas, Size size) {
    final pts = corners.shown;
    final paint = Paint()
      ..color = color
      ..strokeWidth = corners.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 4; i++) {
      final p = pts[i], a = pts[(i + 3) % 4], b = pts[(i + 1) % 4];
      final la = (a - p).distance, lb = (b - p).distance;
      if (la == 0 || lb == 0) continue;
      final armA = (la * 0.16).clamp(14.0, 26.0);
      final armB = (lb * 0.16).clamp(14.0, 26.0);
      canvas.drawPath(
        Path()
          ..moveTo(
            p.dx + (a.dx - p.dx) / la * armA,
            p.dy + (a.dy - p.dy) / la * armA,
          )
          ..lineTo(p.dx, p.dy)
          ..lineTo(
            p.dx + (b.dx - p.dx) / lb * armB,
            p.dy + (b.dy - p.dy) / lb * armB,
          ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CornersPainter old) =>
      old.color != color || old.corners != corners;
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

// the way to a picture, under the hint: a quiet pill on the dark chrome,
// as wide as its words
class _PictureButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PictureButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      label: label,
      onTap: onTap,
      scale: 0.96,
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.photo_library_outlined,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: HaloType.sans(
                    size: 14,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
