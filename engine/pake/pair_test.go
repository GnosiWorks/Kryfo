// SPDX-License-Identifier: GPL-3.0-or-later
package pake

import (
	"bytes"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"testing"
	"time"
)

// fixed inputs; the expected bytes come from a second implementation in
// python (hashlib, hmac and the cryptography package), not from this one
var (
	tNow   = time.Unix(1793275200, 0)
	tSid   = []byte{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16}
	tYa    = sha256.Sum256([]byte("kryfo pake test ya"))
	tYb    = sha256.Sum256([]byte("kryfo pake test yb"))
	tInvA  = append([]byte("KIN4"), bytes.Repeat(seq(0, 256, 1), 8)...)
	tInvB  = append([]byte("KIN4"), bytes.Repeat(seq(255, -1, -1), 7)...)
	tCode  = mustCode("07 123 456")
	tOffer = "4b504f3100000102030405060708090a0b0c0d0e0f10045d18cc36e1707f0326253d8672b614e2ac5e4088a1056a034952fe6d918a2300000000002d9af801c80dba"
)

const (
	tWindow     = 2988792
	tGenerator  = "8f6cc06a5e66b3ead53c52c8b01fb9ca4ff536275cc1b3e3bad8422f9a49437b"
	tAnswerHead = "4b50413100000102030405060708090a0b0c0d0e0f100716773c654dee5265b5ae695b445b51b687ed7fb73bb84bdb4e58cf7b57e3313a530c45ce9110d8055be376d7365dbdaedc990f83982dd493531544cb5e21840714"
	tAnswerHash = "1fa4eadda8c49b034c844b37a99d380f500eccc8dac89304e6886b41a3d42eec"
	tFinishHead = "4b5046310102030405060708090a0b0c0d0e0f10d689543ab223883ed1d29877b96532043429048c8a9e7d4c6cb138d37dd2d9ba0814"
	tFinishHash = "7c4661f01c448c1b643cab684f82bfd3998579dadde3ad859f9ca95f2d347b4b"
)

func seq(from, to, step int) []byte {
	var b []byte
	for i := from; i != to; i += step {
		b = append(b, byte(i))
	}
	return b
}

func mustCode(s string) Code {
	c, err := ParseCode(s)
	if err != nil {
		panic(err)
	}
	return c
}

func sharerRand() *bytes.Reader { return bytes.NewReader(append(bytes.Clone(tSid), tYa[:]...)) }

func fixedSharer(t testing.TB) (*Sharer, []byte) {
	t.Helper()
	c := tCode
	s, err := NewSharer(&c, tInvA)
	if err != nil {
		t.Fatal(err)
	}
	off, w, err := s.Offer(tNow, sharerRand())
	if err != nil || w != tWindow {
		t.Fatalf("offer: %v, window %d", err, w)
	}
	return s, off
}

func fixedJoiner(t testing.TB, code string) *Joiner {
	t.Helper()
	c := mustCode(code)
	j, err := NewJoiner(&c, tInvB)
	if err != nil {
		t.Fatal(err)
	}
	return j
}

func hashHex(b []byte) string {
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}

func TestPairVector(t *testing.T) {
	if string(channelID(tCode.box, tWindow)) != "kryfo-pair-v4:07:2988792" {
		t.Fatalf("ci = %q", channelID(tCode.box, tWindow))
	}
	g := generator(tCode.secret[:], channelID(tCode.box, tWindow), tSid)
	if hex.EncodeToString(g[:]) != tGenerator {
		t.Fatalf("generator = %x", g)
	}
	s, off := fixedSharer(t)
	if hex.EncodeToString(off) != tOffer {
		t.Fatalf("offer = %x", off)
	}
	j := fixedJoiner(t, "07123456")
	ans, err := j.Answer(off, tNow.Add(time.Minute), bytes.NewReader(tYb[:]))
	if err != nil {
		t.Fatal(err)
	}
	if hex.EncodeToString(ans[:answerAAD]) != tAnswerHead || hashHex(ans) != tAnswerHash || len(ans) != 1900 {
		t.Fatalf("answer %d bytes, head %x", len(ans), ans[:answerAAD])
	}
	fin, inv, err := s.Answer(ans, tNow.Add(2*time.Minute))
	if err != nil || !bytes.Equal(inv, tInvB) {
		t.Fatalf("sharer: %v, invite match %v", err, bytes.Equal(inv, tInvB))
	}
	if hex.EncodeToString(fin[:finishAAD]) != tFinishHead || hashHex(fin) != tFinishHash || len(fin) != 2122 {
		t.Fatalf("finish %d bytes, head %x", len(fin), fin[:finishAAD])
	}
	got, err := j.Finish(fin)
	if err != nil || !bytes.Equal(got, tInvA) {
		t.Fatalf("joiner: %v", err)
	}
	if _, err := j.Finish(fin); err != ErrDone {
		t.Fatalf("finish twice: %v", err)
	}
	if _, _, err := s.Answer(ans, tNow); err != ErrDone {
		t.Fatalf("answer after done: %v", err)
	}
}

