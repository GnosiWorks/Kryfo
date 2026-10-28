// SPDX-License-Identifier: GPL-3.0-or-later
// kryfo's own frames: the bundle block, KIN4 (invite), KHL1 (hello), KHB1
// (heal), KDL2 (device list), KDB1 (device bundle) and the move body. big
// endian, fixed widths, one encoding per value. a parse reads every field,
// refuses a key in any but its one form, encodes again and compares, and
// only then checks the signatures inside, so no signature is checked over
// bytes that read two ways. every refusal before the signatures is Format

use crate::Error;
use crate::keys::{
    KYBER_LEN, ed_sig_canonical, ed_verify, secp_lifts, strict_ed, strict_kyber, strict_public,
    strict_sig,
};
use crate::sig::signed_text;
use crate::wire::{Reader, Writer};

type R<T> = Result<T, Error>;

struct Cur<'a> {
    b: &'a [u8],
    at: usize,
}

impl<'a> Cur<'a> {
    fn new(b: &'a [u8]) -> Self {
        Cur { b, at: 0 }
    }

    fn take(&mut self, n: usize) -> R<&'a [u8]> {
        if self.b.len() - self.at < n {
            return Err(Error::Format);
        }
        let v = &self.b[self.at..self.at + n];
        self.at += n;
        Ok(v)
    }

    fn u8(&mut self) -> R<u8> {
        Ok(self.take(1)?[0])
    }

    fn u16(&mut self) -> R<u16> {
        Ok(u16::from_be_bytes(self.take(2)?.try_into().expect("2")))
    }

    fn u32(&mut self) -> R<u32> {
        Ok(u32::from_be_bytes(self.take(4)?.try_into().expect("4")))
    }

    fn u64(&mut self) -> R<u64> {
        Ok(u64::from_be_bytes(self.take(8)?.try_into().expect("8")))
    }

    fn magic(&mut self, m: &[u8; 4]) -> R<()> {
        if self.take(4)? != m {
            return Err(Error::Format);
        }
        Ok(())
    }

    fn version(&mut self) -> R<()> {
        if self.u8()? != 1 {
            return Err(Error::Format);
        }
        Ok(())
    }

    fn key(&mut self) -> R<Vec<u8>> {
        let k = self.take(33)?;
        strict_public(k).map_err(|_| Error::Format)?;
        Ok(k.to_vec())
    }

    fn sig(&mut self) -> R<Vec<u8>> {
        let s = self.take(64)?;
        strict_sig(s).map_err(|_| Error::Format)?;
        Ok(s.to_vec())
    }

    fn end(&self) -> R<()> {
        if self.at != self.b.len() {
            return Err(Error::Format);
        }
        Ok(())
    }
}

// all of [b], then the same bytes again from what was read
fn whole<T>(b: &[u8], read: impl FnOnce(&mut Cur) -> R<T>, enc: impl Fn(&T) -> Vec<u8>) -> R<T> {
    let mut c = Cur::new(b);
    let v = read(&mut c)?;
    c.end()?;
    if enc(&v) != b {
        return Err(Error::Format);
    }
    Ok(v)
}

fn xeddsa_holds(key: &[u8], context: &[u8], body: &[u8], sig: &[u8]) -> R<()> {
    let k = strict_public(key).map_err(|_| Error::Format)?;
    if strict_sig(sig).is_err() || !k.verify_signature(&signed_text(context, body), sig) {
        return Err(Error::Signature);
    }
    Ok(())
}

// the bundle block

pub const BLOCK_LEN: usize = 1744;
const BLOCK_KEY: u8 = 1;
const BLOCK_EC: u8 = 2;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Block {
    pub reg: u32,
    pub device: u8,
    /// the device key the bundle runs on; none: the frame's identity
    pub key: Option<Vec<u8>>,
    pub spk_id: u32,
    pub spk: Vec<u8>,
    pub spk_sig: Vec<u8>,
    pub kyber_id: u32,
    pub kyber: Vec<u8>,
    pub kyber_sig: Vec<u8>,
    pub ec: Option<(u32, Vec<u8>)>,
}

