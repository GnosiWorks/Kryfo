// SPDX-License-Identifier: GPL-3.0-or-later
// the vault's system secret on linux: the Secret Service through libsecret,
// loaded from the system at run time and never shipped. in a flatpak
// libsecret keeps it in the app's own keyring file under the secret
// portal's per-app key
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'system_seal.dart';

/// what the keyring answered a lookup
enum KeyringFind { found, none, locked, error }

/// libsecret's few calls, behind a seam for tests. every call blocks
abstract class SecretApi {
  /// the secret stored under [attrs], as its bytes; null with [find] set
  /// to why there is none
  (Uint8List?, KeyringFind) lookup(Map<String, String> attrs);

  /// false when nothing was stored
  bool store(Map<String, String> attrs, String label, Uint8List secret);

  bool clear(Map<String, String> attrs);

  /// an item under [attrs], locked or not, found without unlocking
  /// anything; null when the keyring did not answer
  bool? there(Map<String, String> attrs);
}

const _attr = 'kryfo-vault';
const _schemaName = 'app.kryfo.Vault';

class KeyringSeal implements SystemSeal {
  KeyringSeal(this.api, {SealRunner? run}) : _run = run ?? offThread;

  final SecretApi api;
  final SealRunner _run;

  @override
  SealPlace get place => SealPlace.keyring;

  static Map<String, String> _attrs(Uint8List id) => {_attr: hexOf(id)};

  @override
  Future<bool> works() async {
    final api = this.api;
    // a name no vault has: a working keyring answers none, without a prompt
    final (_, find) = await _run(() => api.lookup({_attr: 'probe'}));
    return find == KeyringFind.none;
  }

  @override
  Future<SealedSecret> keep(Uint8List id, Uint8List secret) async {
    final api = this.api;
    final attrs = _attrs(id);
    final ok = await _run(() => api.store(attrs, 'Kryfo', secret));
    if (!ok) throw const SealError(SealFail.refused);
    return SealedSecret(SealHow.keyring, Uint8List(0));
  }

  @override
  Future<Uint8List> fetch(Uint8List id, int how, Uint8List data) async {
    if (how != SealHow.keyring) throw const SealError(SealFail.missing);
    final api = this.api;
    final attrs = _attrs(id);
    final (s, find) = await _run(() => api.lookup(attrs));
    if (s != null && s.length == 32) return s;
    s?.fillRange(0, s.length, 0);
    throw SealError(switch (find) {
      KeyringFind.locked || KeyringFind.error => SealFail.unreachable,
      _ => SealFail.missing,
    });
  }

  // libsecret clears unlocked items only, so a locked keyring keeps its
  // item for the next try and shows no prompt
  @override
  Future<bool> forget(Uint8List id) async {
    final api = this.api;
    final attrs = _attrs(id);
    return _run(() {
      final t = api.there(attrs);
      if (t == null) return false;
      if (!t) return true;
      api.clear(attrs);
      return api.there(attrs) == false;
    });
  }
}

// SecretSchemaAttribute and SecretSchema from secret-schema.h
final class _SchemaAttr extends Struct {
  external Pointer<Utf8> name;
  @Int32()
  external int type;
}

final class _Schema extends Struct {
  external Pointer<Utf8> name;
  @Int32()
  external int flags;
  @Array(32)
  external Array<_SchemaAttr> attributes;
  @Int32()
  external int reserved;
  external Pointer<Void> reserved1;
  external Pointer<Void> reserved2;
  external Pointer<Void> reserved3;
  external Pointer<Void> reserved4;
  external Pointer<Void> reserved5;
  external Pointer<Void> reserved6;
  external Pointer<Void> reserved7;
}

final class _GError extends Struct {
  @Uint32()
  external int domain;
  @Int32()
  external int code;
  external Pointer<Utf8> message;
}

typedef _HashNewC = Pointer<Void> Function(Pointer<Void>, Pointer<Void>);
typedef _InsertC = Int32 Function(Pointer<Void>, Pointer<Void>, Pointer<Void>);
typedef _Insert = int Function(Pointer<Void>, Pointer<Void>, Pointer<Void>);
typedef _UnrefC = Void Function(Pointer<Void>);
typedef _Unref = void Function(Pointer<Void>);
typedef _StoreC =
    Int32 Function(
      Pointer<_Schema>,
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Void>,
      Pointer<Pointer<_GError>>,
    );