func TestPairRandom(t *testing.T) {
	for range 20 {
		c, err := NewCode(nil)
		if err != nil {
			t.Fatal(err)
		}
		s, err := NewSharer(&c, tInvA)
		if err != nil {
			t.Fatal(err)
		}
		now := time.Now()
		off, _, err := s.Offer(now, nil)
		if err != nil {
			t.Fatal(err)
		}
		typed := mustCode(c.String())
		j, err := NewJoiner(&typed, tInvB)
		if err != nil {
			t.Fatal(err)
		}
		c.Wipe()
		typed.Wipe()
		ans, err := j.Answer(off, now, nil)
		if err != nil {
			t.Fatal(err)
		}
		fin, inv, err := s.Answer(ans, now)
		if err != nil || !bytes.Equal(inv, tInvB) {
			t.Fatalf("sharer: %v", err)
		}
		if got, err := j.Finish(fin); err != nil || !bytes.Equal(got, tInvA) {
			t.Fatalf("joiner: %v", err)
		}
	}
}

func TestWrongSecretFailsOnTag(t *testing.T) {
	s, off := fixedSharer(t)
	j := fixedJoiner(t, "07123457")
	ans, err := j.Answer(off, tNow, bytes.NewReader(tYb[:]))
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := s.Answer(ans, tNow); err != ErrWrongCode || s.Fails() != 1 {
		t.Fatalf("got %v, fails %d", err, s.Fails())
	}
	// the same wrong answer again is not a second try
	if _, _, err := s.Answer(ans, tNow); err != ErrWrongCode || s.Fails() != 1 {
		t.Fatalf("again: %v, fails %d", err, s.Fails())
	}
	// a wrong box gives another ci, so a wrong tag too
	j2 := fixedJoiner(t, "08123456")
	ans2, err := j2.Answer(off, tNow, nil)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := s.Answer(ans2, tNow); err != ErrWrongCode || s.Fails() != 2 {
		t.Fatalf("other box: %v, fails %d", err, s.Fails())
	}
	// and so does another window in ci, with the tag over the real offer
	head, ks := runAt(t, off, tCode, tWindow-1)
	ans3 := seal(&ks.sealB, append(head, tagB(ks, off, head)...), tInvB)
	if _, _, err := s.Answer(ans3, tNow); err != ErrTries {
		t.Fatalf("third: %v", err)
	}
	// the code is dead: the right answer is refused now
	good := fixedJoiner(t, "07123456")
	ans4, err := good.Answer(off, tNow, nil)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := s.Answer(ans4, tNow); err != ErrTries {
		t.Fatalf("after dead: %v", err)
	}
	if _, _, err := s.Offer(tNow.Add(WindowLength), nil); err != ErrTries {
		t.Fatalf("offer after dead: %v", err)
	}
	assertSharerWiped(t, s)
}

