// SPDX-License-Identifier: GPL-3.0-or-later
// "introduce <B> to..." - pick one accepted contact, add a line if you like,
// and both of them get the other's card. a bottom sheet, not a screen: it is
// one decision, made from inside a conversation.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../intro_budget.dart';
import '../main.dart' show appState;
import '../screens/home_screen.dart' show ContactPreview;
import '../theme.dart';
import '../vouch_text.dart';
import '../widgets/kryfo_avatar.dart';
import '../widgets/notice_banner.dart';

const _noteMax = 40;

Future<void> showIntroduceSheet(
  BuildContext context, {
  required String peerId,
  required String peerName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HaloColors.surface2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _IntroduceSheet(peerId: peerId, peerName: peerName),
  );
}

class _IntroduceSheet extends StatefulWidget {
  final String peerId;
  final String peerName;
  const _IntroduceSheet({required this.peerId, required this.peerName});
  @override
  State<_IntroduceSheet> createState() => _IntroduceSheetState();
}

class _IntroduceSheetState extends State<_IntroduceSheet> {
  final _noteCtrl = TextEditingController();
  String? _picked;
  IntroBudget? _budget;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    IntroBudget.load().then((b) {
      if (mounted) setState(() => _budget = b);
    });
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  List<ContactPreview> get _others => appState.contacts
      .where((c) => c.haloId != widget.peerId && !c.blocked)
      .toList();

  int get _now => DateTime.now().millisecondsSinceEpoch;
  int get _left => _budget?.leftAt(_now) ?? 0;
  bool get _canSend =>
      _picked != null && !_sending && _budget != null && _left > 0;

  String _nameOf(String id) {
    for (final c in appState.contacts) {
      if (c.haloId == id) return c.nickname ?? id;
    }
    return id;
  }

  Future<void> _go() async {
    final other = _picked;
    if (other == null || !_canSend) return;
    HapticFeedback.mediumImpact();
    setState(() => _sending = true);
    final r = await appState.introduce(
      widget.peerId,
      other,
      note: _noteCtrl.text.trim(),
    );
    if (!mounted) return;
    final any = r.toFirst || r.toSecond;
    if (any) {
      final b = _budget!.recordAt(_now);
      await b.save(_now);
      if (!mounted) return;
      _budget = b;
    }
    final b = widget.peerName;
    final c = _nameOf(other);
    if (r.toFirst && r.toSecond) {
      Navigator.of(context).pop();
      showHaloToast(context, 'introduced');
    } else if (any) {
      Navigator.of(context).pop();
      showHaloToast(
        context,
        r.toFirst
            ? '$b got it, but $c could not be reached'
            : '$c got it, but $b could not be reached',
      );
    } else {
      setState(() => _sending = false);
      showHaloToast(context, 'could not reach either of them. try again later');
    }
  }

