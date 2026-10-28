// SPDX-License-Identifier: GPL-3.0-or-later
use std::collections::HashMap;

use libsignal_protocol::IdentityKeyPair;

use crate::wire::{Reader, Writer};
use crate::*;

pub(crate) const NOW: u64 = 1_760_000_000_000;

#[test]
fn an_undated_classic_opener_still_goes_out() {
    let f = fixture();
    let rec = &f["alice_pending_rec"];
    // as the old library left it: an opener with no time on it
    assert!(record::date_pending(rec, NOW).unwrap().is_some());
    let m = run(
        encrypt,
        w().bytes(&f["alice_id"])
            .u32(11)
            .bytes(rec)
            .bytes(b"to dave")
            .u64(NOW)
            .opt(None),
    )
    .unwrap();
    assert_eq!(u32_of(&m[0]), 3);
    let info = run(prekey_message_info, w().bytes(&m[1])).unwrap();
    assert_eq!(u32_of(&info[0]), 3);
    assert_eq!(u32_of(&info[2]), 5);
    // dated now, the record needs nothing more, and goes stale after 30 days
    assert!(record::date_pending(&m[2], NOW).unwrap().is_none());
    let later = NOW + 31 * 24 * 3600 * 1000;
    let mut x = w();
    x.bytes(&f["alice_id"])
        .u32(11)
        .bytes(&m[2])
        .bytes(b"late")
        .u64(later)
        .opt(None);
    assert_eq!(run(encrypt, &mut x), Err(Error::NoSession));
    // an answered session has no opener to date
    assert!(
        record::date_pending(&f["alice_rec"], NOW)
            .unwrap()
            .is_none()
    );
}

pub(crate) fn run(op: Op, w: &mut Writer) -> Result<Vec<Vec<u8>>, Error> {
    let input = w.done();
    let mut out = std::ptr::null_mut();
    let mut n = 0;
    let code = unsafe { call(op, input.as_ptr(), input.len(), &mut out, &mut n) };
    assert_ne!(code, Error::Panic as i32, "a panic crossed into the call");
    if code != 0 {
        assert!(out.is_null());
        return Err(match code {
            1 => Error::Args,
            2 => Error::Key,
            3 => Error::Signature,
            4 => Error::Message,
            5 => Error::NoSession,
            6 => Error::Duplicate,
            7 => Error::Untrusted,
            8 => Error::NoPrekey,
            9 => Error::Classic,
            10 => Error::Session,
            11 => Error::Format,
            12 => Error::Signer,
            _ => Error::Internal,
        });
    }
    let bytes = unsafe { std::slice::from_raw_parts(out, n) }.to_vec();
    unsafe { ks_free(out, n) };
    let mut r = Reader::new(&bytes);
    let mut fields = Vec::new();
    while !r.is_done() {
        fields.push(r.bytes().unwrap().to_vec());
    }
    Ok(fields)
}

pub(crate) fn u32_of(b: &[u8]) -> u32 {
    u32::from_le_bytes(b.try_into().unwrap())
}

pub(crate) fn w() -> Writer {
    Writer::default()
}

pub(crate) struct Party {
    pub(crate) pair: Vec<u8>,
    pub(crate) public: Vec<u8>,
    pub(crate) reg: u32,
    pub(crate) pk: Vec<u8>,
    pub(crate) spk: Vec<u8>,
    pub(crate) kyber: Vec<u8>,
}

impl Party {
    pub(crate) fn new(reg: u32) -> Self {
        let id = run(identity_generate, &mut w()).unwrap();
        let pk = run(prekey_generate, w().u32(7)).unwrap();
        let spk = run(signed_prekey_generate, w().bytes(&id[0]).u32(1).u64(NOW)).unwrap();
        let kyber = run(kyber_prekey_generate, w().bytes(&id[0]).u32(2).u64(NOW)).unwrap();
        Party {
            pair: id[0].clone(),
            public: id[1].clone(),
            reg,
            pk: pk[0].clone(),
            spk: spk[0].clone(),
            kyber: kyber[0].clone(),
        }
    }

    // the fields bundle_build takes, from this party's records
    pub(crate) fn bundle_fields(&self, with_kyber: bool) -> Writer {
        let pk = run(prekey_public, w().u32(0).bytes(&self.pk)).unwrap();
        let spk = run(prekey_public, w().u32(1).bytes(&self.spk)).unwrap();
        let k = run(prekey_public, w().u32(2).bytes(&self.kyber)).unwrap();
        let mut f = w();
        f.u32(self.reg)
            .u32(1)
            .bytes(&pk[0])
            .bytes(&pk[1])
            .bytes(&spk[0])
            .bytes(&spk[1])
            .bytes(&spk[2]);
        if with_kyber {
            f.bytes(&k[0]).bytes(&k[1]).bytes(&k[2]);
        } else {
            f.opt(None).opt(None).opt(None);
        }
        f.bytes(&self.public);
        f
    }

    pub(crate) fn bundle(&self) -> Vec<u8> {
        run(bundle_build, &mut self.bundle_fields(true))
            .unwrap()
            .remove(0)
    }
}