func TestTagFromAnotherRunRefused(t *testing.T) {
	// two runs of the same code: each run's tags and seals are its own
	c := tCode
	s1, _ := NewSharer(&c, tInvA)
	s2, _ := NewSharer(&c, tInvA)
	off1, _, _ := s1.Offer(tNow, nil)
	off2, _, _ := s2.Offer(tNow, nil)
	j1 := fixedJoiner(t, "07123456")
	j2 := fixedJoiner(t, "07123456")
	a1, err := j1.Answer(off1, tNow, nil)
	if err != nil {
		t.Fatal(err)
	}
	a2, err := j2.Answer(off2, tNow, nil)
	if err != nil {
		t.Fatal(err)
	}
	// run 1's tag on run 2's answer
	mixed := bytes.Clone(a2)
	copy(mixed[answerHead:answerHead+TagSize], a1[answerHead:answerHead+TagSize])
	if _, _, err := s2.Answer(mixed, tNow); err != ErrWrongCode {
		t.Fatalf("mixed tag: %v", err)
	}
	// run 1's answer at run 2's sharer names no offer of it
	if _, _, err := s2.Answer(a1, tNow); err != ErrUnknown {
		t.Fatalf("other run's answer: %v", err)
	}
	f1, _, err := s1.Answer(a1, tNow)
	if err != nil {
		t.Fatal(err)
	}
	// run 1's finish at run 2's joiner
	if _, err := j2.Finish(f1); err != ErrUnknown {
		t.Fatalf("other run's finish: %v", err)
	}
	// run 1's tag on run 2's sid
	f2, _, err := s2.Answer(a2, tNow)
	if err != nil {
		t.Fatal(err)
	}
	forged := bytes.Clone(f2)
	copy(forged[4+SidSize:4+SidSize+TagSize], f1[4+SidSize:4+SidSize+TagSize])
	if _, err := j2.Finish(forged); err != ErrWrongCode {
		t.Fatalf("forged finish: %v", err)
	}
	// a wrong finish leaves the answer waiting for the real one
	if got, err := j2.Finish(f2); err != nil || !bytes.Equal(got, tInvA) {
		t.Fatalf("real finish after a forged one: %v", err)
	}
	if _, err := j1.Finish(f1); err != nil {
		t.Fatal(err)
	}
}

func TestEveryAnswerByteFlipRefused(t *testing.T) {
	_, off := fixedSharer(t)
	j := fixedJoiner(t, "07123456")
	ans, err := j.Answer(off, tNow, bytes.NewReader(tYb[:]))
	if err != nil {
		t.Fatal(err)
	}
	for i := range ans {
		s, _ := fixedSharer(t)
		m := bytes.Clone(ans)
		m[i] ^= 0x01
		fin, inv, err := s.Answer(m, tNow)
		if err == nil || fin != nil || inv != nil {
			t.Fatalf("flip at %d taken", i)
		}
		// only a parsed answer for our offer can count as a try
		if s.Fails() > 1 {
			t.Fatalf("flip at %d counted %d", i, s.Fails())
		}
	}
}

func TestEveryFinishByteFlipRefused(t *testing.T) {
	s, off := fixedSharer(t)
	j := fixedJoiner(t, "07123456")
	ans, _ := j.Answer(off, tNow, bytes.NewReader(tYb[:]))
	fin, _, err := s.Answer(ans, tNow)
	if err != nil {
		t.Fatal(err)
	}
	for i := range fin {
		m := bytes.Clone(fin)
		m[i] ^= 0x80
		if got, err := j.Finish(m); err == nil || got != nil {
			t.Fatalf("flip at %d taken", i)
		}
	}
	if got, err := j.Finish(fin); err != nil || !bytes.Equal(got, tInvA) {
		t.Fatalf("real finish after the flips: %v", err)
	}
}

