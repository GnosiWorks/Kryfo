// SPDX-License-Identifier: GPL-3.0-or-later
// the pinned libsignal on its own, with its reference stores and no shim
// code on the path. the shim refuses the same inputs before libsignal sees
// them (src/tests.rs), so those tests would pass on a libsignal that took
// classic sessions again; these fail when an update makes it do that
use std::collections::HashMap;
use std::future::Future;
use std::path::Path;
use std::pin::pin;
use std::task::{Context, Poll, Waker};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use libsignal_protocol::*;
use rand::TryRngCore as _;
use rand::rngs::OsRng;

const LIBSIGNAL: &str = "git+https://github.com/signalapp/libsignal?rev=387da3e29ac87c821aedc697aee77646a1c72fff#387da3e29ac87c821aedc697aee77646a1c72fff";
const SPQR: &str = "git+https://github.com/signalapp/SparsePostQuantumRatchet.git?tag=v1.5.3#fd320484dcec89004021e6fdc7481825f5f261fa";

// the reference stores never wait
fn block_on<F: Future>(f: F) -> F::Output {
    let mut f = pin!(f);
    let mut cx = Context::from_waker(Waker::noop());
    loop {
        if let Poll::Ready(v) = f.as_mut().poll(&mut cx) {
            return v;
        }
    }
}

fn rng() -> rand::rand_core::UnwrapErr<OsRng> {
    OsRng.unwrap_err()
}

fn now() -> SystemTime {
    UNIX_EPOCH + Duration::from_secs(1_760_000_000)
}

fn addr(name: &str) -> ProtocolAddress {
    ProtocolAddress::new(name.into(), DeviceId::new(1).unwrap())
}

fn manifest(file: &str) -> String {
    std::fs::read_to_string(Path::new(env!("CARGO_MANIFEST_DIR")).join(file)).unwrap()
}

// each [[package]] of Cargo.lock as (name, version, source)
fn lock_packages() -> Vec<(String, String, Option<String>)> {
    let lock = manifest("Cargo.lock");
    let field = |pkg: &str, key: &str| {
        pkg.lines()
            .find_map(|l| l.strip_prefix(&format!("{key} = \"")))
            .map(|v| v.trim_end_matches('"').to_string())
    };
    lock.split("[[package]]")
        .skip(1)
        .map(|p| {
            (
                field(p, "name").unwrap(),
                field(p, "version").unwrap(),
                field(p, "source"),
            )
        })
        .collect()
}

#[test]
fn the_lock_names_the_reviewed_commits() {
    let pkgs = lock_packages();
    let source_of = |name: &str| {
        let s: Vec<_> = pkgs.iter().filter(|p| p.0 == name).collect();
        assert_eq!(s.len(), 1, "{name} once in Cargo.lock");
        s[0].2.clone().unwrap()
    };
    assert_eq!(source_of("libsignal-protocol"), LIBSIGNAL);
    assert_eq!(source_of("spqr"), SPQR);
    // every crate from either repository at that one commit, and no other
    // git source at all
    let mut git = HashMap::new();
    for (name, _, src) in &pkgs {
        if let Some(s) = src.as_deref().filter(|s| s.starts_with("git+")) {
            git.insert(name.clone(), s.to_string());
        }
    }
    for (name, s) in &git {
        assert!(s == LIBSIGNAL || s == SPQR, "{name} from {s}");
    }
    assert!(
        git.len() > 2,
        "libsignal's own crates come from the same commit"
    );
    // the manifest names the same commit, so the lock is not stale, and
    // says which tag it is; spqr stays on the tag libsignal's own manifest
    // names, or the lock would hold it twice
    let toml = manifest("Cargo.toml");
    assert!(
        toml.contains(
            "# libsignal v0.99.4, named by its commit: a tag can move, a commit cannot.\n"
        )
    );
    assert!(toml.contains(
        "libsignal-protocol = { git = \"https://github.com/signalapp/libsignal\", rev = \"387da3e29ac87c821aedc697aee77646a1c72fff\" }\n"
    ));
    assert!(toml.contains(
        "spqr = { git = \"https://github.com/signalapp/SparsePostQuantumRatchet.git\", tag = \"v1.5.3\" }\n"
    ));
    assert_eq!(toml.matches("signalapp/").count(), 2);
    // and the builds take the lock as it is
    let host = manifest("build-host.sh");
    assert!(host.contains("cargo build --locked --release"));
    assert!(host.contains("cargo test --locked"));
    assert!(!host.contains("cargo update"));
}

