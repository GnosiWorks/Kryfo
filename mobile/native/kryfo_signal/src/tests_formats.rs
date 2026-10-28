// SPDX-License-Identifier: GPL-3.0-or-later
// the frames (formats.rs) against testdata/formats_v1.txt, and the same
// builders made fresh on every run. write_vectors makes both vector files
use std::collections::HashMap;

use curve25519_dalek::edwards::{CompressedEdwardsY, EdwardsPoint};
use curve25519_dalek::montgomery::MontgomeryPoint;
use curve25519_dalek::scalar::Scalar;
use libsignal_protocol::{IdentityKeyPair, PrivateKey, PublicKey};
use sha2::{Digest, Sha256, Sha512};

use crate::formats::*;
use crate::sig::signed_text;
use crate::tests::{NOW, Rng, mutate, raw, run, u32_of, w};
use crate::*;

pub(crate) fn hex(s: &str) -> Vec<u8> {
    if s == "-" {
        return Vec::new();
    }
    assert!(s.len() % 2 == 0, "odd hex {s}");
    (0..s.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&s[i..i + 2], 16).unwrap())
        .collect()
}

pub(crate) fn to_hex(b: &[u8]) -> String {
    if b.is_empty() {
        return "-".into();
    }
    b.iter().map(|x| format!("{x:02x}")).collect()
}

/// a test identity, its pair as the shim takes it
#[derive(Clone)]
pub(crate) struct Id {
    pub(crate) pair: Vec<u8>,
    pub(crate) public: Vec<u8>,
    pub(crate) private: Vec<u8>,
}

impl Id {
    pub(crate) fn new() -> Self {
        let o = run(identity_generate, &mut w()).unwrap();
        Self::of(&o[0])
    }

    pub(crate) fn from_private(private: &[u8]) -> Self {
        let o = run(identity_from_private, w().bytes(private)).unwrap();
        Self::of(&o[0])
    }

    fn of(pair: &[u8]) -> Self {
        let p = IdentityKeyPair::try_from(pair).unwrap();
        Id {
            pair: pair.to_vec(),
            public: p.identity_key().serialize().to_vec(),
            private: p.private_key().serialize().to_vec(),
        }
    }

    /// through ks_sign, with every check
    pub(crate) fn sign(&self, context: &[u8], body: &[u8]) -> Result<Vec<u8>, Error> {
        run(sign, w().bytes(&self.pair).bytes(context).bytes(body)).map(|mut o| o.remove(0))
    }

    /// xeddsa over the kryfo text past every check of the shim
    pub(crate) fn raw_sign(&self, context: &[u8], body: &[u8]) -> Vec<u8> {
        PrivateKey::deserialize(&self.private)
            .unwrap()
            .calculate_signature(&signed_text(context, body), &mut crate::ops::rng())
            .unwrap()
            .to_vec()
    }
}

/// ed25519 for test faces and onions, rfc 8032 from a seed
pub(crate) struct Ed {
    a: Scalar,
    prefix: Vec<u8>,
    pub(crate) public: Vec<u8>,
}

impl Ed {
    pub(crate) fn new(seed: [u8; 32]) -> Self {
        let h = Sha512::digest(seed);
        let mut a: [u8; 32] = h[..32].try_into().unwrap();
        a[0] &= 248;
        a[31] &= 127;
        a[31] |= 64;
        let public = EdwardsPoint::mul_base_clamped(a)
            .compress()
            .to_bytes()
            .to_vec();
        Ed {
            a: Scalar::from_bytes_mod_order(a),
            prefix: h[32..].to_vec(),
            public,
        }
    }

    pub(crate) fn sign(&self, m: &[u8]) -> Vec<u8> {
        let wide = |parts: &[&[u8]]| {
            let mut d = Sha512::new();
            for p in parts {
                d.update(p);
            }
            Scalar::from_bytes_mod_order_wide(d.finalize().as_slice().try_into().unwrap())
        };
        let r = wide(&[&self.prefix, m]);
        let big_r = EdwardsPoint::mul_base(&r).compress().to_bytes();
        let k = wide(&[&big_r, &self.public, m]);
        let s = r + k * self.a;
        [&big_r[..], s.as_bytes()].concat()
    }
}

fn rand_bytes(rng: &mut Rng, n: usize) -> Vec<u8> {
    (0..n).map(|_| rng.next() as u8).collect()
}

/// a secp256k1 x-only key: random until it lifts
pub(crate) fn fc_key(rng: &mut Rng) -> Vec<u8> {
    loop {
        let b = rand_bytes(rng, 32);
        if crate::keys::secp_lifts(&b) {
            return b;
        }
    }
}

fn nonzero(rng: &mut Rng) -> u32 {
    loop {
        let v = rng.next() as u32;
        if v != 0 {
            return v;
        }
    }
}

/// session prekeys signed by [by]; the key in the block when [named]. a
/// random registration id on device 1 unless [on] names them
pub(crate) fn block(rng: &mut Rng, by: &Id, named: bool, ec: bool, on: Option<(u32, u8)>) -> Block {
    let (reg, device) = on.unwrap_or_else(|| (nonzero(rng), 1));
    let spk_id = rng.next() as u32;
    let spk = run(
        signed_prekey_generate,
        w().bytes(&by.pair).u32(spk_id).u64(NOW),
    )
    .unwrap();
    let kyber_id = rng.next() as u32;
    let k = run(
        kyber_prekey_generate,
        w().bytes(&by.pair).u32(kyber_id).u64(NOW),
    )
    .unwrap();
    let ec = ec.then(|| {
        let id = rng.next() as u32;
        (id, run(prekey_generate, w().u32(id)).unwrap()[1].clone())
    });
    Block {
        reg,
        device,
        key: named.then(|| by.public.clone()),
        spk_id,
        spk: spk[1].clone(),
        spk_sig: spk[2].clone(),
        kyber_id,
        kyber: k[1].clone(),
        kyber_sig: k[2].clone(),
        ec,
    }
}

pub(crate) const ISSUED: u32 = 497_000;

pub(crate) fn invite_of(rng: &mut Rng, id: &Id) -> Invite {
    let mut inv_id = rand_bytes(rng, 16);
    inv_id[0] |= 1;
    Invite {
        one_time: true,
        issued: ISSUED,
        expires: ISSUED + 7 * 24,
        id: inv_id,
        identity: id.public.clone(),
        first_contact: fc_key(rng),
        onion: None,
        face: None,
        block: None,
        list: None,
        sig: None,
    }
}

fn with_face(mut inv: Invite, face: &Ed, onion: &Ed) -> Invite {
    inv.onion = Some(onion.public.clone());
    inv.face = Some((face.public.clone(), face.sign(&inv.face_text())));
    inv
}

fn signed(mut inv: Invite, by: &Id) -> Invite {
    inv.sig = Some(by.sign(b"invite", &inv.body()).unwrap());
    inv
}

fn raw_signed(mut inv: Invite, by: &Id) -> Vec<u8> {
    inv.sig = Some(by.raw_sign(b"invite", &inv.body()));
    inv.encode()
}

