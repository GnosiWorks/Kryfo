// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"crypto/mlkem"
	"encoding/base64"
	"errors"
	"strings"
	"testing"
	"time"
)

var t0 = time.Date(2026, 10, 28, 12, 0, 0, 0, time.UTC)

// a link run up to both sides showing their digits, with every byte that
// went between them
type linkRun struct {
	joiner *Joiner
	linker *Linker
	phone  *identity
	key    Key
	wire   [][]byte
}

func startLink(t testing.TB, now time.Time) *linkRun {
	t.Helper()
	s := newShim()
	r := &linkRun{phone: s.identity(t)}
	r.key, _ = newKey(t)
	j, err := StartJoin(r.key, 4321, now)
	if err != nil {
		t.Fatal(err)
	}
	p, accept, err := AcceptOffer(j.Offer(), r.phone.pub, now)
	if err != nil {
		t.Fatal(err)
	}
	reveal, err := j.HandleAccept(accept, now)
	if err != nil {
		t.Fatal(err)
	}
	if err := p.HandleReveal(reveal, now); err != nil {
		t.Fatal(err)
	}
	r.joiner, r.linker = j, p
	r.wire = [][]byte{j.Offer(), accept, reveal}
	return r
}

func (r *linkRun) finish(t *testing.T, now time.Time) (*Linked, []byte, *[StreamKeySize]byte) {
	t.Helper()
	if err := r.joiner.Confirm(); err != nil {
		t.Fatal(err)
	}
	if err := r.linker.Confirm(now); err != nil {
		t.Fatal(err)
	}
	sk, err := NewStreamKey()
	if err != nil {
		t.Fatal(err)
	}
	keep := *sk
	w, err := r.linker.Welcome(sk, now)
	if err != nil {
		t.Fatal(err)
	}
	r.wire = append(r.wire, w)
	got, err := r.joiner.HandleWelcome(w, now)
	if err != nil {
		t.Fatal(err)
	}
	return got, w, &keep
}

func TestLinkANewDevice(t *testing.T) {
	r := startLink(t, t0)
	sj, err := r.joiner.SAS()
	if err != nil {
		t.Fatal(err)
	}
	sp, err := r.linker.SAS()
	if err != nil || sj != sp || len(sj) != 6 {
		t.Fatalf("digits %q %q %v", sj, sp, err)
	}
	dk, err := r.linker.Device()
	if err != nil || dk.Key != r.key || dk.Reg != 4321 || dk.Identity != r.phone.pub {
		t.Fatalf("device %+v %v", dk, err)
	}
	bj, _ := r.linker.Bind()
	got, _, sk := r.finish(t, t0)
	if got.StreamKey != *sk {
		t.Fatal("stream key")
	}
	if got.Identity != r.phone.pub || got.Keys != dk || got.Bind != bj {
		t.Fatal("what the new device came away with")
	}
	// the number shown after linking is the phone's own
	if got.KeyNumber() != r.linker.KeyNumber() || got.KeyNumber() != KeyNumber(r.phone.pub) {
		t.Fatal("key numbers differ")
	}
	// the keys go onto the phone's list as they arrived
	a := &account{id: r.phone}
	l, err := Genesis(r.phone.pub, 1, seeded(1))
	if err != nil {
		t.Fatal(err)
	}
	e, err := EntryFor(l, dk, seeded(2))
	if err != nil {
		t.Fatal(err)
	}
	n, err := l.Add(e, seeded(3))
	if err != nil {
		t.Fatal(err)
	}
	a.list = n
	if _, ok := n.FindKey(got.Keys.Key); !ok {
		t.Fatal("not on the list")
	}
	got.Forget()
	if got.StreamKey != [StreamKeySize]byte{} {
		t.Fatal("stream key kept")
	}
	// done is done
	if _, err := r.joiner.HandleWelcome(r.wire[3], t0); !errors.Is(err, ErrState) {
		t.Fatalf("a second welcome: %v", err)
	}
	if err := r.linker.HandleReveal(r.wire[2], t0); !errors.Is(err, ErrState) {
		t.Fatalf("a second reveal: %v", err)
	}
}

