// SPDX-License-Identifier: GPL-3.0-or-later
package pake

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"io"
	"sync"
	"time"

	"golang.org/x/crypto/hkdf"
)

const (
	// MaxTries is the wrong answers a sharer takes, and the offers a joiner
	// answers, before the code is dead. each one is a single guess
	MaxTries = 3
	// MaxInvite is the largest sealed invite, as the registry's cap
	MaxInvite = 4096
	// OfferLife is how long an offer stays answerable
	OfferLife = WindowLength
	// Skew is the clock difference taken between the two phones
	Skew = 5 * time.Minute

	SidSize = 16
	TagSize = 32
	keySize = 32
	sealTag = 16

	magicOffer  = "KPO1"
	magicAnswer = "KPA1"
	magicFinish = "KPF1"

	// magic, flags, sid, ya, window, expires
	OfferSize = 4 + 2 + SidSize + PointSize + 8 + 4
	// magic, flags, sid, yb
	answerHead = 4 + 2 + SidSize + PointSize
	// then tag_b and the sealed length
	answerAAD = answerHead + TagSize + 2
	// magic, sid, tag_a, sealed length
	finishAAD = 4 + SidSize + TagSize + 2

	infoConfA = "kryfo-pair-v4:conf-a"
	infoConfB = "kryfo-pair-v4:conf-b"
	infoSealA = "kryfo-pair-v4:seal-a"
	infoSealB = "kryfo-pair-v4:seal-b"
)

var (
	ErrFormat = errors.New("pake: bad message")
	// ErrWrongCode is a tag that does not match: the other side has another
	// code, or someone guessed
	ErrWrongCode = errors.New("pake: wrong code")
	// ErrTries is a code past MaxTries: it is dead
	ErrTries   = errors.New("pake: too many tries")
	ErrExpired = errors.New("pake: offer out of its time")
	ErrUnknown = errors.New("pake: not our offer")
	ErrDone    = errors.New("pake: already paired")
	ErrInvite  = errors.New("pake: invite size")
)

type offer struct {
	sid     [SidSize]byte
	ya      [PointSize]byte
	window  uint64
	expires uint32
}

// windowMinutes is one window in the unit of expires
const windowMinutes = uint64(WindowLength / time.Minute)

// expiresFits is the sharer's rule: expires is now + OfferLife rounded up
// to the minute, so it falls in [w+1, w+2] windows, counted in minutes
func expiresFits(e uint32, w uint64) bool {
	m := uint64(e)
	if m < windowMinutes {
		return false
	}
	if m/windowMinutes-1 == w {
		return true
	}
	return m%windowMinutes == 0 && m >= 2*windowMinutes && m/windowMinutes-2 == w
}

func (o *offer) encode() []byte {
	b := make([]byte, 0, OfferSize)
	b = append(b, magicOffer...)
	b = append(b, 0, 0)
	b = append(b, o.sid[:]...)
	b = append(b, o.ya[:]...)
	b = binary.BigEndian.AppendUint64(b, o.window)
	return binary.BigEndian.AppendUint32(b, o.expires)
}

// ada is the offer without ya
func (o *offer) ada() []byte {
	b := make([]byte, 0, OfferSize-PointSize)
	b = append(b, magicOffer...)
	b = append(b, 0, 0)
	b = append(b, o.sid[:]...)
	b = binary.BigEndian.AppendUint64(b, o.window)
	return binary.BigEndian.AppendUint32(b, o.expires)
}

func parseOffer(m []byte) (offer, error) {
	var o offer
	if len(m) != OfferSize || string(m[:4]) != magicOffer || m[4] != 0 || m[5] != 0 {
		return o, ErrFormat
	}
	copy(o.sid[:], m[6:22])
	copy(o.ya[:], m[22:54])
	o.window = binary.BigEndian.Uint64(m[54:62])
	o.expires = binary.BigEndian.Uint32(m[62:66])
	if !canonical(o.ya[:]) || !expiresFits(o.expires, o.window) {
		return o, ErrFormat
	}
	return o, nil
}