#[test]
fn the_library_says_what_it_was_built_from() {
    // the call itself, not ks_build_info: the c boundary would set a quiet
    // panic hook and take the reasons out of every failure below
    let b = kryfo_signal::build_info(&[]).unwrap();
    let mut fields = Vec::new();
    let mut rest = &b[..];
    while !rest.is_empty() {
        let len = u32::from_le_bytes(rest[..4].try_into().unwrap()) as usize;
        fields.push(String::from_utf8(rest[4..4 + len].to_vec()).unwrap());
        rest = &rest[4 + len..];
    }
    assert_eq!(fields, [LIBSIGNAL, SPQR]);
}

// the shim built for android, wherever a build left it: its exports and the
// sources it names. with none built here there is nothing to check
#[test]
fn android_builds_name_the_reviewed_commits() {
    let mut found = Vec::new();
    let jni = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../android/app/src/main/jniLibs");
    if let Ok(dirs) = std::fs::read_dir(&jni) {
        for d in dirs.flatten() {
            let so = d.path().join("libkryfo_signal.so");
            if so.exists() {
                found.push(so);
            }
        }
    }
    if let Ok(extra) = std::env::var("KS_ANDROID_SO") {
        found.extend(extra.split(':').filter(|s| !s.is_empty()).map(Into::into));
    }
    if found.is_empty() {
        eprintln!("no android build of the shim here; KS_ANDROID_SO=<path>:... names one");
        return;
    }
    let header = manifest("include/kryfo_signal.h");
    let mut calls: Vec<&str> = header
        .lines()
        .filter_map(|l| l.strip_prefix("KS_CALL(")?.strip_suffix(");"))
        .collect();
    calls.extend(["ks_abi_version", "ks_free"]);
    let contains = |hay: &[u8], needle: &[u8]| hay.windows(needle.len()).any(|w| w == needle);
    let mut problems = Vec::new();
    for so in &found {
        let b = std::fs::read(so).unwrap();
        assert_eq!(&b[..4], b"\x7fELF", "{}", so.display());
        for c in &calls {
            let mut name = c.as_bytes().to_vec();
            name.push(0);
            if !contains(&b, &name) {
                problems.push(format!("{}: no {c}", so.display()));
            }
        }
        for s in [LIBSIGNAL, SPQR] {
            if !contains(&b, s.as_bytes()) {
                problems.push(format!("{}: does not name {s}", so.display()));
            }
        }
        // libsignal's own refusals are in it
        for s in [
            &b"X3DH no longer supported"[..],
            b"Kyber pre key must be present",
        ] {
            if !contains(&b, s) {
                problems.push(format!(
                    "{}: no {:?}",
                    so.display(),
                    String::from_utf8_lossy(s)
                ));
            }
        }
    }
    assert!(problems.is_empty(), "{}", problems.join("\n"));
}

// one side: its store and what its bundle is made of
struct Side {
    store: InMemSignalProtocolStore,
    reg: u32,
    pk: (PreKeyId, PublicKey),
    spk: (SignedPreKeyId, PublicKey, Vec<u8>),
    kyber: (KyberPreKeyId, kem::PublicKey, Vec<u8>),
}

impl Side {
    fn new(reg: u32) -> Self {
        let mut r = rng();
        let pair = IdentityKeyPair::generate(&mut r);
        let mut store = InMemSignalProtocolStore::new(pair, reg).unwrap();
        let pk = KeyPair::generate(&mut r);
        let spk = KeyPair::generate(&mut r);
        let spk_sig = pair
            .private_key()
            .calculate_signature(&spk.public_key.serialize(), &mut r)
            .unwrap()
            .to_vec();
        let k = kem::KeyPair::generate(kem::KeyType::Kyber1024, &mut r);
        let k_sig = pair
            .private_key()
            .calculate_signature(&k.public_key.serialize(), &mut r)
            .unwrap()
            .to_vec();
        let ts = Timestamp::from_epoch_millis(1_760_000_000_000);
        block_on(async {
            store
                .save_pre_key(7.into(), &PreKeyRecord::new(7.into(), &pk))
                .await
                .unwrap();
            store
                .save_signed_pre_key(
                    1.into(),
                    &SignedPreKeyRecord::new(1.into(), ts, &spk, &spk_sig),
                )
                .await
                .unwrap();
            store
                .save_kyber_pre_key(2.into(), &KyberPreKeyRecord::new(2.into(), ts, &k, &k_sig))
                .await
                .unwrap();
        });
        Side {
            store,
            reg,
            pk: (7.into(), pk.public_key),
            spk: (1.into(), spk.public_key, spk_sig),
            kyber: (2.into(), k.public_key, k_sig),
        }
    }

