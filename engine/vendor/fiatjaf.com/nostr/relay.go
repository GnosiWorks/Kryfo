package nostr

import (
	"bytes"
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"iter"
	"log"
	"math"
	"net/http"
	"net/textproto"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	ws "github.com/coder/websocket"
	"github.com/puzpuzpuz/xsync/v3"
)

var subscriptionIDCounter atomic.Int64

var (
	ErrDisconnected = errors.New("<disconnected>")
	ErrPingFailed   = errors.New("<ping failed>")
)

type writeRequest struct {
	msg    []byte
	answer chan error
}

type closeCause struct {
	code   ws.StatusCode
	reason string
}

func (c closeCause) Error() string {
	if c.reason == "" {
		return "relay closed"
	}
	return c.reason
}

// Relay represents a connection to a Nostr relay.
type Relay struct {
	URL           string
	requestHeader http.Header // e.g. for origin header

	// websocket connection
	conn       *ws.Conn
	writeQueue chan writeRequest
	closed     *atomic.Bool

	Subscriptions *xsync.MapOf[int64, *Subscription]

	ConnectionError         error
	connectionContext       context.Context // will be canceled when the connection closes
	connectionContextCancel context.CancelCauseFunc

	challenge   string // NIP-42 challenge, we only keep the last
	performAuth sync.Once
	authed      bool

	authHandler                   func(context.Context, *Relay, *Event) error
	noticeHandler                 func(*Relay, string) // NIP-01 NOTICEs
	customHandler                 func(string)         // nonstandard unparseable messages
	okCallbacks                   map[ID]okcallback
	okCallbacksMutex              sync.Mutex
	subscriptionChannelCloseQueue chan *Subscription

	// custom things that aren't often used
	//
	AssumeValid bool // this will skip verifying signatures for events received from this relay
}

// NewRelay returns a new relay. It takes a context that, when canceled, will close the relay connection.
func NewRelay(ctx context.Context, url string, opts RelayOptions) *Relay {
	ctx, cancel := context.WithCancelCause(ctx)
	r := &Relay{
		URL:                           NormalizeURL(url),
		connectionContext:             ctx,
		connectionContextCancel:       cancel,
		Subscriptions:                 xsync.NewMapOf[int64, *Subscription](),
		okCallbacks:                   make(map[ID]okcallback, 20),
		subscriptionChannelCloseQueue: make(chan *Subscription),
		requestHeader:                 opts.RequestHeader,
		customHandler:                 opts.CustomHandler,
		noticeHandler:                 opts.NoticeHandler,
		authHandler:                   opts.AuthHandler,
		closed:                        &atomic.Bool{},
		AssumeValid:                   opts.AssumeValid,
	}

	go func() {
		<-ctx.Done()

		if wasClosed := r.closed.Swap(true); wasClosed {
			return
		}

		if r.conn != nil {
			cause := context.Cause(ctx)
			code := ws.StatusNormalClosure
			reason := ""
			var cc closeCause
			if errors.As(cause, &cc) {
				code = cc.code
				reason = cc.reason
			} else if cause != nil {
				reason = cause.Error()
			}

			_ = r.conn.Close(code, reason)
		}
	}()

	return r
}

// RelayConnect returns a relay object connected to url.
//
// The given subscription is only used during the connection phase. Once successfully connected, cancelling ctx has no effect.
//
// The ongoing relay connection uses a background context. To close the connection, call r.Close().
// If you need fine grained long-term connection contexts, use NewRelay() instead.
func RelayConnect(ctx context.Context, url string, opts RelayOptions) (*Relay, error) {
	r := NewRelay(context.Background(), url, opts)
	err := r.Connect(ctx)
	return r, err
}

type RelayOptions struct {
	// AuthHandler is fired when an AUTH message is received. It is given the AUTH event, unsigned, and expects you to sign it.
	AuthHandler func(context.Context, *Relay, *Event) error

	// NoticeHandler just takes notices and is expected to do something with them.
	// When not given defaults to logging the notices.
	NoticeHandler func(relay *Relay, notice string)

	// CustomHandler, if given, must be a function that handles any relay message
	// that couldn't be parsed as a standard envelope.
	CustomHandler func(data string)

	// RequestHeader sets the HTTP request header of the websocket preflight request
	RequestHeader http.Header

	// AssumeValid disables signature verification for events received from this relay
	AssumeValid bool
}

