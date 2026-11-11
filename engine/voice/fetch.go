// SPDX-License-Identifier: GPL-3.0-or-later
package voice

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/halo/engine/translate"
)

var (
	ErrHash   = errors.New("hash mismatch")
	ErrSize   = errors.New("wrong size")
	ErrStatus = errors.New("bad status")
	ErrShort  = errors.New("no progress")
)

// Chunk is what every request asks for, so all but the last are the same
// size on the wire.
const Chunk = 1 << 20

// Getter asks for n bytes of url from off. it returns the body and where
// the body starts: off when the range was honoured, 0 when the server sent
// the whole file instead.
type Getter func(ctx context.Context, url string, off, n int64) (io.ReadCloser, int64, error)

// HTTPGetter makes range requests with c, which the engine builds on a tor
// lane of its own. no user agent, no compression: the request names the
// file and says nothing of who asks.
func HTTPGetter(c *http.Client) Getter {
	return func(ctx context.Context, url string, off, n int64) (io.ReadCloser, int64, error) {
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
		if err != nil {
			return nil, 0, err
		}
		req.Header.Set("User-Agent", "")
		req.Header.Set("Accept-Encoding", "identity")
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-%d", off, off+n-1))
		resp, err := c.Do(req)
		if err != nil {
			return nil, 0, err
		}
		switch resp.StatusCode {
		case http.StatusPartialContent:
			start, ok := rangeStart(resp.Header.Get("Content-Range"))
			if !ok || start != off {
				resp.Body.Close()
				return nil, 0, fmt.Errorf("%w: content-range %q", ErrStatus, resp.Header.Get("Content-Range"))
			}
			return resp.Body, off, nil
		case http.StatusOK:
			return resp.Body, 0, nil
		}
		resp.Body.Close()
		return nil, 0, fmt.Errorf("%w: %d", ErrStatus, resp.StatusCode)
	}
}

// the first byte of "bytes a-b/total"
func rangeStart(h string) (int64, bool) {
	s, ok := strings.CutPrefix(h, "bytes ")
	if !ok {
		return 0, false
	}
	a, _, ok := strings.Cut(s, "-")
	if !ok {
		return 0, false
	}
	n, err := strconv.ParseInt(a, 10, 64)
	return n, err == nil && n >= 0
}

// Progress is told the bytes fetched so far out of the whole model.
type Progress func(done, total int64)

// Path is where md lives in dir once fetched and checked.
func Path(dir string, md Model) string { return filepath.Join(dir, md.File) }

// Fetch puts md into dir, checked against its pin. a cut leaves the part
// file for the next call to go on from; a model already in place is
// checked, not fetched again.
func Fetch(ctx context.Context, get Getter, m *Manifest, md Model, dir string, prog Progress) error {
	if err := AppDir(dir); err != nil {
		return err
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	if err := Check(dir, md); err == nil {
		if prog != nil {
			prog(md.Size, md.Size)
		}
		return nil
	}
	part := Path(dir, md) + ".part"
	if err := fetchPart(ctx, get, m.URL(md), md.Size, part, prog); err != nil {
		return err
	}
	if err := checkFile(part, md); err != nil {
		// a resume would only fetch the same bytes again
		os.Remove(part)
		return err
	}
	// a stop that came during the last chunk or the hash lands nothing
	if err := ctx.Err(); err != nil {
		return err
	}
	return os.Rename(part, Path(dir, md))
}

// FetchWith puts md into dir as Fetch does, but the bytes come the way
// translation's packs do: chunks over f's lanes, each stop waited out with
// a backoff and asked again from the byte the part file holds, a fresh
// circuit after two misses, until no chunk came for f.GiveUp. a cut
// download goes on from its part file at the next call.
func FetchWith(ctx context.Context, f translate.Fetcher, m *Manifest, md Model, dir string, prog Progress) error {
	if err := AppDir(dir); err != nil {
		return err
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	if err := Check(dir, md); err == nil {
		if prog != nil {
			prog(md.Size, md.Size)
		}
		return nil
	}
	part, got := Path(dir, md)+".part", Path(dir, md)+".got"
	if err := f.FetchPlain(ctx, m.URL(md), md.Size, part, got, translate.Progress(prog)); err != nil {
		return err
	}
	if err := checkFile(part, md); err != nil {
		os.Remove(part)
		os.Remove(got)
		return err
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	if err := os.Rename(part, Path(dir, md)); err != nil {
		return err
	}
	os.Remove(got)
	os.Remove(got + ".new")
	return nil
}

func fetchPart(ctx context.Context, get Getter, url string, size int64, part string, prog Progress) error {
	fh, err := os.OpenFile(part, os.O_RDWR|os.O_CREATE, 0o600)
	if err != nil {
		return err
	}
	defer fh.Close()
	have, err := fh.Seek(0, io.SeekEnd)
	if err != nil {
		return err
	}
	if have > size {
		if err := restart(fh); err != nil {
			return err
		}
		have = 0
	}
	if prog != nil {
		prog(have, size)
	}
	for have < size {
		if err := ctx.Err(); err != nil {
			return err
		}
		body, start, err := get(ctx, url, have, min(Chunk, size-have))
		if err != nil {
			return err
		}
		if start != have {
			// the server ignored the range: take the whole file from the top
			if start != 0 {
				body.Close()
				return fmt.Errorf("%w: body from %d", ErrStatus, start)
			}
			if err := restart(fh); err != nil {
				body.Close()
				return err
			}
			have = 0
		}
		w, err := io.Copy(fh, io.LimitReader(body, size-have+1))
		body.Close()
		have += w
		if have > size {
			restart(fh)
			return fmt.Errorf("%w: more than %d bytes", ErrSize, size)
		}
		if prog != nil {
			prog(have, size)
		}
		if err != nil {
			return err
		}
		if w == 0 {
			return ErrShort
		}
	}
	return fh.Sync()
}

func restart(fh *os.File) error {
	if err := fh.Truncate(0); err != nil {
		return err
	}
	_, err := fh.Seek(0, io.SeekStart)
	return err
}

func checkFile(path string, md Model) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return err
	}
	if st.Size() != md.Size {
		return fmt.Errorf("%w: %d bytes, pinned %d", ErrSize, st.Size(), md.Size)
	}
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return err
	}
	if got := hex.EncodeToString(h.Sum(nil)); got != md.SHA256 {
		return fmt.Errorf("%w: %s", ErrHash, got)
	}
	return nil
}

// Check says whether md is in dir and matches its pin. a file that does
// not is deleted, so the next tap asks for the download again. reads every
// byte, so the app asks off the ui thread.
func Check(dir string, md Model) error {
	p := Path(dir, md)
	err := checkFile(p, md)
	if errors.Is(err, ErrHash) || errors.Is(err, ErrSize) {
		os.Remove(p)
	}
	return err
}

// Remove takes md off the phone, a part file too.
func Remove(dir string, md Model) error {
	if err := AppDir(dir); err != nil {
		return err
	}
	at := Path(dir, md)
	for _, p := range []string{at, at + ".part", at + ".got", at + ".got.new"} {
		if err := os.Remove(p); err != nil && !errors.Is(err, os.ErrNotExist) {
			return err
		}
	}
	return nil
}
