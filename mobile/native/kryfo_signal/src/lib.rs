// SPDX-License-Identifier: GPL-3.0-or-later
// kryfo's c abi over libsignal-protocol. every call is
//   int32_t ks_<op>(const uint8_t *in, size_t in_len,
//                   uint8_t **out, size_t *out_len)
// with framed fields both ways (wire.rs), an error code back, and the
// output freed with ks_free. nothing is logged: no logger is ever set, so
// libsignal's log lines go nowhere, and a panic stops at the boundary

use std::panic::{AssertUnwindSafe, catch_unwind};
#[cfg(not(test))]
use std::sync::Once;

use libsignal_protocol::SignalProtocolError;

mod ops;
mod record;
mod wire;

pub use ops::*;

/// bump on any change to a call's fields
pub const ABI_VERSION: u32 = 1;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(i32)]
pub enum Error {
    /// framing, a missing field, a number of the wrong width
    Args = 1,
    /// a key or prekey record that does not read
    Key = 2,
    /// a prekey signature that does not hold
    Signature = 3,
    /// a message that does not read or authenticate
    Message = 4,
    NoSession = 5,
    Duplicate = 6,
    /// not the pinned identity
    Untrusted = 7,
    /// the message names a prekey that was not given
    NoPrekey = 8,
    /// a first contact without the pq prekey: a bundle with none, or a
    /// pre-pq opener for a session not held
    Classic = 9,
    /// a session record that does not read, or a state that cannot be used
    Session = 10,
    Panic = 98,
    Internal = 99,
}

impl From<SignalProtocolError> for Error {
    fn from(e: SignalProtocolError) -> Self {
        use SignalProtocolError as E;
        match e {
            E::InvalidArgument(_) => Error::Args,
            E::NoKeyTypeIdentifier
            | E::BadKeyType(_)
            | E::BadKeyLength(..)
            | E::BadKEMKeyType(_)
            | E::WrongKEMKeyType(..)
            | E::BadKEMKeyLength(..)
            | E::InvalidProtobufEncoding => Error::Key,
            E::SignatureValidationFailed => Error::Signature,
            E::UntrustedIdentity(_) => Error::Untrusted,
            E::InvalidPreKeyId | E::InvalidSignedPreKeyId | E::InvalidKyberPreKeyId => {
                Error::NoPrekey
            }
            E::SessionNotFound(_) => Error::NoSession,
            E::InvalidSessionStructure(_) | E::InvalidState(..) => Error::Session,
            E::DuplicatedMessage(..) => Error::Duplicate,
            E::LegacyCiphertextVersion(_) => Error::Classic,
            E::InvalidMessage(..)
            | E::CiphertextMessageTooShort(_)
            | E::UnrecognizedCiphertextVersion(_)
            | E::UnrecognizedMessageVersion(_)
            | E::InvalidKeyAgreement
            | E::InvalidMacKeyLength(_)
            | E::BadKEMCiphertextLength(..) => Error::Message,
            _ => Error::Internal,
        }
    }
}

pub type Op = fn(&[u8]) -> Result<Vec<u8>, Error>;

#[cfg(not(test))]
static QUIET: Once = Once::new();

/// [op] on the input, its output handed over in [out]. never unwinds
///
/// # Safety
/// [inp] is null with [len] 0, or points at [len] readable bytes; [out] and
/// [out_len] point at writable slots
pub unsafe fn call(
    op: Op,
    inp: *const u8,
    len: usize,
    out: *mut *mut u8,
    out_len: *mut usize,
) -> i32 {
    // the default hook prints the panic's text, which may carry a value.
    // tests keep it, so their own failures still say why
    #[cfg(not(test))]
    QUIET.call_once(|| std::panic::set_hook(Box::new(|_| {})));
    if out.is_null() || out_len.is_null() || (inp.is_null() && len != 0) {
        return Error::Args as i32;
    }
    unsafe {
        *out = std::ptr::null_mut();
        *out_len = 0;
    }
    let input: &[u8] = if len == 0 {
        &[]
    } else {
        unsafe { std::slice::from_raw_parts(inp, len) }
    };
    match catch_unwind(AssertUnwindSafe(|| op(input))) {
        Ok(Ok(v)) => {
            let b = v.into_boxed_slice();
            let n = b.len();
            unsafe {
                *out = Box::into_raw(b) as *mut u8;
                *out_len = n;
            }
            0
        }
        Ok(Err(e)) => e as i32,
        Err(_) => Error::Panic as i32,
    }
}

/// an output of any call, wiped and given back
///
/// # Safety
/// [p] and [n] as a call handed them out, freed once
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ks_free(p: *mut u8, n: usize) {
    if p.is_null() {
        return;
    }
    let _ = catch_unwind(|| unsafe {
        for i in 0..n {
            std::ptr::write_volatile(p.add(i), 0);
        }
        drop(Box::from_raw(std::ptr::slice_from_raw_parts_mut(p, n)));
    });
}

#[unsafe(no_mangle)]
pub extern "C" fn ks_abi_version() -> u32 {
    ABI_VERSION
}

macro_rules! export {
    ($($name:ident => $op:path),* $(,)?) => {$(
        /// # Safety
        /// see [call]
        #[unsafe(no_mangle)]
        pub unsafe extern "C" fn $name(
            inp: *const u8,
            len: usize,
            out: *mut *mut u8,
            out_len: *mut usize,
        ) -> i32 {
            unsafe { call($op, inp, len, out, out_len) }
        }
    )*};
}

export! {
    ks_identity_generate => ops::identity_generate,
    ks_identity_from_private => ops::identity_from_private,
    ks_prekey_generate => ops::prekey_generate,
    ks_signed_prekey_generate => ops::signed_prekey_generate,
    ks_kyber_prekey_generate => ops::kyber_prekey_generate,
    ks_prekey_public => ops::prekey_public,
    ks_verify => ops::verify,
    ks_bundle_build => ops::bundle_build,
    ks_bundle_parse => ops::bundle_parse,
    ks_session_from_bundle => ops::session_from_bundle,
    ks_encrypt => ops::encrypt,
    ks_prekey_message_info => ops::prekey_message_info,
    ks_decrypt_prekey => ops::decrypt_prekey,
    ks_decrypt_signal => ops::decrypt_signal,
    ks_session_info => ops::session_info,
    ks_session_promote => ops::session_promote,
}

#[cfg(test)]
mod tests;
