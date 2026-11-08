// SPDX-License-Identifier: GPL-3.0-or-later
package main

// device-pair addresses:
// pinned outputs in testdata/address_device.json, both sides agree, every
// role apart from every other, device 1 to device 1 unchanged. the same
// write rule as address_v4_test.go: KRYFO_WRITE_VECTORS=1 writes it

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/mailru/easyjson"
	nostr2 "github.com/nbd-wtf/go-nostr"
	"golang.org/x/crypto/curve25519"
)

const devVectorFile = "testdata/address_device.json"

// the identities of the device tests: a's phone and its device 5, b's
// phone and its device 9, each as its own container would hold it
const (
	dvA1 = 71
	dvA5 = 72
	dvB1 = 73
	dvB9 = 74
)

type fakeDeviceKeys map[string][32]byte

func (f fakeDeviceKeys) deviceKey(_ int, peer [32]byte, dev uint8) ([32]byte, bool) {
	k, ok := f[hex.EncodeToString(peer[:])+"/"+strconv.Itoa(int(dev))]
	return k, ok
}

func (f fakeDeviceKeys) put(peer [32]byte, dev uint8, k [32]byte) {
	f[hex.EncodeToString(peer[:])+"/"+strconv.Itoa(int(dev))] = k
}

type devWorld struct {
	a, b, da, db xid
	keys         fakeDeviceKeys
	aHex, bHex   string
}

// the four containers in one engine, the switch on, the lists held
func newDevWorld(t *testing.T) devWorld {
	t.Helper()
	w := devWorld{
		a: fixedXid(t, v4Keys["a"]), b: fixedXid(t, v4Keys["b"]),
		da: fixedXid(t, v4Keys["da"]), db: fixedXid(t, v4Keys["db"]),
		keys: fakeDeviceKeys{},
	}
	w.aHex, w.bHex = hex.EncodeToString(w.a.pub[:]), hex.EncodeToString(w.b.pub[:])
	w.keys.put(w.a.pub, 5, w.da.pub)
	w.keys.put(w.b.pub, 9, w.db.pub)
	putIdentity(dvA1, w.a)
	putIdentity(dvA5, w.da)
	putIdentity(dvB1, w.b)
	putIdentity(dvB9, w.db)
	if err := putLinkedIdent(dvA5, w.a.pub, 5); err != nil {
		t.Fatal(err)
	}
	if err := putLinkedIdent(dvB9, w.b.pub, 9); err != nil {
		t.Fatal(err)
	}
	was := devicePairsOn.Load()
	devicePairsOn.Store(true)
	setDeviceKeys(w.keys)
	t.Cleanup(func() {
		for _, i := range []int{dvA1, dvA5, dvB1, dvB9} {
			identDrop(i)
		}
		devicePairsOn.Store(was)
		setDeviceKeys(nil)
	})
	return w
}

func mustPair(t *testing.T, ident int, arg string) convPair {
	t.Helper()
	c, _, err := pairArg(ident, arg)
	if err != nil {
		t.Fatalf("%d %s: %v", ident, arg, err)
	}
	return c
}

// one device pair from both of its ends
type devCase struct {
	name       string
	x, y       string
	xId, yId   int
	xArg, yArg string
}

func (w devWorld) cases(seed string) []devCase {
	return []devCase{
		{"a1-b9", "a1", "b9", dvA1, dvB9, w.bHex + "/9/1." + seed, w.aHex + "/1/9." + seed},
		{"a5-b9", "a5", "b9", dvA5, dvB9, w.bHex + "/9/5." + seed, w.aHex + "/5/9." + seed},
		{"a5-b1", "a5", "b1", dvA5, dvB1, w.bHex + "/1/5." + seed, w.aHex + "/5/1." + seed},
		{"a1-a5", "a1", "a5", dvA1, dvA5, w.aHex + "/5/1." + seed, w.aHex + "/1/5." + seed},
	}
}

func roleKey(t *testing.T, p v4Pair, role string, mine bool) (sk, pk string) {
	t.Helper()
	sk, pk, err := p.role(role, mine)
	if err != nil {
		t.Fatal(err)
	}
	return sk, pk
}

