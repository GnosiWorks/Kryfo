// SPDX-License-Identifier: GPL-3.0-or-later
// kryfo's own signatures: xeddsa by a libsignal identity key over
//   "kryfo-sig-v1" 0x00 context 0x00 message
// with the context from the list below and nowhere else. every signed text
// starts 0x6b, libsignal signs prekeys (0x05 or 0x08 first) and alternate
// identities (0xff first), so no signature passes for one of the other kind.
// the message is always a whole body of its context's format, parsed with
// every check before anything is signed or verified, and only the key the
// body names as its signer signs it

use libsignal_protocol::IdentityKeyPair;

use crate::Error;
use crate::formats::{self, Kind};
use crate::keys::{strict_public, strict_sig};
use crate::wire::{Reader, Writer};

type R<T> = Result<T, Error>;

pub const PREFIX: &[u8] = b"kryfo-sig-v1";

// the only contexts there are, each with the format its body must parse
// as (without its own signature). face-claim comes with its format; link
// proofs carry no signature
pub const CONTEXTS: &[(&str, Kind)] = &[
    ("invite", Kind::Invite),
    ("hello", Kind::Hello),
    ("heal", Kind::Heal),
    ("device-list", Kind::DeviceList),
    ("move", Kind::Move),
];

pub fn kind_of(context: &[u8]) -> R<Kind> {
    CONTEXTS
        .iter()
        .find(|(c, _)| c.as_bytes() == context)
        .map(|(_, k)| *k)
        .ok_or(Error::Args)
}

/// the keys that may sign [message] under [kind]: the identity the body
/// names, the sending device's key for a heal, and for a move the old or
/// the new identity but never the peer's
pub fn signers(kind: Kind, message: &[u8]) -> R<Vec<Vec<u8>>> {
    Ok(match kind {
        Kind::Invite => vec![formats::invite(message, false)?.identity],
        Kind::Hello => vec![formats::hello(message, false)?.invite.identity],
        Kind::Heal => vec![formats::heal(message, false)?.signer().to_vec()],
        Kind::DeviceList => vec![formats::device_list(message, false)?.identity],
        Kind::Move => {
            let m = formats::moved(message)?;
            vec![m.old, m.new]
        }
        Kind::DeviceBundle => return Err(Error::Args),
    })
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

/// identity, context, message -> signature (64)
pub fn sign(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let pair = crate::ops::identity_pair(r.need()?)?;
    let context = r.need()?;
    let message = r.need()?;
    r.end()?;
    let allowed = signers(kind_of(context)?, message)?;
    let me = pair.identity_key().serialize();
    if !allowed.iter().any(|k| k[..] == me[..]) {
        return Err(Error::Signer);
    }
    sign_text(&pair, context, message)
}

fn sign_text(pair: &IdentityKeyPair, context: &[u8], message: &[u8]) -> R<Vec<u8>> {
    let sig = pair
        .private_key()
        .calculate_signature(&signed_text(context, message), &mut crate::ops::rng())
        .map_err(|_| Error::Key)?;
    Ok(Writer::default().bytes(&sig).done())
}

/// public, context, message, signature -> () or Signature. a body sign
/// would refuse, or a key it names in no signing role, is Signature too
pub fn verify_ctx(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let key_bytes = r.bytes()?;
    let context = r.bytes()?;
    let message = r.bytes()?;
    let sig = r.bytes()?;
    r.end()?;
    let key = strict_public(key_bytes)?;
    let kind = kind_of(context)?;
    let Ok(sig) = strict_sig(sig) else {
        return Err(Error::Signature);
    };
    let ok = signers(kind, message).is_ok_and(|s| s.iter().any(|k| k == key_bytes))
        && key.verify_signature(&signed_text(context, message), sig);
    if !ok {
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