/// an unsigned list of [phone]'s identity with [others], the answering one
/// flagged
pub(crate) fn list_of(rng: &mut Rng, phone: &Id, others: &[(&Id, bool)]) -> DeviceList {
    let mut devices: Vec<u8> = Vec::new();
    while devices.len() < others.len() + 1 {
        let d = 1 + rng.below(127) as u8;
        if !devices.contains(&d) {
            devices.push(d);
        }
    }
    let mut entries = vec![Entry {
        device: devices[0],
        key: phone.public.clone(),
        reg: nonzero(rng),
        phone: true,
        answers: false,
    }];
    for (i, (o, answers)) in others.iter().enumerate() {
        entries.push(Entry {
            device: devices[i + 1],
            key: o.public.clone(),
            reg: nonzero(rng),
            phone: false,
            answers: *answers,
        });
    }
    entries.sort_by_key(|e| e.device);
    DeviceList {
        identity: phone.public.clone(),
        version: rng.next() >> 8,
        entries,
        sig: None,
    }
}

fn signed_list(mut l: DeviceList, by: &Id) -> DeviceList {
    l.sig = Some(by.sign(b"device-list", &l.body()).unwrap());
    l
}

pub(crate) struct Keys {
    pub(crate) ids: Vec<(&'static str, Id)>,
    pub(crate) ana_face: Ed,
    pub(crate) ana_onion: Ed,
    pub(crate) ben_face: Ed,
    pub(crate) ben_onion: Ed,
}

impl Keys {
    pub(crate) fn new() -> Self {
        Self::from(
            [
                "ana0", "ana1", "ben0", "desk", "dev2", "dev3", "dev4", "dev5",
            ]
            .map(|n| (n, Id::new()))
            .to_vec(),
        )
    }

