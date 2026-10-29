// SPDX-License-Identifier: GPL-3.0-or-later
// ks_sign and ks_verify_ctx against testdata/sig_v1.txt, and the line
// between kryfo's signatures and libsignal's own
use libsignal_protocol::{IdentityKey, IdentityKeyPair, PrivateKey, PublicKey};

use crate::formats::{self, Kind, MOVE_LEN};
use crate::keys::canonical_s;
use crate::sig::{CONTEXTS, PREFIX, signed_text, signers};
use crate::tests::{Party, Rng, mutate, raw, run, w};
use crate::tests_formats::{Goods, Id, Keys, add_l, bad_keys, goods, hex, to_hex};
use crate::*;

struct Good {
    name: String,
    key: Vec<u8>,
    context: String,
    message: Vec<u8>,
    text: Vec<u8>,
    sig: Vec<u8>,
}

struct Bad {
    name: String,
    want: Error,
    // libsignal's own verify takes it: only the shim's checks refuse it
    lax: bool,
    key: Vec<u8>,
    context: String,
    message: Vec<u8>,
    sig: Vec<u8>,
}

#[derive(Default)]
struct Vectors {
    keys: Vec<(String, Vec<u8>, Vec<u8>)>,
    good: Vec<Good>,
    bad: Vec<Bad>,
    // (key, prekey public, libsignal's signature over it)
    prekeys: Vec<(Vec<u8>, Vec<u8>, Vec<u8>)>,
    // (key, other identity, libsignal's alternate identity signature)
    alts: Vec<(Vec<u8>, Vec<u8>, Vec<u8>)>,
}

fn vectors() -> Vectors {
    let mut v = Vectors::default();
    let src = include_str!("../testdata/sig_v1.txt");
    let public_of = |v: &Vectors, name: &str| {
        v.keys
            .iter()
            .find(|k| k.0 == name)
            .unwrap_or_else(|| panic!("no key {name}"))
            .2
            .clone()
    };
    for line in src.lines().filter(|l| !l.is_empty() && !l.starts_with('#')) {
        let f: Vec<&str> = line.split(' ').collect();
        match f[..] {
            ["key", name, private, public] => {
                v.keys.push((name.into(), hex(private), hex(public)));
            }
            ["good", name, key, context, message, text, sig] => {
                let key = public_of(&v, key);
                v.good.push(Good {
                    name: name.into(),
                    key,
                    context: context.into(),
                    message: hex(message),
                    text: hex(text),
                    sig: hex(sig),
                });
            }
            ["bad", name, want, lax, key, context, message, sig] => v.bad.push(Bad {
                name: name.into(),
                want: match want {
                    "key" => Error::Key,
                    "signature" => Error::Signature,
                    "args" => Error::Args,
                    _ => panic!("want {want}"),
                },
                lax: lax == "lax",
                key: hex(key),
                context: context.into(),
                message: hex(message),
                sig: hex(sig),
            }),
            ["prekey", key, public, sig] => {
                let key = public_of(&v, key);
                v.prekeys.push((key, hex(public), hex(sig)));
            }
            ["alt", key, other, sig] => {
                let key = public_of(&v, key);
                v.alts.push((key, hex(other), hex(sig)));
            }
            _ => panic!("line {line}"),
        }
    }
    v
}

fn verify_ctx_of(key: &[u8], context: &[u8], message: &[u8], sig: &[u8]) -> Result<(), Error> {
    run(
        verify_ctx,
        w().bytes(key).bytes(context).bytes(message).bytes(sig),
    )
    .map(|o| assert!(o.is_empty()))
}

fn sign_of(pair: &[u8], context: &[u8], message: &[u8]) -> Result<Vec<u8>, Error> {
    run(sign, w().bytes(pair).bytes(context).bytes(message)).map(|mut o| o.remove(0))
}

// xeddsa over the kryfo text straight from the private key, past every
// check of the shim: what libsignal alone would take
fn raw_sign_with(private: &PrivateKey, context: &[u8], message: &[u8]) -> Vec<u8> {
    private
        .calculate_signature(&signed_text(context, message), &mut crate::ops::rng())
        .unwrap()
        .to_vec()
}

// one real body per context, with the keys that sign it and one that may not
struct Body {
    context: &'static str,
    message: Vec<u8>,
    signers: Vec<Id>,
    not: Id,
}

