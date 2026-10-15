// SPDX-License-Identifier: GPL-3.0-or-later
// what was picked, before it goes: the item large, a strip of all of them
// to switch, drop, add to or reorder, and a caption that rides on the
// first. nothing leaves until send is tapped; back sends nothing.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';

import '../album.dart' show kPickMax;
import '../bidi_safe.dart';
import '../l10n/l10n.dart';
import '../l10n/numbers.dart';
import '../main.dart' show appState;
import '../open_file.dart';
import '../picked.dart' show MediaSendResult, PickedMedia;
import '../theme.dart';
import '../widgets/decode_px.dart';
import '../widgets/motion.dart' show kHouseCurve, kHouseTime, motionStill;
import '../widgets/press_scale.dart';
import '../widgets/shift_tap_guard.dart';
import '../widgets/swap.dart';
import '../widgets/written_field.dart';

class MediaSendScreen extends StatefulWidget {
  final List<PickedMedia> items;
  // reopens the picker: what comes back joins the end
  final Future<List<PickedMedia>> Function()? addMore;
  // the protect switch and how it starts. null where the chat has none
  final bool? secure;
  // the chat blocks screenshots, so this screen does too
  final bool holdSecure;
  const MediaSendScreen({
    super.key,
    required this.items,
    this.addMore,
    this.secure,
    this.holdSecure = false,
  });
  @override
  State<MediaSendScreen> createState() => MediaSendScreenState();
}

class _Entry {
  final PickedMedia media;
  final Key key = UniqueKey();
  bool leaving = false;
  bool fresh;
  _Entry(this.media, {this.fresh = false});
}

class MediaSendScreenState extends State<MediaSendScreen> {
  late final List<_Entry> _items = [
    for (final m in widget.items.take(kPickMax)) _Entry(m),
  ];
  late final PageController _pages = PageController();
  final _caption = TextEditingController();
  int _at = 0;
  late bool _secure = widget.secure ?? false;
  bool _held = false;
  bool _adding = false;
  bool _done = false;

  /// what is in it now, in order
  List<PickedMedia> get items => [
    for (final e in _items)
      if (!e.leaving) e.media,
  ];

  List<_Entry> get _live => [
    for (final e in _items)
      if (!e.leaving) e,
  ];

