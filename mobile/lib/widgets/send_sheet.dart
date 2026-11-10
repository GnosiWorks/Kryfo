// SPDX-License-Identifier: GPL-3.0-or-later
// what goes into a chat, in one sheet: photos and videos from the phone's
// own picker, files from its file browser, and files already in kryfo's
// chats. each pick is numbered in the order it was chosen, a caption goes
// with them, and "Send as file" sends photos and videos as they are, in
// full quality. every send is cleaned of what the camera wrote, as always.
// the pickers' copies are let go with the sheet, sent or not, and the lock
// closes it
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dlog.dart';
import '../file_kind.dart';
import '../l10n/dates.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart' show whole;
import '../lock_guard.dart' show LockGuard, lockGuard;
import '../theme.dart';
import 'ease_size.dart';
import 'file_badge.dart';
import 'file_bubble.dart' show fileNameDir;
import 'halo_sheet.dart';
import 'halo_switch.dart';
import 'media_bubbles.dart' show humanFileSize, splitFileName;
import 'motion.dart' show kHouseCurve, motionStill;
import 'pill_tabs.dart';
import 'press_scale.dart';
import 'sheet_handle.dart';

enum SendTab { gallery, files, recent }

/// one thing that may go: a pick's copy or a file already in a chat
class SendPick {
  final String path;
  final String name;
  final int size;
  final DateTime? when;
  // a photo or a video from the gallery: goes through the photo preview
  // unless it is sent as a file
  final bool media;
  final bool video;
  final SendTab from;
  // lets the pick's copy go; null for a file kryfo keeps itself
  final Future<void> Function()? release;
  // what the picker gave, for the photo preview
  final Object? source;
  const SendPick({
    required this.path,
    required this.name,
    required this.size,
    required this.from,
    this.when,
    this.media = false,
    this.video = false,
    this.release,
    this.source,
  });
}

class SendSheetResult {
  final List<SendPick> picks;
  final bool asFiles;
  final String caption;
  const SendSheetResult(this.picks, {this.asFiles = false, this.caption = ''});

  /// what goes through the photo preview, in order
  List<SendPick> get media => asFiles
      ? const []
      : [
          for (final p in picks)
            if (p.media) p,
        ];

  /// what goes as files, in order
  List<SendPick> get files => [
    for (final p in picks)
      if (asFiles || !p.media) p,
  ];

  /// the copies let go, once the chat is done with them
  Future<void> release() async {
    for (final p in picks) {
      await p.release?.call();
    }
  }
}

/// a quick way in from the gallery tab: the camera, a gif
class SendShortcut {
  final Widget Function(Color color) icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;
  const SendShortcut(this.icon, this.label, this.tint, this.onTap);
}

@visibleForTesting
LockGuard sendSheetGuard = lockGuard;

/// the clock the day lines read, fixed by the goldens
@visibleForTesting
DateTime Function() sendSheetNow = DateTime.now;

/// the sheet, up over the chat [to]. null when it was closed without a send
Future<SendSheetResult?> showSendSheet(
  BuildContext context, {
  required String to,
  required Future<List<SendPick>> Function() pickGallery,
  required Future<List<SendPick>> Function() pickFiles,
  required Future<List<SendPick>> Function() recent,
  List<SendShortcut> shortcuts = const [],
  SendTab start = SendTab.gallery,
  // the gallery tab's name: "Pictures" on a computer
  String? galleryLabel,
}) {
  HapticFeedback.selectionClick();
  return showHaloSheet<SendSheetResult>(
    context,
    scroll: true,
    builder: (ctx) => SendSheet(
      to: to,
      pickGallery: pickGallery,
      pickFiles: pickFiles,
      recent: recent,
      shortcuts: shortcuts,
      start: start,
      galleryLabel: galleryLabel,
    ),
  );
}

