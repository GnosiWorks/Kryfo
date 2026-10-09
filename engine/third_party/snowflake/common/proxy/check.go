package proxy

import (
	"errors"
	"net/url"
	"strings"
)

var errUnsupportedProxyType = errors.New("unsupported proxy type")

func CheckProxyProtocolSupport(proxy *url.URL) error {
	switch strings.ToLower(proxy.Scheme) {
	case "socks5":
		return nil
	default:
		return errUnsupportedProxyType
	}
}