type answer struct {
	sid    [SidSize]byte
	yb     [PointSize]byte
	tag    [TagSize]byte
	sealed []byte
}

func answerHeader(sid, yb []byte) []byte {
	b := make([]byte, 0, answerHead)
	b = append(b, magicAnswer...)
	b = append(b, 0, 0)
	b = append(b, sid...)
	return append(b, yb...)
}

// adb is the answer header without yb
func adb(sid []byte) []byte {
	return answerHeader(sid, nil)
}

func parseAnswer(m []byte) (answer, error) {
	var a answer
	if len(m) < answerAAD || string(m[:4]) != magicAnswer || m[4] != 0 || m[5] != 0 {
		return a, ErrFormat
	}
	n := int(binary.BigEndian.Uint16(m[answerAAD-2 : answerAAD]))
	if len(m) != answerAAD+n || !sealedSize(n) {
		return a, ErrFormat
	}
	copy(a.sid[:], m[6:22])
	copy(a.yb[:], m[22:54])
	copy(a.tag[:], m[54:86])
	a.sealed = m[answerAAD:]
	if !canonical(a.yb[:]) {
		return a, ErrFormat
	}
	return a, nil
}

type finish struct {
	sid    [SidSize]byte
	tag    [TagSize]byte
	sealed []byte
}

func parseFinish(m []byte) (finish, error) {
	var f finish
	if len(m) < finishAAD || string(m[:4]) != magicFinish {
		return f, ErrFormat
	}
	n := int(binary.BigEndian.Uint16(m[finishAAD-2 : finishAAD]))
	if len(m) != finishAAD+n || !sealedSize(n) {
		return f, ErrFormat
	}
	copy(f.sid[:], m[4:20])
	copy(f.tag[:], m[20:52])
	f.sealed = m[finishAAD:]
	return f, nil
}

func sealedSize(n int) bool { return n > sealTag && n <= MaxInvite+sealTag }

// keys are the four that come out of one run
type keys struct {
	confA, confB, sealA, sealB [keySize]byte
}

func (k *keys) wipe() {
	wipe(k.confA[:])
	wipe(k.confB[:])
	wipe(k.sealA[:])
	wipe(k.sealB[:])
}

// deriveKeys is hkdf-sha256 over the isk, salted with the offer and the
// answer header
func deriveKeys(isk *[ISKSize]byte, offerMsg, head []byte) (*keys, error) {
	h := sha256.New()
	h.Write(offerMsg)
	h.Write(head)
	salt := h.Sum(nil)
	k := new(keys)
	for _, p := range []struct {
		info string
		out  []byte
	}{
		{infoConfA, k.confA[:]},
		{infoConfB, k.confB[:]},
		{infoSealA, k.sealA[:]},
		{infoSealB, k.sealB[:]},
	} {
		if _, err := io.ReadFull(hkdf.New(sha256.New, isk[:], salt, []byte(p.info)), p.out); err != nil {
			k.wipe()
			return nil, err
		}
	}
	return k, nil
}

// tag_b = hmac(k_conf_b, "b" || offer || answer header)
func tagB(k *keys, offerMsg, head []byte) []byte {
	m := hmac.New(sha256.New, k.confB[:])
	m.Write([]byte("b"))
	m.Write(offerMsg)
	m.Write(head)
	return m.Sum(nil)
}

// tag_a = hmac(k_conf_a, "a" || offer || answer header || tag_b)
func tagA(k *keys, offerMsg, head, tb []byte) []byte {
	m := hmac.New(sha256.New, k.confA[:])
	m.Write([]byte("a"))
	m.Write(offerMsg)
	m.Write(head)
	m.Write(tb)
	return m.Sum(nil)
}

// each seal key seals one invite, so the zero nonce never repeats
func gcm(key *[keySize]byte) cipher.AEAD {
	b, err := aes.NewCipher(key[:])
	if err != nil {
		panic("pake: aes-256 key refused")
	}
	g, err := cipher.NewGCM(b)
	if err != nil {
		panic("pake: gcm refused")
	}
	return g
}

var zeroNonce [12]byte

