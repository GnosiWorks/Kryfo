package nostr

import (
	"context"
	"errors"
	"fmt"
	"math"
	"slices"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"fiatjaf.com/nostr/nip45/hyperloglog"
	"github.com/puzpuzpuz/xsync/v3"
)

const (
	seenAlreadyDropTick = time.Minute
)

// Pool manages connections to multiple relays, ensures they are reopened when necessary and not duplicated.
type Pool struct {
	Relays  *xsync.MapOf[string, *Relay]
	Context context.Context

	cancel context.CancelCauseFunc

	// AuthRequiredHandler, if given, must be a function that signs the auth event when called.
	// it will be called whenever any relay in the pool returns a `CLOSED` or `OK` message
	// with the "auth-required:" prefix, only once for each relay
	AuthRequiredHandler func(context.Context, *Event) error

	// EventMiddleware is a function that will be called with all events received.
	EventMiddleware func(RelayEvent)

	// DuplicateMiddleware is a function that will be called with all duplicate ids received.
	DuplicateMiddleware func(relay string, id ID)

	// AuthorKindQueryMiddleware is a function that will be called with every combination of
	// relay+pubkey+kind queried in a .SubscribeMany*() call -- when applicable (i.e. when the query
	// contains a pubkey and a kind).
	QueryMiddleware func(relay string, pubkey PubKey, kind Kind)

	// RelayOptions are any options that should be passed to Relays instantiated by this pool
	RelayOptions RelayOptions

	// custom things not often used
	penaltyBox *xsync.MapOf[string, [2]float64]
}

// DirectedFilter combines a Filter with a specific relay URL.
type DirectedFilter struct {
	Filter
	Relay string
}

func (df DirectedFilter) String() string {
	return fmt.Sprintf("%s(%s)", df.Relay, df.Filter)
}

func (ie RelayEvent) String() string { return fmt.Sprintf("[%s] >> %s", ie.Relay.URL, ie.Event) }

// NewPool creates a new Pool with the given context and options.
func NewPool() *Pool {
	ctx, cancel := context.WithCancelCause(context.Background())

	return &Pool{
		Relays: xsync.NewMapOf[string, *Relay](),

		Context: ctx,
		cancel:  cancel,
	}
}

func (pool *Pool) StartPenaltyBox() {
	pool.penaltyBox = xsync.NewMapOf[string, [2]float64]()

	go func() {
		sleep := 30.0
		for {
			select {
			case <-pool.Context.Done():
				return
			case <-time.After(time.Duration(sleep) * time.Second):

				nextSleep := 300.0
				for url, v := range pool.penaltyBox.Range {
					remainingSeconds := v[1]
					remainingSeconds -= sleep
					if remainingSeconds <= 0 {
						pool.penaltyBox.Store(url, [2]float64{v[0], 0})
						continue
					} else {
						pool.penaltyBox.Store(url, [2]float64{v[0], remainingSeconds})
					}

					if remainingSeconds < nextSleep {
						nextSleep = remainingSeconds
					}
				}

				sleep = nextSleep
			}
		}
	}()
}

// AddToPenaltyBox manually adds a relay to the penalty box for the specified duration.
// This prevents EnsureRelay from attempting to connect to the relay until the duration expires.
func (pool *Pool) AddToPenaltyBox(url string, duration time.Duration) {
	if pool.penaltyBox == nil {
		return
	}
	nm := NormalizeURL(url)
	pool.penaltyBox.Store(nm, [2]float64{0, duration.Seconds()})
	pool.Relays.Store(nm, nil) // mark as explicitly disconnected for penalty box detection
}

