// SPDX-License-Identifier: GPL-3.0-or-later
// the dev screen

part of '../main.dart';

class DevScreen extends StatefulWidget {
  const DevScreen({super.key});
  @override
  State<DevScreen> createState() => _DevScreenState();
}

/// scan, pairing code or a pasted link: the choice and the words pasted.
/// null when cancelled or dismissed
@visibleForTesting
Future<(String, String)?> showImportPeerDialog(BuildContext context) =>
    showDialog<(String, String)>(
      context: context,
      builder: (_) => OwnedText(
        builder: (ctx, ctrl) => AlertDialog(
          backgroundColor: HaloColors.surface2,
          title: Text(
            l10n.appAddAKryfo,
            style: HaloType.sans(color: HaloColors.amberText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.maxFinite,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, ('scan', ctrl.text)),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(l10n.appScanQr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HaloColors.amber,
                    foregroundColor: HaloColors.onAmber,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.maxFinite,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, ('code', ctrl.text)),
                  icon: const Icon(Icons.dialpad, size: 18),
                  label: Text(l10n.appPairingCode),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HaloColors.text2,
                    side: BorderSide(color: HaloColors.line),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.appOrPaste,
                style: HaloType.sans(size: 11, color: HaloColors.text2),
              ),
              const SizedBox(height: 10),
              ShiftTapGuard(
                controller: ctrl,
                child: TextField(
                  textDirection: TextDirection.ltr,
                  controller: ctrl,
                  enableIMEPersonalizedLearning: false,
                  maxLines: 4,
                  style: HaloType.mono(size: 11, color: HaloColors.text),
                  decoration: InputDecoration(
                    hintText: 'kryfo://share?...',
                    hintStyle: HaloType.mono(size: 11, color: HaloColors.text3),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ('paste', ctrl.text)),
              child: Text(
                l10n.appImport,
                style: HaloType.sans(color: HaloColors.amberText),
              ),
            ),
          ],
        ),
      ),
    );

