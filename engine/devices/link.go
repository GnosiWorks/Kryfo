// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/ecdh"
	"crypto/hkdf"
	"crypto/mlkem"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"strings"
	"time"
)

// linking a new device: offer (qr), answer, reveal, six digits compared by
// the person, then the welcome. the joiner commits to its nonce before it
// sees the phone's key, so the digits cannot be ground

const (
	offerMagic   = "KLO2"
	acceptMagic  = "KLA2"
	revealMagic  = "KLR2"
	welcomeMagic = "KLW2"

	// OfferPrefix starts an offer as text, for a qr code
	OfferPrefix = "kryfo-link:"

	// LinkLife is how long a link may take, by each side's own clock
	LinkLife = 10 * time.Minute
	// the most an offer's expiry may run ahead of the phone's clock
	maxAhead = time.Hour

	offerSize   = 4 + 32 + 32 + 8
	acceptSize  = 4 + 32 + mlkem.EncapsulationKeySize1024
	revealPlain = 32 + KeySize + 4
	revealSize  = 4 + mlkem.CiphertextSize1024 + revealPlain + 16
	// StreamKeySize is the history stream's key
	StreamKeySize = 32
	welcomePlain  = StreamKeySize + KeySize
	welcomeSize   = 4 + welcomePlain + 16

	labelTranscript = "kryfo-link-v2 transcript"
	labelCommit     = "kryfo-link-v2 commit"
	labelSAS        = "kryfo-link-v2 sas"
	labelBind       = "kryfo-link-v2 bind"
	labelN2P        = "kryfo-link-v2 joiner to phone"
	labelP2N        = "kryfo-link-v2 phone to joiner"
)

var (
	ErrState   = errors.New("devices: not now in this link")
	ErrExpired = errors.New("devices: link expired")
	ErrCommit  = errors.New("devices: nonce does not match the offer")
	ErrOpen    = errors.New("devices: does not open")
)

type linkState int

const (
	stOffered linkState = iota
	stAccepted
	stRevealed
	stConfirmed
	stDone
	stFailed
)

// a hash over labelled parts, each part's length first so no two splits of
// one byte string hash alike
func linkHash(label string, parts ...[]byte) [32]byte {
	h := sha256.New()
	h.Write([]byte(label))
	h.Write([]byte{0})
	for _, p := range parts {
		var n [4]byte
		binary.BigEndian.PutUint32(n[:], uint32(len(p)))
		h.Write(n[:])
		h.Write(p)
	}
	var out [32]byte
	copy(out[:], h.Sum(nil))
	return out
}

func commitOf(nonce []byte) [32]byte { return linkHash(labelCommit, nonce) }

// six digits from the offer, the answer and the committed nonce alone. the
// reveal's other fields stay out: the joiner picks them after the nonce is
// fixed, and they travel sealed under the key the digits confirm
func sasOf(offer, accept, nonce []byte) string {
	d := linkHash(labelSAS, offer, accept, nonce)
	return fmt.Sprintf("%06d", binary.BigEndian.Uint64(d[:8])%1000000)
}

func x25519Key(eph *ecdh.PrivateKey, peer []byte) ([]byte, error) {
	p, err := ecdh.X25519().NewPublicKey(peer)
	if err != nil {
		return nil, ErrMalformed
	}
	// a low-order key gives the all-zero secret, which ecdh refuses
	s, err := eph.ECDH(p)
	if err != nil {
		return nil, ErrMalformed
	}
	return s, nil
}

func revealKey(dh []byte, th0 [32]byte) ([]byte, error) {
	return hkdf.Key(sha256.New, dh, th0[:], labelN2P, 32)
}

// the welcome needs both secrets: a recorded link stays closed to anyone
// who later breaks x25519
func welcomeKey(dh, kem []byte, bind [32]byte) ([]byte, error) {
	ikm := append(append([]byte(nil), dh...), kem...)
	defer wipe(ikm)
	return hkdf.Key(sha256.New, ikm, bind[:], labelP2N, 32)
}

// each key seals exactly one message, so a zero nonce is safe
var zeroNonce = make([]byte, 12)

func sealOnce(key, plain, ad []byte) ([]byte, error) {
	c, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	g, err := cipher.NewGCM(c)
	if err != nil {
		return nil, err
	}
	return g.Seal(nil, zeroNonce, plain, ad), nil
}

func openOnce(key, ct, ad []byte) ([]byte, error) {
	c, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	g, err := cipher.NewGCM(c)
	if err != nil {
		return nil, err
	}
	p, err := g.Open(nil, zeroNonce, ct, ad)
	if err != nil {
		return nil, ErrOpen
	}
	return p, nil
}

