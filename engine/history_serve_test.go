// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bufio"
	"context"
	"crypto/ecdh"
	"crypto/rand"
	"encoding/hex"
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/halo/engine/devices"
)

const histTestOnion = "abcdefghijklmnopqrstuvwxyz234567abcdefghijklmnopqrstuvwx"

// the phone's door in this process: each dial is a pipe into handleConn
func histDoorHere(t *testing.T) {
	t.Helper()
	was := histDialNow
	histDialNow = func(ctx context.Context, onion string) (net.Conn, error) {
		if onion != histTestOnion {
			return nil, errLinkUnreached
		}
		a, b := net.Pipe()
		go handleConn(b)
		return a, nil
	}
	t.Cleanup(func() {
		histDialNow = was
		histCli.Lock()
		histDropConn()
		histCli.Unlock()
	})
}

type histPhone struct {
	key    *[devices.StreamKeySize]byte
	bind   [32]byte
	id     devices.Key
	tag    string
	handle int64
	send   *devices.Sender
}

func histIdentity() devices.Key {
	p, _ := ecdh.X25519().GenerateKey(rand.Reader)
	var id devices.Key
	id[0] = 5
	copy(id[1:], p.PublicKey().Bytes())
	return id
}

func (p *histPhone) args(extra func(*histServeArgs)) *histServeArgs {
	a := &histServeArgs{Key: hex.EncodeToString(p.key[:]), Bind: hex.EncodeToString(p.bind[:])}
	if extra != nil {
		extra(a)
	}
	return a
}

// the phone opens a copy of generation gen and serves a small history
func (p *histPhone) serve(t *testing.T, gen uint32) {
	t.Helper()
	out := &histServeOut{}
	if err := histServeCall("open", p.args(func(a *histServeArgs) { a.Gen = gen }), out); err != nil {
		t.Fatal(err)
	}
	p.tag = out.Tag
	k, err := hex.DecodeString(out.Key)
	if err != nil || len(k) != devices.StreamKeySize {
		t.Fatal("no key for the sender")
	}
	var gk [devices.StreamKeySize]byte
	copy(gk[:], k)
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "a.jpg"), make([]byte, 3000), 0o600)
	s, err := devices.NewSender(&gk, p.bind, p.id, devices.SendOptions{Spool: filepath.Join(dir, "spool"), Root: dir, Chunk: devices.MinChunk})
	if err != nil {
		t.Fatal(err)
	}
	s.Chat([]byte(`{"halo_id":"a"}`))
	s.Message([]byte(`{"plaintext":"hi"}`))
	s.Media(0, 1, "a.jpg")
	if err := s.Plan(); err != nil {
		t.Fatal(err)
	}
	p.send = s
	p.handle = int64(histAdd(s, nil))
	t.Cleanup(func() { histSendClose(p.handle) })
	if err := histServeCall("serve", &histServeArgs{Tag: p.tag, Send: p.handle, Gen: gen}, &histServeOut{}); err != nil {
		t.Fatal(err)
	}
}

func (p *histPhone) state(t *testing.T) *histServeOut {
	t.Helper()
	out := &histServeOut{}
	if err := histServeCall("state", &histServeArgs{Tag: p.tag}, out); err != nil {
		t.Fatal(err)
	}
	return out
}

func (p *histPhone) fetch(t *testing.T, op string, extra func(*histServeArgs)) *histServeOut {
	t.Helper()
	out := &histServeOut{}
	a := p.args(extra)
	a.Onion = histTestOnion
	if err := histFetchCall(op, a, out); err != nil {
		t.Fatalf("%s: %v", op, err)
	}
	return out
}

func newHistPhone(t *testing.T) *histPhone {
	key, _ := devices.NewStreamKey()
	p := &histPhone{key: key, id: histIdentity()}
	rand.Read(p.bind[:])
	t.Cleanup(func() {
		histServeCall("drop", &histServeArgs{Tag: p.tag}, &histServeOut{})
	})
	return p
}

