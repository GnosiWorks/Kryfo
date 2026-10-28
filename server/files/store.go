// SPDX-License-Identifier: GPL-3.0-or-later
package main

// where the sealed bytes are kept. the first store is this box's own disk.
// an s3 store fits the same calls when the disk gets tight or bigger files
// need it: parts are already s3 sized, seal is the multipart complete, and
// open hands back a seeker that reads by range. it is not built yet.

import (
	"errors"
	"io"
	"os"
	"path/filepath"
	"syscall"
)

type blobStore interface {
	// bytes the store has free, for the guard. an s3 store has no disk and
	// reports what is left of its quota
	free() (uint64, error)
	// part n of file id, at its place in the file
	writePart(id string, n int, b []byte) error
	// every part is in: the file is whole on durable storage
	seal(id string) error
	open(id string) (io.ReadSeekCloser, error)
	remove(id string) error
}

var errNoBlob = errors.New("no such file")

// one file per upload under dir, written in place part by part. nothing
// in the path but the random id
type diskStore struct{ dir string }

func newDiskStore(dir string) (*diskStore, error) {
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, err
	}
	return &diskStore{dir: dir}, nil
}

func (d *diskStore) path(id string) string { return filepath.Join(d.dir, id) }

func (d *diskStore) free() (uint64, error) {
	var st syscall.Statfs_t
	if err := syscall.Statfs(d.dir, &st); err != nil {
		return 0, err
	}
	return st.Bavail * uint64(st.Bsize), nil
}

func (d *diskStore) writePart(id string, n int, b []byte) error {
	f, err := os.OpenFile(d.path(id), os.O_WRONLY|os.O_CREATE, 0o600)
	if err != nil {
		return err
	}
	_, err = f.WriteAt(b, int64(n)*partSize)
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	return err
}

func (d *diskStore) seal(id string) error {
	f, err := os.OpenFile(d.path(id), os.O_WRONLY, 0)
	if err != nil {
		return err
	}
	err = f.Sync()
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	return err
}

func (d *diskStore) open(id string) (io.ReadSeekCloser, error) {
	f, err := os.Open(d.path(id))
	if errors.Is(err, os.ErrNotExist) {
		return nil, errNoBlob
	}
	return f, err
}

func (d *diskStore) remove(id string) error {
	err := os.Remove(d.path(id))
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	return err
}
