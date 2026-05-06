// halo mobile — phase 1: identity persistence (SQLCipher) + ECDH over tor

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

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
  late final TwoArgFnDart _restoreIdentity;
  late final CStrFnDart _myId;
  late final CStrFnDart _myEdPub;
  late final CStrFnDart _myXPub;
  late final CStrFnDart _myEdPriv;
  late final CStrFnDart _myXPriv;
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
    _restoreIdentity = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloRestoreIdentity');
    _myId = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMyId');
    _myEdPub = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMyEdPubkey');
    _myXPub = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMyXPubkey');
    _myEdPriv = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMyEdPrivkey');
    _myXPriv = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloMyXPrivkey');
    _encryptFor = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloEncryptFor');
    _decryptFrom = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloDecryptFrom');
    _start = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloStartListener');
    _lastRecv = _lib.lookupFunction<CStrFn, CStrFnDart>('HaloLastReceived');
    _send = _lib.lookupFunction<TwoArgFn, TwoArgFnDart>('HaloSendTo');
  }

  String version() => _version().toDartString();
  String generateIdentity() => _genIdentity().toDartString();
  String myId() => _myId().toDartString();
  String myEdPubkey() => _myEdPub().toDartString();
  String myXPubkey() => _myXPub().toDartString();
  String myEdPrivkey() => _myEdPriv().toDartString();
  String myXPrivkey() => _myXPriv().toDartString();
  String startListener() => _start().toDartString();
  String lastReceived() => _lastRecv().toDartString();

  String restoreIdentity(String edPriv, String xPriv) {
    final c1 = edPriv.toNativeUtf8();
    final c2 = xPriv.toNativeUtf8();
    try {
      return _restoreIdentity(c1, c2).toDartString();
    } finally {
      calloc.free(c1);
      calloc.free(c2);
    }
  }

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

// thin wrapper around SQLCipher. handles identity + contacts + messages.
class HaloDb {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _passphraseKey = 'halo.db.passphrase';

  Database? _db;

  Future<String> _passphrase() async {
    var pw = await _storage.read(key: _passphraseKey);
    if (pw != null) return pw;
    pw = _randomPassphrase();
    await _storage.write(key: _passphraseKey, value: pw);
    return pw;
  }

  String _randomPassphrase() {
    final r = DateTime.now().microsecondsSinceEpoch.toString();
    final chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    var out = StringBuffer(r);
    for (var i = 0; i < 32; i++) {
      out.write(chars[(r.codeUnitAt(i % r.length) + i) % chars.length]);
    }
    return out.toString();
  }

  Future<Database> open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'halo.db');
    final pw = await _passphrase();
    _db = await openDatabase(
      path,
      password: pw,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE identity (
            id TEXT PRIMARY KEY,
            ed_priv TEXT NOT NULL,
            x_priv TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE contacts (
            halo_id TEXT PRIMARY KEY,
            onion TEXT NOT NULL,
            xpub TEXT NOT NULL,
            first_seen INTEGER NOT NULL,
            last_seen INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            peer_id TEXT NOT NULL,
            direction TEXT NOT NULL,
            plaintext TEXT NOT NULL,
            sent_at INTEGER NOT NULL,
            FOREIGN KEY (peer_id) REFERENCES contacts(halo_id)
          )
        ''');
      },
    );
    return _db!;
  }

  Future<Map<String, String>?> loadIdentity() async {
    final db = await open();
    final rows = await db.query('identity', limit: 1);
    if (rows.isEmpty) return null;
    return {
      'id': rows.first['id'] as String,
      'ed_priv': rows.first['ed_priv'] as String,
      'x_priv': rows.first['x_priv'] as String,
    };
  }

  Future<void> saveIdentity(String id, String edPriv, String xPriv) async {
    final db = await open();
    await db.delete('identity');
    await db.insert('identity', {
      'id': id,
      'ed_priv': edPriv,
      'x_priv': xPriv,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, Object?>>> contacts() async {
    final db = await open();
    return db.query('contacts', orderBy: 'last_seen DESC');
  }

  Future<void> upsertContact(String haloId, String onion, String xpub) async {
    final db = await open();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await db.query('contacts', where: 'halo_id = ?', whereArgs: [haloId], limit: 1);
    if (existing.isEmpty) {
      await db.insert('contacts', {
        'halo_id': haloId,
        'onion': onion,
        'xpub': xpub,
        'first_seen': now,
        'last_seen': now,
      });
    } else {
      await db.update(
        'contacts',
        {'onion': onion, 'xpub': xpub, 'last_seen': now},
        where: 'halo_id = ?',
        whereArgs: [haloId],
      );
    }
  }

  Future<void> saveMessage(String peerId, String direction, String plaintext) async {
    final db = await open();
    await db.insert('messages', {
      'peer_id': peerId,
      'direction': direction,
      'plaintext': plaintext,
      'sent_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, Object?>>> messagesFor(String peerId) async {
    final db = await open();
    return db.query(
      'messages',
      where: 'peer_id = ?',
      whereArgs: [peerId],
      orderBy: 'sent_at ASC',
    );
  }
}

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
  final _db = HaloDb();
  final _msgCtrl = TextEditingController(text: 'hello from the other side');
  String _myId = '';
  String _myXPub = '';
  String _myAddr = '';
  String _status = 'loading...';
  String _peerId = '';
  String _peerOnion = '';
  String _peerXPub = '';
  String _receivedCipher = '';
  String _receivedPlain = '';
  bool _restored = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _bootIdentity();
  }

  Future<void> _bootIdentity() async {
    final saved = await _db.loadIdentity();
    String id;
    if (saved != null) {
      id = _engine.restoreIdentity(saved['ed_priv']!, saved['x_priv']!);
      _restored = true;
    } else {
      id = _engine.generateIdentity();
      await _db.saveIdentity(
        id,
        _engine.myEdPrivkey(),
        _engine.myXPrivkey(),
      );
    }
    final contacts = await _db.contacts();
    setState(() {
      _myId = id;
      _myXPub = _engine.myXPubkey();
      _status = _restored ? 'identity restored' : 'identity created';
      if (contacts.isNotEmpty) {
        final last = contacts.first;
        _peerId = last['halo_id'] as String;
        _peerOnion = last['onion'] as String;
        _peerXPub = last['xpub'] as String;
      }
    });
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
        if (!plain.startsWith('error')) {
          _db.saveMessage(_peerId, 'in', plain);
        }
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
    final plain = _msgCtrl.text;
    final cipher = _engine.encryptFor(_peerXPub, plain);
    if (cipher.startsWith('error')) {
      setState(() => _status = cipher);
      return;
    }
    final result = await Future(() => _engine.sendTo(_peerOnion, cipher));
    if (result == 'ok') {
      await _db.saveMessage(_peerId, 'out', plain);
    }
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
    await _db.upsertContact(parsed['id']!, parsed['onion']!, parsed['xpub']!);
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
                  _myId.isEmpty ? '...' : _myId,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFF59E0B),
                    fontSize: 18,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (_restored)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('restored from disk',
                      style: TextStyle(color: Color(0xFF34D399), fontSize: 9)),
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