func TestParsersRefuse(t *testing.T) {
	off, _ := hex.DecodeString(tOffer)
	if _, err := parseOffer(off); err != nil {
		t.Fatal(err)
	}
	bad := map[string][]byte{
		"short":    off[:OfferSize-1],
		"trailing": append(bytes.Clone(off), 0),
		"empty":    nil,
	}
	for name, at := range map[string]int{"magic": 0, "flags hi": 4, "flags lo": 5} {
		m := bytes.Clone(off)
		m[at] ^= 0x01
		bad[name] = m
	}
	top := bytes.Clone(off)
	top[22+31] |= 0x80
	bad["ya bit 255"] = top
	big := bytes.Clone(off)
	copy(big[22:54], bytes.Repeat([]byte{0xff}, 31))
	big[22+31] = 0x7f
	bad["ya above p"] = big
	for name, m := range bad {
		if _, err := parseOffer(m); err != ErrFormat {
			t.Fatalf("offer %s: %v", name, err)
		}
	}

	_, off2 := fixedSharer(t)
	j := fixedJoiner(t, "07123456")
	ans, _ := j.Answer(off2, tNow, bytes.NewReader(tYb[:]))
	if _, err := parseAnswer(ans); err != nil {
		t.Fatal(err)
	}
	setLen := func(m []byte, at, n int) []byte {
		m = bytes.Clone(m)
		binary.BigEndian.PutUint16(m[at:], uint16(n))
		return m
	}
	for name, m := range map[string][]byte{
		"short":       ans[:answerAAD-1],
		"trailing":    append(bytes.Clone(ans), 0),
		"cut":         ans[:len(ans)-1],
		"length up":   setLen(ans, answerAAD-2, len(ans)-answerAAD+1),
		"length zero": setLen(ans[:answerAAD], answerAAD-2, 0),
		"only a tag":  setLen(append(bytes.Clone(ans[:answerAAD]), make([]byte, sealTag)...), answerAAD-2, sealTag),
		"too big":     setLen(append(bytes.Clone(ans[:answerAAD]), make([]byte, MaxInvite+sealTag+1)...), answerAAD-2, MaxInvite+sealTag+1),
		"flags":       append(append([]byte(magicAnswer), 0, 1), ans[6:]...),
		"magic":       append([]byte("KPA2"), ans[4:]...),
	} {
		if _, err := parseAnswer(m); err != ErrFormat {
			t.Fatalf("answer %s: %v", name, err)
		}
	}

	for name, m := range map[string][]byte{
		"short":   []byte(magicFinish),
		"magic":   append([]byte("KPF0"), make([]byte, finishAAD+20)...),
		"no seal": append([]byte(magicFinish), make([]byte, finishAAD-4)...),
	} {
		if _, err := parseFinish(m); err != ErrFormat {
			t.Fatalf("finish %s: %v", name, err)
		}
	}
}

func TestLowOrderShareNotATry(t *testing.T) {
	s, off := fixedSharer(t)
	j := fixedJoiner(t, "07123456")
	ans, _ := j.Answer(off, tNow, bytes.NewReader(tYb[:]))
	for _, u := range [][]byte{make([]byte, 32), append([]byte{1}, make([]byte, 31)...)} {
		m := bytes.Clone(ans)
		copy(m[22:54], u)
		if _, _, err := s.Answer(m, tNow); err != ErrLowOrder || s.Fails() != 0 {
			t.Fatalf("low order yb: %v, fails %d", err, s.Fails())
		}
		o := bytes.Clone(off)
		o[6] ^= 0xff
		copy(o[22:54], u)
		if _, err := j.Answer(o, tNow, nil); err != ErrLowOrder {
			t.Fatalf("low order ya: %v", err)
		}
	}
	if j.Tries() != 1 {
		t.Fatalf("joiner tries %d", j.Tries())
	}
	if _, _, err := s.Answer(ans, tNow); err != nil {
		t.Fatal(err)
	}
}

func TestJoinerAnswersThreeOffers(t *testing.T) {
	j := fixedJoiner(t, "07123456")
	var first, firstAns []byte
	for i := range MaxTries {
		c := mustCode("07 999 999")
		s, _ := NewSharer(&c, tInvA)
		off, _, _ := s.Offer(tNow, nil)
		a, err := j.Answer(off, tNow, nil)
		if err != nil {
			t.Fatalf("offer %d: %v", i, err)
		}
		if i == 0 {
			first, firstAns = off, a
		}
	}
	// a relay sending the first offer again gets the same answer, no try
	again, err := j.Answer(first, tNow, nil)
	if err != nil || !bytes.Equal(again, firstAns) || j.Tries() != MaxTries {
		t.Fatalf("again: %v, tries %d", err, j.Tries())
	}
	// the same sid with other bytes is another offer, past the cap
	other := bytes.Clone(first)
	other[22] ^= 1
	if _, err := j.Answer(other, tNow, nil); err != ErrTries {
		t.Fatalf("same sid, other offer: %v", err)
	}
	_, off := fixedSharer(t)
	if _, err := j.Answer(off, tNow, nil); err != ErrTries {
		t.Fatalf("fourth offer: %v", err)
	}
}

