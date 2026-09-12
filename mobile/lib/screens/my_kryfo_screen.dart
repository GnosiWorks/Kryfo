// SPDX-License-Identifier: GPL-3.0-or-later
// the page someone opens to bring a friend in. two ways in, by outcome:
// the friend is next to you, or the friend is somewhere else. the
// mechanism sits under each as a detail. this is the one screen that grows
// kryfo, so it gets the room and the type of a front door.
import 'package:flutter/material.dart';
import '../lock_state.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../contact_card.dart';
import '../dlog.dart';
import '../handle_lookup.dart' show handleFromInput;
import '../main.dart' show appState, buildHaloUriV3, handleHaloUri;
import '../theme.dart';
import '../widgets/kryfo_avatar.dart';
import '../widgets/motion.dart' show haloRoute;
import '../widgets/pair_code_panel.dart';
import '../widgets/stagger_in.dart';
import 'handle_screen.dart';
import 'scan_screen.dart';

enum _Way { none, here, away, handle }

class MyKryfoScreen extends StatefulWidget {
  const MyKryfoScreen({super.key});
  @override
  State<MyKryfoScreen> createState() => _MyKryfoScreenState();
}

class _MyKryfoScreenState extends State<MyKryfoScreen> {
  String? _uri;
  _Way _open = _Way.none;

  @override
  void initState() {
    super.initState();
    appState.addListener(_onState);
    _load();
  }

  @override
  void dispose() {
    appState.removeListener(_onState);
    _handleCtrl.dispose();
    super.dispose();
  }

  void _onState() {
    if (_uri == null && appState.myOnion.isNotEmpty) _load();
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (appState.myOnion.isEmpty) return;
    final uri = await buildHaloUriV3(
      appState.myId,
      appState.myOnion,
      appState.fcCounter,
    );
    // debug builds only: a second device on the desk can import it off
    // logcat instead of scanning a screen
    dlog('invite: $uri');
    if (mounted) setState(() => _uri = uri);
  }

  void _toggle(_Way w) {
    HapticFeedback.selectionClick();
    setState(() => _open = _open == w ? _Way.none : w);
  }

  Future<void> _scanTheirs() async {
    HapticFeedback.selectionClick();
    final raw = await Navigator.of(
      context,
    ).push<String>(haloRoute<String>(const ScanScreen()));
    if (raw == null || !mounted) return;
    final status = await handleHaloUri(raw);
    await appState.refreshContacts();
    if (mounted) showHaloToast(context, status);
  }

  final _handleCtrl = TextEditingController();
  bool _finding = false;

