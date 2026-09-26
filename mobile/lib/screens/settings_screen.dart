// SPDX-License-Identifier: GPL-3.0-or-later
// user-facing settings. the dev screen keeps the technical ones.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show appState, session;
import '../lock_state.dart';
import '../intro_prefs.dart';
import '../scam_prefs.dart';
import '../miui_autostart.dart';
import '../widgets/motion.dart' show haloRoute;
import 'why_kryfo_screen.dart';
import 'transport_screen.dart';
import 'bridges_screen.dart';
import 'seen_screen.dart';
import '../theme.dart';
import '../notif_permission.dart';
import 'modes_screen.dart';
import 'blocked_screen.dart';
import 'pins_screen.dart';
import 'backup_screen.dart';
import '../wipe.dart';
import 'restore_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../notifications.dart';
import '../delivery_mode.dart';
import 'getting_messages_screen.dart';
import '../widgets/halo_rows.dart';
import '../widgets/stagger_in.dart';
import '../widgets/confirm_sheet.dart';
import '../l10n/l10n.dart';
import '../widgets/language_sheet.dart';
import '../wipe_word.dart';

Widget _postureLine(String label, bool on, String onText, String offText) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            on ? Icons.check_circle : Icons.radio_button_unchecked,
            key: ValueKey(on),
            size: 16,
            color: on ? HaloColors.amber : HaloColors.text3,
          ),
        ),
        const SizedBox(width: 10),
        // the label wraps and the state keeps its place: in a long language
        // at a big font size the two do not fit one line
        Expanded(
          child: Text(
            label,
            style: HaloType.sans(size: 13, color: HaloColors.text),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 240),
          style: HaloType.mono(
            size: 10,
            color: on ? HaloColors.amber : HaloColors.text3,
          ),
          child: Text(on ? onText : offText),
        ),
      ],
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _hidePreview;
  Future<void> _confirmWipe() async {
    // step 1: explain what's about to happen
    final go = await showConfirmSheet(
      context,
      title: l10n.settingsWipeKryfo,
      line: l10n.settingsIdentityMessagesContactsAnd,
      yes: l10n.commonContinue,
      keep: l10n.commonCancel,
    );
    if (!go || !mounted) return;

    // step 2: type the word
    final typed = (await showInputSheet(
      context,
      title: l10n.settingsTypeWipeToConfirm(l10n.settingsWipeWord),
      line: l10n.settingsTheLastStepNothing,
      hint: l10n.settingsWipeWord,
      mono: true,
      rose: true,
      save: l10n.settingsWipeKryfo2,
    ));
    if (isWipeWord(typed, l10n.settingsWipeWord)) await wipeHalo();
  }

  bool _disguise = false;
  bool _acceptIntros = true;
  bool _shieldOn = true;

  @override
  void initState() {
    super.initState();
    loadHideNotifContent(session.container).then((v) {
      if (mounted) setState(() => _hidePreview = v);
    });
    appState.loadDisguisePref().then((d) {
      if (mounted) setState(() => _disguise = d);
    });
    loadAcceptIntros(session.container).then((v) {
      if (mounted) setState(() => _acceptIntros = v);
    });
    loadScamShieldOn(session.container).then((v) {
      if (mounted) setState(() => _shieldOn = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: HaloColors.text2),
        title: Text(
          l10n.commonSettings,
          style: HaloType.serif(size: 22, color: HaloColors.text, italic: true),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: staggerAll([
          ListenableBuilder(
            listenable: Listenable.merge([appState, lockState]),
            builder: (_, _) {
              // the same predicate the home pill uses, or the two screens
              // disagree about the same tor
              final tor = appState.torUsable;
              // relay and fast modes never use tor, so "connecting" there
              // would be a promise nothing is trying to keep
              final onTor = appState.sendMode == 'private';
              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                decoration: BoxDecoration(
                  color: HaloColors.surface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: HaloColors.line, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsYourProtections,
                      style: HaloType.mono(size: 11, color: HaloColors.amber),
                    ),
                    const SizedBox(height: 10),
                    _postureLine(
                      l10n.settingsTorRouting,
                      onTor && tor,
                      l10n.settingsConnected,
                      onTor
                          ? l10n.settingsConnecting
                          : appState.sendMode == 'fast'
                          ? l10n.settingsOffFastMode
                          : l10n.settingsOffMode,
                    ),
                    _postureLine(
                      l10n.settingsScreenshots,
                      appState.blockScreenshotsApplied ||
                          appState.screenSecureByLock,
                      l10n.settingsBlocked2,
                      l10n.settingsAllowed,
                    ),
                    _postureLine(
                      l10n.settingsAppLock,
                      lockState.enabled,
                      l10n.settingsOn,
                      l10n.settingsOff,
                    ),
                    // only when android is blocking them: a line that says
                    // so outlives the home banner, which can be dismissed
                    FutureBuilder<bool>(
                      future: notificationsEnabled(),
                      builder: (_, snap) => snap.data == false
                          ? _postureLine(
                              l10n.settingsNotifications,
                              false,
                              '',
                              l10n.settingsBlockedByAndroid,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            },
          ),

          HaloGroup(
            children: [
              HaloRow(
                icon: Icons.language,
                label: l10n.languageTitle,
                value: languageValue(),
                onTap: () => pickLanguage(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          HaloSection(l10n.settingsPrivacy),
          HaloGroup(
            children: [
              HaloRow(
                icon: Icons.shield_outlined,
                label: l10n.settingsSpeedPrivacy,
                value: appState.sendMode == 'fast'
                    ? l10n.settingsFast
                    : appState.sendMode == 'balanced'
                    ? l10n.settingsRelay1Hop
                    : l10n.settingsOnion3Hops,
                onTap: () async {
                  await Navigator.of(
                    context,
                  ).push(haloRoute(const ModesScreen()));
                  if (mounted) setState(() {});
                },
              ),
              HaloRow(
                icon: Icons.vpn_lock_outlined,
                label: l10n.settingsBridges,
                hint: l10n.settingsForNetworksThatBlock,
                value: appState.bridgesOn ? l10n.commonOn : l10n.commonOff,
                onTap: () async {
                  await Navigator.push(
                    context,
                    haloRoute(const BridgesScreen()),
                  );
                  if (mounted) setState(() {});
                },
              ),
              // one row: how messages arrive and what they say when they do
              // belong together
              HaloRow(
                icon: Icons.mark_email_unread_outlined,
                label: l10n.settingsGettingMessages,
                value: switch (_hidePreview) {
                  null => deliveryModeName(appState.deliveryMode),
                  true => l10n.settingsPreviewHidden(
                    deliveryModeName(appState.deliveryMode),
                  ),
                  false => l10n.settingsPreviewShown(
                    deliveryModeName(appState.deliveryMode),
                  ),
                },
                onTap: () async {
                  await Navigator.of(
                    context,
                  ).push(haloRoute(const GettingMessagesScreen()));
                  final v = await loadHideNotifContent(session.container);
                  if (mounted) {
                    setState(() => _hidePreview = v);
                  }
                },
              ),
              HaloRow(
                icon: Icons.battery_saver,
                label: l10n.settingsRunInBackground,
                value: l10n.settingsSoMessagesArrive,
                onTap: () => forceShowBackgroundPrompt(context),
              ),
              HaloRow(
                icon: Icons.lan_outlined,
                label: l10n.settingsTransport,
                value: l10n.settingsWhatTheNetworkIs,
                onTap: () =>
                    Navigator.push(context, haloRoute(const TransportScreen())),
              ),
              HaloRow(
                icon: Icons.block,
                label: l10n.settingsBlocked,
                onTap: () => Navigator.of(
                  context,
                ).push(haloRoute(const BlockedScreen())),
              ),
              HaloRow(
                icon: Icons.people_outline,
                label: l10n.settingsAcceptIntroductions,
                hint: l10n.settingsFriendsCanIntroduceYou,
                value: _acceptIntros ? l10n.commonOn : l10n.commonOff,
                onTap: () async {
                  setState(() => _acceptIntros = !_acceptIntros);
                  await saveAcceptIntros(_acceptIntros, session.container);
                },
              ),
              HaloRow(
                icon: Icons.shield_outlined,
                label: l10n.settingsScamShield,
                hint: l10n.settingsChecksStrangersOnYour,
                value: _shieldOn ? l10n.commonOn : l10n.commonOff,
                onTap: () async {
                  setState(() => _shieldOn = !_shieldOn);
                  await saveScamShieldOn(_shieldOn, session.container);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          HaloSection(l10n.settingsSecurity),
          HaloGroup(
            children: [
              // one switch for the whole app, applied at the next start:
              // changing the flag live recreates the surface and flashes
              HaloRow(
                icon: Icons.visibility_off_outlined,
                label: l10n.settingsBlockScreenshots,
                // with an app lock the screen stays covered, whatever the
                // switch says, and the row says so
                hint: appState.screenSecureByLock
                    ? l10n.settingsKeptOnWhileLock
                    : appState.blockScreenshotsPending
                    ? l10n.settingsWholeAppHiddenFrom
                    : l10n.settingsWholeAppHiddenFromRecentsAnd,
                value: appState.screenSecureByLock
                    ? l10n.commonOn
                    : appState.blockScreenshots
                    ? (appState.blockScreenshotsPending
                          ? l10n.settingsOnNextStart
                          : l10n.commonOn)
                    : (appState.blockScreenshotsPending
                          ? l10n.settingsOffNextStart
                          : l10n.commonOff),
                onTap: appState.screenSecureByLock
                    ? null
                    : () async {
                        await appState.setBlockScreenshots(
                          !appState.blockScreenshots,
                        );
                        if (mounted) setState(() {});
                      },
              ),
              HaloRow(
                icon: Icons.light_mode_outlined,
                label: l10n.settingsLightTheme,
                hint: l10n.settingsSameProtectionBrighter,
                value: HaloColors.isLight ? l10n.commonOn : l10n.commonOff,
                onTap: () async {
                  await appState.setLight(!HaloColors.isLight);
                  if (mounted) setState(() {});
                },
              ),
              AnimatedBuilder(
                animation: lockState,
                builder: (_, _) => HaloRow(
                  icon: Icons.lock_outline,
                  label: l10n.settingsAppLock2,
                  hint: l10n.settingsYourPinAndA,
                  value: !lockState.enabled
                      ? l10n.commonOff
                      : lockState.panicEnabled
                      ? l10n.settingsPinWipePin
                      : l10n.commonOn,
                  onTap: () =>
                      Navigator.of(context).push(haloRoute(const PinsScreen())),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          HaloSection(l10n.settingsBackup),
          HaloGroup(
            children: [
              HaloRow(
                icon: Icons.save_alt,
                label: l10n.settingsBackUpIdentity,
                value: l10n.settingsEncryptedFile,
                onTap: () =>
                    Navigator.of(context).push(haloRoute(const BackupScreen())),
              ),
              HaloRow(
                icon: Icons.restore,
                label: l10n.settingsRestoreFromBackup,
                value: l10n.settingsReplaceCurrent,
                onTap: () => Navigator.of(
                  context,
                ).push(haloRoute(const RestoreScreen())),
              ),
            ],
          ),
          const SizedBox(height: 24),

          HaloSection(l10n.settingsVoice),
          HaloGroup(
            children: [
              HaloRow(
                icon: Icons.record_voice_over,
                label: l10n.settingsDisguiseVoice,
                hint: l10n.settingsShiftsYourPitchBefore,
                value: _disguise ? l10n.commonOn : l10n.commonOff,
                onTap: () async {
                  setState(() => _disguise = !_disguise);
                  await appState.saveDisguisePref(_disguise);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          HaloSection(l10n.settingsAbout),
          HaloGroup(
            children: [
              HaloRow(
                icon: Icons.help_outline,
                label: l10n.settingsWhyKryfo,
                value: l10n.settingsHowItProtectsYou,
                onTap: () =>
                    Navigator.push(context, haloRoute(const WhyKryfoScreen())),
              ),
              HaloRow(
                icon: Icons.autorenew,
                label: l10n.settingsResetMyInviteLink,
                hint: l10n.settingsOldLinksAndCodes,
                onTap: () async {
                  final ok = await showConfirmSheet(
                    context,
                    title: l10n.settingsResetInviteLink,
                    line: l10n.settingsAnyoneWithAnOld,
                    yes: l10n.settingsReset,
                  );
                  if (!ok) return;
                  await appState.resetInviteAddress();
                  if (context.mounted) {
                    showHaloToast(context, l10n.settingsInviteResetShareThe);
                  }
                },
              ),
              HaloRow(
                icon: Icons.visibility_outlined,
                label: l10n.settingsWhatWeCanSee,
                value: l10n.settingsTheHonestList,
                onTap: () =>
                    Navigator.push(context, haloRoute(const SeenScreen())),
              ),
              HaloRow(
                icon: Icons.info_outline,
                label: l10n.settingsVersion,
                value: l10n.settings030Alpha,
              ),
              HaloRow(
                icon: Icons.flag_outlined,
                label: l10n.settingsReportAnIssue,
                value: l10n.settingsBugOrSecurityFlaw,
                onTap: () => launchUrl(
                  Uri.parse(
                    'mailto:gnosiworks@proton.me?subject=Kryfo%20report',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              // copies, never opens: a browser hop would hand github the
              // phone's address
              HaloRow(
                icon: Icons.code,
                label: l10n.settingsOpenSource,
                value: 'github.com/GnosiWorks/Kryfo',
                onTap: () async {
                  await Clipboard.setData(
                    const ClipboardData(
                      text: 'https://github.com/GnosiWorks/Kryfo',
                    ),
                  );
                  if (context.mounted) {
                    showHaloToast(context, l10n.settingsLinkCopied);
                  }
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 10, 12, 0),
            child: Text(
              l10n.settingsTheOfflineMapIn,
              style: HaloType.sans(
                size: 12,
                color: HaloColors.warm,
                height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 10, 12, 0),
            child: Text(
              l10n.settingsNotIndependentlyAuditedPre,
              style: HaloType.sans(
                size: 12,
                color: HaloColors.text3,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),

          HaloSection(l10n.settingsDangerZone),
          HaloGroup(
            rose: true,
            children: [
              HaloRow(
                icon: Icons.delete_outline,
                label: l10n.settingsWipeKryfoFromThis,
                rose: true,
                onTap: _confirmWipe,
              ),
            ],
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}
