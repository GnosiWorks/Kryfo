// SPDX-License-Identifier: GPL-3.0-or-later
package main

import "C"

import (
	"encoding/json"
	"errors"
	"time"

	"github.com/halo/engine/devices"
	"github.com/halo/engine/kshim"
)

// the linked-devices calls for dart: json in, json out. every answer that
// changes the state carries "rows", to write in order before anything is
// sent. calls that name a session's remote are in dev_session.go.

type devEntry struct {
	ID      int    `json:"id"`
	Key     string `json:"key"`
	Reg     uint32 `json:"reg"`
	Phone   bool   `json:"phone,omitempty"`
	Answers bool   `json:"answers,omitempty"`
}

type devSlot struct {
	Identity string `json:"identity"`
	Device   int    `json:"device"`
	Key      string `json:"key"`
	Reg      uint32 `json:"reg"`
	Own      bool   `json:"own,omitempty"`
	Rebuild  bool   `json:"rebuild,omitempty"`
}

type devBlock struct {
	Device  int    `json:"device"`
	Reg     uint32 `json:"reg"`
	Key     string `json:"key,omitempty"`
	SpkID   uint32 `json:"spk_id"`
	KyberID uint32 `json:"kyber_id"`
}

type devOut struct {
	Err       string     `json:"err,omitempty"`
	Rows      []devOp    `json:"rows"`
	Claimants []string   `json:"claimants,omitempty"`
	Outcome   string     `json:"outcome,omitempty"`
	Held      []byte     `json:"held,omitempty"`
	Gone      []devEntry `json:"gone,omitempty"`
	Devices   []devEntry `json:"devices,omitempty"`
	Slots     []devSlot  `json:"slots,omitempty"`
	KDB1      []byte     `json:"kdb1,omitempty"`
	Low       bool       `json:"low,omitempty"`
	Need      int        `json:"need,omitempty"`
	Fresh     bool       `json:"fresh,omitempty"`
	Block     *devBlock  `json:"block,omitempty"`
	Stale     []int      `json:"stale,omitempty"`
	Key       string     `json:"key,omitempty"`
	List      []byte     `json:"list,omitempty"`
	Skipped   int        `json:"skipped,omitempty"`
}

// the error names dart sees
var devErrNames = []struct {
	err  error
	name string
}{
	{devices.ErrRollback, "rollback"},
	{devices.ErrEquivocation, "equivocation"},
	{devices.ErrJump, "jump"},
	{devices.ErrSource, "source"},
	{devices.ErrTaken, "taken"},
	{devices.ErrUnknown, "unknown"},
	{devices.ErrSignature, "signature"},
	{devices.ErrWrongIdentity, "identity"},
	{devices.ErrNotListed, "not_listed"},
	{devices.ErrNotItsKey, "not_its_key"},
	{devices.ErrSelf, "self"},
	{devices.ErrRemoved, "removed"},
	{devices.ErrClassic, "classic"},
	{devices.ErrNoBundle, "no_bundle"},
	{devices.ErrOldKeys, "old_keys"},
	{devices.ErrDuplicate, "duplicate"},
	{devices.ErrTooMany, "too_many"},
	{devices.ErrPhone, "phone"},
	{devices.ErrMalformed, "malformed"},
	{errNoShim, "no_shim"},
}

func devErrName(err error) string {
	for _, e := range devErrNames {
		if errors.Is(err, e.err) {
			return e.name
		}
	}
	return "error"
}

func entryOut(e devices.Entry) devEntry {
	return devEntry{ID: int(e.ID), Key: hexKey(e.Key), Reg: e.Reg, Phone: e.Phone, Answers: e.Answers}
}

func keysOut(ks []devices.Key) []string {
	out := make([]string, 0, len(ks))
	for _, k := range ks {
		out = append(out, hexKey(k))
	}
	return out
}

func outcomeName(o devices.Outcome) string {
	switch o {
	case devices.First:
		return "first"
	case devices.Changed:
		return "changed"
	}
	return "same"
}

