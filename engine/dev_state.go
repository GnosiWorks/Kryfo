// SPDX-License-Identifier: GPL-3.0-or-later
package main

// linked devices: the everyday container's Book, Own, Quiet and Pool,
// held here and loaded at the start from the rows the app keeps. every call
// that changes them gives the rows to write, and the app writes them in the
// session's transaction before anything is sent. list signatures are
// checked by the shim (kshim): the rules stay there, and the app never
// vouches for one. nothing here runs while the app's switch is off.

import (
	"bytes"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"slices"
	"sync"
	"time"

	"github.com/halo/engine/devices"
	"github.com/halo/engine/kshim"
)

// owner of an own list's row in dev_lists
const devOwnerMe = "me"

var errNoShim = errors.New("the signal library is not open")

// a verifier over the shim, or one that refuses every signature while it
// is not open
type devVerifier struct{ l *kshim.Lib }

func (v devVerifier) Verify(pub devices.Key, context string, body, sig []byte) error {
	if v.l == nil {
		return devices.ErrSignature
	}
	if err := v.l.Verify(pub[:], context, body, sig); err != nil {
		return devices.ErrSignature
	}
	return nil
}

type devMine struct {
	ident int
	// this device's key for the identity: the identity itself on the phone
	key devices.Key
}

type devState struct {
	mu    sync.Mutex
	v     devVerifier
	book  *devices.Book
	own   *devices.Own
	quiet *devices.Quiet
	pool  *devices.Pool
	// my identities, and the identity of each ident
	mine   map[devices.Key]devMine
	idents map[int]devices.Key
	// each contact identity's ident
	peers map[devices.Key]int
}

func newDevState(v devVerifier) *devState {
	return &devState{
		v:      v,
		book:   devices.NewBook(),
		own:    devices.NewOwn(),
		quiet:  devices.NewQuiet(),
		pool:   devices.NewPool(),
		mine:   map[devices.Key]devMine{},
		idents: map[int]devices.Key{},
		peers:  map[devices.Key]int{},
	}
}

var (
	devMu  sync.Mutex
	devCur = newDevState(devVerifier{})
)

func devNow() *devState {
	devMu.Lock()
	defer devMu.Unlock()
	return devCur
}

// one row to write or delete, in the order given
type devOp struct {
	T   string         `json:"t"`
	Put map[string]any `json:"put,omitempty"`
	Del map[string]any `json:"del,omitempty"`
}

func hexKey(k devices.Key) string { return hex.EncodeToString(k[:]) }

func parseHexKey(s string) (devices.Key, error) {
	b, err := hex.DecodeString(s)
	if err != nil {
		return devices.Key{}, devices.ErrMalformed
	}
	return devices.ParseKey(b)
}

func devB64(b []byte) any {
	if b == nil {
		return nil
	}
	return base64.StdEncoding.EncodeToString(b)
}

func ms(t time.Time) int64 {
	if t.IsZero() {
		return 0
	}
	return t.UnixMilli()
}

func fromMs(v int64) time.Time {
	if v == 0 {
		return time.Time{}
	}
	return time.UnixMilli(v)
}

func bit(b bool) int {
	if b {
		return 1
	}
	return 0
}

// the ident of a contact or of one of my identities
func (d *devState) identOf(identity devices.Key) (int, bool) {
	if m, ok := d.mine[identity]; ok {
		return m.ident, true
	}
	i, ok := d.peers[identity]
	return i, ok
}

