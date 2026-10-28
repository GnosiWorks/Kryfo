// SPDX-License-Identifier: GPL-3.0-or-later
package opus

import (
	"bufio"
	"crypto/rand"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"math"
	"os"
)

// what a voice note goes out as: speech, mono, 24 kbit/s
const (
	VoiceBitrate = 24000
	// libopus's own default; the encode is still far faster than the note
	voiceComplexity = 10
	// 20 ms, what speech codecs use and what rfc 7845 expects
	frameMs = 20
)

// the longest note either side reads, in seconds: the mic's 30 minutes
// and a little over
const maxNote = 31 * 60

// the least file a second of decoded audio needs, in bytes: 1 kbit/s. the
// encoder here never goes under about 3.8 kbit/s, even for silence, so
// only a stream made to claim long audio from a small file stops on it
const leastPerSec = 125

var (
	// ErrNotWav is input that is not 16-bit pcm wav
	ErrNotWav = errors.New("wav: not 16-bit pcm")
	// ErrRate is a wav at a rate libopus does not take as it is
	ErrRate = errors.New("wav: rate")
	// ErrEmpty is a note with no samples
	ErrEmpty = errors.New("voice: no samples")
	// ErrLong is a note longer than any the app records, or one that
	// claims far more audio than its file could hold
	ErrLong = errors.New("voice: too long")
	// ErrStopped is an encode asked to stop
	ErrStopped = errors.New("voice: stopped")
)

type wavHead struct {
	rate, channels int
	// bytes of samples, or -1 for the rest of the file
	size int64
}

// readWavHead reads up to the first sample, as the app's wav reader does:
// a data length of 0 or one past the end means the rest of the file
func readWavHead(r *bufio.Reader) (wavHead, error) {
	var h [12]byte
	if _, err := io.ReadFull(r, h[:]); err != nil {
		return wavHead{}, ErrNotWav
	}
	if string(h[:4]) != "RIFF" || string(h[8:]) != "WAVE" {
		return wavHead{}, ErrNotWav
	}
	var head wavHead
	bits := 0
	read := 12
	for read < 64*1024 {
		var c [8]byte
		if _, err := io.ReadFull(r, c[:]); err != nil {
			return wavHead{}, ErrNotWav
		}
		read += 8
		id := string(c[:4])
		n := int64(binary.LittleEndian.Uint32(c[4:]))
		switch id {
		case "fmt ":
			if n < 16 || n > 1024 {
				return wavHead{}, ErrNotWav
			}
			b := make([]byte, n+n&1)
			if _, err := io.ReadFull(r, b); err != nil {
				return wavHead{}, ErrNotWav
			}
			read += len(b)
			format := binary.LittleEndian.Uint16(b)
			if format != 1 && format != 0xFFFE {
				return wavHead{}, ErrNotWav
			}
			head.channels = int(binary.LittleEndian.Uint16(b[2:]))
			head.rate = int(binary.LittleEndian.Uint32(b[4:]))
			bits = int(binary.LittleEndian.Uint16(b[14:]))
		case "data":
			if bits != 16 || head.channels < 1 || head.channels > 2 {
				return wavHead{}, ErrNotWav
			}
			if !RateOK(head.rate) {
				return wavHead{}, ErrRate
			}
			head.size = n
			if n == 0 || n == 0xFFFFFFFF {
				head.size = -1
			}
			return head, nil
		default:
			skip := n + n&1
			if skip > 64*1024 {
				return wavHead{}, ErrNotWav
			}
			if _, err := r.Discard(int(skip)); err != nil {
				return wavHead{}, ErrNotWav
			}
			read += int(skip)
		}
	}
	return wavHead{}, ErrNotWav
}

// Note is what was written or read
type Note struct {
	// samples at the wav's rate, without the encoder's delay or padding
	Samples int
	Rate    int
	Bytes   int64
}

// Ms is how long the note plays
func (n Note) Ms() int {
	if n.Rate == 0 {
		return 0
	}
	return int(int64(n.Samples) * 1000 / int64(n.Rate))
}

type counter struct {
	w io.Writer
	n int64
}

func (c *counter) Write(b []byte) (int, error) {
	n, err := c.w.Write(b)
	c.n += int64(n)
	return n, err
}

