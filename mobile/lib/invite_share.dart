// SPDX-License-Identifier: GPL-3.0-or-later
// the invite as other messengers carry it: a kryfo:// link is not tappable in
// many of them and does nothing without the app, so the text holds an https
// page on our relay that opens Kryfo or says where to get it, and the
// download page. the page link carries the kryfo link's query after the '#',
// which a browser never sends, so the relay never sees the invite.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'desktop/desktop_mode.dart' show canShareOut;
import 'invites.dart' show isV4Link;
import 'l10n/app_locale.dart' show currentLanguage;
import 'l10n/l10n.dart';
import 'lock_state.dart';
import 'main.dart' show appState, AppStateSession;
import 'theme.dart';
import 'update_check.dart' show downloadPageFor;

const kInviteHost = 'relay.kryfo.app';
const _kryfoShare = 'kryfo://share?';
const _webShare = 'https://$kInviteHost/i#';

/// the invite page for a kryfo invite link, or null for anything else
String? webInviteOf(String kryfo) {
  if (!kryfo.startsWith(_kryfoShare)) return null;
  final q = kryfo.substring(_kryfoShare.length);
  if (q.isEmpty || q.contains(RegExp(r'[\s#]'))) return null;
  return '$_webShare$q';
}

/// [raw] with an invite page's link read as the kryfo link it opens, so a
/// whole pasted message reads as the old one did. anything else as it came
String kryfoInviteOf(String raw) =>
    raw.replaceAllMapped(_webInvite, (m) => '$_kryfoShare${m.group(1)}');

// only a link that starts a word: not one inside another url. '#' is what
// the app writes, '?' what earlier builds of 0.6 wrote. the bidi marks are
// the ones a right-to-left share text puts around the link
final _webInvite = RegExp(
  r'''(?<![^\s<(\["'\u200e\u200f\u2066-\u2069])'''
  r'https://relay\.kryfo\.app/i[#?]([A-Za-z0-9._~%+/=&-]+)',
  caseSensitive: false,
);

/// the text the share sheet carries: the name, the page, the download page,
/// and for a v4 link the line saying it needs 0.6 (0.5 reads it as invalid)
String inviteShareText(String id, String kryfo, {String? lang}) {
  final web = webInviteOf(kryfo) ?? kryfo;
  final text = l10n.inviteShareText(
    id,
    web,
    downloadPageFor(lang ?? currentLanguage),
  );
  return isV4Link(kryfo) ? '$text\n${l10n.inviteNeeds06}' : text;
}

/// the invite once the onion address is known: the first start may still be
/// making it. null when it is not there in [wait]
Future<String?> readyInvite({
  Duration wait = const Duration(seconds: 90),
}) async {
  if (appState.sessionOnion.isEmpty) {
    final done = Completer<void>();
    void on() {
      if (appState.sessionOnion.isNotEmpty && !done.isCompleted) {
        done.complete();
      }
    }

    appState.addListener(on);
    try {
      await done.future.timeout(wait);
    } on TimeoutException {
      return null;
    } finally {
      appState.removeListener(on);
    }
  }
  final uri = await appState.sessionInvite();
  return uri.startsWith(_kryfoShare) ? uri : null;
}

/// the share sheet with the invite text. false: nothing was handed on
@visibleForTesting
Future<bool> Function(String text, String subject) shareInviteText =
    (text, subject) async {
      if (!canShareOut) return false;
      final r = await lockState.hold(
        () =>
            SharePlus.instance.share(ShareParams(text: text, subject: subject)),
      );
      return r.status != ShareResultStatus.dismissed;
    };

/// builds the invite and opens the share sheet. false when it did not go
Future<bool> shareInvite(BuildContext context) async {
  if (!canShareOut) return false;
  HapticFeedback.selectionClick();
  final uri = await readyInvite();
  if (uri == null) {
    if (context.mounted) showHaloToast(context, l10n.inviteNotReady);
    return false;
  }
  return shareInviteText(
    inviteShareText(appState.sessionId, uri),
    l10n.myKryfoAddMeOnKryfo2,
  );
}
