// halo mobile — phase 1: identity persistence + ECDH + editorial UI

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'theme.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'signal_session.dart';

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
      version: 2,
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
        await _signalTables(db);
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) await _signalTables(db);
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

Future<void> _signalTables(Database db) async {
  await db.execute('CREATE TABLE IF NOT EXISTS prekeys (id INTEGER PRIMARY KEY, record BLOB NOT NULL)');
  await db.execute('CREATE TABLE IF NOT EXISTS signed_prekeys (id INTEGER PRIMARY KEY, record BLOB NOT NULL, created_at INTEGER NOT NULL)');
  await db.execute('CREATE TABLE IF NOT EXISTS sessions (address TEXT NOT NULL, device_id INTEGER NOT NULL, record BLOB NOT NULL, PRIMARY KEY (address, device_id))');
  await db.execute('CREATE TABLE IF NOT EXISTS peer_identities (address TEXT PRIMARY KEY, identity_key BLOB NOT NULL)');
  await db.execute('CREATE TABLE IF NOT EXISTS signal_meta (k TEXT PRIMARY KEY, v TEXT NOT NULL)');
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

// shared singletons + state

final engine = HaloEngine();
final db = HaloDb();

class AppState extends ChangeNotifier {
  String myId = '';
  String myXPub = '';
  bool restored = false;
  bool ready = false;
  List<ContactPreview> contacts = [];

  Future<void> boot() async {
    final saved = await db.loadIdentity();
    if (saved != null) {
      myId = engine.restoreIdentity(saved['ed_priv']!, saved['x_priv']!);
      restored = true;
    } else {
      myId = engine.generateIdentity();
      await db.saveIdentity(myId, engine.myEdPrivkey(), engine.myXPrivkey());
    }
    myXPub = engine.myXPubkey();
    await _bootSignal();
    await refreshContacts();
    ready = true;
    notifyListeners();
  }

  Future<void> _bootSignal() async {
    try {
      final database = await db.open();
      await signalSession.bootstrap(
        database: database,
        xPubBytes: _hexDecode(engine.myXPubkey()),
        xPrivBytes: _hexDecode(engine.myXPrivkey()),
      );
    } catch (e, st) {
      debugPrint('signal bootstrap failed: $e\n$st');
    }
  }

  Uint8List _hexDecode(String s) {
    final bytes = Uint8List(s.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  Future<void> refreshContacts() async {
    final rows = await db.contacts();
    contacts = rows.map((r) {
      final ts = r['last_seen'] as int;
      return ContactPreview(
        haloId: r['halo_id'] as String,
        avatarSeed: r['halo_id'] as String,
        when: DateTime.fromMillisecondsSinceEpoch(ts),
      );
    }).toList();
    notifyListeners();
  }
}

final appState = AppState();

void main() => runApp(const HaloApp());

class HaloApp extends StatelessWidget {
  const HaloApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Halo',
      theme: buildHaloTheme(),
      home: const RootShell(),
    );
  }
}

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
    appState.boot();
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    appState.removeListener(_onChange);
    super.dispose();
  }

  void _open(Widget w) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => w));
  }

  @override
  Widget build(BuildContext context) {
    if (!appState.ready) {
      return Scaffold(
        backgroundColor: HaloColors.surface,
        body: Center(
          child: Text('booting...',
              style: HaloType.mono(size: 11, color: HaloColors.text2)),
        ),
      );
    }
    return HomeScreen(
      haloId: appState.myId,
      contacts: appState.contacts,
      onAddContact: () => _open(const DevScreen()),
      onOpenDev: () => _open(const DevScreen()),
      onOpenChat: (id) async {
        final rows = await db.contacts();
        final matches = rows.where((r) => r['halo_id'] == id).toList();
        if (matches.isEmpty || !mounted) return;
        final row = matches.first;
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
          peerHaloId: id,
          peerOnion: row['onion'] as String,
          peerXPub: row['xpub'] as String,
          avatarSeed: id,
        )));
      },
    );
  }
}

class DevScreen extends StatefulWidget {
  const DevScreen({super.key});
  @override
  State<DevScreen> createState() => _DevScreenState();
}

