// SPDX-License-Identifier: GPL-3.0-or-later
package main

// eight digit pair codes (identity v4 6, IDENTITY-V4.md 4.3 and 5.4). the
// first two digits are a public box, which with the ten-minute window names
// a rendezvous address; the last six are the cpace password (engine/pake)
// and never leave this process. the sharer puts an offer at the box, the
// joiner answers with its one-time invite sealed under the shared key, the
// sharer checks the tag and finishes with its own. each try is one guess.
//
// dart runs a pairing by handle: share or join makes a run, step does one
// round over the relays, finish or cancel wipes it. the code, the keys and
// the scalars stay here; dart only ever gets the code to show (the sharer)
// and the other side's invite once both tags held.

/*
#include <string.h>
*/
import "C"

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"math"
	"strconv"
	"sync"
	"time"
	"unsafe"

	"fiatjaf.com/nostr"
	"github.com/halo/engine/pake"
	"github.com/mailru/easyjson"
	nostr2 "github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip44"
)

// the box address: a secp256k1 key from hkdf over a fixed ikm, no salt,
// and the box and window in the info. a seed that is no key (about 2^-128)
// tries again with ":1", ":2", ":3" after the info
const (
	pairBoxIKM  = "kryfo-pair-v4"
	pairBoxInfo = "kryfo-pair-box-v4:"
)

func pairBoxKeys(box string, w uint64) (sk, pk string, err error) {
	if len(box) != pake.BoxDigits {
		return "", "", fmt.Errorf("a box is two digits")
	}
	base := pairBoxInfo + box + ":" + strconv.FormatUint(w, 10)
	for ctr := 0; ctr < 4; ctr++ {
		info := base
		if ctr > 0 {
			info += ":" + strconv.Itoa(ctr)
		}
		seed := nostrHkdf([]byte(pairBoxIKM), nil, []byte(info), 32)
		sk = hex.EncodeToString(seed)
		clear(seed)
		if pk, err = nostr2.GetPublicKey(sk); err == nil {
			return sk, pk, nil
		}
	}
	return "", "", fmt.Errorf("pair box derive failed")
}

// one box address, with the nip-44 key its events are sealed under. the
// box is public, so this hides nothing from someone who knows it; it keeps
// the events looking like other wraps
type pairAddr struct {
	w  uint64
	pk string
	ck [32]byte
}

func pairAddrOf(box string, w uint64) (pairAddr, error) {
	sk, pk, err := pairBoxKeys(box, w)
	if err != nil {
		return pairAddr{}, err
	}
	ck, err := nip44.GenerateConversationKey(pk, sk)
	if err != nil {
		return pairAddr{}, fmt.Errorf("key: %v", err)
	}
	return pairAddr{w: w, pk: pk, ck: ck}, nil
}

// how long a pair event stays on a relay: as long as an offer lives
const pairEventLife = pake.OfferLife

// no relay took the share, or none answered the lookup. the app words it
// for the person, so it stays this fixed text
const pairUnreached = "error: unreached"

// the event that puts msg at a, made at now, signed by a key made for this
// event alone
func pairBoxEvent(a pairAddr, msg []byte, now time.Time) (nostr.Event, error) {
	var out nostr.Event
	ct, err := nip44.Encrypt(base64.StdEncoding.EncodeToString(msg), a.ck)
	if err != nil {
		return out, fmt.Errorf("encrypt: %v", err)
	}
	author := nostr2.GeneratePrivateKey()
	if author == "" {
		return out, fmt.Errorf("sign: no key")
	}
	ev := nostr2.Event{
		Kind:      1059,
		CreatedAt: nostr2.Timestamp(now.Unix()),
		Content:   ct,
		Tags: nostr2.Tags{
			{"p", a.pk},
			{"expiration", fmt.Sprintf("%d", now.Add(pairEventLife).Unix())},
		},
	}
	if err := ev.Sign(author); err != nil {
		return out, fmt.Errorf("sign: %v", err)
	}
	if err := easyjson.Unmarshal([]byte(ev.String()), &out); err != nil {
		return out, fmt.Errorf("convert: %v", err)
	}
	return out, nil
}