// alice opens to bob from his bundle; both records after the first
// message, and that message
fn opened(alice: &Party, bob: &Party) -> (Vec<u8>, Vec<u8>, Vec<Vec<u8>>) {
    let s = run(
        session_from_bundle,
        w().bytes(&alice.pair)
            .u32(alice.reg)
            .opt(None)
            .bytes(&bob.bundle())
            .u64(NOW)
            .opt(None),
    )
    .unwrap();
    assert_eq!(s[1], bob.public);
    let m = run(
        encrypt,
        w().bytes(&alice.pair)
            .u32(alice.reg)
            .bytes(&s[0])
            .bytes(b"hello")
            .u64(NOW)
            .opt(None),
    )
    .unwrap();
    assert_eq!(u32_of(&m[0]), 3);
    let d = run(
        decrypt_prekey,
        w().bytes(&bob.pair)
            .u32(bob.reg)
            .opt(None)
            .bytes(&m[1])
            .bytes(&bob.pk)
            .bytes(&bob.spk)
            .bytes(&bob.kyber)
            .opt(None),
    )
    .unwrap();
    assert_eq!(d[0], b"hello");
    (m[2].clone(), d[1].clone(), d)
}

#[test]
fn pqxdh_both_ways() {
    let alice = Party::new(11);
    let bob = Party::new(22);
    let (mut a, mut b, d) = opened(&alice, &bob);
    // the one-time and kyber prekeys it used, and who sent it
    assert_eq!(u32_of(&d[2]), 7);
    assert_eq!(u32_of(&d[3]), 2);
    assert_eq!(d[4], alice.public);
    for i in 0..5u8 {
        let m = run(
            encrypt,
            w().bytes(&bob.pair)
                .u32(22)
                .bytes(&b)
                .bytes(&[i; 9])
                .u64(NOW)
                .opt(None),
        )
        .unwrap();
        assert_eq!(u32_of(&m[0]), 2);
        b = m[2].clone();
        let p = run(
            decrypt_signal,
            w().bytes(&alice.pair)
                .u32(11)
                .bytes(&a)
                .bytes(&m[1])
                .opt(None),
        )
        .unwrap();
        assert_eq!(p[0], vec![i; 9]);
        assert_eq!(p[2], bob.public);
        a = p[1].clone();
        let m = run(
            encrypt,
            w().bytes(&alice.pair)
                .u32(11)
                .bytes(&a)
                .bytes(&[i; 3])
                .u64(NOW)
                .opt(None),
        )
        .unwrap();
        // answered, so no longer a prekey message
        assert_eq!(u32_of(&m[0]), 2);
        a = m[2].clone();
        let p = run(
            decrypt_signal,
            w().bytes(&bob.pair)
                .u32(22)
                .bytes(&b)
                .bytes(&m[1])
                .opt(None),
        )
        .unwrap();
        assert_eq!(p[0], vec![i; 3]);
        b = p[1].clone();
    }
    for rec in [&a, &b] {
        let info = run(session_info, w().bytes(rec)).unwrap();
        assert_eq!(u32_of(&info[0]), 1);
        assert_eq!(u32_of(&info[1]), 4, "pqxdh session");
        assert_eq!(u32_of(&info[2]), 1, "spqr state held");
    }
    let info = run(session_info, w().bytes(&a)).unwrap();
    assert_eq!(info[4], bob.public);
    assert_eq!(u32_of(&info[5]), 11);
    assert_eq!(u32_of(&info[6]), 22);
}

#[test]
fn a_message_opens_once() {
    let alice = Party::new(1);
    let bob = Party::new(2);
    let (a, b, _) = opened(&alice, &bob);
    let m = run(
        encrypt,
        w().bytes(&alice.pair)
            .u32(1)
            .bytes(&a)
            .bytes(b"x")
            .u64(NOW)
            .opt(None),
    )
    .unwrap();
    // still unanswered: a prekey message on the same session
    assert_eq!(u32_of(&m[0]), 3);
    let in1 = || {
        let mut f = w();
        f.bytes(&bob.pair)
            .u32(2)
            .bytes(&b)
            .bytes(&m[1])
            .opt(None)
            .bytes(&bob.spk)
            .bytes(&bob.kyber)
            .opt(None);
        f
    };
    let d = run(decrypt_prekey, &mut in1()).unwrap();
    assert_eq!(d[0], b"x");
    // the session was held, so no prekey was spent on this one
    assert!(d[2].is_empty() && d[3].is_empty());
    let mut again = w();
    again
        .bytes(&bob.pair)
        .u32(2)
        .bytes(&d[1])
        .bytes(&m[1])
        .opt(None)
        .bytes(&bob.spk)
        .bytes(&bob.kyber)
        .opt(None);
    assert_eq!(run(decrypt_prekey, &mut again), Err(Error::Duplicate));
}

#[test]
fn a_missing_prekey_is_named() {
    let alice = Party::new(1);
    let bob = Party::new(2);
    let s = run(
        session_from_bundle,
        w().bytes(&alice.pair)
            .u32(1)
            .opt(None)
            .bytes(&bob.bundle())
            .u64(NOW)
            .opt(None),
    )
    .unwrap();
    let m = run(
        encrypt,
        w().bytes(&alice.pair)
            .u32(1)
            .bytes(&s[0])
            .bytes(b"x")
            .u64(NOW)
            .opt(None),
    )
    .unwrap();
    let info = run(prekey_message_info, w().bytes(&m[1])).unwrap();
    assert_eq!(u32_of(&info[0]), 4);
    assert_eq!(u32_of(&info[1]), 1);
    assert_eq!(u32_of(&info[2]), 7);
    assert_eq!(u32_of(&info[3]), 1);
    assert_eq!(u32_of(&info[4]), 2);
    assert_eq!(info[6], alice.public);
    for (pk, spk, k) in [
        (None, Some(&bob.spk), Some(&bob.kyber)),
        (Some(&bob.pk), None, Some(&bob.kyber)),
        (Some(&bob.pk), Some(&bob.spk), None),
    ] {
        let mut f = w();
        f.bytes(&bob.pair)
            .u32(2)
            .opt(None)
            .bytes(&m[1])
            .opt(pk.map(|v| v.as_slice()))
            .opt(spk.map(|v| v.as_slice()))
            .opt(k.map(|v| v.as_slice()))
            .opt(None);
        assert_eq!(run(decrypt_prekey, &mut f), Err(Error::NoPrekey));
    }
}