func TestOfferTimes(t *testing.T) {
	s, off := fixedSharer(t)
	j := fixedJoiner(t, "07123456")
	// windows the joiner would not have read
	for _, w := range []uint64{tWindow - 3, tWindow + 1, tWindow + 100} {
		if _, err := j.Answer(withWindow(off, w), tNow, nil); err != ErrExpired {
			t.Fatalf("window %d: %v", w, err)
		}
	}
	// past its expiry plus the skew
	late := tNow.Add(OfferLife + Skew + 2*time.Minute)
	if _, err := j.Answer(off, late, nil); err != ErrExpired {
		t.Fatalf("late: %v", err)
	}
	// an expiry too far ahead, inside what its window allows
	o, _ := parseOffer(off)
	o.expires += 6
	if _, err := j.Answer(o.encode(), tNow, nil); err != ErrExpired {
		t.Fatalf("far expiry: %v", err)
	}
	// an expiry its window does not allow is no offer at all
	for _, e := range []uint32{o.expires - 7, o.expires + 5} {
		o.expires = e
		if _, err := j.Answer(o.encode(), tNow, nil); err != ErrFormat {
			t.Fatalf("expiry %d for window %d: %v", e, o.window, err)
		}
	}
	if j.Tries() != 0 {
		t.Fatalf("refused offers cost %d tries", j.Tries())
	}
	ans, err := j.Answer(off, tNow, nil)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := s.Answer(ans, late); err != ErrExpired || s.Fails() != 0 {
		t.Fatalf("sharer late: %v", err)
	}
	if _, _, err := s.Answer(ans, tNow.Add(OfferLife)); err != nil {
		t.Fatalf("in time: %v", err)
	}
}

func TestOffersPerWindow(t *testing.T) {
	c := tCode
	s, _ := NewSharer(&c, tInvA)
	o1, w1, _ := s.Offer(tNow, nil)
	same, _, _ := s.Offer(tNow.Add(time.Minute), nil)
	if !bytes.Equal(o1, same) {
		t.Fatal("a second offer in one window")
	}
	t2 := tNow.Add(WindowLength)
	o2, w2, _ := s.Offer(t2, nil)
	if w2 != w1+1 || bytes.Equal(o1, o2) || bytes.Equal(o1[6:54], o2[6:54]) {
		t.Fatal("next window kept the sid or ya")
	}
	// the joiner found the first offer in the window before
	j := fixedJoiner(t, "07123456")
	a1, err := j.Answer(o1, t2, nil)
	if err != nil {
		t.Fatal(err)
	}
	t3 := t2.Add(WindowLength)
	if _, _, err := s.Offer(t3, nil); err != nil {
		t.Fatal(err)
	}
	// a third window pushed the first offer out
	if _, _, err := s.Answer(a1, t2); err != ErrUnknown {
		t.Fatalf("pushed out offer: %v", err)
	}
	j2 := fixedJoiner(t, "07123456")
	a2, _ := j2.Answer(o2, t3, nil)
	if _, _, err := s.Answer(a2, t3); err != nil {
		t.Fatalf("previous window's offer: %v", err)
	}
}

func assertSharerWiped(t *testing.T, s *Sharer) {
	t.Helper()
	if !allZero(s.prs) || !allZero(s.invite) || s.offers != nil {
		t.Fatal("sharer kept secrets")
	}
}

func allZero(b []byte) bool {
	for _, x := range b {
		if x != 0 {
			return false
		}
	}
	return true
}

func TestWipe(t *testing.T) {
	s, off := fixedSharer(t)
	so := s.offers[0]
	j := fixedJoiner(t, "07123456")
	ans, _ := j.Answer(off, tNow, bytes.NewReader(tYb[:]))
	var p *pending
	for _, x := range j.pend {
		p = x
	}
	fin, _, err := s.Answer(ans, tNow)
	if err != nil {
		t.Fatal(err)
	}
	assertSharerWiped(t, s)
	if !allZero(so.y[:]) {
		t.Fatal("sharer scalar kept")
	}
	if _, err := j.Finish(fin); err != nil {
		t.Fatal(err)
	}
	if !allZero(j.prs) || !allZero(j.invite) || len(j.pend) != 0 || !allZero(p.confA[:]) || !allZero(p.sealA[:]) {
		t.Fatal("joiner kept secrets")
	}

	c := tCode
	s2, _ := NewSharer(&c, tInvA)
	s2.Offer(tNow, nil)
	so2 := s2.offers[0]
	s2.Close()
	assertSharerWiped(t, s2)
	if !allZero(so2.y[:]) {
		t.Fatal("closed sharer kept its scalar")
	}
	if _, _, err := s2.Offer(tNow, nil); err != ErrTries {
		t.Fatalf("offer after close: %v", err)
	}
	j2 := fixedJoiner(t, "07123456")
	j2.Close()
	if !allZero(j2.prs) || !allZero(j2.invite) {
		t.Fatal("closed joiner kept secrets")
	}
	c.Wipe()
	if !allZero(c.secret[:]) || c.Box() != "07" {
		t.Fatal("code wipe")
	}
}

