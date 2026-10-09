// SPDX-License-Identifier: GPL-3.0-or-later
package main

// the two providers. each request carries the key, the question, the rating
// and nothing else: no random_id, no customer id, no address.

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
)

var errUpstream = errors.New("upstream")

// a json answer from a provider, read whole up to a megabyte
func getJSON(ctx context.Context, c *http.Client, u string, v any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return errUpstream
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "application/json")
	resp, err := c.Do(req)
	if err != nil {
		return errUpstream
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return errUpstream
	}
	if json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(v) != nil {
		return errUpstream
	}
	return nil
}

type giphy struct {
	base string
	key  string
	c    *http.Client
}

func (g *giphy) name() string  { return "giphy" }
func (g *giphy) brand() string { return "GIPHY" }

// giphy writes its numbers as strings
type giphyImage struct {
	URL      string `json:"url"`
	Width    string `json:"width"`
	Height   string `json:"height"`
	Size     string `json:"size"`
	Webp     string `json:"webp"`
	WebpSize string `json:"webp_size"`
}

func (g *giphy) fetch(ctx context.Context, a ask) ([]item, bool, error) {
	v := url.Values{}
	v.Set("api_key", g.key)
	v.Set("limit", strconv.Itoa(a.limit))
	v.Set("offset", strconv.Itoa(a.offset))
	v.Set("rating", rating)
	v.Set("bundle", "messaging_non_clips")
	path := "/v1/gifs/trending"
	if !a.trending {
		path = "/v1/gifs/search"
		v.Set("q", a.q)
		if a.lang != "" {
			v.Set("lang", a.lang)
		}
	}
	var r struct {
		Data []struct {
			ID     string                `json:"id"`
			Images map[string]giphyImage `json:"images"`
		} `json:"data"`
		Pagination struct {
			Total  int `json:"total_count"`
			Count  int `json:"count"`
			Offset int `json:"offset"`
		} `json:"pagination"`
	}
	if err := getJSON(ctx, g.c, g.base+path+"?"+v.Encode(), &r); err != nil {
		return nil, false, err
	}
	var out []item
	for _, d := range r.Data {
		fw, ok := d.Images["fixed_width"]
		if !ok {
			continue
		}
		pre := media{URL: fw.Webp, W: atoi(fw.Width), H: atoi(fw.Height), Bytes: int64(atoi(fw.WebpSize))}
		if pre.URL == "" {
			pre.URL, pre.Bytes = fw.URL, int64(atoi(fw.Size))
		}
		// the full one is the gif that goes inside a message: downsized
		// keeps the size it was made at under two megabytes
		full := media{}
		for _, k := range []string{"downsized", "downsized_medium", "fixed_width"} {
			im, ok := d.Images[k]
			n := int64(atoi(im.Size))
			if ok && im.URL != "" && n > 0 && n <= maxMedia {
				full = media{URL: im.URL, W: atoi(im.Width), H: atoi(im.Height), Bytes: n}
				break
			}
		}
		pre.URL, full.URL = bare(pre.URL), bare(full.URL)
		out = append(out, item{ID: d.ID, W: full.W, H: full.H, Preview: pre, Full: full})
	}
	// a short page is the last one, whatever the total says
	p := r.Pagination
	more := p.Count == a.limit && p.Offset+p.Count < p.Total
	return out, more, nil
}

// giphy's media urls carry the id of the api call that named them: the
// file is the same without it
func bare(s string) string {
	u, err := url.Parse(s)
	if err != nil {
		return ""
	}
	u.RawQuery, u.Fragment = "", ""
	return u.String()
}

func atoi(s string) int {
	n, err := strconv.Atoi(s)
	if err != nil || n < 0 {
		return 0
	}
	return n
}

type klipy struct {
	base string
	key  string
	c    *http.Client
}

func (k *klipy) name() string  { return "klipy" }
func (k *klipy) brand() string { return "Klipy" }

type klipyFile struct {
	URL    string `json:"url"`
	Width  int    `json:"width"`
	Height int    `json:"height"`
	Size   int64  `json:"size"`
}

