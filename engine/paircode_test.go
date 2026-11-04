// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"bytes"
	"encoding/base64"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"fiatjaf.com/nostr"
	"github.com/halo/engine/pake"
)

func keptEvents(r *relayStandIn) int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.events)
}

// pinned against ~/kryfo-notes/pake/boxref.py (python hmac and secp256k1)
func TestPairBoxKeysVector(t *testing.T) {
	for _, v := range []struct {
		box    string
		w      uint64
		sk, pk string
	}{
		{"07", 2950000, "4f8bfc53602e3dad275bee1e50973d8880081f6401037a11c3f680be416936fd", "028111af16c46af26b90f0984bd1f4e5354d8b7a6aec78642ca5c770841d831c"},
		{"93", 0, "0cd3f8385b5b4deebc47113137cf677b49cc1385dd9028cbae11bf3a7b24ed63", "882588b4d642bd81c5e63ac2b94f827e212de76fa5a1ab7063d35b0b65355a54"},
		{"00", 1<<64 - 1, "193223d28e37b8116ca3a1241cb7e5a3d4a2358d709971f970231a4e15545950", "ebe4815a2ea93e9c2a762caad85731fd3d190ef48cea2867032d052951895953"},
	} {
		sk, pk, err := pairBoxKeys(v.box, v.w)
		if err != nil || sk != v.sk || pk != v.pk {
			t.Fatalf("%s %d: %s %s %v", v.box, v.w, sk, pk, err)
		}
	}
	if _, _, err := pairBoxKeys("7", 1); err == nil {
		t.Fatal("a one-digit box")
	}
	a, _, _ := pairBoxKeys("07", 1)
	b, _, _ := pairBoxKeys("07", 2)
	c, _, _ := pairBoxKeys("08", 1)
	if a == b || a == c {
		t.Fatal("box or window does not change the address")
	}
}

func pairTestInvite(tag byte) []byte {
	b := bytes.Repeat([]byte{tag}, 1941)
	b[0] = 'K'
	return b
}

func pairB64(b []byte) string { return base64.StdEncoding.EncodeToString(b) }

func pairFast(t *testing.T) {
	t.Helper()
	oldGap, oldCollect, oldWait := pairStepGap, pairCollectWindow, pairAnswerWait
	pairStepGap, pairCollectWindow = 0, 200*time.Millisecond
	t.Cleanup(func() {
		pairStepGap, pairCollectWindow, pairAnswerWait = oldGap, oldCollect, oldWait
		pairClock = time.Now
		pairRunsMu.Lock()
		hs := make([]int64, 0, len(pairRuns))
		for h := range pairRuns {
			hs = append(hs, h)
		}
		pairRunsMu.Unlock()
		for _, h := range hs {
			pairDrop(h)
		}
		pairTriedMu.Lock()
		clear(pairTriedSet)
		pairTriedMu.Unlock()
	})
}

func pairRelays(t *testing.T, n int) []*relayStandIn {
	t.Helper()
	rs := make([]*relayStandIn, n)
	for i := range rs {
		rs[i] = newRelayStandIn(t, 0)
		rs[i].keep = true
	}
	useStandIns(t, modeBalanced, nil, rs...)
	return rs
}

func shareOrFail(t *testing.T, inv []byte) (int64, string) {
	t.Helper()
	h, shown, res := pairShare(pairB64(inv))
	if shown == nil {
		t.Fatalf("share: %s", res)
	}
	return h, string(shown)
}

func joinOrFail(t *testing.T, code string, inv []byte) int64 {
	t.Helper()
	res := pairJoin([]byte(code), pairB64(inv))
	h, ok := strings.CutPrefix(res, "ok ")
	if !ok {
		t.Fatalf("join %q: %s", code, res)
	}
	n, err := strconv.ParseInt(h, 10, 64)
	if err != nil {
		t.Fatal(err)
	}
	return n
}

