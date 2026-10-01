// SPDX-License-Identifier: GPL-3.0-or-later
// the in-app camera. a photo taken for kryfo never exists outside kryfo: the
// plugin's temp file is read and shredded, and only the stripped bytes go on
// to the chat. nothing lands in the camera roll unless the person asks.
import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../dlog.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../jpeg_strip.dart';
import '../main.dart' show shredFile, exportToPictures;
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import '../theme.dart';
import '../widgets/ease_size.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/motion.dart' show BreathDot, motionStill;
import '../widgets/press_scale.dart';
import '../widgets/swap.dart';
import '../widgets/decode_px.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../lock_guard.dart' show lockGuard;
import 'scan_screen.dart' show cameraDenied;

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
  // the error is a permission the app's settings can give back
  bool _denied = false;
  // only the microphone was refused, which a photo does not need
  bool _micOff = false;
  bool _retried = false;
  // the review step
  Uint8List? _shot;

  static const _platform = MethodChannel('halo/platform');
  Future<Uint8List> _shrink(Uint8List b) async {
    try {
      final r = await _platform.invokeMethod<Uint8List>('shrinkJpeg', {
        'bytes': b,
        'maxEdge': 1280,
        'quality': 70,
      });
      if (r != null && r.isNotEmpty) return r;
    } catch (e) {
      dlog('shrink: $e');
    }
    return b;
  }

  String? _clip;
  int _clipBytes = 0;
  // the clip's length in whole seconds, counted while it records
  int _recSecs = 0;
  Timer? _recTick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _unguard = lockGuard.closeOnLock(_closeForLock);
    _setup();
  }

  // the lock closes the camera: it never runs under the pin pad
  VoidCallback? _unguard;
  void _closeForLock() {
    _unguard = null;
    if (!mounted) return;
    final r = ModalRoute.of(context);
    if (r != null && r.isActive) Navigator.of(context).removeRoute(r);
  }

  Future<void> _setup() async {
    try {
      _cams = await availableCameras();
      if (_cams.isEmpty) {
        setState(() {
          _error = l10n.cameraNoCameraOnThis;
          _denied = false;
          _micOff = false;
        });
        return;
      }
      // back camera first
      _which = _cams.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_which < 0) _which = 0;
      await _open();
    } catch (e) {
      if (mounted) setState(() => _error = l10n.cameraCameraNotAvailable);
    }
  }

  Future<void> _open() async {
    // the lock can go up in the same resume that reopens the camera, and
    // the camera may not run under it
    if (lockGuard.isLocked()) return;
    final old = _cam;
    _cam = null;
    if (mounted) setState(() {});
    // the old picture fades to dark while it still runs, then lets go
    if (old != null && mounted && !motionStill(context)) {
      await Future.delayed(const Duration(milliseconds: 240));
    }
    await old?.dispose();
    if (!mounted || lockGuard.isLocked()) return;
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
      final denied = cameraDenied(e);
      final mic = denied && (e as CameraException).code.startsWith('Audio');
      setState(() {
        _denied = denied;
        _micOff = mic;
        _error = !denied
            ? l10n.cameraCameraNotAvailable
            : mic
            ? l10n.chatMicPermissionNeeded
            : l10n.cameraCameraPermissionIsOff;
      });
      return;
    }
    _error = null;
    _denied = false;
    _micOff = false;
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
      _recTick?.cancel();
      if (c != null) unawaited(_letGo(c, wasRecording));
    } else if (state == AppLifecycleState.resumed && _cam == null) {
      _open();
    }
  }

  @override
  void dispose() {
    _unguard?.call();
    _recTick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    // a clip that was never used is shredded on the way out
    final c = _clip;
    if (c != null) shredFile(c);
    super.dispose();
  }

  Future<void> _flip() async {
    // nothing to flip while the last switch is still opening
    if (_cams.length < 2 || _busy || _recording || _cam == null) return;
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
    } catch (e) {
      dlog('camera: flash refused: $e');
    }
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
      // the shrink first, on the raw bytes: it turns the pixels upright from
      // the orientation tag and writes a jpeg with no tags at all. the strip
      // after it is the belt to that brace. same size and quality as a
      // gallery pick.
      final small = await _shrink(raw);
      final stripped = stripJpegMetadata(small);
      final clean = stripped;
      if (!mounted) return;
      // a file the stripper could not walk, or one that still reads as
      // tagged, is refused rather than passed on
      setState(
        () => _shot = clean == null || jpegHasExif(clean) ? null : clean,
      );
      if (_shot == null) {
        showHaloToast(context, l10n.cameraCouldNotStripThat);
      }
    } catch (_) {
      if (mounted) showHaloToast(context, l10n.cameraNoPhotoCameOut);
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
      } catch (e) {
        dlog('camera: interrupted clip: $e');
      }
    }
    try {
      await c.dispose();
    } catch (e) {
      dlog('camera: dispose: $e');
    }
  }

  // video needs the microphone, which the photo controller never asked
  // for. reopen with audio, which is where the prompt appears
  Future<void> _toVideo() async {
    if (_video) return;
    setState(() => _video = true);
    _retried = false;
    await _open();
  }

  // a refused microphone only stops video. back on photo the camera opens
  // again without audio
  Future<void> _toPhoto() async {
    if (!_video) return;
    final reopen = _micOff;
    setState(() {
      _video = false;
      if (reopen) {
        _error = null;
        _micOff = false;
      }
    });
    if (reopen) await _open();
  }

  Future<void> _toggleRecord(CameraController c) async {
    if (!_recording) {
      try {
        await c.startVideoRecording();
        HapticFeedback.mediumImpact();
        setState(() {
          _recording = true;
          _recSecs = 0;
        });
        _recTick?.cancel();
        _recTick = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recSecs++);
        });
      } catch (_) {
        if (mounted) showHaloToast(context, l10n.cameraCouldNotStartRecording);
      }
      return;
    }
    setState(() => _busy = true);
    _recTick?.cancel();
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
        showHaloToast(context, l10n.cameraTheRecordingWasLost);
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
      ok ? l10n.cameraACopyIsIn : l10n.cameraCouldNotSaveA,
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
      showHaloToast(context, l10n.cameraTooLongForA);
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
              // the margin sits outside the clip, so all four corners round
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: ColoredBox(
                    color: HaloColors.surface,
                    child: FadeSwap(child: reviewing ? _review() : _live()),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _video
                  ? l10n.cameraNeverSavedToYour
                  : l10n.cameraNoExifNeverSaved,
              style: HaloType.mono(
                size: 10.5,
                color: HaloColors.text2,
                letter: 0.06,
              ),
            ),
            const SizedBox(height: 14),
            // the bars cross with the picture above them
            EaseSize(
              child: FadeSwap(
                child: reviewing
                    ? KeyedSubtree(
                        key: const ValueKey('review'),
                        child: _reviewBar(),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('shutter'),
                        child: _shutterBar(),
                      ),
              ),
            ),
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
        // a flip, a switch to video or a return to the app fades through
        // dark instead of cutting to an empty box
        FadeSwap(
          child: _error != null
              ? KeyedSubtree(key: const ValueKey('error'), child: _failed())
              : c == null || !c.value.isInitialized
              ? ColoredBox(
                  key: const ValueKey('dark'),
                  // dark in both themes, like the preview it stands in for
                  color: Colors.black,
                  child: const SizedBox.expand(),
                )
              : FittedBox(
                  key: ObjectKey(c),
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: c.value.previewSize?.height ?? 1,
                    height: c.value.previewSize?.width ?? 1,
                    child: CameraPreview(c),
                  ),
                ),
        ),
        // top bar over the preview
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Row(
            children: [
              _round(
                Icons.close,
                l10n.cameraClose,
                () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              FadeSwap(
                child: _recording
                    ? _recPill()
                    : const SizedBox.shrink(key: ValueKey('idle')),
              ),
              const Spacer(),
              _round(_flashIcon(), l10n.cameraFlash, _cycleFlash),
              const SizedBox(width: 8),
              _round(
                Icons.cameraswitch_outlined,
                l10n.cameraSwitchCamera,
                _flip,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // a breathing dot and the running time, so a long clip is no surprise
  Widget _recPill() {
    final t = _recSecs;
    return Semantics(
      key: const ValueKey('rec'),
      label: l10n.cameraRec,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(9, 5, 11, 5),
        decoration: BoxDecoration(
          color: HaloColors.ink.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BreathDot(color: HaloColors.rose, size: 8),
            const SizedBox(width: 7),
            Text(
              '${whole(t ~/ 60)}:${twoDigits(t % 60)}',
              style: HaloType.mono(
                size: 12,
                color: HaloColors.text,
                weight: FontWeight.w600,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }

  // what went wrong, and a way out: try again, or the app's settings when
  // a permission is off
  Widget _failed() {
    final again = _cams.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography_outlined,
              size: 30,
              color: HaloColors.amber,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: HaloType.sans(size: 14, color: HaloColors.text),
            ),
            if (again) ...[
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_denied) ...[
                      HaloPrimaryButton(
                        label: l10n.cameraOpenSettings,
                        onTap: openAppSettings,
                      ),
                      const SizedBox(height: 8),
                    ],
                    HaloGhostButton(
                      label: l10n.commonTryAgain,
                      quiet: _denied,
                      onTap: _tryAgain,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _tryAgain() {
    _retried = true;
    setState(() => _error = null);
    _open();
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
        cacheWidth: screenPx(context),
      );
    }
    final mb = decimal(_clipBytes / (1024 * 1024), 1);
    final secs = _recSecs;
    return Center(
      key: const ValueKey('clip'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_outlined, size: 44, color: HaloColors.amber),
          const SizedBox(height: 12),
          Text(
            l10n.cameraClipSMb(whole(secs), mb),
            style: HaloType.mono(size: 12, color: HaloColors.text2),
          ),
          if (_clipBytes > 8 * 1024 * 1024) ...[
            const SizedBox(height: 8),
            Text(
              l10n.cameraTooLongForA,
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
            _modeTab(l10n.cameraPhoto, !_video, _toPhoto),
            const SizedBox(width: 8),
            _modeTab(l10n.cameraVideo, _video, _toVideo),
          ],
        ),
        const SizedBox(height: 6),
        PressScale(
          label: _video
              ? (_recording
                    ? l10n.cameraStopRecording
                    : l10n.cameraStartRecording)
              : l10n.cameraTakeAPhoto,
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

  // a full-height target, the colour eases and a short amber line grows
  // under the chosen one
  Widget _modeTab(String label, bool on, VoidCallback onTap) {
    final d = motionStill(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    // one node: the name, a button, chosen or not
    return Semantics(
      container: true,
      button: true,
      selected: on,
      label: label,
      child: PressScale(
        scale: 0.94,
        onTap: _recording
            ? null
            : () {
                if (_flash == FlashMode.torch || _flash == FlashMode.auto) {
                  _flash = FlashMode.off;
                  _cam?.setFlashMode(FlashMode.off);
                }
                onTap();
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedDefaultTextStyle(
                  duration: d,
                  curve: Curves.easeOutCubic,
                  style: HaloType.mono(
                    size: 11,
                    letter: 0.12,
                    weight: FontWeight.w600,
                    color: on ? HaloColors.amber : HaloColors.text2,
                  ),
                  child: ExcludeSemantics(child: Text(label)),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: d,
                  curve: Curves.easeOutCubic,
                  width: on ? 16 : 0,
                  height: 2,
                  decoration: BoxDecoration(
                    color: HaloColors.amber,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reviewBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _ghost(l10n.cameraRetake, _retake)),
              const SizedBox(width: 10),
              Expanded(child: _ghost(l10n.cameraKeepACopy, _keepCopy)),
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
                l10n.cameraUseThis,
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
