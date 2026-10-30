// SPDX-License-Identifier: GPL-3.0-or-later
package kshim_test

import (
	"bufio"
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/halo/engine/devices"
	"github.com/halo/engine/kshim"
)

// the shim build-host.sh leaves, or the one KRYFO_SIGNAL_LIB names
func openShim(t testing.TB) *kshim.Lib {
	t.Helper()
	p := os.Getenv("KRYFO_SIGNAL_LIB")
	if p == "" {
		p, _ = filepath.Abs("../../mobile/native/kryfo_signal/target/release/libkryfo_signal.so")
	}
	if _, err := os.Stat(p); err != nil {
		t.Skip("libkryfo_signal not built: run mobile/native/kryfo_signal/build-host.sh or set KRYFO_SIGNAL_LIB")
	}
	l, err := kshim.Open(p)
	if err != nil {
		t.Fatal(err)
	}
	return l
}

type verifier struct{ l *kshim.Lib }

func (v verifier) Verify(pub devices.Key, context string, body, sig []byte) error {
	return v.l.Verify(pub[:], context, body, sig)
}

// an identity through the shim, signing with ks_sign
type signer struct {
	l    *kshim.Lib
	pair []byte
	pub  devices.Key
}

func identity(t testing.TB, l *kshim.Lib, priv []byte) *signer {
	t.Helper()
	o, code, err := l.Call("ks_identity_from_private", priv)
	if err != nil || code != 0 || len(o) != 2 {
		t.Fatalf("identity: %v %d", err, code)
	}
	pub, err := devices.ParseKey(o[1])
	if err != nil {
		t.Fatal(err)
	}
	return &signer{l: l, pair: o[0], pub: pub}
}

func (s *signer) Public() devices.Key { return s.pub }

func (s *signer) Sign(context string, body []byte) ([]byte, error) {
	o, code, err := s.l.Call("ks_sign", s.pair, []byte(context), body)
	if err != nil || code != 0 || len(o) != 1 {
		return nil, errors.New("sign refused")
	}
	return o[0], nil
}

type sigLine struct {
	kind, name string
	f          []string
}

func sigVectors(t *testing.T) (keys map[string][]byte, lines []sigLine) {
	f, err := os.Open("../../mobile/native/kryfo_signal/testdata/sig_v1.txt")
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	keys = map[string][]byte{}
	sc := bufio.NewScanner(f)
	sc.Buffer(nil, 1<<20)
	for sc.Scan() {
		w := strings.Fields(sc.Text())
		if len(w) < 2 || strings.HasPrefix(w[0], "#") {
			continue
		}
		switch w[0] {
		case "key":
			b, _ := hex.DecodeString(w[2])
			keys[w[1]] = b
		case "good", "bad":
			lines = append(lines, sigLine{w[0], w[1], w[2:]})
		}
	}
	return keys, lines
}

