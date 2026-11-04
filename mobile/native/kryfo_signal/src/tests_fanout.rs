// SPDX-License-Identifier: GPL-3.0-or-later
// a message to every device on a signed list, on the calls the shim has:
// one session per device pair, each pinned to the key the list names
use crate::formats::*;
use crate::tests::{NOW, Rng, run, u32_of, w};
use crate::tests_formats::{Id, parse_of};
use crate::*;

// one device of an identity with the records behind its KDB1. every device
// uses the same prekey ids, so a copy opened on the wrong device fails on
// its keys, not on an id it cannot find
struct Dev {
    key: Id,
    device: u8,
    reg: u32,
    spk: Vec<u8>,
    kyber: Vec<u8>,
    ec: Vec<u8>,
    block: Block,
}

const SPK: u32 = 41;
const KYBER: u32 = 42;
const EC: u32 = 43;

impl Dev {
    fn new(key: Id, device: u8, reg: u32) -> Self {
        let spk = run(signed_prekey_generate, w().bytes(&key.pair).u32(SPK).u64(NOW)).unwrap();
        let ky = run(kyber_prekey_generate, w().bytes(&key.pair).u32(KYBER).u64(NOW)).unwrap();
        let ec = run(prekey_generate, w().u32(EC)).unwrap();
        let block = Block {
            reg,
            device,
            key: (device != PHONE_DEVICE).then(|| key.public.clone()),
            spk_id: SPK,
            spk: spk[1].clone(),
            spk_sig: spk[2].clone(),
            kyber_id: KYBER,
            kyber: ky[1].clone(),
            kyber_sig: ky[2].clone(),
            ec: Some((EC, ec[1].clone())),
        };
        Dev {
            key,
            device,
            reg,
            spk: spk[0].clone(),
            kyber: ky[0].clone(),
            ec: ec[0].clone(),
            block,
        }
    }

    fn kdb1(&self) -> Vec<u8> {
        DeviceBundle {
            block: self.block.clone(),
        }
        .encode()
    }

    // an opener sealed to this device, opened here: plaintext, record, the
    // sender's key
    fn open_opener(&self, held: Option<&[u8]>, m: &[u8], pin: &[u8]) -> Result<Vec<Vec<u8>>, Error> {
        run(
            decrypt_prekey,
            w().bytes(&self.key.pair)
                .u32(self.reg)
                .opt(held)
                .bytes(m)
                .bytes(&self.ec)
                .bytes(&self.spk)
                .bytes(&self.kyber)
                .opt(Some(pin)),
        )
    }
}

// an identity: the phone (device 1, on the identity key) and n more
struct Account {
    devs: Vec<Dev>,
    list: Vec<u8>,
}

impl Account {
    fn new(rng: &mut Rng, more: usize) -> Self {
        let phone = Id::new();
        let mut ids = vec![PHONE_DEVICE];
        while ids.len() < more + 1 {
            let d = 2 + rng.below(126) as u8;
            if !ids.contains(&d) {
                ids.push(d);
            }
        }
        ids.sort();
        let mut devs = Vec::new();
        for (i, d) in ids.iter().enumerate() {
            let key = if i == 0 { phone.clone() } else { Id::new() };
            devs.push(Dev::new(key, *d, 100 + i as u32 * 7));
        }
        let mut l = DeviceList {
            identity: phone.public.clone(),
            version: rng.next() >> 8,
            entries: devs
                .iter()
                .map(|d| Entry {
                    device: d.device,
                    key: d.key.public.clone(),
                    reg: d.reg,
                    phone: d.device == PHONE_DEVICE,
                    answers: false,
                })
                .collect(),
            sig: None,
        };
        l.sig = Some(phone.sign(b"device-list", &l.body()).unwrap());
        Account {
            devs,
            list: l.encode(),
        }
    }

    fn identity(&self) -> &[u8] {
        &self.devs[0].key.public
    }
}

// a device of the sender: its key pair and registration id, and its
// sessions with each listed device of the reader
struct Sender<'a> {
    me: &'a Id,
    reg: u32,
}

