package webtunnel

import (
	"crypto/hmac"
	"crypto/x509"
	"errors"
	"net"

	utls "github.com/refraction-networking/utls"
	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/webtunnel/common/certiChainHashCalc"

	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/common/utlsutil"
)

type uTLSConfig struct {
	ServerName string

	uTLSFingerprint string

	// allowInsecure is used to skip certificate verification.
	// This setting should not be used unless pinnedPeerCertificateChainSha256
	// is set, otherwise it will allow any certificate to be accepted.
	allowInsecure                    bool
	pinnedPeerCertificateChainSha256 [][]byte

	InsecureServerNameToVerify string
}

func newUTLSTransport(config *uTLSConfig) (uTLSTransport, error) {
	return uTLSTransport{kind: "utls",
		serverName:                       config.ServerName,
		uTLSFingerprint:                  config.uTLSFingerprint,
		allowInsecure:                    config.allowInsecure,
		pinnedPeerCertificateChainSha256: config.pinnedPeerCertificateChainSha256,
		InsecureServerNameToVerify:       config.InsecureServerNameToVerify,
	}, nil
}

type uTLSTransport struct {
	kind       string
	serverName string

	uTLSFingerprint string

	allowInsecure                    bool
	pinnedPeerCertificateChainSha256 [][]byte

	InsecureServerNameToVerify string
}

func (t *uTLSTransport) Client(conn net.Conn) (net.Conn, error) {
	switch t.kind {
	case "utls":
		fp, err := utlsutil.ParseClientHelloID(t.uTLSFingerprint)
		if err != nil {
			return nil, err
		}
		if t.allowInsecure && t.pinnedPeerCertificateChainSha256 == nil {
			return nil, errors.New("naked allowInsecure is not allowed, pinnedPeerCertificateChainSha256 must be set to verify remote certificate chain")
		}
		conf := &utls.Config{ServerName: t.serverName,
			InsecureSkipVerify:         t.allowInsecure,
			VerifyPeerCertificate:      t.verifyPeerCert,
			InsecureServerNameToVerify: t.InsecureServerNameToVerify}
		return utls.UClient(conn, conf, *fp), nil
	}
	return nil, errors.New("unknown kind")
}

func (t *uTLSTransport) verifyPeerCert(rawCerts [][]byte, verifiedChains [][]*x509.Certificate) error {
	if t.pinnedPeerCertificateChainSha256 != nil {
		hashValue := certiChainHashCalc.GenerateCertChainHash(rawCerts)
		for _, v := range t.pinnedPeerCertificateChainSha256 {
			if hmac.Equal(hashValue, v) {
				return nil
			}
		}
		return errors.New("pinned certificate chain hash not matched")
	}
	return nil
}