func devAnswer(out *devOut, err error) string {
	if err != nil {
		out.Err = devErrName(err)
		var rb *devices.RollbackError
		if errors.As(err, &rb) {
			out.Held = rb.Held
		}
	}
	if out.Rows == nil {
		out.Rows = []devOp{}
	}
	b, jerr := json.Marshal(out)
	if jerr != nil {
		return `{"err":"error","rows":[]}`
	}
	return string(b)
}

// the args every call may carry
type devArgs struct {
	Ident        int      `json:"ident"`
	Identity     string   `json:"identity"`
	Device       int      `json:"device"`
	Key          string   `json:"key"`
	Remote       string   `json:"remote"`
	Reg          uint32   `json:"reg"`
	Opener       bool     `json:"opener"`
	Own          bool     `json:"own"`
	List         []byte   `json:"list"`
	KDB1         []byte   `json:"kdb1"`
	Once         [][]byte `json:"once"`
	Last         []byte   `json:"last"`
	Made         int64    `json:"made"`
	Now          int64    `json:"now"`
	Op           string   `json:"op"`
	Devices      bool     `json:"devices"`
	PhoneClassic bool     `json:"phone_classic"`
	PQ           bool     `json:"pq"`
	Contact      string   `json:"contact"`
	Held         []struct {
		ID  int    `json:"id"`
		Key string `json:"key"`
	} `json:"held"`
}

func (a *devArgs) identity() (devices.Key, error) { return parseHexKey(a.Identity) }

func (a *devArgs) device() (uint8, error) {
	if a.Device < devices.PhoneID || a.Device > devices.MaxID {
		return 0, devices.ErrMalformed
	}
	return uint8(a.Device), nil
}

func (a *devArgs) now() time.Time { return time.UnixMilli(a.Now) }

// opens the shim at path, the name or path the app loaded it by. the
// state already held keeps its verifier until the next load
//
//export HaloDevShim
func HaloDevShim(cPath *C.char) *C.char {
	if err := devOpenShim(goStr(cPath)); err != nil {
		return C.CString("error: " + err.Error())
	}
	return C.CString("ok")
}

func devOpenShim(path string) error {
	l, err := kshim.Open(path)
	if err != nil {
		return err
	}
	devMu.Lock()
	devShim = l
	devMu.Unlock()
	return nil
}

var devShim *kshim.Lib

// HaloDevCall runs one linked-devices call: op, and its args as json.
//
//export HaloDevCall
func HaloDevCall(cOp, cArgs *C.char) *C.char {
	return C.CString(devCallJSON(goStr(cOp), goStr(cArgs)))
}

func devCallJSON(op, raw string) string {
	out := &devOut{}
	if op == "load" {
		var in devLoad
		if err := json.Unmarshal([]byte(raw), &in); err != nil {
			return devAnswer(out, devices.ErrMalformed)
		}
		devMu.Lock()
		defer devMu.Unlock()
		d, claimants, skipped, err := loadDevState(&in, devVerifier{devShim})
		if err != nil {
			return devAnswer(out, err)
		}
		devCur = d
		out.Claimants, out.Skipped = keysOut(claimants), skipped
		return devAnswer(out, nil)
	}
	var a devArgs
	if err := json.Unmarshal([]byte(raw), &a); err != nil {
		return devAnswer(out, devices.ErrMalformed)
	}
	d := devNow()
	d.mu.Lock()
	defer d.mu.Unlock()
	return devAnswer(out, d.call(op, &a, out))
}

