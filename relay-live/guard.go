package main

// khatru reads each message in a goroutine of its own with no recover, so
// one panic in a hook ends the whole relay. every hook is wrapped: a panic
// is logged by the hook's name alone, nothing of the event, the filter or
// the peer, and the event or filter is refused.

import (
	"context"
	"errors"
	"log"
	"net/http"

	"github.com/fiatjaf/khatru"
	"github.com/nbd-wtf/go-nostr"
)

const panicRefusal = "error: could not check this"

var errPanic = errors.New(panicRefusal)

func caught(hook string) bool {
	log.Printf("panic in %s", hook)
	return true
}

func guardReject[T any](hook string, h func(context.Context, T) (bool, string)) func(context.Context, T) (bool, string) {
	return func(ctx context.Context, v T) (reject bool, msg string) {
		defer func() {
			if recover() != nil && caught(hook) {
				reject, msg = true, panicRefusal
			}
		}()
		return h(ctx, v)
	}
}

func guardErr[T any](hook string, h func(context.Context, T) error) func(context.Context, T) error {
	return func(ctx context.Context, v T) (err error) {
		defer func() {
			if recover() != nil && caught(hook) {
				err = errPanic
			}
		}()
		return h(ctx, v)
	}
}

func guardDo[T any](hook string, h func(context.Context, T)) func(context.Context, T) {
	return func(ctx context.Context, v T) {
		defer func() {
			if recover() != nil {
				caught(hook)
			}
		}()
		h(ctx, v)
	}
}

func guardConn(hook string, h func(context.Context)) func(context.Context) {
	return func(ctx context.Context) {
		defer func() {
			if recover() != nil {
				caught(hook)
			}
		}()
		h(ctx)
	}
}

func guardEach[F any](hooks []F, wrap func(F) F) {
	for i, h := range hooks {
		hooks[i] = wrap(h)
	}
}

// called once, after every hook is in
func guardHooks(r *khatru.Relay) {
	guardEach(r.RejectEvent, func(h func(context.Context, *nostr.Event) (bool, string)) func(context.Context, *nostr.Event) (bool, string) {
		return guardReject("RejectEvent", h)
	})
	guardEach(r.RejectFilter, func(h func(context.Context, nostr.Filter) (bool, string)) func(context.Context, nostr.Filter) (bool, string) {
		return guardReject("RejectFilter", h)
	})
	guardEach(r.RejectCountFilter, func(h func(context.Context, nostr.Filter) (bool, string)) func(context.Context, nostr.Filter) (bool, string) {
		return guardReject("RejectCountFilter", h)
	})
	guardEach(r.OverwriteFilter, func(h func(context.Context, *nostr.Filter)) func(context.Context, *nostr.Filter) {
		return guardDo("OverwriteFilter", h)
	})
	guardEach(r.OverwriteDeletionOutcome, func(h func(context.Context, *nostr.Event, *nostr.Event) (bool, string)) func(context.Context, *nostr.Event, *nostr.Event) (bool, string) {
		return func(ctx context.Context, target, deletion *nostr.Event) (accept bool, msg string) {
			defer func() {
				if recover() != nil && caught("OverwriteDeletionOutcome") {
					accept, msg = false, panicRefusal
				}
			}()
			return h(ctx, target, deletion)
		}
	})
	for _, hooks := range []struct {
		name string
		list []func(context.Context, *nostr.Event) error
	}{{"StoreEvent", r.StoreEvent}, {"ReplaceEvent", r.ReplaceEvent}, {"DeleteEvent", r.DeleteEvent}} {
		guardEach(hooks.list, func(h func(context.Context, *nostr.Event) error) func(context.Context, *nostr.Event) error {
			return guardErr(hooks.name, h)
		})
	}
	guardEach(r.OnEventSaved, func(h func(context.Context, *nostr.Event)) func(context.Context, *nostr.Event) {
		return guardDo("OnEventSaved", h)
	})
	guardEach(r.OnEphemeralEvent, func(h func(context.Context, *nostr.Event)) func(context.Context, *nostr.Event) {
		return guardDo("OnEphemeralEvent", h)
	})
	guardEach(r.QueryEvents, func(h func(context.Context, nostr.Filter) (chan *nostr.Event, error)) func(context.Context, nostr.Filter) (chan *nostr.Event, error) {
		return func(ctx context.Context, f nostr.Filter) (ch chan *nostr.Event, err error) {
			defer func() {
				if recover() != nil && caught("QueryEvents") {
					ch, err = nil, errPanic
				}
			}()
			return h(ctx, f)
		}
	})
	guardEach(r.CountEvents, func(h func(context.Context, nostr.Filter) (int64, error)) func(context.Context, nostr.Filter) (int64, error) {
		return func(ctx context.Context, f nostr.Filter) (n int64, err error) {
			defer func() {
				if recover() != nil && caught("CountEvents") {
					n, err = 0, errPanic
				}
			}()
			return h(ctx, f)
		}
	})
	guardEach(r.RejectConnection, func(h func(*http.Request) bool) func(*http.Request) bool {
		return func(req *http.Request) (reject bool) {
			defer func() {
				if recover() != nil && caught("RejectConnection") {
					reject = true
				}
			}()
			return h(req)
		}
	})
	guardEach(r.OnConnect, func(h func(context.Context)) func(context.Context) {
		return guardConn("OnConnect", h)
	})
	guardEach(r.OnDisconnect, func(h func(context.Context)) func(context.Context) {
		return guardConn("OnDisconnect", h)
	})
	guardEach(r.PreventBroadcast, func(h func(*khatru.WebSocket, *nostr.Event) bool) func(*khatru.WebSocket, *nostr.Event) bool {
		return func(ws *khatru.WebSocket, ev *nostr.Event) (prevent bool) {
			defer func() {
				if recover() != nil && caught("PreventBroadcast") {
					prevent = true
				}
			}()
			return h(ws, ev)
		}
	})
}