class SendSheet extends StatefulWidget {
  final String to;
  final Future<List<SendPick>> Function() pickGallery;
  final Future<List<SendPick>> Function() pickFiles;
  final Future<List<SendPick>> Function() recent;
  final List<SendShortcut> shortcuts;
  final SendTab start;
  final String? galleryLabel;
  const SendSheet({
    super.key,
    required this.to,
    required this.pickGallery,
    required this.pickFiles,
    required this.recent,
    this.shortcuts = const [],
    this.start = SendTab.gallery,
    this.galleryLabel,
  });

  @override
  State<SendSheet> createState() => SendSheetState();
}

class SendSheetState extends State<SendSheet> {
  late SendTab _tab = widget.start;
  final _gallery = <SendPick>[];
  final _files = <SendPick>[];
  List<SendPick>? _recent;
  // chosen, in the order chosen
  final _chosen = <SendPick>[];
  bool _asFiles = false;
  bool _picking = false;
  bool _sent = false;
  final _caption = TextEditingController();
  VoidCallback? _unguard;

  @visibleForTesting
  List<SendPick> get chosen => List.unmodifiable(_chosen);

  @override
  void initState() {
    super.initState();
    _unguard = sendSheetGuard.closeOnLock(() {
      _unguard = null;
      if (mounted) Navigator.of(context).maybePop();
    });
    widget.recent().then(
      (r) {
        if (mounted) setState(() => _recent = r);
      },
      onError: (Object e) {
        dlog('send sheet: recent not read (${e.runtimeType})');
        if (mounted) setState(() => _recent = const []);
      },
    );
  }

  @override
  void dispose() {
    _unguard?.call();
    _caption.dispose();
    // what was picked and not sent goes now
    if (!_sent) {
      for (final p in [..._gallery, ..._files]) {
        unawaited(p.release?.call());
      }
    }
    super.dispose();
  }

  Future<void> _pick(SendTab tab) async {
    if (_picking) return;
    _picking = true;
    try {
      final got = await (tab == SendTab.gallery
          ? widget.pickGallery()
          : widget.pickFiles());
      if (!mounted) {
        for (final p in got) {
          await p.release?.call();
        }
        return;
      }
      if (got.isEmpty) return;
      HapticFeedback.selectionClick();
      setState(() {
        (tab == SendTab.gallery ? _gallery : _files).addAll(got);
        _chosen.addAll(got);
      });
    } finally {
      _picking = false;
    }
  }

  void _toggle(SendPick p) {
    HapticFeedback.selectionClick();
    setState(() => _chosen.contains(p) ? _chosen.remove(p) : _chosen.add(p));
  }

  void _send() {
    if (_chosen.isEmpty) return;
    HapticFeedback.mediumImpact();
    // what was picked and not chosen goes now; the chosen go after the send
    for (final p in [..._gallery, ..._files]) {
      if (!_chosen.contains(p)) unawaited(p.release?.call());
    }
    _sent = true;
    Navigator.of(context).pop(
      SendSheetResult(
        List.of(_chosen),
        asFiles: _asFiles,
        caption: _caption.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final still = motionStill(context);
    final height = mq.size.height * 0.86;
    final anyMedia = _chosen.any((p) => p.media);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: l10n.sendSheetTo),
                              const TextSpan(text: ' '),
                              TextSpan(
                                text: widget.to,
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: HaloType.serif(
                            size: 22,
                            color: HaloColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.sendSheetCleaned,
                          style: HaloType.mono(
                            size: 10,
                            color: HaloColors.greenText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PillTabs(
                labels: [
                  widget.galleryLabel ?? l10n.chatGalleryShown,
                  l10n.sendSheetFiles,
                  l10n.sendSheetRecent,
                ],
                at: _tab.index,
                onTap: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _tab = SendTab.values[i]);
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                switchInCurve: kHouseCurve,
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.03),
                      end: Offset.zero,
                    ).animate(a),
                    child: c,
                  ),
                ),
                child: KeyedSubtree(key: ValueKey(_tab), child: _body()),
              ),
            ),
            _Foot(
              count: _chosen.length,
              showAsFiles: anyMedia,
              asFiles: _asFiles,
              onAsFiles: (v) => setState(() => _asFiles = v),
              caption: _caption,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (_tab) {
      case SendTab.gallery:
        return _list(
          head: [
            if (widget.shortcuts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    for (final s in widget.shortcuts)
                      Expanded(child: _Shortcut(s)),
                  ],
                ),
              ),
            _BigPick(
              icon: Icons.photo_library_outlined,
              label: l10n.sendSheetChoosePhotos,
              busy: _picking,
              onTap: () => _pick(SendTab.gallery),
            ),
          ],
          items: _gallery,
          empty: null,
        );
      case SendTab.files:
        return _list(
          head: [
            _BigPick(
              icon: Icons.folder_open_rounded,
              label: l10n.sendSheetBrowseFiles,
              busy: _picking,
              onTap: () => _pick(SendTab.files),
            ),
          ],
          items: _files,
          empty: null,
        );
      case SendTab.recent:
        final r = _recent;
        return _list(
          head: const [],
          items: r ?? const [],
          empty: r == null ? null : l10n.sendSheetNoRecent,
        );
    }
  }

  Widget _list({
    required List<Widget> head,
    required List<SendPick> items,
    required String? empty,
  }) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    children: [
      ...head,
      if (head.isNotEmpty && items.isNotEmpty) const SizedBox(height: 8),
      if (items.isEmpty && empty != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
          child: Text(
            empty,
            textAlign: TextAlign.center,
            style: HaloType.sans(size: 14, color: HaloColors.text),
          ),
        ),
      for (final p in items)
        _PickRow(pick: p, order: _chosen.indexOf(p), onTap: () => _toggle(p)),
    ],
  );
}