// the phone's identity private key appears in nothing that crosses, not
// whole and not in part; the welcome holds the stream key and the public
// identity and nothing else
func TestTheLinkHandsOverNoIdentitySecret(t *testing.T) {
	r := startLink(t, t0)
	got, w, sk := r.finish(t, t0)
	secret := r.phone.priv
	if len(secret) != 32 {
		t.Fatal("no secret to look for")
	}
	plain := append(append([]byte(nil), sk[:]...), got.Identity[:]...)
	all := append(append([][]byte(nil), r.wire...), plain)
	for i, m := range all {
		for off := 0; off+8 <= len(secret); off++ {
			if bytes.Contains(m, secret[off:off+8]) {
				t.Fatalf("message %d holds the identity secret at %d", i, off)
			}
		}
	}
	if len(w) != 4+StreamKeySize+KeySize+16 {
		t.Fatalf("welcome %d bytes", len(w))
	}
	if !bytes.Equal(plain[StreamKeySize:], r.phone.pub[:]) {
		t.Fatal("the welcome's identity")
	}
	// the stream key is random per link, never from the identity
	r2 := startLink(t, t0)
	got2, _, _ := r2.finish(t, t0)
	if got2.StreamKey == got.StreamKey {
		t.Fatal("one stream key for two links")
	}
}

// a recording of the link does not open the welcome with the x25519 secret
// alone: the ml-kem secret is needed too
func TestTheWelcomeNeedsTheKemSecret(t *testing.T) {
	r := startLink(t, t0)
	dh := append([]byte(nil), r.joiner.dh...)
	bind := r.joiner.bind
	_, w, _ := r.finish(t, t0)
	for _, kem := range [][]byte{nil, make([]byte, mlkem.SharedKeySize)} {
		k, err := welcomeKey(dh, kem, bind)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := openOnce(k, w[4:], adOf(welcomeMagic, bind)); err == nil {
			t.Fatal("opened without the kem secret")
		}
	}
}

// someone between the two, answering each side with keys of their own:
// the digits differ and the person stops there
func TestSomeoneInTheMiddleShowsOtherDigits(t *testing.T) {
	s := newShim()
	phone := s.identity(t)
	k1, _ := newKey(t)
	j, _ := StartJoin(k1, 1, t0)
	// they play the phone to the new device
	toJoiner, accept, err := AcceptOffer(j.Offer(), s.identity(t).pub, t0)
	if err != nil {
		t.Fatal(err)
	}
	reveal, err := j.HandleAccept(accept, t0)
	if err != nil {
		t.Fatal(err)
	}
	if err := toJoiner.HandleReveal(reveal, t0); err != nil {
		t.Fatal(err)
	}
	// and a new device to the phone, with their own offer
	k2, _ := newKey(t)
	fake, _ := StartJoin(k2, 1, t0)
	p, accept2, err := AcceptOffer(fake.Offer(), phone.pub, t0)
	if err != nil {
		t.Fatal(err)
	}
	reveal2, err := fake.HandleAccept(accept2, t0)
	if err != nil {
		t.Fatal(err)
	}
	if err := p.HandleReveal(reveal2, t0); err != nil {
		t.Fatal(err)
	}
	sj, _ := j.SAS()
	sp, _ := p.SAS()
	if sj == sp {
		t.Fatal("the same digits on both screens")
	}
	// passing the joiner's reveal on to the phone fails: it is sealed to
	// the key they gave the joiner
	q, _, err := AcceptOffer(j.Offer(), phone.pub, t0)
	if err != nil {
		t.Fatal(err)
	}
	if err := q.HandleReveal(reveal, t0); err == nil {
		t.Fatal("a reveal for one link taken in another")
	}
}

func TestARevealNotMatchingTheOfferIsRefused(t *testing.T) {
	s := newShim()
	k, _ := newKey(t)
	j, _ := StartJoin(k, 1, t0)
	p, accept, err := AcceptOffer(j.Offer(), s.identity(t).pub, t0)
	if err != nil {
		t.Fatal(err)
	}
	// a nonce chosen after the offer, as someone grinding the digits would
	j.nonce = bytes.Repeat([]byte{7}, 32)
	reveal, err := j.HandleAccept(accept, t0)
	if err != nil {
		t.Fatal(err)
	}
	if err := p.HandleReveal(reveal, t0); !errors.Is(err, ErrCommit) {
		t.Fatalf("a nonce not committed to: %v", err)
	}
	if _, err := p.SAS(); !errors.Is(err, ErrState) {
		t.Fatal("digits after a failed reveal")
	}
}

func TestNothingIsSentBeforeTheDigitsAreConfirmed(t *testing.T) {
	r := startLink(t, t0)
	sk, _ := NewStreamKey()
	if _, err := r.linker.Welcome(sk, t0); !errors.Is(err, ErrState) {
		t.Fatalf("a welcome before the phone confirmed: %v", err)
	}
	if err := r.linker.Confirm(t0); err != nil {
		t.Fatal(err)
	}
	w, err := r.linker.Welcome(sk, t0)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := r.joiner.HandleWelcome(w, t0); !errors.Is(err, ErrState) {
		t.Fatalf("a welcome before the new device confirmed: %v", err)
	}
	if err := r.joiner.Confirm(); err != nil {
		t.Fatal(err)
	}
	if _, err := r.joiner.HandleWelcome(w, t0); err != nil {
		t.Fatal(err)
	}
}

