// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha512"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"math/big"
	"os"
	"strings"
	"testing"
	"time"
)

// the shim's own vectors (made by write_vectors in its tests)
const formatsFile = "../../mobile/native/kryfo_signal/testdata/formats_v1.txt"

// every invite vector reads as the shim reads it: the good ones whole, the
// bad ones refused for the same reason
func TestKIN4MatchesTheShim(t *testing.T) {
	b, err := os.ReadFile(formatsFile)
	if err != nil {
		t.Fatalf("the shim's vectors: %v", err)
	}
	good, bad := 0, 0
	for _, line := range strings.Split(string(b), "\n") {
		f := strings.Fields(line)
		if len(f) < 5 || f[0] == "#" || f[2] != "invite" {
			continue
		}
		raw, err := hex.DecodeString(f[len(f)-1])
		if err != nil {
			t.Fatalf("%s: %v", f[1], err)
		}
		k, err := parseKIN4(raw)
		switch f[0] {
		case "good":
			good++
			if err != nil {
				t.Errorf("%s refused: %v", f[1], err)
			} else if len(k.identity) != 33 {
				t.Errorf("%s: identity %x", f[1], k.identity)
			}
		case "bad":
			bad++
			want := map[string]error{"format": errFormat, "signature": errSignature}[f[4]]
			if want == nil {
				t.Fatalf("%s: refused as %q", f[1], f[4])
			}
			if !errors.Is(err, want) {
				t.Errorf("%s: %v, the shim refuses it as %s", f[1], err, f[4])
			}
		}
	}
	if good < 9 || bad < 50 {
		t.Fatalf("only %d good and %d bad invite vectors", good, bad)
	}
}

// xeddsa as libsignal signs, for building invites here: the edwards key of
// the scalar, its sign bit in the signature's last byte
func xedSign(priv, msg []byte) []byte {
	a := leInt(clamp(priv))
	pub := edEncode(edMul(edBase, a))
	nonce := make([]byte, 64)
	_, _ = rand.Read(nonce)
	h := sha512.New()
	h.Write(append([]byte{0xfe}, bytes.Repeat([]byte{0xff}, 31)...))
	h.Write(le32(a))
	h.Write(msg)
	h.Write(nonce)
	r := new(big.Int).Mod(leInt(h.Sum(nil)), orderL)
	rEnc := edEncode(edMul(edBase, r))
	h = sha512.New()
	h.Write(rEnc)
	h.Write(pub)
	h.Write(msg)
	k := new(big.Int).Mod(leInt(h.Sum(nil)), orderL)
	s := new(big.Int).Mod(new(big.Int).Add(r, new(big.Int).Mul(k, a)), orderL)
	sig := append(rEnc, le32(s)...)
	sig[63] |= pub[31] & 0x80
	return sig
}

func clamp(k []byte) []byte {
	c := bytes.Clone(k)
	c[0] &= 248
	c[31] &= 127
	c[31] |= 64
	return c
}

var edBase = func() edPoint {
	y := fmul(big.NewInt(4), new(big.Int).ModInverse(big.NewInt(5), fieldP))
	p, _ := edDecode(le32(y))
	return p
}()

func edEncode(p edPoint) []byte {
	zi := new(big.Int).ModInverse(p.z, fieldP)
	x, y := fmul(p.x, zi), fmul(p.y, zi)
	out := le32(y)
	out[31] |= byte(x.Bit(0)) << 7
	return out
}

// a curve key pair: the private scalar and 0x05 || u
type curveKey struct{ priv, pub []byte }

func newCurveKey(t *testing.T) curveKey {
	priv := make([]byte, 32)
	if _, err := rand.Read(priv); err != nil {
		t.Fatal(err)
	}
	p := edMul(edBase, leInt(clamp(priv)))
	zi := new(big.Int).ModInverse(p.z, fieldP)
	y := fmul(p.y, zi)
	// u = (1 + y) / (1 - y)
	u := fmul(fmod(new(big.Int).Add(big.NewInt(1), y)),
		new(big.Int).ModInverse(fmod(new(big.Int).Sub(big.NewInt(1), y)), fieldP))
	return curveKey{priv, append([]byte{0x05}, le32(u)...)}
}

func firstContactKey(t *testing.T) []byte {
	for {
		b := make([]byte, 32)
		_, _ = rand.Read(b)
		if secpLifts(b) {
			return b
		}
	}
}

// a main invite as the app makes it for a handle: face, onion, bundle
func mainInvite(t *testing.T, face ed25519.PrivateKey, oneTime bool) string {
	id := newCurveKey(t)
	spk := newCurveKey(t)
	onion, _, _ := ed25519.GenerateKey(nil)
	kyber := make([]byte, kyberLen)
	_, _ = rand.Read(kyber)
	kyber[0] = 0x08
	now := uint32(time.Now().Unix() / 3600)
	k := &kin4{
		oneTime: oneTime, issued: now, expires: now + 8760,
		id: make([]byte, 16), identity: id.pub, firstContact: firstContactKey(t),
		onion: onion,
		block: &kinBlock{
			reg: 4242, device: 1, spkID: 7, spk: spk.pub, spkSig: xedSign(id.priv, spk.pub),
			kyberID: 9, kyber: kyber, kyberSig: xedSign(id.priv, kyber),
		},
	}
	_, _ = rand.Read(k.id)
	if oneTime {
		ec := newCurveKey(t)
		k.block.hasEC, k.block.ecID, k.block.ec = true, 11, ec.pub
	}
	if face != nil {
		k.face = face.Public().(ed25519.PublicKey)
		k.faceSig = ed25519.Sign(face, append(append(bytes.Clone(faceText), k.identity...), k.id...))
	}
	k.sig = xedSign(id.priv, signedText("invite", k.body()))
	return v4Prefix + base64.RawURLEncoding.EncodeToString(append(k.body(), k.sig...))
}