// a code with the same box and another secret
func wrongSecret(code string) string {
	d := strings.ReplaceAll(code, " ", "")
	last := (d[7]-'0'+1)%10 + '0'
	return d[:7] + string(last)
}

// steps both runs until each says done or one ends; their last answers
func stepBoth(t *testing.T, s, j int64, rounds int) (string, string) {
	t.Helper()
	var sr, jr string
	for range rounds {
		if !strings.HasPrefix(jr, "done") && !strings.HasPrefix(jr, "error") {
			jr = pairStep(j)
		}
		if !strings.HasPrefix(sr, "done") && !strings.HasPrefix(sr, "error") {
			sr = pairStep(s)
		}
		if strings.HasPrefix(sr, "done") && strings.HasPrefix(jr, "done") {
			break
		}
		if strings.HasPrefix(sr, "error") || strings.HasPrefix(jr, "error") {
			break
		}
	}
	return sr, jr
}

// the whole run over two relays: the code is eight digits, each side gets
// the other's invite, and the secret digits are in nothing a relay holds
func TestPairShareAndJoin(t *testing.T) {
	pairFast(t)
	rs := pairRelays(t, 2)
	invA, invB := pairTestInvite(0xa1), pairTestInvite(0xb2)
	s, code := shareOrFail(t, invA)
	if len(code) != 10 || code[2] != ' ' || code[6] != ' ' {
		t.Fatalf("code %q", code)
	}
	j := joinOrFail(t, code, invB)
	sr, jr := stepBoth(t, s, j, 10)
	if sr != "done "+pairB64(invB) || jr != "done "+pairB64(invA) {
		t.Fatalf("sharer %q, joiner %q", sr, jr)
	}
	// offer, answer, finish on each relay, all at the box's address
	pk := func() map[string]bool {
		w := pake.Window(time.Now())
		m := map[string]bool{}
		for _, x := range []uint64{w - 1, w, w + 1} {
			_, p, _ := pairBoxKeys(code[:2], x)
			m[p] = true
		}
		return m
	}()
	for i, r := range rs {
		if n := keptEvents(r); n != 3 {
			t.Errorf("relay %d holds %d events", i, n)
		}
		r.mu.Lock()
		for _, ev := range r.events {
			if tg := ev.Tags.Find("p"); len(tg) < 2 || !pk[tg[1]] {
				t.Errorf("an event off the box: %v", tg)
			}
			var addrs []pairAddr
			w := pake.Window(time.Now())
			for _, x := range []uint64{w - 1, w, w + 1} {
				a, _ := pairAddrOf(code[:2], x)
				addrs = append(addrs, a)
			}
			m, _, ok := pairBoxOpen(ev, addrs)
			if !ok || bytes.Contains(m, []byte(strings.ReplaceAll(code[3:], " ", ""))) {
				t.Error("an event that does not read, or the secret digits in one")
			}
		}
		r.mu.Unlock()
	}
	// finish wipes: the handle names nothing after
	pairDrop(s)
	pairDrop(j)
	if pairStep(s) != "error: gone" || pairStep(j) != "error: gone" {
		t.Fatal("a finished run still steps")
	}
}

