package util

import (
	"io"
	stdlog "log"
)

// kryfo: the fork logs nothing. its lines carry broker urls, fronts, stun
// servers and sdp, and the app's log is no place for them.
var log = stdlog.New(io.Discard, "", 0)