impl Sender<'_> {
    fn build(&self, bundle: &[u8], pin: &[u8]) -> Result<Vec<Vec<u8>>, Error> {
        run(
            session_from_bundle,
            w().bytes(&self.me.pair)
                .u32(self.reg)
                .opt(None)
                .bytes(bundle)
                .u64(NOW)
                .opt(Some(pin)),
        )
    }

    fn seal(&self, rec: &[u8], plain: &[u8], pin: &[u8]) -> Vec<Vec<u8>> {
        run(
            encrypt,
            w().bytes(&self.me.pair)
                .u32(self.reg)
                .bytes(rec)
                .bytes(plain)
                .u64(NOW)
                .opt(Some(pin)),
        )
        .unwrap()
    }

    fn open(&self, rec: &[u8], m: &[u8], pin: &[u8]) -> Result<Vec<Vec<u8>>, Error> {
        run(
            decrypt_signal,
            w().bytes(&self.me.pair)
                .u32(self.reg)
                .bytes(rec)
                .bytes(m)
                .opt(Some(pin)),
        )
    }
}

fn seal_on(d: &Dev, rec: &[u8], plain: &[u8], pin: &[u8]) -> Vec<Vec<u8>> {
    Sender {
        me: &d.key,
        reg: d.reg,
    }
    .seal(rec, plain, pin)
}

// what the reader takes from the list: (device, key, reg) per entry
fn listed(list: &[u8]) -> Vec<(u8, Vec<u8>, u32)> {
    let o = parse_of("device-list", list, None).unwrap();
    let n = u32_of(&o[3]) as usize;
    (0..n)
        .map(|i| {
            let e = &o[4 + i * 4..8 + i * 4];
            (u32_of(&e[0]) as u8, e[1].clone(), u32_of(&e[2]))
        })
        .collect()
}

// a KDB1 read for a listed device: the key it runs on, its reg and the
// bundle a session is built from
fn bundle_of(kdb1: &[u8], identity: &[u8]) -> (Vec<u8>, u32, u8, Vec<u8>) {
    let o = parse_of("device-bundle", kdb1, Some(identity)).unwrap();
    (o[0].clone(), u32_of(&o[1]), u32_of(&o[2]) as u8, o[12].clone())
}

fn pq_session(rec: &[u8]) {
    let info = run(session_info, w().bytes(rec)).unwrap();
    assert_eq!(u32_of(&info[1]), 4, "pqxdh");
    assert_eq!(u32_of(&info[2]), 1, "spqr");
}

