// SPDX-License-Identifier: GPL-3.0-or-later
// the update card over the chat list: a newer Kryfo is on the site. a tap
// opens the download page, the cross puts it away until the next version.
// nothing is downloaded or installed from here
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_locale.dart' show currentLanguage;
import '../l10n/l10n.dart';
import '../main.dart' show appState;
import '../open_outside.dart';
import '../theme.dart';
import '../update_check.dart';
import 'chat_parts.dart' show GrowSwap;
import 'motion.dart' show motionStill;
import 'press_scale.dart';

class UpdateCard extends StatelessWidget {
  final String version;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;
  const UpdateCard({
    super.key,
    required this.version,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final tint = HaloColors.green;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [tint.withValues(alpha: 0.16), tint.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Expanded(
            child: PressScale(
              label: '${l10n.updateAvailable}. ${l10n.updateReady(version)}',
              scale: 0.98,
              onTap: onOpen,
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 4, 12),
                  child: Row(
                    children: [
                      UpdateMark(color: tint),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.updateAvailable,
                              style: HaloType.sans(
                                size: 14.5,
                                weight: FontWeight.w600,
                                color: HaloColors.text,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              l10n.updateReady(version),
                              style: HaloType.sans(
                                size: 13,
                                color: HaloColors.warm,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          PressScale(
            label: l10n.homeNotNow,
            scale: 0.85,
            onTap: onDismiss,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(Icons.close_rounded, size: 18, color: tint),
            ),
          ),
        ],
      ),
    );
  }
}

/// an arrow that drops into its tray twice, then rests. at rest from the
/// start when the phone asks for no movement
class UpdateMark extends StatefulWidget {
  final Color color;
  const UpdateMark({super.key, required this.color});

  @override
  State<UpdateMark> createState() => _UpdateMarkState();
}

class _UpdateMarkState extends State<UpdateMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    value: 1,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (motionStill(context)) return;
    unawaited(_play());
  }

  Future<void> _play() async {
    for (var i = 0; i < 2 && mounted; i++) {
      try {
        await _c.forward(from: 0).orCancel;
      } on TickerCanceled {
        return;
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) =>
            CustomPaint(painter: _ArrowPainter(_c.value, widget.color)),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final double t;
  final Color color;
  _ArrowPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // the tray
    final tray = Path()
      ..moveTo(c.dx - 7, c.dy + 4)
      ..lineTo(c.dx - 7, c.dy + 7)
      ..lineTo(c.dx + 7, c.dy + 7)
      ..lineTo(c.dx + 7, c.dy + 4);
    canvas.drawPath(tray, p);
    // the arrow falls in from above, fading in as it comes
    final fall = Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
    final dy = (1 - fall) * -9;
    final a = Curves.easeOut.transform((t * 2.5).clamp(0.0, 1.0));
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    p.color = color.withValues(alpha: color.a * a);
    final top = c.dy - 8 + dy, tip = c.dy + 2 + dy;
    canvas.drawLine(Offset(c.dx, top), Offset(c.dx, tip), p);
    final head = Path()
      ..moveTo(c.dx - 4, tip - 4)
      ..lineTo(c.dx, tip)
      ..lineTo(c.dx + 4, tip - 4);
    canvas.drawPath(head, p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.t != t || old.color != color;
}

/// the card where the chat list wants it: there while [updateNotice] has a
/// version to show, and a check asked for whenever tor may have come up
class UpdateHint extends StatefulWidget {
  const UpdateHint({super.key});

  @override
  State<UpdateHint> createState() => _UpdateHintState();
}

class _UpdateHintState extends State<UpdateHint> with WidgetsBindingObserver {
  late final UpdateNotice _n = updateNotice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _n.addListener(_changed);
    appState.addListener(_poke);
    _poke();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _n.removeListener(_changed);
    appState.removeListener(_poke);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _poke();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _poke() => unawaited(_n.check());

  Future<void> _open() async {
    final url = downloadPageFor(currentLanguage);
    if (await openOutside(Uri.parse(url))) return;
    // no browser took it: the link goes on the clipboard instead
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) showHaloToast(context, l10n.settingsLinkCopied);
  }

  @override
  Widget build(BuildContext context) {
    final v = _n.shown;
    return GrowSwap(
      alignment: Alignment.topCenter,
      child: v == null
          ? const SizedBox(key: ValueKey('no-update'), width: 1)
          : UpdateCard(
              key: ValueKey('update-$v'),
              version: v,
              onOpen: _open,
              onDismiss: _n.dismiss,
            ),
    );
  }
}