impl Block {
    fn read(c: &mut Cur, frame: &[u8]) -> R<Self> {
        let reg = c.u32()?;
        let device = c.u8()?;
        let flags = c.u8()?;
        if reg == 0 || !(1..=127).contains(&device) || flags & !(BLOCK_KEY | BLOCK_EC) != 0 {
            return Err(Error::Format);
        }
        let key = if flags & BLOCK_KEY != 0 {
            let k = c.key()?;
            // the frame's own identity has one form here: no key at all
            if k == frame {
                return Err(Error::Format);
            }
            Some(k)
        } else {
            None
        };
        // the phone is device 1 of every identity, and runs on the identity
        // itself; every other device has a key of its own and an id above 1
        if key.is_some() == (device == PHONE_DEVICE) {
            return Err(Error::Format);
        }
        let spk_id = c.u32()?;
        let spk = c.key()?;
        let spk_sig = c.sig()?;
        let kyber_id = c.u32()?;
        let kyber = c.take(KYBER_LEN)?;
        strict_kyber(kyber).map_err(|_| Error::Format)?;
        let kyber_sig = c.sig()?;
        let ec = if flags & BLOCK_EC != 0 {
            let id = c.u32()?;
            let k = c.key()?;
            if k == spk {
                return Err(Error::Format);
            }
            Some((id, k))
        } else {
            None
        };
        Ok(Block {
            reg,
            device,
            key,
            spk_id,
            spk,
            spk_sig,
            kyber_id,
            kyber: kyber.to_vec(),
            kyber_sig,
            ec,
        })
    }

    pub fn write(&self, out: &mut Vec<u8>) {
        let flags =
            self.key.as_ref().map_or(0, |_| BLOCK_KEY) | self.ec.as_ref().map_or(0, |_| BLOCK_EC);
        out.extend_from_slice(&self.reg.to_be_bytes());
        out.push(self.device);
        out.push(flags);
        if let Some(k) = &self.key {
            out.extend_from_slice(k);
        }
        out.extend_from_slice(&self.spk_id.to_be_bytes());
        out.extend_from_slice(&self.spk);
        out.extend_from_slice(&self.spk_sig);
        out.extend_from_slice(&self.kyber_id.to_be_bytes());
        out.extend_from_slice(&self.kyber);
        out.extend_from_slice(&self.kyber_sig);
        if let Some((id, k)) = &self.ec {
            out.extend_from_slice(&id.to_be_bytes());
            out.extend_from_slice(k);
        }
    }

    /// the key the bundle runs on and its prekeys are signed by
    pub fn signer<'a>(&'a self, frame: &'a [u8]) -> &'a [u8] {
        self.key.as_deref().unwrap_or(frame)
    }

    // both prekey signatures, as libsignal checks them
    fn check(&self, frame: &[u8]) -> R<()> {
        let k = strict_public(self.signer(frame)).map_err(|_| Error::Format)?;
        if !k.verify_signature(&self.spk, &self.spk_sig)
            || !k.verify_signature(&self.kyber, &self.kyber_sig)
        {
            return Err(Error::Signature);
        }
        Ok(())
    }

    /// the bundle ks_session_from_bundle takes, through ks_bundle_build's
    /// own checks
    pub fn bundle(&self, frame: &[u8]) -> R<Vec<u8>> {
        let mut w = Writer::default();
        w.u32(self.reg)
            .u32(self.device.into())
            .opt_u32(self.ec.as_ref().map(|e| e.0))
            .opt(self.ec.as_ref().map(|e| e.1.as_slice()))
            .u32(self.spk_id)
            .bytes(&self.spk)
            .bytes(&self.spk_sig)
            .u32(self.kyber_id)
            .bytes(&self.kyber)
            .bytes(&self.kyber_sig)
            .bytes(self.signer(frame));
        let out = crate::ops::bundle_build(&w.done())?;
        let mut r = Reader::new(&out);
        let b = r.need()?.to_vec();
        r.end()?;
        Ok(b)
    }
}

// the device list

pub const MAX_DEVICES: usize = 6;
/// the phone's device id in every identity; other devices use 2..127
pub const PHONE_DEVICE: u8 = 1;
pub const MAX_VERSION: u64 = 1 << 63;
const ENTRY_PHONE: u8 = 1;
const ENTRY_ANSWERS: u8 = 2;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Entry {
    pub device: u8,
    pub key: Vec<u8>,
    pub reg: u32,
    pub phone: bool,
    pub answers: bool,
}

