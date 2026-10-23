// SPDX-License-Identifier: GPL-3.0-or-later
// ks_sign and ks_verify_ctx against testdata/sig_v1.txt, and the line
// between kryfo's signatures and libsignal's own
use libsignal_protocol::{IdentityKey, IdentityKeyPair, PublicKey};

use crate::sig::{CONTEXTS, PREFIX, canonical_s, signed_text};
use crate::tests::{Party, Rng, mutate, raw, run, w};
use crate::*;

fn hex(s: &str) -> Vec<u8> {
    assert!(s.len() % 2 == 0, "odd hex {s}");
    (0..s.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&s[i..i + 2], 16).unwrap())
        .collect()
}

fn to_hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

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
        let key = PublicKey::deserialize(&g.key).unwrap();
        assert!(!key.verify_signature(&g.message, &g.sig));
    }
}

#[test]
fn the_refusals_hold() {
    let v = vectors();
    assert!(v.bad.iter().any(|b| b.lax && b.want == Error::Key));
    assert!(v.bad.iter().any(|b| b.lax && b.want == Error::Signature));
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
        // and a kryfo signature over a prekey's key is no prekey signature
        if g.message.len() == 33 && g.message[0] == 0x05 {
            assert_eq!(
                run(verify, w().bytes(&g.key).bytes(&g.message).bytes(&g.sig)),
                Err(Error::Signature),
                "{}",
                g.name
            );
        }
    }
    assert!(
        v.good
            .iter()
            .any(|g| g.message.len() == 33 && g.message[0] == 0x05)
    );
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
    for g in v.good.iter().filter(|g| g.message.len() == 33) {
        let id = IdentityKey::decode(&g.key).unwrap();
        let o = IdentityKey::decode(&g.message).unwrap();
        assert!(!id.verify_alternate_identity(&o, &g.sig).unwrap());
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
    // bob's own key signs his signed prekey and kyber key under every
    // context that takes a bare key: none stands in for libsignal's
    for (c, magic) in CONTEXTS {
        if magic.is_some() {
            continue;
        }
        let mut f = fields.clone();
        f[6] = sign_of(&bob.pair, c.as_bytes(), &fields[5]).unwrap();
        assert_eq!(rebuild(&f), Err(Error::Signature), "{c}");
        let mut f = fields.clone();
        f[9] = sign_of(&bob.pair, c.as_bytes(), &fields[8]).unwrap();
        assert_eq!(rebuild(&f), Err(Error::Signature), "{c}");
    }
}

#[test]
fn sign_then_verify() {
    let alice = Party::new(1);
    let bob = Party::new(2);
    for (c, magic) in CONTEXTS {
        let mut m = magic.map(|m| m.to_vec()).unwrap_or_default();
        m.extend_from_slice(b" some body");
        let s = sign_of(&alice.pair, c.as_bytes(), &m).unwrap();
        assert_eq!(s.len(), 64);
        verify_ctx_of(&alice.public, c.as_bytes(), &m, &s).unwrap();
        assert!(canonical_s(s.as_slice().try_into().unwrap()));
        assert_eq!(
            verify_ctx_of(&bob.public, c.as_bytes(), &m, &s),
            Err(Error::Signature)
        );
        // randomised: two signatures over one text differ, both hold
        let t = sign_of(&alice.pair, c.as_bytes(), &m).unwrap();
        assert_ne!(s, t);
        verify_ctx_of(&alice.public, c.as_bytes(), &m, &t).unwrap();
    }
}