fn bodies(k: &Keys, g: &Goods) -> Vec<Body> {
    let id = |n: &str| k.id(n).clone();
    vec![
        Body {
            context: "invite",
            message: g.qr_ci.body(),
            signers: vec![id("ana1")],
            not: id("ana0"),
        },
        Body {
            context: "hello",
            message: g.hello.body(),
            signers: vec![id("ben0")],
            not: id("ana0"),
        },
        Body {
            context: "heal",
            message: g.heal.body(),
            signers: vec![id("ana0")],
            not: id("ben0"),
        },
        Body {
            context: "heal",
            message: g.heal_device.body(),
            signers: vec![id("desk")],
            not: id("ana1"),
        },
        Body {
            context: "device-list",
            message: g.list_pool.body(),
            signers: vec![id("ana1")],
            not: id("desk"),
        },
        Body {
            context: "move",
            message: g.mv.encode(),
            signers: vec![id("ana0"), id("ana1")],
            not: id("ben0"),
        },
    ]
}

fn fresh() -> (Keys, Goods) {
    let k = Keys::new();
    let mut rng = Rng(0x7777_1111_3333_5555);
    let g = goods(&mut rng, &k);
    (k, g)
}

// move bodies one step off the one shape
fn moves_refused(m: &[u8]) -> Vec<(&'static str, Vec<u8>)> {
    let mut top = m.to_vec();
    top[98] |= 0x80;
    let mut typed = m.to_vec();
    typed[33] = 0x06;
    let p: Vec<u8> = [&[0x05u8][..], &[0xed], &[0xff; 30], &[0x7f]].concat();
    let zero: Vec<u8> = [&[0x05u8][..], &[0; 32]].concat();
    vec![
        ("short", m[..MOVE_LEN - 1].to_vec()),
        ("long", [m, &[0]].concat()),
        ("two_keys", [&m[..66], &m[99..]].concat()),
        ("old_twice", [&m[..33], &m[..33], &m[66..]].concat()),
        ("new_is_peer", [&m[..66], &m[33..66], &m[99..]].concat()),
        ("new_key_top_bit", top),
        ("peer_key_type", typed),
        ("old_key_at_p", [&p[..], &m[33..]].concat()),
        ("peer_key_zero", [&m[..33], &zero[..], &m[66..]].concat()),
    ]
}

#[test]
fn the_vectors_hold() {
    let v = vectors();
    assert!(v.good.len() >= CONTEXTS.len());
    for c in CONTEXTS {
        assert!(
            v.good.iter().any(|g| g.context == c.0),
            "no vector for {}",
            c.0
        );
    }
    for g in &v.good {
        // the text is spelled out in the file: the construction is pinned,
        // not only this code's view of it
        let mut text = PREFIX.to_vec();
        text.push(0);
        text.extend_from_slice(g.context.as_bytes());
        text.push(0);
        text.extend_from_slice(&g.message);
        assert_eq!(g.text, text, "{}", g.name);
        assert_eq!(signed_text(g.context.as_bytes(), &g.message), text);
        assert_eq!(text[0], 0x6b);
        assert!(
            PublicKey::deserialize(&g.key)
                .unwrap()
                .verify_signature(&g.text, &g.sig),
            "{}",
            g.name
        );
        verify_ctx_of(&g.key, g.context.as_bytes(), &g.message, &g.sig)
            .unwrap_or_else(|e| panic!("{}: {e:?}", g.name));
    }
}

#[test]
fn a_signature_holds_under_its_own_context_only() {
    let v = vectors();
    for g in &v.good {
        for (c, _) in CONTEXTS.iter().filter(|c| c.0 != g.context) {
            assert_eq!(
                verify_ctx_of(&g.key, c.as_bytes(), &g.message, &g.sig),
                Err(Error::Signature),
                "{} under {c}",
                g.name
            );
        }
        // the context in the text alone keeps them apart, with no body
        // rule in the way
        let key = PublicKey::deserialize(&g.key).unwrap();
        for (c, _) in CONTEXTS.iter().filter(|c| c.0 != g.context) {
            assert!(!key.verify_signature(&signed_text(c.as_bytes(), &g.message), &g.sig));
        }
        for c in ["face-claim", "link-proof", "", "kryfo"] {
            assert!(!key.verify_signature(&signed_text(c.as_bytes(), &g.message), &g.sig));
        }
        // nor for another key, another message, or the message bare
        for (_, _, other) in v.keys.iter().filter(|k| k.2 != g.key) {
            assert_eq!(
                verify_ctx_of(other, g.context.as_bytes(), &g.message, &g.sig),
                Err(Error::Signature)
            );
        }
        let mut m = g.message.clone();
        *m.last_mut().unwrap() ^= 1;
        assert_eq!(
            verify_ctx_of(&g.key, g.context.as_bytes(), &m, &g.sig),
            Err(Error::Signature)
        );
        assert!(!key.verify_signature(&g.message, &g.sig));
    }
}

