// SPDX-License-Identifier: GPL-3.0-or-later
// each call: framed fields in, framed fields out (see wire.rs and
// include/kryfo_signal.h). nothing is kept between calls; the stores
// libsignal asks for are filled from the input and read back after

use std::future::Future;
use std::pin::pin;
use std::task::{Context, Poll, Waker};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use async_trait::async_trait;
use libsignal_protocol::*;
use rand::TryRngCore as _;
use rand::rngs::OsRng;

use crate::Error;
use crate::keys::{strict_kyber, strict_public, strict_sig};
use crate::record;
use crate::wire::{Reader, Writer};

type R<T> = Result<T, Error>;

// the stores below never wait, so a future here is ready on its first poll
fn block_on<F: Future>(f: F) -> F::Output {
    let mut f = pin!(f);
    let mut cx = Context::from_waker(Waker::noop());
    loop {
        if let Poll::Ready(v) = f.as_mut().poll(&mut cx) {
            return v;
        }
    }
}

pub(crate) fn rng() -> rand::rand_core::UnwrapErr<OsRng> {
    OsRng.unwrap_err()
}

fn at(ms: u64) -> SystemTime {
    UNIX_EPOCH + Duration::from_millis(ms)
}

// the names never reach a message: libsignal only binds addresses that
// parse as signal service ids
fn addr(name: &str) -> ProtocolAddress {
    ProtocolAddress::new(name.into(), DeviceId::new(1).expect("1 is a device id"))
}

/// a stored identity pair whose public half is its private key's, in its
/// one form: a pair that does not belong together would sign or open for a
/// key it does not hold
pub(crate) fn identity_pair(b: &[u8]) -> R<IdentityKeyPair> {
    let pair = IdentityKeyPair::try_from(b).map_err(|_| Error::Key)?;
    let public = pair.private_key().public_key().map_err(|_| Error::Key)?;
    if public != *pair.public_key() {
        return Err(Error::Key);
    }
    strict_public(&public.serialize())?;
    Ok(pair)
}

fn identity(b: &[u8]) -> R<IdentityKey> {
    Ok(IdentityKey::new(strict_public(b)?))
}

fn public(b: &[u8]) -> R<PublicKey> {
    strict_public(b)
}

fn session(b: &[u8]) -> R<SessionRecord> {
    SessionRecord::deserialize(b).map_err(|_| Error::Session)
}

// the stores of one call

struct Ids {
    pair: IdentityKeyPair,
    reg: u32,
    // when set, the only key trusted: anything else fails as untrusted
    pinned: Option<IdentityKey>,
    seen: Option<IdentityKey>,
}

#[async_trait(?Send)]
impl IdentityKeyStore for Ids {
    async fn get_identity_key_pair(&self) -> Result<IdentityKeyPair, SignalProtocolError> {
        Ok(self.pair)
    }
    async fn get_local_registration_id(&self) -> Result<u32, SignalProtocolError> {
        Ok(self.reg)
    }
    async fn save_identity(
        &mut self,
        _: &ProtocolAddress,
        id: &IdentityKey,
    ) -> Result<IdentityChange, SignalProtocolError> {
        self.seen = Some(*id);
        Ok(IdentityChange::NewOrUnchanged)
    }
    // trust is the app's to decide, with the key handed back; here only a pin
    async fn is_trusted_identity(
        &self,
        _: &ProtocolAddress,
        id: &IdentityKey,
        _: Direction,
    ) -> Result<bool, SignalProtocolError> {
        Ok(self.pinned.is_none_or(|p| p == *id))
    }
    async fn get_identity(
        &self,
        _: &ProtocolAddress,
    ) -> Result<Option<IdentityKey>, SignalProtocolError> {
        Ok(self.pinned.or(self.seen))
    }
}

#[derive(Default)]
struct Sessions(Option<SessionRecord>);

#[async_trait(?Send)]
impl SessionStore for Sessions {
    async fn load_session(
        &self,
        _: &ProtocolAddress,
    ) -> Result<Option<SessionRecord>, SignalProtocolError> {
        Ok(self.0.clone())
    }
    async fn store_session(
        &mut self,
        _: &ProtocolAddress,
        r: &SessionRecord,
    ) -> Result<(), SignalProtocolError> {
        self.0 = Some(r.clone());
        Ok(())
    }
}

#[derive(Default)]
struct PreKeys {
    rec: Option<PreKeyRecord>,
    used: Option<u32>,
}