// what [c] computes of its pair: names by owner, as [me] and [them]
func pairView(t *testing.T, c convPair, name, me, them string) map[string]string {
	t.Helper()
	out := map[string]string{}
	_, rcv, err := c.rcvAddress()
	if err != nil {
		t.Fatal(err)
	}
	theirs, err := c.theirAddress()
	if err != nil {
		t.Fatal(err)
	}
	out[name+" rcv "+me], out[name+" rcv "+them] = rcv, theirs
	_, out[name+" snd "+me] = roleKey(t, c.v4(), roleSnd, true)
	_, out[name+" snd "+them] = roleKey(t, c.v4(), roleSnd, false)
	o, err := c.openerOf()
	if err != nil {
		t.Fatal(err)
	}
	_, opn, err := o.rcvAddress()
	if err != nil {
		t.Fatal(err)
	}
	theirOpn, err := o.theirAddress()
	if err != nil {
		t.Fatal(err)
	}
	out[name+" opn "+me], out[name+" opn "+them] = opn, theirOpn
	_, out[name+" ops "+me] = roleKey(t, o.v4(), roleOps, true)
	_, out[name+" ops "+them] = roleKey(t, o.v4(), roleOps, false)
	return out
}

func devOutputs(t *testing.T, w devWorld) map[string]string {
	t.Helper()
	seed := hex.EncodeToString(fixedSeed(1))
	out := map[string]string{}
	for _, dc := range w.cases(seed) {
		x := pairView(t, mustPair(t, dc.xId, dc.xArg), dc.name, dc.x, dc.y)
		y := pairView(t, mustPair(t, dc.yId, dc.yArg), dc.name, dc.y, dc.x)
		if len(x) != len(y) {
			t.Fatalf("%s: the two sides name %d and %d", dc.name, len(x), len(y))
		}
		for k, v := range x {
			if y[k] != v {
				t.Errorf("%s: %s... and %s...", k, v[:12], y[k][:12])
			}
			out[k] = v
		}
	}
	// a secret key too, for another implementation to check its curve step
	o, _ := mustPair(t, dvA1, w.bHex+"/9/1."+seed).openerOf()
	out["a1-b9 opn a1 sk"], _, _ = o.rcvAddress()
	return out
}