// a wrong secret is a try the sharer counts and the joiner never finishes;
// the sharer still pairs with the right code after
func TestPairWrongCodeIsATry(t *testing.T) {
	pairFast(t)
	pairRelays(t, 1)
	s, code := shareOrFail(t, pairTestInvite(1))
	bad := joinOrFail(t, wrongSecret(code), pairTestInvite(2))
	if r := pairStep(bad); r != "wait 0" {
		t.Fatalf("the wrong joiner: %q", r)
	}
	if r := pairStep(s); r != "wait 1" {
		t.Fatalf("the sharer after a wrong code: %q", r)
	}
	// the same answer again is not another try
	if r := pairStep(s); r != "wait 1" {
		t.Fatalf("the sharer again: %q", r)
	}
	if r := pairStep(bad); r != "wait 0" {
		t.Fatalf("the wrong joiner waits: %q", r)
	}
	// past its offer's time the wrong joiner gives up
	pairClock = func() time.Time { return time.Now().Add(pake.OfferLife + pake.Skew + time.Minute) }
	if r := pairStep(bad); r != "error: unanswered" {
		t.Fatalf("the wrong joiner later: %q", r)
	}
	pairClock = time.Now
	good := joinOrFail(t, code, pairTestInvite(3))
	sr, jr := stepBoth(t, s, good, 10)
	if !strings.HasPrefix(sr, "done") || !strings.HasPrefix(jr, "done") {
		t.Fatalf("after a wrong try: %q %q", sr, jr)
	}
}

// three wrong codes kill it: the right one is refused after
func TestPairThreeWrongKillTheCode(t *testing.T) {
	pairFast(t)
	pairRelays(t, 1)
	s, code := shareOrFail(t, pairTestInvite(1))
	d := strings.ReplaceAll(code, " ", "")
	for i := range pake.MaxTries {
		w := []byte(d)
		w[2] = (w[2]-'0'+byte(i)+1)%10 + '0'
		j := joinOrFail(t, string(w), pairTestInvite(2))
		if r := pairStep(j); r != "wait 0" {
			t.Fatalf("wrong joiner %d: %q", i, r)
		}
		pairDrop(j)
	}
	if r := pairStep(s); r != "error: tries" {
		t.Fatalf("the sharer after three: %q", r)
	}
	if r := pairStep(s); r != "error: tries" {
		t.Fatalf("a dead code steps on: %q", r)
	}
	good := joinOrFail(t, code, pairTestInvite(3))
	for range 3 {
		if r := pairStep(good); strings.HasPrefix(r, "done") {
			t.Fatal("a dead code paired")
		}
	}
}

// a code typed again goes on from its tries (review F3): a fake sharer at
// the box gets three guesses at it, however often it is typed
func TestPairRetypedCodeKeepsItsTries(t *testing.T) {
	pairFast(t)
	pairAnswerWait = 0
	pairRelays(t, 1)
	// the fake sharer: same box, another secret, a fresh offer each time
	_, code := shareOrFail(t, pairTestInvite(1))
	typed := wrongSecret(code)
	for i := range pake.MaxTries {
		if i > 0 {
			// another offer at the box, as the fake one puts up
			pairShareAt(t, code[:2], pairTestInvite(9))
		}
		j := joinOrFail(t, typed, pairTestInvite(2))
		if r := pairStep(j); r != "wait 0" {
			t.Fatalf("typed %d: %q", i, r)
		}
		pairDrop(j)
	}
	if r := pairJoin([]byte(typed), pairB64(pairTestInvite(2))); r != "error: tries" {
		t.Fatalf("a fourth time: %q", r)
	}
	// with its spaces, as shown: the same code
	if r := pairJoin([]byte(typed[:2]+" "+typed[2:5]+" "+typed[5:]), pairB64(pairTestInvite(2))); r != "error: tries" {
		t.Fatalf("with spaces: %q", r)
	}
}

// an offer at box [box] from a sharer of its own
func pairShareAt(t *testing.T, box string, inv []byte) {
	t.Helper()
	r, err := pake.NewCode(nil)
	if err != nil {
		t.Fatal(err)
	}
	c, err := pake.ParseCode(box + r.String()[3:])
	if err != nil {
		t.Fatal(err)
	}
	s, err := pake.NewSharer(&c, inv)
	if err != nil {
		t.Fatal(err)
	}
	off, w, err := s.Offer(time.Now(), nil)
	if err != nil {
		t.Fatal(err)
	}
	a, err := pairAddrOf(box, w)
	if err != nil || !pairBoxPublish(t.Context(), pairLane(a.pk), a, off) {
		t.Fatal("no offer up")
	}
}