#[async_trait(?Send)]
impl PreKeyStore for PreKeys {
    async fn get_pre_key(&self, id: PreKeyId) -> Result<PreKeyRecord, SignalProtocolError> {
        match &self.rec {
            Some(r) if r.id()? == id => Ok(r.clone()),
            _ => Err(SignalProtocolError::InvalidPreKeyId),
        }
    }
    async fn save_pre_key(
        &mut self,
        _: PreKeyId,
        _: &PreKeyRecord,
    ) -> Result<(), SignalProtocolError> {
        Ok(())
    }
    async fn remove_pre_key(&mut self, id: PreKeyId) -> Result<(), SignalProtocolError> {
        self.used = Some(id.into());
        Ok(())
    }
}

#[derive(Default)]
struct Signed(Option<SignedPreKeyRecord>);

#[async_trait(?Send)]
impl SignedPreKeyStore for Signed {
    async fn get_signed_pre_key(
        &self,
        id: SignedPreKeyId,
    ) -> Result<SignedPreKeyRecord, SignalProtocolError> {
        match &self.0 {
            Some(r) if r.id()? == id => Ok(r.clone()),
            _ => Err(SignalProtocolError::InvalidSignedPreKeyId),
        }
    }
    async fn save_signed_pre_key(
        &mut self,
        _: SignedPreKeyId,
        _: &SignedPreKeyRecord,
    ) -> Result<(), SignalProtocolError> {
        Ok(())
    }
}

#[derive(Default)]
struct Kybers {
    rec: Option<KyberPreKeyRecord>,
    used: Option<u32>,
}

#[async_trait(?Send)]
impl KyberPreKeyStore for Kybers {
    async fn get_kyber_pre_key(
        &self,
        id: KyberPreKeyId,
    ) -> Result<KyberPreKeyRecord, SignalProtocolError> {
        match &self.rec {
            Some(r) if r.id()? == id => Ok(r.clone()),
            _ => Err(SignalProtocolError::InvalidKyberPreKeyId),
        }
    }
    async fn save_kyber_pre_key(
        &mut self,
        _: KyberPreKeyId,
        _: &KyberPreKeyRecord,
    ) -> Result<(), SignalProtocolError> {
        Ok(())
    }
    async fn mark_kyber_pre_key_used(
        &mut self,
        id: KyberPreKeyId,
        _: SignedPreKeyId,
        _: &PublicKey,
    ) -> Result<(), SignalProtocolError> {
        self.used = Some(id.into());
        Ok(())
    }
}

fn ids(r: &mut Reader) -> R<Ids> {
    Ok(Ids {
        pair: identity_pair(r.need()?)?,
        reg: r.u32()?,
        pinned: None,
        seen: None,
    })
}

fn pin_to(ids: &mut Ids, b: Option<&[u8]>) -> R<()> {
    ids.pinned = b.map(identity).transpose()?;
    Ok(())
}

// keys

pub fn identity_generate(input: &[u8]) -> R<Vec<u8>> {
    Reader::new(input).end()?;
    let pair = IdentityKeyPair::generate(&mut rng());
    Ok(Writer::default()
        .bytes(&pair.serialize())
        .bytes(&pair.identity_key().serialize())
        .done())
}

pub fn identity_from_private(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let b = r.need()?;
    r.end()?;
    if b.len() != 32 {
        return Err(Error::Key);
    }
    let private = PrivateKey::deserialize(b).map_err(|_| Error::Key)?;
    let public = private.public_key().map_err(|_| Error::Key)?;
    let pair = IdentityKeyPair::new(IdentityKey::new(public), private);
    Ok(Writer::default()
        .bytes(&pair.serialize())
        .bytes(&pair.identity_key().serialize())
        .done())
}

pub fn prekey_generate(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let id = r.u32()?;
    r.end()?;
    let kp = KeyPair::generate(&mut rng());
    let rec = PreKeyRecord::new(id.into(), &kp);
    Ok(Writer::default()
        .bytes(&rec.serialize()?)
        .bytes(&kp.public_key.serialize())
        .done())
}

pub fn signed_prekey_generate(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let pair = identity_pair(r.need()?)?;
    let id = r.u32()?;
    let ts = r.u64()?;
    r.end()?;
    let mut rng = rng();
    let kp = KeyPair::generate(&mut rng);
    let sig = pair
        .private_key()
        .calculate_signature(&kp.public_key.serialize(), &mut rng)
        .map_err(|_| Error::Key)?;
    let rec = SignedPreKeyRecord::new(id.into(), Timestamp::from_epoch_millis(ts), &kp, &sig);
    Ok(Writer::default()
        .bytes(&rec.serialize()?)
        .bytes(&kp.public_key.serialize())
        .bytes(&sig)
        .done())
}