// seal appends the sealed length and the sealed invite to aad, which ends
// where the length goes
func seal(key *[keySize]byte, aad, invite []byte) []byte {
	g := gcm(key)
	aad = binary.BigEndian.AppendUint16(aad, uint16(len(invite)+g.Overhead()))
	return g.Seal(aad, zeroNonce[:], invite, aad)
}

func open(key *[keySize]byte, msg []byte, aadLen int) ([]byte, error) {
	return gcm(key).Open(nil, zeroNonce[:], msg[aadLen:], msg[:aadLen])
}

func checkInvite(invite []byte) error {
	if len(invite) == 0 || len(invite) > MaxInvite {
		return ErrInvite
	}
	return nil
}

func expiresAt(o *offer) time.Time { return time.Unix(int64(o.expires)*60, 0) }

// run is everything one side needs after K: the isk and the four keys
func run(sid, k, ya, ada, yb, adbytes, offerMsg, head []byte) (*keys, error) {
	i := isk(sid, k, ya, ada, yb, adbytes)
	defer wipe(i[:])
	return deriveKeys(&i, offerMsg, head)
}

func randomScalar(rnd io.Reader) (*[ScalarSize]byte, error) {
	y := new([ScalarSize]byte)
	if _, err := io.ReadFull(rnd, y[:]); err != nil {
		return nil, err
	}
	return y, nil
}

func orRand(rnd io.Reader) io.Reader {
	if rnd == nil {
		return rand.Reader
	}
	return rnd
}

// sharerOffer is one offer the sharer has up, with its scalar
type sharerOffer struct {
	o   offer
	msg []byte
	y   *[ScalarSize]byte
}

func (so *sharerOffer) wipe() {
	if so.y != nil {
		wipe(so.y[:])
	}
}

// Sharer shows the code and puts up offers. it takes MaxTries wrong
// answers over all its offers, then the code is dead
type Sharer struct {
	mu     sync.Mutex
	box    [BoxDigits]byte
	prs    []byte
	invite []byte
	offers []*sharerOffer
	fails  int
	seen   map[[32]byte]bool
	done   bool
	dead   bool
}

// NewSharer copies the code and the invite to seal; the caller can wipe
// its own code after
func NewSharer(c *Code, invite []byte) (*Sharer, error) {
	if err := checkInvite(invite); err != nil {
		return nil, err
	}
	return &Sharer{
		box:    c.box,
		prs:    bytes.Clone(c.secret[:]),
		invite: bytes.Clone(invite),
		seen:   map[[32]byte]bool{},
	}, nil
}

// Offer is the offer for the window now falls in, made once per window.
// the one from the window before stays answerable until it expires
func (s *Sharer) Offer(now time.Time, rnd io.Reader) ([]byte, uint64, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := s.closed(); err != nil {
		return nil, 0, err
	}
	w := Window(now)
	for _, so := range s.offers {
		if so.o.window == w {
			return bytes.Clone(so.msg), w, nil
		}
	}
	rnd = orRand(rnd)
	so := &sharerOffer{o: offer{window: w}}
	if _, err := io.ReadFull(rnd, so.o.sid[:]); err != nil {
		return nil, 0, err
	}
	y, err := randomScalar(rnd)
	if err != nil {
		return nil, 0, err
	}
	so.y = y
	ci := channelID(s.box, w)
	g := generator(s.prs, ci, so.o.sid[:])
	so.o.ya, err = scalarMult(so.y, g[:])
	wipe(g[:])
	if err != nil {
		so.wipe()
		return nil, 0, err
	}
	so.o.expires = uint32((now.Add(OfferLife).Unix() + 59) / 60)
	so.msg = so.o.encode()
	// a newer offer pushes out all but the one before it
	for len(s.offers) > 1 {
		s.offers[0].wipe()
		s.offers = s.offers[1:]
	}
	s.offers = append(s.offers, so)
	return bytes.Clone(so.msg), w, nil
}