// EnsureRelay ensures that a relay connection exists and is active.
// If the relay is not connected, it attempts to connect.
func (pool *Pool) EnsureRelay(url string) (*Relay, error) {
	nm := NormalizeURL(url)
	defer namedLock(nm)()

	relay, ok := pool.Relays.Load(nm)
	if ok && relay == nil {
		if pool.penaltyBox != nil {
			v, _ := pool.penaltyBox.Load(nm)
			if v[1] > 0 {
				return nil, fmt.Errorf("in penalty box, %fs remaining", v[1])
			}
		}
	} else if ok && relay.IsConnected() {
		// already connected, unlock and return
		return relay, nil
	}

	relay = NewRelay(pool.Context, url, pool.RelayOptions)
	// try to connect
	// we use this ctx here so when the pool dies everything dies
	if err := relay.Connect(pool.Context); err != nil {
		if pool.penaltyBox != nil {
			// putting relay in penalty box
			pool.penaltyBox.Compute(nm, func(v [2]float64, loaded bool) (newV [2]float64, delete bool) {
				return [2]float64{v[0] + 1, 30.0 + math.Pow(2, v[0]+1)}, false
			})
			pool.Relays.Store(nm, nil) // this is important for penalty box detection on EnsureRelay
		}
		return nil, fmt.Errorf("failed to connect: %w", err)
	}

	pool.Relays.Store(nm, relay)
	go func(r *Relay, relayURL string) {
		<-r.Context().Done()
		if current, ok := pool.Relays.Load(relayURL); ok && current == r {
			pool.Relays.Delete(relayURL)
		}
	}(relay, nm)
	return relay, nil
}

// PublishResult represents the result of publishing an event to a relay.
type PublishResult struct {
	Error    error
	RelayURL string
	Relay    *Relay
}

// PublishMany publishes an event to multiple relays and returns a channel of results emitted as they're received.
func (pool *Pool) PublishMany(ctx context.Context, urls []string, evt Event) chan PublishResult {
	ch := make(chan PublishResult, len(urls))

	wg := sync.WaitGroup{}
	wg.Add(len(urls))
	go func() {
		for i, url := range urls {
			if slices.IndexFunc(urls[0:i], func(iurl string) bool {
				return NormalizeURL(url) == NormalizeURL(iurl)
			}) != -1 {
				// duplicated URL
				wg.Done()
				continue
			}

			go func() {
				defer wg.Done()

				relay, err := pool.EnsureRelay(url)
				if err != nil {
					ch <- PublishResult{err, url, nil}
					return
				}

				if err := relay.Publish(ctx, evt); err == nil {
					// success with no auth required
					ch <- PublishResult{nil, url, relay}
				} else if strings.HasPrefix(err.Error(), "msg: auth-required:") && pool.AuthRequiredHandler != nil {
					// try to authenticate if we can
					if authErr := relay.Auth(ctx, pool.AuthRequiredHandler); authErr == nil {
						if err := relay.Publish(ctx, evt); err == nil {
							// success after auth
							ch <- PublishResult{nil, url, relay}
						} else {
							// failure after auth
							ch <- PublishResult{err, url, relay}
						}
					} else {
						// failure to auth
						ch <- PublishResult{fmt.Errorf("failed to auth: %w", authErr), url, relay}
					}
				} else {
					// direct failure
					ch <- PublishResult{err, url, relay}
				}
			}()
		}

		wg.Wait()
		close(ch)
	}()

	return ch
}

// SubscribeMany opens a subscription with the given filter to multiple relays
// the subscriptions ends when the context is canceled or when all relays return a CLOSED.
func (pool *Pool) SubscribeMany(
	ctx context.Context,
	urls []string,
	filter Filter,
	opts SubscriptionOptions,
) chan RelayEvent {
	return pool.subMany(ctx, urls, filter, nil, nil, opts)
}

func (pool *Pool) FetchManyNotifyClosed(
	ctx context.Context,
	urls []string,
	filter Filter,
	opts SubscriptionOptions,
) (chan RelayEvent, chan RelayClosed) {
	closedChan := make(chan RelayClosed)
	events := pool.fetchMany(ctx, urls, filter, closedChan, opts)
	return events, closedChan
}