#[test]
fn sign_refuses() {
    let alice = Party::new(1);
    // a context off the list, in any spelling
    for c in [&b"Invite"[..], b"invite\0", b"kryfo-sig-v1", b"move ", b"x"] {
        assert_eq!(sign_of(&alice.pair, c, b"KIN4 x"), Err(Error::Args));
        assert_eq!(
            verify_ctx_of(&alice.public, c, b"KIN4 x", &[0; 64]),
            Err(Error::Args)
        );
    }
    // nothing to sign, or no context
    assert_eq!(sign_of(&alice.pair, b"move", b""), Err(Error::Args));
    assert_eq!(sign_of(&alice.pair, b"", b"x"), Err(Error::Args));
    // a body that is not the context's format
    for (c, magic) in CONTEXTS {
        if magic.is_some() {
            assert_eq!(
                sign_of(&alice.pair, c.as_bytes(), b"KXX1 x"),
                Err(Error::Args)
            );
        }
    }
    // a key pair whose halves do not belong together
    let a = IdentityKeyPair::try_from(alice.pair.as_slice()).unwrap();
    let b = IdentityKeyPair::try_from(Party::new(2).pair.as_slice()).unwrap();
    let mixed = IdentityKeyPair::new(*b.identity_key(), *a.private_key()).serialize();
    assert_eq!(sign_of(&mixed, b"move", b"x"), Err(Error::Key));
    // a pair that does not read
    assert_eq!(sign_of(&[1, 2, 3], b"move", b"x"), Err(Error::Key));
    // fields left over
    let mut x = w();
    x.bytes(&alice.pair).bytes(b"move").bytes(b"x").bytes(b"y");
    assert_eq!(run(sign, &mut x), Err(Error::Args));
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
    let mut id = bob.public.clone();
    id.push(0);
    assert_eq!(
        run(verify, w().bytes(&id).bytes(&spk[1]).bytes(&spk[2])),
        Err(Error::Key)
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
    assert!(o[0].starts_with(b"git+https://github.com/signalapp/libsignal?"));
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
    for c in ["ks_sign", "ks_verify_ctx", "ks_build_info", "ks_verify"] {
        assert!(calls.contains(&c), "{c}");
    }
    let lib = include_str!("lib.rs");
    for c in &calls {
        assert!(lib.contains(&format!("    {c} => ")), "{c} not exported");
    }
    assert_eq!(
        lib.matches(" => ops::").count() + lib.matches(" => sig::").count(),
        calls.len()
    );
}

#[test]
fn signature_calls_take_garbage() {
    let alice = Party::new(1);
    let s = sign_of(&alice.pair, b"invite", b"KIN4 garbage").unwrap();
    let seeds: Vec<(Op, Vec<u8>)> = vec![
        (
            sign,
            w().bytes(&alice.pair)
                .bytes(b"invite")
                .bytes(b"KIN4 x")
                .done(),
        ),
        (
            verify_ctx,
            w().bytes(&alice.public)
                .bytes(b"invite")
                .bytes(b"KIN4 garbage")
                .bytes(&s)
                .done(),
        ),
        (build_info, Vec::new()),
    ];
    let mut rng = Rng(0x2545f4914f6cdd1d);
    for (op, seed) in &seeds {
        for _ in 0..300 {
            raw(*op, &mutate(&mut rng, seed));
        }
    }
}

// makes testdata/sig_v1.txt: cargo test write_sig_vectors -- --ignored
// --nocapture. xeddsa is randomised, so a new run gives new signatures; the
// file is what the tests hold to
#[test]
#[ignore]
fn write_sig_vectors() {
    let k1 = run(identity_generate, &mut w()).unwrap();
    let k2 = run(identity_generate, &mut w()).unwrap();
    let private = |pair: &[u8]| {
        IdentityKeyPair::try_from(pair)
            .unwrap()
            .private_key()
            .serialize()
    };
    println!("# kryfo signatures, version 1: xeddsa by a libsignal identity key over");
    println!("# \"kryfo-sig-v1\" 00 context 00 message. xeddsa is randomised, so these are");
    println!("# only checked, never made again (src/tests_sig.rs). test keys only");
    println!("# key name private public");
    println!("# good name key context message text signature");
    println!("# bad name refused-as lax|strict public context message signature");
    println!("#   lax: libsignal's own verify takes it, only the shim refuses it");
    println!("# prekey key public signature: libsignal's own prekey signature");
    println!("# alt key other signature: libsignal's alternate identity signature");
    println!("key k1 {} {}", to_hex(&private(&k1[0])), to_hex(&k1[1]));
    println!("key k2 {} {}", to_hex(&private(&k2[0])), to_hex(&k2[1]));
    let mut good = Vec::new();
    let bodies: Vec<(&str, &str, Vec<u8>)> = vec![
        ("invite_1", "invite", [&b"KIN4"[..], &[1; 28]].concat()),
        ("hello_1", "hello", [&b"KHL1"[..], &[2; 20]].concat()),
        (
            "device_list_1",
            "device-list",
            [&b"KDL2"[..], &k1[1]].concat(),
        ),
        ("link_proof_1", "link-proof", k2[1].clone()),
        ("move_1", "move", vec![0x33; 32]),
        ("face_claim_1", "face-claim", b"amber-otter-lake".to_vec()),
        ("move_short", "move", vec![0]),
    ];
    for (name, context, message) in bodies {
        let s = sign_of(&k1[0], context.as_bytes(), &message).unwrap();
        let text = signed_text(context.as_bytes(), &message);
        println!(
            "good {name} k1 {context} {} {} {}",
            to_hex(&message),
            to_hex(&text),
            to_hex(&s)
        );
        good.push((context, message, s));
    }
    let s2 = sign_of(&k2[0], b"move", &[0x44; 32]).unwrap();
    println!(
        "good move_2 k2 move {} {} {}",
        to_hex(&[0x44; 32]),
        to_hex(&signed_text(b"move", &[0x44; 32])),
        to_hex(&s2)
    );

    let bad = |name: &str, want: &str, lax: bool, key: &[u8], c: &str, m: &[u8], s: &[u8]| {
        if lax {
            let k = PublicKey::deserialize(key).unwrap();
            assert!(
                k.verify_signature(&signed_text(c.as_bytes(), m), s),
                "{name}"
            );
        }
        println!(
            "bad {name} {want} {} {} {c} {} {}",
            if lax { "lax" } else { "strict" },
            to_hex(key),
            to_hex(m),
            to_hex(s)
        );
    };
    let (c, m, s) = &good[0];
    // s + l: the same signature in a second encoding
    let mut sl = s.clone();
    let sign_bit = sl[63] & 0x80;
    sl[63] &= 0x7f;
    let mut carry = 0u16;
    for i in 0..32 {
        let l = [
            0xedu8, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58, 0xd6, 0x9c, 0xf7, 0xa2, 0xde, 0xf9,
            0xde, 0x14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x10,
        ][i];
        let t = sl[32 + i] as u16 + l as u16 + carry;
        sl[32 + i] = t as u8;
        carry = t >> 8;
    }
    assert_eq!(carry, 0);
    sl[63] |= sign_bit;
    bad("s_plus_l", "signature", true, &k1[1], c, m, &sl);
    // the key with its top bit set, and with a byte after it
    let mut top = k1[1].clone();
    top[32] |= 0x80;
    bad("key_top_bit", "key", true, &top, c, m, s);
    let mut trail = k1[1].clone();
    trail.push(0);
    bad("key_trailing_byte", "key", true, &trail, c, m, s);
    bad("key_no_type", "key", false, &k1[1][1..], c, m, s);
    let mut typed = k1[1].clone();
    typed[0] = 0x06;
    bad("key_type", "key", false, &typed, c, m, s);
    let p: Vec<u8> = [&[0x05u8][..], &[0xed], &[0xff; 30], &[0x7f]].concat();
    bad("key_p", "key", false, &p, c, m, s);
    let zero: Vec<u8> = [&[0x05u8][..], &[0; 32]].concat();
    bad("key_zero", "key", false, &zero, c, m, s);
    let mut one = zero.clone();
    one[1] = 1;
    bad("key_one", "key", false, &one, c, m, s);
    bad("other_key", "signature", false, &k2[1], c, m, s);
    bad("sig_short", "signature", false, &k1[1], c, m, &s[..63]);
    bad(
        "sig_long",
        "signature",
        false,
        &k1[1],
        c,
        m,
        &[&s[..], &[0]].concat(),
    );
    for (name, i, bit) in [
        ("sig_r_flip", 3, 1),
        ("sig_s_flip", 40, 4),
        ("sig_sign_bit", 63, 0x80),
    ] {
        let mut f = s.clone();
        f[i] ^= bit;
        bad(name, "signature", false, &k1[1], c, m, &f);
    }
    let mut mm = m.clone();
    mm[10] ^= 1;
    bad("message_changed", "signature", false, &k1[1], c, &mm, s);
    bad(
        "invite_without_magic",
        "signature",
        false,
        &k1[1],
        "invite",
        &m[4..],
        s,
    );
    let (_, m5, s5) = &good[4];
    bad(
        "move_as_link_proof",
        "signature",
        false,
        &k1[1],
        "link-proof",
        m5,
        s5,
    );
    bad(
        "move_as_face_claim",
        "signature",
        false,
        &k1[1],
        "face-claim",
        m5,
        s5,
    );
    bad("context_case", "args", false, &k1[1], "Invite", m, s);
    bad("context_unknown", "args", false, &k1[1], "kryfo", m, s);

    let spk = run(signed_prekey_generate, w().bytes(&k1[0]).u32(1).u64(1)).unwrap();
    println!("prekey k1 {} {}", to_hex(&spk[1]), to_hex(&spk[2]));
    let ky = run(kyber_prekey_generate, w().bytes(&k1[0]).u32(2).u64(1)).unwrap();
    println!("prekey k1 {} {}", to_hex(&ky[1]), to_hex(&ky[2]));
    let pair = IdentityKeyPair::try_from(k1[0].as_slice()).unwrap();
    let other = IdentityKey::decode(&k2[1]).unwrap();
    let alt = pair
        .sign_alternate_identity(&other, &mut crate::ops::rng())
        .unwrap();
    println!("alt k1 {} {}", to_hex(&k2[1]), to_hex(&alt));
}