// EncodeWav writes the 16-bit pcm wav in [in] to [out] as ogg opus. a
// stereo wav is mixed down to mono
func EncodeWav(in io.Reader, out io.Writer) (Note, error) {
	return EncodeWavStop(in, out, nil)
}

// how often, in frames, an encode asks whether it should stop: a second
const stopEvery = 50

// EncodeWavStop is [EncodeWav] that gives up with ErrStopped once [stop]
// says so. nil never stops
func EncodeWavStop(in io.Reader, out io.Writer, stop func() bool) (Note, error) {
	r := bufio.NewReaderSize(in, 64*1024)
	head, err := readWavHead(r)
	if err != nil {
		return Note{}, err
	}
	enc, err := NewEncoder(head.rate, VoiceBitrate, voiceComplexity)
	if err != nil {
		return Note{}, err
	}
	defer enc.Close()
	look := enc.Lookahead()
	if look < 0 {
		return Note{}, errors.New("opus: no lookahead")
	}
	up := uint64(48000 / head.rate)
	preskip := uint64(look) * up

	var serial [4]byte
	if _, err := rand.Read(serial[:]); err != nil {
		return Note{}, err
	}
	cw := &counter{w: out}
	bw := bufio.NewWriterSize(cw, 32*1024)
	o := &oggWriter{w: bw, serial: binary.LittleEndian.Uint32(serial[:])}

	// OpusHead: version 1, one channel, family 0
	oh := make([]byte, 19)
	copy(oh, "OpusHead")
	oh[8] = 1
	oh[9] = 1
	binary.LittleEndian.PutUint16(oh[10:], uint16(preskip))
	binary.LittleEndian.PutUint32(oh[12:], uint32(head.rate))
	if err := o.header(oh); err != nil {
		return Note{}, err
	}
	// OpusTags with an empty vendor and no comments: nothing of the phone
	// or the encoder rides in the file
	tags := make([]byte, 16)
	copy(tags, "OpusTags")
	if err := o.header(tags); err != nil {
		return Note{}, err
	}

	frame := head.rate * frameMs / 1000
	ch := head.channels
	raw := make([]byte, frame*2*ch)
	pcm := make([]int16, frame)
	left := head.size
	most := int64(maxNote) * int64(head.rate)
	var n int64
	eof := false
	for k := uint64(1); ; k++ {
		if stop != nil && k%stopEvery == 1 && stop() {
			return Note{}, ErrStopped
		}
		got := 0
		if !eof {
			want := len(raw)
			if left >= 0 && int64(want) > left {
				want = int(left - left%int64(2*ch))
			}
			m, err := io.ReadFull(r, raw[:want])
			if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
				return Note{}, err
			}
			if left >= 0 {
				left -= int64(m)
			}
			got = m / (2 * ch)
			if m < len(raw) {
				eof = true
			}
		}
		for i := range got {
			if ch == 1 {
				pcm[i] = int16(binary.LittleEndian.Uint16(raw[2*i:]))
				continue
			}
			a := int32(int16(binary.LittleEndian.Uint16(raw[4*i:])))
			b := int32(int16(binary.LittleEndian.Uint16(raw[4*i+2:])))
			pcm[i] = int16((a + b) / 2)
		}
		clear(pcm[got:])
		n += int64(got)
		if n > most {
			return Note{}, ErrLong
		}
		if eof && n == 0 {
			return Note{}, ErrEmpty
		}
		p, err := enc.Encode(pcm)
		if err != nil {
			return Note{}, err
		}
		// done once the encoder's delay is played out past the last sample
		last := eof && int64(k)*int64(frame) >= n+int64(look)
		g := k * uint64(frame) * up
		if last {
			g = preskip + uint64(n)*up
		}
		if err := o.add(p, g); err != nil {
			return Note{}, err
		}
		if last {
			break
		}
	}
	if err := o.flush(true); err != nil {
		return Note{}, err
	}
	if err := bw.Flush(); err != nil {
		return Note{}, err
	}
	return Note{Samples: int(n), Rate: head.rate, Bytes: cw.n}, nil
}

