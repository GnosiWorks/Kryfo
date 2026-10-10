package messages

import (
	"context"
	"errors"
)

type RendezvousMethod string

const (
	RendezvousHttp     RendezvousMethod = "http"
	RendezvousAmpCache RendezvousMethod = "ampcache"
	RendezvousSqs      RendezvousMethod = "sqs"
)

type Arg struct {
	Body             []byte
	RemoteAddr       string
	RendezvousMethod RendezvousMethod
	Context          context.Context
}

var (
	ErrBadRequest = errors.New("bad request")
	ErrInternal   = errors.New("internal error")
	ErrExtraInfo  = errors.New("client sent extra info")

	StrTimedOut  = "timed out waiting for answer!"
	StrNoProxies = "no snowflake proxies currently available"
)
