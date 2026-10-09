package snowflake_client

import (
	"bytes"
	"errors"
	"io"
	"log"
	"math/rand"
	"net/http"
	"net/url"
	"time"
)

// httpRendezvous is a RendezvousMethod that communicates with the .../client
// route of the broker over HTTP or HTTPS, with optional domain fronting.
type httpRendezvous struct {
	brokerURL *url.URL
	fronts    []string          // Optional front domain to replace url.Host in requests.
	transport http.RoundTripper // Used to make all requests.
}

// newHTTPRendezvous creates a new httpRendezvous that contacts the broker at
// the given URL, with an optional front domain. transport is the
// http.RoundTripper used to make all requests.
func newHTTPRendezvous(broker string, fronts []string, transport http.RoundTripper) (*httpRendezvous, error) {
	brokerURL, err := url.Parse(broker)
	if err != nil {
		return nil, err
	}
	return &httpRendezvous{
		brokerURL: brokerURL,
		fronts:    fronts,
		transport: transport,
	}, nil
}

func (r *httpRendezvous) Exchange(encPollReq []byte) ([]byte, error) {
	log.Println("Negotiating via HTTP rendezvous...")
	log.Println("Target URL: ", r.brokerURL.Host)

	// Suffix the path with the broker's client registration handler.
	reqURL := r.brokerURL.ResolveReference(&url.URL{Path: "client"})
	req, err := http.NewRequest("POST", reqURL.String(), bytes.NewReader(encPollReq))
	if err != nil {
		return nil, err
	}

	if len(r.fronts) != 0 {
		// Do domain fronting. Replace the domain in the URL's with a randomly
		// selected front, and store the original domain the HTTP Host header.
		rand.Seed(time.Now().UnixNano())
		front := r.fronts[rand.Intn(len(r.fronts))]
		log.Println("Front URL:  ", front)
		req.Host = req.URL.Host
		req.URL.Host = front
	}

	resp, err := r.transport.RoundTrip(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	log.Printf("HTTP rendezvous response: %s", resp.Status)
	if resp.StatusCode != http.StatusOK {
		return nil, errors.New(brokerErrorUnexpected)
	}

	return limitedRead(resp.Body, readLimit)
}

func limitedRead(r io.Reader, limit int64) ([]byte, error) {
	p, err := io.ReadAll(&io.LimitedReader{R: r, N: limit + 1})
	if err != nil {
		return p, err
	} else if int64(len(p)) == limit+1 {
		return p[0:limit], io.ErrUnexpectedEOF
	}
	return p, err
}