func TestInviteSize(t *testing.T) {
	c := tCode
	for _, n := range []int{0, MaxInvite + 1} {
		if _, err := NewSharer(&c, make([]byte, n)); err != ErrInvite {
			t.Fatalf("sharer invite %d: %v", n, err)
		}
		if _, err := NewJoiner(&c, make([]byte, n)); err != ErrInvite {
			t.Fatalf("joiner invite %d: %v", n, err)
		}
	}
	// the largest invite goes through both ways
	big := bytes.Repeat([]byte{7}, MaxInvite)
	s, _ := NewSharer(&c, big)
	off, _, _ := s.Offer(tNow, nil)
	j, _ := NewJoiner(&c, big)
	a, err := j.Answer(off, tNow, nil)
	if err != nil {
		t.Fatal(err)
	}
	fin, inv, err := s.Answer(a, tNow)
	if err != nil || !bytes.Equal(inv, big) {
		t.Fatalf("sharer: %v", err)
	}
	if got, err := j.Finish(fin); err != nil || !bytes.Equal(got, big) {
		t.Fatalf("joiner: %v", err)
	}
}

func TestCodes(t *testing.T) {
	for in, want := range map[string]string{
		"07123456":   "07 123 456",
		"07 123 456": "07 123 456",
		"07-123-456": "07 123 456",
		"٠٧١٢٣٤٥٦":   "07 123 456",
		"۰۷ ۱۲۳ ۴۵۶": "07 123 456",
		"०७१२३४५६":   "07 123 456",
		"０７１２３４５６":   "07 123 456",
	} {
		c, err := ParseCode(in)
		if err != nil || c.String() != want {
			t.Fatalf("%q: %q %v", in, c.String(), err)
		}
	}
	for _, in := range []string{"", "0712345", "071234567", "07a23456", "07.123.456", "07 123 45x"} {
		if _, err := ParseCode(in); !errors.Is(err, ErrCode) {
			t.Fatalf("%q taken", in)
		}
	}
	// every digit place sees every digit
	var seen [BoxDigits + SecretDigits][10]bool
	for range 2000 {
		c, err := NewCode(nil)
		if err != nil {
			t.Fatal(err)
		}
		d := append(c.box[:], c.secret[:]...)
		for i, x := range d {
			seen[i][x-'0'] = true
		}
	}
	for i := range seen {
		for v, ok := range seen[i] {
			if !ok {
				t.Fatalf("place %d never drew %d", i, v)
			}
		}
	}
	// rejection: a draw at or above the cut is thrown away
	r := bytes.NewReader([]byte{0xff, 0xff, 0xff, 0xff, 0, 0, 0, 5})
	if v, err := uniform(r, 100); err != nil || v != 5 {
		t.Fatalf("uniform = %d %v", v, err)
	}
}

func FuzzParse(f *testing.F) {
	off, _ := hex.DecodeString(tOffer)
	f.Add(off)
	f.Add([]byte(magicFinish))
	f.Fuzz(func(t *testing.T, b []byte) {
		if o, err := parseOffer(b); err == nil && !bytes.Equal(o.encode(), b) {
			t.Fatal("offer does not re-encode")
		}
		if a, err := parseAnswer(b); err == nil && len(a.sealed) != len(b)-answerAAD {
			t.Fatal("answer length")
		}
		if fi, err := parseFinish(b); err == nil && len(fi.sealed) != len(b)-finishAAD {
			t.Fatal("finish length")
		}
	})
}

func TestAnswerYbNotCanonical(t *testing.T) {
	s, off := fixedSharer(t)
	j := fixedJoiner(t, "07123456")
	ans, _ := j.Answer(off, tNow, bytes.NewReader(tYb[:]))
	m := bytes.Clone(ans)
	m[22+31] |= 0x80
	if _, _, err := s.Answer(m, tNow); err != ErrFormat || s.Fails() != 0 {
		t.Fatalf("yb with bit 255: %v, fails %d", err, s.Fails())
	}
}

