// SPDX-License-Identifier: GPL-3.0-or-later
package translate

import (
	"context"
	"io"
)

// a download's volume is padded up to a size class, so the bytes the guard
// counts name a class of languages, not one. small models fill the first
// class, base models the second; past that, whole steps of the second.
var PadClasses = []int64{48 << 20, 96 << 20}

// PadName is the mirror's padding file, PadSize bytes of noise: the most
// padding one bundle can need is under the largest class
const (
	PadName = "pad"
	PadSize = 96 << 20
)

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
	gz, _ := m.BundleBytes(lang)
	return PadTo(gz)
}

// fetchPad asks for n bytes of the padding file in chunks the size of the
// real ones and throws them away. it is not checked and cannot fail a
// download: the files are in place, and a mirror that cuts it short only
// shows the size it would have hidden.
func fetchPad(ctx context.Context, get Getter, url string, n int64, on func(int64)) {
	var done, off int64
	for done < n && ctx.Err() == nil {
		k := min(Chunk, n-done, PadSize-off)
		body, _, err := get(ctx, url, off, k)
		if err != nil {
			return
		}
		w, _ := io.Copy(io.Discard, io.LimitReader(body, k))
		body.Close()
		if w == 0 {
			return
		}
		done += w
		off = (off + w) % PadSize
		if on != nil {
			on(done)
		}
	}
}