pub fn kyber_prekey_generate(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let pair = identity_pair(r.need()?)?;
    let id = r.u32()?;
    let ts = r.u64()?;
    r.end()?;
    let mut rng = rng();
    let kp = kem::KeyPair::generate(kem::KeyType::Kyber1024, &mut rng);
    let sig = pair
        .private_key()
        .calculate_signature(&kp.public_key.serialize(), &mut rng)
        .map_err(|_| Error::Key)?;
    let rec = KyberPreKeyRecord::new(id.into(), Timestamp::from_epoch_millis(ts), &kp, &sig);
    Ok(Writer::default()
        .bytes(&rec.serialize()?)
        .bytes(&kp.public_key.serialize())
        .bytes(&sig)
        .done())
}

// kinds of prekey record
const ONE_TIME: u32 = 0;
const SIGNED: u32 = 1;
const KYBER: u32 = 2;

/// a stored prekey's id, public key and signature (empty for a one-time key)
pub fn prekey_public(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let kind = r.u32()?;
    let b = r.need()?;
    r.end()?;
    let mut w = Writer::default();
    match kind {
        ONE_TIME => {
            let rec = PreKeyRecord::deserialize(b).map_err(|_| Error::Key)?;
            w.u32(rec.id()?.into())
                .bytes(&rec.public_key()?.serialize())
                .bytes(&[]);
        }
        SIGNED => {
            let rec = SignedPreKeyRecord::deserialize(b).map_err(|_| Error::Key)?;
            w.u32(rec.id()?.into())
                .bytes(&rec.public_key()?.serialize())
                .bytes(&rec.signature()?);
        }
        KYBER => {
            let rec = KyberPreKeyRecord::deserialize(b).map_err(|_| Error::Key)?;
            w.u32(rec.id()?.into())
                .bytes(&rec.public_key()?.serialize())
                .bytes(&rec.signature()?);
        }
        _ => return Err(Error::Args),
    }
    Ok(w.done())
}

/// an identity's signature over a prekey's public key, the one thing
/// libsignal signs with it this way: a 33 byte curve key or a 1569 byte
/// kyber key. anything else is for sig.rs, under a context
pub fn verify(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let id = strict_public(r.need()?)?;
    let msg = r.need()?;
    let sig = r.need()?;
    r.end()?;
    let prekey = matches!(msg, [0x05, ..] if msg.len() == 33)
        || matches!(msg, [0x08, ..] if msg.len() == 1569);
    if !prekey {
        return Err(Error::Args);
    }
    if strict_sig(sig).is_err() || !id.verify_signature(msg, sig) {
        return Err(Error::Signature);
    }
    Ok(Vec::new())
}

// bundles

const BUNDLE_MAGIC: &[u8; 4] = b"KSB1";

// a bundle from its fields, checked as far as it can be before use: every
// key reads, both signatures hold, and the kyber prekey is there. the fields
// come back as they will be written
fn bundle_fields(r: &mut Reader) -> R<(PreKeyBundle, Vec<u8>)> {
    let reg = r.u32()?;
    let device = r.u32()?;
    let pk_id = r.opt_u32()?;
    let pk_pub = r.opt()?;
    let spk_id = r.u32()?;
    let spk_pub = public(r.need()?)?;
    let spk_sig = r.need()?;
    let k_id = r.opt_u32()?;
    let k_pub = r.opt()?;
    let k_sig = r.opt()?;
    let id = identity(r.need()?)?;
    // no first contact without the pq prekey: libsignal would refuse it
    // later, this says why
    let (Some(k_id), Some(k_pub), Some(k_sig)) = (k_id, k_pub, k_sig) else {
        return Err(Error::Classic);
    };
    let k_pub_key = strict_kyber(k_pub)?;
    let pk = match (pk_id, pk_pub) {
        (Some(i), Some(p)) => Some((PreKeyId::from(i), public(p)?)),
        (None, None) => None,
        _ => return Err(Error::Args),
    };
    if strict_sig(spk_sig).is_err()
        || strict_sig(k_sig).is_err()
        || !id
            .public_key()
            .verify_signature(&spk_pub.serialize(), spk_sig)
        || !id.public_key().verify_signature(k_pub, k_sig)
    {
        return Err(Error::Signature);
    }
    let device_id = DeviceId::try_from(device).map_err(|_| Error::Args)?;
    let b = PreKeyBundle::new(
        reg,
        device_id,
        pk,
        spk_id.into(),
        spk_pub,
        spk_sig.to_vec(),
        k_id.into(),
        k_pub_key,
        k_sig.to_vec(),
        id,
    )?;
    let out = Writer::default()
        .u32(reg)
        .u32(device)
        .opt_u32(pk_id)
        .opt(pk_pub)
        .u32(spk_id)
        .bytes(&spk_pub.serialize())
        .bytes(spk_sig)
        .u32(k_id)
        .bytes(k_pub)
        .bytes(k_sig)
        .bytes(&id.serialize())
        .done();
    Ok((b, out))
}