  @override
  Widget build(BuildContext context) {
    final others = _others;
    final maxH = MediaQuery.of(context).size.height * 0.82;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: insets),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: HaloColors.line2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text(
                'introduce ${widget.peerName} to...',
                style: HaloType.serif(size: 20, color: HaloColors.text),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'both of them get the other\'s card. neither sees your name for the other.',
                style: HaloType.sans(
                  size: 12,
                  color: HaloColors.text2,
                  height: 1.5,
                ),
              ),
            ),
            Flexible(
              child: others.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Text(
                        'no one else to introduce yet. add another contact first.',
                        style: HaloType.sans(size: 13, color: HaloColors.text2),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: others.length,
                      itemBuilder: (_, i) {
                        final c = others[i];
                        return _FadeRight(
                          index: i,
                          child: _PickRow(
                            contact: c,
                            picked: _picked == c.haloId,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(
                                () => _picked = _picked == c.haloId
                                    ? null
                                    : c.haloId,
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
            Divider(color: HaloColors.line, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextField(
                controller: _noteCtrl,
                maxLength: _noteMax,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.none,
                style: HaloType.sans(size: 14, color: HaloColors.text),
                cursorColor: HaloColors.amber,
                decoration: InputDecoration(
                  hintText: 'a note, like "my cousin" - optional',
                  hintStyle: HaloType.serif(
                    size: 14,
                    italic: true,
                    color: HaloColors.text3,
                  ),
                  counterText: '',
                  suffixText: _noteCtrl.text.isEmpty
                      ? null
                      : '${_noteCtrl.text.length}/$_noteMax',
                  suffixStyle: HaloType.mono(size: 9, color: HaloColors.text3),
                  isDense: true,
                  filled: true,
                  fillColor: HaloColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            // the one warning there is. no approval step behind it, on
            // purpose: the introducer could forward an invite by hand today.
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _picked == null
                  ? const SizedBox(width: double.infinity, height: 0)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: NoticeBanner(
                        key: ValueKey(_picked),
                        glyph: NoticeGlyph.link,
                        text: shareWarning(widget.peerName, _nameOf(_picked!)),
                        color: HaloColors.amber,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: _GoButton(
                enabled: _canSend,
                sending: _sending,
                onTap: _go,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                14 + MediaQuery.of(context).padding.bottom,
              ),
              child: Center(child: _caption()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _caption() {
    final b = _budget;
    if (b == null) return const SizedBox(height: 14);
    final String text;
    final refill = b.refillAt(_now);
    if (refill == null) {
      text = '$_left of $introBudgetMax introductions left this week';
    } else {
      final until = Duration(milliseconds: refill - _now);
      text = 'no introductions left. next one frees up ${refillPhrase(until)}';
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        text,
        key: ValueKey(text),
        textAlign: TextAlign.center,
        style: HaloType.mono(
          size: 10,
          color: refill == null ? HaloColors.text3 : HaloColors.amber,
        ),
      ),
    );
  }
}

// one contact to pick. the face grows and gets an amber ring when chosen.
class _PickRow extends StatelessWidget {
  final ContactPreview contact;
  final bool picked;
  final VoidCallback onTap;
  const _PickRow({
    required this.contact,
    required this.picked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = contact.nickname;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            AnimatedScale(
              scale: picked ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: picked ? HaloColors.amber : Colors.transparent,
                    width: 1.6,
                  ),
                ),
                child: KryfoAvatar(
                  seed: contact.avatarSeed,
                  size: 38,
                  choice: contact.avatar,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name ?? contact.haloId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: name == null
                        ? HaloType.mono(
                            size: 12,
                            weight: FontWeight.w500,
                            color: HaloColors.text,
                          )
                        : HaloType.sans(
                            size: 14,
                            weight: FontWeight.w500,
                            color: HaloColors.text,
                          ),
                  ),
                  if (name != null)
                    Text(
                      contact.haloId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.mono(size: 10, color: HaloColors.text3),
                    ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: picked ? HaloColors.amber : Colors.transparent,
                border: Border.all(
                  color: picked ? HaloColors.amber : HaloColors.line2,
                  width: 1.4,
                ),
              ),
              alignment: Alignment.center,
              child: picked
                  ? Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: HaloColors.onAmber,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// primary amber button. dims when there is nothing to send, shows a small
// spinner while the two frames are out.
class _GoButton extends StatefulWidget {
  final bool enabled;
  final bool sending;
  final VoidCallback onTap;
  const _GoButton({
    required this.enabled,
    required this.sending,
    required this.onTap,
  });
  @override
  State<_GoButton> createState() => _GoButtonState();
}

class _GoButtonState extends State<_GoButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final on = widget.enabled;
    return GestureDetector(
      onTapDown: on ? (_) => setState(() => _down = true) : null,
      onTapUp: on ? (_) => setState(() => _down = false) : null,
      onTapCancel: on ? () => setState(() => _down = false) : null,
      onTap: on ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on || widget.sending
                ? HaloColors.amber
                : HaloColors.surface3,
            borderRadius: BorderRadius.circular(14),
          ),
          child: widget.sending
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: HaloColors.onAmber,
                  ),
                )
              : Text(
                  'introduce',
                  style: HaloType.sans(
                    size: 15,
                    weight: FontWeight.w600,
                    color: on ? HaloColors.onAmber : HaloColors.text3,
                  ),
                ),
        ),
      ),
    );
  }
}

// staggered slide in from the right, one row after the other.
class _FadeRight extends StatefulWidget {
  final int index;
  final Widget child;
  const _FadeRight({required this.index, required this.child});
  @override
  State<_FadeRight> createState() => _FadeRightState();
}

class _FadeRightState extends State<_FadeRight> {
  double _t = 0;
  @override
  void initState() {
    super.initState();
    final delay = 80 + (widget.index * 40).clamp(0, 360);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) setState(() => _t = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _t,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: Offset((1 - _t) * 0.06, 0),
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