#[test]
fn a_pin_holds() {
    let alice = Party::new(1);
    let bob = Party::new(2);
    let carol = Party::new(3);
    let mut f = w();
    f.bytes(&alice.pair)
        .u32(1)
        .opt(None)
        .bytes(&bob.bundle())
        .u64(NOW)
        .bytes(&carol.public);
    assert_eq!(run(session_from_bundle, &mut f), Err(Error::Untrusted));
    let (a, b, _) = opened(&alice, &bob);
    let mut f = w();
    f.bytes(&alice.pair)
        .u32(1)
        .bytes(&a)
        .bytes(b"x")
        .u64(NOW)
        .bytes(&carol.public);
    assert_eq!(run(encrypt, &mut f), Err(Error::Untrusted));
    let m = run(
        encrypt,
        w().bytes(&bob.pair)
            .u32(2)
            .bytes(&b)
            .bytes(b"y")
            .u64(NOW)
            .bytes(&alice.public),
    )
    .unwrap();
    let mut f = w();
    f.bytes(&alice.pair)
        .u32(1)
        .bytes(&a)
        .bytes(&m[1])
        .bytes(&carol.public);
    assert_eq!(run(decrypt_signal, &mut f), Err(Error::Untrusted));
    let p = run(
        decrypt_signal,
        w().bytes(&alice.pair)
            .u32(1)
            .bytes(&a)
            .bytes(&m[1])
            .bytes(&bob.public),
    )
    .unwrap();
    assert_eq!(p[0], b"y");
}

#[test]
fn no_bundle_without_kyber() {
    let bob = Party::new(2);
    assert_eq!(
        run(bundle_build, &mut bob.bundle_fields(false)),
        Err(Error::Classic)
    );
}

#[test]
fn a_stripped_bundle_fails() {
    let alice = Party::new(1);
    let bob = Party::new(2);
    let fields = run(bundle_parse, w().bytes(&bob.bundle())).unwrap();
    assert_eq!(fields.len(), 11);
    let rebuild = |f: &[Vec<u8>]| {
        let mut x = w();
        for v in f {
            x.bytes(v);
        }
        run(bundle_build, &mut x)
    };
    assert_eq!(rebuild(&fields).unwrap()[0], bob.bundle());

    // kyber part taken out
    let mut f = fields.clone();
    f[7].clear();
    f[8].clear();
    f[9].clear();
    assert_eq!(rebuild(&f), Err(Error::Classic));
    // its signature broken
    let mut f = fields.clone();
    f[9][5] ^= 1;
    assert_eq!(rebuild(&f), Err(Error::Signature));
    // another kyber key under the old signature
    let other = run(
        kyber_prekey_generate,
        w().bytes(&alice.pair).u32(2).u64(NOW),
    )
    .unwrap();
    let mut f = fields.clone();
    f[8] = other[1].clone();
    assert_eq!(rebuild(&f), Err(Error::Signature));
    // a signature by someone else
    let mut f = fields.clone();
    f[9] = other[2].clone();
    assert_eq!(rebuild(&f), Err(Error::Signature));
    // the signed prekey's signature broken
    let mut f = fields.clone();
    f[6][0] ^= 1;
    assert_eq!(rebuild(&f), Err(Error::Signature));

    // a built bundle edited after the fact is read as strictly
    let mut b = bob.bundle();
    let n = b.len();
    b[n - 40] ^= 1;
    let mut f = w();
    f.bytes(&alice.pair)
        .u32(1)
        .opt(None)
        .bytes(&b)
        .u64(NOW)
        .opt(None);
    assert!(run(session_from_bundle, &mut f).is_err());
    // and one cut short of its kyber fields does not read
    let mut x = b"KSB1".to_vec();
    let mut short = w();
    for v in &fields[..7] {
        short.bytes(v);
    }
    x.extend(short.done());
    let mut f = w();
    f.bytes(&alice.pair)
        .u32(1)
        .opt(None)
        .bytes(&x)
        .u64(NOW)
        .opt(None);
    assert!(run(session_from_bundle, &mut f).is_err());
}

#[test]
fn identity_from_private_matches() {
    let id = run(identity_generate, &mut w()).unwrap();
    let pair = IdentityKeyPair::try_from(id[0].as_slice()).unwrap();
    let again = run(
        identity_from_private,
        w().bytes(&pair.private_key().serialize()),
    )
    .unwrap();
    assert_eq!(again[1], id[1]);
    assert_eq!(again[0], id[0]);
}

#[test]
fn signatures_verify() {
    let bob = Party::new(2);
    let spk = run(prekey_public, w().u32(1).bytes(&bob.spk)).unwrap();
    run(verify, w().bytes(&bob.public).bytes(&spk[1]).bytes(&spk[2])).unwrap();
    let alice = Party::new(1);
    let mut f = w();
    f.bytes(&alice.public).bytes(&spk[1]).bytes(&spk[2]);
    assert_eq!(run(verify, &mut f), Err(Error::Signature));
}

