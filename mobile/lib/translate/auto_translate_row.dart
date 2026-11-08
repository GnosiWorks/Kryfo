// SPDX-License-Identifier: GPL-3.0-or-later
// a chat's own switch for translating on its own, on the person's page.
// off unless the default in settings says otherwise.
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../widgets/halo_rows.dart';
import 'hub.dart';

class AutoTranslateRow extends StatefulWidget {
  final String chatId;
  final TranslationHub hub;
  const AutoTranslateRow({super.key, required this.chatId, required this.hub});

  @override
  State<AutoTranslateRow> createState() => _AutoTranslateRowState();
}

class _AutoTranslateRowState extends State<AutoTranslateRow> {
  // null until read, so the switch never opens on a default and slides
  bool? _on;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    await widget.hub.ready();
    final on = await widget.hub.chatAuto(widget.chatId);
    if (mounted) setState(() => _on = on);
  }

  @override
  Widget build(BuildContext context) {
    final on = _on ?? false;
    return HaloRow(
      icon: Icons.translate_rounded,
      label: l10n.translateAutoInChat,
      hint: l10n.translateAutoInChatHint,
      toggled: on,
      pending: _on == null,
      onTap: () async {
        setState(() => _on = !on);
        await widget.hub.setChatAuto(widget.chatId, !on);
      },
    );
  }
}
