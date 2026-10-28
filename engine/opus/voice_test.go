// SPDX-License-Identifier: GPL-3.0-or-later
package opus

import (
	"bufio"
	"bytes"
	"encoding/binary"
	"errors"
	"io"
	"math"
	"math/rand/v2"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// something like speech: a voiced buzz whose pitch and loudness move, in
// words with pauses between them, over a little room noise
func speech(secs float64, rate int) []int16 {
	n := int(secs * float64(rate))
	r := rand.New(rand.NewPCG(1, 2))
	out := make([]int16, n)
	phase := 0.0
	for i := range n {
		t := float64(i) / float64(rate)
		f0 := 140 + 40*math.Sin(2*math.Pi*0.7*t)
		phase += 2 * math.Pi * f0 / float64(rate)
		v := 0.0
		for h := 1; h <= 12; h++ {
			v += math.Sin(float64(h)*phase) / float64(h)
		}
		word := math.Mod(t, 0.9)
		env := 0.0
		if word < 0.6 {
			env = math.Sin(math.Pi * word / 0.6)
		}
		s := 7000*env*v + 120*r.NormFloat64()
		out[i] = int16(max(-32768, min(32767, s)))
	}
	return out
}

func wavOf(pcm []int16, rate, channels int) []byte {
	var b bytes.Buffer
	h := WavHead(rate, len(pcm)/channels)
	binary.LittleEndian.PutUint16(h[22:], uint16(channels))
	binary.LittleEndian.PutUint32(h[28:], uint32(rate*2*channels))
	binary.LittleEndian.PutUint16(h[32:], uint16(2*channels))
	binary.LittleEndian.PutUint32(h[40:], uint32(len(pcm)*2))
	binary.LittleEndian.PutUint32(h[4:], uint32(36+len(pcm)*2))
	b.Write(h)
	for _, s := range pcm {
		binary.Write(&b, binary.LittleEndian, s)
	}
	return b.Bytes()
}

func encode(t *testing.T, wav []byte) ([]byte, Note) {
	t.Helper()
	var out bytes.Buffer
	note, err := EncodeWav(bytes.NewReader(wav), &out)
	if err != nil {
		t.Fatalf("encode: %v", err)
	}
	if note.Bytes != int64(out.Len()) {
		t.Fatalf("note says %d bytes, wrote %d", note.Bytes, out.Len())
	}
	return out.Bytes(), note
}

func decode(t *testing.T, ogg []byte) ([]int16, Note) {
	t.Helper()
	var pcm []int16
	note, err := Decode(bytes.NewReader(ogg), DecodeRate, func(p []int16) error {
		pcm = append(pcm, p...)
		return nil
	})
	if err != nil {
		t.Fatalf("decode: %v", err)
	}
	return pcm[:note.Samples], note
}

func rms(p []int16) float64 {
	s := 0.0
	for _, v := range p {
		s += float64(v) * float64(v)
	}
	return math.Sqrt(s / float64(max(1, len(p))))
}

func TestRoundTrip(t *testing.T) {
	src := speech(42, 16000)
	ogg, note := encode(t, wavOf(src, 16000, 1))
	if note.Samples != len(src) || note.Ms() != 42000 {
		t.Fatalf("note %+v", note)
	}
	// a 42 s note: 1.3 mb as wav, under 160 kb as opus
	if len(ogg) > 160*1024 {
		t.Fatalf("42 s is %d bytes", len(ogg))
	}
	if len(ogg) < 60*1024 {
		t.Fatalf("42 s is only %d bytes: not 24 kbit/s", len(ogg))
	}
	got, back := decode(t, ogg)
	if len(got) != len(src) || back.Ms() != 42000 {
		t.Fatalf("decoded %d samples, %d ms", len(got), back.Ms())
	}
	// lossy, but the same sound in the same place: each 100 ms keeps its
	// loudness, silence stays silent
	for at := 0; at+1600 <= len(src); at += 1600 {
		a, b := rms(src[at:at+1600]), rms(got[at:at+1600])
		if math.Abs(a-b) > 0.25*a+300 {
			t.Fatalf("at %d ms: %0.f against %0.f", at/16, a, b)
		}
	}
}

func TestPagesFollowTheSpec(t *testing.T) {
	src := speech(3.3, 16000)
	ogg, _ := encode(t, wavOf(src, 16000, 1))
	o := &oggReader{r: bufio.NewReader(bytes.NewReader(ogg))}
	var flags []byte
	var granules []uint64
	for at := 0; at < len(ogg); {
		if string(ogg[at:at+4]) != "OggS" {
			t.Fatalf("no page at %d", at)
		}
		flags = append(flags, ogg[at+5])
		granules = append(granules, binary.LittleEndian.Uint64(ogg[at+6:]))
		n := int(ogg[at+26])
		size := 0
		for _, s := range ogg[at+27 : at+27+n] {
			size += int(s)
		}
		at += 27 + n + size
	}
	if flags[0] != pageBOS || flags[len(flags)-1] != pageEOS {
		t.Fatalf("flags %v", flags)
	}
	if granules[0] != 0 || granules[1] != 0 {
		t.Fatalf("headers carry granules %v", granules[:2])
	}
	if err := o.page(); err != nil {
		t.Fatal(err)
	}
	head, _ := o.next()
	preskip := uint64(binary.LittleEndian.Uint16(head[10:]))
	if got := binary.LittleEndian.Uint32(head[12:]); got != 16000 {
		t.Fatalf("input rate %d", got)
	}
	tags, _ := o.next()
	if !bytes.Equal(tags, []byte("OpusTags\x00\x00\x00\x00\x00\x00\x00\x00")) {
		t.Fatalf("tags carry %q", tags)
	}
	last := granules[len(granules)-1]
	if last != preskip+uint64(len(src))*3 {
		t.Fatalf("last granule %d, want %d", last, preskip+uint64(len(src))*3)
	}
	for i := 1; i < len(granules); i++ {
		if granules[i] < granules[i-1] {
			t.Fatalf("granules go back: %v", granules)
		}
	}
}

func TestOtherRatesAndStereo(t *testing.T) {
	for _, rate := range []int{8000, 12000, 24000, 48000} {
		src := speech(1, rate)
		ogg, note := encode(t, wavOf(src, rate, 1))
		if note.Rate != rate || note.Samples != len(src) {
			t.Fatalf("%d: %+v", rate, note)
		}
		if _, back := decode(t, ogg); back.Ms() != 1000 {
			t.Fatalf("%d: back %d ms", rate, back.Ms())
		}
	}
	mono := speech(1, 16000)
	st := make([]int16, 0, 2*len(mono))
	for _, s := range mono {
		st = append(st, s, s)
	}
	ogg, note := encode(t, wavOf(st, 16000, 2))
	if note.Samples != len(mono) {
		t.Fatalf("stereo: %+v", note)
	}
	got, _ := decode(t, ogg)
	if a, b := rms(mono), rms(got); math.Abs(a-b) > 0.2*a {
		t.Fatalf("stereo mixed down to %0.f, want about %0.f", b, a)
	}
}

func TestWavTheMicLeftOpen(t *testing.T) {
	src := speech(2, 16000)
	wav := wavOf(src, 16000, 1)
	// a recorder stopped hard never writes the lengths
	binary.LittleEndian.PutUint32(wav[40:], 0)
	_, note := encode(t, wav)
	if note.Samples != len(src) {
		t.Fatalf("open wav: %d samples, want %d", note.Samples, len(src))
	}
	// a length past the end is the rest of the file
	binary.LittleEndian.PutUint32(wav[40:], 1<<30)
	if _, note = encode(t, wav); note.Samples != len(src) {
		t.Fatalf("long length: %d samples", note.Samples)
	}
	// a length short of the end stops there
	binary.LittleEndian.PutUint32(wav[40:], 16000*2)
	if _, note = encode(t, wav); note.Samples != 16000 {
		t.Fatalf("short length: %d samples", note.Samples)
	}
}

func TestWhatIsNotTaken(t *testing.T) {
	src := wavOf(speech(1, 16000), 16000, 1)
	cases := map[string]struct {
		wav  []byte
		want error
	}{
		"empty":   {nil, ErrNotWav},
		"text":    {[]byte("RIFF....WAVEnot a wav at all"), ErrNotWav},
		"no data": {src[:36], ErrNotWav},
		"silence": {src[:44], ErrEmpty},
	}
	b8 := bytes.Clone(src)
	binary.LittleEndian.PutUint16(b8[34:], 8)
	cases["8-bit"] = struct {
		wav  []byte
		want error
	}{b8, ErrNotWav}
	r44 := bytes.Clone(src)
	binary.LittleEndian.PutUint32(r44[24:], 44100)
	cases["44.1 khz"] = struct {
		wav  []byte
		want error
	}{r44, ErrRate}
	float := bytes.Clone(src)
	binary.LittleEndian.PutUint16(float[20:], 3)
	cases["float"] = struct {
		wav  []byte
		want error
	}{float, ErrNotWav}
	for name, c := range cases {
		_, err := EncodeWav(bytes.NewReader(c.wav), io.Discard)
		if !errors.Is(err, c.want) {
			t.Errorf("%s: %v, want %v", name, err, c.want)
		}
	}
}

func TestDecodeRefusesWhatIsNotOpus(t *testing.T) {
	ogg, _ := encode(t, wavOf(speech(2, 16000), 16000, 1))
	bad := bytes.Clone(ogg)
	bad[len(bad)/2] ^= 0x40
	sink := func([]int16) error { return nil }
	for name, b := range map[string][]byte{
		"empty":     nil,
		"wav":       wavOf(speech(1, 16000), 16000, 1),
		"cut":       ogg[:len(ogg)/2+3],
		"crc":       bad,
		"head only": ogg[:47],
	} {
		if _, err := Decode(bytes.NewReader(b), DecodeRate, sink); err == nil {
			t.Errorf("%s: decoded", name)
		}
	}
}

func TestPeaksFollowTheSound(t *testing.T) {
	// a second of tone, a second of silence, a second of quieter tone
	pcm := make([]int16, 48000)
	for i := range pcm {
		a := 0.0
		switch {
		case i < 16000:
			a = 12000
		case i >= 32000:
			a = 3000
		}
		pcm[i] = int16(a * math.Sin(2*math.Pi*300*float64(i)/16000))
	}
	ogg, _ := encode(t, wavOf(pcm, 16000, 1))
	p, note, err := Peaks(bytes.NewReader(ogg), 30)
	if err != nil || len(p) != 30 || note.Ms() != 3000 {
		t.Fatalf("peaks %v %+v %v", p, note, err)
	}
	if p[4] < 0.9 || p[15] > 0.2 || p[25] < 0.35 || p[25] > 0.75 {
		t.Fatalf("peaks %v", p)
	}
	if _, _, err := Peaks(bytes.NewReader(ogg), 0); err == nil {
		t.Fatal("no bars taken")
	}
}

func TestFiles(t *testing.T) {
	dir := t.TempDir()
	in := filepath.Join(dir, "vn_1.wav")
	src := speech(5, 16000)
	if err := os.WriteFile(in, wavOf(src, 16000, 1), 0o600); err != nil {
		t.Fatal(err)
	}
	ogg := filepath.Join(dir, "vn_1.ogg")
	note, err := EncodeFile(in, ogg, nil)
	if err != nil || note.Ms() != 5000 {
		t.Fatalf("%+v %v", note, err)
	}
	back := filepath.Join(dir, "back.wav")
	if note, err = DecodeFile(ogg, back); err != nil || note.Samples != len(src) {
		t.Fatalf("%+v %v", note, err)
	}
	b, _ := os.ReadFile(back)
	if len(b) != 44+2*len(src) || !bytes.Equal(b[:44], WavHead(16000, len(src))) {
		t.Fatalf("wav of %d bytes, head %x", len(b), b[:44])
	}
	// what fails leaves nothing behind
	if _, err := EncodeFile(filepath.Join(dir, "none.wav"), filepath.Join(dir, "x.ogg"), nil); err == nil {
		t.Fatal("encoded nothing")
	}
	if _, err := EncodeFile(ogg, filepath.Join(dir, "y.ogg"), nil); err == nil {
		t.Fatal("encoded an ogg")
	}
	if _, err := DecodeFile(in, filepath.Join(dir, "z.wav")); err == nil {
		t.Fatal("decoded a wav")
	}
	for _, n := range []string{"x.ogg", "y.ogg", "z.wav"} {
		if _, err := os.Stat(filepath.Join(dir, n)); err == nil {
			t.Fatalf("%s left behind", n)
		}
	}
}

// the notes recorded on phones, when KRYFO_VOICE_SAMPLES names their folder
func TestRealNotes(t *testing.T) {
	dir := os.Getenv("KRYFO_VOICE_SAMPLES")
	if dir == "" {
		t.Skip("KRYFO_VOICE_SAMPLES not set")
	}
	names, _ := filepath.Glob(filepath.Join(dir, "*.wav"))
	if len(names) == 0 {
		t.Fatal("no samples")
	}
	for _, n := range names {
		wav, err := os.ReadFile(n)
		if err != nil {
			t.Fatal(err)
		}
		ogg, note := encode(t, wav)
		_, back := decode(t, ogg)
		if back.Samples != note.Samples {
			t.Fatalf("%s: %d samples back of %d", n, back.Samples, note.Samples)
		}
		kbps := float64(len(ogg)) * 8 / float64(note.Ms())
		t.Logf("%s: %d ms, wav %d bytes, ogg %d bytes (%.1f kbit/s)",
			strings.TrimPrefix(n, dir+"/"), note.Ms(), len(wav), len(ogg), kbps)
		if kbps > 32 {
			t.Fatalf("%s: %.1f kbit/s", n, kbps)
		}
	}
}

func FuzzDecode(f *testing.F) {
	var ogg bytes.Buffer
	if _, err := EncodeWav(bytes.NewReader(wavOf(speech(0.5, 16000), 16000, 1)), &ogg); err != nil {
		f.Fatal(err)
	}
	f.Add(ogg.Bytes())
	f.Add([]byte("OggS"))
	f.Fuzz(func(t *testing.T, b []byte) {
		Decode(bytes.NewReader(b), DecodeRate, func([]int16) error { return nil })
		Peaks(bytes.NewReader(b), 30)
	})
}

// the last page of [ogg] given [granule], its crc made again
func withLastGranule(t *testing.T, ogg []byte, granule uint64) []byte {
	t.Helper()
	b := bytes.Clone(ogg)
	last := bytes.LastIndex(b, []byte("OggS"))
	binary.LittleEndian.PutUint64(b[last+6:], granule)
	binary.LittleEndian.PutUint32(b[last+22:], 0)
	binary.LittleEndian.PutUint32(b[last+22:], crcOf(b[last:]))
	return b
}

func TestAGranulePastWhatIntHolds(t *testing.T) {
	ogg, _ := encode(t, wavOf(speech(2, 16000), 16000, 1))
	preskip := uint64(binary.LittleEndian.Uint16(ogg[28+10:]))
	for _, g := range []uint64{3<<31 + preskip, 1<<63 + preskip, ^uint64(0)} {
		b := withLastGranule(t, ogg, g)
		got, note := decode(t, b)
		if note.Samples <= 0 || note.Samples > 32000+16000 || len(got) != note.Samples {
			t.Fatalf("granule %d: %d samples", g, note.Samples)
		}
		p, n, err := Peaks(bytes.NewReader(b), 30)
		if err != nil || len(p) != 30 || n.Samples != note.Samples {
			t.Fatalf("granule %d: peaks %v %+v %v", g, p, n, err)
		}
	}
	// the clamp itself, as a 32-bit phone runs it: what comes out always
	// fits an int32 and is never more than was decoded
	for _, c := range []struct{ given, granule, preskip uint64 }{
		{32000, 3<<31 + 312, 312},
		{32000, 1<<63 + 312, 312},
		{32000, ^uint64(0), 312},
		{32000, 100, 312},
		{32000, 312 + 3*16000, 312},
	} {
		got := noteSamples(int64(c.given), c.granule, c.preskip, 3)
		if got < 0 || got > int64(c.given) || int64(int32(got)) != got {
			t.Fatalf("%+v: %d", c, got)
		}
	}
	if got := noteSamples(32000, 312+3*16000, 312, 3); got != 16000 {
		t.Fatalf("a true granule trims to %d", got)
	}
}

// packets that hold nothing but say they are 120 ms each
func lostFrames(t *testing.T, packets int) []byte {
	t.Helper()
	var out bytes.Buffer
	o := &oggWriter{w: &out, serial: 7}
	oh := make([]byte, 19)
	copy(oh, "OpusHead")
	oh[8], oh[9] = 1, 1
	binary.LittleEndian.PutUint32(oh[12:], 16000)
	if err := o.header(oh); err != nil {
		t.Fatal(err)
	}
	tags := make([]byte, 16)
	copy(tags, "OpusTags")
	if err := o.header(tags); err != nil {
		t.Fatal(err)
	}
	for i := 1; i <= packets; i++ {
		if err := o.add([]byte{9<<3 | 3, 6}, uint64(i)*5760); err != nil {
			t.Fatal(err)
		}
	}
	if err := o.flush(true); err != nil {
		t.Fatal(err)
	}
	return out.Bytes()
}

func TestASmallFileThatClaimsHours(t *testing.T) {
	b := lostFrames(t, 60000)
	if len(b) > 250*1024 {
		t.Fatalf("%d bytes", len(b))
	}
	start := time.Now()
	_, err := Decode(bytes.NewReader(b), DecodeRate, func([]int16) error { return nil })
	if !errors.Is(err, ErrLong) {
		t.Fatalf("decoded: %v", err)
	}
	if _, _, err := Peaks(bytes.NewReader(b), 30); !errors.Is(err, ErrLong) {
		t.Fatalf("peaks: %v", err)
	}
	if d := time.Since(start); d > 2*time.Second {
		t.Fatalf("took %v to refuse", d)
	}
	// a real note of silence is far above the floor
	silent := make([]int16, 60*16000)
	ogg, _ := encode(t, wavOf(silent, 16000, 1))
	if _, back := decode(t, ogg); back.Ms() != 60000 {
		t.Fatalf("a minute of silence: %d ms", back.Ms())
	}
}

func TestAnEncodeStops(t *testing.T) {
	dir := t.TempDir()
	in := filepath.Join(dir, "vn_1.wav")
	os.WriteFile(in, wavOf(speech(10, 16000), 16000, 1), 0o600)
	out := filepath.Join(dir, "vn_1.ogg")
	asked := 0
	_, err := EncodeFile(in, out, func() bool { asked++; return asked > 3 })
	if !errors.Is(err, ErrStopped) || asked != 4 {
		t.Fatalf("%v after %d asks", err, asked)
	}
	if _, err := os.Stat(out); err == nil {
		t.Fatal("a stopped encode left its file")
	}
}

func TestWhatFailsIsZeroedFirst(t *testing.T) {
	dir := t.TempDir()
	out := filepath.Join(dir, "vn_1.ogg")
	other := filepath.Join(dir, "seen")
	_, err := writeFile(out, func(w io.Writer) (Note, error) {
		w.Write(bytes.Repeat([]byte("speech"), 30000))
		// a second name on the same bytes sees what is left of them
		if err := os.Link(out, other); err != nil {
			t.Fatal(err)
		}
		return Note{}, errors.New("cut")
	})
	if err == nil {
		t.Fatal("no error")
	}
	if _, err := os.Stat(out); err == nil {
		t.Fatal("left behind")
	}
	b, _ := os.ReadFile(other)
	if len(b) != 180000 || bytes.Count(b, []byte{0}) != len(b) {
		t.Fatalf("%d bytes left, not zeroed", len(b))
	}
}

// the fuzzer's bytes as packets and granules of a stream whose pages and
// crcs are right, so they reach libopus rather than the crc check
func FuzzPackets(f *testing.F) {
	f.Add([]byte{9<<3 | 3, 6, 0xff, 1, 2, 3}, uint64(5760))
	f.Add([]byte{0xfc, 0xff, 0xfe}, uint64(3<<31))
	f.Fuzz(func(t *testing.T, b []byte, granule uint64) {
		var out bytes.Buffer
		o := &oggWriter{w: &out, serial: 1}
		oh := make([]byte, 19)
		copy(oh, "OpusHead")
		oh[8], oh[9] = 1, 1
		binary.LittleEndian.PutUint32(oh[12:], 16000)
		tags := make([]byte, 16)
		copy(tags, "OpusTags")
		if o.header(oh) != nil || o.header(tags) != nil {
			t.Skip()
		}
		for i := 0; len(b) > 0 && i < 200; i++ {
			n := min(int(b[0])%64+1, len(b))
			if o.add(b[:n], granule+uint64(i)*960) != nil {
				t.Skip()
			}
			b = b[n:]
		}
		if o.flush(true) != nil {
			t.Skip()
		}
		_, note, err := Peaks(bytes.NewReader(out.Bytes()), 30)
		if err == nil && note.Samples <= 0 {
			t.Fatalf("%d samples", note.Samples)
		}
	})
}