#[test]
fn promote_keeps_each_session_once() {
    let alice = Party::new(1);
    let bob = Party::new(2);
    let (_, b1, _) = opened(&alice, &bob);
    let (_, b2, _) = opened(&alice, &bob);
    let i1 = run(session_info, w().bytes(&b1)).unwrap();
    let i2 = run(session_info, w().bytes(&b2)).unwrap();
    let both = run(session_promote, w().bytes(&b1).bytes(&b2))
        .unwrap()
        .remove(0);
    let i = run(session_info, w().bytes(&both)).unwrap();
    assert_eq!(i[3], i2[3]);
    assert_eq!(u32_of(&i[7]), 1);
    assert_eq!(u32_of(&i[8]), 4);
    assert_eq!(i[9], i1[3]);
    // the newer one again: held once, in front
    let again = run(session_promote, w().bytes(&both).bytes(&b2))
        .unwrap()
        .remove(0);
    let i = run(session_info, w().bytes(&again)).unwrap();
    assert_eq!(i[3], i2[3]);
    assert_eq!(u32_of(&i[7]), 1);
    assert_eq!(i[9], i1[3]);
    // b1 back on top, b2 archived, no copy of b1 left behind
    let back = run(session_promote, w().bytes(&again).bytes(&b1))
        .unwrap()
        .remove(0);
    let i = run(session_info, w().bytes(&back)).unwrap();
    assert_eq!(i[3], i1[3]);
    assert_eq!(u32_of(&i[7]), 1);
    assert_eq!(i[9], i2[3]);
}

fn fixture() -> HashMap<String, Vec<u8>> {
    let hex = |s: &str| {
        (0..s.len())
            .step_by(2)
            .map(|i| u8::from_str_radix(&s[i..i + 2], 16).unwrap())
            .collect::<Vec<u8>>()
    };
    include_str!("../testdata/dart_v3.txt")
        .lines()
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
        .map(|l| {
            let (k, v) = l.split_once('=').unwrap();
            (k.to_string(), hex(v))
        })
        .collect()
}

fn public_of(pair: &[u8]) -> Vec<u8> {
    IdentityKeyPair::try_from(pair)
        .unwrap()
        .identity_key()
        .serialize()
        .to_vec()
}

#[test]
fn a_classic_opener_is_refused() {
    let f = fixture();
    let info = run(prekey_message_info, w().bytes(&f["m1"])).unwrap();
    assert_eq!(u32_of(&info[0]), 3);
    // bob on a fresh install: no session held, the x3dh opener goes nowhere
    let mut x = w();
    x.bytes(&f["bob_id"])
        .u32(22)
        .opt(None)
        .bytes(&f["m1"])
        .bytes(&f["bob_pk"])
        .bytes(&f["bob_spk"])
        .opt(None)
        .opt(None);
    assert_eq!(run(decrypt_prekey, &mut x), Err(Error::Classic));
    // with the session it built held, it is a copy already read
    let mut x = w();
    x.bytes(&f["bob_id"])
        .u32(22)
        .bytes(&f["bob_rec"])
        .bytes(&f["m1"])
        .bytes(&f["bob_pk"])
        .bytes(&f["bob_spk"])
        .opt(None)
        .opt(None);
    assert_eq!(run(decrypt_prekey, &mut x), Err(Error::Duplicate));
}

#[test]
fn a_classic_session_goes_on() {
    let f = fixture();
    let info = run(session_info, w().bytes(&f["bob_rec"])).unwrap();
    assert_eq!(u32_of(&info[1]), 3);
    assert_eq!(u32_of(&info[2]), 0);
    assert_eq!(info[4], public_of(&f["alice_id"]));
    // m3, sealed by the dart library, read here
    let p = run(
        decrypt_signal,
        w().bytes(&f["bob_id"])
            .u32(22)
            .bytes(&f["bob_rec"])
            .bytes(&f["m3"])
            .opt(None),
    )
    .unwrap();
    assert_eq!(p[0], b"m3 from dart");
    let (mut a, mut b) = (f["alice_rec"].clone(), p[1].clone());
    for i in 0..3u8 {
        let m = run(
            encrypt,
            w().bytes(&f["bob_id"])
                .u32(22)
                .bytes(&b)
                .bytes(&[i; 4])
                .u64(NOW)
                .opt(None),
        )
        .unwrap();
        assert_eq!(u32_of(&m[0]), 2);
        b = m[2].clone();
        let p = run(
            decrypt_signal,
            w().bytes(&f["alice_id"])
                .u32(11)
                .bytes(&a)
                .bytes(&m[1])
                .opt(None),
        )
        .unwrap();
        assert_eq!(p[0], vec![i; 4]);
        a = p[1].clone();
        let m = run(
            encrypt,
            w().bytes(&f["alice_id"])
                .u32(11)
                .bytes(&a)
                .bytes(&[i; 5])
                .u64(NOW)
                .opt(None),
        )
        .unwrap();
        a = m[2].clone();
        let p = run(
            decrypt_signal,
            w().bytes(&f["bob_id"])
                .u32(22)
                .bytes(&b)
                .bytes(&m[1])
                .opt(None),
        )
        .unwrap();
        assert_eq!(p[0], vec![i; 5]);
        b = p[1].clone();
    }
    // still the classic session: libsignal does not move it on by itself
    let info = run(session_info, w().bytes(&b)).unwrap();
    assert_eq!(u32_of(&info[1]), 3);
}