func adOf(magic string, t [32]byte, more ...[]byte) []byte {
	ad := append([]byte(magic), t[:]...)
	for _, m := range more {
		ad = append(ad, m...)
	}
	return ad
}

// Joiner is the new device's side of a link.
type Joiner struct {
	st      linkState
	key     Key
	reg     uint32
	eph     *ecdh.PrivateKey
	nonce   []byte
	offer   []byte
	expires time.Time
	dh      []byte
	kem     []byte
	bind    [32]byte
	sas     string
}

// StartJoin begins a link for a new device. key and reg are a fresh
// libsignal key and registration id made for this link; they become the
// device's keys for the identity the welcome names.
func StartJoin(key Key, reg uint32, now time.Time) (*Joiner, error) {
	if key[0] != 0x05 || !canonicalU(key[1:]) || reg == 0 || reg > MaxReg {
		return nil, ErrMalformed
	}
	eph, err := ecdh.X25519().GenerateKey(rand.Reader)
	if err != nil {
		return nil, err
	}
	j := &Joiner{key: key, reg: reg, eph: eph, nonce: make([]byte, 32)}
	if _, err := io.ReadFull(rand.Reader, j.nonce); err != nil {
		return nil, err
	}
	j.expires = now.Add(LinkLife)
	c := commitOf(j.nonce)
	j.offer = append([]byte(offerMagic), eph.PublicKey().Bytes()...)
	j.offer = append(j.offer, c[:]...)
	j.offer = binary.BigEndian.AppendUint64(j.offer, uint64(j.expires.Unix()))
	return j, nil
}

// Offer is what the new device shows.
func (j *Joiner) Offer() []byte { return append([]byte(nil), j.offer...) }

// OfferText is the offer as text for a qr code.
func (j *Joiner) OfferText() string {
	return OfferPrefix + base64.RawURLEncoding.EncodeToString(j.offer)
}

func (j *Joiner) fail(err error) error {
	j.st = stFailed
	j.forget()
	return err
}

func (j *Joiner) forget() {
	wipe(j.nonce)
	wipe(j.dh)
	wipe(j.kem)
	j.eph = nil
}

// HandleAccept takes the phone's answer and gives the reveal to send back.
func (j *Joiner) HandleAccept(msg []byte, now time.Time) ([]byte, error) {
	if j.st != stOffered {
		return nil, ErrState
	}
	if now.After(j.expires) {
		return nil, j.fail(ErrExpired)
	}
	if len(msg) != acceptSize || string(msg[:4]) != acceptMagic {
		return nil, j.fail(ErrMalformed)
	}
	dh, err := x25519Key(j.eph, msg[4:36])
	if err != nil {
		return nil, j.fail(err)
	}
	j.dh = dh
	ek, err := mlkem.NewEncapsulationKey1024(msg[36:])
	if err != nil {
		return nil, j.fail(ErrMalformed)
	}
	kem, ct := ek.Encapsulate()
	j.kem = kem
	th0 := linkHash(labelTranscript, j.offer, msg)
	k, err := revealKey(dh, th0)
	if err != nil {
		return nil, j.fail(err)
	}
	defer wipe(k)
	pt := append([]byte(nil), j.nonce...)
	pt = append(pt, j.key[:]...)
	pt = binary.BigEndian.AppendUint32(pt, j.reg)
	sealed, err := sealOnce(k, pt, adOf(revealMagic, th0, ct))
	wipe(pt)
	if err != nil {
		return nil, j.fail(err)
	}
	out := append([]byte(revealMagic), ct...)
	out = append(out, sealed...)
	j.sas = sasOf(j.offer, msg, j.nonce)
	j.bind = linkHash(labelBind, th0[:], out)
	j.st = stRevealed
	return out, nil
}

// SAS is the six digits to compare with the phone's screen.
func (j *Joiner) SAS() (string, error) {
	if j.st != stRevealed && j.st != stConfirmed {
		return "", ErrState
	}
	return j.sas, nil
}

// Confirm is the person saying the digits match.
func (j *Joiner) Confirm() error {
	if j.st != stRevealed {
		return ErrState
	}
	j.st = stConfirmed
	return nil
}

// Abort ends the link and forgets its secrets.
func (j *Joiner) Abort() {
	if j.st != stDone {
		j.st = stFailed
	}
	j.forget()
}