    fn identity(&self) -> IdentityKey {
        *block_on(self.store.get_identity_key_pair())
            .unwrap()
            .identity_key()
    }

    fn bundle_with(&self, kyber: (KyberPreKeyId, kem::PublicKey, Vec<u8>)) -> PreKeyBundle {
        PreKeyBundle::new(
            self.reg,
            DeviceId::new(1).unwrap(),
            Some(self.pk),
            self.spk.0,
            self.spk.1,
            self.spk.2.clone(),
            kyber.0,
            kyber.1,
            kyber.2,
            self.identity(),
        )
        .unwrap()
    }

    fn bundle(&self) -> PreKeyBundle {
        self.bundle_with(self.kyber.clone())
    }

    fn session(&self, peer: &str) -> Option<SessionRecord> {
        block_on(self.store.load_session(&addr(peer))).unwrap()
    }

    fn saved(&self, peer: &str) -> Option<IdentityKey> {
        block_on(self.store.get_identity(&addr(peer))).unwrap()
    }

    fn holds_prekeys(&self) -> bool {
        block_on(async {
            self.store.get_pre_key(self.pk.0).await.is_ok()
                && self.store.get_signed_pre_key(self.spk.0).await.is_ok()
                && self.store.get_kyber_pre_key(self.kyber.0).await.is_ok()
        })
    }

    fn take_bundle(&mut self, peer: &str, b: &PreKeyBundle) -> Result<(), SignalProtocolError> {
        let s = &mut self.store;
        block_on(process_prekey_bundle(
            &addr(peer),
            &addr("me"),
            &mut s.session_store,
            &mut s.identity_store,
            b,
            now(),
            &mut rng(),
        ))
    }

    fn seal(&mut self, peer: &str, text: &[u8]) -> CiphertextMessage {
        let s = &mut self.store;
        block_on(message_encrypt(
            text,
            &addr(peer),
            &addr("me"),
            &mut s.session_store,
            &mut s.identity_store,
            now(),
            &mut rng(),
        ))
        .unwrap()
    }

    fn open_prekey(&mut self, peer: &str, m: &[u8]) -> Result<Vec<u8>, SignalProtocolError> {
        let m = PreKeySignalMessage::try_from(m)?;
        let s = &mut self.store;
        block_on(message_decrypt_prekey(
            &m,
            &addr(peer),
            &addr("me"),
            &mut s.session_store,
            &mut s.identity_store,
            &mut s.pre_key_store,
            &s.signed_pre_key_store,
            &mut s.kyber_pre_key_store,
            &mut rng(),
        ))
    }

    fn open_signal(&mut self, peer: &str, m: &[u8]) -> Result<Vec<u8>, SignalProtocolError> {
        let m = SignalMessage::try_from(m)?;
        let s = &mut self.store;
        block_on(message_decrypt_signal(
            &m,
            &addr(peer),
            &addr("me"),
            &mut s.session_store,
            &mut s.identity_store,
            &mut rng(),
        ))
    }
}

// what libsignal's bundle constructor takes: the kyber prekey is not an
// option. an update that made it one again stops this compiling
#[allow(clippy::type_complexity)]
const _BUNDLE_NEEDS_KYBER: fn(
    u32,
    DeviceId,
    Option<(PreKeyId, PublicKey)>,
    SignedPreKeyId,
    PublicKey,
    Vec<u8>,
    KyberPreKeyId,
    kem::PublicKey,
    Vec<u8>,
    IdentityKey,
) -> Result<PreKeyBundle, SignalProtocolError> = PreKeyBundle::new;

