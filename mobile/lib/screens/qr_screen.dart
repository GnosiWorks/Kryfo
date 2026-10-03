// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../store.dart';
import '../theme.dart';
import '../tools/qr_payload.dart';
import '../tools/qr_png.dart';
import '../tools/tools_bridge.dart';
import '../widgets/ease_size.dart';
import '../widgets/motion.dart';
import '../widgets/press_scale.dart';
import '../widgets/qr_wipe.dart';
import '../widgets/stroke_icon.dart';
import '../widgets/swap.dart';
import '../widgets/tool_parts.dart';
import '../l10n/l10n.dart';
import '../lock_guard.dart' show LockDropped;

class _Field {
  final String id;
  final String label;
  final TextInputType keyboard;
  final bool secret;
  final bool plain;
  final int lines;
  final String hint;
  const _Field(
    this.id,
    this.label, {
    this.keyboard = TextInputType.text,
    this.secret = false,
    this.plain = false,
    this.lines = 1,
    this.hint = '',
  });
}

class _Kind {
  final QrKind kind;
  final String label;
  final List<String> icon;
  final String note;
  final List<_Field> fields;
  const _Kind(this.kind, this.label, this.icon, this.note, this.fields);
}

List<_Kind> get _kinds => [
  _Kind(
    QrKind.link,
    l10n.qrLink,
    [
      'M10 14a4.5 4.5 0 0 0 6.4 0l2.8-2.8a4.5 4.5 0 0 0-6.4-6.4L11.5 6',
      'M14 10a4.5 4.5 0 0 0-6.4 0l-2.8 2.8a4.5 4.5 0 0 0 6.4 6.4l1.3-1.2',
    ],
    l10n.qrYourLinkAsTyped,
    [
      _Field(
        'link',
        l10n.qrLink,
        keyboard: TextInputType.url,
        plain: true,
        hint: 'https://',
      ),
    ],
  ),
  _Kind(
    QrKind.text,
    l10n.qrText,
    ['M5 6h14', 'M5 11h14', 'M5 16h9'],
    l10n.qrStaysInTheCode,
    [_Field('text', l10n.qrText, keyboard: TextInputType.multiline, lines: 3)],
  ),
  _Kind(
    QrKind.wifi,
    l10n.qrWiFi,
    [
      'M3 9.5a13 13 0 0 1 18 0',
      'M6 13a8.5 8.5 0 0 1 12 0',
      'M9 16.5a4 4 0 0 1 6 0',
      'M12 19.6v.1',
    ],
    l10n.qrMadeOnThisPhone,
    [
      _Field('ssid', l10n.qrNetworkName, plain: true),
      _Field('password', l10n.qrPassword, secret: true, plain: true),
    ],
  ),
  _Kind(
    QrKind.contact,
    l10n.qrContact,
    [
      'M15.6 8.5a3.6 3.6 0 1 1-7.2 0 3.6 3.6 0 1 1 7.2 0z',
      'M5 19.5c1.3-3.4 4-4.9 7-4.9s5.7 1.5 7 4.9',
    ],
    l10n.qrOnlyWhatYouType,
    [
      _Field('name', l10n.qrName, keyboard: TextInputType.name, plain: true),
      _Field('phone', l10n.qrPhone, keyboard: TextInputType.phone),
      _Field(
        'email',
        l10n.qrEmail,
        keyboard: TextInputType.emailAddress,
        plain: true,
      ),
    ],
  ),
  _Kind(
    QrKind.email,
    l10n.qrEmail,
    ['M4 6.5h16v11H4z', 'M4.5 7l7.5 6 7.5-6'],
    l10n.qrOpensTheirMailApp,
    [
      _Field(
        'to',
        l10n.qrTo,
        keyboard: TextInputType.emailAddress,
        plain: true,
      ),
      _Field('subject', l10n.qrSubject),
    ],
  ),
  _Kind(
    QrKind.phone,
    l10n.qrPhone,
    [
      'M6.5 4h3l1.5 4-2 1.3a9 9 0 0 0 5.7 5.7l1.3-2 4 1.5v3a2 2 0 0 1-2 2A15 15 0 0 1 4.5 6a2 2 0 0 1 2-2z',
    ],
    l10n.qrANumberNothingElse,
    [_Field('number', l10n.qrNumber, keyboard: TextInputType.phone)],
  ),
  _Kind(
    QrKind.sms,
    l10n.qrSms,
    [
      'M4.5 6.8A2.8 2.8 0 0 1 7.3 4h9.4a2.8 2.8 0 0 1 2.8 2.8v6.4a2.8 2.8 0 0 1-2.8 2.8H11l-4.3 3.4V16a2.8 2.8 0 0 1-2.2-2.8z',
      'M8.5 10h.01',
      'M12 10h.01',
      'M15.5 10h.01',
    ],
    l10n.qrOpensTheirMessagesApp,
    [
      _Field('number', l10n.qrNumber, keyboard: TextInputType.phone),
      _Field('message', l10n.qrMessage, lines: 2),
    ],
  ),
  _Kind(
    QrKind.geo,
    l10n.qrLocation,
    [
      'M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z',
      'M14.3 10a2.3 2.3 0 1 1-4.6 0 2.3 2.3 0 1 1 4.6 0z',
    ],
    l10n.qrCoordinatesOnlyNoMap,
    [
      _Field(
        'lat',
        l10n.qrLatitude,
        keyboard: TextInputType.numberWithOptions(signed: true, decimal: true),
        hint: '52.52000',
      ),
      _Field(
        'lon',
        l10n.qrLongitude,
        keyboard: TextInputType.numberWithOptions(signed: true, decimal: true),
        hint: '13.40500',
      ),
    ],
  ),
  // the play build makes no payment codes
  if (!kPlayBuild)
    _Kind(
      QrKind.btc,
      l10n.qrBitcoin,
      [
        'M8 5h5.5a3 3 0 0 1 0 6H8z',
        'M8 11h6.5a3 3 0 0 1 0 6H8z',
        'M8 5v12',
        'M10 3v2',
        'M13 3v2',
        'M10 17v2',
        'M13 17v2',
      ],
      l10n.qrAddressAndAmountNo,
      [
        _Field('address', l10n.qrAddress, plain: true),
        _Field(
          'amount',
          l10n.qrAmountInBtc,
          keyboard: TextInputType.numberWithOptions(decimal: true),
          hint: '0.001',
        ),
      ],
    ),
];