  @override
  void initState() {
    super.initState();
    _hold(widget.holdSecure || _secure);
    // more picked than one send takes: the rest stays behind, and says so
    if (widget.items.length > kPickMax) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showHaloToast(context, l10n.mediaSendUpTo(whole(kPickMax)));
      });
    }
  }

  @override
  void dispose() {
    _hold(false);
    _pages.dispose();
    _caption.dispose();
    super.dispose();
  }

  void _hold(bool on) {
    if (on == _held) return;
    _held = on;
    unawaited(appState.forceSecure(on));
  }

  Duration get _move => motionStill(context) ? Duration.zero : kHouseTime;

  void _show(int i) {
    final live = _live;
    if (live.isEmpty) return;
    final to = i.clamp(0, live.length - 1);
    setState(() => _at = to);
    _moveTo(to, motionStill(context));
  }

  // after the frame that lays the pages out with what was added
  void _moveTo(int to, bool still) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients) return;
      if (still) {
        _pages.jumpToPage(to);
      } else {
        // no overshoot: a page that ends moving back snaps to the one before
        _pages.animateToPage(
          to,
          duration: kHouseTime,
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// drops the item at [i]; the last one gone closes the screen
  void remove(int i) {
    final live = _live;
    if (i < 0 || i >= live.length) return;
    HapticFeedback.selectionClick();
    final e = live[i];
    if (live.length == 1) {
      _cancel();
      return;
    }
    setState(() {
      e.leaving = true;
      if (_at >= live.length - 1) _at = live.length - 2;
    });
    if (_pages.hasClients) _pages.jumpToPage(_at);
    Future.delayed(_move, () {
      if (mounted) setState(() => _items.remove(e));
    });
  }

  Future<void> _more() async {
    final add = widget.addMore;
    if (add == null || _adding) return;
    _adding = true;
    try {
      final got = await add();
      if (!mounted || got.isEmpty) return;
      final room = kPickMax - _live.length;
      if (got.length > room) {
        showHaloToast(context, l10n.mediaSendUpTo(whole(kPickMax)));
      }
      final take = got.take(room.clamp(0, got.length)).toList();
      if (take.isEmpty) return;
      final first = _live.length;
      setState(() {
        _items.addAll([for (final m in take) _Entry(m, fresh: true)]);
      });
      _show(first);
    } finally {
      _adding = false;
    }
  }

  // [from] and [to] count every tile in the strip, one folding away too
  void _reorder(int from, int to) {
    if (to > from) to -= 1;
    final live = _live;
    final shown = live.isEmpty ? null : live[_at.clamp(0, live.length - 1)];
    setState(() {
      final e = _items.removeAt(from);
      _items.insert(to, e);
      if (shown != null) _at = _live.indexOf(shown);
    });
    if (_pages.hasClients) _pages.jumpToPage(_at);
  }

  void _toggleSecure() {
    HapticFeedback.selectionClick();
    setState(() => _secure = !_secure);
    _hold(widget.holdSecure || _secure);
    showHaloToast(
      context,
      _secure ? l10n.mediaSendProtectedOn : l10n.chatPhotoProtectionOff,
    );
  }

  void _cancel() {
    if (_done) return;
    _done = true;
    Navigator.of(context).pop();
  }

  void _send() {
    if (_done) return;
    final list = items;
    if (list.isEmpty) return;
    _done = true;
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(
      MediaSendResult(
        items: list,
        caption: _caption.text.trim(),
        secure: _secure,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final live = _live;
    final n = live.length;
    final current = n == 0 ? null : live[_at.clamp(0, n - 1)].media;
    final title = n > 1
        ? l10n.albumCounter(whole(_at + 1), whole(n))
        : current?.isVideo == true
        ? l10n.mediaSendVideo
        : l10n.mediaBubblesSendPhoto;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (popped, _) => _done = true,
      child: Scaffold(
        backgroundColor: HaloColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              _bar(title),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: n,
                  onPageChanged: (i) => setState(() => _at = i),
                  // keyed by the count too: the pages learn how many there
                  // are only when the one in view is put in again
                  itemBuilder: (_, i) => Padding(
                    key: ValueKey((live[i].key, n)),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: _Large(media: live[i].media),
                  ),
                ),
              ),
              if (n > 1 || widget.addMore != null) _strip(live),
              _composer(n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(String title) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 8, 4),
    child: Row(
      children: [
        IconButton(
          tooltip: l10n.commonBack,
          icon: Icon(Icons.close_rounded, color: HaloColors.text2, size: 24),
          onPressed: _cancel,
        ),
        Expanded(
          child: FadeSwap(
            child: Text(
              title,
              key: ValueKey(title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HaloType.serif(
                size: 16,
                italic: true,
                color: HaloColors.text,
              ),
            ),
          ),
        ),
        if (widget.secure != null)
          IconButton(
            tooltip: l10n.mediaSendProtect,
            isSelected: _secure,
            icon: Icon(
              _secure ? Icons.shield_rounded : Icons.shield_outlined,
              size: 22,
              color: _secure ? HaloColors.amber : HaloColors.text2,
            ),
            onPressed: _toggleSecure,
          ),
        IconButton(
          tooltip: l10n.mediaSendRemove,
          icon: Icon(
            Icons.delete_outline_rounded,
            size: 22,
            color: HaloColors.text2,
          ),
          onPressed: () => remove(_at),
        ),
      ],
    ),
  );

  Widget _strip(List<_Entry> live) {
    final shown = live.isEmpty ? null : live[_at.clamp(0, live.length - 1)];
    return SizedBox(
      height: 76,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        buildDefaultDragHandles: false,
        proxyDecorator: (child, _, _) =>
            Material(type: MaterialType.transparency, child: child),
        itemCount: _items.length,
        onReorder: _reorder,
        footer: widget.addMore == null || live.length >= kPickMax
            ? null
            : _AddTile(onTap: _more),
        itemBuilder: (_, i) {
          final e = _items[i];
          final at = live.indexOf(e);
          return ReorderableDelayedDragStartListener(
            key: e.key,
            index: i,
            enabled: !e.leaving,
            child: _Thumb(
              entry: e,
              selected: identical(e, shown),
              at: at,
              of: live.length,
              onTap: () => _show(live.indexOf(e)),
              onRemove: () => remove(live.indexOf(e)),
            ),
          );
        },
      ),
    );
  }

  Widget _composer(int n) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: Row(
      children: [
        Expanded(
          child: WrittenDir(
            controller: _caption,
            builder: (dir) => ShiftTapGuard(
              controller: _caption,
              child: TextField(
                textDirection: dir,
                inputFormatters: const [UnmarkedInput()],
                controller: _caption,
                style: HaloType.sans(size: 14),
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.mediaBubblesAddACaption,
                  hintStyle: HaloType.sans(size: 14, color: HaloColors.text2),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: HaloColors.surface2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        PressScale(
          label: l10n.commonSend,
          scale: 0.88,
          haptic: false,
          onTap: n == 0 ? null : _send,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HaloColors.amber,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_upward,
                  size: 20,
                  color: HaloColors.onAmber,
                ),
              ),
              if (n > 1)
                PositionedDirectional(
                  end: -4,
                  top: -4,
                  child: ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: HaloColors.surface,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: HaloColors.amber),
                      ),
                      child: Text(
                        whole(n),
                        style: HaloType.mono(
                          size: 10,
                          weight: FontWeight.w700,
                          color: HaloColors.amber,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

// the item large: a photo whole, a video by its first frame
class _Large extends StatelessWidget {
  final PickedMedia media;
  const _Large({required this.media});

  @override
  Widget build(BuildContext context) {
    final photo = media.photo;
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: photo != null
            ? Semantics(
                image: true,
                label: l10n.appPhoto,
                child: Image.memory(
                  photo,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  cacheWidth: screenPx(context),
                ),
              )
            : _VideoStill(path: media.video!.path, big: true),
      ),
    );
  }
}

class _VideoStill extends StatefulWidget {
  final String path;
  final bool big;
  const _VideoStill({required this.path, this.big = false});
  @override
  State<_VideoStill> createState() => _VideoStillState();
}

class _VideoStillState extends State<_VideoStill> {
  late VideoInfo? _info = videoInfoNow(widget.path);

  @override
  void initState() {
    super.initState();
    if (_info == null) {
      videoInfoFor(widget.path).then((i) {
        if (mounted && i != null) setState(() => _info = i);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = _info;
    final jpeg = i?.jpeg;
    final mark = widget.big ? 56.0 : 22.0;
    final face = jpeg == null
        ? ColoredBox(color: HaloColors.surface3)
        : Image.memory(jpeg, fit: BoxFit.cover, gaplessPlayback: true);
    return Semantics(
      image: true,
      label: l10n.videoBubbleVideo,
      child: AspectRatio(
        aspectRatio: widget.big ? (i?.aspect ?? 16 / 9).clamp(0.5, 2.4) : 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            face,
            Center(
              child: Container(
                width: mark,
                height: mark,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: mark * 0.66,
                  color: HaloColors.amber,
                ),
              ),
            ),
            if (widget.big && i != null && i.length > Duration.zero)
              PositionedDirectional(
                start: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    videoLength(i.length),
                    style: HaloType.mono(size: 10, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final _Entry entry;
  final bool selected;
  final int at;
  final int of;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _Thumb({
    required this.entry,
    required this.selected,
    required this.at,
    required this.of,
    required this.onTap,
    required this.onRemove,
  });

  static const size = 60.0;

  @override
  Widget build(BuildContext context) {
    final still = motionStill(context);
    final media = entry.media;
    final Widget face = media.photo != null
        ? Image.memory(
            media.photo!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: decodePx(context, size),
          )
        : _VideoStill(path: media.video!.path);
    final what = media.isVideo ? l10n.videoBubbleVideo : l10n.appPhoto;
    // a new one grows in, one dropped folds away
    final thumb = TweenAnimationBuilder<double>(
      tween: Tween(begin: entry.fresh && !still ? 0.0 : 1.0, end: 1.0),
      duration: still ? Duration.zero : kHouseTime,
      curve: kHouseCurve,
      onEnd: () => entry.fresh = false,
      builder: (_, grow, child) => Transform.scale(
        scale: 0.6 + 0.4 * grow.clamp(0.0, 1.2),
        child: Opacity(opacity: grow.clamp(0.0, 1.0), child: child),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: Semantics(
          button: true,
          selected: selected,
          label: '$what, ${l10n.albumCounter(whole(at + 1), whole(of))}',
          onTap: onTap,
          customSemanticsActions: {
            CustomSemanticsAction(label: l10n.mediaSendRemove): onRemove,
          },
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? HaloColors.amber : Colors.transparent,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: face,
                  ),
                  PositionedDirectional(
                    top: 0,
                    end: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onRemove,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(end: entry.leaving ? 0.0 : 1.0),
      duration: still ? Duration.zero : kHouseTime,
      curve: Curves.easeInOutCubic,
      builder: (_, f, child) => ClipRect(
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: f,
          child: Opacity(opacity: f, child: child),
        ),
      ),
      child: IgnorePointer(
        ignoring: entry.leaving,
        child: ExcludeSemantics(excluding: entry.leaving, child: thumb),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) => PressScale(
    label: l10n.mediaSendAddMore,
    scale: 0.92,
    onTap: onTap,
    child: Container(
      width: _Thumb.size,
      height: _Thumb.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: HaloColors.surface2,
        border: Border.all(color: HaloColors.amber.withValues(alpha: 0.5)),
      ),
      child: Icon(
        Icons.add_photo_alternate_outlined,
        size: 24,
        color: HaloColors.amber,
      ),
    ),
  );
}