#[test]
fn the_refusals_hold() {
    let v = vectors();
    assert!(v.bad.iter().any(|b| b.lax && b.want == Error::Key));
    assert!(
        v.bad
            .iter()
            .filter(|b| b.lax && b.want == Error::Signature)
            .count()
            > 10
    );
    for b in &v.bad {
        assert_eq!(
            verify_ctx_of(&b.key, b.context.as_bytes(), &b.message, &b.sig),
            Err(b.want),
            "{}",
            b.name
        );
        if b.lax {
            // what libsignal alone would take
            let key = PublicKey::deserialize(&b.key).unwrap();
            let text = signed_text(b.context.as_bytes(), &b.message);
            assert!(key.verify_signature(&text, &b.sig), "{} is not lax", b.name);
        }
    }
}

#[test]
fn prekey_and_kryfo_signatures_never_cross() {
    let v = vectors();
    assert!(!v.prekeys.is_empty() && !v.alts.is_empty());
    for (key, public, sig) in &v.prekeys {
        // libsignal's prekey signature, as ks_verify reads it
        run(verify, w().bytes(key).bytes(public).bytes(sig)).unwrap();
        // under any context it holds for nothing
        for (c, _) in CONTEXTS {
            assert_eq!(
                verify_ctx_of(key, c.as_bytes(), public, sig),
                Err(Error::Signature),
                "prekey signature under {c}"
            );
        }
    }
    for g in &v.good {
        // the raw call takes only a prekey's key, never a kryfo text
        assert_eq!(
            run(verify, w().bytes(&g.key).bytes(&g.text).bytes(&g.sig)),
            Err(Error::Args)
        );
    }
    // a kryfo text over a prekey's key or another identity, signed past
    // the shim's checks, is neither libsignal signature
    let (_, k1, k1_public) = v.keys.iter().find(|k| k.0 == "ana0").unwrap();
    let k1 = PrivateKey::deserialize(k1).unwrap();
    for (key, public, _) in &v.prekeys {
        assert_eq!(key, k1_public);
        for (c, _) in CONTEXTS {
            let s = raw_sign_with(&k1, c.as_bytes(), public);
            assert_eq!(
                run(verify, w().bytes(key).bytes(public).bytes(&s)),
                Err(Error::Signature),
                "{c}"
            );
        }
    }
    for (key, other, sig) in &v.alts {
        let id = IdentityKey::decode(key).unwrap();
        let o = IdentityKey::decode(other).unwrap();
        assert!(id.verify_alternate_identity(&o, sig).unwrap());
        for (c, _) in CONTEXTS {
            assert_eq!(
                verify_ctx_of(key, c.as_bytes(), other, sig),
                Err(Error::Signature)
            );
        }
    }
    for (key, other, _) in &v.alts {
        assert_eq!(key, k1_public);
        let id = IdentityKey::decode(key).unwrap();
        let o = IdentityKey::decode(other).unwrap();
        for (c, _) in CONTEXTS {
            let s = raw_sign_with(&k1, c.as_bytes(), other);
            assert!(!id.verify_alternate_identity(&o, &s).unwrap(), "{c}");
        }
    }
}

#[test]
fn a_kryfo_signature_builds_no_bundle() {
    let bob = Party::new(2);
    let fields = run(bundle_parse, w().bytes(&bob.bundle())).unwrap();
    let rebuild = |f: &[Vec<u8>]| {
        let mut x = w();
        for v in f {
            x.bytes(v);
        }
        run(bundle_build, &mut x)
    };
    let pair = IdentityKeyPair::try_from(bob.pair.as_slice()).unwrap();
    for (c, _) in CONTEXTS {
        // the shim signs no bare prekey under any context: it is no body
        for i in [5, 8] {
            assert_eq!(
                sign_of(&bob.pair, c.as_bytes(), &fields[i]),
                Err(Error::Format),
                "{c}"
            );
        }
        // and the same text signed past the shim stands in for no
        // prekey signature
        let mut f = fields.clone();
        f[6] = raw_sign_with(pair.private_key(), c.as_bytes(), &fields[5]);
        assert_eq!(rebuild(&f), Err(Error::Signature), "{c}");
        let mut f = fields.clone();
        f[9] = raw_sign_with(pair.private_key(), c.as_bytes(), &fields[8]);
        assert_eq!(rebuild(&f), Err(Error::Signature), "{c}");
    }
    // the fields as they came build, so the refusals were the signatures'
    rebuild(&fields).unwrap();
}