    pub(crate) fn from(ids: Vec<(&'static str, Id)>) -> Self {
        Keys {
            ids,
            ana_face: Ed::new([7; 32]),
            ana_onion: Ed::new([8; 32]),
            ben_face: Ed::new([9; 32]),
            ben_onion: Ed::new([10; 32]),
        }
    }

    pub(crate) fn id(&self, name: &str) -> &Id {
        &self.ids.iter().find(|i| i.0 == name).unwrap().1
    }

    pub(crate) fn name_of(&self, public: &[u8]) -> &'static str {
        self.ids.iter().find(|i| i.1.public == public).unwrap().0
    }
}

#[derive(Clone)]
pub(crate) struct Vector {
    pub(crate) name: String,
    pub(crate) kind: &'static str,
    // the identity a device bundle belongs to
    pub(crate) identity: Option<&'static str>,
    pub(crate) bytes: Vec<u8>,
    // bad ones: what refuses it, and the key whose outer signature still
    // holds over it, when one does
    pub(crate) want: Option<Error>,
    pub(crate) signer: Option<&'static str>,
}

fn good(name: &str, kind: &'static str, identity: Option<&'static str>, bytes: Vec<u8>) -> Vector {
    Vector {
        name: name.into(),
        kind,
        identity,
        bytes,
        want: None,
        signer: None,
    }
}

fn bad(
    name: &str,
    kind: &'static str,
    want: Error,
    signer: Option<&'static str>,
    bytes: Vec<u8>,
) -> Vector {
    Vector {
        name: name.into(),
        kind,
        identity: None,
        bytes,
        want: Some(want),
        signer,
    }
}

// the frames each good vector is, as structs, for the bad ones to start from
pub(crate) struct Goods {
    pub(crate) qr_ci: Invite,
    pub(crate) link_ci: Invite,
    pub(crate) link_p0: Invite,
    pub(crate) pool_link: Invite,
    pub(crate) list_pool: DeviceList,
    pub(crate) hello: Hello,
    pub(crate) heal: Heal,
    pub(crate) heal_device: Heal,
    pub(crate) bundle_phone: DeviceBundle,
    pub(crate) mv: Move,
    pub(crate) vectors: Vec<Vector>,
}

pub(crate) fn goods(rng: &mut Rng, k: &Keys) -> Goods {
    let (ana0, ana1, ben0, desk) = (k.id("ana0"), k.id("ana1"), k.id("ben0"), k.id("desk"));
    let mut v = Vec::new();

    let qr_ci = signed(invite_of(rng, ana1), ana1);
    v.push(good("invite_qr_ci", "invite", None, qr_ci.encode()));
    let mut roster = invite_of(rng, ana1);
    roster.one_time = false;
    roster.expires = roster.issued + 365 * 24;
    v.push(good(
        "invite_roster",
        "invite",
        None,
        signed(roster, ana1).encode(),
    ));
    let mut qr_p0 = with_face(invite_of(rng, ana0), &k.ana_face, &k.ana_onion);
    qr_p0.one_time = false;
    let qr_p0 = signed(qr_p0, ana0);
    v.push(good("invite_qr_p0", "invite", None, qr_p0.encode()));
    let mut link_ci = invite_of(rng, ana1);
    link_ci.block = Some(block(rng, ana1, false, true, None));
    let link_ci = signed(link_ci, ana1);
    v.push(good("invite_link_ci", "invite", None, link_ci.encode()));
    let mut link_p0 = with_face(invite_of(rng, ana0), &k.ana_face, &k.ana_onion);
    link_p0.one_time = false;
    link_p0.expires = link_p0.issued + 365 * 24;
    link_p0.block = Some(block(rng, ana0, false, false, None));
    let link_p0 = signed(link_p0, ana0);
    v.push(good("invite_link_p0", "invite", None, link_p0.encode()));
    let mut once_p0 = invite_of(rng, ana0);
    once_p0.block = Some(block(rng, ana0, false, true, None));
    let once_p0 = signed(with_face(once_p0, &k.ana_face, &k.ana_onion), ana0);
    v.push(good("invite_once_p0", "invite", None, once_p0.encode()));
    let mut life = invite_of(rng, ana1);
    life.expires = life.issued + MAX_LIFE;
    v.push(good(
        "invite_life_max",
        "invite",
        None,
        signed(life, ana1).encode(),
    ));

    // a pool identity: the desktop answers, its bundle runs on its own key
    let list_pool = signed_list(list_of(rng, ana1, &[(desk, true)]), ana1);
    let mut pool_qr = invite_of(rng, ana1);
    pool_qr.list = Some(list_pool.clone());
    v.push(good(
        "invite_pool_qr",
        "invite",
        None,
        signed(pool_qr, ana1).encode(),
    ));
    let answering = list_pool.answering().unwrap().clone();
    let mut pool_link = invite_of(rng, ana1);
    pool_link.list = Some(list_pool.clone());
    pool_link.block = Some(block(
        rng,
        desk,
        true,
        true,
        Some((answering.reg, answering.device)),
    ));
    let pool_link = signed(pool_link, ana1);
    v.push(good("invite_pool_link", "invite", None, pool_link.encode()));

    // ben answers ana's qr with a one-time invite of his own
    let mut inner = invite_of(rng, ben0);
    inner.block = Some(block(rng, ben0, false, true, None));
    let inner = signed(with_face(inner, &k.ben_face, &k.ben_onion), ben0);
    let mut hello = Hello {
        answers: qr_p0.id.clone(),
        owner: ana0.public.clone(),
        invite: inner.clone(),
        sig: None,
    };
    hello.sig = Some(ben0.sign(b"hello", &hello.body()).unwrap());
    v.push(good("hello_1", "hello", None, hello.encode()));
    let mut v3 = Hello {
        answers: vec![0; 16],
        owner: k.id("dev2").public.clone(),
        invite: inner,
        sig: None,
    };
    v3.sig = Some(ben0.sign(b"hello", &v3.body()).unwrap());
    v.push(good("hello_v3_link", "hello", None, v3.encode()));

    let mut heal = Heal {
        restored: false,
        issued: ISSUED,
        nonce: rand_bytes(rng, 16),
        identity: ana0.public.clone(),
        peer: ben0.public.clone(),
        since: 0,
        block: block(rng, ana0, false, false, None),
        sig: None,
    };
    heal.sig = Some(ana0.sign(b"heal", &heal.body()).unwrap());
    v.push(good("heal_phone", "heal", None, heal.encode()));
    let mut restored = heal.clone();
    restored.restored = true;
    restored.since = (ISSUED - 30 * 24) / 24 * 24;
    restored.nonce = rand_bytes(rng, 16);
    restored.sig = Some(ana0.sign(b"heal", &restored.body()).unwrap());
    v.push(good("heal_restored", "heal", None, restored.encode()));
    let mut heal_device = Heal {
        restored: false,
        issued: ISSUED,
        nonce: rand_bytes(rng, 16),
        identity: ana1.public.clone(),
        peer: ben0.public.clone(),
        since: 0,
        block: block(
            rng,
            desk,
            true,
            false,
            Some((answering.reg, answering.device)),
        ),
        sig: None,
    };
    heal_device.sig = Some(desk.sign(b"heal", &heal_device.body()).unwrap());
    v.push(good("heal_device", "heal", None, heal_device.encode()));

    let one = signed_list(list_of(rng, ana0, &[]), ana0);
    v.push(good("device_list_1", "device-list", None, one.encode()));
    v.push(good(
        "device_list_pool",
        "device-list",
        None,
        list_pool.encode(),
    ));
    let devs: Vec<(&Id, bool)> = ["desk", "dev2", "dev3", "dev4", "dev5"]
        .iter()
        .map(|n| (k.id(n), false))
        .collect();
    let six = signed_list(list_of(rng, ana0, &devs), ana0);
    v.push(good("device_list_6", "device-list", None, six.encode()));

    let bundle_phone = DeviceBundle {
        block: block(rng, ana0, false, false, None),
    };
    v.push(good(
        "device_bundle_phone",
        "device-bundle",
        Some("ana0"),
        bundle_phone.encode(),
    ));
    let desk_bundle = DeviceBundle {
        block: block(
            rng,
            desk,
            true,
            true,
            Some((answering.reg, answering.device)),
        ),
    };
    v.push(good(
        "device_bundle_desk",
        "device-bundle",
        Some("ana1"),
        desk_bundle.encode(),
    ));

    let mv = Move {
        old: ana0.public.clone(),
        peer: ben0.public.clone(),
        new: ana1.public.clone(),
        hash: Sha256::digest(link_ci.encode()).to_vec(),
    };
    v.push(good("move_1", "move", None, mv.encode()));

    Goods {
        qr_ci,
        link_ci,
        link_p0,
        pool_link,
        list_pool,
        hello,
        heal,
        heal_device,
        bundle_phone,
        mv,
        vectors: v,
    }
}

// keys one step off their one form
pub(crate) struct BadKeys {
    pub(crate) top_bit: Vec<u8>,
    pub(crate) base_plus_p: Vec<u8>,
    pub(crate) zero: Vec<u8>,
    pub(crate) mixed_order: Vec<u8>,
    pub(crate) twist: Vec<u8>,
}

pub(crate) fn bad_keys(of: &[u8]) -> BadKeys {
    let mut top_bit = of.to_vec();
    top_bit[32] |= 0x80;
    // u = 9 + p: the base point again, refused only by the range check
    let mut base_plus_p = vec![0x05, 0xf6];
    base_plus_p.extend_from_slice(&[0xff; 30]);
    base_plus_p.push(0x7f);
    // a prime order point plus one of order 4
    let ed = MontgomeryPoint(of[1..].try_into().unwrap())
        .to_edwards(0)
        .unwrap();
    let t4 = CompressedEdwardsY([0; 32]).decompress().unwrap();
    let mixed = (ed + t4).to_montgomery().to_bytes();
    // the first u, from 2 up, that is on the twist
    let twist = (2u8..)
        .find(|u| {
            let mut b = [0u8; 32];
            b[0] = *u;
            MontgomeryPoint(b).to_edwards(0).is_none()
        })
        .unwrap();
    let mut tw = vec![0x05, twist];
    tw.extend_from_slice(&[0; 31]);
    BadKeys {
        top_bit,
        base_plus_p,
        zero: [&[0x05u8][..], &[0; 32]].concat(),
        mixed_order: [&[0x05u8][..], &mixed].concat(),
        twist: tw,
    }
}

pub(crate) fn bads(rng: &mut Rng, k: &Keys, g: &Goods) -> Vec<Vector> {
    use Error::{Format, Signature};
    let (ana0, ana1, ben0, desk) = (k.id("ana0"), k.id("ana1"), k.id("ben0"), k.id("desk"));
    let bk = bad_keys(&ana1.public);
    let mut v = Vec::new();
    let inv = |f: &dyn Fn(&mut Invite)| {
        let mut x = g.qr_ci.clone();
        f(&mut x);
        raw_signed(x, ana1)
    };
    let link = |f: &dyn Fn(&mut Invite)| {
        let mut x = g.link_ci.clone();
        f(&mut x);
        raw_signed(x, ana1)
    };
    // byte edits of a body, signed again
    let resign = |body: Vec<u8>, by: &Id, ctx: &[u8]| {
        let s = by.raw_sign(ctx, &body);
        [body, s].concat()
    };
    let qr_body = g.qr_ci.body();
    let at = |name: &str| -> usize {
        // offsets in a KIN4 body
        match name {
            "flags" => 5,
            "issued" => 7,
            "expires" => 11,
            "id" => 15,
            "identity" => 31,
            "fc" => 64,
            "after_fc" => 96,
            _ => unreachable!(),
        }
    };

    // the frame as a whole
    v.push(bad(
        "invite_trailing_byte",
        "invite",
        Format,
        None,
        [g.qr_ci.encode(), vec![0]].concat(),
    ));
    let e = g.qr_ci.encode();
    v.push(bad(
        "invite_short",
        "invite",
        Format,
        None,
        e[..e.len() - 1].to_vec(),
    ));
    let mut b = qr_body.clone();
    b[4] = 2;
    v.push(bad(
        "invite_version_2",
        "invite",
        Format,
        Some("ana1"),
        resign(b, ana1, b"invite"),
    ));
    let mut b = qr_body.clone();
    b[at("flags")] = 0x00;
    b[at("flags") + 1] = 0x21;
    v.push(bad(
        "invite_unknown_flag",
        "invite",
        Format,
        Some("ana1"),
        resign(b, ana1, b"invite"),
    ));
    let mut b = qr_body.clone();
    b[0] = b'k';
    v.push(bad(
        "invite_magic_case",
        "invite",
        Format,
        Some("ana1"),
        resign(b, ana1, b"invite"),
    ));
    // times
    v.push(bad(
        "invite_expires_at_issued",
        "invite",
        Format,
        Some("ana1"),
        inv(&|x| x.expires = x.issued),
    ));
    v.push(bad(
        "invite_expires_before",
        "invite",
        Format,
        Some("ana1"),
        inv(&|x| x.expires = x.issued - 1),
    ));
    v.push(bad(
        "invite_life_too_long",
        "invite",
        Format,
        Some("ana1"),
        inv(&|x| x.expires = x.issued + MAX_LIFE + 1),
    ));
    v.push(bad(
        "invite_id_zero",
        "invite",
        Format,
        Some("ana1"),
        inv(&|x| x.id = vec![0; 16]),
    ));
    // the identity in each wrong form; signed by ana1 over the bytes
    for (n, key) in [
        ("top_bit", &bk.top_bit),
        ("base_plus_p", &bk.base_plus_p),
        ("zero", &bk.zero),
        ("mixed_order", &bk.mixed_order),
        ("twist", &bk.twist),
    ] {
        let mut b = qr_body.clone();
        b[at("identity")..at("fc")].copy_from_slice(key);
        v.push(bad(
            &format!("invite_identity_{n}"),
            "invite",
            Format,
            None,
            resign(b, ana1, b"invite"),
        ));
    }
    let mut b = qr_body.clone();
    b[at("identity")] = 0x06;
    v.push(bad(
        "invite_identity_type",
        "invite",
        Format,
        None,
        resign(b, ana1, b"invite"),
    ));
    // first-contact keys that are no point
    let off_curve = (0u8..)
        .map(|i| {
            let mut x = g.qr_ci.first_contact.clone();
            x[31] = i;
            x
        })
        .find(|x| !crate::keys::secp_lifts(x))
        .unwrap();
    v.push(bad(
        "invite_fc_off_curve",
        "invite",
        Format,
        Some("ana1"),
        inv(&|x| x.first_contact = off_curve.clone()),
    ));
    let mut p = hex("fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f");
    v.push(bad(
        "invite_fc_at_p",
        "invite",
        Format,
        Some("ana1"),
        inv(&|x| x.first_contact = p.clone()),
    ));
    // p + 1, a second form of x = 1
    p[31] = 0x30;
    v.push(bad(
        "invite_fc_above_p",
        "invite",
        Format,
        Some("ana1"),
        inv(&|x| x.first_contact = p.clone()),
    ));
    // the face and the onion
    let small: Vec<u8> = {
        let mut b = vec![0xffu8; 32];
        b[0] = 0xec;
        b[31] = 0x7f;
        b
    };
    let p0 = g.link_p0.clone();
    let face_of = |f: &dyn Fn(&mut Invite)| {
        let mut x = p0.clone();
        f(&mut x);
        raw_signed(x, ana0)
    };
    v.push(bad(
        "invite_face_small_order",
        "invite",
        Format,
        Some("ana0"),
        face_of(&|x| x.face.as_mut().unwrap().0 = small.clone()),
    ));
    let mut y_plus_p = vec![0xffu8; 32];
    y_plus_p[0] = 0xee;
    y_plus_p[31] = 0x7f;
    v.push(bad(
        "invite_face_y_plus_p",
        "invite",
        Format,
        Some("ana0"),
        face_of(&|x| x.face.as_mut().unwrap().0 = y_plus_p.clone()),
    ));
    v.push(bad(
        "invite_face_s_plus_l",
        "invite",
        Format,
        Some("ana0"),
        face_of(&|x| {
            let s = &mut x.face.as_mut().unwrap().1;
            add_l(&mut s[32..]);
        }),
    ));
    v.push(bad(
        "invite_face_sig_wrong",
        "invite",
        Signature,
        Some("ana0"),
        face_of(&|x| x.face.as_mut().unwrap().1[3] ^= 1),
    ));
    v.push(bad(
        "invite_face_other_invite",
        "invite",
        Signature,
        Some("ana0"),
        face_of(&|x| x.id[0] ^= 2),
    ));
    v.push(bad(
        "invite_onion_small_order",
        "invite",
        Format,
        Some("ana0"),
        face_of(&|x| x.onion = Some(small.clone())),
    ));
    // the bundle block
    v.push(bad(
        "block_reg_zero",
        "invite",
        Format,
        Some("ana1"),
        link(&|x| x.block.as_mut().unwrap().reg = 0),
    ));
    v.push(bad(
        "block_device_zero",
        "invite",
        Format,
        Some("ana1"),
        link(&|x| x.block.as_mut().unwrap().device = 0),
    ));
    v.push(bad(
        "block_device_128",
        "invite",
        Format,
        Some("ana1"),
        link(&|x| x.block.as_mut().unwrap().device = 128),
    ));
    let lb = g.link_ci.body();
    let flags_at = at("after_fc") + 5;
    let mut b = lb.clone();
    b[flags_at] |= 4;
    v.push(bad(
        "block_unknown_flag",
        "invite",
        Format,
        Some("ana1"),
        resign(b, ana1, b"invite"),
    ));
    v.push(bad(
        "block_key_without_list",
        "invite",
        Format,
        Some("ana1"),
        link(&|x| x.block.as_mut().unwrap().key = Some(desk.public.clone())),
    ));
    v.push(bad(
        "block_key_is_identity",
        "invite",
        Format,
        Some("ana1"),
        link(&|x| x.block.as_mut().unwrap().key = Some(ana1.public.clone())),
    ));
    v.push(bad(
        "block_once_without_ec",
        "invite",
        Format,
        Some("ana1"),
        link(&|x| x.block.as_mut().unwrap().ec = None),
    ));
    v.push(bad(
        "block_ec_is_spk",
        "invite",
        Format,
        Some("ana1"),
        link(&|x| {
            let b = x.block.as_mut().unwrap();
            b.ec.as_mut().unwrap().1 = b.spk.clone();
        }),
    ));
    v.push(bad(
        "block_spk_top_bit",
        "invite",
        Format,
        Some("ana1"),
        link(&|x| x.block.as_mut().unwrap().spk[32] |= 0x80),
    ));
    v.push(bad(
        "block_ec_top_bit",
        "invite",
        Format,
        Some("ana1"),
        link(&|x| x.block.as_mut().unwrap().ec.as_mut().unwrap().1[32] |= 0x80),
    ));
    v.push(bad(
        "block_spk_sig_s_plus_l",
        "invite",
        Format,
        Some("ana1"),
        link(&|x| add_l(&mut x.block.as_mut().unwrap().spk_sig[32..])),
    ));
    v.push(bad(
        "block_kyber_short",
        "invite",
        Format,
        Some("ana1"),
        link(&|x| {
            x.block.as_mut().unwrap().kyber.pop();
        }),
    ));
    v.push(bad(
        "block_kyber_type",
        "invite",
        Format,
        Some("ana1"),
        link(&|x| x.block.as_mut().unwrap().kyber[0] = 0x09),
    ));
    v.push(bad(
        "block_spk_sig_wrong",
        "invite",
        Signature,
        Some("ana1"),
        link(&|x| x.block.as_mut().unwrap().spk_sig[2] ^= 1),
    ));
    // the kyber key's signature moved onto the spk: a prekey signature for another key
    v.push(bad(
        "block_kyber_sig_is_spk_sig",
        "invite",
        Signature,
        Some("ana1"),
        link(&|x| {
            let b = x.block.as_mut().unwrap();
            b.kyber_sig = b.spk_sig.clone();
        }),
    ));
    let other = block(rng, ben0, false, true, None);
    v.push(bad(
        "block_kyber_of_another",
        "invite",
        Signature,
        Some("ana1"),
        link(&|x| {
            let b = x.block.as_mut().unwrap();
            b.kyber = other.kyber.clone();
            b.kyber_sig = other.kyber_sig.clone();
        }),
    ));
    // the list and the answering device
    let pool = |f: &dyn Fn(&mut Invite)| {
        let mut x = g.pool_link.clone();
        f(&mut x);
        raw_signed(x, ana1)
    };
    v.push(bad(
        "pool_block_not_answering",
        "invite",
        Format,
        Some("ana1"),
        pool(&|x| x.block.as_mut().unwrap().device ^= 0x40),
    ));
    v.push(bad(
        "pool_block_reg_not_listed",
        "invite",
        Format,
        Some("ana1"),
        pool(&|x| x.block.as_mut().unwrap().reg ^= 1),
    ));
    v.push(bad(
        "pool_block_on_identity",
        "invite",
        Format,
        Some("ana1"),
        pool(&|x| x.block.as_mut().unwrap().key = None),
    ));
    let other_list = signed_list(list_of(rng, ana0, &[(desk, true)]), ana0);
    v.push(bad(
        "pool_list_of_another",
        "invite",
        Format,
        Some("ana1"),
        pool(&|x| x.list = Some(other_list.clone())),
    ));
    let quiet = signed_list(list_of(rng, ana1, &[(desk, false)]), ana1);
    v.push(bad(
        "pool_list_no_answering",
        "invite",
        Format,
        Some("ana1"),
        pool(&|x| {
            x.list = Some(quiet.clone());
            x.block = None;
        }),
    ));
    v.push(bad(
        "pool_list_sig_wrong",
        "invite",
        Signature,
        Some("ana1"),
        pool(&|x| x.list.as_mut().unwrap().sig.as_mut().unwrap()[1] ^= 1),
    ));
    let mut b = g.pool_link.body();
    let n = b.len();
    let len_at = n - g.list_pool.encode().len() - 2;
    b[len_at + 1] ^= 1;
    v.push(bad(
        "pool_list_length",
        "invite",
        Format,
        Some("ana1"),
        resign(b, ana1, b"invite"),
    ));
    // the invite's own signature
    let mut e = g.qr_ci.encode();
    let n = e.len();
    e[n - 40] ^= 1;
    v.push(bad("invite_sig_wrong", "invite", Signature, None, e));
    v.push(bad(
        "invite_sig_by_another",
        "invite",
        Signature,
        Some("ana0"),
        raw_signed(g.qr_ci.clone(), ana0),
    ));
    let mut e = g.qr_ci.encode();
    add_l(&mut e[n - 32..]);
    v.push(bad("invite_sig_s_plus_l", "invite", Format, None, e));
    // a hello signature where an invite one goes
    let mut x = g.qr_ci.clone();
    x.sig = Some(ana1.raw_sign(b"hello", &x.body()));
    v.push(bad(
        "invite_sig_other_context",
        "invite",
        Signature,
        None,
        x.encode(),
    ));

    // device lists
    let lst = |f: &dyn Fn(&mut DeviceList)| {
        let mut x = g.list_pool.clone();
        f(&mut x);
        x.sig = Some(ana1.raw_sign(b"device-list", &x.body()));
        x.encode()
    };
    v.push(bad(
        "list_two_phones",
        "device-list",
        Format,
        Some("ana1"),
        lst(&|x| x.entries.iter_mut().for_each(|e| e.phone = true)),
    ));
    v.push(bad(
        "list_no_phone",
        "device-list",
        Format,
        Some("ana1"),
        lst(&|x| x.entries.iter_mut().for_each(|e| e.phone = false)),
    ));
    v.push(bad(
        "list_phone_not_identity",
        "device-list",
        Format,
        Some("ana1"),
        lst(&|x| x.identity = ana0.public.clone()),
    ));
    v.push(bad(
        "list_unsorted",
        "device-list",
        Format,
        Some("ana1"),
        lst(&|x| x.entries.reverse()),
    ));
    v.push(bad(
        "list_same_device_twice",
        "device-list",
        Format,
        Some("ana1"),
        lst(&|x| {
            let d = x.entries[0].device;
            x.entries[1].device = d;
        }),
    ));
    v.push(bad(
        "list_device_zero",
        "device-list",
        Format,
        Some("ana1"),
        lst(&|x| x.entries[0].device = 0),
    ));
    v.push(bad(
        "list_device_128",
        "device-list",
        Format,
        Some("ana1"),
        lst(&|x| x.entries[1].device = 128),
    ));
    v.push(bad(
        "list_reg_zero",
        "device-list",
        Format,
        Some("ana1"),
        lst(&|x| x.entries[0].reg = 0),
    ));
    v.push(bad(
        "list_phone_answers",
        "device-list",
        Format,
        Some("ana1"),
        lst(&|x| x.entries.iter_mut().for_each(|e| e.answers = e.phone)),
    ));
    v.push(bad(
        "list_two_answering",
        "device-list",
        Format,
        Some("ana1"),
        {
            let mut x = list_of(rng, ana1, &[(desk, true), (k.id("dev2"), true)]);
            x.sig = Some(ana1.raw_sign(b"device-list", &x.body()));
            x.encode()
        },
    ));
    v.push(bad(
        "list_same_key_twice",
        "device-list",
        Format,
        Some("ana1"),
        {
            let mut x = list_of(rng, ana1, &[(desk, false), (desk, false)]);
            x.sig = Some(ana1.raw_sign(b"device-list", &x.body()));
            x.encode()
        },
    ));
    v.push(bad(
        "list_device_is_identity",
        "device-list",
        Format,
        Some("ana1"),
        lst(&|x| {
            for e in x.entries.iter_mut().filter(|e| !e.phone) {
                e.key = ana1.public.clone();
            }
        }),
    ));
    v.push(bad(
        "list_device_top_bit",
        "device-list",
        Format,
        Some("ana1"),
        lst(&|x| {
            for e in x.entries.iter_mut().filter(|e| !e.phone) {
                e.key[32] |= 0x80;
            }
        }),
    ));
    let mut x = list_of(rng, ana0, &[(desk, false)]);
    x.entries.clear();
    x.sig = Some(ana0.raw_sign(b"device-list", &x.body()));
    v.push(bad(
        "list_empty",
        "device-list",
        Format,
        Some("ana0"),
        x.encode(),
    ));
    let names = ["desk", "dev2", "dev3", "dev4", "dev5", "ben0"];
    let seven: Vec<(&Id, bool)> = names.iter().map(|n| (k.id(n), false)).collect();
    let mut x = list_of(rng, ana0, &seven);
    x.sig = Some(ana0.raw_sign(b"device-list", &x.body()));
    v.push(bad(
        "list_seven",
        "device-list",
        Format,
        Some("ana0"),
        x.encode(),
    ));
    let mut b = g.list_pool.body();
    let flags_at = 4 + 33 + 8 + 1 + 1 + 33 + 4;
    b[flags_at] |= 4;
    v.push(bad(
        "list_unknown_flag",
        "device-list",
        Format,
        Some("ana1"),
        resign(b, ana1, b"device-list"),
    ));
    v.push(bad(
        "list_sig_by_device",
        "device-list",
        Signature,
        Some("desk"),
        {
            let mut x = g.list_pool.clone();
            x.sig = Some(desk.raw_sign(b"device-list", &x.body()));
            x.encode()
        },
    ));

    // hellos
    let hel = |f: &dyn Fn(&mut Hello), by: &Id| {
        let mut x = g.hello.clone();
        f(&mut x);
        x.sig = Some(by.raw_sign(b"hello", &x.body()));
        x.encode()
    };
    v.push(bad(
        "hello_inner_not_once",
        "hello",
        Format,
        Some("ben0"),
        hel(
            &|x| {
                x.invite.one_time = false;
                x.invite.sig = Some(k.id("ben0").raw_sign(b"invite", &x.invite.body()));
            },
            ben0,
        ),
    ));
    v.push(bad(
        "hello_inner_no_bundle",
        "hello",
        Format,
        Some("ben0"),
        hel(
            &|x| {
                x.invite.block = None;
                x.invite.sig = Some(k.id("ben0").raw_sign(b"invite", &x.invite.body()));
            },
            ben0,
        ),
    ));
    v.push(bad(
        "hello_to_itself",
        "hello",
        Format,
        Some("ben0"),
        hel(&|x| x.owner = k.id("ben0").public.clone(), ben0),
    ));
    v.push(bad(
        "hello_owner_top_bit",
        "hello",
        Format,
        Some("ben0"),
        hel(&|x| x.owner[32] |= 0x80, ben0),
    ));
    v.push(bad(
        "hello_inner_sig_wrong",
        "hello",
        Signature,
        Some("ben0"),
        hel(&|x| x.invite.sig.as_mut().unwrap()[0] ^= 1, ben0),
    ));
    v.push(bad(
        "hello_signed_by_owner",
        "hello",
        Signature,
        Some("ana0"),
        hel(&|_| {}, ana0),
    ));
    let mut b = g.hello.body();
    b[4] = 2;
    v.push(bad(
        "hello_version_2",
        "hello",
        Format,
        Some("ben0"),
        resign(b, ben0, b"hello"),
    ));
    let mut b = g.hello.body();
    b[6] ^= 1;
    v.push(bad(
        "hello_readdressed",
        "hello",
        Signature,
        None,
        [b, g.hello.sig.clone().unwrap()].concat(),
    ));

    // heals
    let hb = |f: &dyn Fn(&mut Heal), by: &Id| {
        let mut x = g.heal.clone();
        f(&mut x);
        x.sig = Some(by.raw_sign(b"heal", &x.body()));
        x.encode()
    };
    v.push(bad("heal_unknown_flag", "heal", Format, Some("ana0"), {
        let mut b = g.heal.body();
        b[5] = 2;
        resign(b, ana0, b"heal")
    }));
    v.push(bad(
        "heal_since_not_a_day",
        "heal",
        Format,
        Some("ana0"),
        hb(
            &|x| {
                x.restored = true;
                x.since = 24 * 1000 + 1;
            },
            ana0,
        ),
    ));
    v.push(bad(
        "heal_since_not_restored",
        "heal",
        Format,
        Some("ana0"),
        hb(&|x| x.since = 24 * 1000, ana0),
    ));
    v.push(bad(
        "heal_peer_is_identity",
        "heal",
        Format,
        Some("ana0"),
        hb(&|x| x.peer = x.identity.clone(), ana0),
    ));
    v.push(bad(
        "heal_block_key_is_identity",
        "heal",
        Format,
        Some("ana0"),
        hb(&|x| x.block.key = Some(x.identity.clone()), ana0),
    ));
    v.push(bad(
        "heal_signed_by_peer",
        "heal",
        Signature,
        Some("ben0"),
        hb(&|_| {}, ben0),
    ));
    v.push(bad(
        "heal_device_signed_by_identity",
        "heal",
        Signature,
        Some("ana1"),
        {
            let mut x = g.heal_device.clone();
            x.sig = Some(ana1.raw_sign(b"heal", &x.body()));
            x.encode()
        },
    ));
    v.push(bad("heal_peer_changed", "heal", Signature, None, {
        let mut x = g.heal.clone();
        x.peer = k.id("dev2").public.clone();
        x.encode()
    }));

    // device bundles
    let mut x = g.bundle_phone.clone();
    x.block.key = Some(ana0.public.clone());
    let mut kb = bad(
        "bundle_key_is_identity",
        "device-bundle",
        Format,
        None,
        x.encode(),
    );
    kb.identity = Some("ana0");
    v.push(kb);
    let mut kb = bad(
        "bundle_of_another",
        "device-bundle",
        Signature,
        None,
        g.bundle_phone.encode(),
    );
    kb.identity = Some("ana1");
    v.push(kb);
    let mut x = g.bundle_phone.encode();
    x[4] = 2;
    let mut kb = bad("bundle_version_2", "device-bundle", Format, None, x);
    kb.identity = Some("ana0");
    v.push(kb);

    // moves
    let m = g.mv.encode();
    v.push(bad(
        "move_short",
        "move",
        Format,
        None,
        m[..MOVE_LEN - 1].to_vec(),
    ));
    v.push(bad(
        "move_long",
        "move",
        Format,
        None,
        [&m[..], &[0]].concat(),
    ));
    v.push(bad(
        "move_98_bytes",
        "move",
        Format,
        None,
        [&m[..66], &m[99..]].concat(),
    ));
    for (n, f) in [
        (
            "old_is_peer",
            Box::new(|x: &mut Move| x.peer = x.old.clone()) as Box<dyn Fn(&mut Move)>,
        ),
        ("old_is_new", Box::new(|x: &mut Move| x.new = x.old.clone())),
        (
            "peer_is_new",
            Box::new(|x: &mut Move| x.new = x.peer.clone()),
        ),
        ("new_top_bit", Box::new(|x: &mut Move| x.new[32] |= 0x80)),
        (
            "peer_zero",
            Box::new(|x: &mut Move| x.peer = [&[0x05u8][..], &[0; 32]].concat()),
        ),
    ] {
        let mut x = g.mv.clone();
        f(&mut x);
        v.push(bad(&format!("move_{n}"), "move", Format, None, x.encode()));
    }
    v
}

// s + l in place, for the second encoding of a signature
pub(crate) fn add_l(s: &mut [u8]) {
    const L: [u8; 32] = [
        0xed, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58, 0xd6, 0x9c, 0xf7, 0xa2, 0xde, 0xf9, 0xde,
        0x14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x10,
    ];
    let mut carry = 0u16;
    for i in 0..32 {
        let t = s[i] as u16 + L[i] as u16 + carry;
        s[i] = t as u8;
        carry = t >> 8;
    }
    assert_eq!(carry, 0);
}

pub(crate) fn parse_of(
    kind: &str,
    b: &[u8],
    identity: Option<&[u8]>,
) -> Result<Vec<Vec<u8>>, Error> {
    run(parse, w().bytes(kind.as_bytes()).bytes(b).opt(identity))
}

// each frame's size from its field widths
fn size_of(name: &str) -> Option<usize> {
    Some(match name {
        "invite_qr_ci" | "invite_roster" | "invite_life_max" => 160,
        "invite_qr_p0" => 288,
        "invite_link_ci" => 1941,
        "invite_link_p0" => 2032,
        "invite_once_p0" => 2069,
        "invite_pool_qr" => 350,
        "invite_pool_link" => 2164,
        "hello_1" | "hello_v3_link" => 4 + 1 + 16 + 33 + 2069 + 64,
        "heal_phone" | "heal_restored" => 1904,
        "heal_device" => 1937,
        "device_list_1" => 149,
        "device_list_pool" => 188,
        "device_list_6" => 344,
        "device_bundle_phone" => 5 + 1744,
        "device_bundle_desk" => 5 + 1744 + 33 + 37,
        "move_1" => 131,
        _ => return None,
    })
}

pub(crate) struct File {
    pub(crate) keys: Keys,
    pub(crate) vectors: Vec<Vector>,
}

pub(crate) fn file() -> File {
    let mut ids = Vec::new();
    let mut vectors = Vec::new();
    let leak = |s: &str| -> &'static str { Box::leak(s.to_string().into_boxed_str()) };
    for line in include_str!("../testdata/formats_v1.txt")
        .lines()
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
    {
        let f: Vec<&str> = line.split(' ').collect();
        let opt = |s: &str| (s != "-").then(|| leak(s));
        match f[..] {
            ["key", name, private, public] => {
                let id = Id::from_private(&hex(private));
                assert_eq!(id.public, hex(public), "{name}");
                ids.push((leak(name), id));
            }
            ["good", name, kind, identity, b] => {
                vectors.push(good(name, leak(kind), opt(identity), hex(b)));
            }
            ["bad", name, kind, identity, want, signer, b] => {
                let mut x = bad(name, leak(kind), err_of(want), opt(signer), hex(b));
                x.identity = opt(identity);
                vectors.push(x);
            }
            _ => panic!("line {line}"),
        }
    }
    File {
        keys: Keys::from(ids),
        vectors,
    }
}

pub(crate) fn err_name(e: Error) -> &'static str {
    match e {
        Error::Format => "format",
        Error::Signature => "signature",
        Error::Key => "key",
        Error::Args => "args",
        Error::Signer => "signer",
        _ => panic!("{e:?}"),
    }
}

