/* SPDX-License-Identifier: GPL-3.0-or-later */
/* kryfo's c abi over libsignal-protocol (see src/lib.rs and src/ops.rs).
 *
 * every call takes and gives framed fields: each field is a u32 little
 * endian length and its bytes, one after another. an empty field is an
 * absent one ("?" below); numbers are u32 (4 bytes) or u64 (8 bytes), little
 * endian. on 0 the output is in *out and must go back through ks_free; on
 * an error *out is null. nothing is kept between calls.
 *
 * identity: a serialized IdentityKeyPair whose public half is its private
 * key's. pub: a curve key in its one form: 33 bytes, 0x05 first, u below
 * 2^255 - 19 with the top bit clear, in the prime order group; any other
 * form of a key a call takes is KS_ERR_KEY. record: a serialized
 * SessionRecord, the bytes the app stores already. now and ts are
 * milliseconds since 1970. pinned?: when given, the only identity accepted
 * for the peer.
 *
 * the abi version moves on any change to a call's fields or to what a call
 * refuses.
 */
#ifndef KRYFO_SIGNAL_H
#define KRYFO_SIGNAL_H

#include <stddef.h>
#include <stdint.h>

/* what ks_abi_version returns for this header */
#define KS_ABI_VERSION 3

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
#define KS_ERR_FORMAT 11   /* a kryfo frame not in its one encoding */
#define KS_ERR_SIGNER 12   /* a key the body does not name as its signer */
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
/* pub, message, signature -> () or KS_ERR_SIGNATURE. message is a prekey's
 * public key (33 bytes 0x05 first, or 1569 bytes 0x08 first), else
 * KS_ERR_ARGS */
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
/* record, version (u32, 1 or more) -> record without the archived states
 * below version, how many went (u32). a current state below version is
 * KS_ERR_SESSION, none KS_ERR_NO_SESSION */
KS_CALL(ks_session_drop_below);
/* identity, context, message -> signature (64), xeddsa over
 * "kryfo-sig-v1" 0x00 context 0x00 message. context is one of invite,
 * hello, heal, device-list, move, else KS_ERR_ARGS. the message is the
 * whole body of that context's format without its own signature: a KIN4,
 * KHL1, KHB1 or KDL2 as ks_parse reads it, or a move body. a body that
 * does not parse is KS_ERR_FORMAT, one whose signatures inside do not
 * hold KS_ERR_SIGNATURE. the signer must be the key the body names:
 * the invite's identity, the identity of the invite inside a hello, the
 * key a heal's block runs on (the identity when it names none), the list's
 * identity, a move's old or new identity; any other is KS_ERR_SIGNER */
KS_CALL(ks_sign);
/* pub, context, message, signature -> () or KS_ERR_SIGNATURE. pub not in
 * its one form is KS_ERR_KEY; context as for ks_sign; a body ks_sign
 * would refuse, a pub the body does not name as its signer, or a
 * signature not 64 bytes with s below the group order, is
 * KS_ERR_SIGNATURE */
KS_CALL(ks_verify_ctx);
/* () -> the libsignal-protocol and spqr sources it was built from, as
 * Cargo.lock names them. this says what the lock held when it was built,
 * not what the code is: a build with replaced sources reports the same */
KS_CALL(ks_build_info);
/* format, frame, identity? -> the frame's fields, with every check done:
 * each key in its one form, the bytes the one encoding of what they say,
 * then every signature inside and the frame's own. anything off is
 * KS_ERR_FORMAT, a signature that does not hold KS_ERR_SIGNATURE. numbers
 * are u32 unless named u64; "block" is twelve fields, all empty when
 * there is no bundle: reg, device, key?, spk id, spk, spk sig, kyber id,
 * kyber, kyber sig, ec id?, ec?, then the bundle ks_session_from_bundle
 * takes. identity is given for device-bundle only.
 *   invite: flags, issued, expires, invite id, identity, first contact,
 *     onion?, face?, face sig?, device list? (a KDL2), answering key, sig,
 *     block
 *   hello: answers, owner, invite (a KIN4), sender, sig
 *   heal: restored, issued, nonce, identity, peer, since, signer, sig,
 *     block
 *   device-list: identity, version (u64), sig, n, then n times device,
 *     key, reg, flags
 *   device-bundle: the key the bundle runs on, block
 *   move: old, peer, new, invite hash */
KS_CALL(ks_parse);

#undef KS_CALL

#endif