#[test]
fn sign_then_verify() {
    let (k, g) = fresh();
    for b in bodies(&k, &g) {
        let c = b.context.as_bytes();
        for me in &b.signers {
            let s = sign_of(&me.pair, c, &b.message).unwrap();
            assert_eq!(s.len(), 64);
            verify_ctx_of(&me.public, c, &b.message, &s).unwrap();
            assert!(canonical_s(s.as_slice().try_into().unwrap()));
            assert_eq!(
                verify_ctx_of(&b.not.public, c, &b.message, &s),
                Err(Error::Signature)
            );
            // randomised: two signatures over one text differ, both hold
            let t = sign_of(&me.pair, c, &b.message).unwrap();
            assert_ne!(s, t);
            verify_ctx_of(&me.public, c, &b.message, &t).unwrap();
        }
        // a key the body names in no signing role signs nothing, and its
        // signature made past the shim does not verify either
        assert_eq!(
            sign_of(&b.not.pair, c, &b.message),
            Err(Error::Signer),
            "{}",
            b.context
        );
        let s = b.not.raw_sign(c, &b.message);
        assert_eq!(
            verify_ctx_of(&b.not.public, c, &b.message, &s),
            Err(Error::Signature)
        );
        let kind = crate::sig::kind_of(c).unwrap();
        assert_eq!(
            signers(kind, &b.message).unwrap(),
            b.signers
                .iter()
                .map(|i| i.public.clone())
                .collect::<Vec<_>>()
        );
    }
}

#[test]
fn sign_refuses() {
    let (k, g) = fresh();
    let ana1 = k.id("ana1");
    let invite = g.qr_ci.body();
    // a context off the list in any spelling, one that is gone, one whose
    // format is not here yet, and a format that is never signed
    for c in [
        &b"Invite"[..],
        b"invite\0",
        b"kryfo-sig-v1",
        b"move ",
        b"x",
        b"link-proof",
        b"face-claim",
        b"device-bundle",
    ] {
        assert_eq!(sign_of(&ana1.pair, c, &invite), Err(Error::Args));
        assert_eq!(
            verify_ctx_of(&ana1.public, c, &invite, &[0; 64]),
            Err(Error::Args)
        );
    }
    // nothing to sign, or no context
    assert_eq!(sign_of(&ana1.pair, b"invite", b""), Err(Error::Args));
    assert_eq!(sign_of(&ana1.pair, b"", &invite), Err(Error::Args));
    // a magic and another identity's key is no invite, and neither is an
    // invite naming another identity
    let other = [&b"KIN4"[..], &k.id("ana0").public].concat();
    assert_eq!(sign_of(&ana1.pair, b"invite", &other), Err(Error::Format));
    assert_eq!(
        sign_of(&k.id("ana0").pair, b"invite", &invite),
        Err(Error::Signer)
    );
    // a body of another context's format
    let bs = bodies(&k, &g);
    for b in &bs {
        for (c, _) in CONTEXTS.iter().filter(|c| c.0 != b.context) {
            assert!(
                matches!(
                    sign_of(&b.signers[0].pair, c.as_bytes(), &b.message),
                    Err(Error::Format)
                ),
                "{} as {c}",
                b.context
            );
        }
    }
    // a whole frame, its own signature still on it
    assert_eq!(
        sign_of(&ana1.pair, b"invite", &g.qr_ci.encode()),
        Err(Error::Format)
    );
    assert_eq!(
        sign_of(&k.id("ben0").pair, b"hello", &g.hello.encode()),
        Err(Error::Format)
    );
    // a body whose signatures inside do not hold
    let mut h = g.hello.clone();
    h.invite.sig.as_mut().unwrap()[0] ^= 1;
    assert_eq!(
        sign_of(&k.id("ben0").pair, b"hello", &h.body()),
        Err(Error::Signature)
    );
    let mut x = g.link_ci.clone();
    x.block.as_mut().unwrap().spk_sig[1] ^= 1;
    assert_eq!(
        sign_of(&ana1.pair, b"invite", &x.body()),
        Err(Error::Signature)
    );
    // a move by the peer, or by a key it does not name
    assert_eq!(
        sign_of(&k.id("ben0").pair, b"move", &g.mv.encode()),
        Err(Error::Signer)
    );
    assert_eq!(
        sign_of(&k.id("dev2").pair, b"move", &g.mv.encode()),
        Err(Error::Signer)
    );
    // a move body one step off: refused, and signed past the shim it
    // still does not hold
    for (what, m) in moves_refused(&g.mv.encode()) {
        assert_eq!(
            sign_of(&k.id("ana0").pair, b"move", &m),
            Err(Error::Format),
            "{what}"
        );
        let s = k.id("ana0").raw_sign(b"move", &m);
        assert_eq!(
            verify_ctx_of(&k.id("ana0").public, b"move", &m, &s),
            Err(Error::Signature),
            "{what}"
        );
    }
    // a key pair whose halves do not belong together
    let a = IdentityKeyPair::try_from(ana1.pair.as_slice()).unwrap();
    let b = IdentityKeyPair::try_from(k.id("ana0").pair.as_slice()).unwrap();
    let mixed = IdentityKeyPair::new(*b.identity_key(), *a.private_key()).serialize();
    assert_eq!(sign_of(&mixed, b"invite", &invite), Err(Error::Key));
    // a pair whose public half is its key with the top bit set
    let mut top = ana1.public.clone();
    top[32] |= 0x80;
    let lax = IdentityKeyPair::new(IdentityKey::decode(&top).unwrap(), *a.private_key());
    assert_eq!(
        sign_of(&lax.serialize(), b"invite", &invite),
        Err(Error::Key)
    );
    // a pair that does not read
    assert_eq!(sign_of(&[1, 2, 3], b"invite", &invite), Err(Error::Key));
    // fields left over
    let mut x = w();
    x.bytes(&ana1.pair)
        .bytes(b"invite")
        .bytes(&invite)
        .bytes(b"y");
    assert_eq!(run(sign, &mut x), Err(Error::Args));
}