// the whole copy over the door: the hello names the sender, each record
// comes as the sender sealed it, and the tally comes back
func TestAHistoryCopyOverThePhonesDoor(t *testing.T) {
	histDoorHere(t)
	p := newHistPhone(t)
	// before the sender is made, the device hears it is being made
	out := &histServeOut{}
	if err := histServeCall("open", p.args(nil), out); err != nil {
		t.Fatal(err)
	}
	p.tag = out.Tag
	if h := p.fetch(t, "hello", nil); h.Why != histWhyMaking {
		t.Fatalf("hello while making: %+v", h)
	}
	p.serve(t, 0)
	h := p.fetch(t, "hello", nil)
	sid := p.send.ID()
	if h.Why != "" || h.ID != hex.EncodeToString(sid[:]) || h.Gen != 0 || h.Key != hex.EncodeToString(p.key[:]) {
		t.Fatalf("hello: %+v", h)
	}
	r, err := devices.NewReceiver(p.key, p.bind, sid, p.id)
	if err != nil {
		t.Fatal(err)
	}
	head, _ := p.send.Head()
	for i := uint64(0); i < head.Records; i++ {
		got := p.fetch(t, "rec", func(a *histServeArgs) { a.I = i })
		want, _ := p.send.Record(i)
		if string(got.Rec) != string(want) {
			t.Fatalf("record %d is not the sender's", i)
		}
		if _, err := r.Take(got.Rec); err != nil {
			t.Fatalf("record %d: %v", i, err)
		}
	}
	if !r.Done() {
		t.Fatal("not whole")
	}
	if st := p.state(t); st.Asked != head.Records || st.Tally != nil {
		t.Fatalf("state before the tally: %+v", st)
	}
	counts := []devices.Count{{Messages: 1, Media: 1, MediaBytes: 3000}}
	tally, err := r.Tally(counts)
	if err != nil {
		t.Fatal(err)
	}
	if !p.fetch(t, "tally", func(a *histServeArgs) { a.Tally = tally }).Ok {
		t.Fatal("tally not taken")
	}
	st := p.state(t)
	if string(st.Tally) != string(tally) {
		t.Fatal("the phone holds another tally")
	}
	if mm, err := p.send.CheckTally(st.Tally); err != nil || len(mm) != 0 {
		t.Fatalf("check: %v %v", mm, err)
	}
	// past the end, nothing
	if got := p.fetch(t, "rec", func(a *histServeArgs) { a.I = head.Records }); got.Why != histWhyNone {
		t.Fatalf("past the end: %+v", got)
	}
	// ended by a hide: every ask hears it, and no record goes
	histServeCall("end", &histServeArgs{Tag: p.tag, Why: histWhyEnded}, &histServeOut{})
	if got := p.fetch(t, "rec", func(a *histServeArgs) { a.I = 1 }); got.Why != histWhyEnded || got.Rec != nil {
		t.Fatalf("after a hide: %+v", got)
	}
	if got := p.fetch(t, "hello", nil); got.Why != histWhyEnded {
		t.Fatalf("hello after a hide: %+v", got)
	}
}

// a big tally goes in lines and is whole only once every line came
func TestABigTallyComesInLines(t *testing.T) {
	histDoorHere(t)
	p := newHistPhone(t)
	p.serve(t, 0)
	big := make([]byte, 3*histTallyChunk+5)
	rand.Read(big)
	if !p.fetch(t, "tally", func(a *histServeArgs) { a.Tally = big }).Ok {
		t.Fatal("not taken")
	}
	if string(p.state(t).Tally) != string(big) {
		t.Fatal("the tally came otherwise")
	}
}

