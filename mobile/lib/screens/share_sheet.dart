// SPDX-License-Identifier: GPL-3.0-or-later
// words shared from another app, as home takes them: the lock first, then
// the forward picker, then the composer of the chat picked. nothing here
// sends, and what is not used is let go
import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';
import '../lock_guard.dart';
import '../lock_state.dart';
import '../share_text.dart';
import '../tools/tools_bridge.dart';
import 'dev_about_sheet.dart' show devForwardTarget;
import 'forward_sheet.dart';

class ShareTexts {
  ShareTexts({LockGuard? guard, String Function()? where})
    : gate = ShareGate(guard: guard ?? lockGuard, where: where ?? _where),
      _whereNow = where ?? _where;

  final ShareGate gate;
  final String Function() _whereNow;

  static String _where() =>
      shareSessionTag(decoy: lockState.inDecoy, vault: lockState.inVault);

  // what this process is done with: a screen rebuilt from an older saved
  // state can offer one again
  static final _done = <String>{};

  bool _busy = false;
  BuildContext? _sheet;
  bool _replaced = false;

  ToolsBridge get _bridge => ToolsBridge.instance;

  /// a share came in: a picker still up for an older one gives way
  void arrived(BuildContext context, bool Function() alive) {
    final s = _sheet;
    if (s != null && s.mounted && (ModalRoute.of(s)?.isCurrent ?? false)) {
      _replaced = true;
      Navigator.of(s).pop();
    }
    take(context, alive);
  }

  /// what waits is shown once it may be. [alive] is false once [context]'s
  /// screen is gone; a new home takes over from there
  Future<void> take(BuildContext context, bool Function() alive) async {
    if (_busy) return;
    _busy = true;
    try {
      while (alive()) {
        final s = await _bridge.peekSharedText();
        if (s == null) return;
        // let go already: dropped once more, never looped on
        if (_done.contains(s.id)) {
          await _bridge.dropSharedText(s.id);
          return;
        }
        if (s.words.isEmpty || !await gate.clear(s)) {
          await _finish(s.id);
          continue;
        }
        // an unlock that opened another session builds another home
        await WidgetsBinding.instance.endOfFrame;
        if (!alive() || !context.mounted) return;
        // a newer one came while this one waited
        final now = await _bridge.peekSharedText();
        if (now?.id != s.id) continue;
        await _bridge.sawSharedText(s.id, _whereNow());
        if (!context.mounted) return;
        _replaced = false;
        final id = await pickWordsChat(
          context,
          title: l10n.shareChooseChat,
          empty: l10n.shareNoChats,
          dev: devForwardTarget,
          words: s.words,
          onSheet: (c) => _sheet = c,
        );
        _sheet = null;
        if (_replaced) continue;
        await _finish(s.id);
        if (!context.mounted) return;
        // one that came while a held contact was asked about comes next
        if (id != null) await landWords(context, id, s.words);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _finish(String id) async {
    _done.add(id);
    await _bridge.dropSharedText(id);
  }
}