// Decode reads the ogg opus in [in] and hands [sink] its samples at
// [rate], without the encoder's delay. the note it returns has the
// samples the stream says it holds, which can be fewer than [sink] was
// given: the padding of the last frame
func Decode(in io.Reader, rate int, sink func([]int16) error) (Note, error) {
	o := &oggReader{r: bufio.NewReaderSize(in, 64*1024)}
	if err := o.page(); err != nil {
		return Note{}, ErrNotOpus
	}
	head, err := o.next()
	if err != nil || len(head) < 19 || string(head[:8]) != "OpusHead" || head[8]>>4 != 0 {
		return Note{}, ErrNotOpus
	}
	if ch := head[9]; ch < 1 || ch > 2 || head[18] != 0 {
		return Note{}, ErrNotOpus
	}
	preskip := uint64(binary.LittleEndian.Uint16(head[10:]))
	tags, err := o.next()
	if err != nil || len(tags) < 8 || string(tags[:8]) != "OpusTags" {
		return Note{}, ErrNotOpus
	}
	dec, err := NewDecoder(rate)
	if err != nil {
		return Note{}, err
	}
	defer dec.Close()
	down := uint64(48000 / rate)
	skip := int(preskip / down)
	most := int64(maxNote) * int64(rate)
	given := int64(0)
	var granule uint64
	for {
		p, err := o.next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return Note{}, err
		}
		granule = o.granule
		pcm, err := dec.Decode(p)
		if err != nil {
			return Note{}, err
		}
		if skip > 0 {
			cut := min(skip, len(pcm))
			pcm, skip = pcm[cut:], skip-cut
		}
		given += int64(len(pcm))
		// a second's grace, then no more audio than its bytes could carry
		if given > most || given > o.read*int64(rate)/leastPerSec+int64(rate) {
			return Note{}, ErrLong
		}
		if len(pcm) > 0 {
			if err := sink(pcm); err != nil {
				return Note{}, err
			}
		}
	}
	samples := noteSamples(given, granule, preskip, down)
	if samples <= 0 {
		return Note{}, ErrEmpty
	}
	return Note{Samples: int(samples), Rate: rate}, nil
}

// the samples a stream says it holds, never more than [given] were
// decoded. in uint64 first: on a 32-bit phone a granule made up past what
// int holds would turn negative
func noteSamples(given int64, granule, preskip, down uint64) int64 {
	if granule < preskip || given <= 0 {
		return given
	}
	if s := (granule - preskip) / down; s < uint64(given) {
		return int64(s)
	}
	return given
}

// the rate notes are decoded at for their wave and for transcripts
const DecodeRate = 16000

// Peaks is a note's loudness in [bars] steps, 0 to 1 against its own
// loudest with a square root on top, as the app draws a wav's
func Peaks(in io.Reader, bars int) ([]float64, Note, error) {
	if bars < 1 || bars > 1000 {
		return nil, Note{}, fmt.Errorf("peaks: %d bars", bars)
	}
	const block = DecodeRate * frameMs / 1000
	var sums []float64
	var counts []int
	fill := 0
	note, err := Decode(in, DecodeRate, func(pcm []int16) error {
		for _, s := range pcm {
			if fill == 0 {
				sums = append(sums, 0)
				counts = append(counts, 0)
			}
			v := float64(s) / 32768
			sums[len(sums)-1] += v * v
			counts[len(counts)-1]++
			fill = (fill + 1) % block
		}
		return nil
	})
	if err != nil {
		return nil, Note{}, err
	}
	// the padding past the last sample is no part of the wave
	keep := max((note.Samples+block-1)/block, 0)
	sums, counts = sums[:min(keep, len(sums))], counts[:min(keep, len(counts))]
	out := make([]float64, bars)
	frames := len(sums)
	for i := range bars {
		from := frames * i / bars
		to := max(from+1, frames*(i+1)/bars)
		var s float64
		var c int
		for f := from; f < to && f < frames; f++ {
			s += sums[f]
			c += counts[f]
		}
		if c > 0 {
			out[i] = math.Sqrt(s / float64(c))
		}
	}
	top := 0.0
	for _, v := range out {
		top = max(top, v)
	}
	if top > 0 {
		for i, v := range out {
			out[i] = math.Sqrt(v / top)
		}
	}
	return out, note, nil
}