// Answer checks a joiner's answer. on a good tag it gives the finish to
// publish and the joiner's invite. a wrong tag counts as a try; a message
// that does not parse, names no offer of ours, comes again or has a good
// tag on a broken seal does not
func (s *Sharer) Answer(msg []byte, now time.Time) (fin, invite []byte, err error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := s.closed(); err != nil {
		return nil, nil, err
	}
	a, err := parseAnswer(msg)
	if err != nil {
		return nil, nil, err
	}
	var so *sharerOffer
	for _, x := range s.offers {
		if x.o.sid == a.sid {
			so = x
		}
	}
	if so == nil {
		return nil, nil, ErrUnknown
	}
	if now.After(expiresAt(&so.o).Add(Skew)) {
		return nil, nil, ErrExpired
	}
	h := sha256.Sum256(msg)
	if s.seen[h] {
		return nil, nil, ErrWrongCode
	}
	k, err := scalarMult(so.y, a.yb[:])
	if err != nil {
		return nil, nil, err
	}
	head := answerHeader(a.sid[:], a.yb[:])
	ks, err := run(a.sid[:], k[:], so.o.ya[:], so.o.ada(), a.yb[:], adb(a.sid[:]), so.msg, head)
	wipe(k[:])
	if err != nil {
		return nil, nil, err
	}
	defer ks.wipe()
	tb := tagB(ks, so.msg, head)
	if !hmac.Equal(tb, a.tag[:]) {
		return nil, nil, s.fail(h)
	}
	invite, err = open(&ks.sealB, msg, answerAAD)
	if err != nil || checkInvite(invite) != nil {
		// the tag does not cover the sealed bytes, so anyone can break the
		// seal of an honest answer: no guess, not a try, keep waiting
		wipe(invite)
		return nil, nil, ErrFormat
	}
	fh := make([]byte, 0, finishAAD+len(s.invite)+sealTag)
	fh = append(fh, magicFinish...)
	fh = append(fh, a.sid[:]...)
	fh = append(fh, tagA(ks, so.msg, head, tb)...)
	fin = seal(&ks.sealA, fh, s.invite)
	s.done = true
	s.wipe()
	return fin, invite, nil
}

func (s *Sharer) fail(h [32]byte) error {
	s.seen[h] = true
	s.fails++
	if s.fails >= MaxTries {
		s.dead = true
		s.wipe()
		return ErrTries
	}
	return ErrWrongCode
}

func (s *Sharer) closed() error {
	if s.done {
		return ErrDone
	}
	if s.dead {
		return ErrTries
	}
	return nil
}

// Fails is the wrong answers so far
func (s *Sharer) Fails() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.fails
}

// Close wipes the code, the scalars and the invite; the sharer takes
// nothing after
func (s *Sharer) Close() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !s.done {
		s.dead = true
	}
	s.wipe()
}

func (s *Sharer) wipe() {
	wipe(s.prs)
	wipe(s.invite)
	for _, so := range s.offers {
		so.wipe()
	}
	s.offers = nil
}

// pending is an offer the joiner answered, waiting for its finish
type pending struct {
	sid      [SidSize]byte
	offerMsg []byte
	answer   []byte
	head     []byte
	tb       []byte
	confA    [keySize]byte
	sealA    [keySize]byte
}

func (p *pending) wipe() {
	wipe(p.confA[:])
	wipe(p.sealA[:])
}

// Joiner has the code typed and answers offers in its box: MaxTries of
// them, since a fake offer gets one guess from each answer
type Joiner struct {
	mu       sync.Mutex
	box      [BoxDigits]byte
	prs      []byte
	invite   []byte
	answered int
	// by the offer's hash, so a fake offer on an honest sid cannot shadow
	// the real one
	pend map[[32]byte]*pending
	done bool
	dead bool
}

// NewJoiner copies the code and the invite to seal
func NewJoiner(c *Code, invite []byte) (*Joiner, error) {
	if err := checkInvite(invite); err != nil {
		return nil, err
	}
	return &Joiner{
		box:    c.box,
		prs:    bytes.Clone(c.secret[:]),
		invite: bytes.Clone(invite),
		pend:   map[[32]byte]*pending{},
	}, nil
}