// FetchMany opens a subscription, much like SubscribeMany, but it ends as soon as all Relays
// return an EOSE message.
func (pool *Pool) FetchMany(
	ctx context.Context,
	urls []string,
	filter Filter,
	opts SubscriptionOptions,
) chan RelayEvent {
	return pool.fetchMany(ctx, urls, filter, nil, opts)
}

func (pool *Pool) fetchMany(
	ctx context.Context,
	urls []string,
	filter Filter,
	closedChan chan RelayClosed,
	opts SubscriptionOptions,
) chan RelayEvent {
	seenAlready := xsync.NewMapOf[ID, struct{}]()

	if opts.CheckDuplicate == nil {
		opts.CheckDuplicate = func(id ID, relay string) bool {
			_, exists := seenAlready.LoadOrStore(id, struct{}{})
			if exists && pool.DuplicateMiddleware != nil {
				pool.DuplicateMiddleware(relay, id)
			}
			return exists
		}
	}

	return pool.subManyEose(ctx, urls, filter, closedChan, opts)
}

// SubscribeManyNotifyEOSE is like SubscribeMany, but also returns a channel that is closed when all subscriptions have received an EOSE
func (pool *Pool) SubscribeManyNotifyEOSE(
	ctx context.Context,
	urls []string,
	filter Filter,
	opts SubscriptionOptions,
) (chan RelayEvent, chan struct{}) {
	eoseChan := make(chan struct{})
	events := pool.subMany(ctx, urls, filter, eoseChan, nil, opts)
	return events, eoseChan
}

type RelayClosed struct {
	Reason string
	Relay  *Relay

	// this is true when the close reason was "auth-required" and already handled internally
	HandledAuth bool
}

// SubscribeManyNotifyClosed is like SubscribeMany, but also returns a channel that emits every time a subscription receives a CLOSED message
func (pool *Pool) SubscribeManyNotifyClosed(
	ctx context.Context,
	urls []string,
	filter Filter,
	opts SubscriptionOptions,
) (chan RelayEvent, chan RelayClosed) {
	closedChan := make(chan RelayClosed)
	events := pool.subMany(ctx, urls, filter, nil, closedChan, opts)
	return events, closedChan
}

type ReplaceableKey struct {
	PubKey PubKey
	D      string
}

// FetchManyReplaceable is like FetchMany, but deduplicates replaceable and addressable events and returns
// only the latest for each "d" tag.
func (pool *Pool) FetchManyReplaceable(
	ctx context.Context,
	urls []string,
	filter Filter,
	opts SubscriptionOptions,
) *xsync.MapOf[ReplaceableKey, Event] {
	ctx, cancel := context.WithCancelCause(ctx)

	results := xsync.NewMapOf[ReplaceableKey, Event]()

	wg := sync.WaitGroup{}
	wg.Add(len(urls))

	seenAlreadyLatest := xsync.NewMapOf[ReplaceableKey, Timestamp]()
	opts.CheckDuplicateReplaceable = func(rk ReplaceableKey, ts Timestamp) bool {
		discard := true
		seenAlreadyLatest.Compute(rk, func(latest Timestamp, _ bool) (newValue Timestamp, delete bool) {
			if ts > latest {
				discard = false // we are going to use this, so don't discard it
				return ts, false
			}
			return latest, false // the one we had was already more recent, so discard this
		})
		return discard
	}
	if opts.MaxWaitForEOSE == 0 {
		opts.MaxWaitForEOSE = time.Second * 4
	}

	for _, url := range urls {
		go func(nm string) {
			defer wg.Done()

			if mh := pool.QueryMiddleware; mh != nil {
				if filter.Kinds != nil && filter.Authors != nil {
					for _, kind := range filter.Kinds {
						for _, author := range filter.Authors {
							mh(nm, author, kind)
						}
					}
				}
			}

			relay, err := pool.EnsureRelay(nm)
			if err != nil {
				debugLogf("[pool] error connecting to %s with %v: %s", nm, filter, err)
				return
			}

			hasAuthed := false

		subscribe:
			sub, err := relay.Subscribe(ctx, filter, opts)
			if err != nil {
				debugLogf("[pool] error subscribing to %s with %v: %s", relay, filter, err)
				return
			}

			for {
				select {
				case <-ctx.Done():
					return
				case <-sub.EndOfStoredEvents:
					return
				case reason := <-sub.ClosedReason:
					if strings.HasPrefix(reason, "auth-required:") && pool.AuthRequiredHandler != nil && !hasAuthed {
						// relay is requesting auth. if we can we will perform auth and try again
						err := relay.Auth(ctx, pool.AuthRequiredHandler)
						if err == nil {
							hasAuthed = true // so we don't keep doing AUTH again and again
							goto subscribe
						}
					}
					debugLogf("[pool] CLOSED from %s: '%s'\n", nm, reason)
					return
				case evt, more := <-sub.Events:
					if !more {
						return
					}

					ie := RelayEvent{Event: evt, Relay: relay}
					if mh := pool.EventMiddleware; mh != nil {
						mh(ie)
					}

					results.Store(ReplaceableKey{evt.PubKey, evt.Tags.GetD()}, evt)
				}
			}
		}(NormalizeURL(url))
	}

	// this will happen when all subscriptions get an eose (or when they die)
	wg.Wait()
	cancel(errors.New("all subscriptions ended"))

	return results
}