// ten minutes by the new device's clock, and ten by the phone's
func TestOffersOlderThanTenMinutesAreRefused(t *testing.T) {
	s := newShim()
	phone := s.identity(t).pub
	k, _ := newKey(t)
	late := t0.Add(LinkLife + time.Second)

	// the phone's clock: an offer whose life has run out
	j, _ := StartJoin(k, 1, t0)
	if _, _, err := AcceptOffer(j.Offer(), phone, late); !errors.Is(err, ErrExpired) {
		t.Fatalf("an old offer on the phone: %v", err)
	}
	if _, _, err := AcceptOffer(j.Offer(), phone, t0.Add(LinkLife)); !errors.Is(err, ErrExpired) {
		t.Fatalf("an offer at its expiry: %v", err)
	}
	// the new device's clock: an answer after its ten minutes
	_, accept, err := AcceptOffer(j.Offer(), phone, t0)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := j.HandleAccept(accept, late); !errors.Is(err, ErrExpired) {
		t.Fatalf("an answer too late: %v", err)
	}
	// and a welcome after them
	r := startLink(t, t0)
	r.joiner.Confirm()
	r.linker.Confirm(t0)
	sk, _ := NewStreamKey()
	w, _ := r.linker.Welcome(sk, t0)
	if _, err := r.joiner.HandleWelcome(w, late); !errors.Is(err, ErrExpired) {
		t.Fatalf("a welcome too late: %v", err)
	}
	// an offer claiming to live for days is not taken
	far, _ := StartJoin(k, 1, t0.Add(48*time.Hour))
	if _, _, err := AcceptOffer(far.Offer(), phone, t0); !errors.Is(err, ErrMalformed) {
		t.Fatalf("an offer from far ahead: %v", err)
	}
	// the phone keeps its own clock: an offer from a clock half an hour
	// ahead still ends ten minutes after the phone took it
	ahead, _ := StartJoin(k, 1, t0.Add(30*time.Minute))
	p, accept, err := AcceptOffer(ahead.Offer(), phone, t0)
	if err != nil {
		t.Fatal(err)
	}
	reveal, err := ahead.HandleAccept(accept, t0.Add(30*time.Minute))
	if err != nil {
		t.Fatal(err)
	}
	if err := p.HandleReveal(reveal, t0); err != nil {
		t.Fatal(err)
	}
	if err := p.Confirm(late); !errors.Is(err, ErrExpired) {
		t.Fatalf("a confirm past the phone's own deadline: %v", err)
	}
	// and a reveal past it
	ahead2, _ := StartJoin(k, 1, t0.Add(30*time.Minute))
	p2, accept2, _ := AcceptOffer(ahead2.Offer(), phone, t0)
	reveal2, _ := ahead2.HandleAccept(accept2, t0.Add(30*time.Minute))
	if err := p2.HandleReveal(reveal2, late); !errors.Is(err, ErrExpired) {
		t.Fatalf("a reveal past the phone's own deadline: %v", err)
	}
	// a welcome past it
	r3 := startLink(t, t0)
	r3.linker.Confirm(t0)
	if _, err := r3.linker.Welcome(sk, late); !errors.Is(err, ErrExpired) {
		t.Fatalf("a welcome past the phone's own deadline: %v", err)
	}
}

