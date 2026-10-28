// SPDX-License-Identifier: GPL-3.0-or-later
package main

// fcm's http v1 api with a service account: a jwt signed with its key buys
// an access token for an hour, and each push is one empty high-priority
// data message. the service-account file is read once at start; no error
// and no log line ever carries anything from it but its project id.

import (
	"bytes"
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	fcmScope  = "https://www.googleapis.com/auth/firebase.messaging"
	fcmBase   = "https://fcm.googleapis.com"
	tokenHost = "oauth2.googleapis.com"
	// as long as the relay asks a push server to keep a knock
	fcmTTL = "3600s"
)

// where the access token may come from: google's own host. the tests point
// it at a fake one
var tokenURLOK = func(u *url.URL) bool {
	return u.Scheme == "https" && u.Host == tokenHost && u.User == nil
}

type outcome int

const (
	sent outcome = iota
	// the token is no longer a phone's: the endpoint can go
	gone
	// fcm is pacing us, try after the wait
	busy
	// fcm or our credentials failed, nothing about the endpoint
	failed
)

type pusher interface {
	push(ctx context.Context, token string) (outcome, time.Duration)
}

type fcm struct {
	project  string
	email    string
	keyID    string
	key      *rsa.PrivateKey
	tokenURL string
	base     string
	c        *http.Client

	mu     sync.Mutex
	access string
	until  time.Time
}

// the service account's file. errors name the field, never a value
func loadFCM(path string) (*fcm, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, errors.New("the service-account file could not be read")
	}
	defer clear(b)
	var sa struct {
		Type         string `json:"type"`
		ProjectID    string `json:"project_id"`
		PrivateKeyID string `json:"private_key_id"`
		PrivateKey   string `json:"private_key"`
		ClientEmail  string `json:"client_email"`
		TokenURI     string `json:"token_uri"`
	}
	if json.Unmarshal(b, &sa) != nil {
		return nil, errors.New("the service-account file is not json")
	}
	switch {
	case sa.Type != "service_account":
		return nil, errors.New("the service-account file is not a service account's")
	case !projectOK(sa.ProjectID):
		return nil, errors.New("the service-account file has no usable project_id")
	case sa.ClientEmail == "" || strings.ContainsAny(sa.ClientEmail, " \r\n"):
		return nil, errors.New("the service-account file has no client_email")
	}
	if sa.TokenURI == "" {
		sa.TokenURI = "https://" + tokenHost + "/token"
	}
	u, err := url.Parse(sa.TokenURI)
	if err != nil || !tokenURLOK(u) {
		return nil, errors.New("the service-account file's token_uri is not google's")
	}
	blk, _ := pem.Decode([]byte(sa.PrivateKey))
	if blk == nil {
		return nil, errors.New("the service-account file's private_key is not pem")
	}
	parsed, err := x509.ParsePKCS8PrivateKey(blk.Bytes)
	if err != nil {
		parsed, err = x509.ParsePKCS1PrivateKey(blk.Bytes)
	}
	key, ok := parsed.(*rsa.PrivateKey)
	if err != nil || !ok {
		return nil, errors.New("the service-account file's private_key is not an rsa key")
	}
	return &fcm{
		project:  sa.ProjectID,
		email:    sa.ClientEmail,
		keyID:    sa.PrivateKeyID,
		key:      key,
		tokenURL: u.String(),
		base:     fcmBase,
		c:        outClient(),
	}, nil
}

func projectOK(p string) bool {
	if p == "" || len(p) > 64 {
		return false
	}
	return strings.Trim(p, "abcdefghijklmnopqrstuvwxyz0123456789-") == ""
}