func (d *devState) call(op string, a *devArgs, out *devOut) error {
	switch op {
	case "add":
		return d.add(a, out)
	case "forget":
		return d.forget(a, out)
	case "accept_invite":
		id, err := a.identity()
		if err != nil {
			return err
		}
		return d.accept(id, a.List, devices.FromInvite(), out)
	case "fanout":
		return d.fanout(a, out)
	case "quiet":
		return d.quietCall(a, out)
	case "pool_put", "pool_take", "pool_need", "pool_drop":
		return d.poolCall(op, a, out)
	case "admit":
		return d.admit(a)
	case "stale":
		return d.stale(a, out)
	case "current":
		return d.current(a, out)
	case "pin":
		id, err := a.identity()
		if err != nil {
			return err
		}
		dev, err := a.device()
		if err != nil {
			return err
		}
		k, ok := d.book.Pin(id, dev)
		if !ok {
			return devices.ErrNotListed
		}
		out.Key = hexKey(k)
		return nil
	case "claimants":
		out.Claimants = keysOut(d.book.Claimants())
		return nil
	}
	return errors.New("no such call")
}

// a contact of my identity a.Ident, proven by its invite or a session
func (d *devState) add(a *devArgs, out *devOut) error {
	id, err := a.identity()
	if err != nil {
		return err
	}
	if _, mine := d.mine[id]; mine {
		return devices.ErrTaken
	}
	if i, ok := d.peers[id]; ok && i != a.Ident {
		return devices.ErrTaken
	}
	claimants, err := d.book.Add(id)
	if err != nil {
		return err
	}
	d.peers[id] = a.Ident
	out.Claimants = keysOut(claimants)
	return nil
}

// a contact deleted: everything held for it goes, rows too
func (d *devState) forget(a *devArgs, out *devOut) error {
	id, err := a.identity()
	if err != nil {
		return err
	}
	ident, ok := d.peers[id]
	if !ok {
		return devices.ErrUnknown
	}
	out.Claimants = keysOut(d.book.Forget(id))
	for _, dev := range d.quiet.Slots(id) {
		d.quiet.Forget(id, dev)
	}
	// every row of the contact, those that did not load too
	peer := hexKey(id)
	for _, t := range []string{"dev_lists", "dev_proven", "dev_pq", "dev_quiet"} {
		k := map[string]any{"ident": ident, "peer": peer}
		if t == "dev_lists" {
			k = map[string]any{"ident": ident, "owner": peer}
		}
		out.Rows = append(out.Rows, devOp{T: t, Del: k})
	}
	delete(d.peers, id)
	return nil
}

// a list for a contact, from where it came
func (d *devState) accept(id devices.Key, wire []byte, from devices.From, out *devOut) error {
	s := d.snap(id)
	_, o, claimants, err := d.book.Accept(id, wire, from, d.v)
	if err != nil {
		return err
	}
	out.Outcome, out.Claimants = outcomeName(o), keysOut(claimants)
	out.Rows = s.rows()
	return nil
}

func (d *devState) fanout(a *devArgs, out *devOut) error {
	mine, ok := d.idents[a.Ident]
	if !ok {
		return devices.ErrUnknown
	}
	contact, err := parseHexKey(a.Contact)
	if err != nil {
		return err
	}
	if i, ok := d.peers[contact]; !ok || i != a.Ident {
		return devices.ErrUnknown
	}
	sc, sm := d.snap(contact), d.snap(mine)
	f := &devices.Fanout{Book: d.book, Own: d.own, Quiet: d.quiet}
	slots, err := f.To(mine, contact, devices.Peer{Devices: a.Devices, PhoneClassic: a.PhoneClassic}, a.now())
	out.Rows = append(sc.rows(), sm.rows()...)
	if err != nil {
		return err
	}
	for _, s := range slots {
		out.Slots = append(out.Slots, devSlot{
			Identity: hexKey(s.Identity), Device: int(s.Device), Key: hexKey(s.Key),
			Reg: s.Reg, Own: s.Own, Rebuild: s.Rebuild,
		})
	}
	return nil
}