// any bad message ends the link for good: the good one after it is refused
func TestTamperedLinkMessagesEndTheLink(t *testing.T) {
	flip := func(b []byte, i int) []byte {
		c := bytes.Clone(b)
		c[i] ^= 1
		return c
	}
	// the answer is not sealed, so a changed one shows only later: the
	// phone cannot open the reveal it leads to
	for _, i := range []int{4, 40, acceptSize - 1} {
		s := newShim()
		k, _ := newKey(t)
		j, _ := StartJoin(k, 1, t0)
		p, accept, err := AcceptOffer(j.Offer(), s.identity(t).pub, t0)
		if err != nil {
			t.Fatal(err)
		}
		reveal, err := j.HandleAccept(flip(accept, i), t0)
		if err != nil {
			continue
		}
		if err := p.HandleReveal(reveal, t0); err == nil {
			t.Fatalf("a reveal after an answer flipped at %d taken", i)
		}
		if err := p.HandleReveal(reveal, t0); !errors.Is(err, ErrState) {
			t.Fatalf("the phone went on after a bad reveal: %v", err)
		}
	}
	for _, i := range []int{0, 4, 4 + mlkem.CiphertextSize1024 + 3, revealSize - 1} {
		s := newShim()
		k, _ := newKey(t)
		j, _ := StartJoin(k, 1, t0)
		p, accept, _ := AcceptOffer(j.Offer(), s.identity(t).pub, t0)
		reveal, _ := j.HandleAccept(accept, t0)
		if err := p.HandleReveal(flip(reveal, i), t0); err == nil {
			t.Fatalf("reveal flipped at %d taken", i)
		}
		if err := p.HandleReveal(reveal, t0); err == nil {
			t.Fatal("a link went on after a bad reveal")
		}
	}
	for _, i := range []int{0, 4, welcomeSize - 1} {
		r := startLink(t, t0)
		r.joiner.Confirm()
		r.linker.Confirm(t0)
		sk, _ := NewStreamKey()
		w, _ := r.linker.Welcome(sk, t0)
		if _, err := r.joiner.HandleWelcome(flip(w, i), t0); err == nil {
			t.Fatalf("welcome flipped at %d taken", i)
		}
		if _, err := r.joiner.HandleWelcome(w, t0); err == nil {
			t.Fatal("a link went on after a bad welcome")
		}
	}
	// short and long messages
	r := startLink(t, t0)
	r.joiner.Confirm()
	if _, err := r.joiner.HandleWelcome(make([]byte, welcomeSize+1), t0); !errors.Is(err, ErrMalformed) {
		t.Fatalf("a long welcome: %v", err)
	}
}

func TestAWelcomeFromAnotherLinkIsRefused(t *testing.T) {
	r1 := startLink(t, t0)
	r2 := startLink(t, t0)
	_, _, _ = r1.finish(t, t0)
	r2.joiner.Confirm()
	if _, err := r2.joiner.HandleWelcome(r1.wire[3], t0); err == nil {
		t.Fatal("another link's welcome taken")
	}
}

func TestBadKeysEndTheLink(t *testing.T) {
	s := newShim()
	phone := s.identity(t).pub
	if _, err := StartJoin(Key{0x05}, 1, t0); err == nil {
		t.Fatal("a small-order device key")
	}
	k, _ := newKey(t)
	if _, err := StartJoin(k, 0, t0); err == nil {
		t.Fatal("registration id 0")
	}
	if _, err := StartJoin(k, MaxReg+1, t0); err == nil {
		t.Fatal("a registration id out of range")
	}
	j, _ := StartJoin(k, 1, t0)
	if _, _, err := AcceptOffer(j.Offer(), Key{0x05, 1}, t0); err == nil {
		t.Fatal("a small-order identity")
	}
	// a joiner offering the phone's own identity key as its device key
	same, _ := StartJoin(phone, 1, t0)
	p, accept, _ := AcceptOffer(same.Offer(), phone, t0)
	reveal, _ := same.HandleAccept(accept, t0)
	if err := p.HandleReveal(reveal, t0); !errors.Is(err, ErrMalformed) {
		t.Fatalf("the identity as a device key: %v", err)
	}
	// an all-zero ephemeral key in the offer
	bad := j.Offer()
	copy(bad[4:36], make([]byte, 32))
	if _, _, err := AcceptOffer(bad, phone, t0); err == nil {
		t.Fatal("a low-order ephemeral")
	}
	// an accept with a kem key that does not read
	j2, _ := StartJoin(k, 1, t0)
	_, accept2, _ := AcceptOffer(j2.Offer(), phone, t0)
	broken := bytes.Clone(accept2)
	for i := 36; i < 36+384; i++ {
		broken[i] = 0xff
	}
	if _, err := j2.HandleAccept(broken, t0); !errors.Is(err, ErrMalformed) {
		t.Fatalf("a kem key above the modulus: %v", err)
	}
}

func TestOfferText(t *testing.T) {
	k, _ := newKey(t)
	j, _ := StartJoin(k, 1, t0)
	txt := j.OfferText()
	if !strings.HasPrefix(txt, OfferPrefix) {
		t.Fatal(txt)
	}
	b, err := ParseOfferText("  " + txt + "\n")
	if err != nil || !bytes.Equal(b, j.Offer()) {
		t.Fatalf("round trip: %v", err)
	}
	for _, bad := range []string{
		"",
		OfferPrefix,
		"kryfo-lnk:" + txt[len(OfferPrefix):],
		txt + "A",
		txt[:len(txt)-1],
		OfferPrefix + base64.RawURLEncoding.EncodeToString(append([]byte("KLO1"), j.Offer()[4:]...)),
		OfferPrefix + base64.RawURLEncoding.EncodeToString(j.Offer()[:offerSize-1]),
		OfferPrefix + strings.Repeat("A", 400),
		txt + "=",
	} {
		if _, err := ParseOfferText(bad); err == nil {
			t.Errorf("%q read", bad)
		}
	}
}