typedef _Store =
    int Function(
      Pointer<_Schema>,
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Void>,
      Pointer<Pointer<_GError>>,
    );
typedef _LookupC =
    Pointer<Uint8> Function(
      Pointer<_Schema>,
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Pointer<_GError>>,
    );
typedef _ClearC =
    Int32 Function(
      Pointer<_Schema>,
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Pointer<_GError>>,
    );
typedef _Clear =
    int Function(
      Pointer<_Schema>,
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Pointer<_GError>>,
    );
typedef _SearchC =
    Pointer<Void> Function(
      Pointer<_Schema>,
      Pointer<Void>,
      Int32,
      Pointer<Void>,
      Pointer<Pointer<_GError>>,
    );
typedef _Search =
    Pointer<Void> Function(
      Pointer<_Schema>,
      Pointer<Void>,
      int,
      Pointer<Void>,
      Pointer<Pointer<_GError>>,
    );
typedef _LenC = Uint32 Function(Pointer<Void>);
typedef _Len = int Function(Pointer<Void>);
typedef _FreeFullC = Void Function(Pointer<Void>, Pointer<Void>);
typedef _FreeFull = void Function(Pointer<Void>, Pointer<Void>);

// SECRET_SEARCH_ALL: every match, locked or not. no SECRET_SEARCH_UNLOCK,
// so nothing is unlocked and no prompt shows
const _searchAll = 1 << 1;

/// libsecret over dart:ffi. holds only the library's name, so it can be
/// sent to the isolate that makes the call
class FfiSecretApi implements SecretApi {
  const FfiSecretApi({this.library = 'libsecret-1.so.0'});

  final String library;

  @override
  (Uint8List?, KeyringFind) lookup(Map<String, String> attrs) {
    final l = _Lib.of(library);
    if (l == null) return (null, KeyringFind.error);
    return l.withCall(attrs, (schema, table, err) {
      final p = l.lookup(schema, table, nullptr, err);
      if (err.value != nullptr) return (null, KeyringFind.error);
      if (p == nullptr) {
        // nothing came back: not there, or there and still locked
        return (null, l.lockedThere(schema, table));
      }
      try {
        var n = 0;
        while (p[n] != 0 && n < 4096) {
          n++;
        }
        final hex = p.asTypedList(n);
        if (n != 64) return (null, KeyringFind.none);
        final out = Uint8List(32);
        for (var i = 0; i < 32; i++) {
          final hi = _nibble(hex[2 * i]), lo = _nibble(hex[2 * i + 1]);
          if (hi < 0 || lo < 0) {
            out.fillRange(0, 32, 0);
            return (null, KeyringFind.none);
          }
          out[i] = hi << 4 | lo;
        }
        return (out, KeyringFind.found);
      } finally {
        // libsecret clears the memory before it frees it
        l.free(p.cast());
      }
    });
  }

  @override
  bool store(Map<String, String> attrs, String label, Uint8List secret) {
    final l = _Lib.of(library);
    if (l == null) return false;
    return l.withCall(attrs, (schema, table, err) {
      final n = secret.length * 2;
      final pw = calloc<Uint8>(n + 1);
      final lb = label.toNativeUtf8();
      try {
        const digits = '0123456789abcdef';
        for (var i = 0; i < secret.length; i++) {
          pw[2 * i] = digits.codeUnitAt(secret[i] >> 4);
          pw[2 * i + 1] = digits.codeUnitAt(secret[i] & 15);
        }
        final ok = l.store(schema, table, nullptr, lb, pw.cast(), nullptr, err);
        return ok != 0 && err.value == nullptr;
      } finally {
        pw.asTypedList(n + 1).fillRange(0, n + 1, 0);
        calloc.free(pw);
        calloc.free(lb);
      }
    });
  }

  @override
  bool? there(Map<String, String> attrs) {
    final l = _Lib.of(library);
    if (l == null) return null;
    return l.withCall(attrs, (schema, table, err) {
      return switch (l.lockedThere(schema, table)) {
        KeyringFind.locked => true,
        KeyringFind.none => false,
        _ => null,
      };
    });
  }

  @override
  bool clear(Map<String, String> attrs) {
    final l = _Lib.of(library);
    if (l == null) return false;
    return l.withCall(attrs, (schema, table, err) {
      final ok = l.clear(schema, table, nullptr, err);
      return ok != 0 && err.value == nullptr;
    });
  }
}

int _nibble(int c) {
  if (c >= 0x30 && c <= 0x39) return c - 0x30;
  if (c >= 0x61 && c <= 0x66) return c - 0x61 + 10;
  return -1;
}