#[test]
fn a_panic_stops_at_the_boundary() {
    let mut out = std::ptr::null_mut();
    let mut n = 0;
    let code = unsafe { call(|_| panic!("boom"), std::ptr::null(), 0, &mut out, &mut n) };
    assert_eq!(code, Error::Panic as i32);
    assert!(out.is_null());
    assert_eq!(n, 0);
    let code = unsafe { call(identity_generate, std::ptr::null(), 4, &mut out, &mut n) };
    assert_eq!(code, Error::Args as i32);
    unsafe { ks_free(std::ptr::null_mut(), 0) };
}

// fuzz-style: random and mutated input through every call. none may
// panic (run asserts that) and none may hand back output on an error

pub(crate) struct Rng(pub(crate) u64);

impl Rng {
    pub(crate) fn next(&mut self) -> u64 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        self.0
    }
    pub(crate) fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }
}

pub(crate) fn mutate(rng: &mut Rng, b: &[u8]) -> Vec<u8> {
    let mut v = b.to_vec();
    for _ in 0..1 + rng.below(4) {
        match rng.below(4) {
            0 if !v.is_empty() => {
                let i = rng.below(v.len());
                v[i] ^= 1 << rng.below(8);
            }
            1 if !v.is_empty() => {
                let i = rng.below(v.len());
                v.truncate(i);
            }
            2 => {
                let i = rng.below(v.len() + 1);
                v.insert(i, rng.next() as u8);
            }
            _ if !v.is_empty() => {
                let i = rng.below(v.len());
                v[i] = rng.next() as u8;
            }
            _ => {}
        }
    }
    v
}

pub(crate) fn raw(op: Op, input: &[u8]) {
    let mut out = std::ptr::null_mut();
    let mut n = 0;
    let code = unsafe { call(op, input.as_ptr(), input.len(), &mut out, &mut n) };
    assert_ne!(code, Error::Panic as i32);
    if code == 0 {
        unsafe { ks_free(out, n) };
    } else {
        assert!(out.is_null());
    }
}

#[test]
fn parsers_take_garbage() {
    let alice = Party::new(1);
    let bob = Party::new(2);
    let s = run(
        session_from_bundle,
        w().bytes(&alice.pair)
            .u32(1)
            .opt(None)
            .bytes(&bob.bundle())
            .u64(NOW)
            .opt(None),
    )
    .unwrap();
    let m = run(
        encrypt,
        w().bytes(&alice.pair)
            .u32(1)
            .bytes(&s[0])
            .bytes(b"x")
            .u64(NOW)
            .opt(None),
    )
    .unwrap();
    let (_, b, _) = opened(&alice, &bob);
    let r = run(
        encrypt,
        w().bytes(&bob.pair)
            .u32(2)
            .bytes(&b)
            .bytes(b"y")
            .u64(NOW)
            .opt(None),
    )
    .unwrap();
    let f = fixture();

    let cheap: Vec<(Op, Vec<u8>)> = vec![
        (bundle_parse, w().bytes(&bob.bundle()).done()),
        (bundle_build, bob.bundle_fields(true).done()),
        (prekey_message_info, w().bytes(&m[1]).done()),
        (prekey_message_info, w().bytes(&f["m1"]).done()),
        (session_info, w().bytes(&s[0]).done()),
        (session_info, w().bytes(&f["bob_rec"]).done()),
        (session_promote, w().bytes(&b).bytes(&s[0]).done()),
        (prekey_public, w().u32(2).bytes(&bob.kyber).done()),
        (prekey_public, w().u32(1).bytes(&bob.spk).done()),
        (identity_from_private, w().bytes(&[7; 32]).done()),
        (
            decrypt_signal,
            w().bytes(&alice.pair)
                .u32(1)
                .bytes(&s[0])
                .bytes(&r[1])
                .opt(None)
                .done(),
        ),
        (
            decrypt_signal,
            w().bytes(&f["bob_id"])
                .u32(22)
                .bytes(&f["bob_rec"])
                .bytes(&f["m3"])
                .opt(None)
                .done(),
        ),
    ];
    let mut rng = Rng(0x9e3779b97f4a7c15);
    for (op, seed) in &cheap {
        for _ in 0..300 {
            raw(*op, &mutate(&mut rng, seed));
        }
        for _ in 0..50 {
            let n = rng.below(200);
            let junk: Vec<u8> = (0..n).map(|_| rng.next() as u8).collect();
            raw(*op, &junk);
        }
    }
    // the record and message fields mutated inside otherwise good input
    for _ in 0..200 {
        let rec = mutate(&mut rng, &b);
        raw(
            encrypt,
            &w().bytes(&bob.pair)
                .u32(2)
                .bytes(&rec)
                .bytes(b"z")
                .u64(NOW)
                .opt(None)
                .done(),
        );
        let msg = mutate(&mut rng, &m[1]);
        raw(
            decrypt_prekey,
            &w().bytes(&bob.pair)
                .u32(2)
                .opt(None)
                .bytes(&msg)
                .bytes(&bob.pk)
                .bytes(&bob.spk)
                .bytes(&bob.kyber)
                .opt(None)
                .done(),
        );
        let bundle = mutate(&mut rng, &bob.bundle());
        raw(
            session_from_bundle,
            &w().bytes(&alice.pair)
                .u32(1)
                .opt(None)
                .bytes(&bundle)
                .u64(NOW)
                .opt(None)
                .done(),
        );
    }
}

// one byte read past a 16-byte box. mtecheck.sh runs it under heap tagging,
// where it has to trap, or the check proves nothing
#[cfg(feature = "mtecheck")]
#[test]
fn mte_canary() {
    let p = Box::into_raw(Box::new([7u8; 16])) as *mut u8;
    let past = unsafe { std::ptr::read_volatile(p.add(16)) };
    drop(unsafe { Box::from_raw(p as *mut [u8; 16]) });
    std::hint::black_box(past);
}