func (d *devState) quietCall(a *devArgs, out *devOut) error {
	id, err := a.identity()
	if err != nil {
		return err
	}
	if _, ok := d.identOf(id); !ok {
		return devices.ErrUnknown
	}
	dev, err := a.device()
	if err != nil {
		return err
	}
	s := d.snap(id)
	switch a.Op {
	case "sent", "fresh":
		key, err := parseHexKey(a.Key)
		if err != nil {
			return err
		}
		if a.Op == "sent" {
			d.quiet.Sent(id, dev, key, a.now())
		} else {
			out.Fresh = d.quiet.Fresh(id, dev, key)
		}
	case "heard":
		d.quiet.Heard(id, dev)
	case "rebuilt":
		d.quiet.Rebuilt(id, dev)
	case "forget":
		d.quiet.Forget(id, dev)
	default:
		return errors.New("no such quiet call")
	}
	out.Rows = s.rows()
	return nil
}

// the pool of my identity a.Ident's own device a.Device, as its own list
// names it now
func (d *devState) poolCall(op string, a *devArgs, out *devOut) error {
	mine, ok := d.idents[a.Ident]
	if !ok {
		return devices.ErrUnknown
	}
	dev, err := a.device()
	if err != nil {
		return err
	}
	s := d.snap(mine)
	defer func() { out.Rows = s.rows() }()
	if op == "pool_drop" {
		d.pool.Drop(mine, dev)
		return nil
	}
	l := d.own.Current(mine)
	if l == nil {
		return devices.ErrNotListed
	}
	e, ok := l.Find(dev)
	if !ok {
		return devices.ErrNotListed
	}
	switch op {
	case "pool_put":
		return d.pool.Put(mine, e, a.Once, a.Last, time.UnixMilli(a.Made), a.now())
	case "pool_take":
		b, low, err := d.pool.Take(mine, e, a.now())
		out.KDB1, out.Low = b, low
		return err
	}
	out.Need = d.pool.Need(mine, e, a.now())
	return nil
}

// whether a message that opened on a session with device a.Device of
// a.Identity (a contact's, or with a.Own one of mine) counts as theirs.
// remote is what ks_decrypt_* returned
func (d *devState) admit(a *devArgs) error {
	id, err := a.identity()
	if err != nil {
		return err
	}
	dev, err := a.device()
	if err != nil {
		return err
	}
	remote, err := parseHexKey(a.Remote)
	if err != nil {
		return err
	}
	switch {
	case a.Own && a.Opener:
		return d.own.AdmitOpener(id, dev, remote, a.Reg)
	case a.Own:
		return d.own.Admit(id, dev, remote)
	case a.Opener:
		return d.book.AdmitOpener(id, dev, remote, a.Reg)
	}
	return d.book.Admit(id, dev, remote)
}

func (d *devState) stale(a *devArgs, out *devOut) error {
	id, err := a.identity()
	if err != nil {
		return err
	}
	var held []devices.Held
	for _, h := range a.Held {
		k, err := parseHexKey(h.Key)
		if err != nil || h.ID < devices.PhoneID || h.ID > devices.MaxID {
			return devices.ErrMalformed
		}
		held = append(held, devices.Held{ID: uint8(h.ID), Key: k})
	}
	var ids []uint8
	if a.Own {
		ids = d.own.Stale(id, held)
	} else {
		ids = d.book.Stale(id, held)
	}
	out.Stale = []int{}
	for _, i := range ids {
		out.Stale = append(out.Stale, int(i))
	}
	return nil
}

// the list held: a contact's with a.Identity, else my identity a.Ident's
// own
func (d *devState) current(a *devArgs, out *devOut) error {
	var l *devices.List
	if a.Identity != "" {
		id, err := a.identity()
		if err != nil {
			return err
		}
		l = d.book.Current(id)
	} else if id, ok := d.idents[a.Ident]; ok {
		l = d.own.Current(id)
	}
	if l == nil {
		return devices.ErrNotListed
	}
	out.List = l.Wire()
	for _, e := range l.Devices {
		out.Devices = append(out.Devices, entryOut(e))
	}
	return nil
}