type klipyFormats struct {
	Gif  *klipyFile `json:"gif"`
	Webp *klipyFile `json:"webp"`
}

// klipy takes a country (iso 3166 alpha-2) where giphy takes a language
var klipyLocales = map[string]string{
	"en": "us", "de": "de", "fr": "fr", "es": "es", "pt": "br", "it": "it",
	"ru": "ru", "uk": "ua", "tr": "tr", "zh-CN": "cn", "zh-TW": "tw",
	"vi": "vn", "id": "id", "fa": "ir", "ar": "sa",
}

// klipy's own scale (off, low, medium, high) has no pg-13 by name. low is
// the step that lets pg-13 through and nothing past it
const klipyFilter = "low"

// klipy pages by number, 8 to 50 a page. an offset inside a page is read
// from that page on, and the next page fills what the first leaves. an ad
// or an item we cannot show keeps its place, so offsets stay klipy's
func (k *klipy) fetch(ctx context.Context, a ask) ([]item, bool, error) {
	per := max(a.limit, 8)
	page := a.offset/per + 1
	skip := a.offset % per
	var places []*item
	for {
		got, more, err := k.page(ctx, a, per, page)
		if err != nil {
			return nil, false, err
		}
		if skip < len(got) {
			places = append(places, got[skip:]...)
		}
		skip = 0
		if len(places) >= a.limit || !more || len(got) == 0 {
			if len(places) > a.limit {
				places, more = places[:a.limit], true
			}
			var out []item
			for _, it := range places {
				if it != nil {
					out = append(out, *it)
				}
			}
			return out, more, nil
		}
		page++
	}
}

// one page as klipy numbers it, nil where nothing can be shown
func (k *klipy) page(ctx context.Context, a ask, per, page int) ([]*item, bool, error) {
	v := url.Values{}
	v.Set("per_page", strconv.Itoa(per))
	v.Set("page", strconv.Itoa(page))
	v.Set("content_filter", klipyFilter)
	v.Set("format_filter", "gif,webp")
	if l := klipyLocales[a.lang]; l != "" {
		v.Set("locale", l)
	}
	kind := "trending"
	if !a.trending {
		kind = "search"
		v.Set("q", a.q)
	}
	var r struct {
		Result bool `json:"result"`
		Data   struct {
			Data []struct {
				ID   json.RawMessage         `json:"id"`
				Type string                  `json:"type"`
				File map[string]klipyFormats `json:"file"`
			} `json:"data"`
			HasNext bool `json:"has_next"`
		} `json:"data"`
	}
	u := k.base + "/api/v1/" + url.PathEscape(k.key) + "/gifs/" + kind + "?" + v.Encode()
	if err := getJSON(ctx, k.c, u, &r); err != nil {
		return nil, false, err
	}
	if !r.Result {
		return nil, false, errUpstream
	}
	out := make([]*item, 0, len(r.Data.Data))
	for _, d := range r.Data.Data {
		pre := pick(d.File, []string{"sm", "xs", "md"}, true)
		full := pick(d.File, []string{"md", "sm", "hd"}, false)
		// an ad is a web page, never shown
		if (d.Type != "" && d.Type != "gif") || pre == nil || full == nil {
			out = append(out, nil)
			continue
		}
		out = append(out, &item{
			ID: strings.Trim(string(d.ID), `"`), W: full.Width, H: full.Height,
			Preview: media{URL: pre.URL, W: pre.Width, H: pre.Height, Bytes: pre.Size},
			Full:    media{URL: full.URL, W: full.Width, H: full.Height, Bytes: full.Size},
		})
	}
	return out, r.Data.HasNext, nil
}

// the first size that has the format: webp first for a preview, a gif for
// what is sent
func pick(f map[string]klipyFormats, sizes []string, webp bool) *klipyFile {
	for _, s := range sizes {
		fm, ok := f[s]
		if !ok {
			continue
		}
		if webp && fm.Webp != nil && fm.Webp.URL != "" {
			return fm.Webp
		}
		if fm.Gif != nil && fm.Gif.URL != "" && fm.Gif.Size <= maxMedia {
			return fm.Gif
		}
	}
	return nil
}
