// SPDX-License-Identifier: GPL-3.0-or-later
// the one byte form of each key kind the formats carry. everything here
// runs on public data, so nothing needs to be constant time

use curve25519_dalek::edwards::{CompressedEdwardsY, EdwardsPoint};
use curve25519_dalek::scalar::Scalar;
use libsignal_protocol::{PublicKey, kem};
use sha2::{Digest, Sha512};

use crate::Error;

type R<T> = Result<T, Error>;

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

pub const KYBER_LEN: usize = 1569;

/// a kyber1024 key: exactly 1569 bytes, 0x08 first, and one libsignal reads
pub fn strict_kyber(b: &[u8]) -> R<kem::PublicKey> {
    if b.len() != KYBER_LEN || b[0] != 0x08 {
        return Err(Error::Key);
    }
    kem::PublicKey::deserialize(b).map_err(|_| Error::Key)
}

// the group order l, little endian
const L: [u8; 32] = [
    0xed, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58, 0xd6, 0x9c, 0xf7, 0xa2, 0xde, 0xf9, 0xde, 0x14,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x10,
];

/// whether s, an xeddsa signature's second half without its sign bit, is
/// below l. xeddsa verify reduces s, so s + l would pass as a second
/// encoding
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

/// an xeddsa signature in its one encoding
pub fn strict_sig(b: &[u8]) -> R<&[u8; 64]> {
    let s: &[u8; 64] = b.try_into().map_err(|_| Error::Signature)?;
    if !canonical_s(s) {
        return Err(Error::Signature);
    }
    Ok(s)
}

// ed25519, for the legacy face and the onion key

/// a canonical ed25519 point encoding in the prime order group. a torsion
/// part would let a cofactored and a cofactorless verifier disagree
pub fn strict_ed(b: &[u8]) -> R<EdwardsPoint> {
    let a: [u8; 32] = b.try_into().map_err(|_| Error::Key)?;
    let p = CompressedEdwardsY(a).decompress().ok_or(Error::Key)?;
    // decompress reduces y and takes x = 0 with either sign
    if p.compress().to_bytes() != a || p.is_small_order() || !p.is_torsion_free() {
        return Err(Error::Key);
    }
    Ok(p)
}

/// an ed25519 signature's s below l: one encoding per signature
pub fn ed_sig_canonical(sig: &[u8]) -> bool {
    sig.len() == 64
        && bool::from(Scalar::from_canonical_bytes(sig[32..].try_into().expect("32")).is_some())
}

/// the ed25519 check of rfc 8032 without the cofactor: [s]B = R + [k]A,
/// with R compared as bytes
pub fn ed_verify(key: &EdwardsPoint, message: &[u8], sig: &[u8]) -> bool {
    if !ed_sig_canonical(sig) {
        return false;
    }
    let s: [u8; 32] = sig[32..].try_into().expect("32");
    let s = Scalar::from_canonical_bytes(s).expect("checked");
    let k = Sha512::new()
        .chain_update(&sig[..32])
        .chain_update(key.compress().as_bytes())
        .chain_update(message)
        .finalize();
    let k = Scalar::from_bytes_mod_order_wide(k.as_slice().try_into().expect("64"));
    let r = EdwardsPoint::vartime_double_scalar_mul_basepoint(&k, &-key, &s);
    r.compress().as_bytes()[..] == sig[..32]
}

// secp256k1, for first-contact keys: x-only, the even y point is the key

type U256 = [u64; 4];

// p = 2^256 - 2^32 - 977, limbs little endian
const P: U256 = [
    0xffff_fffe_ffff_fc2f,
    0xffff_ffff_ffff_ffff,
    0xffff_ffff_ffff_ffff,
    0xffff_ffff_ffff_ffff,
];
// 2^256 mod p
const FOLD: u128 = 0x1_0000_03d1;

fn from_be(b: &[u8; 32]) -> U256 {
    let mut x = [0u64; 4];
    for (i, limb) in x.iter_mut().enumerate() {
        let at = 32 - 8 * (i + 1);
        *limb = u64::from_be_bytes(b[at..at + 8].try_into().expect("8"));
    }
    x
}

