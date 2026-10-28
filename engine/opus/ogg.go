// SPDX-License-Identifier: GPL-3.0-or-later
package opus

import (
	"bufio"
	"bytes"
	"encoding/binary"
	"errors"
	"io"
)

// ogg pages as rfc 3533 has them, holding one opus stream (rfc 7845)

var oggCRC = func() (t [256]uint32) {
	for i := range t {
		r := uint32(i) << 24
		for range 8 {
			if r&0x80000000 != 0 {
				r = r<<1 ^ 0x04c11db7
			} else {
				r <<= 1
			}
		}
		t[i] = r
	}
	return
}()

func crcOf(b []byte) uint32 {
	var c uint32
	for _, x := range b {
		c = c<<8 ^ oggCRC[byte(c>>24)^x]
	}
	return c
}

const (
	pageCont = 0x01
	pageBOS  = 0x02
	pageEOS  = 0x04
	// what one page may hold: lacing values and a second of 20 ms packets
	pageSegs    = 255
	pagePackets = 50
)

type oggWriter struct {
	w       io.Writer
	serial  uint32
	seq     uint32
	segs    []byte
	body    []byte
	packets int
	granule uint64
	started bool
}

// add puts one packet on the page being filled; [granule] is the stream's
// position once it has played
func (o *oggWriter) add(p []byte, granule uint64) error {
	need := len(p)/255 + 1
	if len(o.segs)+need > pageSegs || o.packets >= pagePackets {
		if err := o.flush(false); err != nil {
			return err
		}
	}
	if need > pageSegs {
		return errors.New("ogg: packet too big")
	}
	for n := len(p); ; n -= 255 {
		if n < 255 {
			o.segs = append(o.segs, byte(n))
			break
		}
		o.segs = append(o.segs, 255)
	}
	o.body = append(o.body, p...)
	o.packets++
	o.granule = granule
	return nil
}

func (o *oggWriter) flush(last bool) error {
	if len(o.segs) == 0 && !last {
		return nil
	}
	var flags byte
	if !o.started {
		flags |= pageBOS
	}
	if last {
		flags |= pageEOS
	}
	h := make([]byte, 27, 27+len(o.segs)+len(o.body))
	copy(h, "OggS")
	h[5] = flags
	binary.LittleEndian.PutUint64(h[6:], o.granule)
	binary.LittleEndian.PutUint32(h[14:], o.serial)
	binary.LittleEndian.PutUint32(h[18:], o.seq)
	h[26] = byte(len(o.segs))
	page := append(append(h, o.segs...), o.body...)
	binary.LittleEndian.PutUint32(page[22:], crcOf(page))
	o.seq++
	o.started = true
	o.segs, o.body, o.packets = o.segs[:0], o.body[:0], 0
	_, err := o.w.Write(page)
	return err
}

// a header packet goes on a page of its own, as rfc 7845 asks
func (o *oggWriter) header(p []byte) error {
	if err := o.add(p, 0); err != nil {
		return err
	}
	return o.flush(false)
}

// ErrNotOpus is a file that is not one ogg opus stream
var ErrNotOpus = errors.New("ogg: not opus")

// the most a packet may grow to across pages, far past any opus packet
const maxPacketRead = 64 * 1024

type oggReader struct {
	r       *bufio.Reader
	serial  uint32
	known   bool
	packet  []byte
	segs    []byte
	body    []byte
	at      int
	seg     int
	granule uint64
	last    bool
	// the bytes of the pages read so far
	read int64
}

// page reads the next page, skipping any of another stream
func (o *oggReader) page() error {
	var h [27]byte
	for {
		if _, err := io.ReadFull(o.r, h[:]); err != nil {
			if err == io.EOF {
				return io.EOF
			}
			return ErrNotOpus
		}
		if !bytes.Equal(h[:4], []byte("OggS")) || h[4] != 0 {
			return ErrNotOpus
		}
		n := int(h[26])
		segs := make([]byte, n)
		if _, err := io.ReadFull(o.r, segs); err != nil {
			return ErrNotOpus
		}
		size := 0
		for _, s := range segs {
			size += int(s)
		}
		body := make([]byte, size)
		if _, err := io.ReadFull(o.r, body); err != nil {
			return ErrNotOpus
		}
		want := binary.LittleEndian.Uint32(h[22:])
		page := append(append(append([]byte{}, h[:]...), segs...), body...)
		binary.LittleEndian.PutUint32(page[22:], 0)
		if crcOf(page) != want {
			return ErrNotOpus
		}
		serial := binary.LittleEndian.Uint32(h[14:])
		if !o.known {
			if h[5]&pageBOS == 0 {
				return ErrNotOpus
			}
			o.serial, o.known = serial, true
		} else if serial != o.serial {
			continue
		}
		o.read += int64(27 + n + size)
		o.segs, o.body, o.seg, o.at = segs, body, 0, 0
		o.granule = binary.LittleEndian.Uint64(h[6:])
		o.last = h[5]&pageEOS != 0
		return nil
	}
}

// next is the next whole packet. o.granule is then the granule of the page
// it ended on
func (o *oggReader) next() ([]byte, error) {
	o.packet = o.packet[:0]
	for {
		for o.seg < len(o.segs) {
			n := int(o.segs[o.seg])
			o.seg++
			o.packet = append(o.packet, o.body[o.at:o.at+n]...)
			o.at += n
			if len(o.packet) > maxPacketRead {
				return nil, ErrNotOpus
			}
			if n < 255 {
				return o.packet, nil
			}
		}
		if o.last {
			return nil, io.EOF
		}
		if err := o.page(); err != nil {
			if err == io.EOF && len(o.packet) > 0 {
				return nil, ErrNotOpus
			}
			return nil, err
		}
	}
}