#[test]
fn classic_states_go_after_the_pq_restart() {
    let f = fixture();
    let bob_rec = &f["bob_rec"];
    let alice_pub = run(session_info, w().bytes(bob_rec)).unwrap()[4].clone();
    // alice's pq prekeys, and bob restarting the classic chat on them
    let spk = run(
        signed_prekey_generate,
        w().bytes(&f["alice_id"]).u32(51).u64(NOW),
    )
    .unwrap();
    let ky = run(
        kyber_prekey_generate,
        w().bytes(&f["alice_id"]).u32(52).u64(NOW),
    )
    .unwrap();
    let bundle = run(
        bundle_build,
        w().u32(11)
            .u32(1)
            .opt(None)
            .opt(None)
            .u32(51)
            .bytes(&spk[1])
            .bytes(&spk[2])
            .u32(52)
            .bytes(&ky[1])
            .bytes(&ky[2])
            .bytes(&alice_pub),
    )
    .unwrap()
    .remove(0);
    let pq = run(
        session_from_bundle,
        w().bytes(&f["bob_id"])
            .u32(22)
            .bytes(bob_rec)
            .bytes(&bundle)
            .u64(NOW)
            .opt(Some(&alice_pub)),
    )
    .unwrap()
    .remove(0);
    let info = run(session_info, w().bytes(&pq)).unwrap();
    assert_eq!(u32_of(&info[1]), 4);
    assert_eq!(u32_of(&info[7]), 1);
    assert_eq!(u32_of(&info[8]), 3);
    let m3 = |rec: &[u8]| {
        run(
            decrypt_signal,
            w().bytes(&f["bob_id"])
                .u32(22)
                .bytes(rec)
                .bytes(&f["m3"])
                .opt(None),
        )
    };
    assert_eq!(m3(&pq).unwrap()[0], b"m3 from dart");
    // alice has not answered the restart: the classic state stays
    assert_eq!(
        run(session_drop_below, w().bytes(&pq).u32(4)),
        Err(Error::Session)
    );
    // bob's first pq message, alice opens it on her held classic record
    let m = run(
        encrypt,
        w().bytes(&f["bob_id"])
            .u32(22)
            .bytes(&pq)
            .bytes(b"on pq")
            .u64(NOW)
            .opt(None),
    )
    .unwrap();
    assert_eq!(u32_of(&m[0]), 3);
    assert_eq!(
        run(session_drop_below, w().bytes(&m[2]).u32(4)),
        Err(Error::Session)
    );
    let o = run(
        decrypt_prekey,
        w().bytes(&f["alice_id"])
            .u32(11)
            .bytes(&f["alice_rec"])
            .bytes(&m[1])
            .opt(None)
            .bytes(&spk[0])
            .bytes(&ky[0])
            .opt(None),
    )
    .unwrap();
    assert_eq!(o[0], b"on pq");
    // the responder opened bob's pq opener, so her side drops at once
    let a = run(session_drop_below, w().bytes(&o[1]).u32(4)).unwrap();
    assert_eq!(u32_of(&a[1]), 1);
    // her answer reaches bob: now his side drops too
    let reply = run(
        encrypt,
        w().bytes(&f["alice_id"])
            .u32(11)
            .bytes(&a[0])
            .bytes(b"back")
            .u64(NOW)
            .opt(None),
    )
    .unwrap();
    assert_eq!(u32_of(&reply[0]), 2);
    let r = run(
        decrypt_signal,
        w().bytes(&f["bob_id"])
            .u32(22)
            .bytes(&m[2])
            .bytes(&reply[1])
            .opt(None),
    )
    .unwrap();
    assert_eq!(r[0], b"back");
    // m3 still opened here, before the drop
    assert_eq!(m3(&r[1]).unwrap()[0], b"m3 from dart");
    let d = run(session_drop_below, w().bytes(&r[1]).u32(4)).unwrap();
    assert_eq!(u32_of(&d[1]), 1);
    let info = run(session_info, w().bytes(&d[0])).unwrap();
    assert_eq!(u32_of(&info[1]), 4);
    assert_eq!(u32_of(&info[7]), 0);
    assert!(m3(&d[0]).is_err());
    // the pq session goes on
    let m = run(
        encrypt,
        w().bytes(&f["bob_id"])
            .u32(22)
            .bytes(&d[0])
            .bytes(b"still pq")
            .u64(NOW)
            .opt(None),
    )
    .unwrap();
    assert_eq!(u32_of(&m[0]), 2);
    let o = run(
        decrypt_signal,
        w().bytes(&f["alice_id"])
            .u32(11)
            .bytes(&a[0])
            .bytes(&m[1])
            .opt(None),
    )
    .unwrap();
    assert_eq!(o[0], b"still pq");
    // nothing left to drop; a state below the line, none, or no line
    assert_eq!(
        u32_of(&run(session_drop_below, w().bytes(&d[0]).u32(4)).unwrap()[1]),
        0
    );
    assert_eq!(
        run(session_drop_below, w().bytes(bob_rec).u32(4)),
        Err(Error::Session)
    );
    assert_eq!(
        run(session_drop_below, w().bytes(&pq).u32(0)),
        Err(Error::Args)
    );
    assert_eq!(
        run(session_drop_below, w().bytes(&pq).u32(5)),
        Err(Error::Session)
    );
    assert_eq!(
        run(session_drop_below, w().bytes(b"junk").u32(4)),
        Err(Error::Session)
    );
    // a version 3 record keeps its own archived states below 3: none here
    assert_eq!(
        u32_of(&run(session_drop_below, w().bytes(bob_rec).u32(3)).unwrap()[1]),
        0
    );
}