// Answer answers an offer found at the box. ci takes the window the offer
// carries, so the address it was read from does not matter. the same offer
// again gets the same answer and costs no try
func (j *Joiner) Answer(msg []byte, now time.Time, rnd io.Reader) ([]byte, error) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if err := j.closed(); err != nil {
		return nil, err
	}
	o, err := parseOffer(msg)
	if err != nil {
		return nil, err
	}
	key := sha256.Sum256(msg)
	if p := j.pend[key]; p != nil {
		return bytes.Clone(p.answer), nil
	}
	if j.answered >= MaxTries {
		return nil, ErrTries
	}
	// a window or an expiry this phone would not have read is refused
	// before it costs a try
	if o.window+1 < Window(now.Add(-Skew)) || o.window > Window(now.Add(Skew)) {
		return nil, ErrExpired
	}
	exp := expiresAt(&o)
	if now.After(exp.Add(Skew)) || exp.After(now.Add(OfferLife+Skew)) {
		return nil, ErrExpired
	}
	rnd = orRand(rnd)
	y, err := randomScalar(rnd)
	if err != nil {
		return nil, err
	}
	defer wipe(y[:])
	g := generator(j.prs, channelID(j.box, o.window), o.sid[:])
	yb, err := scalarMult(y, g[:])
	wipe(g[:])
	if err != nil {
		return nil, err
	}
	k, err := scalarMult(y, o.ya[:])
	if err != nil {
		return nil, err
	}
	head := answerHeader(o.sid[:], yb[:])
	ks, err := run(o.sid[:], k[:], o.ya[:], o.ada(), yb[:], adb(o.sid[:]), msg, head)
	wipe(k[:])
	if err != nil {
		return nil, err
	}
	defer ks.wipe()
	j.answered++
	tb := tagB(ks, msg, head)
	ah := make([]byte, 0, answerAAD+len(j.invite)+sealTag)
	ah = append(ah, head...)
	ah = append(ah, tb...)
	out := seal(&ks.sealB, ah, j.invite)
	p := &pending{sid: o.sid, offerMsg: bytes.Clone(msg), answer: out, head: head, tb: tb}
	p.confA = ks.confA
	p.sealA = ks.sealA
	j.pend[key] = p
	return bytes.Clone(out), nil
}

// Finish checks the sharer's finish and gives its invite. a wrong tag
// says nothing about the code, since anyone who sees the box can send one,
// so it leaves the answer waiting
func (j *Joiner) Finish(msg []byte) ([]byte, error) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if err := j.closed(); err != nil {
		return nil, err
	}
	f, err := parseFinish(msg)
	if err != nil {
		return nil, err
	}
	// a sid can have more than one pending answer (a fake offer on it),
	// so each one gets the tag check
	err = ErrUnknown
	for _, p := range j.pend {
		if p.sid != f.sid {
			continue
		}
		err = ErrWrongCode
		if invite := p.finish(msg, f.tag[:]); invite != nil {
			j.done = true
			j.wipe()
			return invite, nil
		}
	}
	return nil, err
}

// finish is the invite when the tag and the seal are both good
func (p *pending) finish(msg, tag []byte) []byte {
	ks := &keys{confA: p.confA}
	defer ks.wipe()
	if !hmac.Equal(tagA(ks, p.offerMsg, p.head, p.tb), tag) {
		return nil
	}
	invite, err := open(&p.sealA, msg, finishAAD)
	if err != nil || checkInvite(invite) != nil {
		wipe(invite)
		return nil
	}
	return invite
}

func (j *Joiner) closed() error {
	if j.done {
		return ErrDone
	}
	if j.dead {
		return ErrTries
	}
	return nil
}

// Tries is the offers answered so far
func (j *Joiner) Tries() int {
	j.mu.Lock()
	defer j.mu.Unlock()
	return j.answered
}

// Close wipes the code, the keys and the invite
func (j *Joiner) Close() {
	j.mu.Lock()
	defer j.mu.Unlock()
	if !j.done {
		j.dead = true
	}
	j.wipe()
}

func (j *Joiner) wipe() {
	wipe(j.prs)
	wipe(j.invite)
	for k, p := range j.pend {
		p.wipe()
		delete(j.pend, k)
	}
}