// a copy made again after the phone's app restarted runs on a key of its
// own generation, in the same process too, and the hello says which
func TestACopyMadeAgainHasItsOwnGeneration(t *testing.T) {
	histDoorHere(t)
	p := newHistPhone(t)
	p.serve(t, 0)
	first := p.send.ID()
	histSendClose(p.handle)
	p.serve(t, 3)
	h := p.fetch(t, "hello", nil)
	g3, _ := devices.AgainKey(p.key, p.bind, 3)
	sid := p.send.ID()
	if h.Gen != 3 || h.ID != hex.EncodeToString(sid[:]) || h.Key != hex.EncodeToString(g3[:]) || sid == first {
		t.Fatalf("hello again: %+v", h)
	}
	// the new generation's records open only under its key
	rec := p.fetch(t, "rec", nil).Rec
	if r, _ := devices.NewReceiver(p.key, p.bind, sid, p.id); r != nil {
		if _, err := r.Take(rec); err == nil {
			t.Fatal("generation 3's head opened under the link's key")
		}
	}
	r, _ := devices.NewReceiver(g3, p.bind, sid, p.id)
	if _, err := r.Take(rec); err != nil {
		t.Fatalf("generation 3's head: %v", err)
	}
}

// an ask whose mac or tag does not hold is no history line: the door reads
// it as any line that is not a message, answers nothing and shuts
func TestAStrangersAskGetsNothing(t *testing.T) {
	p := newHistPhone(t)
	p.serve(t, 0)
	ask, _ := devices.AskFor(p.key, p.bind)
	good := histAskLine(ask, "rec", "1")
	if ans, ok := histDoorTake(good); !ok || !strings.HasPrefix(ans, histAnswerYes+" ") {
		t.Fatalf("the device's own ask: %q %v", ans, ok)
	}
	otherKey, _ := devices.NewStreamKey()
	stranger, _ := devices.AskFor(otherKey, p.bind)
	f := strings.Fields(good)
	for _, line := range []string{
		histAskLine(stranger, "rec", "1"),
		// the right tag, another key's mac
		histAskPrefix + f[1] + " rec 1 " + strings.Fields(histAskLine(stranger, "rec", "1"))[4],
		// the mac of rec 1 on rec 2
		histAskPrefix + f[1] + " rec 2 " + f[4],
		histAskPrefix + f[1] + " rec 1",
		histAskPrefix + f[1] + " rec 1 " + f[4][:62],
		"KHQ2 " + strings.Join(f[1:], " "),
	} {
		if ans, ok := histDoorTake(line); ok {
			t.Fatalf("a stranger's ask answered: %q", ans)
		}
	}
	// through the real door: no answer, the stream shut
	a, b := net.Pipe()
	go handleConn(b)
	defer a.Close()
	a.SetDeadline(time.Now().Add(5 * time.Second))
	go a.Write([]byte(histAskLine(stranger, "rec", "1") + "\n"))
	if line, err := bufio.NewReader(a).ReadString('\n'); err == nil {
		t.Fatalf("the door answered a stranger: %q", line)
	}
	// with no copy open at all an ask is junk too
	histServeCall("drop", &histServeArgs{Tag: p.tag}, &histServeOut{})
	if _, ok := histDoorTake(good); ok {
		t.Fatal("an ask answered with no copy open")
	}
}

// an onion that is not one is never dialed
func TestTheDeviceAsksOnlyAnOnion(t *testing.T) {
	dialed := false
	was := histDialNow
	histDialNow = func(context.Context, string) (net.Conn, error) { dialed = true; return nil, errLinkUnreached }
	defer func() { histDialNow = was }()
	p := newHistPhone(t)
	for _, o := range []string{"", "example.com", histTestOnion + "a", strings.ToUpper(histTestOnion), histTestOnion[:55] + "/"} {
		a := p.args(nil)
		a.Onion = o
		if err := histFetchCall("hello", a, &histServeOut{}); err == nil {
			t.Fatalf("asked %q", o)
		}
	}
	if dialed {
		t.Fatal("dialed a name that is not an onion")
	}
}
