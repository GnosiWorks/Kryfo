// SPDX-License-Identifier: GPL-3.0-or-later
package devices

import (
	"bufio"
	"bytes"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func memTotal(t *testing.T) uint64 {
	f, err := os.Open("/proc/meminfo")
	if err != nil {
		t.Skip("no /proc/meminfo")
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		if v, ok := strings.CutPrefix(sc.Text(), "MemTotal:"); ok {
			kb, _ := strconv.ParseUint(strings.Fields(v)[0], 10, 64)
			return kb << 10
		}
	}
	t.Skip("no MemTotal")
	return 0
}

// a stream bigger than the machine's memory goes through with the heap
// flat: one sparse file of more than all ram, sent and taken whole
func TestHistoryLargerThanMemory(t *testing.T) {
	if testing.Short() || raceOn {
		t.Skip("long; runs without -short and -race")
	}
	size := memTotal(t) + 1<<30
	w := newHistWorld(t, histShape{chunk: MaxChunk})
	f, err := os.Create(filepath.Join(w.root, "big.mp4"))
	if err != nil {
		t.Fatal(err)
	}
	// sparse: no disk is used, every byte reads as zero
	if err := f.Truncate(int64(size)); err != nil {
		t.Skip("no sparse files here")
	}
	f.Close()
	w.chats = []histChat{{meta: []byte(`{"k":1}`), rows: [][]byte{[]byte(`{"a":1}`)}}}
	s, err := NewSender(w.key, w.bind, w.id.pub, w.opt)
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	s.Chat(w.chats[0].meta)
	s.Message(w.chats[0].rows[0])
	if err := s.Media(0, 1, "big.mp4"); err != nil {
		t.Fatal(err)
	}

	var peak atomic.Uint64
	stop := make(chan struct{})
	go func() {
		var ms runtime.MemStats
		for {
			select {
			case <-stop:
				return
			case <-time.After(100 * time.Millisecond):
			}
			runtime.ReadMemStats(&ms)
			if ms.HeapInuse > peak.Load() {
				peak.Store(ms.HeapInuse)
			}
		}
	}()
	if err := s.Plan(); err != nil {
		t.Fatal(err)
	}
	r := w.recvFor(s.ID())
	zero := make([]byte, MaxChunk)
	var got uint64
	for i := uint64(0); i < s.head.Records; i++ {
		rec, err := s.Record(i)
		if err != nil {
			t.Fatal(err)
		}
		ev, err := r.Take(rec)
		if err != nil {
			t.Fatalf("record %d: %v", i, err)
		}
		switch ev.Kind {
		case EvData:
			if ev.Offset != got || !bytes.Equal(ev.Bytes, zero[:len(ev.Bytes)]) {
				t.Fatalf("chunk at %d", ev.Offset)
			}
			got += uint64(len(ev.Bytes))
			if ev.Last && !ev.Ok {
				t.Fatal("the file is not whole")
			}
		}
	}
	close(stop)
	if !r.Done() || got != size {
		t.Fatalf("took %d of %d bytes", got, size)
	}
	if p := peak.Load(); p > 256<<20 {
		t.Fatalf("heap reached %d MiB", p>>20)
	}
	t.Logf("%d GiB through, heap at most %d MiB", size>>30, peak.Load()>>20)
}