fn err_of(s: &str) -> Error {
    match s {
        "format" => Error::Format,
        "signature" => Error::Signature,
        "key" => Error::Key,
        "args" => Error::Args,
        "signer" => Error::Signer,
        _ => panic!("{s}"),
    }
}

fn identity_of<'a>(k: &'a Keys, v: &Vector) -> Option<&'a [u8]> {
    v.identity.map(|n| k.id(n).public.as_slice())
}

// what every good vector and every bad one must do, from the file or fresh
fn hold(k: &Keys, vectors: &[Vector]) -> HashMap<&'static str, usize> {
    let mut kinds = HashMap::new();
    for v in vectors {
        let id = identity_of(k, v);
        match v.want {
            None => {
                let o =
                    parse_of(v.kind, &v.bytes, id).unwrap_or_else(|e| panic!("{}: {e:?}", v.name));
                if let Some(n) = size_of(&v.name) {
                    assert_eq!(v.bytes.len(), n, "{}", v.name);
                }
                fields_hold(k, v, &o);
                *kinds.entry(v.kind).or_insert(0) += 1;
            }
            Some(want) => {
                assert_eq!(parse_of(v.kind, &v.bytes, id), Err(want), "{}", v.name);
                // signed again after the change: only the rule refuses it
                if let Some(s) = v.signer {
                    let (body, sig) = v.bytes.split_at(v.bytes.len() - 64);
                    let key = PublicKey::deserialize(&k.id(s).public).unwrap();
                    assert!(
                        key.verify_signature(&signed_text(v.kind.as_bytes(), body), sig),
                        "{} not signed by {s}",
                        v.name
                    );
                }
            }
        }
    }
    kinds
}