class _DevScreenState extends State<DevScreen> {
  final _msgCtrl = TextEditingController(text: l10n.appHelloFromTheOther);
  String _myAddr = '';
  String _status = '';
  TorStatus _torStatus = TorStatus.off;
  int _bootstrapPct = 0;
  String _peerId = '';
  String _peerOnion = '';
  String _peerXPub = '';

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _status = appState.restored
        ? l10n.appIdentityRestored
        : l10n.appIdentityCreated;
    _loadLastPeer();
  }

  Future<void> _loadLastPeer() async {
    final rows = await session.contacts();
    if (rows.isEmpty) return;
    setState(() {
      _peerId = rows.first['halo_id'] as String;
      _peerOnion = rows.first['onion'] as String;
      _peerXPub = rows.first['xpub'] as String;
    });
  }

  Future<void> _startListener() async {
    setState(() => _status = l10n.appStartingTor30s);
    final docsDir = await getApplicationDocumentsDirectory();
    // off the ui thread: starting tor blocks on socket i/o long enough to
    // trip an anr
    final addr = await _startListenerOnIsolate(docsDir.path);
    setState(() {
      if (addr.startsWith('error')) {
        _status = addr;
      } else {
        _myAddr = addr;
        _status = '';
      }
    });
    _pollTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final raw = engine.getStatus();
      final newStatus = parseTorStatus(raw);
      final newPct = parseBootstrapPct(raw);
      if ((newStatus != _torStatus || newPct != _bootstrapPct) && mounted) {
        setState(() {
          _torStatus = newStatus;
          _bootstrapPct = newPct;
        });
      }
      final msgs = engine.drainInbox();
      if (msgs.isEmpty || _peerXPub.isEmpty) return;
      for (final r in msgs) {
        final plain = engine.decryptFrom(_peerXPub, r);
        if (!plain.startsWith('error')) {
          session.saveMessage(_peerId, 'in', plain);
        }
        setState(() {});
      }
    });
  }

  Future<void> _send() async {
    if (_peerOnion.isEmpty || _peerXPub.isEmpty) {
      setState(() => _status = l10n.appScanOrImportA);
      return;
    }
    setState(() => _status = l10n.appEncryptingSending30s);
    final plain = _msgCtrl.text;
    final cipher = engine.encryptFor(_peerXPub, plain);
    if (cipher.startsWith('error')) {
      setState(() => _status = cipher);
      return;
    }
    final result = await Future(() => engine.sendTo(_peerOnion, cipher));
    if (result == 'ok') {
      await session.saveMessage(_peerId, 'out', plain);
    }
    setState(() => _status = result);
  }

  Future<void> _showMyQr() async {
    if (_myAddr.isEmpty) {
      setState(() => _status = l10n.appTapStartListeningFirst);
      return;
    }
    final uri = await buildHaloUriV3(
      appState.myId,
      _myAddr,
      appState.fcCounter,
    );
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: HaloColors.onAmber,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.appYourKryfo,
                style: HaloType.serif(
                  size: 14,
                  italic: true,
                  color: HaloColors.amberText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                appState.myId,
                style: HaloType.mono(size: 18, color: HaloColors.amberText),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                color: Colors.white,
                child: QrImageView(
                  data: uri,
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: HaloColors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  uri,
                  style: HaloType.mono(size: 9, color: HaloColors.amberText),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  copySensitive(uri);
                  showHaloToast(context, l10n.appUriCopied);
                },
                child: Text(
                  l10n.appCopyUri,
                  style: HaloType.sans(color: HaloColors.amberText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importPeer() async {
    final picked = await showImportPeerDialog(context);
    final action = picked?.$1;
    if (action == null || !mounted) return;

    if (action == 'code') {
      await Navigator.of(context).push(haloRoute(const PairCodeScreen()));
      await appState.refreshContacts();
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
      uri = picked!.$2;
    }

    if (!mounted) return;
    final status = await takeOwnLink(
      context,
      uri,
      act: action == 'scan' ? addScanned : handleHaloUri,
    );
    if (status == null) return;
    await appState.refreshContacts();
    final parsed = parseHaloUri(uri);
    if (!mounted) return;
    setState(() {
      if (parsed != null) {
        _peerId = parsed['id'] ?? '';
        _peerOnion = parsed['onion'] ?? '';
        _peerXPub = parsed['xpub'] ?? '';
      }
      _status = status;
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        title: Text(
          l10n.appDev,
          style: HaloType.serif(size: 18, italic: true, color: HaloColors.text),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                'Kryfo',
                style: HaloType.serif(
                  size: 56,
                  weight: FontWeight.w300,
                  italic: true,
                  color: HaloColors.amberText,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                engine.version(),
                style: HaloType.sans(size: 11, color: HaloColors.text2),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.appYourKryfo2,
                style: HaloType.sans(size: 11, color: HaloColors.text2),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: HaloColors.onAmber,
                  border: Border.all(color: HaloColors.amber, width: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  appState.myId.isEmpty ? '...' : appState.myId,
                  style: HaloType.mono(
                    size: 18,
                    color: HaloColors.amberText,
                    letter: 0.04,
                  ),
                ),
              ),
              if (appState.restored)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.appRestoredFromDisk,
                    style: HaloType.mono(size: 9, color: HaloColors.green),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _myAddr.isEmpty ? _startListener : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HaloColors.amber,
                  foregroundColor: HaloColors.onAmber,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _myAddr.isEmpty ? l10n.appStartListening : l10n.appListening,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.qr_code, color: HaloColors.amber),
                      label: Text(l10n.appShowMyQr),
                      onPressed: _showMyQr,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.content_paste, color: HaloColors.violet),
                      label: Text(l10n.appImportPeer),
                      onPressed: _importPeer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_peerId.isNotEmpty) ...[
                Text(
                  l10n.appPeer,
                  style: HaloType.sans(size: 11, color: HaloColors.text2),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: HaloColors.surface3,
                    border: Border.all(color: HaloColors.green, width: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _peerId,
                    style: HaloType.mono(size: 14, color: HaloColors.green),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ShiftTapGuard(
                controller: _msgCtrl,
                child: TextField(
                  controller: _msgCtrl,
                  enableIMEPersonalizedLearning: false,
                  style: HaloType.sans(color: HaloColors.text),
                  decoration: InputDecoration(
                    labelText: l10n.appMessageWillBeEncrypted,
                    labelStyle: HaloType.sans(color: HaloColors.text2),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: (_myAddr.isEmpty || _peerOnion.isEmpty)
                    ? null
                    : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HaloColors.amber,
                  foregroundColor: HaloColors.onAmber,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(l10n.appEncryptSend),
              ),
              const SizedBox(height: 16),
              TorWarmupGraph(status: _torStatus, bootstrapPct: _bootstrapPct),
              const SizedBox(height: 12),
              if (_status.isNotEmpty)
                Text(
                  l10n.appStatus(_status),
                  style: HaloType.sans(size: 12, color: HaloColors.text2),
                ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () =>
                    Navigator.of(context).push(haloRoute(const ModesScreen())),
                child: Text(
                  l10n.appSpeedPrivacy,
                  style: HaloType.mono(size: 11, color: HaloColors.amberText),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.of(
                  context,
                ).push(haloRoute(const GettingMessagesScreen())),
                child: Text(
                  l10n.appGettingMessages,
                  style: HaloType.mono(size: 11, color: HaloColors.amberText),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  if (lockState.lockOn) {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: HaloColors.surface3,
                        title: Text(
                          l10n.appDisableAppLock,
                          style: HaloType.serif(
                            size: 18,
                            color: HaloColors.text,
                          ),
                        ),
                        content: Text(
                          l10n.appThePinWillBe,
                          style: HaloType.sans(
                            size: 13,
                            color: HaloColors.text2,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(
                              l10n.commonCancel,
                              style: HaloType.sans(
                                size: 13,
                                color: HaloColors.text2,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text(
                              l10n.appDisable,
                              style: HaloType.sans(
                                size: 13,
                                color: HaloColors.rose,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await lockState.disable();
                  } else {
                    Navigator.of(
                      context,
                    ).push(haloRoute(const LockSetupScreen()));
                  }
                },
                child: AnimatedBuilder(
                  animation: lockState,
                  builder: (_, _) => Text(
                    lockState.lockOn ? l10n.appAppLockOn : l10n.appAppLockOff,
                    style: HaloType.mono(size: 11, color: HaloColors.amberText),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
