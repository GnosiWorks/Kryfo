// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"compress/gzip"
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

var (
	ErrHash   = errors.New("hash mismatch")
	ErrSize   = errors.New("wrong size")
	ErrStatus = errors.New("bad status")
	ErrShort  = errors.New("no progress")
)

// Chunk is how much every request asks for. all requests but a file's last
// are the same size, so the sizes on the wire say little more than the
// number of them does.
const Chunk = 1 << 20

// Getter asks for n bytes of url from off. it returns the body and where
// the body starts: off when the range was honoured, 0 when the server sent
// the whole file instead.
type Getter func(ctx context.Context, url string, off, n int64) (io.ReadCloser, int64, error)

// HTTPGetter makes range requests with c. the engine hands it a client on
// a tor lane of its own. no user agent, no compression, nothing but the
// range: the request carries what file it wants and nothing about who asks.
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

// Progress is told the bytes fetched so far out of the whole pair.
type Progress func(done, total int64)

// FetchPair puts a pair's files into dir, unpacked and checked. what was
// fetched before stays: a call after a cut picks up where it stopped, and
// a file already in place is checked, not fetched again.
func FetchPair(ctx context.Context, get Getter, m *Manifest, p Pair, dir string, prog Progress) error {
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	total := p.GzBytes()
	var done int64
	for _, f := range p.Files {
		base := done
		on := func(n int64) {
			if prog != nil {
				prog(base+n, total)
			}
		}
		if err := FetchFile(ctx, get, m.SourceURL(f), f, dir, on); err != nil {
			return fmt.Errorf("%s: %w", f.Name, err)
		}
		done += f.GzSize
		on(f.GzSize)
	}
	return nil
}

// FetchFile fetches one file's gzip into dir/<name>.gz.part, checks it,
// and unpacks it to dir/<name>. on a cut the part file stays for the next
// call; on a wrong hash it goes, since a resume would only repeat it.
func FetchFile(ctx context.Context, get Getter, url string, f File, dir string, on func(int64)) error {
	final := filepath.Join(dir, f.Name)
	if err := checkFile(final, f.Size, f.SHA256); err == nil {
		return nil
	}
	part := final + ".gz.part"
	if err := fetchPart(ctx, get, url, f, part, on); err != nil {
		return err
	}
	if err := checkFile(part, f.GzSize, f.GzSHA256); err != nil {
		os.Remove(part)
		return err
	}
	if err := unpack(part, final, f); err != nil {
		return err
	}
	os.Remove(part)
	return nil
}

func fetchPart(ctx context.Context, get Getter, url string, f File, part string, on func(int64)) error {
	fh, err := os.OpenFile(part, os.O_RDWR|os.O_CREATE, 0o600)
	if err != nil {
		return err
	}
	defer fh.Close()
	have, err := fh.Seek(0, io.SeekEnd)
	if err != nil {
		return err
	}
	if have > f.GzSize {
		if err := restart(fh); err != nil {
			return err
		}
		have = 0
	}
	for have < f.GzSize {
		if err := ctx.Err(); err != nil {
			return err
		}
		n := min(Chunk, f.GzSize-have)
		body, start, err := get(ctx, url, have, n)
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
		w, err := io.Copy(fh, io.LimitReader(body, f.GzSize-have+1))
		body.Close()
		have += w
		if on != nil {
			on(min(have, f.GzSize))
		}
		if have > f.GzSize {
			restart(fh)
			return fmt.Errorf("%w: more than %d bytes", ErrSize, f.GzSize)
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

// unpack writes the gzip at part to final through a temp file, so final is
// either the whole checked file or not there.
func unpack(part, final string, f File) error {
	in, err := os.Open(part)
	if err != nil {
		return err
	}
	defer in.Close()
	err = unpackFrom(in, final, f)
	// a gzip that hashed right but unpacks wrong would do so again
	if errors.Is(err, ErrHash) || errors.Is(err, ErrSize) {
		os.Remove(part)
	}
	return err
}

func unpackFrom(in io.Reader, final string, f File) error {
	zr, err := gzip.NewReader(in)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrHash, err)
	}
	zr.Multistream(false)
	tmp, err := os.CreateTemp(filepath.Dir(final), ".unpack-*")
	if err != nil {
		return err
	}
	h := sha256.New()
	n, err := io.Copy(io.MultiWriter(tmp, h), io.LimitReader(zr, f.Size+1))
	if err == nil {
		err = tmp.Sync()
	}
	if cerr := tmp.Close(); err == nil {
		err = cerr
	}
	switch {
	case err != nil:
	case n != f.Size:
		err = fmt.Errorf("%w: unpacked %d, want %d", ErrSize, n, f.Size)
	case hexSum(h.Sum(nil)) != f.SHA256:
		err = fmt.Errorf("%w: unpacked", ErrHash)
	}
	if err == nil {
		err = os.Rename(tmp.Name(), final)
	}
	if err != nil {
		os.Remove(tmp.Name())
		return err
	}
	return nil
}

func checkFile(p string, size int64, sum string) error {
	fh, err := os.Open(p)
	if err != nil {
		return err
	}
	defer fh.Close()
	st, err := fh.Stat()
	if err != nil {
		return err
	}
	if st.Size() != size {
		return fmt.Errorf("%w: %d, want %d", ErrSize, st.Size(), size)
	}
	return checkReader(fh, size, sum)
}

func checkReader(r io.Reader, size int64, sum string) error {
	h := sha256.New()
	n, err := io.Copy(h, io.LimitReader(r, size+1))
	if err != nil {
		return err
	}
	if n != size {
		return fmt.Errorf("%w: %d, want %d", ErrSize, n, size)
	}
	if hexSum(h.Sum(nil)) != sum {
		return ErrHash
	}
	return nil
}

// Installed reports whether every file of the pair is in dir and checks out.
func Installed(p Pair, dir string) bool {
	for _, f := range p.Files {
		if checkFile(filepath.Join(dir, f.Name), f.Size, f.SHA256) != nil {
			return false
		}
	}
	return true
}