fn bundle_bytes(b: &[u8]) -> R<(PreKeyBundle, Vec<u8>)> {
    let body = b.strip_prefix(BUNDLE_MAGIC).ok_or(Error::Key)?;
    let mut r = Reader::new(body);
    let out = bundle_fields(&mut r)?;
    r.end()?;
    Ok(out)
}

/// reg, device, prekey id?, prekey?, signed id, signed, signature,
/// kyber id, kyber, signature, identity -> the bundle as one value
pub fn bundle_build(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let (_, fields) = bundle_fields(&mut r)?;
    r.end()?;
    let mut b = BUNDLE_MAGIC.to_vec();
    b.extend_from_slice(&fields);
    Ok(Writer::default().bytes(&b).done())
}

/// a bundle back into its fields, checked as bundle_build checks them
pub fn bundle_parse(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let b = r.need()?;
    r.end()?;
    Ok(bundle_bytes(b)?.1)
}

// sessions

/// identity, reg, record?, bundle, now, pinned? -> record, their identity
pub fn session_from_bundle(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let mut ids = ids(&mut r)?;
    let mut sessions = Sessions(r.opt()?.map(session).transpose()?);
    let (bundle, _) = bundle_bytes(r.need()?)?;
    let now = at(r.u64()?);
    pin_to(&mut ids, r.opt()?)?;
    r.end()?;
    block_on(process_prekey_bundle(
        &addr("peer"),
        &addr("self"),
        &mut sessions,
        &mut ids,
        &bundle,
        now,
        &mut rng(),
    ))?;
    let rec = sessions.0.ok_or(Error::Internal)?;
    let seen = ids.seen.ok_or(Error::Internal)?;
    Ok(Writer::default()
        .bytes(&rec.serialize()?)
        .bytes(&seen.serialize())
        .done())
}

// message types on the wire, as both libraries number them
const WHISPER: u32 = 2;
const PREKEY: u32 = 3;

/// identity, reg, record, plaintext, now, pinned? -> type, message, record
pub fn encrypt(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let mut ids = ids(&mut r)?;
    let held = r.need()?;
    let plain = r.bytes()?;
    let now_ms = r.u64()?;
    pin_to(&mut ids, r.opt()?)?;
    r.end()?;
    let now = at(now_ms);
    // an opener the old library left undated is dated to this first send
    let mut sessions = Sessions(Some(match record::date_pending(held, now_ms)? {
        Some(dated) => session(&dated)?,
        None => session(held)?,
    }));
    let m = block_on(message_encrypt(
        plain,
        &addr("peer"),
        &addr("self"),
        &mut sessions,
        &mut ids,
        now,
        &mut rng(),
    ))?;
    let t = match m.message_type() {
        CiphertextMessageType::Whisper => WHISPER,
        CiphertextMessageType::PreKey => PREKEY,
        _ => return Err(Error::Internal),
    };
    let rec = sessions.0.ok_or(Error::Internal)?;
    Ok(Writer::default()
        .u32(t)
        .bytes(m.serialize())
        .bytes(&rec.serialize()?)
        .done())
}

fn prekey_message(b: &[u8]) -> R<PreKeySignalMessage> {
    let m = PreKeySignalMessage::try_from(b).map_err(|e| match e {
        SignalProtocolError::LegacyCiphertextVersion(_) => Error::Classic,
        _ => Error::Message,
    })?;
    // libsignal reads both keys in any form: x25519 ignores the top bit and
    // a clamped scalar kills an order 8 part, so one key would open under
    // several byte forms and come back as the peer's identity in one of them
    if !m.identity_key().public_key().is_canonical() || !m.base_key().is_canonical() {
        return Err(Error::Key);
    }
    Ok(m)
}

/// message -> version, reg, prekey id?, signed id, kyber id?, base key,
/// identity: what to load before decrypt_prekey
pub fn prekey_message_info(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let m = prekey_message(r.need()?)?;
    r.end()?;
    Ok(Writer::default()
        .u32(m.message_version().into())
        .u32(m.registration_id())
        .opt_u32(m.pre_key_id().map(Into::into))
        .u32(m.signed_pre_key_id().into())
        .opt_u32(m.kyber_pre_key_id().map(Into::into))
        .bytes(&m.base_key().serialize())
        .bytes(&m.identity_key().serialize())
        .done())
}

