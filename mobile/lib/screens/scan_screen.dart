// SPDX-License-Identifier: GPL-3.0-or-later
// in-app QR scanner. private - never leaves the app. focus on UX:
// dark masked viewfinder, animated scan line, success pulse on detect,
// torch toggle for low-light, and clear feedback when a non-kryfo qr
// is in frame.

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import '../theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  // zxing-cpp under the hood (FOSS) - the camera controller arrives via
  // onControllerCreated and is only used for the torch.
  CameraController? _cam;
  bool _handled = false;
  bool _torchOn = false;
  bool _detectedSuccess = false;
  String? _hint;
  DateTime? _hintAt;
  late final AnimationController _scanAnim;

  @override
  void initState() {
    super.initState();
    _scanAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  void _onScan(Code code) {
    if (_handled) return;
    final raw = code.text;
    if (raw == null || raw.isEmpty) return;
    if (!raw.startsWith('kryfo://')) {
      // brief hint and keep scanning. dedupe by time so the user isn't
      // spammed if many non-kryfo codes are in frame.
      final now = DateTime.now();
      if (_hintAt == null ||
          now.difference(_hintAt!) > const Duration(seconds: 2)) {
        setState(() {
          _hint = "that's not a kryfo qr · keep pointing";
          _hintAt = now;
        });
      }
      return;
    }
    _handled = true;
    setState(() => _detectedSuccess = true);
    // short success pulse before popping
    Future.delayed(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      Navigator.of(context).pop(raw);
    });
  }

  @override
  void dispose() {
    _scanAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boxSize = (size.width * 0.7).clamp(220.0, 320.0);
    return Scaffold(
      backgroundColor: HaloColors.ink,
      body: Stack(
        children: [
          ReaderWidget(
            onScan: _onScan,
            onControllerCreated: (controller, error) => _cam = controller,
            showScannerOverlay: false,
            showFlashlight: false,
            showGallery: false,
            showToggleCamera: false,
            // decode almost the whole frame (default crops to 50%, so a QR
            // that fills the screen spilled outside the box and wouldn't
            // lock without zooming out). tryHarder/tryInverted read it on
            // the first pass in poorer light.
            cropPercent: 0.9,
            tryHarder: true,
            tryInverted: true,
            scanDelay: const Duration(milliseconds: 500),
          ),
          // dim mask with a transparent cutout - uses a CustomPaint with
          // even-odd fill for the hole. saturated/dimmed outside the
          // viewfinder so the user's eye is drawn to the right area.
          IgnorePointer(
            child: CustomPaint(
              size: size,
              painter: _MaskPainter(boxSize: boxSize),
            ),
          ),
          // viewfinder frame (corner brackets + animated scan line)
          Center(
            child: _Viewfinder(
              size: boxSize,
              success: _detectedSuccess,
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
                padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        'scan a kryfo qr',
                        style: HaloType.serif(
                          size: 18,
                          italic: true,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
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
                  duration: const Duration(milliseconds: 220),
                  child: Container(
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
                      _hint ??
                          'point at a kryfo qr · nothing leaves your phone',
                      textAlign: TextAlign.center,
                      style: HaloType.sans(
                        size: 12.5,
                        color: _hint != null ? HaloColors.amber : Colors.white,
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

// the viewfinder frame: amber corner brackets + a moving horizontal
// scan line + a brief success flash when a kryfo qr is detected.
class _Viewfinder extends StatelessWidget {
  final double size;
  final bool success;
  final Animation<double> scanAnim;
  const _Viewfinder({
    required this.size,
    required this.success,
    required this.scanAnim,
  });

  @override
  Widget build(BuildContext context) {
    final accent = success ? HaloColors.green : HaloColors.amber;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // corner brackets - 4 L-shapes
          Positioned(left: 0, top: 0, child: _corner(accent, true, true)),
          Positioned(right: 0, top: 0, child: _corner(accent, false, true)),
          Positioned(left: 0, bottom: 0, child: _corner(accent, true, false)),
          Positioned(right: 0, bottom: 0, child: _corner(accent, false, false)),
          // scan line (hidden once success)
          if (!success)
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
                scale: success ? 1.0 : 0.4,
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
  bool shouldRepaint(_CornerPainter old) => false;
}
