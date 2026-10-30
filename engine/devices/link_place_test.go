// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bytes"
	"crypto/rand"
	"errors"
	"strings"
	"testing"
	"time"
)

const testOnion = "abcdefghijklmnopqrstuvwxyz234567abcdefghijklmnopqrstuvwd"

// a link run to its end, with the phone's list naming the new device
type placeRun struct {
	*linkRun
	linked *Linked
	after  AfterKeys
	acct   *account
	entry  Entry
}

func placed(t *testing.T) *placeRun {
	t.Helper()
	r := &placeRun{linkRun: startLink(t, t0)}
	dk, err := r.linker.Device()
	if err != nil {
		t.Fatal(err)
	}
	r.linked, _, _ = r.finish(t, t0)
	a, err := r.linker.After()
	if err != nil {
		t.Fatal(err)
	}
	r.after = a
	r.acct = &account{id: r.phone, devs: map[uint8]Key{}}
	g, err := Genesis(r.phone.pub, 1234, rand.Reader)
	r.acct.set(t, g, err)
	r.entry, err = EntryFor(r.acct.list, dk, rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	n, err := r.acct.list.Add(r.entry, rand.Reader)
	r.acct.set(t, n, err)
	return r
}

func TestBothSidesHoldTheSameAfterKeys(t *testing.T) {
	r := placed(t)
	if r.after != r.linked.After {
		t.Fatal("the two sides' after keys differ")
	}
	if r.after.Place == r.after.Bundles || r.after.Place == [32]byte{} {
		t.Fatal("one key for two messages")
	}
	// not from bind alone: bind is a hash of what anyone on the
	// rendezvous saw
	for _, w := range [][]byte{r.linked.Bind[:], r.linked.StreamKey[:]} {
		if bytes.Equal(w, r.after.Place[:]) || bytes.Equal(w, r.after.Bundles[:]) {
			t.Fatal("an after key equals another value of the link")
		}
	}
	if _, err := startLink(t, t0).linker.After(); !errors.Is(err, ErrState) {
		t.Fatalf("after keys before the welcome: %v", err)
	}
}

func TestTheRendezvousComesFromTheOffer(t *testing.T) {
	r := startLink(t, t0)
	j, p, err := Rendezvous(r.joiner.Offer())
	if err != nil {
		t.Fatal(err)
	}
	if j == p {
		t.Fatal("one address for both ways")
	}
	j2, p2, _ := Rendezvous(r.joiner.Offer())
	if j != j2 || p != p2 {
		t.Fatal("not the same from one offer")
	}
	o := startLink(t, t0)
	j3, _, _ := Rendezvous(o.joiner.Offer())
	if j3 == j {
		t.Fatal("two offers, one address")
	}
	if _, _, err := Rendezvous([]byte("KLO2short")); !errors.Is(err, ErrMalformed) {
		t.Fatalf("a short offer: %v", err)
	}
}

func TestThePlaceGoesToTheJoinerOnly(t *testing.T) {
	r := placed(t)
	tok, err := NewToken()
	if err != nil {
		t.Fatal(err)
	}
	msg, err := SealPlace(r.after, r.linked.Bind, Place{Onion: testOnion, Token: tok, Want: 12, List: r.acct.wire})
	if err != nil {
		t.Fatal(err)
	}
	got, err := OpenPlace(r.linked.After, r.linked.Bind, msg)
	if err != nil {
		t.Fatal(err)
	}
	if got.Onion != testOnion || got.Token != tok || got.Want != 12 || !bytes.Equal(got.List, r.acct.wire) {
		t.Fatal("not what was sealed")
	}
	// the list names the device by the key it revealed
	l, err := ParseList(got.List)
	if err != nil {
		t.Fatal(err)
	}
	if e, ok := l.FindKey(r.linked.Keys.Key); !ok || e.ID != r.entry.ID {
		t.Fatal("the list does not name the new device")
	}
	other := placed(t)
	if _, err := OpenPlace(other.linked.After, other.linked.Bind, msg); !errors.Is(err, ErrOpen) {
		t.Fatalf("another link's keys: %v", err)
	}
	if _, err := OpenPlace(r.linked.After, other.linked.Bind, msg); !errors.Is(err, ErrOpen) {
		t.Fatalf("another bind: %v", err)
	}
	// the bundles key does not open a place
	swapped := AfterKeys{Place: r.after.Bundles}
	if _, err := OpenPlace(swapped, r.linked.Bind, msg); !errors.Is(err, ErrOpen) {
		t.Fatalf("the bundles key: %v", err)
	}
	for i := 4; i < len(msg); i += 37 {
		bad := bytes.Clone(msg)
		bad[i] ^= 1
		if _, err := OpenPlace(r.linked.After, r.linked.Bind, bad); err == nil {
			t.Fatalf("a flipped byte at %d opened", i)
		}
	}
}

func TestAPlaceRefusesWhatIsNotOne(t *testing.T) {
	r := placed(t)
	tok, _ := NewToken()
	for name, p := range map[string]Place{
		"short onion":      {Onion: testOnion[:55], Token: tok, List: r.acct.wire},
		"upper onion":      {Onion: strings.ToUpper(testOnion), Token: tok, List: r.acct.wire},
		"not v3":           {Onion: testOnion[:55] + "a", Token: tok, List: r.acct.wire},
		"dotted":           {Onion: testOnion[:50] + ".onion", Token: tok, List: r.acct.wire},
		"no list":          {Onion: testOnion, Token: tok},
		"list too long":    {Onion: testOnion, Token: tok, List: make([]byte, MaxListSize+1)},
		"wants too many":   {Onion: testOnion, Token: tok, Want: BundlesMost + 1, List: r.acct.wire},
		"wants below none": {Onion: testOnion, Token: tok, Want: -1, List: r.acct.wire},
	} {
		if _, err := SealPlace(r.after, r.linked.Bind, p); !errors.Is(err, ErrMalformed) {
			t.Errorf("%s: %v", name, err)
		}
	}
	// a list that does not parse is refused on opening, even sealed right
	pt := append([]byte(testOnion), tok[:]...)
	pt = append(pt, 0, 1, 0, byte(MinListSize))
	pt = append(pt, make([]byte, MinListSize)...)
	ct, _ := sealOnce(r.after.Place[:], pt, adOf(placeMagic, r.linked.Bind))
	if _, err := OpenPlace(r.linked.After, r.linked.Bind, append([]byte(placeMagic), ct...)); !errors.Is(err, ErrMalformed) {
		t.Fatalf("junk list: %v", err)
	}
	// bytes after the list
	good, _ := SealPlace(r.after, r.linked.Bind, Place{Onion: testOnion, Token: tok, List: r.acct.wire})
	if _, err := OpenPlace(r.linked.After, r.linked.Bind, good[:len(good)-1]); err == nil {
		t.Fatal("a cut place opened")
	}
}

// the device's bundles for the phone, made after it learned its id
func (r *placeRun) bundles(t *testing.T, n int) Bundles {
	t.Helper()
	b := Bundles{Made: t0.Add(time.Minute)}
	b.First = poolKDB1(t, 1, 7, r.entry)
	b.Last = poolKDB1(t, 2, 7, r.entry)
	for i := 0; i < n; i++ {
		b.Once = append(b.Once, poolKDB1(t, uint32(10+i), 7, r.entry))
	}
	return b
}

func TestTheBundlesReachThePhone(t *testing.T) {
	r := placed(t)
	want := r.bundles(t, 5)
	msg, err := SealBundles(r.linked.After, r.linked.Bind, want)
	if err != nil {
		t.Fatal(err)
	}
	got, err := OpenBundles(r.after, r.linked.Bind, msg, r.phone.pub, r.entry)
	if err != nil {
		t.Fatal(err)
	}
	if !got.Made.Equal(want.Made) || !bytes.Equal(got.First, want.First) || !bytes.Equal(got.Last, want.Last) || len(got.Once) != 5 {
		t.Fatal("not what was sealed")
	}
	for i := range want.Once {
		if !bytes.Equal(got.Once[i], want.Once[i]) {
			t.Fatalf("bundle %d differs", i)
		}
	}
	// none at all is fine: a phone with no contacts on devices yet
	none, _ := SealBundles(r.linked.After, r.linked.Bind, r.bundles(t, 0))
	if g, err := OpenBundles(r.after, r.linked.Bind, none, r.phone.pub, r.entry); err != nil || len(g.Once) != 0 {
		t.Fatalf("no batch: %v", err)
	}
	if _, err := OpenBundles(r.after, r.linked.Bind, msg, r.phone.pub, Entry{ID: PhoneID, Key: r.phone.pub, Reg: 1, Phone: true}); err == nil {
		t.Fatal("bundles taken for the phone itself")
	}
	if _, err := OpenBundles(AfterKeys{Bundles: r.after.Place}, r.linked.Bind, msg, r.phone.pub, r.entry); !errors.Is(err, ErrOpen) {
		t.Fatalf("the place key: %v", err)
	}
}

func TestBundlesOfAnotherDeviceAreRefused(t *testing.T) {
	r := placed(t)
	other := r.acct.link(t)
	seal := func(b Bundles) []byte {
		m, err := SealBundles(r.linked.After, r.linked.Bind, b)
		if err != nil {
			t.Fatal(err)
		}
		return m
	}
	b := r.bundles(t, 2)
	b.Once[1] = poolKDB1(t, 40, 7, other)
	if _, err := OpenBundles(r.after, r.linked.Bind, seal(b), r.phone.pub, r.entry); !errors.Is(err, ErrNotItsKey) {
		t.Fatalf("another device's bundle: %v", err)
	}
	b = r.bundles(t, 2)
	reg := r.entry
	reg.Reg++
	b.First = poolKDB1(t, 1, 7, reg)
	if _, err := OpenBundles(r.after, r.linked.Bind, seal(b), r.phone.pub, r.entry); !errors.Is(err, ErrNotItsKey) {
		t.Fatalf("another registration id: %v", err)
	}
	b = r.bundles(t, 2)
	b.Once[0] = poolKDB1(t, 2, 7, r.entry)
	if _, err := OpenBundles(r.after, r.linked.Bind, seal(b), r.phone.pub, r.entry); !errors.Is(err, ErrDuplicate) {
		t.Fatalf("one kyber id twice: %v", err)
	}
	b = r.bundles(t, 1)
	b.Last = []byte("KDB1")
	if _, err := OpenBundles(r.after, r.linked.Bind, seal(b), r.phone.pub, r.entry); err == nil {
		t.Fatal("junk taken as a bundle")
	}
	if _, err := SealBundles(r.linked.After, r.linked.Bind, Bundles{First: b.First, Last: b.First}); !errors.Is(err, ErrMalformed) {
		t.Fatalf("no make time: %v", err)
	}
	many := r.bundles(t, 0)
	many.Once = make([][]byte, BundlesMost+1)
	if _, err := SealBundles(r.linked.After, r.linked.Bind, many); !errors.Is(err, ErrMalformed) {
		t.Fatalf("too many: %v", err)
	}
}

func TestTheLargestBundlesFitTheirCap(t *testing.T) {
	r := placed(t)
	msg, err := SealBundles(r.linked.After, r.linked.Bind, r.bundles(t, BundlesMost))
	if err != nil {
		t.Fatal(err)
	}
	if len(msg) > BundlesSizeMax {
		t.Fatalf("%d over the cap %d", len(msg), BundlesSizeMax)
	}
	if got, err := OpenBundles(r.after, r.linked.Bind, msg, r.phone.pub, r.entry); err != nil || len(got.Once) != BundlesMost {
		t.Fatalf("the largest batch: %v", err)
	}
}

func FuzzOpenLinkAfter(f *testing.F) {
	f.Add([]byte("KLP1"), []byte("KLB1"))
	var a AfterKeys
	var bind [32]byte
	var id Key
	id[0] = 5
	f.Fuzz(func(t *testing.T, p, b []byte) {
		if _, err := OpenPlace(a, bind, p); err == nil {
			t.Fatal("opened under a zero key")
		}
		if _, err := OpenBundles(a, bind, b, id, Entry{ID: 9, Reg: 1}); err == nil {
			t.Fatal("opened under a zero key")
		}
	})
}