/// identity, reg, record?, message, prekey?, signed prekey?, kyber prekey?,
/// pinned? -> plaintext, record, prekey used?, kyber prekey used?, their
/// identity
pub fn decrypt_prekey(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let mut ids = ids(&mut r)?;
    let held = r.opt()?;
    let m = prekey_message(r.need()?)?;
    let mut pre = PreKeys {
        rec: r
            .opt()?
            .map(PreKeyRecord::deserialize)
            .transpose()
            .map_err(|_| Error::Key)?,
        used: None,
    };
    let signed = Signed(
        r.opt()?
            .map(SignedPreKeyRecord::deserialize)
            .transpose()
            .map_err(|_| Error::Key)?,
    );
    let mut kyber = Kybers {
        rec: r
            .opt()?
            .map(KyberPreKeyRecord::deserialize)
            .transpose()
            .map_err(|_| Error::Key)?,
        used: None,
    };
    pin_to(&mut ids, r.opt()?)?;
    r.end()?;
    // a pre-pq opener goes on only as a copy of one a held session was
    // built from; libsignal refuses it too, this names it apart
    let version = u32::from(m.message_version());
    let base = m.base_key().serialize();
    let known = match held {
        Some(h) => record::holds(h, version, &base)?,
        None => false,
    };
    if version < 4 && !known {
        return Err(Error::Classic);
    }
    let mut sessions = Sessions(held.map(session).transpose()?);
    let plain = block_on(message_decrypt_prekey(
        &m,
        &addr("peer"),
        &addr("self"),
        &mut sessions,
        &mut ids,
        &mut pre,
        &signed,
        &mut kyber,
        &mut rng(),
    ))?;
    let rec = sessions.0.ok_or(Error::Internal)?;
    let seen = ids.seen.ok_or(Error::Internal)?;
    Ok(Writer::default()
        .bytes(&plain)
        .bytes(&rec.serialize()?)
        .opt_u32(pre.used)
        .opt_u32(kyber.used)
        .bytes(&seen.serialize())
        .done())
}

/// identity, reg, record, message, pinned? -> plaintext, record, their
/// identity
pub fn decrypt_signal(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let mut ids = ids(&mut r)?;
    let mut sessions = Sessions(Some(session(r.need()?)?));
    let m = SignalMessage::try_from(r.need()?).map_err(|_| Error::Message)?;
    pin_to(&mut ids, r.opt()?)?;
    r.end()?;
    let plain = block_on(message_decrypt_signal(
        &m,
        &addr("peer"),
        &addr("self"),
        &mut sessions,
        &mut ids,
        &mut rng(),
    ))?;
    let rec = sessions.0.ok_or(Error::Internal)?;
    let seen = ids.seen.ok_or(Error::Internal)?;
    Ok(Writer::default()
        .bytes(&plain)
        .bytes(&rec.serialize()?)
        .bytes(&seen.serialize())
        .done())
}

/// record -> has current, version, pq ratchet, base key, their identity,
/// local reg, remote reg, archived count, then per archived state its
/// version and base key
pub fn session_info(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let b = r.need()?;
    r.end()?;
    let rec = session(b)?;
    let (cur, prev) = record::states(b)?;
    let mut w = Writer::default();
    match &cur {
        Some(s) => {
            w.u32(1)
                .u32(rec.session_version()?)
                .u32(u32::from(s.pq))
                .bytes(&s.base_key)
                .opt(rec.remote_identity_key_bytes()?.as_deref())
                .u32(rec.local_registration_id()?)
                .u32(rec.remote_registration_id()?);
        }
        None => {
            w.u32(0).u32(0).u32(0).bytes(&[]).bytes(&[]).u32(0).u32(0);
        }
    }
    w.u32(prev.len() as u32);
    for s in &prev {
        w.u32(s.version).bytes(&s.base_key);
    }
    Ok(w.done())
}

/// held, newer -> held with newer's current state in front
pub fn session_promote(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let held = r.need()?;
    let newer = r.need()?;
    r.end()?;
    Ok(Writer::default()
        .bytes(&record::promote(held, newer)?)
        .done())
}

/// record, version -> record without the archived states below version,
/// how many went. the current state must be at that version or above
pub fn session_drop_below(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let held = r.need()?;
    let min = r.u32()?;
    r.end()?;
    if min == 0 {
        return Err(Error::Args);
    }
    let (rec, dropped) = record::drop_below(held, min)?;
    Ok(Writer::default().bytes(&rec).u32(dropped).done())
}
