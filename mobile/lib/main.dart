// halo mobile — phase 0: two-instance plaintext over tor

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef CStrFn = Pointer<Utf8> Function();
typedef CStrFnDart = Pointer<Utf8> Function();

typedef SendFn = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef SendFnDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

class HaloEngine {
  late final DynamicLibrary _lib;
  late final CStrFnDart _ping;
  late final CStrFnDart _version;
  late final CStrFnDart _start;
  late final CStrFnDart _lastRecv;
  late final SendFnDart _send;

  HaloEngine() {
    _lib = Platform.isAndroid
        ? DynamicLibrary.open('libhalo.so')
        : DynamicLibrary.process();
    _ping = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloPing');
    _version = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloVersion');
    _start = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloStartListener');
    _lastRecv = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloLastReceived');
    _send = _lib.lookupFunction<SendFn, SendFnDart>('HaloSendTo');
  }

  String ping() => _ping().toDartString();
  String version() => _version().toDartString();
  String startListener() => _start().toDartString();
  String lastReceived() => _lastRecv().toDartString();

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
  String _myAddr = '';
  String _status = 'idle';
  String _received = '';
  Timer? _pollTimer;

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
      if (r.isNotEmpty && r != _received) setState(() => _received = r);
    });
  }

  Future<void> _send() async {
    final addr = _peerCtrl.text.trim();
    if (addr.isEmpty) return;
    setState(() => _status = 'sending (~30s)...');
    final result = await Future(() => _engine.sendTo(addr, _msgCtrl.text));
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
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
              const SizedBox(height: 24),
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
                GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: _myAddr));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('copied')),
                    );
                  },
                  child: Container(
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
                ),
                const Text('long-press to copy',
                    style: TextStyle(color: Colors.white24, fontSize: 10)),
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
                  labelText: 'message',
                  labelStyle: TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _myAddr.isEmpty ? null : _send,
                child: const Text('send'),
              ),
              const SizedBox(height: 16),
              Text('status: $_status',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              if (_received.isNotEmpty) ...[
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
                      const Text('received:',
                          style: TextStyle(color: Color(0xFF34D399), fontSize: 10)),
                      const SizedBox(height: 4),
                      Text(_received,
                          style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
