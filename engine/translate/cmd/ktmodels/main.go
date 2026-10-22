// SPDX-License-Identifier: GPL-3.0-or-later
// a desk tool for the translation prototype: list the pinned models, fetch
// a language's bundle into a directory (directly, for development; the app
// fetches over tor through the engine), and print a pair's bergamot config.
//
//	ktmodels list
//	ktmodels fetch <lang> <dir>
//	ktmodels config <from> <to> <dir>
package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/halo/engine/translate"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	m, err := translate.Pinned()
	if err != nil {
		return err
	}
	if len(args) == 0 {
		return fmt.Errorf("usage: ktmodels list | fetch <lang> <dir> | config <from> <to> <dir>")
	}
	switch {
	case args[0] == "list":
		for _, p := range m.Pairs {
			fmt.Printf("%s-%s %s: fetch %.1f MB, disk %.1f MB\n", p.From, p.To, p.Arch,
				float64(p.GzBytes())/1e6, float64(p.DiskBytes())/1e6)
		}
		return nil
	case args[0] == "fetch" && len(args) == 3:
		pairs := m.Bundle(args[1])
		if len(pairs) == 0 {
			return fmt.Errorf("no models for %q", args[1])
		}
		get := translate.HTTPGetter(&http.Client{Timeout: 60 * time.Second})
		for _, p := range pairs {
			dir := filepath.Join(args[2], p.Dir())
			t0 := time.Now()
			err := translate.FetchPair(context.Background(), get, m, p, dir, func(d, n int64) {
				fmt.Fprintf(os.Stderr, "\r%s %5.1f%%", p.Dir(), 100*float64(d)/float64(n))
			})
			fmt.Fprintln(os.Stderr)
			if err != nil {
				return err
			}
			fmt.Printf("%s in %s (%.1fs)\n", p.Dir(), dir, time.Since(t0).Seconds())
		}
		return nil
	case args[0] == "config" && len(args) == 4:
		p, ok := m.Pair(args[1], args[2])
		if !ok {
			return fmt.Errorf("no %s-%s", args[1], args[2])
		}
		dir, err := filepath.Abs(args[3])
		if err != nil {
			return err
		}
		fmt.Print(p.Config(dir))
		return nil
	}
	return fmt.Errorf("bad arguments %q", args)
}