#[test]
fn a_bundle_with_a_bad_kyber_part_builds_nothing() {
    let mut alice = Side::new(1);
    let bob = Side::new(2);
    let carol = Side::new(3);
    let mut broken = bob.kyber.2.clone();
    broken[5] ^= 1;
    let cases = [
        (
            "kyber signature broken",
            (bob.kyber.0, bob.kyber.1.clone(), broken),
        ),
        (
            "another identity's kyber key",
            (bob.kyber.0, carol.kyber.1.clone(), bob.kyber.2.clone()),
        ),
        (
            "another identity's kyber key and signature",
            carol.kyber.clone(),
        ),
        (
            "the signed prekey's signature on the kyber key",
            (bob.kyber.0, bob.kyber.1.clone(), bob.spk.2.clone()),
        ),
    ];
    for (what, kyber) in cases {
        let b = bob.bundle_with(kyber);
        assert!(
            matches!(
                alice.take_bundle("bob", &b),
                Err(SignalProtocolError::SignatureValidationFailed)
            ),
            "{what}"
        );
        assert!(alice.session("bob").is_none(), "{what}: a session stored");
        assert!(alice.saved("bob").is_none(), "{what}: an identity saved");
    }
    // the good bundle goes through, so the refusals were the kyber part's
    alice.take_bundle("bob", &bob.bundle()).unwrap();
    assert_eq!(alice.session("bob").unwrap().session_version().unwrap(), 4);
    assert_eq!(alice.saved("bob"), Some(bob.identity()));
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

// bob of the fixture on a fresh install: his keys and the prekeys m1 names
fn dart_bob(f: &HashMap<String, Vec<u8>>) -> InMemSignalProtocolStore {
    let pair = IdentityKeyPair::try_from(f["bob_id"].as_slice()).unwrap();
    let mut s = InMemSignalProtocolStore::new(pair, 22).unwrap();
    let pk = PreKeyRecord::deserialize(&f["bob_pk"]).unwrap();
    let spk = SignedPreKeyRecord::deserialize(&f["bob_spk"]).unwrap();
    block_on(async {
        s.save_pre_key(pk.id().unwrap(), &pk).await.unwrap();
        s.save_signed_pre_key(spk.id().unwrap(), &spk)
            .await
            .unwrap();
    });
    s
}

fn open_prekey_in(
    s: &mut InMemSignalProtocolStore,
    m: &PreKeySignalMessage,
) -> Result<Vec<u8>, SignalProtocolError> {
    block_on(message_decrypt_prekey(
        m,
        &addr("alice"),
        &addr("me"),
        &mut s.session_store,
        &mut s.identity_store,
        &mut s.pre_key_store,
        &s.signed_pre_key_store,
        &mut s.kyber_pre_key_store,
        &mut rng(),
    ))
}

#[test]
fn a_classic_opener_builds_nothing() {
    let f = fixture();
    let m = PreKeySignalMessage::try_from(f["m1"].as_slice()).unwrap();
    assert_eq!(m.message_version(), 3);
    assert!(m.kyber_pre_key_id().is_none());
    let mut bob = dart_bob(&f);
    let e = open_prekey_in(&mut bob, &m).unwrap_err();
    assert!(
        matches!(&e, SignalProtocolError::InvalidMessage(CiphertextMessageType::PreKey, why) if why.contains("X3DH")),
        "{e}"
    );
    block_on(async {
        assert!(bob.load_session(&addr("alice")).await.unwrap().is_none());
        assert!(bob.get_identity(&addr("alice")).await.unwrap().is_none());
        // the one-time prekey is not spent
        assert!(bob.get_pre_key(1.into()).await.is_ok());
        assert!(bob.get_signed_pre_key(2.into()).await.is_ok());
    });
}

#[test]
fn a_classic_opener_reads_only_as_the_held_session() {
    let f = fixture();
    let m = PreKeySignalMessage::try_from(f["m1"].as_slice()).unwrap();
    let mut bob = dart_bob(&f);
    let held = SessionRecord::deserialize(&f["bob_rec"]).unwrap();
    let before = held.serialize().unwrap();
    block_on(bob.store_session(&addr("alice"), &held)).unwrap();
    // the opener the held session was built from: a copy already read
    assert!(matches!(
        open_prekey_in(&mut bob, &m),
        Err(SignalProtocolError::DuplicatedMessage(..))
    ));
    let after = block_on(bob.load_session(&addr("alice"))).unwrap().unwrap();
    assert_eq!(after.serialize().unwrap(), before);
    assert_eq!(after.session_version().unwrap(), 3);
    // and the held classic session goes on: m3, sealed by the dart library
    let m3 = SignalMessage::try_from(f["m3"].as_slice()).unwrap();
    let p = block_on(message_decrypt_signal(
        &m3,
        &addr("alice"),
        &addr("me"),
        &mut bob.session_store,
        &mut bob.identity_store,
        &mut rng(),
    ))
    .unwrap();
    assert_eq!(p, b"m3 from dart");
    let rec = block_on(bob.load_session(&addr("alice"))).unwrap().unwrap();
    assert_eq!(rec.session_version().unwrap(), 3);
}

// a protobuf message without the fields [drop], the rest as it was
fn without_fields(pb: &[u8], drop: &[u32]) -> Vec<u8> {
    let mut out = Vec::new();
    let mut i = 0;
    let varint = |i: &mut usize| {
        let mut v = 0u64;
        let mut shift = 0;
        loop {
            let b = pb[*i];
            *i += 1;
            v |= u64::from(b & 0x7f) << shift;
            if b & 0x80 == 0 {
                return v;
            }
            shift += 7;
        }
    };
    while i < pb.len() {
        let start = i;
        let key = varint(&mut i);
        match key & 7 {
            0 => {
                varint(&mut i);
            }
            2 => {
                let n = varint(&mut i) as usize;
                i += n;
            }
            t => panic!("wire type {t}"),
        }
        if !drop.contains(&((key >> 3) as u32)) {
            out.extend_from_slice(&pb[start..i]);
        }
    }
    out
}

#[test]
fn a_pq_opener_without_its_kyber_part_builds_nothing() {
    let mut alice = Side::new(1);
    let mut bob = Side::new(2);
    alice.take_bundle("bob", &bob.bundle()).unwrap();
    let m = alice.seal("bob", b"first");
    let CiphertextMessage::PreKeySignalMessage(m) = m else {
        panic!("not an opener")
    };
    let wire = m.serialized().to_vec();
    assert_eq!(wire[0] >> 4, 4);
    assert!(m.kyber_pre_key_id().is_some());
    // kyber_pre_key_id is field 7, kyber_ciphertext field 8
    for drop in [&[7u32, 8][..], &[7], &[8]] {
        let mut x = vec![wire[0]];
        x.extend(without_fields(&wire[1..], drop));
        assert!(
            matches!(
                bob.open_prekey("alice", &x),
                Err(SignalProtocolError::InvalidMessage(..))
            ),
            "without {drop:?}"
        );
        // and the same claiming version 3, as an x3dh opener would
        x[0] = 0x33;
        assert!(
            matches!(
                bob.open_prekey("alice", &x),
                Err(SignalProtocolError::InvalidMessage(..))
            ),
            "as version 3 without {drop:?}"
        );
        assert!(bob.session("alice").is_none());
        assert!(bob.saved("alice").is_none());
        assert!(bob.holds_prekeys());
    }
    // the opener as sent still opens, so nothing above was spent
    assert_eq!(bob.open_prekey("alice", &wire).unwrap(), b"first");
    assert!(bob.session("alice").is_some());
}

// spqr on one side's current state: v1, and it will not negotiate down
fn assert_spqr_required(rec: &SessionRecord, side: &str) {
    assert_eq!(rec.session_version().unwrap(), 4, "{side}");
    let pq = rec.current_pq_state().expect("a current state");
    assert!(!pq.is_empty(), "{side}: no pq ratchet");
    match spqr::current_version(pq).unwrap() {
        spqr::CurrentVersion::StillNegotiating {
            version,
            min_version,
        } => {
            assert_eq!(version as i32, spqr::Version::V1 as i32, "{side}");
            assert_eq!(
                min_version as i32,
                spqr::Version::V1 as i32,
                "{side}: min_version"
            );
        }
        spqr::CurrentVersion::NegotiationComplete(v) => {
            assert_eq!(v as i32, spqr::Version::V1 as i32, "{side}");
        }
    }
    // a message without the pq part is what a peer without spqr sends
    assert!(
        spqr::recv(pq, &Vec::new()).is_err(),
        "{side}: took a v0 message"
    );
}

#[test]
fn a_pq_session_requires_spqr_on_both_sides() {
    let mut alice = Side::new(1);
    let mut bob = Side::new(2);
    alice.take_bundle("bob", &bob.bundle()).unwrap();
    assert_spqr_required(&alice.session("bob").unwrap(), "alice from the bundle");
    let m = alice.seal("bob", b"first");
    assert_eq!(bob.open_prekey("alice", m.serialize()).unwrap(), b"first");
    assert_spqr_required(&bob.session("alice").unwrap(), "bob from the opener");
    // the first reply, and a few more each way
    for i in 0..3u8 {
        let r = bob.seal("alice", &[i; 3]);
        let CiphertextMessage::SignalMessage(r) = r else {
            panic!("bob answers inside the session")
        };
        assert_eq!(alice.open_signal("bob", r.serialized()).unwrap(), [i; 3]);
        let m = alice.seal("bob", &[i; 4]);
        let m = match m {
            CiphertextMessage::SignalMessage(m) => m.serialized().to_vec(),
            other => panic!("{:?}", other.message_type()),
        };
        assert_eq!(bob.open_signal("alice", &m).unwrap(), [i; 4]);
        assert_spqr_required(&alice.session("bob").unwrap(), "alice");
        assert_spqr_required(&bob.session("alice").unwrap(), "bob");
    }
}

// the shim's calls take framed fields: a u32 little endian length, the bytes
fn frame(fields: &[&[u8]]) -> Vec<u8> {
    let mut out = Vec::new();
    for f in fields {
        out.extend_from_slice(&(f.len() as u32).to_le_bytes());
        out.extend_from_slice(f);
    }
    out
}

fn unframe(mut b: &[u8]) -> Vec<Vec<u8>> {
    let mut out = Vec::new();
    while !b.is_empty() {
        let n = u32::from_le_bytes(b[..4].try_into().unwrap()) as usize;
        out.push(b[4..4 + n].to_vec());
        b = &b[4 + n..];
    }
    out
}

// case 7: the classic state left behind by a pq restart, gone from the
// record, opens nothing in libsignal itself; the pq state goes on
#[test]
fn a_dropped_classic_state_opens_nothing() {
    let f = fixture();
    let mut bob = dart_bob(&f);
    block_on(bob.store_session(
        &addr("alice"),
        &SessionRecord::deserialize(&f["bob_rec"]).unwrap(),
    ))
    .unwrap();
    // alice's pq prekeys, and bob restarting the chat on them
    let mut r = rng();
    let alice_pair = IdentityKeyPair::try_from(f["alice_id"].as_slice()).unwrap();
    let mut alice = InMemSignalProtocolStore::new(alice_pair, 11).unwrap();
    let spk = KeyPair::generate(&mut r);
    let spk_sig = alice_pair
        .private_key()
        .calculate_signature(&spk.public_key.serialize(), &mut r)
        .unwrap();
    let k = kem::KeyPair::generate(kem::KeyType::Kyber1024, &mut r);
    let k_sig = alice_pair
        .private_key()
        .calculate_signature(&k.public_key.serialize(), &mut r)
        .unwrap();
    let ts = Timestamp::from_epoch_millis(1_760_000_000_000);
    block_on(async {
        alice
            .save_signed_pre_key(
                51.into(),
                &SignedPreKeyRecord::new(51.into(), ts, &spk, &spk_sig),
            )
            .await
            .unwrap();
        alice
            .save_kyber_pre_key(
                52.into(),
                &KyberPreKeyRecord::new(52.into(), ts, &k, &k_sig),
            )
            .await
            .unwrap();
        alice
            .store_session(
                &addr("bob"),
                &SessionRecord::deserialize(&f["alice_rec"]).unwrap(),
            )
            .await
            .unwrap();
    });
    let bundle = PreKeyBundle::new(
        11,
        DeviceId::new(1).unwrap(),
        None,
        51.into(),
        spk.public_key,
        spk_sig.to_vec(),
        52.into(),
        k.public_key,
        k_sig.to_vec(),
        *alice_pair.identity_key(),
    )
    .unwrap();
    block_on(process_prekey_bundle(
        &addr("alice"),
        &addr("me"),
        &mut bob.session_store,
        &mut bob.identity_store,
        &bundle,
        now(),
        &mut r,
    ))
    .unwrap();
    let restarted = block_on(bob.load_session(&addr("alice"))).unwrap().unwrap();
    assert_eq!(restarted.session_version().unwrap(), 4);
    let m3 = SignalMessage::try_from(f["m3"].as_slice()).unwrap();
    let open_m3 = |bob: &mut InMemSignalProtocolStore| {
        block_on(message_decrypt_signal(
            &m3,
            &addr("alice"),
            &addr("me"),
            &mut bob.session_store,
            &mut bob.identity_store,
            &mut rng(),
        ))
    };
    // before the drop the archived classic state still takes m3
    let mut copy = dart_bob(&f);
    block_on(copy.store_session(&addr("alice"), &restarted)).unwrap();
    assert_eq!(open_m3(&mut copy).unwrap(), b"m3 from dart");
    // bob's first pq message and alice's answer, on libsignal's stores
    let sealed = block_on(message_encrypt(
        b"on pq",
        &addr("alice"),
        &addr("me"),
        &mut bob.session_store,
        &mut bob.identity_store,
        now(),
        &mut rng(),
    ))
    .unwrap();
    let opener = PreKeySignalMessage::try_from(sealed.serialize()).unwrap();
    assert_eq!(opener.message_version(), 4);
    // unanswered, the drop is refused: the classic state may still be all
    // that reads the peer
    let unanswered = block_on(bob.load_session(&addr("alice")))
        .unwrap()
        .unwrap()
        .serialize()
        .unwrap();
    assert!(kryfo_signal::session_drop_below(&frame(&[&unanswered, &4u32.to_le_bytes()])).is_err());
    let p = block_on(message_decrypt_prekey(
        &opener,
        &addr("bob"),
        &addr("me"),
        &mut alice.session_store,
        &mut alice.identity_store,
        &mut alice.pre_key_store,
        &alice.signed_pre_key_store,
        &mut alice.kyber_pre_key_store,
        &mut rng(),
    ))
    .unwrap();
    assert_eq!(p, b"on pq");
    let reply = block_on(message_encrypt(
        b"back",
        &addr("bob"),
        &addr("me"),
        &mut alice.session_store,
        &mut alice.identity_store,
        now(),
        &mut rng(),
    ))
    .unwrap();
    let reply = SignalMessage::try_from(reply.serialize()).unwrap();
    let p = block_on(message_decrypt_signal(
        &reply,
        &addr("alice"),
        &addr("me"),
        &mut bob.session_store,
        &mut bob.identity_store,
        &mut rng(),
    ))
    .unwrap();
    assert_eq!(p, b"back");
    // answered: the drop goes, and after it the classic state opens nothing
    let held = block_on(bob.load_session(&addr("alice")))
        .unwrap()
        .unwrap()
        .serialize()
        .unwrap();
    let out =
        unframe(&kryfo_signal::session_drop_below(&frame(&[&held, &4u32.to_le_bytes()])).unwrap());
    assert_eq!(out[1], 1u32.to_le_bytes());
    let dropped = SessionRecord::deserialize(&out[0]).unwrap();
    block_on(bob.store_session(&addr("alice"), &dropped)).unwrap();
    assert!(open_m3(&mut bob).is_err());
    let after = block_on(bob.load_session(&addr("alice"))).unwrap().unwrap();
    assert_eq!(
        after.serialize().unwrap(),
        out[0],
        "a failed open changed the record"
    );
    // the pq state goes on
    let again = block_on(message_encrypt(
        b"still pq",
        &addr("alice"),
        &addr("me"),
        &mut bob.session_store,
        &mut bob.identity_store,
        now(),
        &mut rng(),
    ))
    .unwrap();
    let again = SignalMessage::try_from(again.serialize()).unwrap();
    let p = block_on(message_decrypt_signal(
        &again,
        &addr("bob"),
        &addr("me"),
        &mut alice.session_store,
        &mut alice.identity_store,
        &mut rng(),
    ))
    .unwrap();
    assert_eq!(p, b"still pq");
}
