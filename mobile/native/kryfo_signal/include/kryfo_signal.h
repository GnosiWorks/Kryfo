/* SPDX-License-Identifier: GPL-3.0-or-later */
/* kryfo's c abi over libsignal-protocol (see src/lib.rs and src/ops.rs).
 *
 * every call takes and gives framed fields: each field is a u32 little
 * endian length and its bytes, one after another. an empty field is an
 * absent one ("?" below); numbers are u32 (4 bytes) or u64 (8 bytes), little
 * endian. on 0 the output is in *out and must go back through ks_free; on
 * an error *out is null. nothing is kept between calls.
 *
 * identity: a serialized IdentityKeyPair. pub: a 33 byte curve key (0x05
 * first). record: a serialized SessionRecord, the bytes the app stores
 * already. now and ts are milliseconds since 1970. pinned?: when given,
 * the only identity accepted for the peer.
 */
#ifndef KRYFO_SIGNAL_H
#define KRYFO_SIGNAL_H

#include <stddef.h>
#include <stdint.h>

#define KS_OK 0
#define KS_ERR_ARGS 1      /* framing, a missing field, a wrong width */
#define KS_ERR_KEY 2       /* a key or prekey record that does not read */
#define KS_ERR_SIGNATURE 3 /* a prekey signature that does not hold */
#define KS_ERR_MESSAGE 4   /* a message that does not read or authenticate */
#define KS_ERR_NO_SESSION 5
#define KS_ERR_DUPLICATE 6
#define KS_ERR_UNTRUSTED 7 /* not the pinned identity */
#define KS_ERR_NO_PREKEY 8 /* the message names a prekey not given */
#define KS_ERR_CLASSIC 9   /* no kyber prekey, or a version 3 opener */
#define KS_ERR_SESSION 10  /* a record that does not read or cannot be used */
#define KS_ERR_PANIC 98
#define KS_ERR_INTERNAL 99

#define KS_MSG_WHISPER 2
#define KS_MSG_PREKEY 3

#define KS_PREKEY_ONE_TIME 0
#define KS_PREKEY_SIGNED 1
#define KS_PREKEY_KYBER 2

uint32_t ks_abi_version(void);
void ks_free(uint8_t *p, size_t n);

#define KS_CALL(name) \
  int32_t name(const uint8_t *in, size_t in_len, uint8_t **out, size_t *out_len)

/* () -> identity, pub */
KS_CALL(ks_identity_generate);
/* private (32) -> identity, pub */
KS_CALL(ks_identity_from_private);
/* id -> record, pub */
KS_CALL(ks_prekey_generate);
/* identity, id, ts -> record, pub, signature */
KS_CALL(ks_signed_prekey_generate);
/* identity, id, ts -> record, pub (kyber1024, 1569), signature */
KS_CALL(ks_kyber_prekey_generate);
/* kind, record -> id, pub, signature (empty for a one-time key) */
KS_CALL(ks_prekey_public);
/* pub, message, signature -> () or KS_ERR_SIGNATURE */
KS_CALL(ks_verify);
/* reg, device, prekey id?, prekey?, signed id, signed, signature,
 * kyber id, kyber, kyber signature, identity pub -> bundle.
 * both signatures are checked; no kyber is KS_ERR_CLASSIC */
KS_CALL(ks_bundle_build);
/* bundle -> the eleven fields ks_bundle_build takes, checked again */
KS_CALL(ks_bundle_parse);
/* identity, reg, record?, bundle, now, pinned? -> record, their pub */
KS_CALL(ks_session_from_bundle);
/* identity, reg, record, plaintext, now, pinned? -> type, message, record */
KS_CALL(ks_encrypt);
/* message -> version, reg, prekey id?, signed id, kyber id?, base key,
 * their pub: which records to load for ks_decrypt_prekey */
KS_CALL(ks_prekey_message_info);
/* identity, reg, record?, message, prekey?, signed prekey?, kyber prekey?,
 * pinned? -> plaintext, record, prekey used?, kyber prekey used?, their pub */
KS_CALL(ks_decrypt_prekey);
/* identity, reg, record, message, pinned? -> plaintext, record, their pub */
KS_CALL(ks_decrypt_signal);
/* record -> has current, version, pq ratchet, base key, their pub?, local
 * reg, remote reg, n, then n times (version, base key) of archived states */
KS_CALL(ks_session_info);
/* held, newer -> held with newer's current state in front */
KS_CALL(ks_session_promote);

#undef KS_CALL

#endif