// String just returns the relay URL.
func (r *Relay) String() string {
	return r.URL
}

// Context retrieves the context that is associated with this relay connection.
// It will be closed when the relay is disconnected.
func (r *Relay) Context() context.Context { return r.connectionContext }

// IsConnected returns true if the connection to this relay seems to be active.
func (r *Relay) IsConnected() bool {
	if r.closed.Load() {
		return false
	}
	if r.conn == nil {
		return false
	}
	if r.connectionContext == nil {
		return false
	}
	return r.connectionContext.Err() == nil
}

// Connect tries to establish a websocket connection to r.URL.
// If the context expires before the connection is complete, an error is returned.
// Once successfully connected, context expiration has no effect: call r.Close
// to close the connection.
//
// The given context here is only used during the connection phase. The long-living
// relay connection will be based on the context given to NewRelay().
func (r *Relay) Connect(ctx context.Context) error {
	return r.ConnectWithClient(ctx, nil)
}

// ConnectWithTLS is like Connect(), but takes a special tls.Config if you need that.
func (r *Relay) ConnectWithTLS(ctx context.Context, tlsConfig *tls.Config) error {
	return r.ConnectWithClient(ctx, &http.Client{
		Transport: &http.Transport{
			TLSClientConfig: tlsConfig,
		},
	})
}

// ConnectWithClient is like Connect(), but takes a special *http.Client if you need that.
func (r *Relay) ConnectWithClient(ctx context.Context, client *http.Client) error {
	if r.connectionContext == nil || r.Subscriptions == nil {
		return fmt.Errorf("relay must be initialized with a call to NewRelay()")
	}
	if r.connectionContext.Err() != nil {
		return fmt.Errorf("relay context canceled")
	}

	if r.URL == "" {
		return fmt.Errorf("invalid relay URL '%s'", r.URL)
	}

	if err := r.newConnection(ctx, client); err != nil {
		return fmt.Errorf("error opening websocket to '%s': %w", r.URL, err)
	}

	return nil
}

func (r *Relay) newConnection(ctx context.Context, httpClient *http.Client) error {
	debugLogf("{%s} connecting!\n", r.URL)

	dialCtx := ctx
	if _, ok := dialCtx.Deadline(); !ok {
		// if no timeout is set, force it to 7 seconds
		dialCtx, _ = context.WithTimeoutCause(ctx, 7*time.Second, errors.New("connection took too long"))
	}

	dialOpts := &ws.DialOptions{
		HTTPHeader: http.Header{
			textproto.CanonicalMIMEHeaderKey("User-Agent"): {"fiatjaf.com/nostr"},
		},
		CompressionMode: ws.CompressionContextTakeover,
		HTTPClient:      httpClient,
	}
	for k, v := range r.requestHeader {
		dialOpts.HTTPHeader[k] = v
	}

	c, _, err := ws.Dial(dialCtx, r.URL, dialOpts)
	if err != nil {
		return err
	}
	c.SetReadLimit(2 << 24) // 33MB

	// ping every 19 seconds
	ticker := time.NewTicker(19 * time.Second)

	// main websocket loop
	readQueue := make(chan string, 64 /* add some buffer to account for processing/IO mismatches */)

	r.conn = c
	r.writeQueue = make(chan writeRequest, 64 /* idem */)
	r.closed = &atomic.Bool{}

	connCtx := r.connectionContext
	go func() {
		pingAttempt := 0

		for {
			select {
			case <-connCtx.Done():
				return
			case <-ticker.C:
				debugLogf("{%s} pinging\n", r.URL)
				pingCtx, cancel := context.WithTimeoutCause(connCtx, time.Millisecond*800, errors.New("ping took too long"))
				err := c.Ping(pingCtx)
				cancel()

				if err != nil {
					pingAttempt++
					debugLogf("{%s} error writing ping (attempt %d): %v", r.URL, pingAttempt, err)

					if pingAttempt >= 3 {
						debugLogf("{%s} error writing ping after multiple attempts; closing websocket", r.URL)
						_ = r.close(ErrPingFailed)
					}

					continue
				}

				// ping was OK
				debugLogf("{%s} ping OK", r.URL)
				pingAttempt = 0
			case wr := <-r.writeQueue:
				debugLogf("{%s} sending '%v'\n", r.URL, string(wr.msg))
				writeCtx, cancel := context.WithTimeoutCause(connCtx, time.Second*10, errors.New("write took too long"))
				err := c.Write(writeCtx, ws.MessageText, wr.msg)
				cancel()
				if err != nil {
					debugLogf("{%s} closing!, write failed: '%s'\n", r.URL, err)
					_ = r.close(closeCause{code: ws.StatusAbnormalClosure, reason: "write failed"})
					if wr.answer != nil {
						wr.answer <- err
					}
					return
				}
				if wr.answer != nil {
					close(wr.answer)
				}
			case msg := <-readQueue:
				debugLogf("{%s} received %v\n", r.URL, msg)
				r.handleMessage(msg)
			}
		}
	}()

	// read loop -- loops back to the main loop
	go func() {
		buf := new(bytes.Buffer)

		for {
			buf.Reset()

			_, reader, err := c.Reader(connCtx)
			if err != nil {
				debugLogf("{%s} closing!, reader failure: '%s'\n", r.URL, err)
				_ = r.close(closeCause{code: ws.StatusAbnormalClosure, reason: "failed to get reader"})
				return
			}
			if _, err := io.Copy(buf, reader); err != nil {
				debugLogf("{%s} closing!, read failure: '%s'\n", r.URL, err)
				_ = r.close(closeCause{code: ws.StatusAbnormalClosure, reason: "failed to read"})
				return
			}

			msg := string(buf.Bytes())
			select {
			case readQueue <- msg:
			case <-connCtx.Done():
				return
			}
		}
	}()

	return nil
}

