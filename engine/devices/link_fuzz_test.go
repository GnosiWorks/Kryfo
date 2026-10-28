// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"crypto/mlkem"
	"testing"
)

func FuzzParseOfferText(f *testing.F) {
	k := fixedKey(f, 5)
	j, err := StartJoin(k, 1, t0)
	if err != nil {
		f.Fatal(err)
	}
	f.Add(j.OfferText())
	f.Add("kryfo-link:")
	f.Fuzz(func(t *testing.T, s string) {
		b, err := ParseOfferText(s)
		if err != nil {
			return
		}
		if len(b) != offerSize || string(b[:4]) != offerMagic {
			t.Fatalf("%q", s)
		}
	})
}

// link states made once and copied per run, since making them costs a
// key exchange and an ml-kem key pair each
func cloneJoiner(j *Joiner) *Joiner {
	c := *j
	c.nonce = bytes.Clone(j.nonce)
	c.offer = bytes.Clone(j.offer)
	c.dh = bytes.Clone(j.dh)
	c.kem = bytes.Clone(j.kem)
	return &c
}

func cloneLinker(p *Linker) *Linker {
	c := *p
	c.offer = bytes.Clone(p.offer)
	c.accept = bytes.Clone(p.accept)
	c.dh = bytes.Clone(p.dh)
	c.kem = bytes.Clone(p.kem)
	return &c
}

// the ml-kem parts are long and the fuzzer slows to a crawl on long inputs,
// so they stay fixed and take one changed byte; the short parts are fuzzed
// whole

// any answer: refused, or a reveal the phone cannot open
func FuzzAccept(f *testing.F) {
	k := fixedKey(f, 10)
	j, err := StartJoin(k, 1, t0)
	if err != nil {
		f.Fatal(err)
	}
	p, accept, err := AcceptOffer(j.Offer(), fixedKey(f, 9), t0)
	if err != nil {
		f.Fatal(err)
	}
	ek := accept[36:]
	f.Add(accept[:36], uint16(0), byte(0))
	f.Add(accept[:36], uint16(5), byte(0xff))
	f.Add([]byte(acceptMagic), uint16(0), byte(0))
	f.Fuzz(func(t *testing.T, head []byte, off uint16, val byte) {
		tail := bytes.Clone(ek)
		tail[int(off)%len(tail)] ^= val
		msg := append(bytes.Clone(head), tail...)
		jc := cloneJoiner(j)
		reveal, err := jc.HandleAccept(msg, t0)
		if err != nil {
			if _, err := jc.HandleAccept(accept, t0); err == nil {
				t.Fatal("a link went on after a bad answer")
			}
			return
		}
		if bytes.Equal(msg, accept) {
			return
		}
		if err := cloneLinker(p).HandleReveal(reveal, t0); err == nil {
			t.Fatal("a reveal after a changed answer was taken")
		}
	})
}

// any reveal ends the phone's side unless it is the one sealed
func FuzzReveal(f *testing.F) {
	k := fixedKey(f, 10)
	j, _ := StartJoin(k, 1, t0)
	p, accept, err := AcceptOffer(j.Offer(), fixedKey(f, 9), t0)
	if err != nil {
		f.Fatal(err)
	}
	reveal, err := j.HandleAccept(accept, t0)
	if err != nil {
		f.Fatal(err)
	}
	ctEnd := 4 + mlkem.CiphertextSize1024
	ct := reveal[4:ctEnd]
	f.Add([]byte(revealMagic), uint16(0), byte(0), reveal[ctEnd:])
	f.Add([]byte(revealMagic), uint16(9), byte(1), reveal[ctEnd:])
	f.Fuzz(func(t *testing.T, magic []byte, off uint16, val byte, sealed []byte) {
		c := bytes.Clone(ct)
		c[int(off)%len(c)] ^= val
		msg := append(append(bytes.Clone(magic), c...), sealed...)
		pc := cloneLinker(p)
		err := pc.HandleReveal(msg, t0)
		if bytes.Equal(msg, reveal) {
			if err != nil {
				t.Fatal(err)
			}
			return
		}
		if err == nil {
			t.Fatal("a reveal nobody sealed")
		}
		if _, err := pc.Device(); err == nil {
			t.Fatal("a device after a bad reveal")
		}
	})
}

// any bytes in place of the welcome end the new device's side
func FuzzWelcome(f *testing.F) {
	r := startLink(f, t0)
	r.joiner.Confirm()
	r.linker.Confirm(t0)
	sk, _ := NewStreamKey()
	w, err := r.linker.Welcome(sk, t0)
	if err != nil {
		f.Fatal(err)
	}
	f.Add(w)
	f.Fuzz(func(t *testing.T, msg []byte) {
		jc := cloneJoiner(r.joiner)
		got, err := jc.HandleWelcome(msg, t0)
		if bytes.Equal(msg, w) {
			if err != nil || got.StreamKey != *sk {
				t.Fatal(err)
			}
			return
		}
		if err == nil {
			t.Fatal("a welcome nobody sealed")
		}
	})
}
