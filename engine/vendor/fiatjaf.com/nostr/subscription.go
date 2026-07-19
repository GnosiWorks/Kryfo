package nostr

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"sync/atomic"
	"time"
)

var (
	ErrNotConnected = errors.New("not connected")
	ErrFireFailed   = errors.New("failed to fire")
)

// Subscription represents a subscription to a relay.
type Subscription struct {
	counter int64
	id      string

	Relay  *Relay
	Filter Filter

	// for this to be treated as a COUNT and not a REQ this must be set
	countResult chan CountEnvelope

	// the Events channel emits all EVENTs that come in a Subscription
	// will be closed when the subscription ends
	Events chan Event
	mu     sync.Mutex

	// the EndOfStoredEvents channel gets closed when an EOSE comes for that subscription
	EndOfStoredEvents chan struct{}

	// the ClosedReason channel emits the reason when a CLOSED message is received
	ClosedReason chan string

	// Context will be .Done() when the subscription ends
	Context context.Context

	// if it is not nil, checkDuplicate will be called for every event received
	// if it returns true that event will not be processed further.
	checkDuplicate func(id ID, relay string) bool

	// if it is not nil, checkDuplicateReplaceable will be called for every event received
	// if it returns true that event will not be processed further.
	checkDuplicateReplaceable func(rk ReplaceableKey, ts Timestamp) bool

	match        func(Event) bool // this will be either Filters.Match or Filters.MatchIgnoringTimestampConstraints
	live         atomic.Bool
	eosed        atomic.Bool
	eoseTimedOut chan struct{}
	cancel       context.CancelCauseFunc

	// this keeps track of the events we've received before the EOSE that we must dispatch before
	// closing the EndOfStoredEvents channel
	storedwg sync.WaitGroup
}

// All SubscriptionOptions fields are optional
type SubscriptionOptions struct {
	// Label puts a label on the subscription (it is prepended to the automatic id) that is sent to relays.
	Label string

	// CheckDuplicate is a function that, when present, is ran on events before they're parsed.
	// if it returns true the event will be discarded and not processed further.
	CheckDuplicate func(id ID, relay string) bool

	// CheckDuplicateReplaceable is like CheckDuplicate, but runs on replaceable/addressable events
	CheckDuplicateReplaceable func(rk ReplaceableKey, ts Timestamp) bool

	// a fake EndOfStoredEvents will be dispatched at this time if nothing is received before.
	// defaults to 7s (in order to disable, set it to time.Duration(math.MaxInt64))
	MaxWaitForEOSE time.Duration
}

// GetID returns the subscription ID.
func (sub *Subscription) GetID() string { return sub.id }

func (sub *Subscription) dispatchEvent(evt Event) {
	isStored := false
	if !sub.eosed.Load() {
		sub.storedwg.Add(1)
		isStored = true
	}

	go func() {
		if isStored {
			if sub.live.Load() {
				select {
				case sub.Events <- evt:
				case <-sub.Context.Done():
				case <-sub.eoseTimedOut:
				}
			}
			sub.storedwg.Done()
		} else {
			if sub.live.Load() {
				select {
				case sub.Events <- evt:
				case <-sub.Context.Done():
				}
			}
		}
	}()
}

func (sub *Subscription) dispatchEose() {
	if sub.eosed.CompareAndSwap(false, true) {
		sub.match = sub.Filter.MatchesIgnoringTimestampConstraints
		go func() {
			sub.storedwg.Wait()
			sub.EndOfStoredEvents <- struct{}{}
		}()
	}
}

// handleClosed handles the CLOSED message from a relay.
func (sub *Subscription) handleClosed(reason string) {
	go func() {
		sub.ClosedReason <- reason
		sub.live.Store(false) // set this so we don't send an unnecessary CLOSE to the relay
		sub.cancel(fmt.Errorf("CLOSED received: %s", reason))
	}()
}

// Unsub closes the subscription, sending "CLOSE" to relay as in NIP-01.
// Unsub() also closes the channel sub.Events and makes a new one.
func (sub *Subscription) Unsub() {
	sub.cancel(errors.New("Unsub() called"))
}

// Sub sets sub.Filters and then calls sub.Fire(ctx).
// The subscription will be closed if the context expires.
func (sub *Subscription) Sub(_ context.Context, filter Filter) {
	sub.Filter = filter
	sub.Fire()
}

// Fire sends the "REQ" command to the relay.
func (sub *Subscription) Fire() error {
	var reqb []byte
	if sub.countResult == nil {
		reqb, _ = ReqEnvelope{sub.id, []Filter{sub.Filter}}.MarshalJSON()
	} else {
		reqb, _ = CountEnvelope{sub.id, sub.Filter, nil, nil}.MarshalJSON()
	}

	sub.live.Store(true)
	if err := sub.Relay.WriteWithError(reqb); err != nil {
		err := fmt.Errorf("failed to write: %w", err)
		sub.cancel(err)
		return err
	}

	return nil
}