// a wrong tag_b under a seal that opens is still refused: the tag is
// checked on its own, not only through the seal
func TestTagCheckedBeforeSeal(t *testing.T) {
	s, off := fixedSharer(t)
	head, ks := runAt(t, off, tCode, tWindow)
	tb := tagB(ks, off, head)
	tb[0] ^= 1
	m := seal(&ks.sealB, append(bytes.Clone(head), tb...), tInvB)
	if _, err := open(&ks.sealB, m, answerAAD); err != nil {
		t.Fatal(err)
	}
	if _, _, err := s.Answer(m, tNow); err != ErrWrongCode || s.Fails() != 1 {
		t.Fatalf("wrong tag, good seal: %v", err)
	}
	tb[0] ^= 1
	good := seal(&ks.sealB, append(bytes.Clone(head), tb...), tInvB)
	if _, inv, err := s.Answer(good, tNow); err != nil || !bytes.Equal(inv, tInvB) {
		t.Fatalf("good: %v", err)
	}
}

// runAt is the joiner's side of a run with any code and any window in ci
func runAt(t testing.TB, off []byte, c Code, w uint64) ([]byte, *keys) {
	t.Helper()
	o, err := parseOffer(off)
	if err != nil {
		t.Fatal(err)
	}
	g := generator(c.secret[:], channelID(c.box, w), o.sid[:])
	y := tYb
	yb, _ := scalarMult(&y, g[:])
	k, _ := scalarMult(&y, o.ya[:])
	head := answerHeader(o.sid[:], yb[:])
	ks, err := run(o.sid[:], k[:], o.ya[:], o.ada(), yb[:], adb(o.sid[:]), off, head)
	if err != nil {
		t.Fatal(err)
	}
	return head, ks
}

// withWindow is the offer moved to another window, expiry to match
func withWindow(off []byte, w uint64) []byte {
	o, _ := parseOffer(off)
	o.window = w
	o.expires = uint32((w + 1) * windowMinutes)
	return o.encode()
}

// a copy of the honest offer read at another window's address gets the
// same answer: ci comes from the window in the offer, not the address.
// a copy with its window rewritten is another offer and costs one try,
// and the real one is still answered and pairs
func TestMovedOfferDoesNotBlock(t *testing.T) {
	s, off := fixedSharer(t)
	j := fixedJoiner(t, "07123456")
	moved := withWindow(off, tWindow+1)
	next := tNow.Add(WindowLength + time.Minute)
	if _, err := j.Answer(moved, next, nil); err != nil {
		t.Fatal(err)
	}
	a1, err := j.Answer(off, next, nil)
	if err != nil {
		t.Fatal(err)
	}
	a2, err := j.Answer(off, next, nil)
	if err != nil || !bytes.Equal(a1, a2) || j.Tries() != 2 {
		t.Fatalf("the same offer at a second address: %v, tries %d", err, j.Tries())
	}
	fin, inv, err := s.Answer(a1, next)
	if err != nil || !bytes.Equal(inv, tInvB) {
		t.Fatalf("sharer: %v", err)
	}
	if got, err := j.Finish(fin); err != nil || !bytes.Equal(got, tInvA) {
		t.Fatalf("joiner: %v", err)
	}
}

// a fake offer that takes the honest sid first does not shadow the real
// offer, and the finish finds the right answer among the two
func TestSquattedSidDoesNotBlock(t *testing.T) {
	s, off := fixedSharer(t)
	c := mustCode("07 999 999")
	f, _ := NewSharer(&c, tInvA)
	fake, _, _ := f.Offer(tNow, nil)
	copy(fake[6:6+SidSize], off[6:6+SidSize])
	j := fixedJoiner(t, "07123456")
	if _, err := j.Answer(fake, tNow, nil); err != nil {
		t.Fatal(err)
	}
	real, err := j.Answer(off, tNow, nil)
	if err != nil || j.Tries() != 2 {
		t.Fatalf("real offer: %v, tries %d", err, j.Tries())
	}
	fin, _, err := s.Answer(real, tNow)
	if err != nil {
		t.Fatal(err)
	}
	if got, err := j.Finish(fin); err != nil || !bytes.Equal(got, tInvA) {
		t.Fatalf("finish: %v", err)
	}
}