// rows for what the book holds for a contact, from before to after
func bookRows(ident int, identity devices.Key, before, after devices.Kept, had, has bool) []devOp {
	peer := hexKey(identity)
	var out []devOp
	key := map[string]any{"ident": ident, "owner": peer}
	switch {
	case has && after.List != nil && (!had || !bytes.Equal(before.List, after.List) || before.FromInvite != after.FromInvite):
		l, _ := devices.ParseList(after.List)
		out = append(out, devOp{T: "dev_lists", Put: map[string]any{
			"ident": ident, "owner": peer, "version": l.Version, "wire": devB64(after.List),
			"from_invite": bit(after.FromInvite),
		}})
	case had && before.List != nil && (!has || after.List == nil):
		out = append(out, devOp{T: "dev_lists", Del: key})
	}
	for _, p := range before.Proven {
		if !has || !slices.Contains(after.Proven, p) {
			out = append(out, devOp{T: "dev_proven", Del: map[string]any{"ident": ident, "peer": peer, "key": hexKey(p)}})
		}
	}
	for _, p := range after.Proven {
		if !had || !slices.Contains(before.Proven, p) {
			out = append(out, devOp{T: "dev_proven", Put: map[string]any{"ident": ident, "peer": peer, "key": hexKey(p)}})
		}
	}
	switch {
	case has && after.PQ && !(had && before.PQ):
		out = append(out, devOp{T: "dev_pq", Put: map[string]any{"ident": ident, "peer": peer}})
	case !has && had && before.PQ:
		out = append(out, devOp{T: "dev_pq", Del: map[string]any{"ident": ident, "peer": peer}})
	}
	return out
}

func ownRows(ident int, before, after devices.OwnKept, had, has bool) []devOp {
	switch {
	case has && (!had || !bytes.Equal(before.List, after.List)):
		l, _ := devices.ParseList(after.List)
		return []devOp{{T: "dev_lists", Put: map[string]any{
			"ident": ident, "owner": devOwnerMe, "version": l.Version, "wire": devB64(after.List),
			"from_invite": 0,
		}}}
	case had && !has:
		return []devOp{{T: "dev_lists", Del: map[string]any{"ident": ident, "owner": devOwnerMe}}}
	}
	return nil
}

func quietRows(ident int, before, after devices.QuietKept, had, has bool) []devOp {
	k := map[string]any{"ident": ident, "peer": hexKey(after.Identity), "device": int(after.Device)}
	if !has {
		if !had {
			return nil
		}
		return []devOp{{T: "dev_quiet", Del: map[string]any{"ident": ident, "peer": hexKey(before.Identity), "device": int(before.Device)}}}
	}
	if had && before == after {
		return nil
	}
	k["key"] = hexKey(after.Key)
	k["first_at"] = ms(after.First)
	k["rebuilt_at"] = ms(after.Session)
	k["probe_at"] = ms(after.Probed)
	k["silent"] = bit(after.Silent)
	k["under"] = after.Under
	return []devOp{{T: "dev_quiet", Put: k}}
}

func poolRows(ident int, device uint8, before, after devices.PoolKept) []devOp {
	var out []devOp
	old := map[uint32]devices.PoolBundle{}
	for _, b := range before.Bundles {
		old[b.Kyber] = b
	}
	now := map[uint32]bool{}
	sameEntry := before.Entry == after.Entry
	for _, b := range after.Bundles {
		now[b.Kyber] = true
		if o, ok := old[b.Kyber]; ok && sameEntry && o.Last == b.Last && o.At.Equal(b.At) && bytes.Equal(o.KDB1, b.KDB1) {
			continue
		}
		e := after.Entry
		out = append(out, devOp{T: "dev_pool", Put: map[string]any{
			"ident": ident, "device": int(device), "kyber_id": b.Kyber,
			"key": hexKey(e.Key), "reg": e.Reg, "answers": bit(e.Answers),
			"spk_id": b.Spk, "kdb1": devB64(b.KDB1), "aged_at": ms(b.At), "last": bit(b.Last),
		}})
	}
	for _, b := range before.Bundles {
		if !now[b.Kyber] {
			out = append(out, devOp{T: "dev_pool", Del: map[string]any{"ident": ident, "device": int(device), "kyber_id": b.Kyber}})
		}
	}
	return out
}

// what a call does to the stored state of a contact or own identity,
// noted before it runs
type devSnap struct {
	d        *devState
	identity devices.Key
	ident    int
	book     devices.Kept
	hadBook  bool
	own      devices.OwnKept
	hadOwn   bool
	quiet    map[uint8]devices.QuietKept
	pool     map[uint8]devices.PoolKept
}