// one answer at a time: a second offer at the box waits until the first
// answer had its time
func TestPairJoinerAnswersOneAtATime(t *testing.T) {
	pairFast(t)
	pairRelays(t, 1)
	_, code := shareOrFail(t, pairTestInvite(1))
	pairShareAt(t, code[:2], pairTestInvite(9))
	pairShareAt(t, code[:2], pairTestInvite(8))
	j := joinOrFail(t, wrongSecret(code), pairTestInvite(2))
	pairStep(j)
	pairStep(j)
	if n := pairGet(j).joiner.Tries(); n != 1 {
		t.Fatalf("%d offers answered at once", n)
	}
	pairAnswerWait = 0
	pairStep(j)
	if n := pairGet(j).joiner.Tries(); n != 2 {
		t.Fatalf("%d answered after the wait", n)
	}
}

func TestPairJoinRefuses(t *testing.T) {
	pairFast(t)
	inv := pairB64(pairTestInvite(2))
	for code, want := range map[string]string{
		"482913":     "error: old",
		"482 913":    "error: old",
		"۴۸۲۹۱۳":     "error: old",
		"0712345":    "error: code",
		"07 123 45x": "error: code",
		"":           "error: code",
	} {
		if r := pairJoin([]byte(code), inv); r != want {
			t.Fatalf("%q: %q, want %q", code, r, want)
		}
	}
	if r := pairJoin([]byte("07123456"), "not base64!"); r != "error: invite" {
		t.Fatalf("a bad invite: %q", r)
	}
	if r := pairJoin([]byte("07123456"), pairB64(make([]byte, pake.MaxInvite+1))); r != "error: invite" {
		t.Fatalf("a long invite: %q", r)
	}
	if pairStep(424242) != "error: gone" {
		t.Fatal("an unknown handle steps")
	}
}

// at most pairRunsMax at once; cancel frees a place
func TestPairRunsCapped(t *testing.T) {
	pairFast(t)
	var hs []int64
	for i := range pairRunsMax {
		hs = append(hs, joinOrFail(t, "0712345"+strconv.Itoa(i), pairTestInvite(2)))
	}
	if r := pairJoin([]byte("07123459"), pairB64(pairTestInvite(2))); r != "error: busy" {
		t.Fatalf("one too many: %q", r)
	}
	pairDrop(hs[0])
	joinOrFail(t, "07123459", pairTestInvite(2))
}

// no relay takes the offer: the sharer is told, and nothing stays open
func TestPairShareUnreached(t *testing.T) {
	pairFast(t)
	a := newRelayStandIn(t, 0)
	useStandIns(t, modeBalanced, nil, a)
	a.srv.Close()
	if _, shown, res := pairShare(pairB64(pairTestInvite(1))); shown != nil || res != pairUnreached {
		t.Fatalf("share with no relay: %q", res)
	}
	pairRunsMu.Lock()
	n := len(pairRuns)
	pairRunsMu.Unlock()
	if n != 0 {
		t.Fatalf("%d runs left open", n)
	}
}

// the code's time over: both sides say so and are wiped
func TestPairExpires(t *testing.T) {
	pairFast(t)
	pairRelays(t, 1)
	s, code := shareOrFail(t, pairTestInvite(1))
	j := joinOrFail(t, code, pairTestInvite(2))
	pairClock = func() time.Time { return time.Now().Add(pairJoinLife + time.Minute) }
	if r := pairStep(s); r != "error: expired" {
		t.Fatalf("sharer: %q", r)
	}
	if r := pairStep(j); r != "error: expired" {
		t.Fatalf("joiner: %q", r)
	}
	if pairGet(s).sharer.Fails() != 0 {
		t.Fatal("fails")
	}
}

