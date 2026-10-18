// SPDX-License-Identifier: GPL-3.0-or-later
// what a session record holds, read off its protobuf without going through
// libsignal's private state. archived states are kept as bytes there and
// libsignal does not hand them out; restore marks and the opener merge
// need their base keys

use libsignal_protocol::SessionRecord;
use prost::Message;

use crate::Error;

// RecordStructure, its states left as bytes so they go back unchanged
#[derive(Clone, PartialEq, Message)]
struct Rec {
    #[prost(bytes = "vec", optional, tag = "1")]
    current: Option<Vec<u8>>,
    #[prost(bytes = "vec", repeated, tag = "2")]
    previous: Vec<Vec<u8>>,
}

// the few SessionStructure fields read here; the rest is skipped
#[derive(Clone, PartialEq, Message)]
struct Peek {
    #[prost(uint32, tag = "1")]
    version: u32,
    #[prost(bytes = "vec", tag = "13")]
    alice_base_key: Vec<u8>,
    #[prost(bytes = "vec", tag = "15")]
    pq_ratchet_state: Vec<u8>,
    #[prost(message, optional, tag = "9")]
    pending_pre_key: Option<Pending>,
}

// SessionStructure.PendingPreKey, its timestamp only: seconds, as libsignal
// writes it
#[derive(Clone, PartialEq, Message)]
struct Pending {
    #[prost(uint64, tag = "4")]
    timestamp: u64,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct State {
    pub version: u32,
    pub base_key: Vec<u8>,
    pub pq: bool,
}

fn peek(b: &[u8]) -> Result<State, Error> {
    let p = Peek::decode(b).map_err(|_| Error::Session)?;
    Ok(State {
        version: p.version,
        base_key: p.alice_base_key,
        pq: !p.pq_ratchet_state.is_empty(),
    })
}

/// the current state, when there is one, and the archived ones in order
pub fn states(record: &[u8]) -> Result<(Option<State>, Vec<State>), Error> {
    let r = Rec::decode(record).map_err(|_| Error::Session)?;
    let cur = match r.current {
        Some(c) => Some(peek(&c)?).filter(|s| s.version != 0),
        None => None,
    };
    let prev = r
        .previous
        .iter()
        .map(|p| peek(p))
        .collect::<Result<_, _>>()?;
    Ok((cur, prev))
}

/// whether [record] holds a state for this version and base key, current or
/// archived
pub fn holds(record: &[u8], version: u32, base_key: &[u8]) -> Result<bool, Error> {
    let (cur, prev) = states(record)?;
    Ok(cur
        .iter()
        .chain(prev.iter())
        .any(|s| s.version == version && s.base_key == base_key))
}

// as many archived states as libsignal keeps
const ARCHIVED_MAX: usize = 40;

/// [newer]'s current state in front of [held]'s, which is archived as
/// libsignal archives it. an archived copy of the newer state goes, so
/// each session is held once
pub fn promote(held: &[u8], newer: &[u8]) -> Result<Vec<u8>, Error> {
    let mut h = SessionRecord::deserialize(held)?;
    h.archive_current_state()?;
    let h = Rec::decode(h.serialize()?.as_slice()).map_err(|_| Error::Session)?;
    SessionRecord::deserialize(newer)?;
    let n = Rec::decode(newer).map_err(|_| Error::Session)?;
    let cur = n.current.ok_or(Error::NoSession)?;
    let key = peek(&cur)?;
    if key.version == 0 {
        return Err(Error::NoSession);
    }
    let previous = h
        .previous
        .into_iter()
        .filter(|p| {
            peek(p).map_or(true, |s| {
                s.version != key.version || s.base_key != key.base_key
            })
        })
        .take(ARCHIVED_MAX)
        .collect();
    let out = Rec {
        current: Some(cur),
        previous,
    }
    .encode_to_vec();
    SessionRecord::deserialize(&out)?;
    Ok(out)
}

/// [record] with an undated opener dated [now_ms], or None when it needs
/// nothing. libsignal_protocol_dart writes no time on the opener it keeps until
/// the far side answers, and libsignal takes a missing one as 1970: a
/// session older than 30 days, refused. the date goes on as a second
/// PendingPreKey holding only it, which protobuf merges into the first
pub fn date_pending(record: &[u8], now_ms: u64) -> Result<Option<Vec<u8>>, Error> {
    let mut r = Rec::decode(record).map_err(|_| Error::Session)?;
    let Some(cur) = r.current.as_mut() else {
        return Ok(None);
    };
    let p = Peek::decode(cur.as_slice()).map_err(|_| Error::Session)?;
    match p.pending_pre_key {
        Some(Pending { timestamp: 0 }) => {}
        _ => return Ok(None),
    }
    let mut extra = Vec::new();
    let timestamp = now_ms / 1000;
    prost::encoding::message::encode(9, &Pending { timestamp }, &mut extra);
    cur.extend_from_slice(&extra);
    let out = r.encode_to_vec();
    SessionRecord::deserialize(&out)?;
    Ok(Some(out))
}