func (d *devState) snap(identity devices.Key) *devSnap {
	ident, _ := d.identOf(identity)
	s := &devSnap{d: d, identity: identity, ident: ident, quiet: map[uint8]devices.QuietKept{}, pool: map[uint8]devices.PoolKept{}}
	s.book, s.hadBook = d.book.Kept(identity)
	s.own, s.hadOwn = d.own.Kept(identity)
	for _, dev := range d.quiet.Slots(identity) {
		s.quiet[dev], _ = d.quiet.Kept(identity, dev)
	}
	for _, dev := range d.pool.Slots(identity) {
		s.pool[dev], _ = d.pool.Kept(identity, dev)
	}
	return s
}

// the rows that take the stored state from the snapshot to now
func (s *devSnap) rows() []devOp {
	d, id := s.d, s.identity
	var out []devOp
	after, has := d.book.Kept(id)
	out = append(out, bookRows(s.ident, id, s.book, after, s.hadBook, has)...)
	own, hasOwn := d.own.Kept(id)
	out = append(out, ownRows(s.ident, s.own, own, s.hadOwn, hasOwn)...)
	devs := map[uint8]bool{}
	for dev := range s.quiet {
		devs[dev] = true
	}
	for _, dev := range d.quiet.Slots(id) {
		devs[dev] = true
	}
	for _, dev := range sortedDevs(devs) {
		b, had := s.quiet[dev]
		a, has := d.quiet.Kept(id, dev)
		out = append(out, quietRows(s.ident, b, a, had, has)...)
	}
	devs = map[uint8]bool{}
	for dev := range s.pool {
		devs[dev] = true
	}
	for _, dev := range d.pool.Slots(id) {
		devs[dev] = true
	}
	for _, dev := range sortedDevs(devs) {
		a, _ := d.pool.Kept(id, dev)
		out = append(out, poolRows(s.ident, dev, s.pool[dev], a)...)
	}
	return out
}

