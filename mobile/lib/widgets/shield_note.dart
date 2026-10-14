// SPDX-License-Identifier: GPL-3.0-or-later
// the scam shield's one line on a request: what it noticed and what to do,
// in the house notice on an amber tint. no alarm red. the cross folds it
// away for good.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../scam_shield.dart';
import '../theme.dart';
import 'burn_fade.dart' show FadeFold;
import 'notice_banner.dart';

class ShieldNote extends StatefulWidget {
  final ShieldFlag flag;
  // called once the note has folded: store the dismissal, drop the note
  final Future<void> Function() onDismiss;
  final Duration delay;
  final EdgeInsets margin;
  const ShieldNote({
    super.key,
    required this.flag,
    required this.onDismiss,
    this.delay = Duration.zero,
    this.margin = EdgeInsets.zero,
  });

  @override
  State<ShieldNote> createState() => _ShieldNoteState();
}

class _ShieldNoteState extends State<ShieldNote> {
  bool _leaving = false;

  Future<void> _dismiss() async {
    if (_leaving) return;
    HapticFeedback.selectionClick();
    setState(() => _leaving = true);
    await Future<void>.delayed(FadeFold.gone);
    await widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return FadeFold(
      leaving: _leaving,
      child: NoticeBanner(
        glyph: NoticeGlyph.shield,
        text: widget.flag.line,
        color: HaloColors.amber,
        textColor: HaloColors.text,
        delay: widget.delay,
        margin: widget.margin,
        onDismiss: _dismiss,
        dismissLabel: l10n.scamShieldDismiss,
      ),
    );
  }
}