#[test]
fn every_call_takes_keys_in_their_one_form_only() {
    let alice = Party::new(1);
    let bob = Party::new(2);
    let fields = run(bundle_parse, w().bytes(&bob.bundle())).unwrap();
    let rebuild = |f: &[Vec<u8>]| {
        let mut x = w();
        for v in f {
            x.bytes(v);
        }
        run(bundle_build, &mut x)
    };
    let top = |k: &[u8]| {
        let mut k = k.to_vec();
        k[32] |= 0x80;
        k
    };
    // the identity, the spk and the one-time prekey with the top bit set,
    // or a byte after them
    for i in [3, 5, 10] {
        let mut f = fields.clone();
        f[i] = top(&f[i]);
        assert_eq!(rebuild(&f), Err(Error::Key), "field {i}");
        let mut f = fields.clone();
        f[i].push(0);
        assert_eq!(rebuild(&f), Err(Error::Key), "field {i}");
    }
    // a kyber key with a byte after it, or one short
    let mut f = fields.clone();
    f[8].push(0);
    assert_eq!(rebuild(&f), Err(Error::Key));
    let mut f = fields.clone();
    f[8].pop();
    assert_eq!(rebuild(&f), Err(Error::Key));
    // a prekey signature in its second encoding
    for i in [6, 9] {
        let mut f = fields.clone();
        crate::tests_formats::add_l(&mut f[i][32..]);
        assert_eq!(rebuild(&f), Err(Error::Signature), "field {i}");
    }
    rebuild(&fields).unwrap();
    // a pin in a second form
    let mut x = w();
    x.bytes(&alice.pair)
        .u32(1)
        .opt(None)
        .bytes(&bob.bundle())
        .u64(NOW)
        .opt(Some(&top(&bob.public)));
    assert_eq!(run(session_from_bundle, &mut x), Err(Error::Key));
    // a pair whose halves do not belong together opens and seals nothing
    let a = IdentityKeyPair::try_from(alice.pair.as_slice()).unwrap();
    let b = IdentityKeyPair::try_from(bob.pair.as_slice()).unwrap();
    let mixed = IdentityKeyPair::new(*b.identity_key(), *a.private_key()).serialize();
    let mut x = w();
    x.bytes(&mixed)
        .u32(1)
        .opt(None)
        .bytes(&bob.bundle())
        .u64(NOW)
        .opt(None);
    assert_eq!(run(session_from_bundle, &mut x), Err(Error::Key));
    for k in [&mixed[..], &[1, 2, 3]] {
        assert_eq!(
            run(signed_prekey_generate, w().bytes(k).u32(1).u64(NOW)),
            Err(Error::Key)
        );
    }
    // a private key of any but 32 bytes
    let p = a.private_key().serialize();
    assert_eq!(
        run(identity_from_private, w().bytes(&[&p[..], &[0]].concat())),
        Err(Error::Key)
    );
    assert_eq!(
        run(identity_from_private, w().bytes(&p[..31])),
        Err(Error::Key)
    );
    run(identity_from_private, w().bytes(&p)).unwrap();
}

// an order 8 point, for keys with a torsion part
pub(crate) fn order8() -> curve25519_dalek::edwards::EdwardsPoint {
    use curve25519_dalek::edwards::CompressedEdwardsY;
    use curve25519_dalek::traits::IsIdentity;
    let b: [u8; 32] = crate::tests_formats::hex(
        "c7176a703d4dd84fba3c0b760d10670f2a2053fa2c39ccc64ec7fd7792ac037a",
    )
    .try_into()
    .unwrap();
    let p = CompressedEdwardsY(b).decompress().unwrap();
    // small order, and not of order 4 or less
    let p2 = p + p;
    assert!(p.is_small_order() && !(p2 + p2).is_identity());
    p
}