// EncodeFile writes the wav at [in] to [out] as ogg opus. nothing is left
// at [out] when it fails
func EncodeFile(in, out string, stop func() bool) (Note, error) {
	f, err := os.Open(in)
	if err != nil {
		return Note{}, err
	}
	defer f.Close()
	return writeFile(out, func(w io.Writer) (Note, error) { return EncodeWavStop(f, w, stop) })
}

// DecodeFile writes the ogg opus at [in] to [out] as 16 khz 16-bit mono
// wav, the shape the mic records. nothing is left at [out] when it fails
func DecodeFile(in, out string) (Note, error) {
	f, err := os.Open(in)
	if err != nil {
		return Note{}, err
	}
	defer f.Close()
	return writeFile(out, func(w io.Writer) (Note, error) {
		ws, ok := w.(io.WriteSeeker)
		if !ok {
			return Note{}, errors.New("wav: needs a file")
		}
		if _, err := ws.Write(make([]byte, 44)); err != nil {
			return Note{}, err
		}
		bw := bufio.NewWriterSize(ws, 32*1024)
		b := make([]byte, 0, 2*maxFrame)
		total := 0
		note, err := Decode(f, DecodeRate, func(pcm []int16) error {
			b = b[:0]
			for _, s := range pcm {
				b = binary.LittleEndian.AppendUint16(b, uint16(s))
			}
			total += len(pcm)
			_, err := bw.Write(b)
			return err
		})
		if err != nil {
			return Note{}, err
		}
		if err := bw.Flush(); err != nil {
			return Note{}, err
		}
		size := int64(note.Samples) * 2
		if f, ok := w.(*os.File); ok && note.Samples < total {
			if err := f.Truncate(44 + size); err != nil {
				return Note{}, err
			}
		}
		if _, err := ws.Seek(0, io.SeekStart); err != nil {
			return Note{}, err
		}
		if _, err := ws.Write(WavHead(DecodeRate, note.Samples)); err != nil {
			return Note{}, err
		}
		note.Bytes = 44 + size
		return note, nil
	})
}

// WavHead is the 44-byte head of a 16-bit mono wav of [samples] at [rate]
func WavHead(rate, samples int) []byte {
	size := uint32(samples * 2)
	h := make([]byte, 44)
	copy(h, "RIFF")
	binary.LittleEndian.PutUint32(h[4:], 36+size)
	copy(h[8:], "WAVEfmt ")
	binary.LittleEndian.PutUint32(h[16:], 16)
	binary.LittleEndian.PutUint16(h[20:], 1)
	binary.LittleEndian.PutUint16(h[22:], 1)
	binary.LittleEndian.PutUint32(h[24:], uint32(rate))
	binary.LittleEndian.PutUint32(h[28:], uint32(rate*2))
	binary.LittleEndian.PutUint16(h[32:], 2)
	binary.LittleEndian.PutUint16(h[34:], 16)
	copy(h[36:], "data")
	binary.LittleEndian.PutUint32(h[40:], size)
	return h
}

func writeFile(out string, write func(io.Writer) (Note, error)) (Note, error) {
	f, err := os.OpenFile(out, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o600)
	if err != nil {
		return Note{}, err
	}
	note, err := write(f)
	if err == nil {
		err = f.Sync()
	}
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		shredOut(out)
		return Note{}, err
	}
	return note, nil
}

// what a failed write left is zeroed before it goes: speech half encoded
// or decoded stays nowhere on the disk
func shredOut(out string) {
	if f, err := os.OpenFile(out, os.O_WRONLY, 0); err == nil {
		if st, err := f.Stat(); err == nil {
			zero := make([]byte, 64*1024)
			for at := int64(0); at < st.Size(); at += int64(len(zero)) {
				n := min(int64(len(zero)), st.Size()-at)
				if _, err := f.WriteAt(zero[:n], at); err != nil {
					break
				}
			}
			f.Sync()
		}
		f.Close()
	}
	os.Remove(out)
}

// PeaksFile is [Peaks] of the ogg opus at [path]
func PeaksFile(path string, bars int) ([]float64, Note, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, Note{}, err
	}
	defer f.Close()
	return Peaks(f, bars)
}
