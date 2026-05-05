// halo mobile — phase 1 stage A: identity + AES-GCM over tor

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  late final OneArgFnDart _encrypt;
  late final OneArgFnDart _decrypt;
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
    _encrypt = _lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloEncrypt');
    _decrypt = _lib.lookupFunction<OneArgFn, OneArgFnDart>('HaloDecrypt');
    _start = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloStartListener');
    _lastRecv = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloLastReceived');
    _send = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloSendTo');
  }

  String version() => _version().toDartString();
  String generateIdentity() => _genIdentity().toDartString();
  String myId() => _myId().toDartString();
  String startListener() => _start().toDartString();
  String lastReceived() => _lastRecv().toDartString();

  String encrypt(String plain) {
    final c = plain.toNativeUtf8();
    try {
      return _encrypt(c).toDartString();
    } finally {
      calloc.free(c);
    }
  }

  String decrypt(String b64) {
    final c = b64.toNativeUtf8();
    try {
      return _decrypt(c).toDartString();
    } finally {
      calloc.free(c);
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
  final _peerCtrl = TextEditingController();
  final _msgCtrl = TextEditingController(text: 'hello from the other side');
  String _myId = '';
  String _myAddr = '';
  String _status = 'idle';
  String _receivedCipher = '';
  String _receivedPlain = '';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _myId = _engine.generateIdentity();
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
        final plain = _engine.decrypt(r);
        setState(() {
          _receivedCipher = r;
          _receivedPlain = plain;
        });
      }
    });
  }

  Future<void> _send() async {
    final addr = _peerCtrl.text.trim();
    if (addr.isEmpty) return;
    setState(() => _status = 'encrypting + sending (~30s)...');
    final cipher = _engine.encrypt(_msgCtrl.text);
    final result = await Future(() => _engine.sendTo(addr, cipher));
    setState(() => _status = result);
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
              const SizedBox(height: 20),
              const Text(
                'halo',
                style: TextStyle(
                  fontSize: 56,
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 4),
              Text(_engine.version(),
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 20),
              const Text('your halo:',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              GestureDetector(
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: _myId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('copied')),
                  );
                },
                child: Container(
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
              ),
              const SizedBox(height: 20),
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
              if (_myAddr.isNotEmpty) ...[
                const Text('your address:',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF201C17),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _myAddr,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFFF59E0B),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: _peerCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  labelText: 'peer .onion address',
                  labelStyle: TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
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
              OutlinedButton(
                onPressed: _myAddr.isEmpty ? null : _send,
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
                      const SizedBox(height: 8),
                      const Text('ciphertext (b64):',
                          style: TextStyle(color: Colors.white38, fontSize: 9)),
                      const SizedBox(height: 2),
                      Text(_receivedCipher,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.white38,
                            fontSize: 9,
                          )),
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