class _Shortcut extends StatelessWidget {
  final SendShortcut s;
  const _Shortcut(this.s);

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: s.label,
    excludeSemantics: true,
    child: PressScale(
      scale: 0.92,
      onTap: () {
        Navigator.of(context).pop();
        s.onTap();
      },
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: s.tint.withValues(alpha: 0.16),
            ),
            alignment: Alignment.center,
            child: s.icon(s.tint),
          ),
          const SizedBox(height: 6),
          Text(
            s.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: HaloType.sans(size: 12, color: HaloColors.text),
          ),
        ],
      ),
    ),
  );
}

class _BigPick extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onTap;
  const _BigPick({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: PressScale(
      scale: 0.98,
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: HaloColors.surface3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HaloColors.line),
        ),
        child: Row(
          children: [
            Icon(icon, color: HaloColors.amber, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: HaloType.sans(
                  size: 14.5,
                  weight: FontWeight.w600,
                  color: HaloColors.text,
                ),
              ),
            ),
            if (busy)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: HaloColors.amber,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// "today", "yesterday", or the day
String _whenLine(DateTime d) {
  final now = sendSheetNow();
  final day = DateTime(d.year, d.month, d.day);
  final today = DateTime(now.year, now.month, now.day);
  final n = today.difference(day).inDays;
  if (n == 0) return l10n.chatToday;
  if (n == 1) return l10n.chatYesterday;
  return dayMonthMaybeYear(d, now: now);
}

class _PickRow extends StatelessWidget {
  final SendPick pick;
  // its place among the chosen, -1 when it is not
  final int order;
  final VoidCallback onTap;
  const _PickRow({
    required this.pick,
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final facts = FileFacts(
      kindOfName(pick.name),
      extOf(safeFileName(pick.name)),
    );
    final shown = safeFileName(pick.name, facts: facts);
    final (stem, ext) = splitFileName(shown);
    final on = order >= 0;
    final sub = [
      humanFileSize(pick.size),
      if (pick.when != null) _whenLine(pick.when!),
    ].join(' · ');
    final nameStyle = HaloType.sans(
      size: 14,
      weight: FontWeight.w600,
      color: HaloColors.text,
    );
    return Semantics(
      button: true,
      selected: on,
      label: [
        shown,
        sub,
        if (on) l10n.sendSheetChosen(whole(order + 1)),
      ].join(', '),
      excludeSemantics: true,
      child: PressScale(
        scale: 0.98,
        haptic: false,
        onTap: onTap,
        child: AnimatedContainer(
          duration: still ? Duration.zero : const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
          decoration: BoxDecoration(
            color: on ? HaloColors.amberSoft : HaloColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: on ? HaloColors.amber : HaloColors.line,
              width: on ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              FileBadge(facts: facts, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: fileNameDir(stem),
                      children: [
                        Flexible(
                          child: Text(
                            stem,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: fileNameDir(stem),
                            style: nameStyle,
                          ),
                        ),
                        if (ext.isNotEmpty)
                          Text(
                            ext,
                            maxLines: 1,
                            textDirection: TextDirection.ltr,
                            style: nameStyle,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      maxLines: 2,
                      style: HaloType.mono(size: 10.5, color: HaloColors.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _Order(order: order),
            ],
          ),
        ),
      ),
    );
  }
}

/// the round mark of a pick: empty, or its number in the order chosen
class _Order extends StatelessWidget {
  final int order;
  const _Order({required this.order});

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final on = order >= 0;
    return AnimatedContainer(
      duration: still ? Duration.zero : const Duration(milliseconds: 180),
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? HaloColors.amber : Colors.transparent,
        border: Border.all(
          color: on ? HaloColors.amber : HaloColors.line2,
          width: 2,
        ),
      ),
      child: AnimatedSwitcher(
        duration: still ? Duration.zero : const Duration(milliseconds: 180),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: on
            ? Text(
                whole(order + 1),
                key: ValueKey(order),
                textScaler: TextScaler.noScaling,
                style: HaloType.mono(
                  size: 11.5,
                  weight: FontWeight.w700,
                  color: HaloColors.onAmber,
                ),
              )
            : const SizedBox.shrink(key: ValueKey(-1)),
      ),
    );
  }
}

class _Foot extends StatelessWidget {
  final int count;
  final bool showAsFiles;
  final bool asFiles;
  final ValueChanged<bool> onAsFiles;
  final TextEditingController caption;
  final VoidCallback onSend;
  const _Foot({
    required this.count,
    required this.showAsFiles,
    required this.asFiles,
    required this.onAsFiles,
    required this.caption,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context).bottom;
    return EaseSize(
      duration: const Duration(milliseconds: 240),
      alignment: Alignment.bottomCenter,
      child: count == 0
          ? SizedBox(width: double.infinity, height: pad + 8)
          : Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, pad + 12),
              decoration: BoxDecoration(
                color: HaloColors.surface,
                border: Border(top: BorderSide(color: HaloColors.line)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showAsFiles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MergeSemantics(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onAsFiles(!asFiles);
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.sendSheetAsFile,
                                      style: HaloType.sans(
                                        size: 14.5,
                                        weight: FontWeight.w600,
                                        color: HaloColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.sendSheetAsFileLine,
                                      style: HaloType.sans(
                                        size: 12.5,
                                        color: HaloColors.text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              HaloSwitch(value: asFiles, onChanged: onAsFiles),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: HaloColors.surface2,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: TextField(
                            controller: caption,
                            enableIMEPersonalizedLearning: false,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            style: HaloType.sans(
                              size: 14.5,
                              color: HaloColors.text,
                            ),
                            cursorColor: HaloColors.amber,
                            decoration: InputDecoration(
                              hintText: l10n.mediaBubblesAddACaption,
                              hintStyle: HaloType.sans(
                                size: 14.5,
                                color: HaloColors.text2,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Semantics(
                        button: true,
                        label: l10n.sendSheetSend(count, whole(count)),
                        excludeSemantics: true,
                        child: PressScale(
                          scale: 0.94,
                          haptic: false,
                          onTap: onSend,
                          child: Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: HaloColors.amber,
                              borderRadius: BorderRadius.circular(23),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n.sendSheetSend(count, whole(count)),
                                  style: HaloType.sans(
                                    size: 14.5,
                                    weight: FontWeight.w700,
                                    color: HaloColors.onAmber,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Directionality.of(context) ==
                                          TextDirection.rtl
                                      ? Icons.arrow_back_rounded
                                      : Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: HaloColors.onAmber,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
