// SPDX-License-Identifier: GPL-3.0-or-later
// your linked devices: this phone, the computers linked to it, linking one
// more and removing them. only you see this page; your contacts' apps show
// nothing about your devices
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../devices/own_devices.dart';
import '../l10n/dates.dart' show dayMonthMaybeYear;
import '../l10n/l10n.dart';
import '../l10n/numbers.dart' show whole;
import '../theme.dart';
import '../widgets/burn_fade.dart' show FadeFold;
import '../widgets/confirm_sheet.dart';
import '../widgets/fit_column.dart';
import '../widgets/halo_buttons.dart';
import '../widgets/halo_rows.dart';
import '../widgets/halo_sheet.dart';
import '../widgets/motion.dart' show haloRoute;
import '../widgets/page_head.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/stagger_in.dart';
import '../widgets/swap.dart';
import '../widgets/unfold.dart';
import 'link_screens.dart';
import 'scan_screen.dart';
import '../wide/read_width.dart' show DeskPage;

/// the settings row's value: the other devices by name, never a count
String devicesRowValue(List<OwnDevice> all) {
  final others = [
    for (final d in all)
      if (!d.thisDevice) d.name,
  ];
  return others.isEmpty
      ? l10n.devicesThisPhoneOnlyShown
      : others.join(l10n.devicesNameSeparator);
}

/// the home card's title and line for the notices not opened yet: one
/// device by its name and day, more by their names, oldest first. a device
/// another copy of the phone linked comes before anything else; a device
/// that went says why ([why], own_unlink.dart's words); new and gone ones
/// together say the devices changed
({String title, String line}) linkNoticeWords(
  List<({String name, DateTime at, String? why})> all,
  DateTime now,
) {
  final unknown = [
    for (final n in all)
      if (n.why == 'unknown') n,
  ];
  if (unknown.isNotEmpty) {
    return (title: l10n.devicesUnknownNotice, line: l10n.devicesUnknownLine);
  }
  final gone = [
    for (final n in all)
      if (n.why != null) n,
  ];
  if (gone.length == 1 && all.length == 1) {
    final n = gone.single;
    final date = dayMonthMaybeYear(n.at, now: now);
    return (
      title: l10n.devicesGoneNotice,
      line: switch (n.why) {
        'unused' => l10n.devicesGoneUnusedLine(n.name, date),
        'itself' => l10n.devicesGoneItselfLine(n.name, date),
        _ => l10n.devicesGoneRemovedLine(n.name, date),
      },
    );
  }
  if (gone.isNotEmpty) {
    return (title: l10n.devicesChangedNotice, line: l10n.devicesChangedLine);
  }
  if (all.length == 1) {
    final n = all.single;
    return (
      title: l10n.devicesNewNotice,
      line: l10n.devicesNewNoticeLine(
        n.name,
        dayMonthMaybeYear(n.at, now: now),
      ),
    );
  }
  return (
    title: l10n.devicesNewNoticeMany,
    line: l10n.devicesNewNoticeManyLine(
      [for (final n in all) n.name].join(l10n.devicesNameSeparator),
    ),
  );
}

String deviceUseLine(DeviceUse u) => switch (u) {
  DeviceUse.today => l10n.devicesUsedToday,
  DeviceUse.week => l10n.devicesUsedThisWeek,
  DeviceUse.month => l10n.devicesUsedThisMonth,
  DeviceUse.notYet => l10n.devicesNotUsedYet,
};

/// the line under a device's name. on a linked device its own row says
/// whose it is: its phone links and removes
String deviceLine(OwnDevice d, DateTime now, {bool linked = false}) {
  if (d.thisDevice) {
    return linked ? l10n.joinDone : l10n.devicesOnlyThisPhoneShown;
  }
  final use = deviceUseLine(deviceUseOf(d.lastUsed, now));
  final at = d.linkedAt;
  return at == null
      ? use
      : '${l10n.devicesLinkedOn(dayMonthMaybeYear(at, now: now))} · $use';
}

class LinkedDevicesScreen extends StatefulWidget {
  // where the devices come from; the phone alone until linking is wired
  final OwnDevices? source;
  // the clock, for tests
  final DateTime Function()? now;
  const LinkedDevicesScreen({super.key, this.source, this.now});

