// SPDX-License-Identifier: GPL-3.0-or-later
// the root shell and the add sheet

part of '../main.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  @override
  void initState() {
    super.initState();
    appState.addListener(_onChange);
    // boot after the first frame is on screen. loading libhalo.so pulls in the
    // whole go runtime + embedded tor and blocks briefly, and before the first
    // paint that can trip the anr watchdog on weak phones.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => appState.bootWhenWanted(),
    );
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    appState.removeListener(_onChange);
    super.dispose();
  }

  void _open(Widget w) {
    Navigator.push(context, haloRoute(w));
  }

  @override
  Widget build(BuildContext context) {
    if (!appState.ready) {
      return Scaffold(
        backgroundColor: HaloColors.surface,
        body: Center(
          child: Text(
            appState.onboardingComplete
                ? l10n.appBooting
                : l10n.appSettingUpYourIdentity,
            style: HaloType.mono(size: 11, color: HaloColors.text2),
          ),
        ),
      );
    }
    return HomeScreen(
      key: ValueKey(appState.sessionRev),
      haloId: appState.sessionId,
      contacts: appState.contacts,
      devRow: appState.devRow,
      pendingCount: appState.pendingCount,
      support: appState.devMode ? appState.supportWaiting : null,
      groups: appState.groups
          .map(
            (g) => GroupSummary(
              groupId: g.groupId,
              name: g.name,
              memberCount: g.memberCount,
              unread: g.unread,
              mentioned: g.mentioned,
              expiresAt: g.expiresAt,
              joiningAt: g.joiningAt,
              hidden: g.hidden,
              endedBy: g.endedBy,
            ),
          )
          .toList(),
      onAddContact: () => showAddContact(context),
      onNewGroup: () => _open(const NewGroupScreen()),
      onNewRoom: () async {
        final id = await showRoomCreateSheet(context);
        if (id == null || !mounted) return;
        _open(GroupChatScreen(groupId: id));
      },
      expiredRoomName: appState.expiredRoomName,
      onOpenDev: () => _open(const DevScreen()),
      onOpenSettingsDirect: () => _open(SettingsScreen()),
      onOpenChat: (id) => openChatAt(context, peer: id),
      onOpenGroup: (groupId) async {
        if (!mounted) return;
        Navigator.push(context, haloRoute(GroupChatScreen(groupId: groupId)));
      },
    );
  }
}

Future<void> showAddContact(BuildContext context) async {
  final ctrl = TextEditingController();
  final action = await showHaloSheet<String>(
    context,
    builder: (sheetCtx) => _AddSheet(ctrl: ctrl, done: sheetCtx),
  );
  if (action == null || !context.mounted) return;
  if (action == 'mine') {
    await Navigator.of(context).push(haloRoute(const MyKryfoScreen()));
    return;
  }

  String uri;
  if (action == 'scan') {
    final result = await Navigator.of(
      context,
    ).push<String>(haloRoute<String>(const ScanScreen()));
    if (result == null) return;
    uri = result;
  } else {
    uri = ctrl.text.trim();
    if (uri.isEmpty) return;
  }

  if (!context.mounted) return;
  // a room shows what its link says first: put away, nothing happened
  final status = await takeOwnLink(
    context,
    uri,
    act: action == 'scan' ? addScanned : handleHaloUri,
  );
  if (status == null) return;
  await appState.refreshContacts();
  if (!context.mounted) return;
  showHaloToast(context, status);
}