// no proxy from the environment, no cookies, no redirects, short timeouts
func outClient() *http.Client {
	return &http.Client{
		Transport: &http.Transport{
			Proxy:                 nil,
			DialContext:           (&net.Dialer{Timeout: 5 * time.Second}).DialContext,
			TLSHandshakeTimeout:   5 * time.Second,
			ResponseHeaderTimeout: 8 * time.Second,
			MaxIdleConnsPerHost:   32,
			IdleConnTimeout:       90 * time.Second,
			ForceAttemptHTTP2:     true,
		},
		Timeout: 10 * time.Second,
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
}

func (f *fcm) jwt(now time.Time) (string, error) {
	head, _ := json.Marshal(map[string]string{"alg": "RS256", "typ": "JWT", "kid": f.keyID})
	claims, _ := json.Marshal(map[string]any{
		"iss":   f.email,
		"scope": fcmScope,
		"aud":   f.tokenURL,
		"iat":   now.Unix(),
		"exp":   now.Add(time.Hour).Unix(),
	})
	signing := b64.EncodeToString(head) + "." + b64.EncodeToString(claims)
	sum := sha256.Sum256([]byte(signing))
	sig, err := rsa.SignPKCS1v15(rand.Reader, f.key, crypto.SHA256, sum[:])
	if err != nil {
		return "", err
	}
	return signing + "." + b64.EncodeToString(sig), nil
}

// the access token, a new one five minutes before the old one ends
func (f *fcm) token(ctx context.Context, fresh bool) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	now := time.Now()
	if !fresh && f.access != "" && now.Before(f.until) {
		return f.access, nil
	}
	assertion, err := f.jwt(now)
	if err != nil {
		return "", errors.New("auth: could not sign")
	}
	form := url.Values{
		"grant_type": {"urn:ietf:params:oauth:grant-type:jwt-bearer"},
		"assertion":  {assertion},
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, f.tokenURL, strings.NewReader(form.Encode()))
	if err != nil {
		return "", errors.New("auth: bad request")
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := f.c.Do(req)
	if err != nil {
		return "", errors.New("auth: token endpoint unreached")
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
	if resp.StatusCode != http.StatusOK {
		return "", errors.New("auth: token endpoint answered " + strconv.Itoa(resp.StatusCode))
	}
	var t struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if json.Unmarshal(body, &t) != nil || t.AccessToken == "" {
		return "", errors.New("auth: no access token")
	}
	life := time.Duration(t.ExpiresIn) * time.Second
	if life <= 0 || life > time.Hour {
		life = time.Hour
	}
	f.access = t.AccessToken
	f.until = now.Add(life - 5*time.Minute)
	return f.access, nil
}

// the message: no notification, no data, nothing but whom to wake. high
// priority lets android start the short run that fetches over tor. queued
// knocks for a phone that is off collapse into one
func message(token string) []byte {
	b, _ := json.Marshal(map[string]any{
		"message": map[string]any{
			"token": token,
			"android": map[string]any{
				"priority":     "HIGH",
				"ttl":          fcmTTL,
				"collapse_key": "k",
			},
		},
	})
	return b
}

func (f *fcm) push(ctx context.Context, token string) (outcome, time.Duration) {
	for try := 0; try < 2; try++ {
		access, err := f.token(ctx, try > 0)
		if err != nil {
			return failed, 0
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodPost,
			f.base+"/v1/projects/"+f.project+"/messages:send", bytes.NewReader(message(token)))
		if err != nil {
			return failed, 0
		}
		req.Header.Set("Authorization", "Bearer "+access)
		req.Header.Set("Content-Type", "application/json")
		resp, err := f.c.Do(req)
		if err != nil {
			return failed, 0
		}
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 16<<10))
		resp.Body.Close()
		switch code := resp.StatusCode; {
		case code == http.StatusOK:
			return sent, 0
		case code == http.StatusUnauthorized && try == 0:
			// the access token went stale early: once more with a new one
			continue
		case code == http.StatusTooManyRequests:
			return busy, retryAfter(resp.Header.Get("Retry-After"))
		case code >= 500:
			return failed, retryAfter(resp.Header.Get("Retry-After"))
		default:
			if tokenGone(code, body) {
				return gone, 0
			}
			return failed, 0
		}
	}
	return failed, 0
}

// whether fcm's answer says the token belongs to no phone: unregistered,
// or a registration token fcm calls invalid. anything else, a sender
// mismatch or a bare 404 too, is ours or fcm's to fix and drops no
// endpoint: a wrong service-account file must not cost every phone its
// registrations
func tokenGone(code int, body []byte) bool {
	var e struct {
		Error struct {
			Message string `json:"message"`
			Details []struct {
				ErrorCode string `json:"errorCode"`
			} `json:"details"`
		} `json:"error"`
	}
	if json.Unmarshal(body, &e) != nil {
		return false
	}
	for _, d := range e.Error.Details {
		switch d.ErrorCode {
		case "UNREGISTERED":
			return code == http.StatusNotFound || code == http.StatusBadRequest
		case "INVALID_ARGUMENT":
			return code == http.StatusBadRequest &&
				strings.Contains(strings.ToLower(e.Error.Message), "registration token")
		}
	}
	return false
}

// seconds or an http date, at most ten minutes
func retryAfter(v string) time.Duration {
	if v == "" {
		return 0
	}
	var d time.Duration
	if n, err := strconv.Atoi(strings.TrimSpace(v)); err == nil && n > 0 {
		d = time.Duration(n) * time.Second
	} else if t, err := http.ParseTime(v); err == nil {
		d = time.Until(t)
	}
	return min(max(d, 0), 10*time.Minute)
}
