// SPDX-License-Identifier: GPL-3.0-or-later
package voice

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"testing"
	"time"
)

func waitState(t *testing.T, j *Jobs, key, want string) Status {
	t.Helper()
	for i := 0; i < 500; i++ {
		if st := j.Status(key); st.State == want {
			return st
		}
		time.Sleep(2 * time.Millisecond)
	}
	t.Fatalf("%s never got to %s: %+v", key, want, j.Status(key))
	return Status{}
}

func TestJobsDone(t *testing.T) {
	var j Jobs
	if st := j.Status("base"); st.State != StateIdle {
		t.Fatalf("fresh %+v", st)
	}
	j.Start("base", func(ctx context.Context, prog Progress) error {
		prog(5, 10)
		return nil
	})
	st := waitState(t, &j, "base", StateDone)
	if st.Done != 10 || st.Total != 10 {
		t.Fatalf("done %+v", st)
	}
	j.Forget("base")
	if j.Status("base").State != StateIdle {
		t.Fatal("forgotten job still there")
	}
}

func TestJobsOneAtATime(t *testing.T) {
	var j Jobs
	release := make(chan struct{})
	if !j.Start("base", func(ctx context.Context, prog Progress) error { <-release; return nil }) {
		t.Fatal("first start refused")
	}
	if j.Start("base", func(context.Context, Progress) error { return nil }) {
		t.Fatal("a second download of the same model ran")
	}
	if !j.Running("base") {
		t.Fatal("not running")
	}
	j.Forget("base")
	if !j.Running("base") {
		t.Fatal("forgot a running job")
	}
	close(release)
	waitState(t, &j, "base", StateDone)
}

func TestJobsCancelWaits(t *testing.T) {
	var j Jobs
	let := make(chan struct{})
	j.Start("base", func(ctx context.Context, prog Progress) error {
		prog(3, 9)
		<-ctx.Done()
		close(let)
		return ctx.Err()
	})
	waitState(t, &j, "base", StateRunning)
	for j.Status("base").Done != 3 {
		time.Sleep(time.Millisecond)
	}
	j.Cancel("base")
	select {
	case <-let:
	default:
		t.Fatal("cancel returned before the download let go")
	}
	st := waitState(t, &j, "base", StateCancelled)
	// a resume picks the count up where it stopped
	j.Start("base", func(ctx context.Context, prog Progress) error {
		if got := j.Status("base"); got.Done != 3 || got.Total != 9 {
			return fmt.Errorf("resumed at %+v", got)
		}
		return nil
	})
	if st = waitState(t, &j, "base", StateDone); st.Err != "" {
		t.Fatal(st.Err)
	}
	j.Cancel("base")
	j.Cancel("never")
}

func TestJobsFailureKind(t *testing.T) {
	var j Jobs
	j.Start("a", func(context.Context, Progress) error { return fmt.Errorf("t.bin: %w", ErrHash) })
	j.Start("b", func(context.Context, Progress) error { return ErrSize })
	j.Start("c", func(context.Context, Progress) error { return errors.New("dial tcp: refused") })
	for key, kind := range map[string]string{"a": "hash", "b": "hash", "c": "net"} {
		if st := waitState(t, &j, key, StateFailed); st.Kind != kind || st.Err == "" {
			t.Errorf("%s: %+v", key, st)
		}
	}
}

func TestJobsStopAllDoesNotWait(t *testing.T) {
	var j Jobs
	let := make(chan struct{})
	for _, key := range []string{"a", "b"} {
		j.Start(key, func(ctx context.Context, prog Progress) error {
			<-ctx.Done()
			<-let
			return ctx.Err()
		})
	}
	j.Start("c", func(context.Context, Progress) error { return nil })
	waitState(t, &j, "c", StateDone)
	j.StopAll()
	// both still hold their files; StopAll returned all the same, and the
	// app sees them stopped at once
	for _, key := range []string{"a", "b"} {
		if st := j.Status(key); st.State != StateCancelled || !j.Busy(key) {
			t.Fatalf("%s after StopAll: %+v busy %v", key, st, j.Busy(key))
		}
	}
	close(let)
	waitState(t, &j, "a", StateCancelled)
	waitState(t, &j, "b", StateCancelled)
	if j.Status("c").State != StateDone {
		t.Fatal("a finished download lost its word")
	}
}

// a download asked for again right after a stop starts fresh once the
// stopped one lets go, instead of being taken for the old one
func TestJobsStartAfterStopIsFresh(t *testing.T) {
	var j Jobs
	let := make(chan struct{})
	j.Start("base", func(ctx context.Context, prog Progress) error {
		prog(4, 8)
		<-ctx.Done()
		<-let
		return ctx.Err()
	})
	for j.Status("base").Done != 4 {
		time.Sleep(time.Millisecond)
	}
	j.StopAll()
	if j.Running("base") {
		t.Fatal("a stopped download still says running")
	}
	j.Forget("base")
	if !j.Busy("base") {
		t.Fatal("forgot a download that still holds its file")
	}
	ran := make(chan struct{})
	started := make(chan bool, 1)
	go func() {
		started <- j.Start("base", func(ctx context.Context, prog Progress) error {
			close(ran)
			return nil
		})
	}()
	select {
	case <-ran:
		t.Fatal("the new download ran while the old one held the file")
	case <-time.After(50 * time.Millisecond):
	}
	close(let)
	if !<-started {
		t.Fatal("the new download was refused")
	}
	<-ran
	if st := waitState(t, &j, "base", StateDone); st.Done != 8 || st.Total != 8 {
		t.Fatalf("fresh download %+v", st)
	}
}

// Cancel on a download already stopped still waits for it to let go
func TestJobsCancelAfterStopWaits(t *testing.T) {
	var j Jobs
	let := make(chan struct{})
	held := true
	var mu sync.Mutex
	j.Start("base", func(ctx context.Context, prog Progress) error {
		<-ctx.Done()
		<-let
		mu.Lock()
		held = false
		mu.Unlock()
		return ctx.Err()
	})
	j.StopAll()
	go func() {
		time.Sleep(20 * time.Millisecond)
		close(let)
	}()
	j.Cancel("base")
	mu.Lock()
	defer mu.Unlock()
	if held {
		t.Fatal("cancel returned while the stopped download held its file")
	}
	if j.Busy("base") || j.Status("base").State != StateCancelled {
		t.Fatalf("after cancel %+v", j.Status("base"))
	}
}