func (pool *Pool) subMany(
	ctx context.Context,
	urls []string,
	filter Filter,
	eoseChan chan struct{},
	closedChan chan RelayClosed,
	opts SubscriptionOptions,
) chan RelayEvent {
	ctx, cancel := context.WithCancelCause(ctx)
	_ = cancel // do this so `go vet` will stop complaining
	events := make(chan RelayEvent)
	seenAlready := xsync.NewMapOf[ID, Timestamp]()
	ticker := time.NewTicker(seenAlreadyDropTick)

	eoseWg := sync.WaitGroup{}
	eoseWg.Add(len(urls))
	if eoseChan != nil {
		go func() {
			eoseWg.Wait()
			close(eoseChan)
		}()
	}

	if opts.CheckDuplicate == nil {
		opts.CheckDuplicate = func(id ID, relay string) bool {
			_, exists := seenAlready.LoadOrStore(id, Now())
			if exists && pool.DuplicateMiddleware != nil {
				pool.DuplicateMiddleware(relay, id)
			}
			return exists
		}
	}

	pendingWg := sync.WaitGroup{}
	pendingWg.Add(len(urls))

	go func() {
		pendingWg.Wait()
		close(events)
		cancel(fmt.Errorf("aborted: %w", context.Cause(ctx)))
		if closedChan != nil {
			close(closedChan)
		}
	}()

	for i, url := range urls {
		url = NormalizeURL(url)
		urls[i] = url
		if idx := slices.Index(urls, url); idx != i {
			// skip duplicate relays in the list
			eoseWg.Done()
			pendingWg.Done()
			continue
		}

		eosed := atomic.Bool{}

		go func(nm string, filter Filter) {
			defer func() {
				if eosed.CompareAndSwap(false, true) {
					eoseWg.Done()
				}
				pendingWg.Done()
			}()

			hasAuthed := false
			interval := 3 * time.Second
			for {
				if ctx.Err() != nil {
					return
				}

				var sub *Subscription

				if mh := pool.QueryMiddleware; mh != nil {
					if filter.Kinds != nil && filter.Authors != nil {
						for _, kind := range filter.Kinds {
							for _, author := range filter.Authors {
								mh(nm, author, kind)
							}
						}
					}
				}

				relay, err := pool.EnsureRelay(nm)
				if err != nil {
					// otherwise (if we were connected and got disconnected) keep trying to reconnect
					debugLogf("[pool] connection to %s failed, will retry\n", nm)
					goto reconnect
				}
				hasAuthed = false

			subscribe:
				sub, err = relay.Subscribe(ctx, filter, opts)
				if err != nil {
					debugLogf("[pool] subscription to %s failed: %s -- will retry\n", nm, err)
					goto reconnect
				}

				go func() {
					<-sub.EndOfStoredEvents

					// guard here otherwise a resubscription will trigger a duplicate call to eoseWg.Done()
					if eosed.CompareAndSwap(false, true) {
						eoseWg.Done()
					}
				}()

				// reset interval when we get a good subscription
				interval = 3 * time.Second

				for {
					select {
					case evt, more := <-sub.Events:
						if !more {
							// this means the connection was closed for weird reasons, like the server shut down
							// so we will update the filters here to include only events seem from now on
							// and try to reconnect until we succeed
							filter.Since = Now()
							debugLogf("[pool] retrying %s because sub.Events is broken\n", nm)
							goto reconnect
						}

						ie := RelayEvent{Event: evt, Relay: relay}
						if mh := pool.EventMiddleware; mh != nil {
							mh(ie)
						}

						select {
						case events <- ie:
						case <-ctx.Done():
							return
						}
					case <-ticker.C:
						if eosed.Load() {
							old := Timestamp(time.Now().Add(-seenAlreadyDropTick).Unix())
							for id, value := range seenAlready.Range {
								if value < old {
									seenAlready.Delete(id)
								}
							}
						}
					case reason := <-sub.ClosedReason:
						if strings.HasPrefix(reason, "auth-required:") && pool.AuthRequiredHandler != nil && !hasAuthed {
							// relay is requesting auth. if we can we will perform auth and try again
							err := relay.Auth(ctx, pool.AuthRequiredHandler)
							if err == nil {
								hasAuthed = true // so we don't keep doing AUTH again and again
								if closedChan != nil {
									select {
									case closedChan <- RelayClosed{
										Reason:      reason,
										Relay:       relay,
										HandledAuth: true,
									}:
									case <-ctx.Done():
									}
								}
								goto subscribe
							}
						}
						debugLogf("CLOSED from %s: '%s'\n", nm, reason)
						if closedChan != nil {
							select {
							case closedChan <- RelayClosed{
								Reason: reason,
								Relay:  relay,
							}:
							case <-ctx.Done():
							}
						}

						return
					case <-ctx.Done():
						return
					}
				}

			reconnect:
				// we will go back to the beginning of the loop and try to connect again and again
				// until the context is canceled
				debugLogf("[pool] retrying %s in %s\n", nm, interval)
				time.Sleep(interval)
				interval = min(10*time.Minute, interval*17/10) // the next time we try we will wait longer
			}
		}(url, filter)
	}

	return events
}