fn every_kind_in(kinds: &HashMap<&'static str, usize>) {
    for (kind, _) in KINDS {
        assert!(kinds.get(kind).copied().unwrap_or(0) >= 1, "no good {kind}");
    }
}

// the fields ks_parse hands back say what the bytes say
fn fields_hold(k: &Keys, v: &Vector, o: &[Vec<u8>]) {
    let block_ok = |b: &[Vec<u8>], signer: &[u8]| {
        assert_eq!(b.len(), 12);
        // the bundle bytes are the one the shim builds sessions from
        let f = run(bundle_parse, w().bytes(&b[11])).unwrap();
        assert_eq!(f[10], signer, "{}", v.name);
        assert_eq!(f[5], b[4]);
        assert_eq!(f[8], b[7]);
        assert_eq!(f[3], b[10]);
    };
    match v.kind {
        "invite" => {
            assert_eq!(o.len(), 24, "{}", v.name);
            let x = formats::invite(&v.bytes, true).unwrap();
            assert_eq!(u32_of(&o[0]), x.flags() as u32);
            assert_eq!(o[4], x.identity);
            assert_eq!(o[10], x.answering());
            assert_eq!(Some(&o[11]), x.sig.as_ref());
            if x.block.is_some() {
                block_ok(&o[12..], x.answering());
            } else {
                assert!(o[12..].iter().all(|f| f.is_empty()));
            }
            if x.list.is_some() {
                assert_ne!(o[10], o[4]);
                assert_eq!(parse_of("device-list", &o[9], None).unwrap()[0], o[4]);
            }
        }
        "hello" => {
            assert_eq!(o.len(), 5);
            let inner = parse_of("invite", &o[2], None).unwrap();
            assert_eq!(inner[4], o[3]);
            assert_ne!(o[1], o[3]);
        }
        "heal" => {
            assert_eq!(o.len(), 20);
            block_ok(&o[8..], &o[6]);
        }
        "device-list" => {
            let n = u32_of(&o[3]) as usize;
            assert_eq!(o.len(), 4 + 4 * n);
            let phone = (0..n).find(|i| u32_of(&o[4 + 4 * i + 3]) & 1 == 1).unwrap();
            assert_eq!(o[4 + 4 * phone + 1], o[0]);
        }
        "device-bundle" => {
            assert_eq!(o.len(), 13);
            block_ok(&o[1..], &o[0]);
            let id = identity_of(k, v).unwrap();
            let x = formats::device_bundle(&v.bytes, id).unwrap();
            assert_eq!(x.block.key.is_some(), o[0] != id);
        }
        "move" => {
            assert_eq!(o.concat(), v.bytes);
        }
        _ => panic!("{}", v.kind),
    }
}

