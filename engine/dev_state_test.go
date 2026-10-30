// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"sort"
	"strings"
	"testing"
	"time"

	"github.com/halo/engine/devices"
	"github.com/halo/engine/kshim"
)

// the shim build-host.sh leaves, or the one KRYFO_SIGNAL_LIB names
func devTestShim(t *testing.T) *kshim.Lib {
	t.Helper()
	p := os.Getenv("KRYFO_SIGNAL_LIB")
	if p == "" {
		p, _ = filepath.Abs("../mobile/native/kryfo_signal/target/release/libkryfo_signal.so")
	}
	if _, err := os.Stat(p); err != nil {
		t.Skip("libkryfo_signal not built: run mobile/native/kryfo_signal/build-host.sh or set KRYFO_SIGNAL_LIB")
	}
	if err := devOpenShim(p); err != nil {
		t.Fatal(err)
	}
	devMu.Lock()
	defer devMu.Unlock()
	return devShim
}

// an identity in the shim, signing with ks_sign
type devSigner struct {
	l    *kshim.Lib
	pair []byte
	pub  devices.Key
}

func newDevSigner(t *testing.T, l *kshim.Lib) *devSigner {
	t.Helper()
	o, code, err := l.Call("ks_identity_generate")
	if err != nil || code != 0 || len(o) != 2 {
		t.Fatalf("identity: %v %d", err, code)
	}
	pub, err := devices.ParseKey(o[1])
	if err != nil {
		t.Fatal(err)
	}
	return &devSigner{l: l, pair: o[0], pub: pub}
}

func (s *devSigner) Public() devices.Key { return s.pub }

func (s *devSigner) Sign(context string, body []byte) ([]byte, error) {
	o, code, err := s.l.Call("ks_sign", s.pair, []byte(context), body)
	if err != nil || code != 0 || len(o) != 1 {
		return nil, fmt.Errorf("sign refused: %d", code)
	}
	return o[0], nil
}

// an identity's list as its phone keeps it, signed through the shim
type devAcct struct {
	id   *devSigner
	list *devices.List
	wire []byte
}