class _DevScreenState extends State<DevScreen> {
  final _msgCtrl = TextEditingController(text: 'hello from the other side');
  String _myAddr = '';
  String _status = '';
  String _peerId = '';
  String _peerOnion = '';
  String _peerXPub = '';
  String _receivedCipher = '';
  String _receivedPlain = '';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _status = appState.restored ? 'identity restored' : 'identity created';
    _loadLastPeer();
  }

  Future<void> _loadLastPeer() async {
    final rows = await db.contacts();
    if (rows.isEmpty) return;
    setState(() {
      _peerId = rows.first['halo_id'] as String;
      _peerOnion = rows.first['onion'] as String;
      _peerXPub = rows.first['xpub'] as String;
    });
  }

  Future<void> _startListener() async {
    setState(() => _status = 'starting tor (~30s)...');
    final addr = await Future(() => engine.startListener());
    setState(() {
      if (addr.startsWith('error')) {
        _status = addr;
      } else {
        _myAddr = addr;
        _status = 'listening';
      }
    });
    _pollTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final r = engine.lastReceived();
      if (r.isNotEmpty && r != _receivedCipher) {
        if (_peerXPub.isEmpty) return;
        final plain = engine.decryptFrom(_peerXPub, r);
        if (!plain.startsWith('error')) {
          db.saveMessage(_peerId, 'in', plain);
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
    final cipher = engine.encryptFor(_peerXPub, plain);
    if (cipher.startsWith('error')) {
      setState(() => _status = cipher);
      return;
    }
    final result = await Future(() => engine.sendTo(_peerOnion, cipher));
    if (result == 'ok') {
      await db.saveMessage(_peerId, 'out', plain);
    }
    setState(() => _status = result);
  }

  Future<void> _showMyQr() async {
    if (_myAddr.isEmpty) {
      setState(() => _status = 'tap start listening first');
      return;
    }
    final uri = buildHaloUri(appState.myId, _myAddr, appState.myXPub);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: HaloColors.onAmber,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('your halo',
                  style: HaloType.serif(
                    size: 14, italic: true, color: HaloColors.amber,
                  )),
              const SizedBox(height: 4),
              Text(appState.myId,
                  style: HaloType.mono(size: 18, color: HaloColors.amber)),
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
                child: Text('copy uri',
                    style: HaloType.sans(color: HaloColors.amber)),
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
        backgroundColor: HaloColors.surface2,
        title: Text('paste halo:// uri',
            style: HaloType.sans(color: HaloColors.amber)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          style: HaloType.mono(size: 11, color: HaloColors.text),
          decoration: InputDecoration(
            hintText: 'halo://share?id=...&onion=...&xpub=...',
            hintStyle: HaloType.mono(size: 11, color: HaloColors.text3),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('import',
                style: HaloType.sans(color: HaloColors.amber)),
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
    await db.upsertContact(parsed['id']!, parsed['onion']!, parsed['xpub']!);
    await appState.refreshContacts();
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
      backgroundColor: HaloColors.surface,
      appBar: AppBar(
        backgroundColor: HaloColors.surface,
        elevation: 0,
        title: Text('dev',
            style: HaloType.serif(size: 18, italic: true, color: HaloColors.text)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text('halo',
                  style: HaloType.serif(
                    size: 56, weight: FontWeight.w300,
                    italic: true, color: HaloColors.amber, height: 1,
                  )),
              const SizedBox(height: 4),
              Text(engine.version(),
                  style: HaloType.sans(size: 11, color: HaloColors.text3)),
              const SizedBox(height: 16),
              Text('your halo:',
                  style: HaloType.sans(size: 11, color: HaloColors.text2)),
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
                    size: 18, color: HaloColors.amber, letter: 0.04,
                  ),
                ),
              ),
              if (appState.restored)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('restored from disk',
                      style: HaloType.mono(size: 9, color: HaloColors.green)),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _myAddr.isEmpty ? _startListener : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HaloColors.amber,
                  foregroundColor: HaloColors.onAmber,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_myAddr.isEmpty ? 'start listening' : 'listening'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.qr_code, color: HaloColors.amber),
                      label: const Text('show my qr'),
                      onPressed: _showMyQr,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.content_paste, color: HaloColors.violet),
                      label: const Text('import peer'),
                      onPressed: _importPeer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_peerId.isNotEmpty) ...[
                Text('peer:',
                    style: HaloType.sans(size: 11, color: HaloColors.text2)),
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
              TextField(
                controller: _msgCtrl,
                style: HaloType.sans(color: HaloColors.text),
                decoration: InputDecoration(
                  labelText: 'message (will be encrypted)',
                  labelStyle: HaloType.sans(color: HaloColors.text2),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: (_myAddr.isEmpty || _peerOnion.isEmpty) ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HaloColors.amber,
                  foregroundColor: HaloColors.onAmber,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('encrypt + send'),
              ),
              const SizedBox(height: 16),
              Text('status: $_status',
                  style: HaloType.sans(size: 12, color: HaloColors.text2)),
              if (_receivedPlain.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HaloColors.surface3,
                    border: Border.all(color: HaloColors.green),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('decrypted:',
                          style: HaloType.mono(size: 10, color: HaloColors.green)),
                      const SizedBox(height: 4),
                      Text(_receivedPlain,
                          style: HaloType.sans(size: 14, color: HaloColors.text)),
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
