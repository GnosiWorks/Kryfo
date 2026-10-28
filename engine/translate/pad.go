// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"crypto/sha256"
	"encoding/binary"
	"io"
)

// a download's volume is padded up to a size class, so the bytes the guard
// counts name a class of languages, not one. small models fill the first
// class, base models the second; past that, whole steps of the second.
// every class is a whole number of Chunks.
var PadClasses = []int64{48 << 20, 96 << 20}

// PadTo is what a bundle of gz bytes costs on the wire once padded.
func PadTo(gz int64) int64 {
	if gz <= 0 {
		return 0
	}
	for _, c := range PadClasses {
		if gz <= c {
			return c
		}
	}
	step := PadClasses[len(PadClasses)-1]
	return (gz + step - 1) / step * step
}

// WireBytes is what fetching lang's bundle from the mirror costs.
func (m *Manifest) WireBytes(lang string) int64 {
	_, gz := m.bundleFiles(lang)
	return PadTo(gz)
}

// writeNoise writes n bytes of the bundle's padding: sha256 in counter
// mode over its id, so anyone filling a mirror makes the same file. the app
// never reads it, it only has to be there and not shrink on the way
func writeNoise(w io.Writer, id string, n int64) error {
	var ctr [8]byte
	for i := uint64(0); n > 0; i++ {
		binary.BigEndian.PutUint64(ctr[:], i)
		h := sha256.Sum256(append([]byte(id), ctr[:]...))
		k := min(int64(len(h)), n)
		if _, err := w.Write(h[:k]); err != nil {
			return err
		}
		n -= k
	}
	return nil
}