func (r *Relay) closeConnection(code ws.StatusCode, reason string) {
}

func (r *Relay) handleMessage(message string) {
	// if this is an "EVENT" we will have this preparser logic that should speed things up a little
	// as we skip handling duplicate events
	subid := extractSubID(message)
	sub, ok := r.Subscriptions.Load(subIdToSerial(subid))
	if ok {
		if sub.checkDuplicate != nil {
			if sub.checkDuplicate(extractEventID(message[10+len(subid):]), r.URL) {
				return
			}
		} else if sub.checkDuplicateReplaceable != nil {
			if sub.checkDuplicateReplaceable(
				ReplaceableKey{extractEventPubKey(message), extractDTag(message)},
				extractTimestamp(message),
			) {
				return
			}
		}
	}

	envelope, err := ParseMessage(message)
	if envelope == nil {
		if r.customHandler != nil && err == UnknownLabel {
			go r.customHandler(message)
		}
		return
	}

	switch env := envelope.(type) {
	case *NoticeEnvelope:
		if r.noticeHandler != nil {
			r.noticeHandler(r, string(*env))
		} else {
			log.Printf("NOTICE from %s: '%s'\n", r.URL, string(*env))
		}
	case *AuthEnvelope:
		if env.Challenge == nil {
			return
		}

		r.performAuth = sync.Once{} // this ensures we can try to auth again
		r.challenge = *env.Challenge

		if r.authHandler != nil {
			go func() {
				r.Auth(r.Context(), func(ctx context.Context, evt *Event) error {
					return r.authHandler(ctx, r, evt)
				})
			}()
		}
	case *EventEnvelope:
		// we already have the subscription from the pre-check above, so we can just reuse it
		if sub == nil {
			// InfoLogger.Printf("{%s} no subscription with id '%s'\n", r.URL, *env.SubscriptionID)
			return
		} else {
			// check if the event matches the desired filter, ignore otherwise
			if !sub.match(env.Event) {
				InfoLogger.Printf("{%s} filter does not match: %v ~ %v\n", r.URL, sub.Filter, env.Event)
				return
			}

			// check signature, ignore invalid, except from trusted (AssumeValid) relays
			if !r.AssumeValid {
				if !env.Event.VerifySignature() {
					InfoLogger.Printf("{%s} bad signature on %s\n", r.URL, env.Event.ID)
					return
				}
			}

			// dispatch this to the internal .events channel of the subscription
			sub.dispatchEvent(env.Event)
		}
	case *EOSEEnvelope:
		if subscription, ok := r.Subscriptions.Load(subIdToSerial(string(*env))); ok {
			subscription.dispatchEose()
		}
	case *ClosedEnvelope:
		if subscription, ok := r.Subscriptions.Load(subIdToSerial(env.SubscriptionID)); ok {
			subscription.handleClosed(env.Reason)
		}
	case *CountEnvelope:
		if subscription, ok := r.Subscriptions.Load(subIdToSerial(env.SubscriptionID)); ok && env.Count != nil && subscription.countResult != nil {
			subscription.countResult <- *env
		}
	case *OKEnvelope:
		r.okCallbacksMutex.Lock()
		if okCallback, exist := r.okCallbacks[env.EventID]; exist {
			okCallback(env.OK, env.Reason)
		} else {
			InfoLogger.Printf("{%s} got an unexpected OK message for event %s", r.URL, env.EventID)
		}
		r.okCallbacksMutex.Unlock()
	}
}