impl Entry {
    pub fn flags(&self) -> u8 {
        (self.phone as u8 * ENTRY_PHONE) | (self.answers as u8 * ENTRY_ANSWERS)
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DeviceList {
    pub identity: Vec<u8>,
    pub version: u64,
    pub entries: Vec<Entry>,
    pub sig: Option<Vec<u8>>,
}

impl DeviceList {
    fn read(c: &mut Cur, signed: bool) -> R<Self> {
        c.magic(b"KDL2")?;
        let identity = c.key()?;
        let version = c.u64()?;
        let count = c.u8()? as usize;
        // versions start below 2^56 and grow by at most 2^41 a restore; the
        // top half is never reached and reads as negative in dart
        if !(1..=MAX_DEVICES).contains(&count) || version >= MAX_VERSION {
            return Err(Error::Format);
        }
        let mut entries: Vec<Entry> = Vec::with_capacity(count);
        for _ in 0..count {
            let device = c.u8()?;
            let key = c.key()?;
            let reg = c.u32()?;
            let flags = c.u8()?;
            // sorted, so each list has one order
            let after = entries.last().map_or(0, |e| e.device);
            let phone = flags & ENTRY_PHONE != 0;
            if device <= after
                || device > 127
                || phone != (device == PHONE_DEVICE)
                || reg == 0
                || flags & !(ENTRY_PHONE | ENTRY_ANSWERS) != 0
            {
                return Err(Error::Format);
            }
            entries.push(Entry {
                device,
                key,
                reg,
                phone,
                answers: flags & ENTRY_ANSWERS != 0,
            });
        }
        let phones: Vec<&Entry> = entries.iter().filter(|e| e.phone).collect();
        let answering = entries.iter().filter(|e| e.answers).count();
        // the phone runs on the identity itself, every other device on a
        // key of its own; the answering device is never the phone
        let ok = phones.len() == 1
            && phones[0].key == identity
            && !phones[0].answers
            && answering <= 1
            && entries.iter().all(|e| e.phone || e.key != identity)
            && (1..entries.len()).all(|i| entries[..i].iter().all(|o| o.key != entries[i].key));
        if !ok {
            return Err(Error::Format);
        }
        let sig = if signed { Some(c.sig()?) } else { None };
        Ok(DeviceList {
            identity,
            version,
            entries,
            sig,
        })
    }

    pub fn write(&self, out: &mut Vec<u8>) {
        self.write_body(out);
        if let Some(s) = &self.sig {
            out.extend_from_slice(s);
        }
    }

    fn write_body(&self, out: &mut Vec<u8>) {
        out.extend_from_slice(b"KDL2");
        out.extend_from_slice(&self.identity);
        out.extend_from_slice(&self.version.to_be_bytes());
        out.push(self.entries.len() as u8);
        for e in &self.entries {
            out.push(e.device);
            out.extend_from_slice(&e.key);
            out.extend_from_slice(&e.reg.to_be_bytes());
            out.push(e.flags());
        }
    }

    pub fn encode(&self) -> Vec<u8> {
        let mut out = Vec::new();
        self.write(&mut out);
        out
    }

    pub fn body(&self) -> Vec<u8> {
        let mut out = Vec::new();
        self.write_body(&mut out);
        out
    }

    pub fn answering(&self) -> Option<&Entry> {
        self.entries.iter().find(|e| e.answers)
    }

    fn check(&self) -> R<()> {
        if let Some(s) = &self.sig {
            xeddsa_holds(&self.identity, b"device-list", &self.body(), s)?;
        }
        Ok(())
    }
}

// the invite

pub const INVITE_ONE_TIME: u16 = 1;
pub const INVITE_BUNDLE: u16 = 2;
pub const INVITE_ONION: u16 = 4;
pub const INVITE_FACE: u16 = 8;
pub const INVITE_LIST: u16 = 16;
/// the longest an invite lives, in hours
pub const MAX_LIFE: u32 = 9000;
pub const FACE_TEXT: &[u8] = b"kryfo-face-v4:";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Invite {
    pub one_time: bool,
    pub issued: u32,
    pub expires: u32,
    pub id: Vec<u8>,
    pub identity: Vec<u8>,
    pub first_contact: Vec<u8>,
    pub onion: Option<Vec<u8>>,
    /// the legacy face key and its signature over FACE_TEXT, I and the id
    pub face: Option<(Vec<u8>, Vec<u8>)>,
    pub block: Option<Block>,
    pub list: Option<DeviceList>,
    pub sig: Option<Vec<u8>>,
}

impl Invite {
    pub fn flags(&self) -> u16 {
        (self.one_time as u16 * INVITE_ONE_TIME)
            | self.block.as_ref().map_or(0, |_| INVITE_BUNDLE)
            | self.onion.as_ref().map_or(0, |_| INVITE_ONION)
            | self.face.as_ref().map_or(0, |_| INVITE_FACE)
            | self.list.as_ref().map_or(0, |_| INVITE_LIST)
    }

    fn read(c: &mut Cur, signed: bool) -> R<Self> {
        c.magic(b"KIN4")?;
        c.version()?;
        let flags = c.u16()?;
        let issued = c.u32()?;
        let expires = c.u32()?;
        if flags & !0x1f != 0 || expires <= issued || expires - issued > MAX_LIFE {
            return Err(Error::Format);
        }
        let id = c.take(16)?.to_vec();
        // all zero is how a hello names a v3 link
        if id.iter().all(|&b| b == 0) {
            return Err(Error::Format);
        }
        let identity = c.key()?;
        let first_contact = c.take(32)?.to_vec();
        if !secp_lifts(&first_contact) {
            return Err(Error::Format);
        }
        let onion = if flags & INVITE_ONION != 0 {
            let o = c.take(32)?;
            strict_ed(o).map_err(|_| Error::Format)?;
            Some(o.to_vec())
        } else {
            None
        };
        let face = if flags & INVITE_FACE != 0 {
            let f = c.take(32)?;
            strict_ed(f).map_err(|_| Error::Format)?;
            let s = c.take(64)?;
            if !ed_sig_canonical(s) {
                return Err(Error::Format);
            }
            Some((f.to_vec(), s.to_vec()))
        } else {
            None
        };
        let block = if flags & INVITE_BUNDLE != 0 {
            Some(Block::read(c, &identity)?)
        } else {
            None
        };
        let list = if flags & INVITE_LIST != 0 {
            let n = c.u16()? as usize;
            let mut lc = Cur::new(c.take(n)?);
            let l = DeviceList::read(&mut lc, true)?;
            lc.end()?;
            Some(l)
        } else {
            None
        };
        let sig = if signed { Some(c.sig()?) } else { None };
        let one_time = flags & INVITE_ONE_TIME != 0;
        // a bundle on another key needs the list that vouches for it, and
        // runs on the device the list says answers
        let ok = match (&block, &list) {
            (Some(b), Some(l)) => l.answering().is_some_and(|a| {
                b.key.as_ref() == Some(&a.key) && b.device == a.device && b.reg == a.reg
            }),
            (Some(b), None) => b.key.is_none(),
            (None, Some(l)) => l.answering().is_some(),
            (None, None) => true,
        } && list.as_ref().is_none_or(|l| l.identity == identity)
            && (!one_time || block.as_ref().is_none_or(|b| b.ec.is_some()));
        if !ok {
            return Err(Error::Format);
        }
        Ok(Invite {
            one_time,
            issued,
            expires,
            id,
            identity,
            first_contact,
            onion,
            face,
            block,
            list,
            sig,
        })
    }

    fn write_body(&self, out: &mut Vec<u8>) {
        out.extend_from_slice(b"KIN4");
        out.push(1);
        out.extend_from_slice(&self.flags().to_be_bytes());
        out.extend_from_slice(&self.issued.to_be_bytes());
        out.extend_from_slice(&self.expires.to_be_bytes());
        out.extend_from_slice(&self.id);
        out.extend_from_slice(&self.identity);
        out.extend_from_slice(&self.first_contact);
        if let Some(o) = &self.onion {
            out.extend_from_slice(o);
        }
        if let Some((f, s)) = &self.face {
            out.extend_from_slice(f);
            out.extend_from_slice(s);
        }
        if let Some(b) = &self.block {
            b.write(out);
        }
        if let Some(l) = &self.list {
            let l = l.encode();
            out.extend_from_slice(&(l.len() as u16).to_be_bytes());
            out.extend_from_slice(&l);
        }
    }

    pub fn write(&self, out: &mut Vec<u8>) {
        self.write_body(out);
        if let Some(s) = &self.sig {
            out.extend_from_slice(s);
        }
    }

    pub fn encode(&self) -> Vec<u8> {
        let mut out = Vec::new();
        self.write(&mut out);
        out
    }

    pub fn body(&self) -> Vec<u8> {
        let mut out = Vec::new();
        self.write_body(&mut out);
        out
    }

    /// the key whose private half answers this invite's first contacts
    pub fn answering(&self) -> &[u8] {
        self.list
            .as_ref()
            .and_then(|l| l.answering())
            .map_or(&self.identity, |a| &a.key)
    }

    pub fn face_text(&self) -> Vec<u8> {
        [FACE_TEXT, &self.identity, &self.id].concat()
    }

    fn check(&self) -> R<()> {
        if let Some((f, s)) = &self.face {
            let f = strict_ed(f).map_err(|_| Error::Format)?;
            if !ed_verify(&f, &self.face_text(), s) {
                return Err(Error::Signature);
            }
        }
        if let Some(b) = &self.block {
            b.check(&self.identity)?;
        }
        if let Some(l) = &self.list {
            l.check()?;
        }
        if let Some(s) = &self.sig {
            xeddsa_holds(&self.identity, b"invite", &self.body(), s)?;
        }
        Ok(())
    }
}

// the hello

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Hello {
    /// the invite id answered; all zero only for a v3 link
    pub answers: Vec<u8>,
    pub owner: Vec<u8>,
    /// the sender's own one-time invite, signed
    pub invite: Invite,
    pub sig: Option<Vec<u8>>,
}

impl Hello {
    fn read(c: &mut Cur, signed: bool) -> R<Self> {
        c.magic(b"KHL1")?;
        c.version()?;
        let answers = c.take(16)?.to_vec();
        let owner = c.key()?;
        let invite = Invite::read(c, true)?;
        if !invite.one_time || invite.block.is_none() || owner == invite.identity {
            return Err(Error::Format);
        }
        let sig = if signed { Some(c.sig()?) } else { None };
        Ok(Hello {
            answers,
            owner,
            invite,
            sig,
        })
    }

    fn write_body(&self, out: &mut Vec<u8>) {
        out.extend_from_slice(b"KHL1");
        out.push(1);
        out.extend_from_slice(&self.answers);
        out.extend_from_slice(&self.owner);
        self.invite.write(out);
    }

    pub fn encode(&self) -> Vec<u8> {
        let mut out = self.body();
        if let Some(s) = &self.sig {
            out.extend_from_slice(s);
        }
        out
    }

    pub fn body(&self) -> Vec<u8> {
        let mut out = Vec::new();
        self.write_body(&mut out);
        out
    }

    fn check(&self) -> R<()> {
        self.invite.check()?;
        if let Some(s) = &self.sig {
            xeddsa_holds(&self.invite.identity, b"hello", &self.body(), s)?;
        }
        Ok(())
    }
}

// the heal

const HEAL_RESTORED: u8 = 1;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Heal {
    pub restored: bool,
    pub issued: u32,
    pub nonce: Vec<u8>,
    pub identity: Vec<u8>,
    pub peer: Vec<u8>,
    /// unix hours, a whole day; zero unless restored
    pub since: u32,
    pub block: Block,
    pub sig: Option<Vec<u8>>,
}

impl Heal {
    fn read(c: &mut Cur, signed: bool) -> R<Self> {
        c.magic(b"KHB1")?;
        c.version()?;
        let flags = c.u8()?;
        let issued = c.u32()?;
        let nonce = c.take(16)?.to_vec();
        let identity = c.key()?;
        let peer = c.key()?;
        let since = c.u32()?;
        let restored = flags & HEAL_RESTORED != 0;
        if flags & !HEAL_RESTORED != 0
            || identity == peer
            || since % 24 != 0
            || (!restored && since != 0)
        {
            return Err(Error::Format);
        }
        let block = Block::read(c, &identity)?;
        let sig = if signed { Some(c.sig()?) } else { None };
        Ok(Heal {
            restored,
            issued,
            nonce,
            identity,
            peer,
            since,
            block,
            sig,
        })
    }

    fn write_body(&self, out: &mut Vec<u8>) {
        out.extend_from_slice(b"KHB1");
        out.push(1);
        out.push(self.restored as u8 * HEAL_RESTORED);
        out.extend_from_slice(&self.issued.to_be_bytes());
        out.extend_from_slice(&self.nonce);
        out.extend_from_slice(&self.identity);
        out.extend_from_slice(&self.peer);
        out.extend_from_slice(&self.since.to_be_bytes());
        self.block.write(out);
    }

    pub fn encode(&self) -> Vec<u8> {
        let mut out = self.body();
        if let Some(s) = &self.sig {
            out.extend_from_slice(s);
        }
        out
    }

    pub fn body(&self) -> Vec<u8> {
        let mut out = Vec::new();
        self.write_body(&mut out);
        out
    }

    /// the sending device's key: the block's, or the identity on a phone
    pub fn signer(&self) -> &[u8] {
        self.block.signer(&self.identity)
    }

    fn check(&self) -> R<()> {
        self.block.check(&self.identity)?;
        if let Some(s) = &self.sig {
            xeddsa_holds(self.signer(), b"heal", &self.body(), s)?;
        }
        Ok(())
    }
}

// the device bundle, inside a session: no signature of its own

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DeviceBundle {
    pub block: Block,
}

impl DeviceBundle {
    fn read(c: &mut Cur, identity: &[u8]) -> R<Self> {
        c.magic(b"KDB1")?;
        c.version()?;
        Ok(DeviceBundle {
            block: Block::read(c, identity)?,
        })
    }

    pub fn encode(&self) -> Vec<u8> {
        let mut out = b"KDB1\x01".to_vec();
        self.block.write(&mut out);
        out
    }
}

// the move body: the old identity, the peer's, the new one, sha256 of the
// new identity's invite

pub const MOVE_LEN: usize = 33 * 3 + 32;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Move {
    pub old: Vec<u8>,
    pub peer: Vec<u8>,
    pub new: Vec<u8>,
    pub hash: Vec<u8>,
}

impl Move {
    fn read(c: &mut Cur) -> R<Self> {
        if c.b.len() != MOVE_LEN {
            return Err(Error::Format);
        }
        let (old, peer, new) = (c.key()?, c.key()?, c.key()?);
        if old == peer || old == new || peer == new {
            return Err(Error::Format);
        }
        Ok(Move {
            old,
            peer,
            new,
            hash: c.take(32)?.to_vec(),
        })
    }

    pub fn encode(&self) -> Vec<u8> {
        [&self.old[..], &self.peer, &self.new, &self.hash].concat()
    }
}

// whole frames, signatures included when [signed]

pub fn invite(b: &[u8], signed: bool) -> R<Invite> {
    let v = whole(b, |c| Invite::read(c, signed), Invite::encode)?;
    v.check()?;
    Ok(v)
}

pub fn hello(b: &[u8], signed: bool) -> R<Hello> {
    let v = whole(b, |c| Hello::read(c, signed), Hello::encode)?;
    v.check()?;
    Ok(v)
}

pub fn heal(b: &[u8], signed: bool) -> R<Heal> {
    let v = whole(b, |c| Heal::read(c, signed), Heal::encode)?;
    v.check()?;
    Ok(v)
}

pub fn device_list(b: &[u8], signed: bool) -> R<DeviceList> {
    let v = whole(b, |c| DeviceList::read(c, signed), DeviceList::encode)?;
    v.check()?;
    Ok(v)
}

/// a KDB1 of [identity]'s device: the identity's own when its block names
/// no other key
pub fn device_bundle(b: &[u8], identity: &[u8]) -> R<DeviceBundle> {
    strict_public(identity)?;
    let v = whole(b, |c| DeviceBundle::read(c, identity), DeviceBundle::encode)?;
    v.block.check(identity)?;
    Ok(v)
}

pub fn moved(b: &[u8]) -> R<Move> {
    whole(b, Move::read, Move::encode)
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Kind {
    Invite,
    Hello,
    Heal,
    DeviceList,
    DeviceBundle,
    Move,
}

/// the names ks_parse takes
pub const KINDS: &[(&str, Kind)] = &[
    ("invite", Kind::Invite),
    ("hello", Kind::Hello),
    ("heal", Kind::Heal),
    ("device-list", Kind::DeviceList),
    ("device-bundle", Kind::DeviceBundle),
    ("move", Kind::Move),
];

pub fn kind_of(name: &[u8]) -> R<Kind> {
    KINDS
        .iter()
        .find(|(n, _)| n.as_bytes() == name)
        .map(|(_, k)| *k)
        .ok_or(Error::Args)
}

// the block as twelve fields, all empty when there is none
fn put_block(w: &mut Writer, b: Option<&Block>, frame: &[u8]) -> R<()> {
    let Some(b) = b else {
        for _ in 0..12 {
            w.bytes(&[]);
        }
        return Ok(());
    };
    let bundle = b.bundle(frame)?;
    w.u32(b.reg)
        .u32(b.device.into())
        .opt(b.key.as_deref())
        .u32(b.spk_id)
        .bytes(&b.spk)
        .bytes(&b.spk_sig)
        .u32(b.kyber_id)
        .bytes(&b.kyber)
        .bytes(&b.kyber_sig)
        .opt_u32(b.ec.as_ref().map(|e| e.0))
        .opt(b.ec.as_ref().map(|e| e.1.as_slice()))
        .bytes(&bundle);
    Ok(())
}

/// format, frame, identity? -> the frame's fields, every check done. see
/// include/kryfo_signal.h for each format's fields
pub fn parse(input: &[u8]) -> R<Vec<u8>> {
    let mut r = Reader::new(input);
    let kind = kind_of(r.need()?)?;
    let b = r.bytes()?;
    let identity = r.opt()?;
    r.end()?;
    // only a device bundle takes the identity it belongs to
    if identity.is_some() != (kind == Kind::DeviceBundle) {
        return Err(Error::Args);
    }
    let mut w = Writer::default();
    match kind {
        Kind::Invite => {
            let v = invite(b, true)?;
            w.u32(v.flags().into())
                .u32(v.issued)
                .u32(v.expires)
                .bytes(&v.id)
                .bytes(&v.identity)
                .bytes(&v.first_contact)
                .opt(v.onion.as_deref())
                .opt(v.face.as_ref().map(|f| f.0.as_slice()))
                .opt(v.face.as_ref().map(|f| f.1.as_slice()))
                .opt(v.list.as_ref().map(DeviceList::encode).as_deref())
                .bytes(v.answering())
                .opt(v.sig.as_deref());
            put_block(&mut w, v.block.as_ref(), &v.identity)?;
        }
        Kind::Hello => {
            let v = hello(b, true)?;
            w.bytes(&v.answers)
                .bytes(&v.owner)
                .bytes(&v.invite.encode())
                .bytes(&v.invite.identity)
                .opt(v.sig.as_deref());
        }
        Kind::Heal => {
            let v = heal(b, true)?;
            w.u32(v.restored as u32)
                .u32(v.issued)
                .bytes(&v.nonce)
                .bytes(&v.identity)
                .bytes(&v.peer)
                .u32(v.since)
                .bytes(v.signer())
                .opt(v.sig.as_deref());
            put_block(&mut w, Some(&v.block), &v.identity)?;
        }
        Kind::DeviceList => {
            let v = device_list(b, true)?;
            w.bytes(&v.identity)
                .u64(v.version)
                .opt(v.sig.as_deref())
                .u32(v.entries.len() as u32);
            for e in &v.entries {
                w.u32(e.device.into())
                    .bytes(&e.key)
                    .u32(e.reg)
                    .u32(e.flags().into());
            }
        }
        Kind::DeviceBundle => {
            let id = identity.expect("checked");
            let v = device_bundle(b, id)?;
            w.bytes(v.block.signer(id));
            put_block(&mut w, Some(&v.block), id)?;
        }
        Kind::Move => {
            let v = moved(b)?;
            w.bytes(&v.old).bytes(&v.peer).bytes(&v.new).bytes(&v.hash);
        }
    }
    Ok(w.done())
}