#[test]
fn the_vectors_hold() {
    let f = file();
    assert!(f.vectors.iter().filter(|v| v.want.is_some()).count() > 80);
    every_kind_in(&hold(&f.keys, &f.vectors));
}

#[test]
fn the_builders_make_what_the_parsers_take() {
    let k = Keys::new();
    let mut rng = Rng(0x1234_5678_9abc_def1);
    let g = goods(&mut rng, &k);
    let b = bads(&mut rng, &k, &g);
    every_kind_in(&hold(&k, &g.vectors));
    assert!(hold(&k, &b).is_empty());
    // the file holds a vector of every name the builders make
    let f = file();
    for v in g.vectors.iter().chain(&b) {
        assert!(
            f.vectors
                .iter()
                .any(|x| x.name == v.name && x.want == v.want),
            "{} not in the file",
            v.name
        );
    }
    assert_eq!(f.vectors.len(), g.vectors.len() + b.len());
}

#[test]
fn every_byte_of_a_signed_frame_counts() {
    let f = file();
    for v in f
        .vectors
        .iter()
        .filter(|v| v.want.is_none() && v.kind != "device-bundle" && v.kind != "move")
    {
        // every byte outside the kyber key, and every 37th inside it
        let kyber = match v.kind {
            "invite" => formats::invite(&v.bytes, true)
                .unwrap()
                .block
                .map(|b| b.kyber),
            "hello" => formats::hello(&v.bytes, true)
                .unwrap()
                .invite
                .block
                .map(|b| b.kyber),
            "heal" => Some(formats::heal(&v.bytes, true).unwrap().block.kyber),
            _ => None,
        };
        let start = kyber.and_then(|k| v.bytes.windows(k.len()).position(|x| x == k));
        let in_kyber = |i: usize| start.is_some_and(|s| i > s && i < s + 1569);
        for i in 0..v.bytes.len() {
            if in_kyber(i) && i % 37 != 0 {
                continue;
            }
            for bit in [0x01, 0x80] {
                let mut b = v.bytes.clone();
                b[i] ^= bit;
                assert!(
                    parse_of(v.kind, &b, None).is_err(),
                    "{} byte {i} bit {bit}",
                    v.name
                );
            }
        }
        // cut anywhere: refused
        for n in (0..v.bytes.len()).step_by(7) {
            assert!(
                parse_of(v.kind, &v.bytes[..n], None).is_err(),
                "{} cut at {n}",
                v.name
            );
        }
    }
}