// [k] with the top bit of u set, and [k] plus an order 8 point: x25519 with
// a clamped scalar gives the same secret for both
pub(crate) fn second_forms(k: &[u8]) -> [(&'static str, Vec<u8>); 2] {
    use curve25519_dalek::montgomery::MontgomeryPoint;
    let mut top = k.to_vec();
    top[32] |= 0x80;
    let ed = MontgomeryPoint(k[1..].try_into().unwrap())
        .to_edwards(0)
        .unwrap()
        + order8();
    let mixed = [&[5u8][..], ed.to_montgomery().as_bytes()].concat();
    [("top bit", top), ("order 8 part", mixed)]
}

// an opener libsignal itself makes for an identity whose public half is
// [public], in whatever form
fn opener_as(private: &[u8], public: &[u8], bob: &Party) -> Vec<u8> {
    use libsignal_protocol::*;
    let f = run(bundle_parse, w().bytes(&bob.bundle())).unwrap();
    let bundle = PreKeyBundle::new(
        u32_of(&f[0]),
        DeviceId::try_from(u32_of(&f[1])).unwrap(),
        Some((u32_of(&f[2]).into(), PublicKey::deserialize(&f[3]).unwrap())),
        u32_of(&f[4]).into(),
        PublicKey::deserialize(&f[5]).unwrap(),
        f[6].clone(),
        u32_of(&f[7]).into(),
        kem::PublicKey::deserialize(&f[8]).unwrap(),
        f[9].clone(),
        IdentityKey::decode(&f[10]).unwrap(),
    )
    .unwrap();
    let pair = IdentityKeyPair::new(
        IdentityKey::new(PublicKey::deserialize(public).unwrap()),
        PrivateKey::deserialize(private).unwrap(),
    );
    let mut st = InMemSignalProtocolStore::new(pair, 77).unwrap();
    let peer = ProtocolAddress::new("peer".into(), DeviceId::new(1).unwrap());
    let me = ProtocolAddress::new("self".into(), DeviceId::new(1).unwrap());
    let now = std::time::UNIX_EPOCH + std::time::Duration::from_millis(NOW);
    let mut rng = crate::ops::rng();
    block_on_test(Box::pin(process_prekey_bundle(
        &peer,
        &me,
        &mut st.session_store,
        &mut st.identity_store,
        &bundle,
        now,
        &mut rng,
    )))
    .unwrap();
    let mut rng = crate::ops::rng();
    let m = block_on_test(Box::pin(message_encrypt(
        b"hi",
        &peer,
        &me,
        &mut st.session_store,
        &mut st.identity_store,
        now,
        &mut rng,
    )))
    .unwrap();
    m.serialize().to_vec()
}

pub(crate) fn block_on_test<T>(
    f: std::pin::Pin<Box<dyn std::future::Future<Output = T> + '_>>,
) -> T {
    let mut f = f;
    let mut cx = std::task::Context::from_waker(std::task::Waker::noop());
    loop {
        if let std::task::Poll::Ready(v) = f.as_mut().poll(&mut cx) {
            return v;
        }
    }
}

fn open_at(bob: &Party, m: &[u8]) -> Result<Vec<Vec<u8>>, Error> {
    run(
        decrypt_prekey,
        w().bytes(&bob.pair)
            .u32(bob.reg)
            .opt(None)
            .bytes(m)
            .bytes(&bob.pk)
            .bytes(&bob.spk)
            .bytes(&bob.kyber)
            .opt(None),
    )
}

#[test]
fn an_opener_names_its_keys_in_one_form_only() {
    let alice = crate::tests_formats::Id::new();
    let bob = Party::new(22);
    // the canonical opener opens, and names alice as she is
    let good = opener_as(&alice.private, &alice.public, &bob);
    let info = run(prekey_message_info, w().bytes(&good)).unwrap();
    assert_eq!(info[6], alice.public);
    let d = open_at(&bob, &good).unwrap();
    assert_eq!(d[0], b"hi");
    assert_eq!(d[4], alice.public);
    // libsignal makes and opens one for alice's key in a second form; the
    // shim takes neither
    for (what, key) in second_forms(&alice.public) {
        assert_eq!(crate::keys::strict_public(&key).err(), Some(Error::Key));
        let m = opener_as(&alice.private, &key, &bob);
        assert_eq!(
            run(prekey_message_info, w().bytes(&m)),
            Err(Error::Key),
            "{what}"
        );
        assert_eq!(open_at(&bob, &m), Err(Error::Key), "{what}");
    }
    // the base key edited in place to a second form: the same secrets, so
    // only the form check refuses it
    let base = info[5].clone();
    let at = good.windows(33).position(|x| x == base).unwrap();
    for (what, key) in second_forms(&base) {
        let mut m = good.clone();
        m[at..at + 33].copy_from_slice(&key);
        assert_eq!(
            run(prekey_message_info, w().bytes(&m)),
            Err(Error::Key),
            "base {what}"
        );
        assert_eq!(open_at(&bob, &m), Err(Error::Key), "base {what}");
    }
    // the prekeys were not spent by any of it
    assert_eq!(open_at(&bob, &good).unwrap()[0], b"hi");
}

#[test]
fn records_are_rewritten_only_as_libsignal_reads_them() {
    let f = fixture();
    // the dart library's records encode back the same
    for k in ["bob_rec", "alice_rec", "alice_pending_rec"] {
        record::rec_of(&f[k]).unwrap_or_else(|e| panic!("{k}: {e:?}"));
    }
    // the unanswered one is no record to drop from
    assert_eq!(
        run(
            session_drop_below,
            w().bytes(&f["alice_pending_rec"]).u32(1)
        ),
        Err(Error::Session)
    );
    // a second current state: libsignal merges the two, a byte reader
    // takes the last, so neither rewrite takes it
    let alice = Party::new(1);
    let bob = Party::new(2);
    let (_, b1, _) = opened(&alice, &bob);
    let (_, b2, _) = opened(&alice, &bob);
    let cur = |r: &[u8]| {
        let mut x = Vec::new();
        prost::encoding::bytes::encode(1, &extract_current(r), &mut x);
        x
    };
    let twice = [&b1[..], &cur(&b2)].concat();
    assert_eq!(
        run(session_drop_below, w().bytes(&twice).u32(4)),
        Err(Error::Session)
    );
    assert_eq!(
        run(session_promote, w().bytes(&b1).bytes(&twice)),
        Err(Error::Session)
    );
    // the records as they are go through both
    run(session_drop_below, w().bytes(&b1).u32(4)).unwrap();
    run(session_promote, w().bytes(&b1).bytes(&b2)).unwrap();
}

// the current state's bytes of a record (RecordStructure field 1)
fn extract_current(r: &[u8]) -> Vec<u8> {
    use prost::Message;
    #[derive(Clone, PartialEq, Message)]
    struct Cur {
        #[prost(bytes = "vec", optional, tag = "1")]
        current: Option<Vec<u8>>,
    }
    Cur::decode(r).unwrap().current.unwrap()
}