#[test]
fn a_six_device_account_is_reachable() {
    let mut rng = Rng(0x5eed_f00d_6006_0001);
    let bob = Account::new(&mut rng, MAX_DEVICES - 1);
    let ana = Id::new();
    let a = Sender { me: &ana, reg: 11 };
    let entries = listed(&bob.list);
    assert_eq!(entries.len(), MAX_DEVICES);
    // ana's sessions, one per listed device, each built on its listed key
    let mut recs = Vec::new();
    for (dev, (id, key, reg)) in bob.devs.iter().zip(&entries) {
        let (signer, breg, bdev, bundle) = bundle_of(&dev.kdb1(), bob.identity());
        assert_eq!((&signer, breg, bdev), (key, *reg, *id));
        let s = a.build(&bundle, key).unwrap();
        assert_eq!(&s[1], key);
        pq_session(&s[0]);
        recs.push(s[0].clone());
    }
    // one message, one copy per device
    let plain = [0x7au8; 1103];
    let copies: Vec<Vec<u8>> = recs
        .iter_mut()
        .zip(&entries)
        .map(|(rec, (_, key, _))| {
            let m = a.seal(rec, &plain, key);
            assert_eq!(u32_of(&m[0]), 3, "an opener until answered");
            *rec = m[2].clone();
            m[1].clone()
        })
        .collect();
    // the openers differ in length only by their varints
    let (lo, hi) = (
        copies.iter().map(Vec::len).min().unwrap(),
        copies.iter().map(Vec::len).max().unwrap(),
    );
    assert!(hi - lo <= 4, "opener copies {lo}..{hi} bytes");
    let mut theirs = Vec::new();
    for (i, dev) in bob.devs.iter().enumerate() {
        let info = run(prekey_message_info, w().bytes(&copies[i])).unwrap();
        assert_eq!(u32_of(&info[0]), 4);
        assert_eq!(u32_of(&info[1]), 11, "the sender device's reg");
        let o = dev.open_opener(None, &copies[i], &ana.public).unwrap();
        assert_eq!(o[0], plain);
        assert_eq!(o[4], ana.public);
        pq_session(&o[1]);
        // a copy for another device opens nowhere else
        for (j, other) in bob.devs.iter().enumerate() {
            if j != i {
                assert!(other.open_opener(None, &copies[i], &ana.public).is_err());
            }
        }
        theirs.push(o[1].clone());
    }
    // each device answers; ana opens each answer on its own session only
    for (i, dev) in bob.devs.iter().enumerate() {
        let m = seal_on(dev, &theirs[i], b"got it", &ana.public);
        assert_eq!(u32_of(&m[0]), 2);
        theirs[i] = m[2].clone();
        let key = &entries[i].1;
        for (j, rec) in recs.iter().enumerate() {
            if j != i {
                assert!(a.open(rec, &m[1], key).is_err());
            }
        }
        let o = a.open(&recs[i], &m[1], key).unwrap();
        assert_eq!((&o[0][..], &o[2]), (&b"got it"[..], key));
        recs[i] = o[1].clone();
    }
    // answered: every later copy is a plain message
    let wh: Vec<Vec<u8>> = recs
        .iter_mut()
        .zip(&entries)
        .map(|(rec, (_, key, _))| {
            let m = a.seal(rec, &[1u8; 847], key);
            assert_eq!(u32_of(&m[0]), 2);
            *rec = m[2].clone();
            m[1].clone()
        })
        .collect();
    for (i, dev) in bob.devs.iter().enumerate() {
        let o = run(
            decrypt_signal,
            w().bytes(&dev.key.pair)
                .u32(dev.reg)
                .bytes(&theirs[i])
                .bytes(&wh[i])
                .opt(Some(&ana.public)),
        )
        .unwrap();
        assert_eq!(o[0], vec![1u8; 847]);
        theirs[i] = o[1].clone();
    }
}

#[test]
fn a_copy_opens_once() {
    let mut rng = Rng(0x5eed_f00d_6006_0002);
    let bob = Account::new(&mut rng, 2);
    let ana = Id::new();
    let a = Sender { me: &ana, reg: 12 };
    let dev = &bob.devs[2];
    let (_, _, _, bundle) = bundle_of(&dev.kdb1(), bob.identity());
    let s = a.build(&bundle, &dev.key.public).unwrap();
    let m = a.seal(&s[0], b"once", &dev.key.public);
    let o = dev.open_opener(None, &m[1], &ana.public).unwrap();
    // the same opener again, on the session it built
    assert_eq!(
        dev.open_opener(Some(&o[1]), &m[1], &ana.public),
        Err(Error::Duplicate)
    );
    // and a plain copy again
    let answer = seal_on(dev, &o[1], b"ok", &ana.public);
    let rec = a.open(&m[2], &answer[1], &dev.key.public).unwrap()[1].clone();
    let p = a.seal(&rec, b"plain", &dev.key.public);
    let first = run(
        decrypt_signal,
        w().bytes(&dev.key.pair)
            .u32(dev.reg)
            .bytes(&answer[2])
            .bytes(&p[1])
            .opt(Some(&ana.public)),
    )
    .unwrap();
    let again = run(
        decrypt_signal,
        w().bytes(&dev.key.pair)
            .u32(dev.reg)
            .bytes(&first[1])
            .bytes(&p[1])
            .opt(Some(&ana.public)),
    );
    assert_eq!(again, Err(Error::Duplicate));
}