#[test]
fn unsigned_frames_take_no_other_form() {
    let f = file();
    for v in f
        .vectors
        .iter()
        .filter(|v| v.want.is_none() && (v.kind == "device-bundle" || v.kind == "move"))
    {
        let id = identity_of(&f.keys, v);
        for n in 0..v.bytes.len() {
            assert!(
                parse_of(v.kind, &v.bytes[..n], id).is_err(),
                "{} cut at {n}",
                v.name
            );
        }
        assert!(parse_of(v.kind, &[&v.bytes[..], &[0]].concat(), id).is_err());
    }
}

#[test]
fn parse_takes_garbage() {
    let f = file();
    let mut rng = Rng(0x0dd_ba11_cafe_f00d);
    for v in f.vectors.iter().filter(|v| v.want.is_none()) {
        let id = identity_of(&f.keys, v);
        let seed = w().bytes(v.kind.as_bytes()).bytes(&v.bytes).opt(id).done();
        for _ in 0..60 {
            raw(parse, &mutate(&mut rng, &seed));
            // the frame mutated inside otherwise good input
            let b = mutate(&mut rng, &v.bytes);
            raw(
                parse,
                &w().bytes(v.kind.as_bytes()).bytes(&b).opt(id).done(),
            );
        }
    }
    // a frame of one kind read as every other
    for v in f.vectors.iter().filter(|v| v.want.is_none()) {
        for (other, _) in KINDS.iter().filter(|o| o.0 != v.kind) {
            let id = (*other == "device-bundle").then(|| f.keys.id("ana0").public.as_slice());
            assert!(
                parse_of(other, &v.bytes, id).is_err(),
                "{} as {other}",
                v.name
            );
        }
    }
}

