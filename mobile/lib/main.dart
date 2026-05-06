// halo mobile — phase 1: QR identity exchange + ECDH encryption over tor

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

typedef CStrFn = Pointer<Utf8> Function();
typedef CStrFnDart = Pointer<Utf8> Function();
typedef OneArgFn = Pointer<Utf8> Function(Pointer<Utf8>);
typedef OneArgFnDart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef TwoArgFn = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef TwoArgFnDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

class HaloEngine {
  late final DynamicLibrary _lib;
  late final CStrFnDart _version;
  late final CStrFnDart _genIdentity;
  late final CStrFnDart _myId;
  late final CStrFnDart _myXPub;
  late final TwoArgFnDart _encryptFor;
  late final TwoArgFnDart _decryptFrom;
  late final CStrFnDart _start;
  late final CStrFnDart _lastRecv;
  late final TwoArgFnDart _send;

  HaloEngine() {
    _lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    _version = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloVersion');
    _genIdentity = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloGenerateIdentity');
    _myId = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMyId');
    _myXPub = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMyXPubkey');
    _encryptFor = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloEncryptFor');
    _decryptFrom = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloDecryptFrom');
    _start = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloStartListener');
    _lastRecv = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloLastReceived');
    _send = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloSendTo');
  }

  String version() => _version().toDartString();
  String generateIdentity() => _genIdentity().toDartString();
  String myId() => _myId().toDartString();
  String myXPubkey() => _myXPub().toDartString();
  String startListener() => _start().toDartString();
  String lastReceived() => _lastRecv().toDartString();

  String encryptFor(String peerPub, String plain) {
    final cPub = peerPub.toNativeUtf8();
    final cPlain = plain.toNativeUtf8();
    try {
      return _encryptFor(cPub, cPlain).toDartString();
    } finally {
      calloc.free(cPub);
      calloc.free(cPlain);
    }
  }

  String decryptFrom(String peerPub, String b64) {
    final cPub = peerPub.toNativeUtf8();
    final cB64 = b64.toNativeUtf8();
    try {
      return _decryptFrom(cPub, cB64).toDartString();
    } finally {
      calloc.free(cPub);
      calloc.free(cB64);
    }
  }

  String sendTo(String addr, String msg) {
    final cAddr = addr.toNativeUtf8();
    final cMsg = msg.toNativeUtf8();
    try {
      return _send(cAddr, cMsg).toDartString();
    } finally {
      calloc.free(cAddr);
      calloc.free(cMsg);
    }
  }
}

// halo://share?id=...&onion=...&xpub=...
String buildHaloUri(String id, String onion, String xpub) {
  return 'halo://share?id=$id&onion=$onion&xpub=$xpub';
}

Map<String, String>? parseHaloUri(String raw) {
  raw = raw.trim();
  if (!raw.startsWith('halo://share')) return null;
  try {
    final uri = Uri.parse(raw);
    final id = uri.queryParameters['id'];
    final onion = uri.queryParameters['onion'];
    final xpub = uri.queryParameters['xpub'];
    if (id == null || onion == null || xpub == null) return null;
    return {'id': id, 'onion': onion, 'xpub': xpub};
  } catch (_) {
    return null;
  }
}

void main() => runApp(const HaloApp());

class HaloApp extends StatelessWidget {
  const HaloApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Halo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF59E0B),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0B09),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _engine = HaloEngine();
  final _msgCtrl = TextEditingController(text: 'hello from the other side');
  String _myId = '';
  String _myXPub = '';
  String _myAddr = '';
  String _status = 'idle';
  String _peerId = '';
  String _peerOnion = '';
  String _peerXPub = '';
  String _receivedCipher = '';
  String _receivedPlain = '';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _myId = _engine.generateIdentity();
    _myXPub = _engine.myXPubkey();
  }

  Future<void> _startListener() async {
    setState(() => _status = 'starting tor (~30s)...');
    final addr = await Future(() => _engine.startListener());
    setState(() {
      if (addr.startsWith('error')) {
        _status = addr;
      } else {
        _myAddr = addr;
        _status = 'listening';
      }
    });
    _pollTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final r = _engine.lastReceived();
      if (r.isNotEmpty && r != _receivedCipher) {
        if (_peerXPub.isEmpty) return;
        final plain = _engine.decryptFrom(_peerXPub, r);
        setState(() {
          _receivedCipher = r;
          _receivedPlain = plain;
        });
      }
    });
  }

  Future<void> _send() async {
    if (_peerOnion.isEmpty || _peerXPub.isEmpty) {
      setState(() => _status = 'scan or import a peer first');
      return;
    }
    setState(() => _status = 'encrypting + sending (~30s)...');
    final cipher = _engine.encryptFor(_peerXPub, _msgCtrl.text);
    if (cipher.startsWith('error')) {
      setState(() => _status = cipher);
      return;
    }
    final result = await Future(() => _engine.sendTo(_peerOnion, cipher));
    setState(() => _status = result);
  }

  Future<void> _showMyQr() async {
    if (_myAddr.isEmpty) {
      setState(() => _status = 'tap start listening first');
      return;
    }
    final uri = buildHaloUri(_myId, _myAddr, _myXPub);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1A0F04),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('your halo',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  )),
              const SizedBox(height: 4),
              Text(_myId,
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 18,
                    fontFamily: 'monospace',
                  )),
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
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: uri));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('uri copied')),
                  );
                },
                child: const Text('copy uri',
                    style: TextStyle(color: Color(0xFFF59E0B))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importPeer() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF201C17),
        title: const Text('paste halo:// uri',
            style: TextStyle(color: Color(0xFFF59E0B))),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
          decoration: const InputDecoration(
            hintText: 'halo://share?id=...&onion=...&xpub=...',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('import',
                style: TextStyle(color: Color(0xFFF59E0B))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final parsed = parseHaloUri(ctrl.text);
    if (parsed == null) {
      setState(() => _status = 'invalid halo:// uri');
      return;
    }
    setState(() {
      _peerId = parsed['id']!;
      _peerOnion = parsed['onion']!;
      _peerXPub = parsed['xpub']!;
      _status = 'peer imported: $_peerId';
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'halo',
                style: TextStyle(
                  fontSize: 56,
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                ),
              ),
              Text(_engine.version(),
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 16),
              const Text('your halo:',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0F04),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _myId,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFF59E0B),
                    fontSize: 18,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _myAddr.isEmpty ? _startListener : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF1A0F04),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_myAddr.isEmpty ? 'start listening' : 'listening'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.qr_code, color: Color(0xFFF59E0B)),
                      label: const Text('show my qr'),
                      onPressed: _showMyQr,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.content_paste, color: Color(0xFFA78BFA)),
                      label: const Text('import peer'),
                      onPressed: _importPeer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_peerId.isNotEmpty) ...[
                const Text('peer:',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2A1F),
                    border: Border.all(color: const Color(0xFF34D399), width: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _peerId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFF34D399),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _msgCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'message (will be encrypted)',
                  labelStyle: TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: (_myAddr.isEmpty || _peerOnion.isEmpty) ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF1A0F04),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('encrypt + send'),
              ),
              const SizedBox(height: 16),
              Text('status: $_status',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              if (_receivedPlain.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2A1F),
                    border: Border.all(color: const Color(0xFF34D399)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('decrypted:',
                          style: TextStyle(color: Color(0xFF34D399), fontSize: 10)),
                      const SizedBox(height: 4),
                      Text(_receivedPlain,
                          style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