const _shareIcon = [
  'M18 8a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
  'M6 14.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
  'M18 21a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z',
  'M8.2 10.8l7.6-4.1',
  'M8.2 13.2l7.6 4.1',
];
const _saveIcon = ['M12 4v11', 'M7.5 10.5L12 15l4.5-4.5', 'M5 19.5h14'];
const _eyeOn = [
  'M2.5 12s3.5-6.5 9.5-6.5 9.5 6.5 9.5 6.5-3.5 6.5-9.5 6.5S2.5 12 2.5 12z',
  'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
];
const _eyeOff = [
  'M3 3l18 18',
  'M10.6 5.7A9.5 9.5 0 0 1 12 5.5c6 0 9.5 6.5 9.5 6.5a15 15 0 0 1-3 3.7',
  'M6.5 7.5A15 15 0 0 0 2.5 12s3.5 6.5 9.5 6.5a9 9 0 0 0 3.6-.8',
];
final _copyIcon = [svgRect(8, 8, 11, 12, 2.5), 'M5 15V6a2 2 0 0 1 2-2h8'];

List<(String, Color)> get _inks => [
  (l10n.qrInk, HaloColors.qrInk),
  (l10n.qrAmber, HaloColors.qrAmber),
  (l10n.qrViolet, HaloColors.qrViolet),
];

