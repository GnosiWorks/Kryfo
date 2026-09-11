// SPDX-License-Identifier: GPL-3.0-or-later
// the in-app camera. a photo taken for kryfo never exists outside kryfo:
// the plugin's temp file is read and shredded, the bytes are stripped of
// exif before anything else sees them, and only the stripped picture goes
// on to the chat. nothing lands in the camera roll unless the person asks
// for a copy. photo and video, front and back, flash. that is all.
import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../jpeg_strip.dart';
import '../main.dart' show shredFile, exportToPictures;
import '../theme.dart';
import '../widgets/press_scale.dart';

class CaptureResult {
  final Uint8List? photo; // stripped jpeg bytes
  final String? videoPath; // an mp4 in app-private storage, caller shreds
  const CaptureResult({this.photo, this.videoPath});
}

// where a recording waits between stop and send. app-private, swept at
// boot, so a force quit leaves nothing behind for long.
Future<Directory> capturesDir() async {
  final base = await getApplicationSupportDirectory();
  final d = Directory('${base.path}/captures');
  if (!await d.exists()) await d.create(recursive: true);
  return d;
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cams = const [];
  CameraController? _cam;
  int _which = 0;
  bool _video = false;
  bool _recording = false;
  bool _busy = false;
  FlashMode _flash = FlashMode.off;
  String? _error;
  bool _retried = false;
  // the review step
  Uint8List? _shot;
  String? _clip;
  int _clipBytes = 0;
  DateTime? _recStart;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  Future<void> _setup() async {
    try {
      _cams = await availableCameras();
      if (_cams.isEmpty) {
        setState(() => _error = 'no camera on this phone');
        return;
      }
      // back camera first
      _which = _cams.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_which < 0) _which = 0;
      await _open();
    } catch (e) {
      if (mounted) setState(() => _error = 'camera not available');
    }
  }

  Future<void> _open() async {
    final old = _cam;
    _cam = null;
    if (mounted) setState(() {});
    await old?.dispose();
    // the microphone is only asked for once someone switches to video. a
    // photo needs the camera and nothing else, and a second permission
    // prompt on the way to a photo is a surprise
    final c = CameraController(
      _cams[_which],
      ResolutionPreset.high,
      enableAudio: _video,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await c.initialize();
      await c.setFlashMode(_flash);
    } catch (e) {
      // the first open usually fails once, while the permission prompt is
      // still up. one quiet retry covers that; after it the line stays and
      // a tap tries again.
      if (!mounted) return;
      if (!_retried) {
        _retried = true;
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) await _open();
        return;
      }
      setState(() => _error = 'camera permission is off · tap to try again');
      return;
    }
    _error = null;
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() => _cam = c);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // let the camera go when the app is in the background; take it back on
    // return. a capture in flight is dropped, nothing of it is kept.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final c = _cam;
      _cam = null;
      final wasRecording = _recording;
      _recording = false;
      if (c != null) unawaited(_letGo(c, wasRecording));
    } else if (state == AppLifecycleState.resumed && _cam == null) {
      _open();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    // a clip that was never used is shredded on the way out
    final c = _clip;
    if (c != null) shredFile(c);
    super.dispose();
  }

  Future<void> _flip() async {
    if (_cams.length < 2 || _busy || _recording) return;
    HapticFeedback.selectionClick();
    _which = (_which + 1) % _cams.length;
    await _open();
  }

  Future<void> _cycleFlash() async {
    final c = _cam;
    if (c == null) return;
    HapticFeedback.selectionClick();
    final next = switch (_flash) {
      FlashMode.off => _video ? FlashMode.torch : FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      FlashMode.always => FlashMode.off,
      FlashMode.torch => FlashMode.off,
    };
    try {
      await c.setFlashMode(next);
      setState(() => _flash = next);
    } catch (_) {}
  }

  Future<void> _shutter() async {
    final c = _cam;
    if (c == null || _busy) return;
    if (_video) {
      await _toggleRecord(c);
      return;
    }
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      final x = await c.takePicture();
      final raw = await x.readAsBytes();
      // the plugin wrote a file with everything the sensor knows. it goes
      // now, and only the stripped bytes live on
      await shredFile(x.path);
      final clean = stripJpegMetadata(raw);
      if (!mounted) return;
      // a file the stripper could not walk, or one that still reads as
      // tagged, is refused rather than passed on
      setState(
        () => _shot = clean == null || jpegHasExif(clean) ? null : clean,
      );
      if (_shot == null) {
        showHaloToast(context, 'could not strip that photo, dropped it');
      }
    } catch (_) {
      if (mounted) showHaloToast(context, 'no photo came out');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // the plugin's clip is stopped and destroyed before the controller goes,
  // so nothing of an interrupted recording stays on disk
  Future<void> _letGo(CameraController c, bool recording) async {
    if (recording) {
      try {
        final x = await c.stopVideoRecording();
        await shredFile(x.path);
      } catch (_) {}
    }
    try {
      await c.dispose();
    } catch (_) {}
  }

  // video needs the microphone, which the photo controller never asked
  // for. reopen with audio, which is where the prompt appears
  Future<void> _toVideo() async {
    if (_video) return;
    setState(() => _video = true);
    _retried = false;
    await _open();
  }

  Future<void> _toggleRecord(CameraController c) async {
    if (!_recording) {
      try {
        await c.startVideoRecording();
        HapticFeedback.mediumImpact();
        setState(() {
          _recording = true;
          _recStart = DateTime.now();
        });
      } catch (_) {
        if (mounted) showHaloToast(context, 'could not start recording');
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final x = await c.stopVideoRecording();
      HapticFeedback.mediumImpact();
      // out of the plugin's cache and into our own private dir, then the
      // cache copy is gone
      final dir = await capturesDir();
      final dest = File(
        '${dir.path}/clip_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      await File(x.path).copy(dest.path);
      await shredFile(x.path);
      final len = await dest.length();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _clip = dest.path;
        _clipBytes = len;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _recording = false);
        showHaloToast(context, 'the recording was lost');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retake() async {
    HapticFeedback.selectionClick();
    final c = _clip;
    setState(() {
      _shot = null;
      _clip = null;
    });
    if (c != null) await shredFile(c);
  }

  Future<void> _keepCopy() async {
    HapticFeedback.selectionClick();
    final ts = DateTime.now().millisecondsSinceEpoch;
    bool ok;
    if (_shot != null) {
      ok = await exportToPictures(_shot!, 'kryfo_$ts.jpg', 'image/jpeg');
    } else if (_clip != null) {
      ok = await exportToPictures(
        await File(_clip!).readAsBytes(),
        'kryfo_$ts.mp4',
        'video/mp4',
      );
    } else {
      return;
    }
    if (!mounted) return;
    showHaloToast(
      context,
      ok ? 'a copy is in your photos' : 'could not save a copy on this phone',
    );
  }

  void _use() {
    HapticFeedback.mediumImpact();
    if (_shot != null) {
      Navigator.of(context).pop(CaptureResult(photo: _shot));
      return;
    }
    final c = _clip;
    if (c == null) return;
    if (_clipBytes > 8 * 1024 * 1024) {
      showHaloToast(context, 'too long for a message · 8 mb max');
      return;
    }
    // handed over: the caller shreds it once sent
    _clip = null;
    Navigator.of(context).pop(CaptureResult(videoPath: c));
  }

  @override
  Widget build(BuildContext context) {
    final reviewing = _shot != null || _clip != null;
    return Scaffold(
      backgroundColor: HaloColors.ink,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  color: HaloColors.surface,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: reviewing ? _review() : _live(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _video
                  ? 'never saved to your photos'
                  : 'no exif, never saved to your photos',
              style: HaloType.mono(
                size: 10.5,
                color: HaloColors.text2,
                letter: 0.06,
              ),
            ),
            const SizedBox(height: 14),
            reviewing ? _reviewBar() : _shutterBar(),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Widget _live() {
    final c = _cam;
    return Stack(
      key: const ValueKey('live'),
      fit: StackFit.expand,
      children: [
        if (_error != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _retried = true;
              _open();
            },
            child: Center(
              child: Text(
                _error!,
                style: HaloType.sans(size: 13, color: HaloColors.text2),
              ),
            ),
          )
        else if (c == null || !c.value.isInitialized)
          const SizedBox.shrink()
        else
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: c.value.previewSize?.height ?? 1,
              height: c.value.previewSize?.width ?? 1,
              child: CameraPreview(c),
            ),
          ),
        // top bar over the preview
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Row(
            children: [
              _round(Icons.close, 'close', () => Navigator.of(context).pop()),
              const Spacer(),
              if (_recording)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: HaloColors.rose.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'rec',
                    style: HaloType.mono(
                      size: 10,
                      color: HaloColors.text,
                      weight: FontWeight.w700,
                      letter: 0.1,
                    ),
                  ),
                ),
              const Spacer(),
              _round(_flashIcon(), 'flash', _cycleFlash),
              const SizedBox(width: 8),
              _round(Icons.cameraswitch_outlined, 'switch camera', _flip),
            ],
          ),
        ),
      ],
    );
  }

  IconData _flashIcon() => switch (_flash) {
    FlashMode.off => Icons.flash_off,
    FlashMode.auto => Icons.flash_auto,
    FlashMode.always => Icons.flash_on,
    FlashMode.torch => Icons.flashlight_on,
  };

  Widget _round(IconData icon, String label, VoidCallback onTap) => PressScale(
    label: label,
    onTap: onTap,
    scale: 0.88,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HaloColors.ink.withValues(alpha: 0.55),
      ),
      child: Icon(icon, size: 20, color: HaloColors.text),
    ),
  );

  Widget _review() {
    if (_shot != null) {
      return Image.memory(
        _shot!,
        key: const ValueKey('shot'),
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }
    final mb = (_clipBytes / (1024 * 1024)).toStringAsFixed(1);
    final secs = _recStart == null
        ? 0
        : DateTime.now().difference(_recStart!).inSeconds;
    return Center(
      key: const ValueKey('clip'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_outlined, size: 44, color: HaloColors.amber),
          const SizedBox(height: 12),
          Text(
            'clip · ${secs}s · $mb mb',
            style: HaloType.mono(size: 12, color: HaloColors.text2),
          ),
          if (_clipBytes > 8 * 1024 * 1024) ...[
            const SizedBox(height: 8),
            Text(
              'too long for a message · 8 mb max',
              style: HaloType.mono(size: 11, color: HaloColors.rose),
            ),
          ],
        ],
      ),
    );
  }

  Widget _shutterBar() {
    return Column(
      children: [
        // photo | video
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _modeTab('photo', !_video, () => setState(() => _video = false)),
            const SizedBox(width: 18),
            _modeTab('video', _video, _toVideo),
          ],
        ),
        const SizedBox(height: 16),
        PressScale(
          label: _video
              ? (_recording ? 'stop recording' : 'start recording')
              : 'take a photo',
          onTap: _shutter,
          scale: 0.9,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _recording ? HaloColors.rose : HaloColors.text,
                width: 3,
              ),
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: _recording ? 26 : 58,
                height: _recording ? 26 : 58,
                decoration: BoxDecoration(
                  color: _video
                      ? HaloColors.rose
                      : _busy
                      ? HaloColors.text2
                      : HaloColors.text,
                  borderRadius: BorderRadius.circular(_recording ? 6 : 999),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _modeTab(String label, bool on, VoidCallback onTap) => GestureDetector(
    onTap: _recording
        ? null
        : () {
            HapticFeedback.selectionClick();
            if (_flash == FlashMode.torch || _flash == FlashMode.auto) {
              _flash = FlashMode.off;
              _cam?.setFlashMode(FlashMode.off);
            }
            onTap();
          },
    behavior: HitTestBehavior.opaque,
    child: Text(
      label,
      style: HaloType.mono(
        size: 11,
        letter: 0.12,
        weight: FontWeight.w600,
        color: on ? HaloColors.amber : HaloColors.text3,
      ),
    ),
  );

  Widget _reviewBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _ghost('retake', _retake)),
              const SizedBox(width: 10),
              Expanded(child: _ghost('keep a copy', _keepCopy)),
            ],
          ),
          const SizedBox(height: 10),
          PressScale(
            onTap: _use,
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: HaloColors.amber,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                'use this',
                style: HaloType.sans(
                  size: 14,
                  weight: FontWeight.w600,
                  color: HaloColors.onAmber,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ghost(String label, VoidCallback onTap) => PressScale(
    onTap: onTap,
    child: Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: HaloColors.line),
      ),
      child: Text(
        label,
        style: HaloType.sans(size: 13, color: HaloColors.text),
      ),
    ),
  );
}