// the tag does not cover the sealed bytes, so a broken seal under a good
// tag is anyone's copy: not a try, and the real answer still works
func TestTamperedSealNotATry(t *testing.T) {
	s, off := fixedSharer(t)
	j := fixedJoiner(t, "07123456")
	ans, _ := j.Answer(off, tNow, bytes.NewReader(tYb[:]))
	for i := range MaxTries + 1 {
		m := bytes.Clone(ans)
		m[len(m)-1-i] ^= 1
		if _, _, err := s.Answer(m, tNow); err != ErrFormat {
			t.Fatalf("tampered %d: %v", i, err)
		}
	}
	if s.Fails() != 0 {
		t.Fatalf("tampered seals counted %d", s.Fails())
	}
	if _, inv, err := s.Answer(ans, tNow); err != nil || !bytes.Equal(inv, tInvB) {
		t.Fatalf("real answer: %v", err)
	}
}

// every offer the sharer makes carries its window and an expiry that fits it
func TestOfferCarriesWindow(t *testing.T) {
	c := tCode
	for sec := int64(0); sec < 1200; sec += 7 {
		now := tNow.Add(time.Duration(sec) * time.Second)
		s, _ := NewSharer(&c, tInvA)
		off, w, err := s.Offer(now, nil)
		if err != nil {
			t.Fatal(err)
		}
		o, err := parseOffer(off)
		if err != nil || o.window != w || w != Window(now) {
			t.Fatalf("sec %d: %v, window %d of %d", sec, err, o.window, w)
		}
	}
	for _, e := range []uint32{0, 9, 10} {
		if expiresFits(e, 1<<63) || (e < 10 && expiresFits(e, 0)) {
			t.Fatalf("expires %d fits", e)
		}
	}
}

// a code typed again goes on from the tries its earlier joiner used
func TestJoinerAfterKeepsTries(t *testing.T) {
	c := mustCode("07123456")
	if _, err := NewJoinerAfter(&c, tInvB, MaxTries); err != ErrTries {
		t.Fatalf("a used-up code: %v", err)
	}
	j, err := NewJoinerAfter(&c, tInvB, MaxTries-1)
	if err != nil {
		t.Fatal(err)
	}
	for i := range 2 {
		s, _ := NewSharer(&c, tInvA)
		off, _, _ := s.Offer(tNow, nil)
		_, err := j.Answer(off, tNow, nil)
		if i == 0 && err != nil {
			t.Fatalf("the last try: %v", err)
		}
		if i == 1 && err != ErrTries {
			t.Fatalf("past the cap: %v", err)
		}
	}
}

// the marks around digits that ar and fa fields and copy-paste add are
// skipped like spaces (review I3); anything else still fails closed
func TestCodesSkipMarks(t *testing.T) {
	for _, m := range []string{"‎", "‏", "؜", "⁦", "⁧", "⁨", "⁩", " ", "‑", " "} {
		in := m + "07" + m + "123" + m + "456" + m
		c, err := ParseCode(in)
		if err != nil || c.String() != "07 123 456" {
			t.Fatalf("%U: %q %v", []rune(m)[0], c.String(), err)
		}
	}
	for _, in := range []string{"07​123456", "07‒123456", "07\xff123456"} {
		if _, err := ParseCode(in); !errors.Is(err, ErrCode) {
			t.Fatalf("%q taken", in)
		}
	}
}

// six digits are an older Kryfo's code, told apart from a mistyped one
func TestOldCode(t *testing.T) {
	for in, want := range map[string]bool{
		"482913": true, "482 913": true, "۴۸۲۹۱۳": true, "‎482-913": true,
		"48291": false, "4829134": false, "07123456": false, "48291x": false, "": false,
	} {
		if OldCode([]byte(in)) != want {
			t.Fatalf("%q: want %v", in, want)
		}
	}
}

func TestKindAndExpiry(t *testing.T) {
	_, off := fixedSharer(t)
	if Kind(off) != "KPO1" || Kind([]byte("KPA1x")) != "KPA1" || Kind([]byte("KPX1")) != "" || Kind(nil) != "" {
		t.Fatal("kinds")
	}
	e, err := OfferExpires(off)
	if err != nil || !e.After(tNow.Add(OfferLife)) || e.After(tNow.Add(OfferLife+Skew+time.Minute)) {
		t.Fatalf("expiry %v %v", e, err)
	}
	if _, err := OfferExpires(off[:10]); err == nil {
		t.Fatal("a cut offer has an expiry")
	}
}