#[test]
fn a_bundle_on_another_key_than_the_listed_one_is_refused() {
    let mut rng = Rng(0x5eed_f00d_6006_0003);
    let bob = Account::new(&mut rng, 2);
    let ana = Id::new();
    let a = Sender { me: &ana, reg: 13 };
    let entries = listed(&bob.list);
    // a KDB1 of device 2's id and reg, on another key
    let mallory = Dev::new(Id::new(), bob.devs[1].device, bob.devs[1].reg);
    let (signer, _, _, bundle) = bundle_of(&mallory.kdb1(), bob.identity());
    assert_ne!(signer, entries[1].1);
    assert_eq!(a.build(&bundle, &entries[1].1), Err(Error::Untrusted));
    // device 3's real bundle pinned to device 2's key: refused too
    let (_, _, _, b3) = bundle_of(&bob.devs[2].kdb1(), bob.identity());
    assert_eq!(a.build(&b3, &entries[1].1), Err(Error::Untrusted));
    // the reader's side: an opener from a key the list does not name
    let s = a.build(&b3, &entries[2].1).unwrap();
    let m = a.seal(&s[0], b"x", &entries[2].1);
    let eve = Id::new();
    assert_eq!(
        bob.devs[2].open_opener(None, &m[1], &eve.public),
        Err(Error::Untrusted)
    );
}

#[test]
fn no_classic_session_with_a_second_device() {
    let mut rng = Rng(0x5eed_f00d_6006_0004);
    let bob = Account::new(&mut rng, 1);
    let dev = &bob.devs[1];
    // a device bundle has no form without kyber
    let mut b = dev.kdb1();
    let at = 4 + 1 + 4 + 1 + 1 + 33 + 4 + 33 + 64 + 4;
    b.drain(at..at + 1569 + 64);
    assert_eq!(parse_of("device-bundle", &b, Some(bob.identity())), Err(Error::Format));
    // the bundle call itself refuses one without kyber
    let mut f = w();
    f.u32(dev.reg)
        .u32(dev.device.into())
        .opt(None)
        .opt(None)
        .u32(dev.block.spk_id)
        .bytes(&dev.block.spk)
        .bytes(&dev.block.spk_sig)
        .opt(None)
        .opt(None)
        .opt(None)
        .bytes(&dev.key.public);
    assert_eq!(run(bundle_build, &mut f), Err(Error::Classic));
    // a classic opener reaches a device that holds no session from it
    let fx = crate::tests::fixture();
    let ana = &fx["alice_id"];
    let pin = public_of(ana);
    assert_eq!(
        dev.open_opener(None, &fx["m1"], &pin),
        Err(Error::Classic)
    );
}

fn public_of(pair: &[u8]) -> Vec<u8> {
    libsignal_protocol::IdentityKeyPair::try_from(pair)
        .unwrap()
        .identity_key()
        .serialize()
        .to_vec()
}

#[test]
fn crossed_openers_between_two_new_devices_settle() {
    let mut rng = Rng(0x5eed_f00d_6006_0005);
    let ana = Account::new(&mut rng, 1);
    let bob = Account::new(&mut rng, 1);
    let (x, y) = (&ana.devs[1], &bob.devs[1]);
    let sx = Sender {
        me: &x.key,
        reg: x.reg,
    };
    let sy = Sender {
        me: &y.key,
        reg: y.reg,
    };
    let (_, _, _, by) = bundle_of(&y.kdb1(), bob.identity());
    let (_, _, _, bx) = bundle_of(&x.kdb1(), ana.identity());
    // both held the other's bundle and both started
    let rx = sx.build(&by, &y.key.public).unwrap()[0].clone();
    let ry = sy.build(&bx, &x.key.public).unwrap()[0].clone();
    let mx = sx.seal(&rx, b"from x", &y.key.public);
    let my = sy.seal(&ry, b"from y", &x.key.public);
    let info = run(prekey_message_info, w().bytes(&my[1])).unwrap();
    assert_eq!(u32_of(&info[1]), y.reg, "the opener names y's reg");
    let ox = x.open_opener(Some(&mx[2]), &my[1], &y.key.public).unwrap();
    let oy = y.open_opener(Some(&my[2]), &mx[1], &x.key.public).unwrap();
    assert_eq!((&ox[0][..], &oy[0][..]), (&b"from y"[..], &b"from x"[..]));
    let (mut rx, mut ry) = (ox[1].clone(), oy[1].clone());
    // a few rounds both ways: every message opens, and they settle
    for i in 0..4u8 {
        let m = sx.seal(&rx, &[i; 5], &y.key.public);
        rx = m[2].clone();
        let kind = u32_of(&m[0]);
        let op: Op = if kind == 3 { decrypt_prekey } else { decrypt_signal };
        let o = run(op, &mut y_input(y, &ry, &m[1], &x.key.public, kind)).unwrap();
        assert_eq!(o[0], vec![i; 5]);
        ry = o[1].clone();
        let m = sy.seal(&ry, &[i; 6], &x.key.public);
        assert_eq!(u32_of(&m[0]), 2, "y answered on what x sent");
        ry = m[2].clone();
        let o = sx.open(&rx, &m[1], &y.key.public).unwrap();
        assert_eq!(o[0], vec![i; 6]);
        rx = o[1].clone();
    }
    let m = sx.seal(&rx, b"settled", &y.key.public);
    assert_eq!(u32_of(&m[0]), 2);
    pq_session(&rx);
    pq_session(&ry);
}