func sortedDevs(m map[uint8]bool) []uint8 {
	out := make([]uint8, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	slices.Sort(out)
	return out
}

// the rows the app reads back at the start
type devLoad struct {
	Mine []struct {
		Ident    int    `json:"ident"`
		Identity string `json:"identity"`
		Key      string `json:"key"`
	} `json:"mine"`
	Contacts []struct {
		Ident    int    `json:"ident"`
		Identity string `json:"identity"`
	} `json:"contacts"`
	Lists []struct {
		Ident      int    `json:"ident"`
		Owner      string `json:"owner"`
		Wire       []byte `json:"wire"`
		FromInvite int    `json:"from_invite"`
	} `json:"dev_lists"`
	Proven []struct {
		Ident int    `json:"ident"`
		Peer  string `json:"peer"`
		Key   string `json:"key"`
	} `json:"dev_proven"`
	PQ []struct {
		Ident int    `json:"ident"`
		Peer  string `json:"peer"`
	} `json:"dev_pq"`
	Quiet []struct {
		Ident     int    `json:"ident"`
		Peer      string `json:"peer"`
		Device    int    `json:"device"`
		Key       string `json:"key"`
		FirstAt   int64  `json:"first_at"`
		RebuiltAt int64  `json:"rebuilt_at"`
		ProbeAt   int64  `json:"probe_at"`
		Silent    int    `json:"silent"`
		Under     uint64 `json:"under"`
	} `json:"dev_quiet"`
	Pool []struct {
		Ident   int    `json:"ident"`
		Device  int    `json:"device"`
		Kyber   uint32 `json:"kyber_id"`
		Key     string `json:"key"`
		Reg     uint32 `json:"reg"`
		Answers int    `json:"answers"`
		Spk     uint32 `json:"spk_id"`
		KDB1    []byte `json:"kdb1"`
		AgedAt  int64  `json:"aged_at"`
		Last    int    `json:"last"`
	} `json:"dev_pool"`
}

// a fresh state from the stored rows, and how many rows did not load: a
// row of a contact gone, a list that no longer reads. such a row stays in
// the database untouched; nothing is deleted at the start
func loadDevState(in *devLoad, v devVerifier) (*devState, []devices.Key, int, error) {
	if v.l == nil {
		return nil, nil, 0, errNoShim
	}
	d := newDevState(v)
	var own []devices.Key
	for _, m := range in.Mine {
		id, err := parseHexKey(m.Identity)
		if err != nil {
			return nil, nil, 0, err
		}
		key := id
		if m.Key != "" {
			if key, err = parseHexKey(m.Key); err != nil {
				return nil, nil, 0, err
			}
		}
		if _, dup := d.idents[m.Ident]; dup {
			return nil, nil, 0, devices.ErrDuplicate
		}
		d.mine[id] = devMine{ident: m.Ident, key: key}
		d.idents[m.Ident] = id
		own = append(own, id, key)
	}
	d.book = devices.NewBook(own...)
	skipped := 0
	for _, c := range in.Contacts {
		id, err := parseHexKey(c.Identity)
		if err != nil {
			skipped++
			continue
		}
		if _, err := d.book.Add(id); err != nil {
			skipped++
			continue
		}
		d.peers[id] = c.Ident
	}
	// a contact's row is its only while it is on the ident the row names
	contact := func(ident int, peer string) (devices.Key, bool) {
		id, err := parseHexKey(peer)
		if err != nil {
			return devices.Key{}, false
		}
		i, ok := d.peers[id]
		return id, ok && i == ident
	}
	kept := map[devices.Key]*devices.Kept{}
	keptOf := func(id devices.Key) *devices.Kept {
		if k := kept[id]; k != nil {
			return k
		}
		k := &devices.Kept{Identity: id}
		kept[id] = k
		return k
	}
	for _, r := range in.Lists {
		if r.Owner == devOwnerMe {
			id, ok := d.idents[r.Ident]
			if !ok {
				skipped++
				continue
			}
			if err := d.own.Restore(devices.OwnKept{Identity: id, List: r.Wire, Mine: d.mine[id].key}, v); err != nil {
				skipped++
			}
			continue
		}
		id, ok := contact(r.Ident, r.Owner)
		if !ok {
			skipped++
			continue
		}
		k := keptOf(id)
		k.List, k.FromInvite = r.Wire, r.FromInvite != 0
	}
	for _, r := range in.Proven {
		id, ok := contact(r.Ident, r.Peer)
		key, err := parseHexKey(r.Key)
		if !ok || err != nil {
			skipped++
			continue
		}
		k := keptOf(id)
		k.Proven = append(k.Proven, key)
	}
	for _, r := range in.PQ {
		id, ok := contact(r.Ident, r.Peer)
		if !ok {
			skipped++
			continue
		}
		keptOf(id).PQ = true
	}
	ids := make([]devices.Key, 0, len(kept))
	for id := range kept {
		ids = append(ids, id)
	}
	slices.SortFunc(ids, func(a, b devices.Key) int { return bytes.Compare(a[:], b[:]) })
	for _, id := range ids {
		if _, err := d.book.Restore(*kept[id], v); err != nil {
			// the list does not read: what else is held still loads
			skipped++
			k := *kept[id]
			k.List, k.Proven = nil, nil
			if _, err := d.book.Restore(k, v); err != nil {
				skipped++
			}
		}
	}
	for _, r := range in.Quiet {
		id, err := parseHexKey(r.Peer)
		key, kerr := parseHexKey(r.Key)
		ident, ok := d.identOf(id)
		if err != nil || kerr != nil || !ok || ident != r.Ident || r.Device < devices.PhoneID || r.Device > devices.MaxID {
			skipped++
			continue
		}
		d.quiet.Restore(devices.QuietKept{
			Identity: id, Device: uint8(r.Device), Key: key,
			First: fromMs(r.FirstAt), Session: fromMs(r.RebuiltAt), Probed: fromMs(r.ProbeAt),
			Silent: r.Silent != 0, Under: r.Under,
		})
	}
	type slot struct {
		ident  int
		device int
	}
	pools := map[slot]*devices.PoolKept{}
	var order []slot
	for _, r := range in.Pool {
		id, ok := d.idents[r.Ident]
		key, err := parseHexKey(r.Key)
		if !ok || err != nil || r.Device <= devices.PhoneID || r.Device > devices.MaxID {
			skipped++
			continue
		}
		s := slot{r.Ident, r.Device}
		e := devices.Entry{ID: uint8(r.Device), Key: key, Reg: r.Reg, Answers: r.Answers != 0}
		p := pools[s]
		if p == nil {
			p = &devices.PoolKept{Identity: id, Entry: e}
			pools[s] = p
			order = append(order, s)
		}
		if p.Entry != e {
			skipped++
			continue
		}
		p.Bundles = append(p.Bundles, devices.PoolBundle{Kyber: r.Kyber, Spk: r.Spk, KDB1: r.KDB1, At: fromMs(r.AgedAt), Last: r.Last != 0})
	}
	for _, s := range order {
		if err := d.pool.Restore(*pools[s]); err != nil {
			skipped++
		}
	}
	return d, d.book.Claimants(), skipped, nil
}

// the listed key of device dev of the contact or own identity peer (an x
// key) of my identity ident: the address layer's device keys. a disputed
// or unlisted device has none
func (d *devState) deviceKey(ident int, peer [32]byte, dev uint8) ([32]byte, bool) {
	d.mu.Lock()
	defer d.mu.Unlock()
	var id devices.Key
	id[0] = 0x05
	copy(id[1:], peer[:])
	var k devices.Key
	if m, ok := d.mine[id]; ok {
		if m.ident != ident {
			return [32]byte{}, false
		}
		l := d.own.Current(id)
		if l == nil {
			return [32]byte{}, false
		}
		e, ok := l.Find(dev)
		if !ok {
			return [32]byte{}, false
		}
		k = e.Key
	} else if i, held := d.peers[id]; !held {
		// a hidden chat's contact while its vault is shut: the keys its
		// card names, for listening alone
		var ok bool
		if k, ok = devHeardKey(ident, id, dev); !ok {
			return [32]byte{}, false
		}
	} else {
		if i != ident {
			return [32]byte{}, false
		}
		var ok bool
		if k, ok = d.book.Pin(id, dev); !ok {
			return [32]byte{}, false
		}
	}
	var out [32]byte
	copy(out[:], k[1:])
	return out, true
}

// the device keys for the address layer: whatever state is loaded now
type devKeySource struct{}

func (devKeySource) deviceKey(ident int, peer [32]byte, dev uint8) ([32]byte, bool) {
	return devNow().deviceKey(ident, peer, dev)
}

func init() { setDeviceKeys(devKeySource{}) }

// a hidden chat's contact, by my identity and theirs: their device keys as
// the vault's card names them, while the book does not hold them. only the
// address layer reads these; nothing is admitted on them
type devHeardAt struct {
	ident    int
	identity devices.Key
}

var (
	devHeardMu   sync.Mutex
	devHeardKeys = map[devHeardAt]map[uint8]devices.Key{}
)

func devHeardKey(ident int, identity devices.Key, dev uint8) (devices.Key, bool) {
	devHeardMu.Lock()
	defer devHeardMu.Unlock()
	k, ok := devHeardKeys[devHeardAt{ident, identity}][dev]
	return k, ok
}

// the keys of a.Identity's devices to listen on, in place of any held;
// none forgets them
func (d *devState) listenKeys(a *devArgs) error {
	id, err := a.identity()
	if err != nil {
		return err
	}
	if _, mine := d.mine[id]; mine {
		return devices.ErrSelf
	}
	keys := map[uint8]devices.Key{}
	for _, h := range a.Held {
		k, err := parseHexKey(h.Key)
		if err != nil || h.ID <= devices.PhoneID || h.ID > devices.MaxID || k == id {
			return devices.ErrMalformed
		}
		keys[uint8(h.ID)] = k
	}
	devHeardMu.Lock()
	defer devHeardMu.Unlock()
	at := devHeardAt{a.Ident, id}
	if len(keys) == 0 {
		delete(devHeardKeys, at)
	} else {
		devHeardKeys[at] = keys
	}
	return nil
}

// the contacts of an open vault and their rows, into the state held: a
// contact the state holds with a list already is left as it is. nothing is
// written; the rows stay in the vault
func (d *devState) loadPeers(in *devLoad) ([]devices.Key, int) {
	skipped := 0
	took := map[devices.Key]int{}
	for _, c := range in.Contacts {
		id, err := parseHexKey(c.Identity)
		if err != nil {
			skipped++
			continue
		}
		if _, mine := d.mine[id]; mine {
			skipped++
			continue
		}
		if i, ok := d.peers[id]; ok {
			k, _ := d.book.Kept(id)
			if i != c.Ident || k.List != nil || len(d.quiet.Slots(id)) > 0 {
				skipped++
				continue
			}
		} else if _, err := d.book.Add(id); err != nil {
			skipped++
			continue
		}
		d.peers[id] = c.Ident
		took[id] = c.Ident
	}
	ours := func(ident int, peer string) (devices.Key, bool) {
		id, err := parseHexKey(peer)
		if err != nil {
			return devices.Key{}, false
		}
		i, ok := took[id]
		return id, ok && i == ident
	}
	kept := map[devices.Key]*devices.Kept{}
	keptOf := func(id devices.Key) *devices.Kept {
		if k := kept[id]; k != nil {
			return k
		}
		k := &devices.Kept{Identity: id}
		kept[id] = k
		return k
	}
	for _, r := range in.Lists {
		id, ok := ours(r.Ident, r.Owner)
		if !ok {
			skipped++
			continue
		}
		k := keptOf(id)
		k.List, k.FromInvite = r.Wire, r.FromInvite != 0
	}
	for _, r := range in.Proven {
		id, ok := ours(r.Ident, r.Peer)
		key, err := parseHexKey(r.Key)
		if !ok || err != nil {
			skipped++
			continue
		}
		k := keptOf(id)
		k.Proven = append(k.Proven, key)
	}
	for _, r := range in.PQ {
		id, ok := ours(r.Ident, r.Peer)
		if !ok {
			skipped++
			continue
		}
		keptOf(id).PQ = true
	}
	ids := make([]devices.Key, 0, len(kept))
	for id := range kept {
		ids = append(ids, id)
	}
	slices.SortFunc(ids, func(a, b devices.Key) int { return bytes.Compare(a[:], b[:]) })
	for _, id := range ids {
		if _, err := d.book.Restore(*kept[id], d.v); err != nil {
			skipped++
			k := *kept[id]
			k.List, k.Proven = nil, nil
			if _, err := d.book.Restore(k, d.v); err != nil {
				skipped++
			}
		}
	}
	for _, r := range in.Quiet {
		id, ok := ours(r.Ident, r.Peer)
		key, kerr := parseHexKey(r.Key)
		if !ok || kerr != nil || r.Device < devices.PhoneID || r.Device > devices.MaxID {
			skipped++
			continue
		}
		d.quiet.Restore(devices.QuietKept{
			Identity: id, Device: uint8(r.Device), Key: key,
			First: fromMs(r.FirstAt), Session: fromMs(r.RebuiltAt), Probed: fromMs(r.ProbeAt),
			Silent: r.Silent != 0, Under: r.Under,
		})
	}
	return d.book.Claimants(), skipped
}

// contacts whose rows went back into a vault that shut: out of the state
// held, with no row written. one in a.Keep is held again as a bare
// contact, as a key-only row on the everyday side holds them
func (d *devState) dropPeers(a *devArgs, out *devOut) error {
	keep := map[devices.Key]bool{}
	for _, h := range a.Keep {
		id, err := parseHexKey(h)
		if err != nil {
			return err
		}
		keep[id] = true
	}
	for _, h := range a.Peers {
		id, err := parseHexKey(h)
		if err != nil {
			return err
		}
		ident, ok := d.peers[id]
		if !ok {
			continue
		}
		d.book.Forget(id)
		for _, dev := range d.quiet.Slots(id) {
			d.quiet.Forget(id, dev)
		}
		delete(d.peers, id)
		if keep[id] {
			if _, err := d.book.Add(id); err == nil {
				d.peers[id] = ident
			}
		}
	}
	out.Claimants = keysOut(d.book.Claimants())
	return nil
}