// Write queues an arbitrary message to be sent to the relay.
func (r *Relay) Write(msg []byte) {
	select {
	case <-r.connectionContext.Done():
	case r.writeQueue <- writeRequest{msg: msg, answer: nil}:
	}
}

// WriteWithError is like Write, but returns an error if the write fails (and the connection gets closed).
func (r *Relay) WriteWithError(msg []byte) error {
	ch := make(chan error, 1)

	if r.writeQueue == nil {
		return nil
	}

	select {
	case <-r.connectionContext.Done():
		return fmt.Errorf("failed to write to %s: %w", r.URL, context.Cause(r.connectionContext))
	case r.writeQueue <- writeRequest{msg: msg, answer: ch}:
	}

	select {
	case err := <-ch:
		return err
	case <-r.connectionContext.Done():
		return fmt.Errorf("failed to write to %s: %w", r.URL, context.Cause(r.connectionContext))
	}
}

// Publish sends an "EVENT" command to the relay r as in NIP-01 and waits for an OK response.
func (r *Relay) Publish(ctx context.Context, event Event) error {
	return r.publish(ctx, event.ID, &EventEnvelope{Event: event})
}

// Auth sends an "AUTH" command client->relay as in NIP-42 and waits for an OK response.
//
// You don't have to build the AUTH event yourself, this function takes a function to which the
// event that must be signed will be passed, so it's only necessary to sign that.
func (r *Relay) Auth(ctx context.Context, sign func(context.Context, *Event) error) error {
	if r.authed {
		return nil
	}

	if r.challenge == "" {
		return fmt.Errorf("no challenge, can't AUTH")
	}

	var err error

	r.performAuth.Do(func() {
		authEvent := Event{
			CreatedAt: Now(),
			Kind:      KindClientAuthentication,
			Tags: Tags{
				Tag{"relay", r.URL},
				Tag{"challenge", r.challenge},
			},
			Content: "",
		}
		if err := sign(ctx, &authEvent); err != nil {
			err = fmt.Errorf("error signing auth event: %w", err)
		}

		err = r.publish(ctx, authEvent.ID, &AuthEnvelope{Event: authEvent})
	})

	if err == nil {
		r.authed = true
	}

	return err
}

// publish can be used both for EVENT and for AUTH
func (r *Relay) publish(ctx context.Context, id ID, env Envelope) error {
	var err error
	var cancel context.CancelFunc

	if _, ok := ctx.Deadline(); !ok {
		// if no timeout is set, force it to 7 seconds
		ctx, cancel = context.WithTimeoutCause(ctx, 7*time.Second, fmt.Errorf("given up waiting for an OK"))
		defer cancel()
	} else {
		// otherwise make the context cancellable so we can stop everything upon receiving an "OK"
		ctx, cancel = context.WithCancel(ctx)
		defer cancel()
	}

	// listen for an OK callback
	gotOk := make(chan bool, 1)
	handleOk := func(ok bool, reason string) {
		err = fmt.Errorf("msg: %s", reason)
		gotOk <- ok
	}

	r.okCallbacksMutex.Lock()
	if previous, exists := r.okCallbacks[id]; !exists {
		// normal path: there is nothing listening for this id, so we register this function
		r.okCallbacks[id] = func(ok bool, reason string) {
			handleOk(ok, reason)

			// and when it's called the mutex will be locked
			// so we just eliminate it
			delete(r.okCallbacks, id)
		}
	} else {
		// if the same event is published twice there will be something here already
		// so we make a function that concatenates both
		r.okCallbacks[id] = func(ok bool, reason string) {
			// we call this with an informative helper for the developer
			handleOk(ok, fmt.Sprintf("published twice: %s", reason))

			// then we replace it with the previous (and when this is called it will nuke itself accordingly)
			r.okCallbacks[id] = previous
		}
	}
	r.okCallbacksMutex.Unlock()

	// publish event
	envb, _ := env.MarshalJSON()
	if err := r.WriteWithError(envb); err != nil {
		return err
	}

	for {
		select {
		case ok := <-gotOk:
			if ok {
				return nil
			}
			return err
		case <-ctx.Done():
			r.okCallbacksMutex.Lock()
			if cb, _ := r.okCallbacks[id]; cb != nil {
				cb(false, "timeout")
			}
			r.okCallbacksMutex.Unlock()
			return fmt.Errorf("publish: %w", context.Cause(ctx))
		case <-r.connectionContext.Done():
			r.okCallbacks = make(map[ID]okcallback)
			return fmt.Errorf("relay: %w", context.Cause(r.connectionContext))
		}
	}
}