func (pool *Pool) subManyEose(
	ctx context.Context,
	urls []string,
	filter Filter,
	closedChan chan RelayClosed,
	opts SubscriptionOptions,
) chan RelayEvent {
	ctx, cancel := context.WithCancelCause(ctx)

	events := make(chan RelayEvent)
	wg := sync.WaitGroup{}
	wg.Add(len(urls))

	go func() {
		// this will happen when all subscriptions get an eose (or when they die)
		wg.Wait()
		cancel(errors.New("all subscriptions ended"))
		close(events)
		if closedChan != nil {
			close(closedChan)
		}
	}()

	for _, url := range urls {
		go func(nm string) {
			defer wg.Done()

			if mh := pool.QueryMiddleware; mh != nil {
				if filter.Kinds != nil && filter.Authors != nil {
					for _, kind := range filter.Kinds {
						for _, author := range filter.Authors {
							mh(nm, author, kind)
						}
					}
				}
			}

			relay, err := pool.EnsureRelay(nm)
			if err != nil {
				debugLogf("[pool] error connecting to %s with %v: %s", nm, filter, err)
				return
			}

			hasAuthed := false

		subscribe:
			sub, err := relay.Subscribe(ctx, filter, opts)
			if err != nil {
				debugLogf("[pool] error subscribing to %s with %v: %s", relay, filter, err)
				return
			}

			for {
				select {
				case <-ctx.Done():
					return
				case <-sub.EndOfStoredEvents:
					return
				case reason := <-sub.ClosedReason:
					if strings.HasPrefix(reason, "auth-required:") && pool.AuthRequiredHandler != nil && !hasAuthed {
						// relay is requesting auth. if we can we will perform auth and try again
						err := relay.Auth(ctx, pool.AuthRequiredHandler)
						if err == nil {
							hasAuthed = true // so we don't keep doing AUTH again and again
							if closedChan != nil {
								select {
								case closedChan <- RelayClosed{
									Relay:       relay,
									Reason:      reason,
									HandledAuth: true,
								}:
								case <-ctx.Done():
								}
							}
							goto subscribe
						}
					}
					debugLogf("[pool] CLOSED from %s: '%s'\n", nm, reason)
					if closedChan != nil {
						select {
						case closedChan <- RelayClosed{
							Relay:  relay,
							Reason: reason,
						}:
						case <-ctx.Done():
						}
					}
					return
				case evt, more := <-sub.Events:
					if !more {
						return
					}

					ie := RelayEvent{Event: evt, Relay: relay}
					if mh := pool.EventMiddleware; mh != nil {
						mh(ie)
					}

					select {
					case events <- ie:
					case <-ctx.Done():
						return
					}
				}
			}
		}(NormalizeURL(url))
	}

	return events
}