// the add someone sheet. the field lights up while it is typed in, and
// "add them" fills once there is something to add. the house sheet scrolls
// it above the keyboard
class _AddSheet extends StatefulWidget {
  final TextEditingController ctrl;
  // the sheet's own context, which the choice pops
  final BuildContext done;
  const _AddSheet({required this.ctrl, required this.done});
  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet>
    with SingleTickerProviderStateMixin {
  final _focus = FocusNode();
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    _focus.addListener(_repaint);
    widget.ctrl.addListener(_repaint);
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_repaint);
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  // nothing to add yet: the sheet stays, the field shakes and takes the
  // focus, so a link can go straight in
  void _add() {
    if (widget.ctrl.text.trim().isNotEmpty) {
      Navigator.pop(widget.done, 'paste');
      return;
    }
    _focus.requestFocus();
    if (!MediaQuery.disableAnimationsOf(context)) _shake.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final sheetCtx = widget.done;
    final still = MediaQuery.disableAnimationsOf(context);
    final d = still ? Duration.zero : const Duration(milliseconds: 200);
    final typed = widget.ctrl.text.trim().isNotEmpty;
    final lit = _focus.hasFocus;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: 18),
            Text(
              l10n.appAddSomeone,
              style: HaloType.serif(
                size: 22,
                italic: true,
                color: HaloColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.appScanTheirCodeOr,
              style: HaloType.sans(size: 12.5, color: HaloColors.text2),
            ),
            const SizedBox(height: 16),
            _Pressable(
              onTap: () => Navigator.pop(sheetCtx, 'scan'),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: HaloColors.amber,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      size: 19,
                      color: HaloColors.onAmber,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      l10n.appScanTheirCode,
                      style: HaloType.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: HaloColors.onAmber,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _shake,
              // a damped side to side, three swings
              builder: (_, child) => Transform.translate(
                offset: Offset(
                  sin(_shake.value * pi * 6) * 9 * (1 - _shake.value),
                  0,
                ),
                child: child,
              ),
              child: AnimatedContainer(
                duration: d,
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: HaloColors.surface3,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: lit
                        ? HaloColors.amber.withValues(alpha: 0.7)
                        : HaloColors.line,
                    width: lit ? 1 : 0.5,
                  ),
                ),
                child: ShiftTapGuard(
                  controller: widget.ctrl,
                  child: TextField(
                    textDirection: TextDirection.ltr,
                    controller: widget.ctrl,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 3,
                    // "add them" under it comes into view with it
                    scrollPadding: const EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      20 + 10 + 46,
                    ),
                    style: HaloType.mono(size: 12, color: HaloColors.text),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: l10n.appAKryfoLinkA,
                      hintStyle: HaloType.mono(
                        size: 12,
                        color: HaloColors.text3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _Pressable(
              onTap: _add,
              child: AnimatedContainer(
                duration: d,
                curve: Curves.easeOutCubic,
                height: 46,
                decoration: BoxDecoration(
                  color: typed ? HaloColors.amber : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: HaloColors.amber, width: 1),
                ),
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: d,
                    style: HaloType.sans(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: typed ? HaloColors.onAmber : HaloColors.amberText,
                    ),
                    child: Text(l10n.appAddThem),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // the page with every way in: your own code, a link to send,
            // handles, introductions
            _Pressable(
              onTap: () => Navigator.pop(sheetCtx, 'mine'),
              // the door most people need, so it gets the amber edge and glow
              // the jump button uses
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: HaloColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: HaloColors.amber.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: HaloColors.amber.withValues(alpha: 0.16),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Row(
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
                        Icons.qr_code_2,
                        size: 20,
                        color: HaloColors.amber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.appEveryWayToAdd,
                            style: HaloType.sans(
                              size: 14.5,
                              weight: FontWeight.w600,
                              color: HaloColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.appShowYourCodeSend,
                            style: HaloType.sans(
                              size: 11.5,
                              color: HaloColors.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: HaloColors.amber,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Pressable({required this.child, required this.onTap});
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  double _scale = 1;
  void _set(double v) {
    if (mounted) setState(() => _scale = v);
  }

  @override
  Widget build(BuildContext context) {
    // with reduced motion the press is felt, not seen
    final still = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(0.96),
      onTapUp: (_) => _set(1),
      onTapCancel: () => _set(1),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: still ? 1 : _scale,
        duration: Duration(milliseconds: _scale < 1 ? 90 : 240),
        curve: _scale < 1 ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
