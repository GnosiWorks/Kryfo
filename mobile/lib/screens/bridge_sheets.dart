// SPDX-License-Identifier: GPL-3.0-or-later
// the sheets around bridges: tor is blocked (with a yes to asking the tor
// project), the yes on its own, a friend's lines, and the country.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bidi_safe.dart';
import '../bridge_mode.dart';
import '../l10n/l10n.dart';
import '../lock_guard.dart' show lockGuard;
import '../lock_state.dart' show lockState;
import '../main.dart' hide live;
import '../stickers/sticker_bubble.dart' show StickerLibraryBuilder;
import '../stickers/sticker_pack.dart' show StickerRef;
import '../stickers/sticker_view.dart';
import '../theme.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/ease_size.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/motion.dart' show haloRoute;
import '../widgets/press_scale.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/swap.dart';
import 'scan_screen.dart';

// the onion from the fokia pack. it plays twice and rests; still when the
// phone asks for no movement
class _Fokia extends StatelessWidget {
  const _Fokia();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 88,
      child: StickerLibraryBuilder(
        builder: (lib, _) {
          final s = lib?.sticker(const StickerRef('fokia', 23));
          if (s == null) return const SizedBox(width: 88);
          return StickerView(sticker: s, size: 88, loops: 2, delay: 200);
        },
      ),
    ),
  );
}

Widget _sheetFrame(BuildContext ctx, List<Widget> children) => ShutOnLock(
  guard: lockGuard,
  child: SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [const SheetHandle(), const SizedBox(height: 6), ...children],
      ),
    ),
  ),
);

// what the tor project sees when asked, said calmly
Widget _seesNote() => Container(
  padding: const EdgeInsetsDirectional.fromSTEB(12, 11, 12, 12),
  decoration: BoxDecoration(
    color: HaloColors.violet.withValues(alpha: 0.09),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: HaloColors.violet.withValues(alpha: 0.28)),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.visibility_outlined, size: 16, color: HaloColors.violet),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          l10n.bridgesWhenYouAskFor,
          style: HaloType.sans(
            size: 12.5,
            color: HaloColors.text,
            height: 1.45,
          ),
        ),
      ),
    ],
  ),
);

Widget _quiet(String label, VoidCallback onTap) => PressScale(
  onTap: onTap,
  scale: 0.96,
  child: ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 46),
    child: Center(
      child: Text(
        label,
        style: HaloType.sans(size: 13.5, color: HaloColors.text2),
      ),
    ),
  ),
);

/// tor is blocked: one obvious way out, and what it shows the tor project.
/// [asked] is the one-time sheet automatic raised: a no there is final
Future<void> showTorBlockedSheet(
  BuildContext context, {
  bool asked = false,
}) async {
  final yes = await showHaloSheet<bool>(
    context,
    builder: (ctx) => _sheetFrame(ctx, [
      const Center(child: _Fokia()),
      const SizedBox(height: 10),
      Text(
        l10n.bridgesTorIsBlockedOnThis,
        textAlign: TextAlign.center,
        style: HaloType.serif(size: 22, color: HaloColors.text),
      ),
      const SizedBox(height: 8),
      Text(
        l10n.bridgesKryfoCanAskThe,
        textAlign: TextAlign.center,
        style: HaloType.sans(size: 14, color: HaloColors.text2, height: 1.45),
      ),
      const SizedBox(height: 14),
      _seesNote(),
      const SizedBox(height: 16),
      HaloPrimaryButton(
        label: l10n.bridgesGetABridge,
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.pop(ctx, true);
        },
      ),
      const SizedBox(height: 4),
      _quiet(l10n.bridgesNotNow, () => Navigator.pop(ctx, false)),
    ]),
  );
  // only a button is an answer. closed another way, the question stands;
  // shut by the lock, it comes back once the lock is open
  if (yes == null) {
    if (asked && lockState.locked) appState.bridgeAskAgain();
    return;
  }
  await appState.answerBridgeAsk(yes, asked: asked);
}

/// the yes to asking the tor project, from "more"
Future<void> showTorProjectConsentSheet(BuildContext context) async {
  final yes = await showHaloSheet<bool>(
    context,
    builder: (ctx) => _sheetFrame(ctx, [
      Text(
        l10n.bridgesAskTorProject,
        style: HaloType.serif(size: 22, color: HaloColors.text),
      ),
      const SizedBox(height: 8),
      Text(
        l10n.bridgesWhenTorIsBlockedAutomatic,
        style: HaloType.sans(size: 14, color: HaloColors.text2, height: 1.45),
      ),
      const SizedBox(height: 14),
      _seesNote(),
      const SizedBox(height: 16),
      HaloPrimaryButton(
        label: l10n.commonAllow,
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.pop(ctx, true);
        },
      ),
      const SizedBox(height: 4),
      _quiet(l10n.bridgesNotNow, () => Navigator.pop(ctx, false)),
    ]),
  );
  if (yes == true) await appState.setBridgeConsent(true);
}