#[test]
fn verify_ctx_says_false_for_empty_fields() {
    let (k, g) = fresh();
    let ana1 = k.id("ana1");
    let m = g.qr_ci.body();
    let s = ana1.sign(b"invite", &m).unwrap();
    assert_eq!(verify_ctx_of(&[], b"invite", &m, &s), Err(Error::Key));
    assert_eq!(
        verify_ctx_of(&ana1.public, b"invite", &[], &s),
        Err(Error::Signature)
    );
    assert_eq!(
        verify_ctx_of(&ana1.public, b"invite", &m, &[]),
        Err(Error::Signature)
    );
    assert_eq!(verify_ctx_of(&ana1.public, b"", &m, &s), Err(Error::Args));
    verify_ctx_of(&ana1.public, b"invite", &m, &s).unwrap();
}

#[test]
fn verify_takes_only_prekey_keys() {
    let bob = Party::new(2);
    let spk = run(prekey_public, w().u32(1).bytes(&bob.spk)).unwrap();
    let k = run(prekey_public, w().u32(2).bytes(&bob.kyber)).unwrap();
    run(verify, w().bytes(&bob.public).bytes(&spk[1]).bytes(&spk[2])).unwrap();
    run(verify, w().bytes(&bob.public).bytes(&k[1]).bytes(&k[2])).unwrap();
    // the same key one byte longer, or with another type byte
    let mut long = spk[1].clone();
    long.push(0);
    let mut typed = spk[1].clone();
    typed[0] = 0x08;
    let mut short_k = k[1].clone();
    short_k.pop();
    for m in [long, typed, short_k, b"anything".to_vec()] {
        assert_eq!(
            run(verify, w().bytes(&bob.public).bytes(&m).bytes(&spk[2])),
            Err(Error::Args)
        );
    }
    // the identity key in one form only
    let mut long = bob.public.clone();
    long.push(0);
    let mut top = bob.public.clone();
    top[32] |= 0x80;
    for id in [long, top] {
        assert_eq!(
            run(verify, w().bytes(&id).bytes(&spk[1]).bytes(&spk[2])),
            Err(Error::Key)
        );
    }
    // the signature in one form only: s + l holds for libsignal alone
    let mut sl = spk[2].clone();
    add_l(&mut sl[32..]);
    assert!(
        PublicKey::deserialize(&bob.public)
            .unwrap()
            .verify_signature(&spk[1], &sl)
    );
    assert_eq!(
        run(verify, w().bytes(&bob.public).bytes(&spk[1]).bytes(&sl)),
        Err(Error::Signature)
    );
}