// Subscribe sends a "REQ" command to the relay r as in NIP-01.
// Events are returned through the channel sub.Events.
// The subscription is closed when context ctx is cancelled ("CLOSE" in NIP-01).
//
// Remember to cancel subscriptions, either by calling `.Unsub()` on them or ensuring their `context.Context` will be canceled at some point.
// Failure to do that will result in a huge number of halted goroutines being created.
func (r *Relay) Subscribe(ctx context.Context, filter Filter, opts SubscriptionOptions) (*Subscription, error) {
	if !r.IsConnected() {
		return nil, ErrDisconnected
	}

	sub := r.PrepareSubscription(ctx, filter, opts)

	if err := sub.Fire(); err != nil {
		sub.cancel(ErrFireFailed)
		return nil, fmt.Errorf("couldn't subscribe to %v at %s: %w", filter, r.URL, err)
	}

	go func() {
		<-ctx.Done()
		sub.cancel(nil)
	}()

	return sub, nil
}

// PrepareSubscription creates a subscription, but doesn't fire it.
//
// Remember to cancel subscriptions, either by calling `.Unsub()` on them or ensuring their `context.Context` will be canceled at some point.
// Failure to do that will result in a huge number of halted goroutines being created.
func (r *Relay) PrepareSubscription(ctx context.Context, filter Filter, opts SubscriptionOptions) *Subscription {
	current := subscriptionIDCounter.Add(1)
	ctx, cancel := context.WithCancelCause(ctx)

	sub := &Subscription{
		Relay:             r,
		Context:           ctx,
		cancel:            cancel,
		counter:           current,
		Events:            make(chan Event),
		EndOfStoredEvents: make(chan struct{}, 1),
		ClosedReason:      make(chan string, 1),
		Filter:            filter,
		match:             filter.Matches,
		eoseTimedOut:      make(chan struct{}),
	}

	sub.checkDuplicate = opts.CheckDuplicate
	sub.checkDuplicateReplaceable = opts.CheckDuplicateReplaceable

	// subscription id computation
	buf := subIdPool.Get().([]byte)[:0]
	buf = strconv.AppendInt(buf, sub.counter, 10)
	buf = append(buf, ':')
	buf = append(buf, opts.Label...)
	defer subIdPool.Put(buf)
	sub.id = string(buf)

	// we track subscriptions only by their counter, no need for the full id
	r.Subscriptions.Store(int64(sub.counter), sub)

	// start counting down for dispatching the fake EOSE
	if opts.MaxWaitForEOSE != math.MaxInt64 {
		if opts.MaxWaitForEOSE == 0 {
			opts.MaxWaitForEOSE = time.Second * 7
		}

		go func() {
			time.Sleep(opts.MaxWaitForEOSE)
			close(sub.eoseTimedOut)
			sub.dispatchEose()
		}()
	}

	// if the relay connection dies, cancel this subscription
	go func() {
		select {
		case <-sub.Context.Done():
			return
		case <-r.connectionContext.Done():
			sub.cancel(context.Cause(r.connectionContext))
		}
	}()

	// start handling events, eose, unsub etc:
	go func() {
		<-sub.Context.Done()

		// mark subscription as closed and send a CLOSE to the relay (naive sync.Once implementation)
		if sub.live.CompareAndSwap(true, false) {
			closeMsg := CloseEnvelope(sub.id)
			closeb, _ := (&closeMsg).MarshalJSON()
			if err := sub.Relay.WriteWithError(closeb); err != nil {
				_ = sub.Relay.close(err)
			}
		}

		// remove subscription from our map
		sub.Relay.Subscriptions.Delete(sub.counter)

		// do this so we don't have the possibility of closing the Events channel and then trying to send to it
		sub.mu.Lock()
		close(sub.Events)
		if sub.countResult != nil {
			close(sub.countResult)
		}
		sub.mu.Unlock()
	}()

	return sub
}