// CountMany aggregates count results from multiple relays using NIP-45 HyperLogLog
func (pool *Pool) CountMany(
	ctx context.Context,
	urls []string,
	filter Filter,
	opts SubscriptionOptions,
) int {
	hll := hyperloglog.New(0) // offset is irrelevant here

	wg := sync.WaitGroup{}
	wg.Add(len(urls))
	for _, url := range urls {
		go func(nm string) {
			defer wg.Done()
			relay, err := pool.EnsureRelay(url)
			if err != nil {
				return
			}
			ce, err := relay.countInternal(ctx, filter, opts)
			if err != nil {
				return
			}
			if len(ce.HyperLogLog) != 256 {
				return
			}
			hll.MergeRegisters(ce.HyperLogLog)
		}(NormalizeURL(url))
	}

	wg.Wait()
	return int(hll.Count())
}

// QuerySingle returns the first event returned by the first relay, cancels everything else.
func (pool *Pool) QuerySingle(
	ctx context.Context,
	urls []string,
	filter Filter,
	opts SubscriptionOptions,
) *RelayEvent {
	ctx, cancel := context.WithCancelCause(ctx)
	for ievt := range pool.FetchMany(ctx, urls, filter, opts) {
		cancel(errors.New("got the first event and ended successfully"))
		return &ievt
	}
	cancel(errors.New("SubManyEose() didn't get yield events"))
	return nil
}

func (pool *Pool) BatchedQueryManyNotifyClosed(
	ctx context.Context,
	dfs []DirectedFilter,
	opts SubscriptionOptions,
) (chan RelayEvent, chan RelayClosed) {
	closedChan := make(chan RelayClosed)
	events := pool.batchedQueryMany(ctx, dfs, closedChan, opts)
	return events, closedChan
}

// BatchedQueryMany takes a bunch of filters and sends each to the target relay but deduplicates results smartly.
func (pool *Pool) BatchedQueryMany(
	ctx context.Context,
	dfs []DirectedFilter,
	opts SubscriptionOptions,
) chan RelayEvent {
	return pool.batchedQueryMany(ctx, dfs, nil, opts)
}