  @override
  State<LinkedDevicesScreen> createState() => _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends State<LinkedDevicesScreen> {
  late final OwnDevices _source =
      widget.source ?? ThisPhoneOnly(phoneName: l10n.devicesThisPhoneShown);
  final _scroll = ScrollController();
  List<OwnDevice>? _devices;
  final Set<String> _leaving = {};

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
    // the page is open: a new device's notice has been seen
    unawaited(_source.opened());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await _source.load();
    if (mounted) setState(() => _devices = all);
  }

  List<OwnDevice> get _others => [
    for (final d in _devices ?? const <OwnDevice>[])
      if (!d.thisDevice) d,
  ];

  bool get _full => _others.length >= kMaxLinkedDevices;

  Future<void> _open(OwnDevice d) async {
    HapticFeedback.selectionClick();
    final what = await showHaloSheet<_Act>(
      context,
      builder: (_) => _DeviceSheet(device: d, now: _now),
    );
    if (!mounted || what == null) return;
    switch (what) {
      case _Act.rename:
        await _rename(d);
      case _Act.remove:
        await _remove(d);
    }
  }

  Future<void> _rename(OwnDevice d) async {
    final typed = await showInputSheet(
      context,
      title: l10n.devicesRenameTitle(d.name),
      line: l10n.devicesRenameLine,
      initial: d.name,
      hint: l10n.devicesNameComputer,
      maxLength: kDeviceNameMax,
    );
    if (typed == null || !mounted) return;
    final name = deviceNameOf(typed);
    if (name == null || name == d.name) return;
    await _source.rename(d.id, name);
    if (!mounted) return;
    setState(() {
      _devices = [
        for (final x in _devices ?? const <OwnDevice>[])
          x.id == d.id ? x.renamed(name) : x,
      ];
    });
  }

  Future<void> _remove(OwnDevice d) async {
    final yes = await showConfirmSheet(
      context,
      title: l10n.devicesRemoveTitle(d.name),
      line: l10n.devicesRemoveLine,
      yes: l10n.devicesRemove,
      titleLines: 2,
    );
    if (!yes || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _leaving.add(d.id));
    await _source.remove(d.id);
    await Future.delayed(FadeFold.gone);
    if (!mounted) return;
    _leaving.remove(d.id);
    await _load();
    if (mounted) showHaloToast(context, l10n.devicesRemoved(d.name));
  }

  Future<void> _removeOthers() async {
    final yes = await showConfirmSheet(
      context,
      title: l10n.devicesRemoveAllTitle,
      line: l10n.devicesRemoveAllLine,
      yes: l10n.devicesRemoveAllYes,
    );
    if (!yes || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _leaving.addAll([for (final d in _others) d.id]));
    await _source.removeOthers();
    await Future.delayed(FadeFold.gone);
    if (!mounted) return;
    _leaving.clear();
    await _load();
    if (mounted) showHaloToast(context, l10n.devicesRemovedAll);
  }

  Future<void> _leave() async {
    final yes = await showConfirmSheet(
      context,
      title: l10n.devicesLeaveTitle,
      line: l10n.devicesLeaveLine,
      yes: l10n.devicesLeaveYes,
    );
    if (!yes || !mounted) return;
    HapticFeedback.mediumImpact();
    await _source.leaveHere();
  }

  void _link() {
    HapticFeedback.selectionClick();
    Navigator.of(
      context,
    ).push(haloRoute(LinkDeviceScreen(onScan: _source.canLink ? _scan : null)));
  }