// the sharer puts a new offer up when the window turns, and a joiner who
// reads only the new window pairs
func TestPairNewWindowNewOffer(t *testing.T) {
	pairFast(t)
	rs := pairRelays(t, 1)
	start := time.Now()
	s, code := shareOrFail(t, pairTestInvite(1))
	next := (pake.Window(start)+1)*uint64(pake.WindowLength/time.Second) + 1
	pairClock = func() time.Time { return time.Unix(int64(next), 0).Add(time.Since(start)) }
	pairStep(s)
	if n := keptEvents(rs[0]); n != 2 {
		t.Fatalf("%d offers up after the turn", n)
	}
	j := joinOrFail(t, code, pairTestInvite(2))
	sr, jr := stepBoth(t, s, j, 10)
	if !strings.HasPrefix(sr, "done") || !strings.HasPrefix(jr, "done") {
		t.Fatalf("across the turn: %q %q", sr, jr)
	}
}

// steps from two isolates at once, and a cancel under way, under -race
func TestPairStepsAtOnce(t *testing.T) {
	pairFast(t)
	pairRelays(t, 1)
	s, code := shareOrFail(t, pairTestInvite(1))
	j := joinOrFail(t, code, pairTestInvite(2))
	var wg sync.WaitGroup
	for range 4 {
		wg.Add(2)
		go func() { defer wg.Done(); pairStep(s) }()
		go func() { defer wg.Done(); pairStep(j) }()
	}
	wg.Add(1)
	go func() { defer wg.Done(); pairDrop(s) }()
	wg.Wait()
	if pairStep(s) != "error: gone" {
		t.Fatal("a cancelled run steps")
	}
}

// each event at a box is signed by a key of its own, never the box's
func TestPairEventHasItsOwnAuthor(t *testing.T) {
	a, err := pairAddrOf("07", 5)
	if err != nil {
		t.Fatal(err)
	}
	e1, err := pairBoxEvent(a, []byte("KPO1xx"), time.Now())
	if err != nil {
		t.Fatal(err)
	}
	e2, _ := pairBoxEvent(a, []byte("KPO1xx"), time.Now())
	if e1.PubKey.Hex() == a.pk || e1.PubKey == e2.PubKey {
		t.Fatal("an author shared")
	}
	if !e1.VerifySignature() {
		t.Fatal("does not verify")
	}
	m, at, ok := pairBoxOpen(e1, []pairAddr{a})
	if !ok || string(m) != "KPO1xx" || at.pk != a.pk {
		t.Fatalf("open: %q %v", m, ok)
	}
	// not a pair message, or another address: not read
	e3, _ := pairBoxEvent(a, []byte("kryfo://share?id=x"), time.Now())
	if _, _, ok := pairBoxOpen(e3, []pairAddr{a}); ok {
		t.Fatal("a non-pair message read")
	}
	b, _ := pairAddrOf("08", 5)
	if _, _, ok := pairBoxOpen(e1, []pairAddr{b}); ok {
		t.Fatal("read at another address")
	}
	var none nostr.Event
	if _, _, ok := pairBoxOpen(none, []pairAddr{a}); ok {
		t.Fatal("an empty event read")
	}
}

// no relay answering is unreached, not empty; the deadline waits on a slow
// one while none has answered
func TestPairQueryUnreachedAndSlow(t *testing.T) {
	old := pairQueryDeadline
	pairQueryDeadline = 300 * time.Millisecond
	t.Cleanup(func() { pairQueryDeadline = old })
	a := newRelayStandIn(t, 0)
	useStandIns(t, modeBalanced, nil, a)
	a.srv.Close()
	if _, _, heard := pairCodeQuery(t.Context(), pairLane("x"), []string{"ab"}); heard != 0 {
		t.Fatal("a closed relay heard")
	}
	slow := newRelayStandIn(t, 0)
	slow.upgradeDelay = time.Second
	useStandIns(t, modeBalanced, nil, slow)
	if _, _, heard := pairCodeQuery(t.Context(), pairLane("x"), []string{"ab"}); heard != 1 {
		t.Fatal("the slow relay was not waited for")
	}
}