// Linked is what a new device comes away with. the identity is public; the
// stream key is the only secret the link hands over.
type Linked struct {
	Identity  Key
	Keys      DeviceKeys
	StreamKey [StreamKeySize]byte
	// Bind is the link's transcript, which the history stream is bound to
	Bind [32]byte
}

// KeyNumber is the number the new device shows after linking, to check
// against the one the phone shows for itself.
func (l *Linked) KeyNumber() string { return KeyNumber(l.Identity) }

// Forget wipes the stream key.
func (l *Linked) Forget() { wipe(l.StreamKey[:]) }

// HandleWelcome takes the phone's welcome, once the person has confirmed.
func (j *Joiner) HandleWelcome(msg []byte, now time.Time) (*Linked, error) {
	if j.st != stConfirmed {
		return nil, ErrState
	}
	if now.After(j.expires) {
		return nil, j.fail(ErrExpired)
	}
	if len(msg) != welcomeSize || string(msg[:4]) != welcomeMagic {
		return nil, j.fail(ErrMalformed)
	}
	k, err := welcomeKey(j.dh, j.kem, j.bind)
	if err != nil {
		return nil, j.fail(err)
	}
	defer wipe(k)
	pt, err := openOnce(k, msg[4:], adOf(welcomeMagic, j.bind))
	if err != nil {
		return nil, j.fail(err)
	}
	defer wipe(pt)
	identity, err := ParseKey(pt[StreamKeySize:])
	if err != nil || identity == j.key {
		return nil, j.fail(ErrMalformed)
	}
	out := &Linked{
		Identity: identity,
		Keys:     DeviceKeys{Identity: identity, Key: j.key, Reg: j.reg},
		Bind:     j.bind,
	}
	copy(out.StreamKey[:], pt[:StreamKeySize])
	j.st = stDone
	j.forget()
	return out, nil
}

// ParseOfferText reads an offer shown as text.
func ParseOfferText(s string) ([]byte, error) {
	s, ok := strings.CutPrefix(strings.TrimSpace(s), OfferPrefix)
	if !ok || len(s) > 2*offerSize {
		return nil, ErrMalformed
	}
	b, err := base64.RawURLEncoding.Strict().DecodeString(s)
	if err != nil || len(b) != offerSize || string(b[:4]) != offerMagic {
		return nil, ErrMalformed
	}
	return b, nil
}

// Linker is the phone's side of a link.
type Linker struct {
	st       linkState
	identity Key
	eph      *ecdh.PrivateKey
	dk       *mlkem.DecapsulationKey1024
	offer    []byte
	accept   []byte
	commit   [32]byte
	deadline time.Time
	dh       []byte
	kem      []byte
	bind     [32]byte
	device   DeviceKeys
	sas      string
}

// AcceptOffer starts the phone's side from an offer it scanned, for the
// identity the new device joins, and gives the answer to send.
func AcceptOffer(offer []byte, identity Key, now time.Time) (*Linker, []byte, error) {
	if len(offer) != offerSize || string(offer[:4]) != offerMagic {
		return nil, nil, ErrMalformed
	}
	if identity[0] != 0x05 || !canonicalU(identity[1:]) {
		return nil, nil, ErrKey
	}
	exp := binary.BigEndian.Uint64(offer[68:])
	if exp > uint64(now.Add(maxAhead).Unix()) {
		return nil, nil, ErrMalformed
	}
	// the clocks need not agree, so the phone keeps to its own as well:
	// never longer than a link's life from now
	deadline := now.Add(LinkLife)
	if t := time.Unix(int64(exp), 0); t.Before(deadline) {
		deadline = t
	}
	if !now.Before(deadline) {
		return nil, nil, ErrExpired
	}
	eph, err := ecdh.X25519().GenerateKey(rand.Reader)
	if err != nil {
		return nil, nil, err
	}
	dh, err := x25519Key(eph, offer[4:36])
	if err != nil {
		return nil, nil, err
	}
	dk, err := mlkem.GenerateKey1024()
	if err != nil {
		wipe(dh)
		return nil, nil, err
	}
	accept := append([]byte(acceptMagic), eph.PublicKey().Bytes()...)
	accept = append(accept, dk.EncapsulationKey().Bytes()...)
	p := &Linker{
		st:       stAccepted,
		identity: identity,
		eph:      eph,
		dk:       dk,
		offer:    append([]byte(nil), offer...),
		accept:   accept,
		deadline: deadline,
		dh:       dh,
	}
	copy(p.commit[:], offer[36:68])
	return p, append([]byte(nil), accept...), nil
}