#[test]
fn parse_refuses_its_own_misuse() {
    let f = file();
    let v = f.vectors.iter().find(|v| v.name == "invite_qr_ci").unwrap();
    let ana0 = f.keys.id("ana0").public.clone();
    // a kind off the list, an identity where none goes, none where one does
    for kind in ["Invite", "kin4", "", "block", "face-claim"] {
        assert_eq!(parse_of(kind, &v.bytes, None), Err(Error::Args), "{kind}");
    }
    assert_eq!(parse_of("invite", &v.bytes, Some(&ana0)), Err(Error::Args));
    let b = f
        .vectors
        .iter()
        .find(|v| v.name == "device_bundle_phone")
        .unwrap();
    assert_eq!(parse_of("device-bundle", &b.bytes, None), Err(Error::Args));
    let mut top = ana0.clone();
    top[32] |= 0x80;
    assert_eq!(
        parse_of("device-bundle", &b.bytes, Some(&top)),
        Err(Error::Key)
    );
    assert_eq!(parse_of("invite", &[], None), Err(Error::Format));
    let mut x = w();
    x.bytes(b"invite").bytes(&v.bytes).opt(None).bytes(b"x");
    assert_eq!(run(parse, &mut x), Err(Error::Args));
}

#[test]
fn an_invite_bundle_builds_a_session_its_owner_opens() {
    let mut rng = Rng(0xfeed_beef_1357_2468);
    let ana = Id::new();
    let ben = Id::new();
    // ana's one-time invite, with the records she keeps
    let spk = run(
        signed_prekey_generate,
        w().bytes(&ana.pair).u32(41).u64(NOW),
    )
    .unwrap();
    let ky = run(kyber_prekey_generate, w().bytes(&ana.pair).u32(42).u64(NOW)).unwrap();
    let pk = run(prekey_generate, w().u32(43)).unwrap();
    let mut inv = invite_of(&mut rng, &ana);
    inv.block = Some(Block {
        reg: 77,
        device: 1,
        key: None,
        spk_id: 41,
        spk: spk[1].clone(),
        spk_sig: spk[2].clone(),
        kyber_id: 42,
        kyber: ky[1].clone(),
        kyber_sig: ky[2].clone(),
        ec: Some((43, pk[1].clone())),
    });
    let inv = signed(inv, &ana).encode();
    // ben reads it, and starts from the bundle it hands back
    let o = parse_of("invite", &inv, None).unwrap();
    let s = run(
        session_from_bundle,
        w().bytes(&ben.pair)
            .u32(88)
            .opt(None)
            .bytes(&o[23])
            .u64(NOW)
            .opt(Some(&o[4])),
    )
    .unwrap();
    let m = run(
        encrypt,
        w().bytes(&ben.pair)
            .u32(88)
            .bytes(&s[0])
            .bytes(b"hi ana")
            .u64(NOW)
            .opt(None),
    )
    .unwrap();
    let info = run(prekey_message_info, w().bytes(&m[1])).unwrap();
    assert_eq!(u32_of(&info[0]), 4);
    assert_eq!(u32_of(&info[4]), 42);
    let d = run(
        decrypt_prekey,
        w().bytes(&ana.pair)
            .u32(77)
            .opt(None)
            .bytes(&m[1])
            .bytes(&pk[0])
            .bytes(&spk[0])
            .bytes(&ky[0])
            .opt(None),
    )
    .unwrap();
    assert_eq!(d[0], b"hi ana");
    assert_eq!(d[4], ben.public);
}

// makes testdata/formats_v1.txt and testdata/sig_v1.txt:
//   KS_WRITE_VECTORS=testdata cargo test write_vectors -- --ignored
// keys and xeddsa are random, so a new run gives new bytes; the files are
// what the tests hold to
#[test]
#[ignore]
fn write_vectors() {
    let dir = std::env::var("KS_WRITE_VECTORS").expect("KS_WRITE_VECTORS=<dir>");
    let k = Keys::new();
    let mut rng = Rng(rand::RngCore::next_u64(&mut crate::ops::rng()) | 1);
    let g = goods(&mut rng, &k);
    let b = bads(&mut rng, &k, &g);
    let mut out = String::new();
    out.push_str(
        "# kryfo frames, version 1: the bundle block, KIN4, KHL1, KHB1, KDL2, KDB1 and the\n\
         # move body, as src/formats.rs reads them. made by write_vectors in\n\
         # src/tests_formats.rs; xeddsa is randomised, so these are only checked, never\n\
         # made again. test keys only\n\
         # key name private public\n\
         # good name kind identity bytes\n\
         # bad name kind identity refused-as signer bytes\n\
         #   identity: the identity a device bundle belongs to\n\
         #   signer: the key whose signature at the end still holds, so only the rule refuses it\n",
    );
    for (n, id) in &k.ids {
        out.push_str(&format!(
            "key {n} {} {}\n",
            to_hex(&id.private),
            to_hex(&id.public)
        ));
    }
    for v in g.vectors.iter().chain(&b) {
        let id = v.identity.unwrap_or("-");
        match v.want {
            None => out.push_str(&format!(
                "good {} {} {id} {}\n",
                v.name,
                v.kind,
                to_hex(&v.bytes)
            )),
            Some(e) => out.push_str(&format!(
                "bad {} {} {id} {} {} {}\n",
                v.name,
                v.kind,
                err_name(e),
                v.signer.unwrap_or("-"),
                to_hex(&v.bytes)
            )),
        }
    }
    std::fs::write(format!("{dir}/formats_v1.txt"), out).unwrap();
    std::fs::write(
        format!("{dir}/sig_v1.txt"),
        crate::tests_sig::sig_vectors(&k, &g),
    )
    .unwrap();
}