// implement Querier interface
func (r *Relay) QueryEvents(filter Filter) iter.Seq[Event] {
	ctx, cancel := context.WithCancel(r.connectionContext)

	return func(yield func(Event) bool) {
		defer cancel()

		sub, err := r.Subscribe(ctx, filter, SubscriptionOptions{Label: "queryevents"})
		if err != nil {
			return
		}

		for {
			select {
			case evt := <-sub.Events:
				if !yield(evt) {
					return
				}
			case <-sub.EndOfStoredEvents:
				return
			case <-sub.ClosedReason:
				return
			case <-ctx.Done():
				return
			}
		}
	}
}

// Count sends a "COUNT" command to the relay and returns the count of events matching the filters.
// If opts.AutoAuth is set, it will handle "auth-required:" CLOSEs using RelayOptions.AuthHandler.
func (r *Relay) Count(ctx context.Context, filter Filter, opts SubscriptionOptions) (uint32, []byte, error) {
	v, err := r.countInternal(ctx, filter, opts)
	if err != nil {
		return 0, nil, err
	}

	if v.Count == nil {
		return 0, nil, errors.New("count subscription ended without result")
	}

	return *v.Count, v.HyperLogLog, nil
}

func (r *Relay) countInternal(ctx context.Context, filter Filter, opts SubscriptionOptions) (CountEnvelope, error) {
	if !r.IsConnected() {
		return CountEnvelope{}, ErrDisconnected
	}

	if _, ok := ctx.Deadline(); !ok {
		// if no timeout is set, force it to 7 seconds
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeoutCause(ctx, 7*time.Second, errors.New("countInternal took too long"))
		defer cancel()
	}

	hasAuthed := false

	for {
		sub := r.PrepareSubscription(ctx, filter, opts)
		sub.countResult = make(chan CountEnvelope, 1)

		if err := sub.Fire(); err != nil {
			sub.cancel(ErrFireFailed)
			return CountEnvelope{}, fmt.Errorf("couldn't count %v at %s: %w", filter, r.URL, err)
		}

		go func() {
			<-ctx.Done()
			sub.cancel(nil)
		}()

		for {
			select {
			case count, ok := <-sub.countResult:
				sub.cancel(errors.New("countInternal() ended"))
				if !ok || count.Count == nil {
					return CountEnvelope{}, errors.New("count subscription ended without result")
				}
				return count, nil
			case reason := <-sub.ClosedReason:
				sub.cancel(errors.New("countInternal() ended"))
				if strings.HasPrefix(reason, "auth-required:") && r.authHandler != nil && !hasAuthed {
					authErr := r.Auth(ctx, func(authCtx context.Context, evt *Event) error {
						return r.authHandler(authCtx, r, evt)
					})
					if authErr == nil {
						hasAuthed = true
						goto resubscribe
					}
					return CountEnvelope{}, fmt.Errorf("failed to auth: %w", authErr)
				}
				return CountEnvelope{}, fmt.Errorf("count: CLOSED received: %s", reason)
			case <-sub.Context.Done():
				sub.cancel(errors.New("countInternal() ended"))
				return CountEnvelope{}, context.Cause(sub.Context)
			case <-ctx.Done():
				sub.cancel(errors.New("countInternal() ended"))
				return CountEnvelope{}, ctx.Err()
			}
		}

	resubscribe:
		continue
	}
}

// Close closes the relay connection.
func (r *Relay) Close() error {
	return r.close(errors.New("Close() called"))
}

func (r *Relay) close(reason error) error {
	r.connectionContextCancel(reason)
	return nil
}

var subIdPool = sync.Pool{
	New: func() any { return make([]byte, 0, 15) },
}

type okcallback func(ok bool, reason string)