func TestAddressDeviceVectors(t *testing.T) {
	w := newDevWorld(t)
	got := devOutputs(t, w)
	if os.Getenv("KRYFO_WRITE_VECTORS") == "1" {
		b, _ := json.MarshalIndent(v4Vectors{Keys: v4Keys, Seed: hex.EncodeToString(fixedSeed(1)), Out: got}, "", "  ")
		if err := os.WriteFile(devVectorFile, append(b, '\n'), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	raw, err := os.ReadFile(devVectorFile)
	if err != nil {
		t.Fatal(err)
	}
	var want v4Vectors
	if err := json.Unmarshal(raw, &want); err != nil {
		t.Fatal(err)
	}
	if want.Seed != hex.EncodeToString(fixedSeed(1)) {
		t.Fatal("the vectors' seed moved")
	}
	for k, v := range v4Keys {
		if want.Keys[k] != v {
			t.Fatalf("the vectors' key %s moved", k)
		}
	}
	if len(want.Out) != len(got) {
		t.Fatalf("%d outputs pinned, %d made", len(want.Out), len(got))
	}
	for k, v := range want.Out {
		if got[k] != v {
			t.Errorf("%s: %s, pinned %s", k, got[k], v)
		}
	}

	// every address and seal key apart: from each other, from the identity
	// pair's (the same seed), from every hello seal key of the same keys
	seen := map[string]string{}
	apart := func(name, v string) {
		if prev, ok := seen[v]; ok {
			t.Errorf("%s is %s", name, prev)
		}
		seen[v] = name
	}
	for k, v := range got {
		if !strings.HasSuffix(k, " sk") {
			apart(k, v)
		}
	}
	v4 := v4Outputs(t)
	// the v4 file's device pair is this one, made by hand
	if v4["da rcv by da"] != got["a5-b9 rcv a5"] {
		t.Fatal("the v4 file's device pair moved")
	}
	for k, v := range v4 {
		if strings.HasSuffix(k, " sk") || strings.HasSuffix(k, " by b") || strings.HasPrefix(k, "da ") {
			continue
		}
		apart("v4 "+k, v)
	}
	devKeys := map[string]xid{"a1": w.a, "a5": w.da, "b1": w.b, "b9": w.db}
	for _, dc := range w.cases("") {
		x, y := devKeys[dc.x], devKeys[dc.y]
		if _, pk, err := v4HelloSealKey(x, y.pub); err == nil {
			apart(dc.name+" hlo "+dc.x, pk)
		}
		if _, pk, err := v4HelloSealKey(y, x.pub); err == nil {
			apart(dc.name+" hlo "+dc.y, pk)
		}
		// a seedless rcv or snd is no address of anything: still apart
		p := mustPair(t, dc.xId, dc.xArg[:strings.LastIndex(dc.xArg, ".")]).v4()
		_, pk := roleKey(t, p, roleRcv, true)
		apart(dc.name+" seedless rcv", pk)
		_, pk = roleKey(t, p, roleSnd, true)
		apart(dc.name+" seedless snd", pk)
	}

	// the opener address by hand, from 3.6's line
	shared, err := curve25519.X25519(w.a.priv[:], w.db.pub[:])
	if err != nil {
		t.Fatal(err)
	}
	h := sha256.New()
	lo, hi := w.a.pub, w.b.pub
	if string(lo[:]) > string(hi[:]) {
		lo, hi = hi, lo
	}
	h.Write(lo[:])
	h.Write(hi[:])
	salt := h.Sum(nil)[:16]
	var byHand string
	for ctr := byte(0); ctr < 4 && byHand == ""; ctr++ {
		info := append([]byte("kryfo-conv-v4:"), libsignalKey(w.a.pub)...)
		info = append(info, libsignalKey(w.db.pub)...)
		info = append(info, "opn"...)
		info = append(info, ctr)
		if pk, err := nostr2.GetPublicKey(hex.EncodeToString(nostrHkdf(shared, salt, info, 32))); err == nil {
			byHand = pk
		}
	}
	if byHand != got["a1-b9 opn a1"] {
		t.Fatalf("the opener address by hand %s, made %s", byHand, got["a1-b9 opn a1"])
	}

	// another seed moves the seeded pair and leaves the opener address
	other := hex.EncodeToString(fixedSeed(2))
	forgetDevicePair(dvA1, w.b.pub, 9, 1)
	o := pairView(t, mustPair(t, dvA1, w.bHex+"/9/1."+other), "x", "me", "them")
	if o["x rcv me"] == got["a1-b9 rcv a1"] || o["x snd me"] == got["a1-b9 snd a1"] {
		t.Fatal("the seed is not in the device pair")
	}
	if o["x opn me"] != got["a1-b9 opn a1"] || o["x ops me"] != got["a1-b9 ops a1"] {
		t.Fatal("the seed reached the opener address")
	}
}

// device 1 to device 1 is today's pair, byte for byte, and the switch
// off leaves every device pair out
func TestDeviceOneIsTheIdentityPair(t *testing.T) {
	w := newDevWorld(t)
	seed := hex.EncodeToString(fixedSeed(1))
	plain := mustPair(t, dvA1, w.bHex+"."+seed)
	named := mustPair(t, dvA1, w.bHex+"/1/1."+seed)
	if named.dev != nil {
		t.Fatal("1/1 made a device pair")
	}
	_, p1, _ := plain.rcvAddress()
	_, p2, _ := named.rcvAddress()
	t1, _ := plain.theirAddress()
	t2, _ := named.theirAddress()
	_, pinned, _ := v4RcvAddress(phonePair(w.a, w.b.pub, fixedSeed(1)))
	if p1 != p2 || t1 != t2 || p1 != pinned || plain.subKey(w.bHex) != named.subKey(w.bHex) {
		t.Fatal("1/1 is not the identity pair")
	}
	if plain.subKey(w.bHex) != subKey(dvA1, w.bHex) {
		t.Fatal("the identity pair's subscription moved")
	}
	gw, err := named.wrap("x")
	if err != nil {
		t.Fatal(err)
	}
	if got, _, err := v4UnwrapStamped(phonePair(w.b, w.a.pub, fixedSeed(1)), gw); err != nil || got != "x" {
		t.Fatalf("%q %v", got, err)
	}
	if _, _, err := pairArg(dvA1, w.bHex+"/1/1"); err == nil {
		t.Fatal("1/1 without a seed taken")
	}
	// the identity pair has no opener address and no device opener
	if _, err := plain.openerOf(); err == nil {
		t.Fatal("an opener address on the identity pair")
	}
	if res := nostrSendDeviceOpener(dvA1, w.bHex+"."+seed, "x"); !strings.HasPrefix(res, "error") {
		t.Fatal(res)
	}

	devicePairsOn.Store(false)
	for _, arg := range []string{w.bHex + "/9/1." + seed, w.bHex + "/9/1", w.bHex + "/1/1." + seed} {
		if _, _, err := pairArg(dvA1, arg); !errors.Is(err, errDevicePairsOff) {
			t.Fatalf("%s with the switch off: %v", arg, err)
		}
	}
	if res := nostrSubscribe(dvA1, w.bHex+"/9/1", false); !strings.Contains(res, "off") {
		t.Fatalf("listen with the switch off: %s", res)
	}
	if err := pairSeedAfresh(dvA1, w.bHex+"/9/1", seed); !errors.Is(err, errDevicePairsOff) {
		t.Fatalf("a device seed with the switch off: %v", err)
	}
	// today's forms as before
	if _, _, err := pairArg(dvA1, w.bHex+"."+seed); err != nil {
		t.Fatal(err)
	}
	if got := (identPeer{I: 1, X: "ab", S: "cd"}).arg(); got != "ab.cd" {
		t.Fatal(got)
	}
	if got := (identPeer{I: 1, X: "ab", T: 9, M: 1, S: "cd"}).arg(); got != "ab/9/1.cd" {
		t.Fatal(got)
	}
}

// what a call may name: its own device only, listed devices, well formed
func TestDevicePairArgRules(t *testing.T) {
	w := newDevWorld(t)
	seed := hex.EncodeToString(fixedSeed(1))
	bad := map[string]struct {
		ident int
		arg   string
	}{
		"a phone as device 5":        {dvA1, w.bHex + "/9/5." + seed},
		"a device as the phone":      {dvA5, w.bHex + "/9/1." + seed},
		"a device as another":        {dvA5, w.bHex + "/9/6." + seed},
		"a linked identity pair":     {dvA5, w.bHex + "." + seed},
		"a linked v3 pair":           {dvA5, w.bHex},
		"a linked 1/1":               {dvA5, w.bHex + "/1/1." + seed},
		"a device not listed":        {dvA1, w.bHex + "/8/1." + seed},
		"itself":                     {dvA5, w.aHex + "/5/5." + seed},
		"device 0":                   {dvA1, w.bHex + "/0/1." + seed},
		"device 128":                 {dvA1, w.bHex + "/128/1." + seed},
		"a leading zero":             {dvA1, w.bHex + "/09/1." + seed},
		"a sign":                     {dvA1, w.bHex + "/+9/1." + seed},
		"one id":                     {dvA1, w.bHex + "/9." + seed},
		"three ids":                  {dvA1, w.bHex + "/9/1/2." + seed},
		"not a number":               {dvA1, w.bHex + "/x/1." + seed},
		"a short seed":               {dvA1, w.bHex + "/9/1.abcd"},
		"an empty seed":              {dvA1, w.bHex + "/9/1."},
		"a bad peer":                 {dvA1, "zz/9/1." + seed},
		"an identity as a device":    {dvA1, w.aHex + "/7/1." + seed},
		"no such identity":           {79, w.bHex + "/9/1." + seed},
		"another identity's device":  {dvB1, w.aHex + "/5/9." + seed},
		"a list naming my own phone": {dvB1, w.bHex + "/3/1." + seed},
	}
	// device 7 of a: its identity key; device 3 of b: b's phone key
	w.keys.put(w.a.pub, 7, w.a.pub)
	w.keys.put(w.b.pub, 3, w.b.pub)
	// b's lists naming my identity key and my own device key
	w.keys.put(w.b.pub, 7, w.a.pub)
	w.keys.put(w.b.pub, 6, w.da.pub)
	bad["b's device as my identity, on my phone"] = struct {
		ident int
		arg   string
	}{dvA1, w.bHex + "/7/1." + seed}
	bad["b's device as my identity, on my device"] = struct {
		ident int
		arg   string
	}{dvA5, w.bHex + "/7/5." + seed}
	bad["b's device as my own device key"] = struct {
		ident int
		arg   string
	}{dvA5, w.bHex + "/6/5." + seed}
	for name, c := range bad {
		if _, _, err := pairArg(c.ident, c.arg); err == nil {
			t.Errorf("%s taken", name)
		}
	}
	// no lists held: only the phone's side
	setDeviceKeys(nil)
	if _, _, err := pairArg(dvA1, w.bHex+"/9/1."+seed); err == nil {
		t.Fatal("a device key without a list")
	}
	if _, _, err := pairArg(dvA5, w.bHex+"/1/5."+seed); err != nil {
		t.Fatalf("a device to a phone needs no list: %v", err)
	}
	setDeviceKeys(w.keys)

	// one seed per pair, a new one only afresh, and a new key on the same
	// id is another pair
	arg := w.bHex + "/9/1"
	if _, _, err := pairArg(dvA1, arg+"."+seed); err != nil {
		t.Fatal(err)
	}
	other := hex.EncodeToString(fixedSeed(2))
	if _, _, err := pairArg(dvA1, arg+"."+other); err == nil {
		t.Fatal("a second seed taken")
	}
	if err := pairSeedAfresh(dvA1, arg, other); err != nil {
		t.Fatal(err)
	}
	if _, _, err := pairArg(dvA1, arg+"."+seed); err == nil {
		t.Fatal("the old seed taken after afresh")
	}
	if err := pairSeedAfresh(dvA1, arg+"."+seed, other); err == nil {
		t.Fatal("a seed in the pair arg of afresh")
	}
	if err := pairSeedAfresh(dvA1, w.bHex+"/1/1", other); err == nil {
		t.Fatal("afresh for 1/1 as a device pair")
	}
	w.keys.put(w.b.pub, 9, w.da.pub)
	if _, _, err := pairArg(dvA1, arg+"."+seed); err != nil {
		t.Fatalf("a new key on device 9 kept the old pair's seed: %v", err)
	}
	w.keys.put(w.b.pub, 9, w.db.pub)
	forgetDevicePair(dvA1, w.b.pub, 9, 1)
	if _, _, err := pairArg(dvA1, arg+"."+seed); err != nil {
		t.Fatalf("forgotten, still held: %v", err)
	}
	identDrop(dvA5)
	if isLinked(dvA5) {
		t.Fatal("a dropped identity stays linked")
	}
	putIdentity(dvA5, w.da)
	if err := putLinkedIdent(dvA5, w.a.pub, 1); err == nil {
		t.Fatal("a linked device as 1")
	}
	if err := putLinkedIdent(dvA5, w.a.pub, 5); err != nil {
		t.Fatal(err)
	}

	// the opener address listens only, and has no first contact
	if res := nostrSend(dvB9, w.aHex+"/1/9", "x"); !strings.Contains(res, "with its seed") {
		t.Fatalf("a send on an opener address: %s", res)
	}
	if res := nostrSendDeviceOpener(dvB9, w.aHex+"/1/9", "x"); !strings.HasPrefix(res, "error") {
		t.Fatalf("an opener without its seed: %s", res)
	}
	c := mustPair(t, dvB9, w.aHex+"/1/9."+seed)
	if _, err := c.wrapFirstContact(w.aHex, "x"); err == nil {
		t.Fatal("a device pair to a first-contact address")
	}
}

// an opener opens on the receiver's opener address only, from that device
// only; what follows opens on the seeded pair only
func TestDeviceOpenerOpensOnItsAddress(t *testing.T) {
	w := newDevWorld(t)
	seed := hex.EncodeToString(fixedSeed(1))
	send := mustPair(t, dvB9, w.aHex+"/1/9."+seed)
	o, err := send.openerOf()
	if err != nil {
		t.Fatal(err)
	}
	gw, err := o.wrap("opener")
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := keptSealOf(gw.ID); !ok {
		t.Fatal("no seal kept")
	}
	listen := mustPair(t, dvA1, w.bHex+"/9/1")
	if got, _, err := listen.unwrapStamped(gw); err != nil || got != "opener" {
		t.Fatalf("%q %v", got, err)
	}
	seeded := mustPair(t, dvA1, w.bHex+"/9/1."+seed)
	if _, _, err := seeded.unwrapStamped(gw); err == nil {
		t.Fatal("an opener opened on the seeded pair")
	}
	if _, _, err := mustPair(t, dvA1, w.bHex+"."+seed).unwrapStamped(gw); err == nil {
		t.Fatal("an opener opened on the identity pair")
	}
	// a's device 5 has its own opener address with b's device 9
	if _, _, err := mustPair(t, dvA5, w.bHex+"/9/5").unwrapStamped(gw); err == nil {
		t.Fatal("an opener opened on another device's address")
	}
	// sealed by anyone else to the same address: refused
	_, rcvPk, _ := listen.rcvAddress()
	sk, pk, _ := roleKey2(mustPair(t, dvA5, w.bHex+"/9/5"))
	forged, err := giftWrapAs(sk, pk, rcvPk, "forged")
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := listen.unwrapStamped(forged); err == nil {
		t.Fatal("an opener sealed by another device taken")
	}
	after, err := send.wrap("after")
	if err != nil {
		t.Fatal(err)
	}
	if got, _, err := seeded.unwrapStamped(after); err != nil || got != "after" {
		t.Fatalf("%q %v", got, err)
	}
	if _, _, err := listen.unwrapStamped(after); err == nil {
		t.Fatal("a seeded wrap opened on the opener address")
	}
	if after.Tags.GetFirst([]string{"p"}).Value() == gw.Tags.GetFirst([]string{"p"}).Value() {
		t.Fatal("the opener and what follows on one address")
	}
}

func roleKey2(c convPair) (sk, pk string, err error) {
	o, err := c.openerOf()
	if err != nil {
		return "", "", err
	}
	return o.v4().role(roleOps, true)
}

// the tags device pairs carry, and back
func TestDevicePairTags(t *testing.T) {
	w := newDevWorld(t)
	seed := hex.EncodeToString(fixedSeed(1))
	c := mustPair(t, dvA1, w.bHex+"/9/1."+seed)
	o, _ := c.openerOf()
	if k := c.subKey(w.bHex); k != "i71:"+w.bHex+"/9/1" {
		t.Fatal(k)
	}
	if k := o.subKey(w.bHex); k != "i71:"+w.bHex+"/9/1/opn" {
		t.Fatal(k)
	}
	main := convPair{ident: mainIdent, dev: &devPair{their: 9, my: 1}}
	if k := main.subKey(w.bHex); k != w.bHex+"/9/1" {
		t.Fatal(k)
	}
	for tag, want := range map[string]struct {
		ident     int
		their, my uint8
		opener    bool
	}{
		"i71:" + w.bHex + "/9/1":     {71, 9, 1, false},
		"i71:" + w.bHex + "/9/1/opn": {71, 9, 1, true},
		w.bHex + "/127/1":            {0, 127, 1, false},
		w.bHex + "/1/5/opn":          {0, 1, 5, true},
	} {
		i, p, th, my, op, ok := devTagOf(tag)
		if !ok || i != want.ident || p != w.bHex || th != want.their || my != want.my || op != want.opener {
			t.Errorf("%s: %d %s %d %d %v %v", tag, i, p, th, my, op, ok)
		}
	}
	for _, tag := range []string{
		w.bHex, "i71:" + w.bHex, "firstcontact", "room:" + w.bHex + ":0", "i0:" + w.bHex + "/9/1",
		"i071:" + w.bHex + "/9/1", strings.ToUpper(w.bHex) + "/9/1", w.bHex + "/9/1/snd", w.bHex + "/0/1",
		w.bHex + "/9/1/opn/opn", "i:" + w.bHex + "/9/1",
	} {
		if _, _, _, _, _, ok := devTagOf(tag); ok {
			t.Errorf("%s read as a device pair", tag)
		}
	}
	// a dropped identity takes its device pairs' listens with it
	nostrMu.Lock()
	nostrSubs[c.subKey(w.bHex)] = func() {}
	nostrSubs[o.subKey(w.bHex)] = func() {}
	nostrMu.Unlock()
	identDrop(dvA1)
	nostrMu.Lock()
	_, a := nostrSubs[c.subKey(w.bHex)]
	_, b := nostrSubs[o.subKey(w.bHex)]
	nostrMu.Unlock()
	if a || b {
		t.Fatal("a device pair listens on after its identity went")
	}
}

// on a relay stand-in: b's device 9 opens to a's phone on a's opener
// address, a listens there, takes the seed, and the next copy comes on the
// seeded pair; lines carry the device pair's tag, the knocks both
// addresses under b's identity, and nothing touches a and b's own pair
func TestDevicePairOnTheRelay(t *testing.T) {
	r := newRelayStandIn(t, 0)
	r.mu.Lock()
	r.keep = true
	r.mu.Unlock()
	useStandIns(t, modeFast, nil, r)
	w := newDevWorld(t)
	nostrMu.Lock()
	nostrInbox, nostrInboxDone = nil, nil
	nostrMu.Unlock()
	seed := hex.EncodeToString(fixedSeed(1))
	_, identRcv, _ := mustPair(t, dvA1, w.bHex+"."+seed).rcvAddress()
	identTheirs, _ := mustPair(t, dvA1, w.bHex+"."+seed).theirAddress()
	listen := mustPair(t, dvA1, w.bHex+"/9/1")
	_, opnRcv, _ := listen.rcvAddress()
	_, seededRcv, _ := mustPair(t, dvA1, w.bHex+"/9/1."+seed).rcvAddress()
	forgetDevicePair(dvA1, w.b.pub, 9, 1)

	// both containers are one engine here: what one sent is not the
	// other's own
	notMine := func() {
		nostrMu.Lock()
		nostrSentIDs = map[string]bool{}
		nostrMu.Unlock()
	}
	line := func(tag, body string) func() bool {
		return func() bool {
			nostrMu.Lock()
			defer nostrMu.Unlock()
			for _, l := range nostrInbox {
				if l == tag+"|"+body {
					return true
				}
			}
			return false
		}
	}
	// sent first, read from the store as the listen starts
	if res := nostrSendDeviceOpener(dvB9, w.aHex+"/1/9."+seed, "opener"); res != "ok" {
		t.Fatal(res)
	}
	notMine()
	if res := nostrSubscribe(dvA1, w.bHex+"/9/1", false); res != "ok" {
		t.Fatal(res)
	}
	defer nostrUnsubscribe(dvA1, w.bHex+"/9/1")
	waitFor(t, "the opener", 10*time.Second, line("i71:"+w.bHex+"/9/1/opn", "opener"))

	if err := pairSeedAfresh(dvA1, w.bHex+"/9/1", seed); err != nil {
		t.Fatal(err)
	}
	if res := nostrSend(dvB9, w.aHex+"/1/9."+seed, "after"); res != "ok" {
		t.Fatal(res)
	}
	notMine()
	if res := nostrSubscribe(dvA1, w.bHex+"/9/1."+seed, false); res != "ok" {
		t.Fatal(res)
	}
	defer nostrUnsubscribe(dvA1, w.bHex+"/9/1."+seed)
	waitFor(t, "the copy after", 10*time.Second, line("i71:"+w.bHex+"/9/1", "after"))

	var to []string
	r.mu.Lock()
	for _, e := range r.events {
		b, _ := easyjson.Marshal(e)
		var ev nostr2.Event
		if err := json.Unmarshal(b, &ev); err == nil {
			to = append(to, ev.Tags.GetFirst([]string{"p"}).Value())
		}
	}
	r.mu.Unlock()
	if len(to) != 2 || to[0] != opnRcv || to[1] != seededRcv {
		t.Fatalf("published to %v, want the opener then the seeded address", to)
	}
	if len(connsOn(r.snapshot(), []string{identRcv, identTheirs})) > 0 {
		t.Fatal("the identity pair's addresses touched")
	}
	var opnKnock, seededKnock bool
	for _, k := range knockTargets() {
		if k.pk == opnRcv && k.peer == w.bHex {
			opnKnock = true
		}
		if k.pk == seededRcv && k.peer == w.bHex {
			seededKnock = true
		}
	}
	if !opnKnock || !seededKnock {
		t.Fatalf("knocks: opener %v, seeded %v", opnKnock, seededKnock)
	}
	// a hidden chat leaves its device pairs out of the knocks too
	for _, k := range knockLive([]string{w.bHex}) {
		if k.pk == opnRcv || k.pk == seededRcv {
			t.Fatal("a hidden contact's device pair knocked")
		}
	}
}

// closing a device-pair listen goes by what it noted: with the switch off,
// with the device off the list, after a new key on the id. an opener
// address leaves the top-up alone, and it listens on a lane of its own
func TestDeviceListenClosesByWhatItNoted(t *testing.T) {
	r := newRelayStandIn(t, 0)
	useStandIns(t, modeFast, nil, r)
	w := newDevWorld(t)
	var dropped, purged []string
	oldDrop, oldPurge := devDropFiles, devPurgeTopup
	devDropFiles = func(pk string) { dropped = append(dropped, pk) }
	devPurgeTopup = func(pk string) { purged = append(purged, pk) }
	t.Cleanup(func() { devDropFiles, devPurgeTopup = oldDrop, oldPurge })
	took := func(what string, wantDropped, wantPurged []string) {
		t.Helper()
		if strings.Join(dropped, ",") != strings.Join(wantDropped, ",") || strings.Join(purged, ",") != strings.Join(wantPurged, ",") {
			t.Fatalf("%s: dropped %v purged %v, want %v %v", what, dropped, purged, wantDropped, wantPurged)
		}
		dropped, purged = nil, nil
	}
	live := func(key string) bool {
		nostrMu.Lock()
		defer nostrMu.Unlock()
		_, ok := nostrSubs[key]
		return ok
	}
	seed := hex.EncodeToString(fixedSeed(1))
	seeded, opn := w.bHex+"/9/1."+seed, w.bHex+"/9/1"
	sc, oc := mustPair(t, dvA1, seeded), mustPair(t, dvA1, opn)
	_, sRcv, _ := sc.rcvAddress()
	sTheirs, _ := sc.theirAddress()
	_, oRcv, _ := oc.rcvAddress()
	sTag, oTag := sc.subKey(w.bHex), oc.subKey(w.bHex)
	idTag := subKey(dvA1, w.bHex)
	sub := func(arg string) {
		t.Helper()
		if res := nostrSubscribe(dvA1, arg, false); res != "ok" {
			t.Fatal(res)
		}
	}
	sub(seeded)
	sub(opn)
	sub(w.bHex + "." + seed)
	defer nostrUnsubscribe(dvA1, w.bHex+"."+seed)

	// L2: the opener address on its identity's own lane
	for _, k := range knockTargets() {
		if k.pk == oRcv && !strings.HasPrefix(k.lane, opnLane(dvA1)+":") {
			t.Fatalf("the opener address on %s", k.lane)
		}
		if k.pk == sRcv && !strings.HasPrefix(k.lane, laneEveryday+":") {
			t.Fatalf("the seeded address on %s", k.lane)
		}
	}

	// the switch off stops every device pair and nothing else
	setDevicePairs(false)
	if live(sTag) || live(oTag) || !live(idTag) {
		t.Fatalf("switch off: seeded %v, opener %v, identity pair %v", live(sTag), live(oTag), live(idTag))
	}
	took("switch off", nil, nil)
	if err := nostrUnsubscribe(dvA1, seeded); err != nil {
		t.Fatal(err)
	}
	took("seeded closed, switch off", []string{sRcv}, []string{sTheirs})
	// L1: my opener stays in the top-up
	if err := nostrUnsubscribe(dvA1, opn); err != nil {
		t.Fatal(err)
	}
	took("opener closed", []string{oRcv}, nil)
	if err := nostrUnsubscribe(dvA1, seeded); err != nil {
		t.Fatal(err)
	}
	took("closed twice", nil, nil)
	setDevicePairs(true)

	// a new key on device 9: the old key's files and top-up go, not the new
	sub(seeded)
	nk := newXid(t)
	w.keys.put(w.b.pub, 9, nk.pub)
	nc := mustPair(t, dvA1, seeded)
	_, nRcv, _ := nc.rcvAddress()
	if nRcv == sRcv {
		t.Fatal("a new key kept the address")
	}
	if err := nostrUnsubscribe(dvA1, seeded); err != nil {
		t.Fatal(err)
	}
	took("closed after a new key", []string{sRcv}, []string{sTheirs})
	// listened again on the new key: the old one goes as it is replaced
	w.keys.put(w.b.pub, 9, w.db.pub)
	sub(seeded)
	w.keys.put(w.b.pub, 9, nk.pub)
	sub(seeded)
	nTheirs, _ := nc.theirAddress()
	took("replaced by a new key", []string{sRcv}, []string{sTheirs})
	// off the list: still closed by its note
	delete(w.keys, w.bHex+"/9")
	if err := nostrUnsubscribe(dvA1, seeded); err != nil {
		t.Fatal(err)
	}
	took("closed off the list", []string{nRcv}, []string{nTheirs})
	if live(sTag) {
		t.Fatal("still listening")
	}
	// 1/1 closes the identity pair
	if err := nostrUnsubscribe(dvA1, w.bHex+"/1/1."+seed); err != nil || live(idTag) {
		t.Fatalf("1/1 left the identity pair on: %v", err)
	}
	took("identity pair", nil, nil)
	// an identity let go takes its notes
	w.keys.put(w.b.pub, 9, w.db.pub)
	sub(seeded)
	identDrop(dvA1)
	devListensMu.Lock()
	_, kept := devListens[sTag]
	devListensMu.Unlock()
	if kept || live(sTag) {
		t.Fatal("a dropped identity kept its device listen")
	}
}