func unhex(t *testing.T, s string) []byte {
	t.Helper()
	if s == "-" {
		return nil
	}
	b, err := hex.DecodeString(s)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

// the lists signed in the shim's own vectors read through the engine with
// the shim checking their signatures, and the refused ones stay refused
func TestShimVerifiesTheSignatureVectors(t *testing.T) {
	l := openShim(t)
	v := verifier{l}
	keys, lines := sigVectors(t)
	goods, bads := 0, 0
	for _, s := range lines {
		switch {
		case s.kind == "good":
			// name key context message text signature
			pub := identity(t, l, keys[s.f[0]]).pub
			msg, sig := unhex(t, s.f[2]), unhex(t, s.f[4])
			if err := l.Verify(pub[:], s.f[1], msg, sig); err != nil {
				t.Errorf("%s: %v", s.name, err)
			}
			if s.f[1] == devices.ContextList {
				got, err := devices.ReadList(append(bytes.Clone(msg), sig...), v)
				if err != nil || got.Identity != pub {
					t.Errorf("%s through the engine: %v", s.name, err)
				}
			}
			goods++
		case s.kind == "bad":
			// name refused-as lax|strict public context message signature
			pub, msg, sig := unhex(t, s.f[2]), unhex(t, s.f[4]), unhex(t, s.f[5])
			if err := l.Verify(pub, s.f[3], msg, sig); !errors.Is(err, kshim.ErrSignature) {
				t.Errorf("%s: taken (%v)", s.name, err)
			}
			if s.f[3] == devices.ContextList && len(pub) == devices.KeySize {
				if _, err := devices.ReadList(append(bytes.Clone(msg), sig...), v); err == nil {
					t.Errorf("%s through the engine: taken", s.name)
				}
			}
			bads++
		}
	}
	if goods == 0 || bads == 0 {
		t.Fatalf("no vectors read: %d good, %d bad", goods, bads)
	}
}

// the engine's own KDL2 vectors carry a zero signature: through the real
// shim each one that parses is refused on its signature, the rest on
// their shape. the same bodies signed by ks_sign under a real key read
func TestShimRefusesTheEngineVectorsUnsigned(t *testing.T) {
	l := openShim(t)
	v := verifier{l}
	b, err := os.ReadFile("../devices/testdata/vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var vf struct {
		KDL2 []struct {
			Name string `json:"name"`
			Hex  string `json:"hex"`
			OK   bool   `json:"ok"`
		} `json:"kdl2"`
	}
	if err := json.Unmarshal(b, &vf); err != nil {
		t.Fatal(err)
	}
	if len(vf.KDL2) == 0 {
		t.Fatal("no kdl2 vectors")
	}
	for _, x := range vf.KDL2 {
		w := unhex(t, x.Hex)
		_, err := devices.ReadList(w, v)
		switch {
		case x.OK && !errors.Is(err, devices.ErrSignature):
			t.Errorf("%s: %v, want a refused signature", x.Name, err)
		case !x.OK && !errors.Is(err, devices.ErrMalformed):
			t.Errorf("%s: %v, want malformed", x.Name, err)
		}
	}
}

func TestShimSignsAndVerifiesALiveList(t *testing.T) {
	l := openShim(t)
	v := verifier{l}
	keys, _ := sigVectors(t)
	ana := identity(t, l, keys["ana1"])
	ben := identity(t, l, keys["ben0"])
	desk := identity(t, l, keys["desk"])
	g, err := devices.Genesis(ana.pub, 77, rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	two, err := g.Add(devices.Entry{ID: 9, Key: desk.pub, Reg: 1234}, rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	wire, err := two.Sign(ana)
	if err != nil {
		t.Fatal(err)
	}
	got, err := devices.ReadList(wire, v)
	if err != nil || got.Version != two.Version || len(got.Devices) != 2 {
		t.Fatalf("read back: %v", err)
	}
	// one bit anywhere is refused
	for i := range wire {
		bad := bytes.Clone(wire)
		bad[i] ^= 0x01
		if _, err := devices.ReadList(bad, v); err == nil {
			t.Fatalf("byte %d flipped: taken", i)
		}
	}
	// another identity's signature over ana's list
	sig, err := ben.Sign(devices.ContextList, two.Body())
	if err == nil {
		if _, err := devices.ReadList(append(two.Body(), sig...), v); err == nil {
			t.Fatal("ben's signature over ana's list taken")
		}
	}
	// the device's own key cannot sign its phone's list
	if s, err := desk.Sign(devices.ContextList, two.Body()); err == nil {
		if _, err := devices.ReadList(append(two.Body(), s...), v); err == nil {
			t.Fatal("the device's signature taken")
		}
	}
}

func TestOpenRefusesWhatIsNotTheShim(t *testing.T) {
	if _, err := kshim.Open("/nonexistent/libkryfo_signal.so"); !errors.Is(err, kshim.ErrOpen) {
		t.Fatalf("missing library: %v", err)
	}
	// a library without ks_abi_version (libc, loaded already)
	if _, err := kshim.Open("libc.so.6"); err == nil {
		t.Fatal("libc taken as the shim")
	}
}