func (p *Linker) fail(err error) error {
	p.st = stFailed
	p.forget()
	return err
}

func (p *Linker) forget() {
	wipe(p.dh)
	wipe(p.kem)
	p.eph = nil
	p.dk = nil
}

// HandleReveal takes the new device's reveal. after it the digits can be
// shown, and Device says which key asks to be linked.
func (p *Linker) HandleReveal(msg []byte, now time.Time) error {
	if p.st != stAccepted {
		return ErrState
	}
	if !now.Before(p.deadline) {
		return p.fail(ErrExpired)
	}
	if len(msg) != revealSize || string(msg[:4]) != revealMagic {
		return p.fail(ErrMalformed)
	}
	ct := msg[4 : 4+mlkem.CiphertextSize1024]
	th0 := linkHash(labelTranscript, p.offer, p.accept)
	k, err := revealKey(p.dh, th0)
	if err != nil {
		return p.fail(err)
	}
	defer wipe(k)
	pt, err := openOnce(k, msg[4+mlkem.CiphertextSize1024:], adOf(revealMagic, th0, ct))
	if err != nil {
		return p.fail(err)
	}
	defer wipe(pt)
	nonce := pt[:32]
	c := commitOf(nonce)
	if subtle.ConstantTimeCompare(c[:], p.commit[:]) != 1 {
		return p.fail(ErrCommit)
	}
	key, err := ParseKey(pt[32 : 32+KeySize])
	reg := binary.BigEndian.Uint32(pt[32+KeySize:])
	if err != nil || key == p.identity || reg == 0 || reg > MaxReg {
		return p.fail(ErrMalformed)
	}
	kem, err := p.dk.Decapsulate(ct)
	if err != nil {
		return p.fail(ErrMalformed)
	}
	p.kem = kem
	p.dk = nil
	p.device = DeviceKeys{Identity: p.identity, Key: key, Reg: reg}
	p.sas = sasOf(p.offer, p.accept, nonce)
	p.bind = linkHash(labelBind, th0[:], msg)
	p.st = stRevealed
	return nil
}

// Device is the new device's keys for the identity, for its list entry.
func (p *Linker) Device() (DeviceKeys, error) {
	if p.st != stRevealed && p.st != stConfirmed {
		return DeviceKeys{}, ErrState
	}
	return p.device, nil
}

// SAS is the six digits to compare with the new device's screen.
func (p *Linker) SAS() (string, error) {
	if p.st != stRevealed && p.st != stConfirmed {
		return "", ErrState
	}
	return p.sas, nil
}

// Bind is the link's transcript, for the history stream.
func (p *Linker) Bind() ([32]byte, error) {
	if p.st != stRevealed && p.st != stConfirmed {
		return [32]byte{}, ErrState
	}
	return p.bind, nil
}

// KeyNumber is the identity's number, which the new device shows too.
func (p *Linker) KeyNumber() string { return KeyNumber(p.identity) }

// Confirm is the person saying the digits match.
func (p *Linker) Confirm(now time.Time) error {
	if p.st != stRevealed {
		return ErrState
	}
	if !now.Before(p.deadline) {
		return p.fail(ErrExpired)
	}
	p.st = stConfirmed
	return nil
}

// Abort ends the link and forgets its secrets.
func (p *Linker) Abort() {
	if p.st != stDone {
		p.st = stFailed
	}
	p.forget()
}

// Welcome seals the history stream's key and the identity for the new
// device. the caller makes the stream key with NewStreamKey and wipes it
// once the stream is sent.
func (p *Linker) Welcome(stream *[StreamKeySize]byte, now time.Time) ([]byte, error) {
	if p.st != stConfirmed {
		return nil, ErrState
	}
	if !now.Before(p.deadline) {
		return nil, p.fail(ErrExpired)
	}
	k, err := welcomeKey(p.dh, p.kem, p.bind)
	if err != nil {
		return nil, p.fail(err)
	}
	defer wipe(k)
	pt := append(append([]byte(nil), stream[:]...), p.identity[:]...)
	ct, err := sealOnce(k, pt, adOf(welcomeMagic, p.bind))
	wipe(pt)
	if err != nil {
		return nil, p.fail(err)
	}
	p.st = stDone
	p.forget()
	return append([]byte(welcomeMagic), ct...), nil
}

// NewStreamKey is a fresh key for one history stream.
func NewStreamKey() (*[StreamKeySize]byte, error) {
	var k [StreamKeySize]byte
	if _, err := io.ReadFull(rand.Reader, k[:]); err != nil {
		return nil, err
	}
	return &k, nil
}