fn below(a: &U256, b: &U256) -> bool {
    for i in (0..4).rev() {
        if a[i] != b[i] {
            return a[i] < b[i];
        }
    }
    false
}

fn sub(a: &U256, b: &U256) -> U256 {
    let mut out = [0u64; 4];
    let mut borrow = false;
    for i in 0..4 {
        let (d, b1) = a[i].overflowing_sub(b[i]);
        let (d, b2) = d.overflowing_sub(borrow as u64);
        out[i] = d;
        borrow = b1 || b2;
    }
    out
}

fn reduce(mut x: U256) -> U256 {
    while !below(&x, &P) {
        x = sub(&x, &P);
    }
    x
}

// x + carry * 2^256 with carry folded back in
fn fold(lo: [u64; 4], carry: u128) -> U256 {
    let mut out = lo;
    let mut c = carry * FOLD;
    for limb in out.iter_mut() {
        let t = *limb as u128 + c;
        *limb = t as u64;
        c = t >> 64;
    }
    if c != 0 {
        // out is tiny after a wrap, so this cannot wrap again
        let mut c = c * FOLD;
        for limb in out.iter_mut() {
            let t = *limb as u128 + c;
            *limb = t as u64;
            c = t >> 64;
        }
    }
    reduce(out)
}

fn mul(a: &U256, b: &U256) -> U256 {
    let mut w = [0u64; 8];
    for i in 0..4 {
        let mut carry = 0u128;
        for j in 0..4 {
            let t = w[i + j] as u128 + a[i] as u128 * b[j] as u128 + carry;
            w[i + j] = t as u64;
            carry = t >> 64;
        }
        w[i + 4] = carry as u64;
    }
    // w = lo + hi * 2^256 = lo + hi * FOLD (mod p)
    let mut lo = [0u64; 4];
    let mut carry = 0u128;
    for i in 0..4 {
        let t = w[i] as u128 + w[i + 4] as u128 * FOLD + carry;
        lo[i] = t as u64;
        carry = t >> 64;
    }
    fold(lo, carry)
}

fn add_small(a: &U256, v: u64) -> U256 {
    let mut out = *a;
    let mut c = v as u128;
    for limb in out.iter_mut() {
        let t = *limb as u128 + c;
        *limb = t as u64;
        c = t >> 64;
    }
    fold(out, c)
}

fn pow(base: &U256, e: &U256) -> U256 {
    let mut acc: U256 = [1, 0, 0, 0];
    for i in (0..256).rev() {
        acc = mul(&acc, &acc);
        if (e[i / 64] >> (i % 64)) & 1 == 1 {
            acc = mul(&acc, base);
        }
    }
    acc
}

/// whether 32 bytes are the x of a secp256k1 point: x below p and x^3 + 7
/// a square (euler's criterion). the curve has no point with y = 0, so a
/// square here is never zero
pub fn secp_lifts(b: &[u8]) -> bool {
    let Ok(b) = <&[u8; 32]>::try_from(b) else {
        return false;
    };
    let x = from_be(b);
    if !below(&x, &P) {
        return false;
    }
    let rhs = add_small(&mul(&mul(&x, &x), &x), 7);
    // (p - 1) / 2
    let mut e = sub(&P, &[1, 0, 0, 0]);
    for i in 0..4 {
        e[i] = (e[i] >> 1) | if i < 3 { e[i + 1] << 63 } else { 0 };
    }
    pow(&rhs, &e) == [1, 0, 0, 0]
}

#[cfg(test)]
mod tests {
    use super::*;
    use num_bigint::BigUint;

    fn hex32(s: &str) -> [u8; 32] {
        let v: Vec<u8> = (0..64)
            .step_by(2)
            .map(|i| u8::from_str_radix(&s[i..i + 2], 16).unwrap())
            .collect();
        v.try_into().unwrap()
    }

    #[test]
    fn the_generator_and_its_multiples_lift() {
        for x in [
            "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
            "c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5",
            "f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9",
        ] {
            assert!(secp_lifts(&hex32(x)), "{x}");
        }
        // p itself and everything above it
        let p = hex32("fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f");
        assert!(!secp_lifts(&p));
        assert!(!secp_lifts(&[0xff; 32]));
        assert!(!secp_lifts(&[1; 31]));
        assert!(!secp_lifts(&[1; 33]));
    }