/// the countries the tor project has advice for, its own guess marked
Future<String?> showCountrySheet(
  BuildContext context, {
  required String current,
  String? guess,
}) => showChoiceSheet<String>(
  context,
  title: l10n.bridgesCountry,
  line: l10n.bridgesTheTorProjectKnows,
  current: current,
  choices: [
    SheetChoice('', l10n.bridgesLetTheTorProject),
    // a guess the tor project has no advice for is still the person's
    for (final cc in [
      ...kBridgeCountries,
      if (guess != null && !kBridgeCountries.contains(guess)) guess,
    ])
      SheetChoice(
        cc,
        bridgeCountryName(cc),
        hint: cc == guess ? l10n.bridgesTheTorProjectSGuess : null,
      ),
  ],
);

/// a friend's lines: pasted or scanned, read by the engine, used at once
Future<void> showFriendLinesSheet(BuildContext context) => showHaloSheet<void>(
  context,
  builder: (_) => ShutOnLock(
    guard: lockGuard,
    child: _FriendSheet(host: context),
  ),
);

class _FriendSheet extends StatefulWidget {
  const _FriendSheet({required this.host});
  // the page under the sheet, where a note goes once it has closed
  final BuildContext host;

  @override
  State<_FriendSheet> createState() => _FriendSheetState();
}

class _FriendSheetState extends State<_FriendSheet> {
  late final _ctrl = TextEditingController(text: appState.bridge.friendLines)
    ..addListener(() => setState(() => _error = null));
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add(String text) {
    final got = bridgeLinesFrom(text);
    if (got.isEmpty) return;
    final have = _ctrl.text.trim();
    _ctrl.text = have.isEmpty ? got.join('\n') : '$have\n${got.join('\n')}';
  }

  // what came from the clipboard, so it can be cleared once used
  String? _pasted;

  Future<void> _paste() async {
    final d = await Clipboard.getData('text/plain');
    final t = d?.text;
    if (t == null || t.trim().isEmpty || !mounted) return;
    HapticFeedback.selectionClick();
    _pasted = t;
    _add(unmarked(t));
  }

  // a bridge line in the clipboard is a secret: gone once used, if the
  // clipboard still holds it, as copySensitive does
  Future<void> _clearPasted() async {
    final p = _pasted;
    if (p == null) return;
    try {
      final now = await Clipboard.getData(Clipboard.kTextPlain);
      if (now?.text == p) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } catch (_) {
      // nothing to clear here
    }
  }

  Future<void> _scan() async {
    final raw = await Navigator.of(
      context,
    ).push<String>(haloRoute<String>(const ScanScreen(bridges: true)));
    if (raw == null || !mounted) return;
    _add(unmarked(raw));
  }

  Future<void> _use() async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await appState.useFriendLines(_ctrl.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.used) {
      HapticFeedback.heavyImpact();
      setState(
        () => _error = r.tooLong
            ? l10n.bridgesThisLineIsTooLong
            : l10n.bridgesNoneOfTheseAre,
      );
      return;
    }
    HapticFeedback.mediumImpact();
    unawaited(_clearPasted());
    Navigator.of(context).pop();
    final host = widget.host;
    if (r.broken > 0 && host.mounted) {
      showHaloToast(host, l10n.bridgesKryfoCouldNotRead(r.broken));
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = bridgeLinesFrom(_ctrl.text).length;
    final err = _error;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 6),
            Text(
              l10n.bridgesBridgeFromAFriend,
              style: HaloType.serif(size: 22, color: HaloColors.text),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.bridgesPasteTheLineThey,
              style: HaloType.sans(
                size: 13.5,
                color: HaloColors.text2,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: HaloColors.surface3,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: err != null
                      ? HaloColors.rose.withValues(alpha: 0.6)
                      : HaloColors.line,
                ),
              ),
              // a keyboard that adds a space after each dot would break an
              // address, so it gets no say here
              child: TextField(
                controller: _ctrl,
                textDirection: TextDirection.ltr,
                minLines: 3,
                maxLines: 6,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                keyboardType: TextInputType.visiblePassword,
                textCapitalization: TextCapitalization.none,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                inputFormatters: const [UnmarkedInput()],
                style: HaloType.mono(size: 11.5, color: HaloColors.text),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: l10n.bridgesPasteABridgeLine,
                  // the line is left to right, the hint the app's way
                  hintTextDirection: Directionality.of(context),
                  hintStyle: HaloType.mono(size: 11.5, color: HaloColors.text2),
                ),
              ),
            ),
            EaseSize(
              child: err == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: RiseSwap(
                        child: Text(
                          err,
                          key: ValueKey(err),
                          style: HaloType.sans(
                            size: 12.5,
                            color: HaloColors.rose,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _Ghost(
                    icon: Icons.content_paste_rounded,
                    label: l10n.bridgesPasteFromClipboard,
                    onTap: _paste,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Ghost(
                    icon: Icons.qr_code_scanner_rounded,
                    label: l10n.bridgesScanACode,
                    onTap: _scan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            HaloPrimaryButton(
              label: n < 2
                  ? l10n.bridgesUseThisBridge
                  : l10n.bridgesUseTheseBridges(n),
              busy: _busy,
              onTap: n == 0 ? null : _use,
            ),
          ],
        ),
      ),
    );
  }
}

class _Ghost extends StatelessWidget {
  const _Ghost({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PressScale(
    scale: 0.96,
    onTap: onTap,
    label: label,
    child: Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: HaloColors.line2),
      ),
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: HaloColors.amber),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: HaloType.sans(
                  size: 13,
                  weight: FontWeight.w600,
                  color: HaloColors.amber,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