// the message an event at one of addrs carries, and the address it came
// to; false for one that is not ours to read
func pairBoxOpen(ev nostr.Event, addrs []pairAddr) ([]byte, pairAddr, bool) {
	tg := ev.Tags.Find("p")
	if len(tg) < 2 {
		return nil, pairAddr{}, false
	}
	for _, a := range addrs {
		if tg[1] != a.pk {
			continue
		}
		pt, err := nip44.Decrypt(ev.Content, a.ck)
		if err != nil {
			return nil, a, false
		}
		m, err := base64.StdEncoding.DecodeString(pt)
		if err != nil || pake.Kind(m) == "" {
			return nil, a, false
		}
		return m, a, true
	}
	return nil, pairAddr{}, false
}

func pairBoxPublish(parent context.Context, lane string, a pairAddr, msg []byte) bool {
	ev, err := pairBoxEvent(a, msg, time.Now())
	if err != nil {
		log.Printf("paircode: no event (%v)", err)
		return false
	}
	ctx, cancel := context.WithTimeout(parent, publishWait)
	defer cancel()
	return nostrPublishMulti(ctx, lane, ev) > 0
}

// a pairing in progress, named by its handle. one of sharer and joiner
type pairRun struct {
	mu     sync.Mutex
	ctx    context.Context
	cancel context.CancelFunc
	sharer *pake.Sharer
	joiner *pake.Joiner
	box    string
	lane   string
	// the joiner's code, as its tries are kept (pairTried)
	tried [32]byte
	// the sharer takes no new answer after this; the joiner gives up then
	until time.Time
	seen  map[nostr.ID]bool
	// sharer: the windows its offer went up in
	offered map[uint64]bool
	// joiner: when each answered offer stops being answerable
	waits map[[32]byte]time.Time
	// joiner: when its last answer went
	answered time.Time
	// the other side's invite once both tags held, and the sharer's
	// finish while no relay has taken it yet
	invite []byte
	fin    []byte
	finAt  []pairAddr
	ended  string
	last   time.Time
}

var (
	pairRunsMu sync.Mutex
	pairRuns   = map[int64]*pairRun{}
	pairNextID int64
)

// how many pairings can be open at once: a screen has one
const pairRunsMax = 4

// how long a code lives on the sharer's screen, and the longest a joiner
// waits on one
const (
	pairCodeLife = pake.OfferLife
	pairJoinLife = pake.OfferLife + 2*pake.Skew
)

// the least time between two rounds of one run, whatever dart asks
var pairStepGap = 2 * time.Second

// the clock the runs count windows and lives on. tests move it
var pairClock = time.Now

func pairPut(r *pairRun) (int64, error) {
	// a run dart lost (an isolate given up on) goes once past any use
	pairRunsMu.Lock()
	var stale []int64
	for h, x := range pairRuns {
		if pairClock().After(x.until.Add(pairJoinLife)) {
			stale = append(stale, h)
		}
	}
	pairRunsMu.Unlock()
	for _, h := range stale {
		pairDrop(h)
	}
	pairRunsMu.Lock()
	defer pairRunsMu.Unlock()
	if len(pairRuns) >= pairRunsMax {
		return 0, errors.New("busy")
	}
	pairNextID++
	pairRuns[pairNextID] = r
	return pairNextID, nil
}

func pairGet(h int64) *pairRun {
	pairRunsMu.Lock()
	defer pairRunsMu.Unlock()
	return pairRuns[h]
}

// the run goes from the table and is wiped: a round under way ends first
func pairDrop(h int64) {
	pairRunsMu.Lock()
	r := pairRuns[h]
	delete(pairRuns, h)
	pairRunsMu.Unlock()
	if r == nil {
		return
	}
	r.cancel()
	r.mu.Lock()
	r.close()
	r.mu.Unlock()
}

// with r.mu held
func (r *pairRun) close() {
	if r.sharer != nil {
		r.sharer.Close()
	}
	if r.joiner != nil {
		pairTriedNote(r.tried, r.joiner.Tries())
		r.joiner.Close()
	}
	clear(r.invite)
	r.invite = nil
}

