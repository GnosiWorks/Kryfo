// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
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

// any bytes in place of the phone's answer: refused, or a reveal the phone
// cannot open
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
	f.Add(accept)
	f.Add([]byte(acceptMagic))
	f.Fuzz(func(t *testing.T, msg []byte) {
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

// any bytes in place of the reveal end the phone's side
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
	f.Add(reveal)
	f.Fuzz(func(t *testing.T, msg []byte) {
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