// y opening what x sent on y's held record, whichever kind it is
fn y_input(y: &Dev, held: &[u8], m: &[u8], pin: &[u8], kind: u32) -> crate::wire::Writer {
    let mut f = w();
    f.bytes(&y.key.pair).u32(y.reg);
    if kind == 3 {
        f.bytes(held)
            .bytes(m)
            .bytes(&y.ec)
            .bytes(&y.spk)
            .bytes(&y.kyber)
            .opt(Some(pin));
    } else {
        f.bytes(held).bytes(m).opt(Some(pin));
    }
    f
}

#[test]
fn copies_between_two_devices_of_one_identity() {
    let mut rng = Rng(0x5eed_f00d_6006_0006);
    let me = Account::new(&mut rng, 2);
    let (phone, desk) = (&me.devs[0], &me.devs[2]);
    let entries = listed(&me.list);
    assert_eq!(entries[2].1, desk.key.public);
    let p = Sender {
        me: &phone.key,
        reg: phone.reg,
    };
    let (_, _, _, b) = bundle_of(&desk.kdb1(), me.identity());
    let s = p.build(&b, &desk.key.public).unwrap();
    // the session runs on the desk's own key, never the identity's
    assert_eq!(s[1], desk.key.public);
    assert_ne!(s[1], me.identity());
    let m = p.seal(&s[0], b"sent to ana: hi", &desk.key.public);
    let o = desk.open_opener(None, &m[1], me.identity()).unwrap();
    assert_eq!(o[0], b"sent to ana: hi");
    assert_eq!(o[4], me.identity());
    // the other own device cannot read the desk's copy
    assert!(me.devs[1].open_opener(None, &m[1], me.identity()).is_err());
}

#[test]
fn a_removed_device_has_nothing_to_open_on() {
    let mut rng = Rng(0x5eed_f00d_6006_0007);
    let bob = Account::new(&mut rng, 2);
    let ana = Id::new();
    let a = Sender { me: &ana, reg: 14 };
    let mut recs = Vec::new();
    let mut theirs = Vec::new();
    for dev in &bob.devs[1..] {
        let (_, _, _, b) = bundle_of(&dev.kdb1(), bob.identity());
        let s = a.build(&b, &dev.key.public).unwrap();
        let m = a.seal(&s[0], b"hi", &dev.key.public);
        let o = dev.open_opener(None, &m[1], &ana.public).unwrap();
        let ans = seal_on(dev, &o[1], b"hi back", &ana.public);
        recs.push(a.open(&m[2], &ans[1], &dev.key.public).unwrap()[1].clone());
        theirs.push(ans[2].clone());
    }
    // device 3 is removed: ana drops its record. what it sends next opens
    // on no session she keeps, under no pin she holds
    let gone = &bob.devs[2];
    let m = seal_on(gone, &theirs[1], b"still here", &ana.public);
    let kept = &bob.devs[1].key.public;
    assert!(a.open(&recs[0], &m[1], kept).is_err());
    assert!(a.open(&recs[0], &m[1], &gone.key.public).is_err());
    // the kept device's session is untouched by the try
    let m = seal_on(&bob.devs[1], &theirs[0], b"fine", &ana.public);
    assert_eq!(a.open(&recs[0], &m[1], kept).unwrap()[0], b"fine");
}
