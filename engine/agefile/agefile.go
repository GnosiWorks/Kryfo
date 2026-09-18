// SPDX-License-Identifier: GPL-3.0-or-later
// lock and open a file with a password, in the age format, so what is locked
// here opens with any age tool and the other way round. passphrase mode
// only. everything streams: a file is never held whole in memory.
package agefile

import (
	"bufio"
	"bytes"
	"errors"
	"io"
	"regexp"
	"strconv"
	"sync/atomic"

	"filippo.io/age"
	"filippo.io/age/armor"
)

var (
	ErrWrongPassword = errors.New("wrong-password")
	ErrCorrupt       = errors.New("corrupt")
	ErrLockedToKey   = errors.New("locked-to-key")
	ErrNotAge        = errors.New("not-age")
	ErrNeedsMemory   = errors.New("needs-memory")
	ErrCancelled     = errors.New("cancelled")
	ErrEmptyPassword = errors.New("empty-password")
	ErrIO            = errors.New("io")
)

const (
	intro       = "age-encryption.org/v1\n"
	armorIntro  = "-----BEGIN AGE ENCRYPTED FILE-----"
	headerPeek  = 16 * 1024
	workFactor  = 18
	maxFactor   = 22
	memHeadroom = 96 << 20
)

var scryptLine = regexp.MustCompile(`(?m)^-> scrypt \S+ (\d{1,2})$`)
var stanzaLine = regexp.MustCompile(`(?m)^-> (\S+)`)

// what scrypt at this work factor allocates: 128 * N * r bytes, r = 8
func scryptBytes(logN int) int64 { return int64(1) << uint(logN+10) }

type counter struct {
	n      *int64
	cancel *int32
}

func (c counter) tick(n int) error {
	if c.n != nil {
		atomic.AddInt64(c.n, int64(n))
	}
	if c.cancel != nil && atomic.LoadInt32(c.cancel) != 0 {
		return ErrCancelled
	}
	return nil
}

func pump(dst io.Writer, src io.Reader, c counter, readErr, writeErr error) error {
	buf := make([]byte, 256*1024)
	for {
		n, err := src.Read(buf)
		if n > 0 {
			if _, werr := dst.Write(buf[:n]); werr != nil {
				return writeErr
			}
			if cerr := c.tick(n); cerr != nil {
				return cerr
			}
		}
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return readErr
		}
	}
}

// Lock encrypts in to out. memAvail may be nil; when it is given and the
// phone cannot spare what scrypt needs, nothing is written.
func Lock(in io.Reader, out io.Writer, pass string, done *int64, cancel *int32, memAvail func() int64) error {
	if pass == "" {
		return ErrEmptyPassword
	}
	if memAvail != nil {
		if free := memAvail(); free > 0 && free < scryptBytes(workFactor)+memHeadroom {
			return ErrNeedsMemory
		}
	}
	r, err := age.NewScryptRecipient(pass)
	if err != nil {
		return ErrEmptyPassword
	}
	r.SetWorkFactor(workFactor)
	w, err := age.Encrypt(out, r)
	if err != nil {
		return ErrIO
	}
	if err := pump(w, in, counter{done, cancel}, ErrIO, ErrIO); err != nil {
		return err
	}
	if err := w.Close(); err != nil {
		return ErrIO
	}
	return nil
}

// Session is a file whose password has been checked and whose body has not
// been read yet, so a wrong password is known before anyone is asked where
// to save.
type Session struct {
	body io.Reader
}

func Begin(in io.Reader, pass string, memAvail func() int64) (*Session, error) {
	br := bufio.NewReaderSize(in, headerPeek)
	head, _ := br.Peek(len(armorIntro))
	var src io.Reader = br
	if bytes.Equal(head, []byte(armorIntro)) {
		src = armor.NewReader(br)
	}
	hr := bufio.NewReaderSize(src, headerPeek)
	peek, _ := hr.Peek(headerPeek)
	if !bytes.HasPrefix(peek, []byte(intro)) {
		return nil, ErrNotAge
	}
	header := peek
	if i := bytes.Index(peek, []byte("\n---")); i >= 0 {
		header = peek[:i+1]
	}
	if !stanzaLine.Match(header) {
		return nil, ErrCorrupt
	}
	m := scryptLine.FindSubmatch(header)
	if m == nil {
		return nil, ErrLockedToKey
	}
	logN, err := strconv.Atoi(string(m[1]))
	if err != nil || logN < 1 || logN > maxFactor {
		return nil, ErrNeedsMemory
	}
	if memAvail != nil {
		if free := memAvail(); free > 0 && free < scryptBytes(logN)+memHeadroom {
			return nil, ErrNeedsMemory
		}
	}
	if pass == "" {
		return nil, ErrWrongPassword
	}
	id, err := age.NewScryptIdentity(pass)
	if err != nil {
		return nil, ErrWrongPassword
	}
	id.SetMaxWorkFactor(logN)
	body, err := age.Decrypt(hr, id)
	if err != nil {
		var none *age.NoIdentityMatchError
		if errors.As(err, &none) {
			return nil, ErrWrongPassword
		}
		return nil, ErrCorrupt
	}
	return &Session{body: body}, nil
}

// Finish writes the opened file out. ErrCorrupt here means the file broke
// part way, and whatever was written before that is not to be kept.
func (s *Session) Finish(out io.Writer, done *int64, cancel *int32) error {
	return pump(out, s.body, counter{done, cancel}, ErrCorrupt, ErrIO)
}