func newDevAcct(t *testing.T, l *kshim.Lib) *devAcct {
	t.Helper()
	a := &devAcct{id: newDevSigner(t, l)}
	g, err := devices.Genesis(a.id.pub, 4321, rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	a.set(t, g, nil)
	return a
}

func (a *devAcct) set(t *testing.T, l *devices.List, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
	if a.wire, err = l.Sign(a.id); err != nil {
		t.Fatal(err)
	}
	a.list = l
}

func (a *devAcct) link(t *testing.T, key devices.Key, answers bool) devices.Entry {
	t.Helper()
	e, err := devices.EntryFor(a.list, devices.DeviceKeys{Identity: a.id.pub, Key: key, Reg: 900 + uint32(len(a.list.Devices))}, rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	e.Answers = answers
	n, err := a.list.Add(e, rand.Reader)
	a.set(t, n, err)
	return e
}

// the app's tables, as the rows say: a put writes over the row with its
// key, a delete takes every row matching what it names
type devFakeDB struct {
	order  map[string][]string
	tables map[string]map[string]map[string]any
}

var devPKs = map[string][]string{
	"dev_lists":  {"ident", "owner"},
	"dev_proven": {"ident", "peer", "key"},
	"dev_pq":     {"ident", "peer"},
	"dev_quiet":  {"ident", "peer", "device"},
	"dev_pool":   {"ident", "device", "kyber_id"},
}

func newDevFakeDB() *devFakeDB {
	return &devFakeDB{order: map[string][]string{}, tables: map[string]map[string]map[string]any{}}
}

func (f *devFakeDB) apply(t *testing.T, answer string) map[string]any {
	t.Helper()
	var out struct {
		Rows []devOp `json:"rows"`
	}
	if err := json.Unmarshal([]byte(answer), &out); err != nil {
		t.Fatal(err)
	}
	var all map[string]any
	json.Unmarshal([]byte(answer), &all)
	for _, op := range out.Rows {
		pk, ok := devPKs[op.T]
		if !ok {
			t.Fatalf("a row for %s", op.T)
		}
		tb := f.tables[op.T]
		if tb == nil {
			tb = map[string]map[string]any{}
			f.tables[op.T] = tb
		}
		if op.Put != nil {
			var parts []string
			for _, c := range pk {
				v, ok := op.Put[c]
				if !ok {
					t.Fatalf("%s put without %s", op.T, c)
				}
				parts = append(parts, fmt.Sprint(v))
			}
			k := strings.Join(parts, "/")
			if tb[k] == nil {
				f.order[op.T] = append(f.order[op.T], k)
				tb[k] = map[string]any{}
			}
			for c, v := range op.Put {
				tb[k][c] = v
			}
			continue
		}
		for k, r := range tb {
			match := true
			for c, v := range op.Del {
				if fmt.Sprint(r[c]) != fmt.Sprint(v) {
					match = false
				}
			}
			if match {
				delete(tb, k)
				f.order[op.T] = slices.DeleteFunc(f.order[op.T], func(s string) bool { return s == k })
			}
		}
	}
	return all
}

func (f *devFakeDB) count(table string) int { return len(f.tables[table]) }

// the load the app makes from its tables
func (f *devFakeDB) load(t *testing.T, mine, contacts []map[string]any) string {
	t.Helper()
	in := map[string]any{"mine": mine, "contacts": contacts}
	for tb := range devPKs {
		rows := []map[string]any{}
		for _, k := range f.order[tb] {
			rows = append(rows, f.tables[tb][k])
		}
		in[tb] = rows
	}
	b, err := json.Marshal(in)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func devJSON(t *testing.T, v map[string]any) string {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func devBundle(t *testing.T, e devices.Entry, kyber uint32) []byte {
	t.Helper()
	var spk devices.Key
	spk[0] = 0x05
	spk[1] = 9
	b := &devices.Block{
		Reg: e.Reg, Device: e.ID, HasKey: true, Key: e.Key,
		SpkID: 7, Spk: spk, SpkSig: bytes.Repeat([]byte{0x5a}, devices.SigSize),
		KyberID:  kyber,
		Kyber:    append([]byte{0x08}, bytes.Repeat([]byte{0x33}, devices.KyberSize-1)...),
		KyberSig: bytes.Repeat([]byte{0x6b}, devices.SigSize),
	}
	w, err := devices.EncodeBundle(b)
	if err != nil {
		t.Fatal(err)
	}
	return w
}

func devErr(t *testing.T, answer string) string {
	t.Helper()
	var out devOut
	if err := json.Unmarshal([]byte(answer), &out); err != nil {
		t.Fatal(err)
	}
	return out.Err
}

func mustOK(t *testing.T, answer string) {
	t.Helper()
	if e := devErr(t, answer); e != "" {
		t.Fatalf("%s: %s", e, answer)
	}
}

// a phone with a linked computer and three contacts writes its rows, stops,
// and comes back from them: everything held is what it was, and it goes on
// the same way
func TestDeviceStateComesBackAfterARestart(t *testing.T) {
	l := devTestShim(t)
	me, bob, carol, dan := newDevAcct(t, l), newDevAcct(t, l), newDevAcct(t, l), newDevAcct(t, l)
	desk := me.link(t, newDevSigner(t, l).pub, false)
	bobDesk := bob.link(t, newDevSigner(t, l).pub, false)
	bobTab := bob.link(t, newDevSigner(t, l).pub, false)
	carol.link(t, newDevSigner(t, l).pub, true)
	db := newDevFakeDB()
	mine := []map[string]any{{"ident": 0, "identity": hexKey(me.id.pub), "key": hexKey(me.id.pub)}}
	contacts := []map[string]any{
		{"ident": 0, "identity": hexKey(bob.id.pub)},
		{"ident": 0, "identity": hexKey(carol.id.pub)},
	}
	mustOK(t, devCallJSON("load", db.load(t, mine, contacts)))
	t0 := time.Unix(1_760_000_000, 0)
	at := func(d time.Duration) int64 { return t0.Add(d).UnixMilli() }
	run := func(session bool, op string, args map[string]any) map[string]any {
		t.Helper()
		var a string
		if session {
			a = devSessionJSON(op, devJSON(t, args))
		} else {
			a = devCallJSON(op, devJSON(t, args))
		}
		mustOK(t, a)
		return db.apply(t, a)
	}
	run(true, "own_mine", map[string]any{"ident": 0, "list": me.wire})
	run(true, "accept", map[string]any{"identity": hexKey(bob.id.pub), "list": bob.wire, "remote": hexKey(bob.id.pub)})
	run(true, "opened", map[string]any{"ident": 0, "identity": hexKey(bob.id.pub), "device": 1, "remote": hexKey(bob.id.pub), "pq": true})
	run(true, "opened", map[string]any{"ident": 0, "identity": hexKey(bob.id.pub), "device": int(bobDesk.ID), "remote": hexKey(bobDesk.Key)})
	run(false, "accept_invite", map[string]any{"identity": hexKey(carol.id.pub), "list": carol.wire})
	// dan writes first, and is added from his phone's session
	run(true, "opened", map[string]any{"ident": 0, "identity": hexKey(dan.id.pub), "device": 1, "remote": hexKey(dan.id.pub)})
	contacts = append(contacts, map[string]any{"ident": 0, "identity": hexKey(dan.id.pub)})
	run(false, "quiet", map[string]any{"op": "sent", "identity": hexKey(bob.id.pub), "device": int(bobTab.ID), "key": hexKey(bobTab.Key), "now": at(0)})
	run(false, "quiet", map[string]any{"op": "sent", "identity": hexKey(me.id.pub), "device": int(desk.ID), "key": hexKey(desk.Key), "now": at(time.Hour)})
	var once []any
	for i := range 5 {
		once = append(once, devBundle(t, desk, uint32(100+i)))
	}
	run(false, "pool_put", map[string]any{"ident": 0, "device": int(desk.ID), "once": once, "last": devBundle(t, desk, 1), "made": at(-time.Hour), "now": at(0)})
	took := run(false, "pool_take", map[string]any{"ident": 0, "device": int(desk.ID), "now": at(time.Minute)})
	fan := run(false, "fanout", map[string]any{"ident": 0, "contact": hexKey(bob.id.pub), "devices": true, "now": at(16 * 24 * time.Hour)})
	if n := len(fan["slots"].([]any)); n != 4 {
		t.Fatalf("slots: %d", n)
	}
	if db.count("dev_lists") != 3 || db.count("dev_proven") != 1 || db.count("dev_pq") != 1 || db.count("dev_quiet") != 2 || db.count("dev_pool") != 6 {
		t.Fatalf("rows: %v", db.tables)
	}

	old := devNow()
	mustOK(t, devCallJSON("load", db.load(t, mine, contacts)))
	cur := devNow()
	if cur == old {
		t.Fatal("not loaded afresh")
	}
	for _, id := range []devices.Key{bob.id.pub, carol.id.pub, dan.id.pub} {
		a, okA := old.book.Kept(id)
		b, okB := cur.book.Kept(id)
		if okA != okB || !bytes.Equal(a.List, b.List) || a.FromInvite != b.FromInvite || a.PQ != b.PQ || !slices.Equal(a.Proven, b.Proven) {
			t.Fatalf("contact %x: %+v, was %+v", id[:4], b, a)
		}
	}
	ownA, _ := old.own.Kept(me.id.pub)
	ownB, _ := cur.own.Kept(me.id.pub)
	if !bytes.Equal(ownA.List, ownB.List) || ownA.Mine != ownB.Mine {
		t.Fatal("own list")
	}
	for _, s := range []struct {
		id  devices.Key
		dev uint8
	}{{bob.id.pub, bobTab.ID}, {me.id.pub, desk.ID}} {
		a, _ := old.quiet.Kept(s.id, s.dev)
		b, ok := cur.quiet.Kept(s.id, s.dev)
		if !ok || a.Key != b.Key || !a.First.Equal(b.First) || !a.Session.Equal(b.Session) || !a.Probed.Equal(b.Probed) || a.Silent != b.Silent || a.Under != b.Under {
			t.Fatalf("quiet %d: %+v, was %+v", s.dev, b, a)
		}
	}
	pa, _ := old.pool.Kept(me.id.pub, desk.ID)
	pb, _ := cur.pool.Kept(me.id.pub, desk.ID)
	if pa.Entry != pb.Entry || len(pa.Bundles) != len(pb.Bundles) {
		t.Fatalf("pool: %d bundles, was %d", len(pb.Bundles), len(pa.Bundles))
	}
	for i := range pa.Bundles {
		x, y := pa.Bundles[i], pb.Bundles[i]
		if x.Kyber != y.Kyber || x.Last != y.Last || !x.At.Equal(y.At) || !bytes.Equal(x.KDB1, y.KDB1) {
			t.Fatalf("pool bundle %d", i)
		}
	}
	// and it goes on as it would have
	if !cur.book.PQ(bob.id.pub) {
		t.Fatal("pq lost")
	}
	a := devCallJSON("fanout", devJSON(t, map[string]any{"ident": 0, "contact": hexKey(bob.id.pub), "devices": true, "phone_classic": true, "now": at(17 * 24 * time.Hour)}))
	if devErr(t, a) != "classic" {
		t.Fatalf("a classic phone session after pq: %s", a)
	}
	again := devCallJSON("pool_put", devJSON(t, map[string]any{"ident": 0, "device": int(desk.ID), "once": []any{took["kdb1"]}, "now": at(time.Hour)}))
	if devErr(t, again) != "duplicate" {
		t.Fatalf("a handed out bundle again: %s", again)
	}
	next := run(false, "pool_take", map[string]any{"ident": 0, "device": int(desk.ID), "now": at(2 * time.Minute)})
	if next["kdb1"] == took["kdb1"] {
		t.Fatal("the same bundle twice")
	}
	if devErr(t, devSessionJSON("opened", devJSON(t, map[string]any{"ident": 0, "identity": hexKey(bob.id.pub), "device": int(bobDesk.ID), "remote": hexKey(bobTab.Key)}))) != "not_its_key" {
		t.Fatal("bob's tablet's key opened as his desktop")
	}
	// forgetting a contact takes every row of it
	run(false, "forget", map[string]any{"identity": hexKey(bob.id.pub)})
	for tb := range devPKs {
		for _, r := range db.tables[tb] {
			if r["owner"] == hexKey(bob.id.pub) || r["peer"] == hexKey(bob.id.pub) {
				t.Fatalf("%s row of bob left", tb)
			}
		}
	}
}

// rows that no longer hold are left out at the start, and left where they
// are; nothing else is lost over them
func TestALoadSkipsWhatDoesNotHold(t *testing.T) {
	l := devTestShim(t)
	me, bob, eve := newDevAcct(t, l), newDevAcct(t, l), newDevAcct(t, l)
	bobDesk := bob.link(t, newDevSigner(t, l).pub, false)
	broken := bytes.Clone(bob.wire)
	broken[len(broken)-1] ^= 1
	in := map[string]any{
		"mine": []map[string]any{{"ident": 0, "identity": hexKey(me.id.pub)}},
		"contacts": []map[string]any{
			{"ident": 0, "identity": hexKey(bob.id.pub)},
			// my own key as a contact
			{"ident": 0, "identity": hexKey(me.id.pub)},
		},
		"dev_lists": []map[string]any{
			{"ident": 0, "owner": hexKey(bob.id.pub), "wire": broken},
			// eve is no contact
			{"ident": 0, "owner": hexKey(eve.id.pub), "wire": eve.wire},
			// bob's list as my own
			{"ident": 0, "owner": "me", "wire": bob.wire},
		},
		"dev_proven": []map[string]any{{"ident": 0, "peer": hexKey(bob.id.pub), "key": hexKey(bobDesk.Key)}},
		"dev_pq":     []map[string]any{{"ident": 0, "peer": hexKey(bob.id.pub)}, {"ident": 1, "peer": hexKey(bob.id.pub)}},
	}
	a := devCallJSON("load", devJSON(t, in))
	mustOK(t, a)
	var out devOut
	json.Unmarshal([]byte(a), &out)
	if out.Skipped != 5 || len(out.Rows) != 0 {
		t.Fatalf("skipped %d, rows %d", out.Skipped, len(out.Rows))
	}
	d := devNow()
	k, ok := d.book.Kept(bob.id.pub)
	if !ok || k.List != nil || !k.PQ || len(k.Proven) != 0 {
		t.Fatalf("bob after a broken list: %+v", k)
	}
	if d.own.Current(me.id.pub) != nil {
		t.Fatal("another identity's list taken as my own")
	}
	// with no shim open nothing loads, and the state held stays
	devMu.Lock()
	keep := devShim
	devShim = nil
	devMu.Unlock()
	if e := devErr(t, devCallJSON("load", devJSON(t, in))); e != "no_shim" {
		t.Fatalf("load without the shim: %s", e)
	}
	if devNow() != d {
		t.Fatal("the state went without a load")
	}
	devMu.Lock()
	devShim = keep
	devMu.Unlock()
}

// the session door: a contact's device key counts only on its own slot and
// only once its list names it; a phone's slot only on the identity
func TestOpenedAdmitsBeforeItProves(t *testing.T) {
	l := devTestShim(t)
	me, bob := newDevAcct(t, l), newDevAcct(t, l)
	stray := newDevSigner(t, l).pub
	mustOK(t, devCallJSON("load", devJSON(t, map[string]any{
		"mine": []map[string]any{{"ident": 0, "identity": hexKey(me.id.pub)}},
	})))
	opened := func(dev int, remote devices.Key, pq bool) string {
		return devErr(t, devSessionJSON("opened", devJSON(t, map[string]any{
			"ident": 0, "identity": hexKey(bob.id.pub), "device": dev, "remote": hexKey(remote), "pq": pq,
		})))
	}
	// a device of a contact not held never adds it
	if e := opened(5, stray, false); e != "unknown" {
		t.Fatalf("an unknown contact's device: %s", e)
	}
	if e := opened(1, stray, true); e != "unknown" {
		t.Fatalf("a phone slot on another key: %s", e)
	}
	if devNow().book.PQ(bob.id.pub) {
		t.Fatal("pq noted for a refused open")
	}
	if e := opened(1, bob.id.pub, false); e != "" {
		t.Fatalf("bob's phone: %s", e)
	}
	if e := opened(1, stray, true); e != "not_its_key" || devNow().book.PQ(bob.id.pub) {
		t.Fatalf("the phone slot on a stray key: %s", e)
	}
	if e := opened(7, stray, false); e != "not_listed" {
		t.Fatalf("an unlisted device: %s", e)
	}
	// my own identity is never a contact here
	if e := devErr(t, devSessionJSON("opened", devJSON(t, map[string]any{"ident": 0, "identity": hexKey(me.id.pub), "device": 1, "remote": hexKey(me.id.pub)}))); e != "self" {
		t.Fatalf("my own identity: %s", e)
	}
	// nor under two of my identities
	if e := devErr(t, devSessionJSON("opened", devJSON(t, map[string]any{"ident": 3, "identity": hexKey(bob.id.pub), "device": 1, "remote": hexKey(bob.id.pub)}))); e != "taken" {
		t.Fatalf("bob under another identity: %s", e)
	}
	// a linked device's own list never comes as the phone's own
	mustOK(t, devCallJSON("load", devJSON(t, map[string]any{
		"mine": []map[string]any{{"ident": 0, "identity": hexKey(me.id.pub), "key": hexKey(stray)}},
	})))
	if e := devErr(t, devSessionJSON("own_mine", devJSON(t, map[string]any{"ident": 0, "list": me.wire}))); e != "source" {
		t.Fatalf("own_mine on a linked device: %s", e)
	}
}

func TestDeviceKeysForTheAddressLayer(t *testing.T) {
	l := devTestShim(t)
	me, bob := newDevAcct(t, l), newDevAcct(t, l)
	desk := me.link(t, newDevSigner(t, l).pub, false)
	bobDesk := bob.link(t, newDevSigner(t, l).pub, false)
	mustOK(t, devCallJSON("load", devJSON(t, map[string]any{
		"mine":     []map[string]any{{"ident": 0, "identity": hexKey(me.id.pub)}},
		"contacts": []map[string]any{{"ident": 0, "identity": hexKey(bob.id.pub)}},
	})))
	mustOK(t, devSessionJSON("own_mine", devJSON(t, map[string]any{"ident": 0, "list": me.wire})))
	mustOK(t, devSessionJSON("accept", devJSON(t, map[string]any{"identity": hexKey(bob.id.pub), "list": bob.wire, "remote": hexKey(bob.id.pub)})))
	x := func(k devices.Key) (out [32]byte) { copy(out[:], k[1:]); return }
	var src devKeySource
	if k, ok := src.deviceKey(0, x(bob.id.pub), bobDesk.ID); !ok || k != x(bobDesk.Key) {
		t.Fatal("bob's desktop")
	}
	if k, ok := src.deviceKey(0, x(me.id.pub), desk.ID); !ok || k != x(desk.Key) {
		t.Fatal("my desktop")
	}
	if _, ok := src.deviceKey(1, x(bob.id.pub), bobDesk.ID); ok {
		t.Fatal("bob under another of my identities")
	}
	if _, ok := src.deviceKey(0, x(bob.id.pub), 99); ok {
		t.Fatal("an unlisted device")
	}
	keys := []string{}
	for _, e := range devErrNames {
		keys = append(keys, e.name)
	}
	sort.Strings(keys)
	if len(slices.Compact(keys)) != len(devErrNames) {
		t.Fatal("two errors share a name")
	}
	if devErrName(errors.New("x")) != "error" {
		t.Fatal("an unnamed error")
	}
}