  // the scanner, then the link from the code it read. "try again" opens
  // the scanner afresh; a link that took closes the link page too
  Future<void> _scan(LinkHistory history) async {
    final nav = Navigator.of(context);
    final code = await nav.push<String>(
      haloRoute(const ScanScreen(link: true)),
    );
    if (code == null || !mounted) return;
    var again = false;
    final linked = await nav.push<bool>(
      haloRoute(
        LinkRunScreen(
          flow: _source.linkFlow(code, history),
          onAgain: () {
            again = true;
            nav.pop(false);
          },
        ),
      ),
    );
    if (!mounted) return;
    if (linked == true) {
      nav.pop();
      await _load();
      unawaited(_source.opened());
    } else if (again) {
      await _scan(history);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = _devices;
    final now = _now;
    final others = _others;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: DeskPage(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageBar(title: l10n.devicesLinkedDevices, controller: _scroll),
              Expanded(
                child: devices == null
                    ? const SizedBox()
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        children: [
                          HaloGroup(
                            children: [
                              for (final (i, d) in devices.indexed)
                                StaggerIn(
                                  key: ValueKey(d.id),
                                  index: i,
                                  child: IgnorePointer(
                                    ignoring: _leaving.contains(d.id),
                                    child: FadeFold(
                                      leaving: _leaving.contains(d.id),
                                      child: _DeviceRow(
                                        device: d,
                                        now: now,
                                        linked: _source.linkedDevice,
                                        onTap:
                                            d.thisDevice || _source.linkedDevice
                                            ? null
                                            : () => _open(d),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          FadeSwap(
                            child: others.isEmpty && _source.linksHere
                                ? const _Empty(key: ValueKey('empty'))
                                : const SizedBox(
                                    key: ValueKey('some'),
                                    width: double.infinity,
                                  ),
                          ),
                          const SizedBox(height: 18),
                          _Note(
                            icon: Icons.visibility_off_outlined,
                            text: l10n.devicesContactsSeeNothing,
                          ),
                          const SizedBox(height: 10),
                          _Note(
                            icon: Icons.timer_outlined,
                            text: l10n.devicesUnusedRule,
                          ),
                          Unfold(
                            open: _source.canLeave,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: HaloGroup(
                                rose: true,
                                children: [
                                  HaloRow(
                                    icon: Icons.link_off_rounded,
                                    label: l10n.devicesLeave,
                                    rose: true,
                                    onTap: _leave,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Unfold(
                            open: others.isNotEmpty && !_source.linkedDevice,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: HaloGroup(
                                rose: true,
                                children: [
                                  HaloRow(
                                    icon: Icons.link_off_rounded,
                                    label: l10n.devicesRemoveAll,
                                    rose: true,
                                    onTap: _removeOthers,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              // linking is the phone's: a linked device and a computer that
              // holds the account offer none
              if (_source.linksHere)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Unfold(
                        open: _full,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            l10n.devicesFull,
                            textAlign: TextAlign.center,
                            style: HaloType.sans(
                              size: 12.5,
                              color: HaloColors.text2,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                      HaloPrimaryButton(
                        label: l10n.devicesLinkADevice,
                        onTap: devices == null || _full ? null : _link,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Act { rename, remove }

class _DeviceRow extends StatelessWidget {
  final OwnDevice device;
  final DateTime now;
  final bool linked;
  final VoidCallback? onTap;
  const _DeviceRow({
    required this.device,
    required this.now,
    this.linked = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final d = device;
    final days = d.unlinksInDays;
    final soon = !d.thisDevice && days != null && days <= kUnlinkWarnDays;
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        splashColor: HaloColors.amber.withValues(alpha: 0.08),
        highlightColor: HaloColors.amber.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: HaloColors.amberSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  d.isPhone ? Icons.smartphone_rounded : Icons.laptop_rounded,
                  size: 19,
                  color: HaloColors.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.name,
                      style: HaloType.sans(
                        size: 15,
                        weight: FontWeight.w600,
                        color: HaloColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      deviceLine(d, now, linked: linked),
                      style: HaloType.sans(
                        size: 12.5,
                        color: HaloColors.text2,
                        height: 1.35,
                      ),
                    ),
                    if (soon) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.devicesUnlinksSoon(days),
                        style: HaloType.sans(
                          size: 12.5,
                          weight: FontWeight.w500,
                          color: HaloColors.warnText,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6, top: 8),
                  child: Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left
                        : Icons.chevron_right,
                    size: 20,
                    color: HaloColors.text3,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// this phone alone: what linking gives, in two lines
class _Empty extends StatelessWidget {
  const _Empty({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 22, 8, 0),
      child: Column(
        children: [
          Icon(Icons.devices_rounded, size: 34, color: HaloColors.amber),
          const SizedBox(height: 10),
          Text(
            l10n.devicesEmptyTitle,
            textAlign: TextAlign.center,
            style: HaloType.serif(size: 18, color: HaloColors.text),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.devicesEmptyLine,
            textAlign: TextAlign.center,
            style: HaloType.sans(
              size: 13,
              color: HaloColors.text2,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Note({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: ExcludeSemantics(
                child: Icon(icon, size: 16, color: HaloColors.text2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: HaloType.sans(
                  size: 12.5,
                  color: HaloColors.text2,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// one linked device: when it was linked and used, its code to match against
// the device itself, and what can be done with it
class _DeviceSheet extends StatelessWidget {
  final OwnDevice device;
  final DateTime now;
  const _DeviceSheet({required this.device, required this.now});

  @override
  Widget build(BuildContext context) {
    final d = device;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            Text(
              d.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: HaloType.serif(size: 20, color: HaloColors.text),
            ),
            const SizedBox(height: 4),
            Text(
              deviceLine(d, now),
              style: HaloType.sans(size: 13, color: HaloColors.text2),
            ),
            if (d.code.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                l10n.devicesDeviceCode,
                style: HaloType.sans(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: HaloColors.amberText,
                ),
              ),
              const SizedBox(height: 6),
              Semantics(
                label: d.code.join(' '),
                excludeSemantics: true,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      for (final g in d.code)
                        Text(
                          g,
                          style: HaloType.mono(
                            size: 17,
                            color: HaloColors.text,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.devicesDeviceCodeLine,
                style: HaloType.sans(
                  size: 12.5,
                  color: HaloColors.text2,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 18),
            HaloGroup(
              children: [
                HaloRow(
                  icon: Icons.edit_outlined,
                  label: l10n.devicesRename,
                  onTap: () => Navigator.pop(context, _Act.rename),
                ),
                HaloRow(
                  icon: Icons.link_off_rounded,
                  label: l10n.devicesRemove,
                  rose: true,
                  onTap: () => Navigator.pop(context, _Act.remove),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// linking one more device: how it goes, and how much history it gets.
/// [onScan] opens the scanner for the device's code; until linking is
/// wired there is none and the button stays off
class LinkDeviceScreen extends StatefulWidget {
  final void Function(LinkHistory history)? onScan;
  const LinkDeviceScreen({super.key, this.onScan});

  @override
  State<LinkDeviceScreen> createState() => _LinkDeviceScreenState();
}

class _LinkDeviceScreenState extends State<LinkDeviceScreen> {
  bool _copy = true;
  bool _skipMedia = false;

  LinkHistory get history => !_copy
      ? LinkHistory.none
      : _skipMedia
      ? LinkHistory.textOnly
      : LinkHistory.all;

  void _pick(bool copy) {
    if (copy == _copy) return;
    HapticFeedback.selectionClick();
    setState(() => _copy = copy);
  }

  @override
  Widget build(BuildContext context) {
    final scan = widget.onScan;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      body: DeskPage(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageBar(title: l10n.devicesLinkADevice),
              Expanded(
                child: FitColumn(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, s) in [
                      l10n.devicesLinkStep1,
                      l10n.devicesLinkStep2,
                      l10n.devicesLinkStep3,
                    ].indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _Step(n: i + 1, text: s),
                      ),
                    HaloSection(l10n.devicesHistory),
                    HaloGroup(
                      children: [
                        _Choice(
                          label: l10n.devicesHistoryCopy,
                          hint: l10n.devicesHistoryCopyHint,
                          on: _copy,
                          onTap: () => _pick(true),
                        ),
                        _Choice(
                          label: l10n.devicesHistoryNone,
                          hint: l10n.devicesHistoryNoneHint,
                          on: !_copy,
                          onTap: () => _pick(false),
                        ),
                      ],
                    ),
                    Unfold(
                      open: _copy,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: HaloGroup(
                          children: [
                            HaloRow(
                              icon: Icons.photo_library_outlined,
                              label: l10n.devicesSkipMedia,
                              hint: l10n.devicesSkipMediaHint,
                              toggled: _skipMedia,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _skipMedia = !_skipMedia);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Note(
                      icon: Icons.lock_outline_rounded,
                      text: l10n.devicesHiddenStayShown,
                    ),
                    const Spacer(),
                    const SizedBox(height: 20),
                    HaloPrimaryButton(
                      label: l10n.devicesScanCode,
                      onTap: scan == null ? null : () => scan(history),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsetsDirectional.only(end: 12),
            decoration: BoxDecoration(
              color: HaloColors.amberSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              whole(n),
              style: HaloType.sans(
                size: 12,
                weight: FontWeight.w600,
                color: HaloColors.amberText,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: HaloType.sans(
                  size: 14,
                  color: HaloColors.text,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// one of the history choices: a ring that fills when picked
class _Choice extends StatelessWidget {
  final String label;
  final String hint;
  final bool on;
  final VoidCallback onTap;
  const _Choice({
    required this.label,
    required this.hint,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: on,
        child: HaloRow(
          label: label,
          hint: hint,
          onTap: onTap,
          mark: AnimatedSwitcher(
            duration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 180),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Icon(
              on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              key: ValueKey(on),
              size: 18,
              color: HaloColors.amber,
            ),
          ),
        ),
      ),
    );
  }
}
