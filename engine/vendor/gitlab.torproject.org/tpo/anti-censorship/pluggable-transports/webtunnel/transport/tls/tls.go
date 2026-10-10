package tls

import (
	"crypto/hmac"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"net"

	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/webtunnel/common/certiChainHashCalc"
)

type Config struct {
	ServerName string

	AllowInsecure                    bool
	PinnedPeerCertificateChainSha256 [][]byte
}

func NewTLSTransport(config *Config) (Transport, error) {
	return Transport{kind: "tls", serverName: config.ServerName,
		allowInsecure: config.AllowInsecure, pinnedPeerCertificateChainSha256: config.PinnedPeerCertificateChainSha256}, nil
}

type Transport struct {
	kind       string
	serverName string

	allowInsecure                    bool
	pinnedPeerCertificateChainSha256 [][]byte
}

func (c Transport) verifyPeerCert(rawCerts [][]byte, verifiedChains [][]*x509.Certificate) error {
	if c.pinnedPeerCertificateChainSha256 != nil {
		hashValue := certiChainHashCalc.GenerateCertChainHash(rawCerts)
		for _, v := range c.pinnedPeerCertificateChainSha256 {
			if hmac.Equal(hashValue, v) {
				return nil
			}
		}
		return errors.New("pinned certificate chain hash not matched")
	}
	return nil
}

func (t Transport) Client(conn net.Conn) (net.Conn, error) {
	switch t.kind {
	case "tls":
		conf := &tls.Config{ServerName: t.serverName, InsecureSkipVerify: t.allowInsecure, VerifyPeerCertificate: t.verifyPeerCert}
		return tls.Client(conn, conf), nil
	}
	return nil, errors.New("unknown kind")
}
