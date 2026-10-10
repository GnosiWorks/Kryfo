package meeklite

import (
	"fmt"
	"math/rand"
	gourl "net/url"
	"slices"
	"strings"
)

type frontArgs struct {
	url   *gourl.URL
	front string
}

type frontsList struct {
	list  []frontArgs
	index int
}

func NewFrontsList() *frontsList {
	return &frontsList{
		list:  []frontArgs{},
		index: 0,
	}
}

// Add inserts the url/front pair in the list in a random position
func (fl *frontsList) Add(url string, front string) error {
	fa := frontArgs{
		front: front,
	}
	var err error
	fa.url, err = toGoURL(url)
	if err != nil {
		return err
	}

	index := rand.Intn(len(fl.list) + 1)
	fl.list = slices.Insert(fl.list, index, fa)
	return nil
}

func toGoURL(urlStr string) (*gourl.URL, error) {
	url, err := gourl.Parse(urlStr)
	if err != nil {
		return nil, fmt.Errorf("malformed url: '%s'", urlStr)
	}
	switch url.Scheme {
	case "http", "https":
	default:
		return nil, fmt.Errorf("invalid scheme: '%s'", url.Scheme)
	}
	return url, nil
}

func (fl *frontsList) Next() {
	fl.index++
	if fl.index >= len(fl.list) {
		fl.index = 0
	}
}

func (fl *frontsList) Front() string {
	return fl.list[fl.index].front
}

func (fl *frontsList) URL() *gourl.URL {
	return fl.list[fl.index].url
}

func (fl *frontsList) String() string {
	str := ""
	for _, front := range fl.list {
		str += front.front + "|" + front.url.String() + " "
	}
	return strings.TrimSpace(str)
}
