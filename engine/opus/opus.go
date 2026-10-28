// SPDX-License-Identifier: GPL-3.0-or-later

// Package opus is libopus, built from libopus/ (see vendor.sh), with an ogg
// writer and reader for voice notes. fixed point and plain c on every abi,
// so each target builds the same code
package opus

/*
#cgo CFLAGS: -DOPUS_BUILD -DFIXED_POINT -DDISABLE_FLOAT_API -DVAR_ARRAYS -DENABLE_HARDENING
#cgo CFLAGS: -DHAVE_LRINT -DHAVE_LRINTF
#cgo CFLAGS: -I${SRCDIR}/libopus -I${SRCDIR}/libopus/include -I${SRCDIR}/libopus/celt
#cgo CFLAGS: -I${SRCDIR}/libopus/silk -I${SRCDIR}/libopus/silk/fixed
#cgo LDFLAGS: -lm
#include <opus.h>

// cgo cannot call the variadic ctl, so each one used has its own call
static int enc_set(OpusEncoder *e, int bitrate, int complexity) {
	int r;
	if ((r = opus_encoder_ctl(e, OPUS_SET_BITRATE(bitrate))) != OPUS_OK) return r;
	if ((r = opus_encoder_ctl(e, OPUS_SET_COMPLEXITY(complexity))) != OPUS_OK) return r;
	if ((r = opus_encoder_ctl(e, OPUS_SET_SIGNAL(OPUS_SIGNAL_VOICE))) != OPUS_OK) return r;
	if ((r = opus_encoder_ctl(e, OPUS_SET_VBR(1))) != OPUS_OK) return r;
	if ((r = opus_encoder_ctl(e, OPUS_SET_DTX(0))) != OPUS_OK) return r;
	return opus_encoder_ctl(e, OPUS_SET_INBAND_FEC(0));
}

static int enc_lookahead(OpusEncoder *e) {
	opus_int32 n = 0;
	if (opus_encoder_ctl(e, OPUS_GET_LOOKAHEAD(&n)) != OPUS_OK) return -1;
	return (int)n;
}
*/
import "C"

import (
	"errors"
	"fmt"
	"unsafe"
)

// the rates libopus takes in and puts out as they are
var rates = map[int]bool{8000: true, 12000: true, 16000: true, 24000: true, 48000: true}

// RateOK says whether libopus takes [rate] without a resampler
func RateOK(rate int) bool { return rates[rate] }

// the biggest packet libopus writes, with room to spare
const maxPacket = 4000

// Encoder is one mono libopus encoder. not for use from two goroutines
type Encoder struct {
	e    *C.OpusEncoder
	rate int
	out  []byte
}

// NewEncoder makes a mono speech encoder for [rate] at [bitrate] bit/s
func NewEncoder(rate, bitrate, complexity int) (*Encoder, error) {
	if !RateOK(rate) {
		return nil, fmt.Errorf("opus: rate %d", rate)
	}
	var err C.int
	e := C.opus_encoder_create(C.opus_int32(rate), 1, C.OPUS_APPLICATION_VOIP, &err)
	if err != C.OPUS_OK || e == nil {
		return nil, fmt.Errorf("opus: encoder %d", int(err))
	}
	if r := C.enc_set(e, C.int(bitrate), C.int(complexity)); r != C.OPUS_OK {
		C.opus_encoder_destroy(e)
		return nil, fmt.Errorf("opus: settings %d", int(r))
	}
	return &Encoder{e: e, rate: rate, out: make([]byte, maxPacket)}, nil
}

// Lookahead is the samples, at the encoder's rate, the output runs behind
func (enc *Encoder) Lookahead() int { return int(C.enc_lookahead(enc.e)) }

// Encode turns one frame of [pcm] (2.5 to 60 ms) into a packet. the packet
// is only good until the next call
func (enc *Encoder) Encode(pcm []int16) ([]byte, error) {
	if len(pcm) == 0 {
		return nil, errors.New("opus: empty frame")
	}
	n := C.opus_encode(enc.e, (*C.opus_int16)(unsafe.Pointer(&pcm[0])), C.int(len(pcm)),
		(*C.uchar)(unsafe.Pointer(&enc.out[0])), C.opus_int32(len(enc.out)))
	if n < 0 {
		return nil, fmt.Errorf("opus: encode %d", int(n))
	}
	return enc.out[:n], nil
}

// Close frees the encoder
func (enc *Encoder) Close() {
	if enc.e != nil {
		C.opus_encoder_destroy(enc.e)
		enc.e = nil
	}
}

// the longest frame a packet holds: 120 ms at 48 khz
const maxFrame = 5760

// Decoder is one mono libopus decoder. not for use from two goroutines
type Decoder struct {
	d    *C.OpusDecoder
	rate int
	pcm  []int16
}

// NewDecoder makes a mono decoder that puts out [rate]
func NewDecoder(rate int) (*Decoder, error) {
	if !RateOK(rate) {
		return nil, fmt.Errorf("opus: rate %d", rate)
	}
	var err C.int
	d := C.opus_decoder_create(C.opus_int32(rate), 1, &err)
	if err != C.OPUS_OK || d == nil {
		return nil, fmt.Errorf("opus: decoder %d", int(err))
	}
	return &Decoder{d: d, rate: rate, pcm: make([]int16, maxFrame*rate/48000)}, nil
}

// Decode turns one packet into samples, only good until the next call
func (dec *Decoder) Decode(packet []byte) ([]int16, error) {
	if len(packet) == 0 {
		return nil, errors.New("opus: empty packet")
	}
	n := C.opus_decode(dec.d, (*C.uchar)(unsafe.Pointer(&packet[0])), C.opus_int32(len(packet)),
		(*C.opus_int16)(unsafe.Pointer(&dec.pcm[0])), C.int(len(dec.pcm)), 0)
	if n < 0 {
		return nil, fmt.Errorf("opus: decode %d", int(n))
	}
	return dec.pcm[:n], nil
}

// Close frees the decoder
func (dec *Decoder) Close() {
	if dec.d != nil {
		C.opus_decoder_destroy(dec.d)
		dec.d = nil
	}
}