#[test]
fn build_info_names_the_lock() {
    let o = run(build_info, &mut w()).unwrap();
    assert_eq!(o.len(), 2);
    let lock = include_str!("../Cargo.lock");
    for s in &o {
        let s = std::str::from_utf8(s).unwrap();
        assert!(lock.contains(&format!("source = \"{s}\"")), "{s}");
    }
    // libsignal by its commit, spqr by the tag libsignal's manifest names
    let rev = "387da3e29ac87c821aedc697aee77646a1c72fff";
    assert_eq!(
        o[0],
        format!("git+https://github.com/signalapp/libsignal?rev={rev}#{rev}").as_bytes()
    );
    assert!(o[1].starts_with(b"git+https://github.com/signalapp/SparsePostQuantumRatchet.git?"));
    assert_eq!(run(build_info, w().bytes(b"x")), Err(Error::Args));
}

#[test]
fn the_header_matches_the_library() {
    let h = include_str!("../include/kryfo_signal.h");
    assert!(h.contains(&format!("#define KS_ABI_VERSION {ABI_VERSION}\n")));
    assert_eq!(ks_abi_version(), ABI_VERSION);
    let calls: Vec<&str> = h
        .lines()
        .filter_map(|l| l.strip_prefix("KS_CALL(")?.strip_suffix(");"))
        .collect();
    for c in [
        "ks_sign",
        "ks_verify_ctx",
        "ks_build_info",
        "ks_verify",
        "ks_parse",
        "ks_session_drop_below",
    ] {
        assert!(calls.contains(&c), "{c}");
    }
    let lib = include_str!("lib.rs");
    for c in &calls {
        assert!(lib.contains(&format!("    {c} => ")), "{c} not exported");
    }
    assert_eq!(
        lib.matches(" => ops::").count()
            + lib.matches(" => sig::").count()
            + lib.matches(" => formats::").count(),
        calls.len()
    );
    // every error code the library has is in the header
    for (name, e) in [
        ("KS_ERR_FORMAT", Error::Format),
        ("KS_ERR_SIGNER", Error::Signer),
        ("KS_ERR_SESSION", Error::Session),
    ] {
        assert!(
            h.contains(&format!("#define {name} {} ", e as i32)),
            "{name}"
        );
    }
    // and each format ks_parse takes, with each context ks_sign takes
    for (n, _) in formats::KINDS {
        assert!(h.contains(n), "{n}");
    }
    assert!(
        CONTEXTS
            .iter()
            .all(|(c, k)| formats::kind_of(c.as_bytes()) == Ok(*k))
    );
    assert!(!CONTEXTS.iter().any(|(_, k)| *k == Kind::DeviceBundle));
}

#[test]
fn signature_calls_take_garbage() {
    let (k, g) = fresh();
    let mut seeds: Vec<(Op, Vec<u8>)> = vec![(build_info, Vec::new())];
    for b in bodies(&k, &g) {
        let me = &b.signers[0];
        let s = me.sign(b.context.as_bytes(), &b.message).unwrap();
        seeds.push((
            sign,
            w().bytes(&me.pair)
                .bytes(b.context.as_bytes())
                .bytes(&b.message)
                .done(),
        ));
        seeds.push((
            verify_ctx,
            w().bytes(&me.public)
                .bytes(b.context.as_bytes())
                .bytes(&b.message)
                .bytes(&s)
                .done(),
        ));
    }
    let mut rng = Rng(0x2545f4914f6cdd1d);
    for (op, seed) in &seeds {
        for _ in 0..80 {
            raw(*op, &mutate(&mut rng, seed));
        }
    }
}