class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  final Map<String, TextEditingController> _text = {};
  var _kindId = QrKind.link;
  _Kind get _kind => _kinds.firstWhere((k) => k.kind == _kindId);
  var _ink = 0;
  var _lock = WifiLock.wpa2;
  var _showSecret = false;
  var _busy = false;

  TextEditingController _ctl(_Kind k, _Field f) =>
      _text.putIfAbsent('${k.kind.name}.${f.id}', () {
        final c = TextEditingController();
        c.addListener(() => setState(() {}));
        return c;
      });

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  QrBuilt get _built => buildQr(_kind.kind, {
    for (final f in _kind.fields) f.id: _ctl(_kind, f).text,
  }, lock: _lock);

  Future<String?> _render(QrGrid g) async {
    final png = await renderQrPng(g, _inks[_ink].$2, HaloColors.qrPaper);
    if (png == null) return null;
    final cache = await getTemporaryDirectory();
    return writeQrPng(png, '${cache.path}/tools_out');
  }

  Future<void> _out(QrGrid g, {required bool save}) async {
    if (_busy) return;
    setState(() => _busy = true);
    String? said;
    try {
      final path = await _render(g);
      if (path == null) {
        said = l10n.qrCouldNotDrawThe;
      } else if (save) {
        final how = await ToolsBridge.instance.saveToGallery(
          path,
          'qr code.png',
          'image/png',
        );
        said = switch (how) {
          'saved' => l10n.qrSavedToYourGallery,
          'kept' => null,
          _ => l10n.qrCouldNotSaveIt,
        };
      } else {
        final ok = await ToolsBridge.instance.shareOut(path, 'image/png');
        if (!ok) said = l10n.qrNoAppOnThis;
      }
    } on LockDropped {
      // the session it was asked in is gone: nothing to say
      said = null;
    } catch (_) {
      said = l10n.qrCouldNotDrawThe;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (said != null) showHaloToast(context, said);
  }

  @override
  Widget build(BuildContext context) {
    final built = _built;
    final grid = built.data == null ? null : gridFor(built.data!);
    final tooLong = built.data != null && grid == null;
    final warn =
        built.problem ??
        (tooLong
            ? l10n.qrTooMuchForOne
            : grid != null && grid.dense
            ? l10n.qrThisIsALot
            : null);
    final ready = grid != null && built.problem == null;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ToolBar(title: l10n.qrPrivateQrCode),
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                        itemCount: _kinds.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => _Chip(
                          kind: _kinds[i],
                          on: _kinds[i].kind == _kindId,
                          onTap: () => setState(() {
                            _kindId = _kinds[i].kind;
                            _showSecret = false;
                          }),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Center(
                        child: _Card(
                          grid: ready ? grid : null,
                          ink: _inks[_ink].$2,
                          caption: built.caption,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.qrColour,
                            style: HaloType.sans(
                              size: 12,
                              color: HaloColors.warm,
                            ),
                          ),
                          const SizedBox(width: 6),
                          for (var i = 0; i < _inks.length; i++)
                            _Swatch(
                              name: _inks[i].$1,
                              color: _inks[i].$2,
                              on: i == _ink,
                              onTap: () => setState(() => _ink = i),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      // one field or three: the form eases to its new height
                      // so the buttons under it glide instead of jumping
                      child: EaseSize(
                        child: AnimatedSwitcher(
                          duration: motionStill(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOutCubic,
                          layoutBuilder: (now, before) => Stack(
                            alignment: Alignment.topCenter,
                            children: [...before, ?now],
                          ),
                          child: Column(
                            key: ValueKey(_kind.kind),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final f in _kind.fields) ...[
                                _Input(
                                  field: f,
                                  controller: _ctl(_kind, f),
                                  shown: _showSecret,
                                  onToggle: () => setState(
                                    () => _showSecret = !_showSecret,
                                  ),
                                  onCopy: () {
                                    final v = _ctl(_kind, f).text;
                                    if (v.isEmpty) return;
                                    copySensitive(v);
                                    showHaloToast(
                                      context,
                                      l10n.qrCopiedItLeavesThe,
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],
                              // a long word at a large text size wraps the pills
                              // onto a second line instead of overflowing
                              if (_kind.kind == QrKind.wifi)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: Text(
                                        l10n.qrSecurity,
                                        style: HaloType.sans(
                                          size: 12,
                                          color: HaloColors.warm,
                                        ),
                                      ),
                                    ),
                                    for (final (l, name) in [
                                      (WifiLock.wpa2, 'WPA2'),
                                      (WifiLock.wpa3, 'WPA3'),
                                      (WifiLock.none, l10n.qrNone),
                                    ])
                                      _Pill(
                                        label: name,
                                        on: _lock == l,
                                        onTap: () => setState(() => _lock = l),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // a warning or the kind's note, each rising in
                            // over the last
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: RiseSwap(
                                alignment: Alignment.center,
                                child: warn != null
                                    ? Text(
                                        warn,
                                        key: ValueKey(warn),
                                        textAlign: TextAlign.center,
                                        style: HaloType.sans(
                                          size: 13,
                                          height: 1.4,
                                          color: HaloColors.amber,
                                        ),
                                      )
                                    : Row(
                                        key: ValueKey(_kind.note),
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          BreathDot(
                                            color: HaloColors.green,
                                            size: 5,
                                            breaths: 3,
                                          ),
                                          const SizedBox(width: 7),
                                          Flexible(
                                            child: Text(
                                              _kind.note,
                                              textAlign: TextAlign.center,
                                              style: HaloType.mono(
                                                size: 9.5,
                                                letter: 0.1,
                                                color: HaloColors.green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: ToolWideButton(
                                    icon: _shareIcon,
                                    label: l10n.commonShare,
                                    height: 52,
                                    filled: true,
                                    onTap: ready && !_busy
                                        ? () => _out(grid, save: false)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ToolWideButton(
                                    icon: _saveIcon,
                                    label: l10n.qrSaveImage,
                                    height: 52,
                                    filled: false,
                                    onTap: ready && !_busy
                                        ? () => _out(grid, save: true)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final _Kind kind;
  final bool on;
  final VoidCallback onTap;
  const _Chip({required this.kind, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = on ? HaloColors.amber : HaloColors.warm;
    return Semantics(
      selected: on,
      child: PressScale(
        label: kind.label,
        onTap: onTap,
        scale: 0.96,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: on
                ? HaloColors.amber.withValues(alpha: 0.16)
                : HaloColors.amber.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              width: 0.5,
              color: on
                  ? HaloColors.amber.withValues(alpha: 0.4)
                  : HaloColors.line2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StrokeIcon(kind.icon, size: 17, color: fg),
              const SizedBox(width: 7),
              ExcludeSemantics(
                child: Text(
                  kind.label,
                  style: HaloType.sans(
                    size: 13,
                    weight: on ? FontWeight.w600 : FontWeight.w500,
                    color: fg,
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

class _Pill extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: on,
      child: PressScale(
        label: label,
        onTap: onTap,
        scale: 0.96,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? HaloColors.amber.withValues(alpha: 0.16) : null,
                borderRadius: BorderRadius.circular(999),
                border: on
                    ? null
                    : Border.all(color: HaloColors.line2, width: 0.5),
              ),
              child: ExcludeSemantics(
                child: Text(
                  label,
                  style: HaloType.sans(
                    size: 12,
                    weight: on ? FontWeight.w600 : FontWeight.w400,
                    color: on ? HaloColors.amber : HaloColors.warm,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final String name;
  final Color color;
  final bool on;
  final VoidCallback onTap;
  const _Swatch({
    required this.name,
    required this.color,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: on,
      child: PressScale(
        label: l10n.qrColour2(name),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: motionStill(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              width: on ? 32 : 26,
              height: on ? 32 : 26,
              padding: EdgeInsets.all(on ? 4 : 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  width: on ? 2 : 1,
                  color: on ? HaloColors.amber : HaloColors.line2,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final QrGrid? grid;
  final Color ink;
  final String caption;
  const _Card({required this.grid, required this.ink, required this.caption});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: -0.026 * (1 - t),
          child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        decoration: BoxDecoration(
          color: HaloColors.qrPaper,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: HaloColors.amber.withValues(alpha: 0.28),
              blurRadius: 50,
              spreadRadius: -24,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 212,
              height: 212,
              child: grid == null
                  ? Center(
                      child: Text(
                        l10n.qrTypeBelowAndThe,
                        textAlign: TextAlign.center,
                        style: HaloType.sans(
                          size: 13,
                          height: 1.4,
                          color: HaloColors.qrAmber,
                        ),
                      ),
                    )
                  // a code that appears assembles corner to corner
                  : Semantics(
                      label: l10n.qrQrCode,
                      image: true,
                      child: QrWipe(
                        child: CustomPaint(
                          size: const Size.square(212),
                          painter: _QrPainter(grid!, ink),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 212),
              child: Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HaloType.mono(
                  size: 10,
                  letter: 0.12,
                  weight: FontWeight.w500,
                  color: HaloColors.qrAmber,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  final QrGrid grid;
  final Color ink;
  const _QrPainter(this.grid, this.ink);

  @override
  void paint(Canvas canvas, Size size) =>
      paintQr(canvas, size.width, grid, ink);

  @override
  bool shouldRepaint(_QrPainter old) =>
      !identical(old.grid, grid) || old.ink != ink;
}

class _Input extends StatelessWidget {
  final _Field field;
  final TextEditingController controller;
  final bool shown;
  final VoidCallback onToggle;
  final VoidCallback onCopy;
  const _Input({
    required this.field,
    required this.controller,
    required this.shown,
    required this.onToggle,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
          child: ExcludeSemantics(
            child: Text(
              field.label,
              style: HaloType.sans(size: 12, color: HaloColors.warm),
            ),
          ),
        ),
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: HaloColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HaloColors.line2, width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: MergeSemantics(
                  child: Semantics(
                    label: field.label,
                    child: TextField(
                      controller: controller,
                      keyboardType: field.keyboard,
                      obscureText: field.secret && !shown,
                      // never offered to the phone's autofill service
                      autofillHints: null,
                      minLines: 1,
                      maxLines: field.secret ? 1 : field.lines,
                      autocorrect: !field.plain && !field.secret,
                      enableSuggestions: !field.plain && !field.secret,
                      enableIMEPersonalizedLearning: false,
                      textCapitalization: field.plain || field.secret
                          ? TextCapitalization.none
                          : TextCapitalization.sentences,
                      cursorColor: HaloColors.amber,
                      style: HaloType.sans(size: 14.5, color: HaloColors.text),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: field.hint.isEmpty ? null : field.hint,
                        hintStyle: HaloType.sans(
                          size: 14.5,
                          color: HaloColors.text3,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (field.secret) ...[
                PressScale(
                  label: shown ? l10n.qrHidePassword : l10n.qrShowPassword,
                  onTap: onToggle,
                  child: SizedBox(
                    width: 44,
                    height: 48,
                    child: Center(
                      child: StrokeIcon(
                        shown ? _eyeOff : _eyeOn,
                        size: 19,
                        color: HaloColors.warm,
                      ),
                    ),
                  ),
                ),
                PressScale(
                  label: l10n.qrCopyPassword,
                  onTap: onCopy,
                  child: SizedBox(
                    width: 44,
                    height: 48,
                    child: Center(
                      child: StrokeIcon(
                        _copyIcon,
                        size: 19,
                        color: HaloColors.warm,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
