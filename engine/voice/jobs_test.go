// SPDX-License-Identifier: GPL-3.0-or-later
package voice

import (
	"context"
	"errors"
	"fmt"
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