func TestMainInviteBuiltHereReads(t *testing.T) {
	o := newOwner(t)
	inv := mainInvite(t, o.priv, false)
	if len(inv) < 2700 || len(inv) > 2760 {
		t.Fatalf("a main invite link is %d characters", len(inv))
	}
	if !inviteOK(inv) || !inviteIsKeys(inv, o.hexPub()) {
		t.Fatal("the owner's own main invite was refused")
	}
	if inviteIsKeys(inv, newOwner(t).hexPub()) {
		t.Fatal("another key owns the invite")
	}
}

// only a whole main invite with a face, in its one form, under the ceiling
func TestV4InviteShapes(t *testing.T) {
	o := newOwner(t)
	inv := mainInvite(t, o.priv, false)
	enc := strings.TrimPrefix(inv, v4Prefix)
	raw, _ := base64.RawURLEncoding.DecodeString(enc)
	flip := bytes.Clone(raw)
	flip[len(flip)-70] ^= 1
	bad := []struct{ why, s string }{
		{"no face", mainInvite(t, nil, false)},
		{"one-time", mainInvite(t, o.priv, true)},
		{"padded", inv + "="},
		{"standard base64", v4Prefix + base64.StdEncoding.EncodeToString(raw)},
		{"a second encoding of the last byte", v4Prefix + enc[:len(enc)-1] + string(enc[len(enc)-1]^1)},
		{"something after it", inv + "&x=1"},
		{"a script after it", inv + "\"><script>"},
		{"a byte changed", v4Prefix + base64.RawURLEncoding.EncodeToString(flip)},
		{"a byte less", v4Prefix + base64.RawURLEncoding.EncodeToString(raw[:len(raw)-1])},
		{"empty", v4Prefix},
		{"past the ceiling", v4Prefix + strings.Repeat("A", maxInvite)},
		{"v4 in another order", "kryfo://share?i=" + enc + "&v=4"},
	}
	for _, c := range bad {
		if inviteOK(c.s) {
			t.Errorf("took %s", c.why)
		}
	}
}

// a handle claimed with a v4 main invite: only by its face, served as it
// was claimed, and the page links it
func TestClaimV4(t *testing.T) {
	srv, st := service(t, newLimiter(100, 100))
	c := srv.Client()
	o := newOwner(t)
	inv := mainInvite(t, o.priv, false)
	now := time.Now().Unix()
	if out := post(t, c, srv.URL, "/handle/claim", claimWith("wren", inv, o, now)); out["ok"] != true {
		t.Fatalf("claim: %v", out)
	}
	if e, _ := st.get("wren"); e.Invite != inv || e.Pubkey != o.hexPub() {
		t.Fatalf("stored: %+v", e)
	}
	// someone else's main invite under my key
	other := newOwner(t)
	theirs := mainInvite(t, other.priv, false)
	if out := post(t, c, srv.URL, "/handle/claim", claimWith("lark", theirs, o, now)); out["error"] != "the invite is not yours" {
		t.Fatalf("another face: %v", out)
	}
	// from v3 to v4 and back, by the same key
	if out := post(t, c, srv.URL, "/handle/claim", claimWith("wren", o.invite(), o, now+1)); out["ok"] != true {
		t.Fatalf("back to v3: %v", out)
	}
	inv2 := mainInvite(t, o.priv, false)
	if out := post(t, c, srv.URL, "/handle/claim", claimWith("wren", inv2, o, now+2)); out["ok"] != true {
		t.Fatalf("a new main invite: %v", out)
	}
	_, page := fetch(t, c, srv.URL+"/@wren")
	if !strings.Contains(page, `href="`+esc(inv2)+`"`) {
		t.Fatal("the page does not link the invite")
	}
}

// a v3 link of a 0.6 phone carries the kyber prekey: about 3,700 bytes
func TestFullV3Fits(t *testing.T) {
	inv := "kryfo://share?" + fullV3(t)
	if len(inv) < 3600 || !inviteOK(inv) {
		t.Fatalf("a %d byte v3 was refused", len(inv))
	}
}

// what a claim costs the registry: the v4 parse is slow next to the shim
func BenchmarkInviteV4(b *testing.B) {
	t := &testing.T{}
	pub, priv, _ := ed25519.GenerateKey(nil)
	inv := mainInvite(t, priv, false)
	for b.Loop() {
		if !inviteIsKeys(inv, hex.EncodeToString(pub)) {
			b.Fatal("refused")
		}
	}
}