// the offers a code answered, by a mac of the code under a key of this
// process, kept for as long as the code can live: a code typed again goes
// on from its tries (review F3), so a fake sharer never gets more than
// pake.MaxTries guesses at it. lost when the app restarts
var (
	pairTriedMu  sync.Mutex
	pairTriedKey [32]byte
	pairTriedSet = map[[32]byte]pairTry{}
)

type pairTry struct {
	n     int
	until time.Time
}

func init() {
	if _, err := rand.Read(pairTriedKey[:]); err != nil {
		panic(err)
	}
}

func pairTriedOf(code []byte) [32]byte {
	m := hmac.New(sha256.New, pairTriedKey[:])
	m.Write(code)
	var out [32]byte
	m.Sum(out[:0])
	return out
}

func pairTriedGet(k [32]byte) int {
	pairTriedMu.Lock()
	defer pairTriedMu.Unlock()
	now := time.Now()
	for key, t := range pairTriedSet {
		if now.After(t.until) {
			delete(pairTriedSet, key)
		}
	}
	return pairTriedSet[k].n
}

func pairTriedNote(k [32]byte, n int) {
	pairTriedMu.Lock()
	defer pairTriedMu.Unlock()
	if t := pairTriedSet[k]; n > t.n || t.until.IsZero() {
		pairTriedSet[k] = pairTry{n: max(n, t.n), until: time.Now().Add(2 * pairJoinLife)}
	}
}

// the windows a joiner reads at now: every one an offer it would take can
// carry (pake.Joiner.Answer), oldest first
func pairJoinWindows(now time.Time) []uint64 {
	lo := pake.Window(now.Add(-pake.Skew)) - 1
	hi := pake.Window(now.Add(pake.Skew))
	var ws []uint64
	for w := lo; w <= hi; w++ {
		ws = append(ws, w)
	}
	return ws
}

