// SPDX-License-Identifier: GPL-3.0-or-later
// tor's main loop runs inside this process, and there can be one of it.
// bine's close returns after 300ms whether or not that loop has ended, and a
// second loop started while the first unwinds trips an assertion in tor that
// aborts the app. this tracks the real end so a start can wait for it.
package main

import (
	"context"
	"net"
	"sync/atomic"
	"time"

	libtor "github.com/alexballas/go-libtor"
	"github.com/cretz/bine/process"
)

// tor main loops alive in this process. never meant to pass one.
var torMains int32

type trackedCreator struct{}

var torCreator process.Creator = trackedCreator{}

func (trackedCreator) New(ctx context.Context, args ...string) (process.Process, error) {
	// the inner process gets a context that never ends: its Wait returns
	// early when the context does, before the loop has really ended
	inner, err := libtor.Creator.New(context.Background(), args...)
	if err != nil {
		return nil, err
	}
	if ctx == nil {
		ctx = context.Background()
	}
	return &trackedProcess{ctx: ctx, inner: inner, exited: make(chan struct{})}, nil
}

type trackedProcess struct {
	ctx    context.Context
	inner  process.Process
	exited chan struct{}
	err    error
}

func (p *trackedProcess) Start() error {
	if err := p.inner.Start(); err != nil {
		return err
	}
	atomic.AddInt32(&torMains, 1)
	go func() {
		p.err = p.inner.Wait()
		atomic.AddInt32(&torMains, -1)
		close(p.exited)
	}()
	return nil
}

func (p *trackedProcess) Wait() error {
	select {
	case <-p.ctx.Done():
		return p.ctx.Err()
	case <-p.exited:
		return p.err
	}
}

func (p *trackedProcess) EmbeddedControlConn() (net.Conn, error) {
	return p.inner.EmbeddedControlConn()
}

// true once no tor main loop is left, false when the wait ran out
func waitTorGone(limit time.Duration) bool {
	deadline := time.Now().Add(limit)
	for atomic.LoadInt32(&torMains) > 0 {
		if time.Now().After(deadline) {
			return false
		}
		time.Sleep(100 * time.Millisecond)
	}
	return true
}
