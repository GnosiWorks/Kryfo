// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the gif relay: search, trending and the pictures. on a lane of its own,
// tor on the onion route, our server directly on the others. every request
// says it is the app's, which a web page cannot say for it.

import "C"

import (
	"context"
	"fmt"
	"io"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// the largest file taken, a little over what the relay passes on
const torFileMax = 8 << 20

// the kinds a picture may come as
var torFileTypes = map[string]bool{"image/gif": true, "image/webp": true}

// the client for the gif lane; tests stand their own in
var gifClient = func() (*http.Client, error) { return torNostrClientFor(laneGifs) }

// POST json to the gif relay. the body of a 2xx, or "error: ...".
//
//export HaloGifPost
func HaloGifPost(cUrl, cBody *C.char) *C.char {
	return C.CString(gifAsk(http.MethodPost, C.GoString(cUrl), C.GoString(cBody)))
}

// GET from the gif relay. the body of a 2xx, or "error: ...".
//
//export HaloGifGet
func HaloGifGet(cUrl *C.char) *C.char {
	return C.CString(gifAsk(http.MethodGet, C.GoString(cUrl), ""))
}

// GET a picture from the gif relay into path, whole or not at all.
// "ok <bytes>" or "error: ...".
//
//export HaloGifGetFile
func HaloGifGetFile(cUrl, cPath *C.char) *C.char {
	url, path := C.GoString(cUrl), C.GoString(cPath)
	if url == "" || path == "" {
		return C.CString("error: empty url")
	}
	c, err := gifClient()
	if err != nil {
		return C.CString(fmt.Sprintf("error: tor client: %v", err))
	}
	return C.CString(getFileWith(c, url, path))
}

func gifRequest(method, url, body string) (*http.Request, error) {
	var r io.Reader
	if method == http.MethodPost {
		r = strings.NewReader(body)
	}
	req, err := http.NewRequest(method, url, r)
	if err != nil {
		return nil, err
	}
	req.Header.Set("X-Kryfo", "1")
	if method == http.MethodPost {
		req.Header.Set("Content-Type", "application/json")
	}
	return req, nil
}

func gifAsk(method, url, body string) string {
	if url == "" {
		return "error: empty url"
	}
	c, err := gifClient()
	if err != nil {
		return fmt.Sprintf("error: tor client: %v", err)
	}
	req, err := gifRequest(method, url, body)
	if err != nil {
		return fmt.Sprintf("error: req: %v", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	resp, err := c.Do(req.WithContext(ctx))
	if err != nil {
		return fmt.Sprintf("error: get: %v", err)
	}
	defer resp.Body.Close()
	out, err := io.ReadAll(io.LimitReader(resp.Body, 256*1024))
	if err != nil {
		return fmt.Sprintf("error: read: %v", err)
	}
	if resp.StatusCode >= 300 {
		return fmt.Sprintf("error: status %d", resp.StatusCode)
	}
	return string(out)
}

func getFileWith(c *http.Client, url, path string) string {
	req, err := gifRequest(http.MethodGet, url, "")
	if err != nil {
		return fmt.Sprintf("error: req: %v", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	resp, err := c.Do(req.WithContext(ctx))
	if err != nil {
		return fmt.Sprintf("error: get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Sprintf("error: status %d", resp.StatusCode)
	}
	ct, _, _ := mime.ParseMediaType(resp.Header.Get("Content-Type"))
	if !torFileTypes[ct] {
		return "error: not a picture"
	}
	if resp.ContentLength > torFileMax {
		return "error: too big"
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), ".part-*")
	if err != nil {
		return fmt.Sprintf("error: file: %v", err)
	}
	n, err := io.Copy(tmp, io.LimitReader(resp.Body, torFileMax+1))
	cerr := tmp.Close()
	switch {
	case err != nil:
		err = fmt.Errorf("read: %v", err)
	case cerr != nil:
		err = fmt.Errorf("file: %v", cerr)
	case n > torFileMax:
		err = fmt.Errorf("too big")
	case resp.ContentLength >= 0 && n != resp.ContentLength:
		err = fmt.Errorf("cut short")
	}
	if err == nil {
		err = os.Rename(tmp.Name(), path)
	}
	if err != nil {
		os.Remove(tmp.Name())
		return fmt.Sprintf("error: %v", err)
	}
	return fmt.Sprintf("ok %d", n)
}