  // @wren: the registry hands back the invite wren published, and it goes
  // through the same add path as a scan
  Future<void> _findHandle() async {
    final typed = _handleCtrl.text.trim();
    if (typed.isEmpty || _finding) return;
    final raw = typed.startsWith('@') ? typed : '@$typed';
    if (handleFromInput(raw) == null) {
      showHaloToast(context, 'A handle is 3 to 20 letters, digits or _');
      return;
    }
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() => _finding = true);
    final status = await handleHaloUri(raw);
    await appState.refreshContacts();
    if (!mounted) return;
    setState(() => _finding = false);
    showHaloToast(context, status);
    if (status.startsWith('added') || status.startsWith('already')) {
      HapticFeedback.mediumImpact();
      _handleCtrl.clear();
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    }
  }

  void _copyLink() {
    if (_uri == null) return;
    HapticFeedback.mediumImpact();
    copySensitive(_uri!);
    showHaloToast(context, 'Invite copied · clears in 60s');
  }

  void _shareLink() {
    if (_uri == null) return;
    HapticFeedback.selectionClick();
    lockState.hold(
      () => SharePlus.instance.share(
        ShareParams(
          text:
              "add me on kryfo. my id is ${appState.myId}\n\n"
              "tap to add me:\n$_uri\n\n"
              "kryfo is a private messenger. no phone number, no email.",
          subject: 'Add me on kryfo',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = appState.myId;
    final handle = appState.myHandle;
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: HaloColors.text2),
        title: Text(
          'Add someone',
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
          children: staggerAll([
            // ---- identity: the part people screenshot
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  KryfoAvatar(
                    seed: id.isEmpty ? 'kryfo' : id,
                    size: 96,
                    choice: appState.myAvatar,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    id.isEmpty ? '...' : id,
                    textAlign: TextAlign.center,
                    style: HaloType.mono(
                      size: 22,
                      weight: FontWeight.w600,
                      color: HaloColors.amber,
                      letter: 0.02,
                    ),
                  ),
                  if (handle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '@$handle',
                      style: HaloType.sans(size: 14, color: HaloColors.text2),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    "kryfo doesn't scan your contacts, that's the point.",
                    textAlign: TextAlign.center,
                    style: HaloType.serif(
                      size: 15,
                      italic: true,
                      color: HaloColors.text2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // ---- way one: next to you
            _Way1Card(
              open: _open == _Way.here,
              onToggle: () => _toggle(_Way.here),
              uri: _uri,
              onScan: _scanTheirs,
            ),
            const SizedBox(height: 12),

            // ---- way two: somewhere else
            _Way2Card(
              open: _open == _Way.away,
              onToggle: () => _toggle(_Way.away),
              uri: _uri,
              onCopy: _copyLink,
              onShare: _shareLink,
              onCard: () async {
                if (_uri == null) return;
                HapticFeedback.selectionClick();
                await shareContactCard(
                  context: context,
                  haloId: appState.myId,
                  uri: _uri!,
                );
              },
              onFile: () async {
                if (_uri == null) return;
                HapticFeedback.selectionClick();
                await shareContactVcf(haloId: appState.myId, uri: _uri!);
              },
            ),
            const SizedBox(height: 12),

            // ---- way three: they told you a handle
            _Way3Card(
              open: _open == _Way.handle,
              onToggle: () => _toggle(_Way.handle),
              ctrl: _handleCtrl,
              busy: _finding,
              onFind: _findHandle,
            ),
            const SizedBox(height: 12),

            // ---- the third way in, not hidden: a friend can vouch
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
              child: Text(
                'Already share a friend on kryfo? They can introduce you '
                'both from their chat, and you skip the request.',
                style: HaloType.sans(
                  size: 12,
                  color: HaloColors.text2,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ---- the handle: a public front door, if you want one
            _HandleRow(
              handle: handle,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(haloRoute(const HandleScreen()));
              },
              onCopy: handle == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      Clipboard.setData(ClipboardData(text: '@$handle'));
                      showHaloToast(context, 'Handle copied');
                    },
            ),
          ]),
        ),
      ),
    );
  }
}

// ───────── the two ways ─────────

// a card that opens. the head is the outcome in serif with one plain line
// under it; the body is the mechanism, revealed with a size change and a
// fade rather than a rebuild.
class _WayCard extends StatelessWidget {
  final String title;
  final String line;
  final IconData icon;
  final bool open;
  final VoidCallback onToggle;
  final Widget body;
  const _WayCard({
    required this.title,
    required this.line,
    required this.icon,
    required this.open,
    required this.onToggle,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: HaloColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: open
              ? HaloColors.amber.withValues(alpha: 0.5)
              : HaloColors.line,
          width: open ? 0.8 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: HaloColors.amber),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: HaloType.serif(
                            size: 19,
                            italic: true,
                            color: HaloColors.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          line,
                          style: HaloType.sans(
                            size: 12.5,
                            color: HaloColors.text2,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: HaloColors.text2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? AnimatedOpacity(
                    opacity: 1,
                    duration: const Duration(milliseconds: 200),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                      child: body,
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}

class _Way1Card extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;
  final String? uri;
  final VoidCallback onScan;
  const _Way1Card({
    required this.open,
    required this.onToggle,
    required this.uri,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return _WayCard(
      title: "they're here with me",
      line: 'Point your phones at each other. Nothing goes through a server.',
      icon: Icons.qr_code_2_outlined,
      open: open,
      onToggle: onToggle,
      body: Column(
        children: [
          _QrFrame(uri: uri),
          const SizedBox(height: 16),
          const PairCodePanel(compact: true),
          const SizedBox(height: 14),
          _Ghost(
            icon: Icons.center_focus_strong_outlined,
            label: 'Scan theirs instead',
            onTap: onScan,
          ),
        ],
      ),
    );
  }
}

class _Way2Card extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;
  final String? uri;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onCard;
  final VoidCallback onFile;
  const _Way2Card({
    required this.open,
    required this.onToggle,
    required this.uri,
    required this.onCopy,
    required this.onShare,
    required this.onCard,
    required this.onFile,
  });

  @override
  Widget build(BuildContext context) {
    final ready = uri != null;
    return _WayCard(
      title: "they're somewhere else",
      line: 'Send them a link. It opens straight into add.',
      icon: Icons.send_outlined,
      open: open,
      onToggle: onToggle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: ready ? onCopy : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: HaloColors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ready ? uri! : 'Your link appears once you are connected',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HaloType.mono(
                        size: 9.5,
                        color: ready ? HaloColors.amber : HaloColors.text3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.copy_outlined, size: 14, color: HaloColors.amber),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The link carries your id, your address and the keys to start a '
            'chat. It works until you reset it in settings.',
            style: HaloType.sans(
              size: 12,
              color: HaloColors.text2,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          _Primary(label: 'Send the link', onTap: ready ? onShare : null),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Ghost(
                  icon: Icons.badge_outlined,
                  label: 'As a card',
                  sub: 'An image with the qr',
                  onTap: ready ? onCard : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Ghost(
                  icon: Icons.contact_page_outlined,
                  label: 'As a file',
                  sub: 'Contact file',
                  onTap: ready ? onFile : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// someone said "i'm @wren". one field, one button. the registry only ever
// sees the handle asked about.
class _Way3Card extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;
  final TextEditingController ctrl;
  final bool busy;
  final VoidCallback onFind;
  const _Way3Card({
    required this.open,
    required this.onToggle,
    required this.ctrl,
    required this.busy,
    required this.onFind,
  });

  @override
  Widget build(BuildContext context) {
    return _WayCard(
      title: 'I know their handle',
      line: 'Type the @name they gave you. Works if they claimed one.',
      icon: Icons.alternate_email,
      open: open,
      onToggle: onToggle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: HaloColors.surface3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HaloColors.line, width: 0.5),
            ),
            child: Row(
              children: [
                Text(
                  '@',
                  style: HaloType.mono(size: 14, color: HaloColors.text3),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    maxLength: 20,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => onFind(),
                    style: HaloType.mono(size: 14, color: HaloColors.text),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      hintText: 'Wren',
                      hintStyle: HaloType.mono(
                        size: 14,
                        color: HaloColors.text3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The lookup asks for that one name and nothing about you. Their '
            'first message from you still lands as a request on their side.',
            style: HaloType.sans(
              size: 12,
              color: HaloColors.text2,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          _Primary(
            label: busy ? 'looking…' : 'Find them',
            onTap: busy ? null : onFind,
          ),
        ],
      ),
    );
  }
}

// the qr fades up once its frame has settled, so it reads as placed, not
// dumped
class _QrFrame extends StatefulWidget {
  final String? uri;
  const _QrFrame({required this.uri});
  @override
  State<_QrFrame> createState() => _QrFrameState();
}

class _QrFrameState extends State<_QrFrame> {
  bool _shown = false;
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.of(context).size.width - 22 * 2 - 18 * 2;
    return Container(
      width: side,
      height: side,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HaloColors.text,
        borderRadius: BorderRadius.circular(18),
      ),
      child: AnimatedOpacity(
        opacity: _shown && widget.uri != null ? 1 : 0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: _shown ? 1 : 0.94,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          child: widget.uri == null
              ? Center(
                  child: Text(
                    'Your address appears once you are connected',
                    textAlign: TextAlign.center,
                    style: HaloType.sans(size: 12, color: HaloColors.ink),
                  ),
                )
              : QrImageView(
                  data: widget.uri!,
                  version: QrVersions.auto,
                  backgroundColor: HaloColors.text,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: HaloColors.ink,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: HaloColors.ink,
                  ),
                ),
        ),
      ),
    );
  }
}

class _HandleRow extends StatelessWidget {
  final String? handle;
  final VoidCallback onTap;
  final VoidCallback? onCopy;
  const _HandleRow({required this.handle, required this.onTap, this.onCopy});
  @override
  Widget build(BuildContext context) {
    final claimed = handle != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        decoration: BoxDecoration(
          color: HaloColors.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HaloColors.line, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.alternate_email, size: 20, color: HaloColors.amber),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    claimed ? '@$handle' : 'A public handle',
                    style: claimed
                        ? HaloType.mono(size: 16, color: HaloColors.text)
                        : HaloType.serif(
                            size: 19,
                            italic: true,
                            color: HaloColors.text,
                          ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    claimed
                        ? 'Put it in a bio. Anyone who knows it can find you.'
                        : 'A name people can find you by. Off until you claim one.',
                    style: HaloType.sans(
                      size: 12.5,
                      color: HaloColors.text2,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (onCopy != null)
              IconButton(
                tooltip: 'Copy',
                onPressed: onCopy,
                icon: Icon(
                  Icons.copy_outlined,
                  size: 18,
                  color: HaloColors.text2,
                ),
              )
            else
              Icon(Icons.chevron_right, size: 20, color: HaloColors.text2),
          ],
        ),
      ),
    );
  }
}

// ───────── buttons ─────────

class _Primary extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  const _Primary({required this.label, required this.onTap});
  @override
  State<_Primary> createState() => _PrimaryState();
}

class _PrimaryState extends State<_Primary> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    return GestureDetector(
      onTapDown: on ? (_) => setState(() => _down = true) : null,
      onTapUp: on ? (_) => setState(() => _down = false) : null,
      onTapCancel: on ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? HaloColors.amber : HaloColors.surface3,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            widget.label,
            style: HaloType.sans(
              size: 14,
              weight: FontWeight.w600,
              color: on ? HaloColors.onAmber : HaloColors.text3,
            ),
          ),
        ),
      ),
    );
  }
}

class _Ghost extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback? onTap;
  const _Ghost({
    required this.icon,
    required this.label,
    this.sub,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: HaloColors.surface3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HaloColors.line, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: sub == null
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 16,
              color: on ? HaloColors.amber : HaloColors.text3,
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: HaloType.sans(
                      size: 13,
                      weight: FontWeight.w500,
                      color: on ? HaloColors.text : HaloColors.text3,
                    ),
                  ),
                  if (sub != null)
                    Text(
                      sub!,
                      style: HaloType.mono(size: 9.5, color: HaloColors.text3),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
