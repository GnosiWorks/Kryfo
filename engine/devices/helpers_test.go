// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"crypto/ecdh"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"errors"
	"io"
	mrand "math/rand/v2"
	"sync"
	"testing"
)

// a stand-in for the shim's ks_sign and ks_verify_ctx: randomised 64-byte
// signatures that only the key's holder can make, the same prefix and
// context text, the same context table, and the body rules phase 2 adds
// (the body parses, and its identity is the signer)
type shim struct {
	mu      sync.Mutex
	secrets map[Key][]byte
}

func newShim() *shim { return &shim{secrets: map[Key][]byte{}} }

// an identity key as the phone holds it, inside the stand-in
type identity struct {
	pub  Key
	priv []byte
	s    *shim
}

func newKey(t testing.TB) (Key, []byte) {
	t.Helper()
	p, err := ecdh.X25519().GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	var k Key
	k[0] = 0x05
	copy(k[1:], p.PublicKey().Bytes())
	return k, p.Bytes()
}

// a key from fixed private bytes, for vectors
func fixedKey(t testing.TB, seed byte) Key {
	t.Helper()
	priv := bytes.Repeat([]byte{seed}, 32)
	p, err := ecdh.X25519().NewPrivateKey(priv)
	if err != nil {
		t.Fatal(err)
	}
	var k Key
	k[0] = 0x05
	copy(k[1:], p.PublicKey().Bytes())
	return k
}

func (s *shim) identity(t testing.TB) *identity {
	t.Helper()
	pub, priv := newKey(t)
	sec := make([]byte, 32)
	rand.Read(sec)
	s.mu.Lock()
	s.secrets[pub] = sec
	s.mu.Unlock()
	return &identity{pub: pub, priv: priv, s: s}
}

func signedText(context string, body []byte) []byte {
	t := []byte("kryfo-sig-v1")
	t = append(t, 0)
	t = append(t, context...)
	t = append(t, 0)
	return append(t, body...)
}

func bodyFits(signer Key, context string, body []byte) bool {
	if context != ContextList || !bytes.HasPrefix(body, []byte(listMagic)) {
		return false
	}
	// parse before sign: the body is a list without its signature, and
	// the list's identity is the signing key
	l, err := ParseList(append(bytes.Clone(body), make([]byte, SigSize)...))
	return err == nil && l.Identity == signer
}

func (s *shim) mac(pub Key, context string, body, r []byte) ([]byte, bool) {
	s.mu.Lock()
	sec, ok := s.secrets[pub]
	s.mu.Unlock()
	if !ok {
		return nil, false
	}
	m := hmac.New(sha256.New, sec)
	m.Write(signedText(context, body))
	m.Write(r)
	return m.Sum(nil), true
}

var errArgs = errors.New("shim: args")

func (i *identity) Public() Key { return i.pub }

func (i *identity) Sign(context string, body []byte) ([]byte, error) {
	if !bodyFits(i.pub, context, body) {
		return nil, errArgs
	}
	r := make([]byte, 32)
	rand.Read(r)
	m, _ := i.s.mac(i.pub, context, body, r)
	return append(r, m...), nil
}

func (s *shim) Verify(pub Key, context string, body, sig []byte) error {
	if len(sig) != SigSize || !bodyFits(pub, context, body) {
		return ErrSignature
	}
	m, ok := s.mac(pub, context, body, sig[:32])
	if !ok || !hmac.Equal(m, sig[32:]) {
		return ErrSignature
	}
	return nil
}

// a signer that signs anything, to reach the parser's checks past the
// signature
type anySigner struct{ pub Key }

func (a anySigner) Public() Key { return a.pub }
func (a anySigner) Sign(string, []byte) ([]byte, error) {
	return make([]byte, SigSize), nil
}

// the device side of ks_identity_generate
type keySource struct{ t testing.TB }

func (k keySource) NewKey() (Key, error) {
	pub, _ := newKey(k.t)
	return pub, nil
}

// a seeded random source, so a run can be repeated
func seeded(n uint64) io.Reader { return mrand.NewChaCha8([32]byte{byte(n), byte(n >> 8), 7}) }

// a reader giving one byte again and again
type constReader byte

func (c constReader) Read(p []byte) (int, error) {
	for i := range p {
		p[i] = byte(c)
	}
	return len(p), nil
}

// one identity as its phone holds it, with the devices linked so far
type account struct {
	id   *identity
	list *List
	wire []byte
	devs map[uint8]Key
}

func newAccount(t testing.TB, s *shim) *account {
	t.Helper()
	id := s.identity(t)
	l, err := Genesis(id.pub, 1234, rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	a := &account{id: id, list: l, devs: map[uint8]Key{PhoneID: id.pub}}
	a.sign(t)
	return a
}

func (a *account) sign(t testing.TB) {
	t.Helper()
	w, err := a.list.Sign(a.id)
	if err != nil {
		t.Fatal(err)
	}
	a.wire = w
}

func (a *account) set(t testing.TB, l *List, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
	a.list = l
	a.sign(t)
}

// a device linked straight onto the list, without the handshake
func (a *account) link(t testing.TB) Entry {
	t.Helper()
	k, _ := newKey(t)
	e, err := EntryFor(a.list, DeviceKeys{Identity: a.id.pub, Key: k, Reg: 77}, rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	n, err := a.list.Add(e, rand.Reader)
	a.set(t, n, err)
	a.devs[e.ID] = k
	return e
}

func (a *account) unlink(t testing.TB, id uint8) {
	t.Helper()
	n, err := a.list.Remove(id, rand.Reader)
	a.set(t, n, err)
	delete(a.devs, id)
}

// a list signed as it stands, whatever it breaks
func forge(l *List) []byte { return append(l.Body(), make([]byte, SigSize)...) }

func clone(l *List) *List {
	n := *l
	n.Devices = append([]Entry(nil), l.Devices...)
	n.sig = nil
	return &n
}

// a list read and verified, then offered to k as Book.Accept would
func (k *known) take(b []byte, from From, v Verifier) (*List, Outcome, error) {
	l, err := ReadList(b, v)
	if err != nil {
		return nil, 0, err
	}
	return k.accept(l, from)
}
