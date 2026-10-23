// SPDX-License-Identifier: GPL-3.0-or-later
// kryfo's own signatures: xeddsa by a libsignal identity key over
//   "kryfo-sig-v1" 0x00 context 0x00 message
// with the context from the list below and nowhere else. every signed text
// starts 0x6b, libsignal signs prekeys (0x05 or 0x08 first) and alternate
// identities (0xff first), so no signature passes for one of the other kind

use libsignal_protocol::{IdentityKeyPair, PublicKey};

use crate::Error;
use crate::wire::{Reader, Writer};

type R<T> = Result<T, Error>;

pub const PREFIX: &[u8] = b"kryfo-sig-v1";

// what a body must be before anything signs or checks it under a context.
// the full parse of each format comes with its format
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Body {
    /// a format that opens with this magic
    Magic(&'static [u8; 4]),
    /// the old identity, the peer's identity, sha256 of the new invite
    Move,
}

// the only contexts there are. face-claim comes with its format; link
// proofs carry no signature
pub const CONTEXTS: &[(&str, Body)] = &[
    ("invite", Body::Magic(b"KIN4")),
    ("hello", Body::Magic(b"KHL1")),
    ("heal", Body::Magic(b"KHB1")),
    ("device-list", Body::Magic(b"KDL2")),
    ("move", Body::Move),
];

pub const MOVE_LEN: usize = 33 + 33 + 32;

fn body_of(context: &[u8]) -> R<Body> {
    CONTEXTS
        .iter()
        .find(|(c, _)| c.as_bytes() == context)
        .map(|(_, b)| *b)
        .ok_or(Error::Args)
}

/// whether [message] has the shape [body] asks for
pub fn body_fits(body: Body, message: &[u8]) -> bool {
    match body {
        Body::Magic(m) => message.starts_with(m),
        // both keys in their one encoding, so one move has one body
        Body::Move => {
            message.len() == MOVE_LEN
                && strict_public(&message[..33]).is_ok()
                && strict_public(&message[33..66]).is_ok()
                && message[..33] != message[33..66]
        }
    }
}

/// the bytes a signature under [context] covers
pub fn signed_text(context: &[u8], message: &[u8]) -> Vec<u8> {
    let mut t = Vec::with_capacity(PREFIX.len() + context.len() + message.len() + 2);
    t.extend_from_slice(PREFIX);
    t.push(0);
    t.extend_from_slice(context);
    t.push(0);
    t.extend_from_slice(message);
    t
}

/// a curve key in its one encoding: 33 bytes, 0x05, u below p with the top
/// bit clear, in the prime order group. libsignal itself takes trailing
/// bytes and ignores the top bit, which gives one key several forms
pub fn strict_public(b: &[u8]) -> R<PublicKey> {
    if b.len() != 33 || b[0] != 0x05 {
        return Err(Error::Key);
    }
    let k = PublicKey::deserialize(b).map_err(|_| Error::Key)?;
    if !k.is_canonical() {
        return Err(Error::Key);
    }
    Ok(k)
}

// the group order l, little endian
const L: [u8; 32] = [
    0xed, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58, 0xd6, 0x9c, 0xf7, 0xa2, 0xde, 0xf9, 0xde, 0x14,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x10,
];

/// whether s, the signature's second half without its sign bit, is below
/// l. xeddsa verify reduces s, so s + l would pass as a second encoding
pub fn canonical_s(sig: &[u8; 64]) -> bool {
    let mut s: [u8; 32] = sig[32..].try_into().expect("32 bytes");
    s[31] &= 0x7f;
    for i in (0..32).rev() {
        if s[i] != L[i] {
            return s[i] < L[i];
        }
    }
    false
}

/// identity, context, message -> signature (64)
pub fn sign(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let pair = IdentityKeyPair::try_from(r.need()?).map_err(|_| Error::Key)?;
    let context = r.need()?;
    let message = r.need()?;
    r.end()?;
    if !body_fits(body_of(context)?, message) {
        return Err(Error::Args);
    }
    // a pair whose halves do not belong together would sign for a key it
    // does not hold
    let public = pair.private_key().public_key().map_err(|_| Error::Key)?;
    if public != *pair.public_key() {
        return Err(Error::Key);
    }
    let sig = pair
        .private_key()
        .calculate_signature(&signed_text(context, message), &mut crate::ops::rng())
        .map_err(|_| Error::Key)?;
    Ok(Writer::default().bytes(&sig).done())
}

/// public, context, message, signature -> () or Signature
pub fn verify_ctx(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let key = strict_public(r.need()?)?;
    let context = r.need()?;
    let message = r.need()?;
    let sig = r.need()?;
    r.end()?;
    let body = body_of(context)?;
    let Ok(sig) = <&[u8; 64]>::try_from(sig) else {
        return Err(Error::Signature);
    };
    if !body_fits(body, message)
        || !canonical_s(sig)
        || !key.verify_signature(&signed_text(context, message), sig)
    {
        return Err(Error::Signature);
    }
    Ok(Vec::new())
}

include!(concat!(env!("OUT_DIR"), "/build_info.rs"));

/// () -> the libsignal-protocol and spqr sources this was built from, as
/// Cargo.lock names them
pub fn build_info(input: &[u8]) -> R<Vec<u8>> {
    Reader::new(input).end()?;
    Ok(Writer::default()
        .bytes(LIBSIGNAL.as_bytes())
        .bytes(SPQR.as_bytes())
        .done())
}
