// SPDX-License-Identifier: GPL-3.0-or-later
// words shared from another app, as home takes them: the lock first, then
// the forward picker, then the composer of the chat picked. nothing here
// sends, and what is not used is let go
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';
import '../lock_guard.dart';
import '../lock_state.dart';
import '../main.dart' show appState;
import '../share_text.dart';
import '../tools/tools_bridge.dart';
import '../voice_live.dart';
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

  // what this process is done with: a home made again can be offered one
  // it already let go
  static final _done = <String>{};

  bool _busy = false;
  BuildContext? _sheet;
  // a newer share came since the one about to show or showing
  bool _newer = false;
  // the home went, its navigator with it: what waited on it ends here
  final _gone = Completer<void>();

  ToolsBridge get _bridge => ToolsBridge.instance;

  void dispose() {
    if (!_gone.isCompleted) _gone.complete();
  }

  // [f], or [orElse] once the home is gone
  Future<T> _whileHere<T>(Future<T> f, T orElse) =>
      Future.any([f, _gone.future.then((_) => orElse)]);

  void _popSheet() {
    final s = _sheet;
    if (s != null && s.mounted && (ModalRoute.of(s)?.isCurrent ?? false)) {
      Navigator.of(s).pop();
    }
  }

  /// a share came in: a picker up or about to come up for an older one
  /// gives way
  void arrived(BuildContext context, bool Function() alive) {
    if (_busy) {
      _newer = true;
      _popSheet();
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
        final clear =
            s.words.isNotEmpty && await _whileHere(gate.clear(s), false);
        if (!alive()) return;
        if (!clear) {
          await _finish(s.id);
          continue;
        }
        // a voice note being recorded keeps the screen
        await _whileHere(voiceNotesDone(), null);
        // an unlock that opened another session builds another home
        await WidgetsBinding.instance.endOfFrame;
        if (!alive() || !context.mounted) return;
        _newer = false;
        // a newer one came while this one waited
        final now = await _bridge.peekSharedText();
        if (now?.id != s.id) continue;
        await _bridge.sawSharedText(s.id, _whereNow());
        if (!context.mounted) return;
        final id = await _whileHere(
          pickWordsChat(
            context,
            title: l10n.shareChooseChat,
            empty: appState.contacts.isEmpty
                ? l10n.shareNoChats
                : l10n.shareNoOne,
            dev: devForwardTarget,
            words: s.words,
            onSheet: (c) {
              _sheet = c;
              // one came before this sheet was up: it goes at once
              if (_newer) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _popSheet(),
                );
              }
            },
          ),
          null,
        );
        _sheet = null;
        if (!alive()) return;
        if (_newer) continue;
        await _finish(s.id);
        if (!context.mounted) return;
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