    #[test]
    fn the_lift_agrees_with_big_integers() {
        let p = BigUint::parse_bytes(
            b"fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f",
            16,
        )
        .unwrap();
        let e = (&p - 1u32) >> 1;
        let mut rng = crate::tests::Rng(0x5eed_1234_9876_abcd);
        let mut yes = 0;
        for n in 0..400 {
            let mut b = [0u8; 32];
            for c in b.chunks_mut(8) {
                c.copy_from_slice(&rng.next().to_be_bytes());
            }
            // values near p and near zero as well
            if n % 7 == 0 {
                b[..28].fill(0xff);
            }
            if n % 11 == 0 {
                b[..31].fill(0);
            }
            let x = BigUint::from_bytes_be(&b);
            let want = x < p && {
                let rhs = (&x * &x * &x + 7u32) % &p;
                rhs.modpow(&e, &p) == BigUint::from(1u32)
            };
            assert_eq!(secp_lifts(&b), want, "{x:x}");
            yes += want as u32;
        }
        assert!(yes > 100 && yes < 300, "{yes}");
    }

    #[test]
    fn the_field_maths_reduces() {
        let pm1 = sub(&P, &[1, 0, 0, 0]);
        // (p - 1)^2 = 1
        assert_eq!(mul(&pm1, &pm1), [1, 0, 0, 0]);
        assert_eq!(add_small(&pm1, 1), [0, 0, 0, 0]);
        assert_eq!(add_small(&pm1, 8), [7, 0, 0, 0]);
    }

    // rfc 8032 section 7.1, tests 1 and 2
    #[test]
    fn ed25519_against_the_rfc() {
        let cases = [
            (
                "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a",
                "",
                "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b",
            ),
            (
                "3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c",
                "72",
                "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00",
            ),
        ];
        let hex = |s: &str| -> Vec<u8> {
            (0..s.len())
                .step_by(2)
                .map(|i| u8::from_str_radix(&s[i..i + 2], 16).unwrap())
                .collect()
        };
        for (key, msg, sig) in cases {
            let k = strict_ed(&hex(key)).unwrap();
            let (m, s) = (hex(msg), hex(sig));
            assert!(ed_verify(&k, &m, &s));
            let mut bad = s.clone();
            bad[5] ^= 1;
            assert!(!ed_verify(&k, &m, &bad));
            assert!(!ed_verify(&k, b"other", &s));
            // s + l, the second encoding
            let mut sl = s.clone();
            let mut carry = 0u16;
            for i in 0..32 {
                let t = sl[32 + i] as u16 + L[i] as u16 + carry;
                sl[32 + i] = t as u8;
                carry = t >> 8;
            }
            assert!(!ed_sig_canonical(&sl));
            assert!(!ed_verify(&k, &m, &sl));
        }
    }

    #[test]
    fn ed25519_keys_in_one_form() {
        let good = strict_ed(&hex32(
            "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a",
        ))
        .unwrap()
        .compress()
        .to_bytes();
        // the top bit picks x's sign: the other point, still fine
        let mut neg = good;
        neg[31] ^= 0x80;
        assert!(strict_ed(&neg).is_ok());
        // the identity, the order 2 and order 4 points: small order
        let mut id = [0u8; 32];
        id[0] = 1;
        let mut minus_one = [0xffu8; 32];
        minus_one[0] = 0xec;
        minus_one[31] = 0x7f;
        for b in [id, minus_one, [0; 32]] {
            assert_eq!(strict_ed(&b), Err(Error::Key));
        }
        // y = 1 + p: the identity in a second form
        let mut y = [0xffu8; 32];
        y[0] = 0xee;
        y[31] = 0x7f;
        assert_eq!(strict_ed(&y), Err(Error::Key));
        // x = 0 with the sign bit set
        let mut negzero = id;
        negzero[31] |= 0x80;
        assert_eq!(strict_ed(&negzero), Err(Error::Key));
        assert_eq!(strict_ed(&good[..31]), Err(Error::Key));
    }
}