// the match is said on every step until finish or cancel: a step dart gave
// up on never loses it (review F1)
func TestPairDoneKeptUntilFinish(t *testing.T) {
	pairFast(t)
	pairRelays(t, 1)
	s, code := shareOrFail(t, pairTestInvite(1))
	j := joinOrFail(t, code, pairTestInvite(2))
	sr, jr := stepBoth(t, s, j, 10)
	if !strings.HasPrefix(sr, "done") || !strings.HasPrefix(jr, "done") {
		t.Fatalf("%q %q", sr, jr)
	}
	for range 3 {
		if pairStep(s) != sr || pairStep(j) != jr {
			t.Fatal("a later step lost the match")
		}
	}
	pairDrop(s)
	if pairStep(s) != "error: gone" {
		t.Fatal("finished, still there")
	}
}

// the sharer's finish lands on the relay but its ok comes after the step's
// deadline: the joiner matches, the sharer says finishing, goes on past the
// code's life, and matches on the next step. never one-sided (review F1)
func TestPairLateFinishStillMatchesBoth(t *testing.T) {
	pairFast(t)
	rs := pairRelays(t, 1)
	oldBudget := pairStepBudget
	t.Cleanup(func() { pairStepBudget = oldBudget })
	s, code := shareOrFail(t, pairTestInvite(1))
	j := joinOrFail(t, code, pairTestInvite(2))
	if r := pairStep(j); r != "wait 0" {
		t.Fatalf("joiner: %q", r)
	}
	rs[0].mu.Lock()
	rs[0].okDelay = 3 * time.Second
	rs[0].mu.Unlock()
	pairStepBudget = 1500 * time.Millisecond
	if r := pairStep(s); r != "finishing" {
		t.Fatalf("sharer with a late ok: %q", r)
	}
	if r := pairStep(j); !strings.HasPrefix(r, "done") {
		t.Fatalf("joiner after the finish landed: %q", r)
	}
	rs[0].mu.Lock()
	rs[0].okDelay = 0
	rs[0].mu.Unlock()
	pairStepBudget = oldBudget
	// past the code's life it still finishes
	pairClock = func() time.Time { return time.Now().Add(pairCodeLife + pake.Skew + time.Minute) }
	if r := pairStep(s); r != "done "+pairB64(pairTestInvite(2)) {
		t.Fatalf("sharer next: %q", r)
	}
}

// a step never runs past its deadline, whatever the relays do
func TestPairStepKeepsItsDeadline(t *testing.T) {
	pairFast(t)
	rs := pairRelays(t, 1)
	oldBudget := pairStepBudget
	t.Cleanup(func() { pairStepBudget = oldBudget })
	s, _ := shareOrFail(t, pairTestInvite(1))
	rs[0].mu.Lock()
	rs[0].reqDelay = 10 * time.Second
	rs[0].mu.Unlock()
	pairStepBudget = time.Second
	start := time.Now()
	pairStep(s)
	if took := time.Since(start); took > 3*time.Second {
		t.Fatalf("a step took %v", took)
	}
}

// a decoy reads the box on its own lane and puts nothing up
func TestDecoyPairLookPutsNothingUp(t *testing.T) {
	pairFast(t)
	rs := pairRelays(t, 1)
	if r := decoyPairLook("07"); r != "look" {
		t.Fatalf("look: %q", r)
	}
	if keptEvents(rs[0]) != 0 {
		t.Fatal("the decoy published")
	}
	if decoyPairLook("7") != "error: code" || decoyPairLook("0a") != "error: code" {
		t.Fatal("a box that is not two digits")
	}
	rs[0].srv.Close()
	if r := decoyPairLook("07"); r != "unreached" {
		t.Fatalf("no relay: %q", r)
	}
}