/// testdata/sig_v1.txt, made by write_vectors (tests_formats.rs) with the
/// keys and bodies of formats_v1.txt
pub(crate) fn sig_vectors(k: &Keys, g: &Goods) -> String {
    let mut out = String::new();
    let mut line = |s: String| {
        out.push_str(&s);
        out.push('\n');
    };
    line("# kryfo signatures, version 1: xeddsa by a libsignal identity key over".into());
    line("# \"kryfo-sig-v1\" 00 context 00 message, the message a whole body of the".into());
    line("# context's format without its own signature (formats_v1.txt has the frames).".into());
    line("# xeddsa is randomised, so these are only checked, never made again".into());
    line("# (src/tests_sig.rs). test keys only".into());
    line("# key name private public".into());
    line("# good name key context message text signature".into());
    line("# bad name refused-as lax|strict public context message signature".into());
    line("#   lax: libsignal's own verify takes it, only the shim refuses it".into());
    line("# prekey key public signature: libsignal's own prekey signature".into());
    line("# alt key other signature: libsignal's alternate identity signature".into());
    for (n, id) in &k.ids {
        line(format!(
            "key {n} {} {}",
            to_hex(&id.private),
            to_hex(&id.public)
        ));
    }
    let named: Vec<(&str, Body)> = [
        "invite_1",
        "hello_1",
        "heal_1",
        "heal_2",
        "device_list_1",
        "move",
    ]
    .into_iter()
    .zip(bodies(k, g))
    .collect();
    let mut good = Vec::new();
    for (name, b) in &named {
        for (i, me) in b.signers.iter().enumerate() {
            let name = if b.context == "move" {
                format!("move_{}", i + 1)
            } else {
                name.to_string()
            };
            let s = me.sign(b.context.as_bytes(), &b.message).unwrap();
            let text = signed_text(b.context.as_bytes(), &b.message);
            line(format!(
                "good {name} {} {} {} {} {}",
                k.name_of(&me.public),
                b.context,
                to_hex(&b.message),
                to_hex(&text),
                to_hex(&s)
            ));
            good.push((b.context, b.message.clone(), s, me.clone()));
        }
    }
    let mut bad = |name: &str, want: &str, lax: bool, key: &[u8], c: &str, m: &[u8], s: &[u8]| {
        if lax {
            let k = PublicKey::deserialize(key).unwrap();
            assert!(
                k.verify_signature(&signed_text(c.as_bytes(), m), s),
                "{name}"
            );
        }
        line(format!(
            "bad {name} {want} {} {} {c} {} {}",
            if lax { "lax" } else { "strict" },
            to_hex(key),
            to_hex(m),
            to_hex(s)
        ));
    };
    let (c, m, s, me) = &good[0];
    let key = &me.public;
    // s + l: the same signature in a second encoding
    let mut sl = s.clone();
    let sign_bit = sl[63] & 0x80;
    sl[63] &= 0x7f;
    add_l(&mut sl[32..]);
    sl[63] |= sign_bit;
    bad("s_plus_l", "signature", true, key, c, m, &sl);
    // the key with its top bit set, and with a byte after it
    let bk = bad_keys(key);
    bad("key_top_bit", "key", true, &bk.top_bit, c, m, s);
    bad(
        "key_trailing_byte",
        "key",
        true,
        &[&key[..], &[0]].concat(),
        c,
        m,
        s,
    );
    bad("key_no_type", "key", false, &key[1..], c, m, s);
    let mut typed = key.clone();
    typed[0] = 0x06;
    bad("key_type", "key", false, &typed, c, m, s);
    let p: Vec<u8> = [&[0x05u8][..], &[0xed], &[0xff; 30], &[0x7f]].concat();
    bad("key_p", "key", false, &p, c, m, s);
    bad("key_base_plus_p", "key", false, &bk.base_plus_p, c, m, s);
    bad("key_zero", "key", false, &bk.zero, c, m, s);
    let mut one = bk.zero.clone();
    one[1] = 1;
    bad("key_one", "key", false, &one, c, m, s);
    bad("key_mixed_order", "key", false, &bk.mixed_order, c, m, s);
    bad("key_twist", "key", false, &bk.twist, c, m, s);
    bad("key_empty", "key", false, &[], c, m, s);
    bad(
        "other_key",
        "signature",
        false,
        &k.id("ana0").public,
        c,
        m,
        s,
    );
    bad("sig_short", "signature", false, key, c, m, &s[..63]);
    bad(
        "sig_long",
        "signature",
        false,
        key,
        c,
        m,
        &[&s[..], &[0]].concat(),
    );
    bad("sig_empty", "signature", false, key, c, m, &[]);
    for (name, i, bit) in [
        ("sig_r_flip", 3, 1),
        ("sig_s_flip", 40, 4),
        ("sig_sign_bit", 63, 0x80),
    ] {
        let mut f = s.clone();
        f[i] ^= bit;
        bad(name, "signature", false, key, c, m, &f);
    }
    let mut mm = m.clone();
    mm[20] ^= 1;
    bad("message_changed", "signature", false, key, c, &mm, s);
    bad("message_empty", "signature", false, key, c, &[], s);
    bad(
        "invite_without_magic",
        "signature",
        false,
        key,
        "invite",
        &m[4..],
        s,
    );
    // the whole frame with its signature is not the body
    let whole = [&m[..], s].concat();
    let ws = me.raw_sign(b"invite", &whole);
    bad(
        "invite_with_its_sig",
        "signature",
        true,
        key,
        "invite",
        &whole,
        &ws,
    );
    let (_, mv, ms, mk) = good.iter().find(|g| g.0 == "move").unwrap();
    bad(
        "move_as_heal",
        "signature",
        false,
        &mk.public,
        "heal",
        mv,
        ms,
    );
    bad(
        "move_as_link_proof",
        "args",
        false,
        &mk.public,
        "link-proof",
        mv,
        ms,
    );
    bad(
        "move_as_face_claim",
        "args",
        false,
        &mk.public,
        "face-claim",
        mv,
        ms,
    );
    let (_, hm, hs, hk) = good.iter().find(|g| g.0 == "heal").unwrap();
    bad(
        "heal_as_hello",
        "signature",
        false,
        &hk.public,
        "hello",
        hm,
        hs,
    );
    // bodies only the shim refuses: signed past its checks
    let old = k.id("ana0");
    for (name, m) in moves_refused(mv) {
        let s = old.raw_sign(b"move", &m);
        bad(
            &format!("move_{name}"),
            "signature",
            true,
            &old.public,
            "move",
            &m,
            &s,
        );
    }
    let raw = [3u8; 28];
    let hs = old.raw_sign(b"heal", &raw);
    bad(
        "heal_without_magic",
        "signature",
        true,
        &old.public,
        "heal",
        &raw,
        &hs,
    );
    // a key in no signing role, signing past the shim
    for b in bodies(k, g) {
        let s = b.not.raw_sign(b.context.as_bytes(), &b.message);
        let name = format!(
            "{}_by_{}",
            b.context.replace('-', "_"),
            k.name_of(&b.not.public)
        );
        bad(
            &name,
            "signature",
            true,
            &b.not.public,
            b.context,
            &b.message,
            &s,
        );
    }
    bad("context_case", "args", false, key, "Invite", m, s);
    bad("context_unknown", "args", false, key, "kryfo", m, s);

    let spk = run(signed_prekey_generate, w().bytes(&old.pair).u32(1).u64(1)).unwrap();
    line(format!(
        "prekey ana0 {} {}",
        to_hex(&spk[1]),
        to_hex(&spk[2])
    ));
    let ky = run(kyber_prekey_generate, w().bytes(&old.pair).u32(2).u64(1)).unwrap();
    line(format!("prekey ana0 {} {}", to_hex(&ky[1]), to_hex(&ky[2])));
    let pair = IdentityKeyPair::try_from(old.pair.as_slice()).unwrap();
    let other = IdentityKey::decode(&k.id("ben0").public).unwrap();
    let alt = pair
        .sign_alternate_identity(&other, &mut crate::ops::rng())
        .unwrap();
    line(format!(
        "alt ana0 {} {}",
        to_hex(&k.id("ben0").public),
        to_hex(&alt)
    ));
    out
}

#[test]
fn every_good_body_is_a_frame_of_its_context() {
    let v = vectors();
    for g in &v.good {
        let kind = crate::sig::kind_of(g.context.as_bytes()).unwrap();
        assert!(
            signers(kind, &g.message).unwrap().contains(&g.key),
            "{}",
            g.name
        );
    }
    // the file's bodies are the frames' bodies in formats_v1.txt
    let f = crate::tests_formats::file();
    for g in v.good.iter().filter(|g| g.context != "move") {
        assert!(
            f.vectors.iter().any(|x| x.want.is_none()
                && x.kind == g.context
                && x.bytes.len() == g.message.len() + 64
                && x.bytes[..g.message.len()] == g.message[..]),
            "{}",
            g.name
        );
    }
}

#[test]
fn bodies_name_their_signers() {
    let (k, g) = fresh();
    let i = formats::invite(&g.qr_ci.body(), false).unwrap();
    assert_eq!(i.identity, k.id("ana1").public);
    // the pool invite answers on the desktop, its list signed by the phone
    let p = formats::invite(&g.pool_link.encode(), true).unwrap();
    assert_eq!(p.answering(), k.id("desk").public);
    assert_eq!(p.list.unwrap().identity, k.id("ana1").public);
}