class _Lib {
  _Lib._(DynamicLibrary s, DynamicLibrary g, DynamicLibrary o)
    : hashNew = g.lookupFunction<_HashNewC, _HashNewC>('g_hash_table_new'),
      insert = g.lookupFunction<_InsertC, _Insert>('g_hash_table_insert'),
      unref = g.lookupFunction<_UnrefC, _Unref>('g_hash_table_unref'),
      errorFree = g.lookupFunction<_UnrefC, _Unref>('g_error_free'),
      listLength = g.lookupFunction<_LenC, _Len>('g_list_length'),
      listFreeFull = g.lookupFunction<_FreeFullC, _FreeFull>(
        'g_list_free_full',
      ),
      strHash = g.lookup<Void>('g_str_hash'),
      strEqual = g.lookup<Void>('g_str_equal'),
      objectUnref = o.lookup<Void>('g_object_unref'),
      store = s.lookupFunction<_StoreC, _Store>('secret_password_storev_sync'),
      lookup = s.lookupFunction<_LookupC, _LookupC>(
        'secret_password_lookupv_sync',
      ),
      clear = s.lookupFunction<_ClearC, _Clear>('secret_password_clearv_sync'),
      search = s.lookupFunction<_SearchC, _Search>(
        'secret_password_searchv_sync',
      ),
      free = s.lookupFunction<_UnrefC, _Unref>('secret_password_free');

  // one per isolate
  static final _opened = <String, _Lib?>{};

  static _Lib? of(String library) => _opened.putIfAbsent(library, () {
    try {
      return _Lib._(
        DynamicLibrary.open(library),
        DynamicLibrary.open('libglib-2.0.so.0'),
        DynamicLibrary.open('libgobject-2.0.so.0'),
      );
    } catch (_) {
      return null;
    }
  });

  final Pointer<Void> Function(Pointer<Void>, Pointer<Void>) hashNew;
  final _Insert insert;
  final _Unref unref;
  final _Unref errorFree;
  final _Len listLength;
  final _FreeFull listFreeFull;
  final Pointer<Void> strHash;
  final Pointer<Void> strEqual;
  final Pointer<Void> objectUnref;
  final _Store store;
  final Pointer<Uint8> Function(
    Pointer<_Schema>,
    Pointer<Void>,
    Pointer<Void>,
    Pointer<Pointer<_GError>>,
  )
  lookup;
  final _Clear clear;
  final _Search search;
  final _Unref free;

  /// [f] with the schema, the attributes as a GHashTable and an error
  /// slot, all freed after
  T withCall<T>(
    Map<String, String> attrs,
    T Function(
      Pointer<_Schema> schema,
      Pointer<Void> table,
      Pointer<Pointer<_GError>> err,
    )
    f,
  ) {
    final held = <Pointer<Utf8>>[];
    Pointer<Utf8> keep(String s) {
      final p = s.toNativeUtf8();
      held.add(p);
      return p;
    }

    final schema = calloc<_Schema>();
    final err = calloc<Pointer<_GError>>();
    final table = hashNew(strHash, strEqual);
    try {
      schema.ref.name = keep(_schemaName);
      // SECRET_SCHEMA_NONE, one string attribute; the rest stay zero
      schema.ref.attributes[0].name = keep(_attr);
      schema.ref.attributes[0].type = 0;
      for (final e in attrs.entries) {
        insert(table, keep(e.key).cast(), keep(e.value).cast());
      }
      return f(schema, table, err);
    } finally {
      if (err.value != nullptr) errorFree(err.value.cast());
      calloc.free(err);
      unref(table);
      calloc.free(schema);
      for (final p in held) {
        calloc.free(p);
      }
    }
  }

  /// an item under [table], found by a search that unlocks nothing:
  /// locked (or not) when there is one
  KeyringFind lockedThere(Pointer<_Schema> schema, Pointer<Void> table) {
    final err = calloc<Pointer<_GError>>();
    try {
      final list = search(schema, table, _searchAll, nullptr, err);
      if (err.value != nullptr) {
        errorFree(err.value.cast());
        return KeyringFind.error;
      }
      if (list == nullptr) return KeyringFind.none;
      final n = listLength(list);
      listFreeFull(list, objectUnref);
      return n > 0 ? KeyringFind.locked : KeyringFind.none;
    } finally {
      calloc.free(err);
    }
  }
}
