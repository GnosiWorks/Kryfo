// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"context"
	"errors"
	"sync"
)

// what a download is doing, as the app polls it
const (
	StateIdle      = "idle"
	StateRunning   = "running"
	StateDone      = "done"
	StateFailed    = "failed"
	StateCancelled = "cancelled"
)

// Status is one download as the app sees it. Kind sorts a failure for the
// words the app shows: "hash" for a file that did not match its pin,
// "net" for everything a retry may get past.
type Status struct {
	State string `json:"state"`
	Done  int64  `json:"done"`
	Total int64  `json:"total"`
	Kind  string `json:"kind,omitempty"`
	Err   string `json:"err,omitempty"`
}

type job struct {
	st     Status
	cancel context.CancelFunc
}

// Jobs runs at most one download per key in the background and keeps the
// last word on each, so the app can poll instead of being called back.
type Jobs struct {
	mu sync.Mutex
	m  map[string]*job
}

// Start runs fn for key unless it is running already. fn's progress shows in
// Status; its error, or ctx's when cancelled, ends it.
func (j *Jobs) Start(key string, fn func(ctx context.Context, prog Progress) error) bool {
	j.mu.Lock()
	defer j.mu.Unlock()
	if j.m == nil {
		j.m = map[string]*job{}
	}
	if old := j.m[key]; old != nil && old.st.State == StateRunning {
		return false
	}
	ctx, cancel := context.WithCancel(context.Background())
	jb := &job{st: Status{State: StateRunning}, cancel: cancel}
	if old := j.m[key]; old != nil {
		// a resume starts its count where the last one got to
		jb.st.Done, jb.st.Total = old.st.Done, old.st.Total
	}
	j.m[key] = jb
	go func() {
		err := fn(ctx, func(done, total int64) {
			j.mu.Lock()
			jb.st.Done, jb.st.Total = done, total
			j.mu.Unlock()
		})
		cancel()
		j.mu.Lock()
		defer j.mu.Unlock()
		switch {
		case err == nil:
			jb.st.State = StateDone
			jb.st.Done = jb.st.Total
		case errors.Is(err, context.Canceled):
			jb.st.State = StateCancelled
		default:
			jb.st.State = StateFailed
			jb.st.Err = err.Error()
			jb.st.Kind = "net"
			if errors.Is(err, ErrHash) || errors.Is(err, ErrSize) {
				jb.st.Kind = "hash"
			}
		}
	}()
	return true
}

// Status is the last word on key; StateIdle when it never ran.
func (j *Jobs) Status(key string) Status {
	j.mu.Lock()
	defer j.mu.Unlock()
	if jb := j.m[key]; jb != nil {
		return jb.st
	}
	return Status{State: StateIdle}
}

// Cancel stops key's download. what it fetched stays for the next Start.
func (j *Jobs) Cancel(key string) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if jb := j.m[key]; jb != nil && jb.st.State == StateRunning {
		jb.cancel()
	}
}

// Forget drops key's last word, once its files are gone.
func (j *Jobs) Forget(key string) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if jb := j.m[key]; jb != nil && jb.st.State != StateRunning {
		delete(j.m, key)
	}
}
