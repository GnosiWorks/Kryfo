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

	// kryfo: events read and not handed over yet, in the order they were
	// read, and whether a goroutine is handing them over. both under mu
	queue    []queuedEvent
	draining bool
	// kryfo: the subscription ended. under mu, and Events is closed only
	// while nothing drains, so nothing sends on it once it is closed
	ending bool
}

// kryfo: stored is whether it came before the EOSE
type queuedEvent struct {
	evt    Event
	stored bool
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

// kryfo: events are queued in the order they were read and handed over by
// one goroutine at a time. upstream starts a goroutine per event, and a later
// one can overtake an earlier one, so what a page cut short kept need not be
// the newest of what the relay sent.
func (sub *Subscription) dispatchEvent(evt Event) {
	sub.mu.Lock()
	defer sub.mu.Unlock()
	if sub.ending || sub.Context.Err() != nil {
		return
	}
	isStored := !sub.eosed.Load()
	if isStored {
		sub.storedwg.Add(1)
	}
	sub.queue = append(sub.queue, queuedEvent{evt: evt, stored: isStored})
	if !sub.draining {
		sub.draining = true
		go sub.drain()
	}
}

// kryfo: hands the queue over until it is empty. once the subscription has
// ended the rest is dropped, so what did come is the start of what was read,
// and Events is closed here if the closer found this still draining.
func (sub *Subscription) drain() {
	for {
		sub.mu.Lock()
		if sub.ending || sub.Context.Err() != nil || len(sub.queue) == 0 {
			for _, q := range sub.queue {
				if q.stored {
					sub.storedwg.Done()
				}
			}
			sub.queue = nil
			sub.draining = false
			if sub.ending {
				close(sub.Events)
			}
			sub.mu.Unlock()
			return
		}
		q := sub.queue[0]
		sub.queue[0] = queuedEvent{}
		sub.queue = sub.queue[1:]
		sub.mu.Unlock()

		if q.stored {
			if sub.live.Load() {
				select {
				case sub.Events <- q.evt:
				case <-sub.Context.Done():
				case <-sub.eoseTimedOut:
				}
			}
			sub.storedwg.Done()
		} else {
			if sub.live.Load() {
				select {
				case sub.Events <- q.evt:
				case <-sub.Context.Done():
				}
			}
		}
	}
}

func (sub *Subscription) dispatchEose() {
	// kryfo: under mu, so a stored event is counted before the wait below
	// begins, or it is not a stored event
	sub.mu.Lock()
	defer sub.mu.Unlock()
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
	// kryfo: the first reason is kept and any later one for the same
	// subscription is dropped, so nothing waits on a reader that never comes
	select {
	case sub.ClosedReason <- reason:
	default:
	}
	sub.live.Store(false) // set this so we don't send an unnecessary CLOSE to the relay
	sub.cancel(fmt.Errorf("CLOSED received: %s", reason))
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