func pairAddrs(box string, ws []uint64) ([]pairAddr, error) {
	out := make([]pairAddr, 0, len(ws))
	for _, w := range ws {
		a, err := pairAddrOf(box, w)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, nil
}

func pairPks(addrs []pairAddr) []string {
	pks := make([]string, len(addrs))
	for i, a := range addrs {
		pks[i] = a.pk
	}
	return pks
}

// a box another sharer has an offer up in now: the sharer picks another
func pairBoxBusy(ctx context.Context, lane string, a pairAddr) (busy, heard bool) {
	evs, _, n := pairCodeQuery(ctx, lane, []string{a.pk})
	for _, ev := range evs {
		if m, _, ok := pairBoxOpen(ev, []pairAddr{a}); ok && pake.Kind(m) == "KPO1" {
			return true, n > 0
		}
	}
	return false, n > 0
}

// a sharer for [invite] (the signed one-time KIN4): a box that is free
// now, an offer up there, and the code to show. "ok <handle> <8 digits>",
// pairUnreached when no relay took the offer, or "error: ..."
//
//export HaloPairShare
func HaloPairShare(cInvite *C.char) *C.char {
	h, shown, res := pairShare(goStr(cInvite))
	if shown == nil {
		return C.CString(res)
	}
	// the code goes out without a go string of it: dart zeroes its copy
	b := fmt.Appendf(nil, "ok %d ", h)
	b = append(b, shown...)
	b = append(b, 0)
	clear(shown)
	defer clear(b)
	return (*C.char)(C.CBytes(b))
}

// the handle and the code as shown, or the answer to give instead
func pairShare(inviteB64 string) (int64, []byte, string) {
	inv, err := base64.StdEncoding.DecodeString(inviteB64)
	if err != nil || len(inv) == 0 || len(inv) > pake.MaxInvite {
		return 0, nil, "error: invite"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*publishWait)
	defer cancel()
	now := pairClock()
	var code pake.Code
	var a pairAddr
	for i := 0; ; i++ {
		code, err = pake.NewCode(nil)
		if err != nil {
			return 0, nil, "error: code"
		}
		a, err = pairAddrOf(code.Box(), pake.Window(now))
		if err != nil {
			code.Wipe()
			return 0, nil, "error: " + err.Error()
		}
		// a busy box is left for another; a look no relay answered says
		// nothing, and the offer going up tells next
		busy, _ := pairBoxBusy(ctx, pairLane(a.pk), a)
		if !busy || i == 2 {
			break
		}
		code.Wipe()
	}
	defer code.Wipe()
	s, err := pake.NewSharer(&code, inv)
	clear(inv)
	if err != nil {
		return 0, nil, "error: invite"
	}
	rctx, rcancel := context.WithCancel(context.Background())
	r := &pairRun{
		ctx: rctx, cancel: rcancel, sharer: s, box: code.Box(), lane: pairLane(a.pk),
		until: now.Add(pairCodeLife), seen: map[nostr.ID]bool{}, offered: map[uint64]bool{},
	}
	r.mu.Lock()
	ok := r.offer(now)
	r.mu.Unlock()
	if !ok {
		rcancel()
		s.Close()
		return 0, nil, pairUnreached
	}
	h, err := pairPut(r)
	if err != nil {
		rcancel()
		s.Close()
		return 0, nil, "error: busy"
	}
	log.Printf("paircode: sharing, box %s", r.box)
	return h, code.Shown(), ""
}

// the offer for now's window up at its address, once per window. false
// when no relay took it. with r.mu held
func (r *pairRun) offer(now time.Time) bool {
	msg, w, err := r.sharer.Offer(now, nil)
	if err != nil {
		return false
	}
	if r.offered[w] {
		return true
	}
	a, err := pairAddrOf(r.box, w)
	if err != nil || !pairBoxPublish(r.ctx, r.lane, a, msg) {
		return false
	}
	r.offered[w] = true
	return true
}

// a joiner for the typed [code] with [invite] (the signed one-time KIN4)
// to seal. "ok <handle>", "error: old" for six digits (a Kryfo before 0.6,
// which nothing here can pair with), "error: code" for anything else that
// is not eight digits, "error: tries" for a code that used its tries. the
// code comes as bytes and is cleared here once read
//
//export HaloPairJoin
func HaloPairJoin(cCode, cInvite *C.char) *C.char {
	if cCode == nil {
		return C.CString("error: code")
	}
	b := C.GoBytes(unsafe.Pointer(cCode), C.int(C.strlen(cCode)))
	defer clear(b)
	return C.CString(pairJoin(b, goStr(cInvite)))
}

func pairJoin(typed []byte, inviteB64 string) string {
	if pake.OldCode(typed) {
		return "error: old"
	}
	code, err := pake.ParseCodeBytes(typed)
	if err != nil {
		return "error: code"
	}
	defer code.Wipe()
	inv, err := base64.StdEncoding.DecodeString(inviteB64)
	if err != nil || len(inv) == 0 || len(inv) > pake.MaxInvite {
		return "error: invite"
	}
	defer clear(inv)
	shown := code.Shown()
	tried := pairTriedOf(shown)
	clear(shown)
	// the same code typed again: the run before goes, and its tries stay
	pairRunsMu.Lock()
	var again []int64
	for h, r := range pairRuns {
		if r.joiner != nil && r.tried == tried {
			again = append(again, h)
		}
	}
	pairRunsMu.Unlock()
	for _, h := range again {
		pairDrop(h)
	}
	j, err := pake.NewJoinerAfter(&code, inv, pairTriedGet(tried))
	if errors.Is(err, pake.ErrTries) {
		return "error: tries"
	}
	if err != nil {
		return "error: invite"
	}
	now := pairClock()
	a, err := pairAddrOf(code.Box(), pake.Window(now))
	if err != nil {
		j.Close()
		return "error: " + err.Error()
	}
	rctx, rcancel := context.WithCancel(context.Background())
	r := &pairRun{
		ctx: rctx, cancel: rcancel, joiner: j, box: code.Box(), lane: pairLane(a.pk),
		tried: tried, until: now.Add(pairJoinLife), seen: map[nostr.ID]bool{},
		waits: map[[32]byte]time.Time{},
	}
	h, err := pairPut(r)
	if err != nil {
		rcancel()
		j.Close()
		return "error: busy"
	}
	return fmt.Sprintf("ok %d", h)
}

// one round of the pairing [h] over the relays. the sharer puts its offer
// up again when a window turns and reads the answers; the joiner reads the
// offers and finishes and answers each offer once. what it says:
//
//	"look"           the joiner has no offer yet
//	"wait <n>"       waiting; n is the wrong codes the sharer has seen
//	"unreached"      no relay answered this round; the next may
//	"done <base64>"  both tags held: the other side's invite
//	"error: tries"   the code is dead: three wrong tries, or three offers
//	                 the joiner answered went unfinished
//	"error: unanswered" the joiner's answers all ran out with no finish:
//	                 a wrong code, or the sharer went
//	"error: expired" the code's time is over
//	"error: gone"    no such pairing
//
//export HaloPairStep
func HaloPairStep(h C.longlong) *C.char {
	return C.CString(pairStep(int64(h)))
}

func pairStep(h int64) string {
	r := pairGet(h)
	if r == nil {
		return "error: gone"
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.ended != "" {
		return r.ended
	}
	if gap := pairStepGap - time.Since(r.last); gap > 0 && !r.last.IsZero() {
		select {
		case <-time.After(gap):
		case <-r.ctx.Done():
			return "error: gone"
		}
	}
	defer func() { r.last = time.Now() }()
	if r.sharer != nil {
		return r.end(r.shareStep(pairClock()))
	}
	return r.end(r.joinStep(pairClock()))
}

// a final answer is kept, and the run wiped but for what dart takes
func (r *pairRun) end(s string) string {
	if len(s) > 6 && s[:6] == "error:" {
		r.ended = s
		r.close()
	}
	return s
}

func (r *pairRun) done() string {
	return "done " + base64.StdEncoding.EncodeToString(r.invite)
}

func (r *pairRun) query(addrs []pairAddr) ([]nostr.Event, bool) {
	ctx, cancel := context.WithTimeout(r.ctx, 30*time.Second)
	defer cancel()
	evs, _, heard := pairCodeQuery(ctx, r.lane, pairPks(addrs))
	return evs, heard > 0
}

func (r *pairRun) shareStep(now time.Time) string {
	if r.fin != nil {
		return r.sendFinish()
	}
	if now.After(r.until.Add(pake.Skew)) {
		return "error: expired"
	}
	// a new window, a new offer; the one before stays answerable. one no
	// relay took goes up again next round, and the answers are read still
	offered := !now.Before(r.until) || r.offer(now)
	w := pake.Window(now)
	addrs, err := pairAddrs(r.box, []uint64{w - 1, w})
	if err != nil {
		return "error: " + err.Error()
	}
	evs, heard := r.query(addrs)
	for _, ev := range evs {
		if r.seen[ev.ID] {
			continue
		}
		r.seen[ev.ID] = true
		m, at, ok := pairBoxOpen(ev, addrs)
		if !ok || pake.Kind(m) != "KPA1" {
			continue
		}
		fin, inv, err := r.sharer.Answer(m, now)
		switch {
		case err == nil:
			r.invite = inv
			r.fin = fin
			// where the joiner read the offer, and where it looks now
			r.finAt = []pairAddr{at}
			if at.w != w {
				r.finAt = append(r.finAt, addrs[1])
			}
			log.Printf("paircode: an answer held, finishing")
			return r.sendFinish()
		case errors.Is(err, pake.ErrTries):
			log.Printf("paircode: three wrong codes, the code is dead")
			return "error: tries"
		case errors.Is(err, pake.ErrWrongCode):
			log.Printf("paircode: a wrong code (%d)", r.sharer.Fails())
		}
	}
	if !heard || !offered {
		return "unreached"
	}
	return fmt.Sprintf("wait %d", r.sharer.Fails())
}

// the finish out at every address it goes to; the invite is dart's once
// one relay took it, and the finish is tried again on the next round until
func (r *pairRun) sendFinish() string {
	sent := false
	for _, a := range r.finAt {
		if pairBoxPublish(r.ctx, r.lane, a, r.fin) {
			sent = true
		}
	}
	if !sent {
		if pairClock().After(r.until.Add(pake.Skew)) {
			return "error: expired"
		}
		return "unreached"
	}
	r.fin, r.finAt = nil, nil
	return r.done()
}

// how long the joiner waits on one answer before it answers another offer
// at the box (a second pairing there, or a fake one put up first)
var pairAnswerWait = 90 * time.Second

func (r *pairRun) joinStep(now time.Time) string {
	if now.After(r.until) {
		return "error: expired"
	}
	addrs, err := pairAddrs(r.box, pairJoinWindows(now))
	if err != nil {
		return "error: " + err.Error()
	}
	evs, heard := r.query(addrs)
	// finishes first: an answer this round cannot have one yet
	type cand struct {
		id  nostr.ID
		m   []byte
		at  pairAddr
		exp time.Time
	}
	var best *cand
	for _, ev := range evs {
		if r.seen[ev.ID] {
			continue
		}
		m, at, ok := pairBoxOpen(ev, addrs)
		switch {
		case ok && pake.Kind(m) == "KPF1":
			r.seen[ev.ID] = true
			if inv, err := r.joiner.Finish(m); err == nil {
				r.invite = inv
				pairTriedNote(r.tried, r.joiner.Tries())
				log.Printf("paircode: the finish held")
				return r.done()
			}
		case ok && pake.Kind(m) == "KPO1":
			exp, err := pake.OfferExpires(m)
			if err != nil || !now.Before(exp) {
				r.seen[ev.ID] = true
				continue
			}
			if best == nil || exp.After(best.exp) {
				best = &cand{ev.ID, m, at, exp}
			}
		default:
			r.seen[ev.ID] = true
		}
	}
	// one answer at a time, the newest offer first: each answer is a try,
	// so a mistyped code costs one, and the sharer's screen says so before
	// another goes
	live := 0
	for _, exp := range r.waits {
		if now.Before(exp) {
			live++
		}
	}
	waiting := live > 0 && now.Sub(r.answered) < pairAnswerWait
	if best != nil && !waiting {
		ans, err := r.joiner.Answer(best.m, now, nil)
		pairTriedNote(r.tried, r.joiner.Tries())
		if err != nil {
			// out of its time or past the cap: never answered
			r.seen[best.id] = true
		} else if pairBoxPublish(r.ctx, r.lane, best.at, ans) {
			// an answer no relay took goes again next round: the same offer
			// gets the same answer and costs no try
			r.seen[best.id] = true
			r.waits[sha256.Sum256(best.m)] = best.exp
			r.answered = now
			live++
		}
	}
	// every offer answered is past its time with no finish: the code was
	// wrong, or their phone went
	if len(r.waits) > 0 && live == 0 {
		if r.joiner.Tries() >= pake.MaxTries {
			return "error: tries"
		}
		return "error: unanswered"
	}
	if !heard {
		return "unreached"
	}
	if len(r.waits) == 0 {
		return "look"
	}
	return "wait 0"
}

// the pairing [h] is over and what it gave was taken: wiped and gone
//
//export HaloPairFinish
func HaloPairFinish(h C.longlong) *C.char {
	pairDrop(int64(h))
	return C.CString("ok")
}

// the pairing [h] given up: wiped and gone, as finish
//
//export HaloPairCancel
func HaloPairCancel(h C.longlong) *C.char {
	pairDrop(int64(h))
	return C.CString("ok")
}

// how long the joiner keeps listening once the first event turns up at an
// address, for the relays that have not answered yet
var pairCollectWindow = 3 * time.Second

// how many events one relay is asked for at a box. a relay sends the
// newest first and stops here
const pairQueryLimit = 100

// what one relay sent, and which one by its place in the list: an event, or
// nil once it has sent everything it holds (or could not be asked). heard
// says the relay itself got as far as the end of what it holds
type pairAnswer struct {
	from  int
	ev    *nostr.Event
	heard bool
}

// ask every relay at once and keep everything they hold at the addresses
// pks. a one-shot lookup, not a subscription: the caller polls while the
// screen is open. it ends once every relay has answered, a few seconds
// after the first event, or at the deadline, whichever comes first. full is
// true, and it ends at once, when one relay's answer reaches
// pairQueryLimit. heard counts the relays that answered at all: none means
// nothing is known. the deadline waits on while none has, since an onion
// relay can take longer than it to open, and then only until the first
// answer.
func pairCodeQuery(ctx context.Context, lane string, pks []string) (got []nostr.Event, full bool, heard int) {
	for {
		routeC := routeEnded()
		urls := relaysInUse(ctx)
		if len(urls) == 0 {
			return nil, false, 0
		}
		var ended bool
		got, full, heard, ended = pairCodeQueryOn(ctx, lane, pks, urls, routeC)
		if !ended || ctx.Err() != nil {
			return got, full, heard
		}
		// the mode changed: what the old route heard goes, and the new
		// list is asked from the start, the new way
		log.Printf("paircode: the route changed, asking again")
	}
}

// one round over urls, the list of the route routeC belongs to. ended says
// that route ended first, and the answer is no answer
func pairCodeQueryOn(ctx context.Context, lane string, pks []string, urls []string, routeC <-chan struct{}) (got []nostr.Event, full bool, heard int, ended bool) {
	// the sockets go when the route does
	qctx, cancel := onRoute(ctx, routeC)
	defer cancel()
	out := make(chan pairAnswer)
	since := nostr.Timestamp(time.Now().Add(-2*pake.OfferLife - pake.Skew - time.Minute).Unix())

	for i, u := range urls {
		go func(i int, u string) {
			// every relay reports done exactly once, after its events
			done := func(heard bool) {
				select {
				case out <- pairAnswer{from: i, heard: heard}:
				case <-qctx.Done():
				}
			}
			client, err := relayClientFor(lane, u)
			// the list is the old mode's and the client may be the new one's
			if err != nil || routeGone(routeC) {
				done(false)
				return
			}
			r := nostr.NewRelay(qctx, u, nostr.RelayOptions{})
			dctx, dcancel := relayDialCtx(qctx, u)
			err = r.ConnectWithClient(dctx, client)
			dcancel()
			if err != nil {
				done(false)
				return
			}
			defer r.Close()
			sub, err := r.Subscribe(qctx, nostr.Filter{
				Kinds: []nostr.Kind{1059},
				Tags:  nostr.TagMap{"p": pks},
				Since: since,
				Limit: pairQueryLimit,
			}, nostr.SubscriptionOptions{
				// the end of stored events comes from the relay or not at
				// all: a made-up one would cut its answer short
				MaxWaitForEOSE: time.Duration(math.MaxInt64),
			})
			if err != nil {
				done(false)
				return
			}
			eosed := false
			for {
				select {
				case ev, alive := <-sub.Events:
					if !alive {
						if !eosed {
							done(false)
						}
						return
					}
					select {
					case out <- pairAnswer{from: i, ev: &ev}:
					case <-qctx.Done():
						return
					}
				case <-sub.EndOfStoredEvents:
					// stored events all come before this. the socket stays
					// open, so an event that lands while others answer
					// still counts
					if !eosed {
						eosed = true
						done(true)
					}
				case <-qctx.Done():
					return
				}
			}
		}(i, u)
	}

	sent := make([]int, len(urls))
	answered := make([]bool, len(urls))
	count := func() int {
		n := 0
		for _, a := range answered {
			if a {
				n++
			}
		}
		return n
	}
	pending := len(urls)
	deadline := time.NewTimer(pairQueryDeadline)
	defer deadline.Stop()
	// the deadline passed with no answer: the first one ends the wait
	late := false
	var window <-chan time.Time
	for {
		select {
		case a := <-out:
			if a.ev == nil {
				if a.heard {
					answered[a.from] = true
				}
				pending--
				if pending == 0 || (late && a.heard) {
					return got, false, count(), false
				}
				continue
			}
			answered[a.from] = true
			got = append(got, *a.ev)
			if sent[a.from]++; sent[a.from] >= pairQueryLimit {
				return got, true, count(), false
			}
			if window == nil {
				window = time.After(pairCollectWindow)
			}
		case <-window:
			return got, false, count(), false
		case <-deadline.C:
			if n := count(); n > 0 {
				return got, false, n, false
			}
			late = true
		case <-routeC:
			return nil, false, 0, true
		case <-ctx.Done():
			return got, false, count(), false
		}
	}
}

// how long a lookup waits on the relays that have not answered once one has
var pairQueryDeadline = 12 * time.Second