func (pool *Pool) batchedQueryMany(
	ctx context.Context,
	dfs []DirectedFilter,
	closedChan chan RelayClosed,
	opts SubscriptionOptions,
) chan RelayEvent {
	res := make(chan RelayEvent)
	wg := sync.WaitGroup{}
	wg.Add(len(dfs))
	seenAlready := xsync.NewMapOf[ID, struct{}]()
	forwardWg := sync.WaitGroup{}

	opts.CheckDuplicate = func(id ID, relay string) bool {
		_, exists := seenAlready.LoadOrStore(id, struct{}{})
		if exists && pool.DuplicateMiddleware != nil {
			pool.DuplicateMiddleware(relay, id)
		}
		return exists
	}

	for _, df := range dfs {
		go func(df DirectedFilter) {
			var innerClosed chan RelayClosed
			if closedChan != nil {
				innerClosed = make(chan RelayClosed)
				forwardWg.Add(1)
				go func() {
					defer forwardWg.Done()
					for rc := range innerClosed {
						select {
						case closedChan <- rc:
						case <-ctx.Done():
							for range innerClosed {
							}
							return
						}
					}
				}()
			}

			for ie := range pool.subManyEose(ctx,
				[]string{df.Relay},
				df.Filter,
				innerClosed,
				opts,
			) {
				select {
				case res <- ie:
				case <-ctx.Done():
					wg.Done()
					return
				}
			}
			wg.Done()
		}(df)
	}

	go func() {
		wg.Wait()
		close(res)
		if closedChan != nil {
			forwardWg.Wait()
			close(closedChan)
		}
	}()

	return res
}

func (pool *Pool) BatchedSubscribeManyNotifyClosed(
	ctx context.Context,
	dfs []DirectedFilter,
	opts SubscriptionOptions,
) (chan RelayEvent, chan RelayClosed) {
	closedChan := make(chan RelayClosed)
	events := pool.batchedSubscribeMany(ctx, dfs, closedChan, opts)
	return events, closedChan
}

// BatchedSubscribeMany is like BatchedQueryMany but keeps the subscription open.
func (pool *Pool) BatchedSubscribeMany(
	ctx context.Context,
	dfs []DirectedFilter,
	opts SubscriptionOptions,
) chan RelayEvent {
	return pool.batchedSubscribeMany(ctx, dfs, nil, opts)
}

// BatchedSubscribeMany is like BatchedQueryMany but keeps the subscription open.
func (pool *Pool) batchedSubscribeMany(
	ctx context.Context,
	dfs []DirectedFilter,
	closedChan chan RelayClosed,
	opts SubscriptionOptions,
) chan RelayEvent {
	res := make(chan RelayEvent)
	wg := sync.WaitGroup{}
	wg.Add(len(dfs))
	seenAlready := xsync.NewMapOf[ID, struct{}]()
	forwardWg := sync.WaitGroup{}

	opts.CheckDuplicate = func(id ID, relay string) bool {
		_, exists := seenAlready.LoadOrStore(id, struct{}{})
		if exists && pool.DuplicateMiddleware != nil {
			pool.DuplicateMiddleware(relay, id)
		}
		return exists
	}

	for _, df := range dfs {
		go func(df DirectedFilter) {
			var innerClosed chan RelayClosed
			if closedChan != nil {
				innerClosed = make(chan RelayClosed)
				forwardWg.Add(1)
				go func() {
					defer forwardWg.Done()
					for rc := range innerClosed {
						select {
						case closedChan <- rc:
						case <-ctx.Done():
							for range innerClosed {
							}
							return
						}
					}
				}()
			}

			for ie := range pool.subMany(ctx,
				[]string{df.Relay},
				df.Filter,
				nil,
				innerClosed,
				opts,
			) {
				select {
				case res <- ie:
				case <-ctx.Done():
					wg.Done()
					return
				}
			}
			wg.Done()
		}(df)
	}

	go func() {
		wg.Wait()
		close(res)
		if closedChan != nil {
			forwardWg.Wait()
			close(closedChan)
		}
	}()

	return res
}

// Close closes the pool with the given reason.
func (pool *Pool) Close(reason string) {
	pool.cancel(fmt.Errorf("pool closed with reason: '%s'", reason))
}
