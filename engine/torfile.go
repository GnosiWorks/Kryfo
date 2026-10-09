// SPDX-License-Identifier: GPL-3.0-or-later
package main

// a file read over the services lane: the gif relay's pictures. the route
// is the one people search takes, tor on the onion route, our server
// directly on the others.

import "C"

import (
	"context"
	"fmt"
	"io"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

// the largest file taken, a little over what the relay passes on
const torFileMax = 8 << 20

// the kinds a picture may come as
var torFileTypes = map[string]bool{"image/gif": true, "image/webp": true}

// GET url into path, whole or not at all. "ok <bytes>" or "error: ...".
//
//export HaloTorGetFile
func HaloTorGetFile(cUrl, cPath *C.char) *C.char {
	return C.CString(torGetFile(C.GoString(cUrl), C.GoString(cPath)))
}

func torGetFile(url, path string) string {
	if url == "" || path == "" {
		return "error: empty url"
	}
	client, err := torNostrClientFor(laneServices)
	if err != nil {
		return fmt.Sprintf("error: tor client: %v", err)
	}
	return getFileWith(client, url, path)
}

func getFileWith(c *http.Client, url, path string) string {
	req, err := http.NewRequest(http.MethodGet, url, nil)
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
