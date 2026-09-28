// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"context"

	libtor "github.com/alexballas/go-libtor"
	"github.com/cretz/bine/process"
)

// go-libtor types its processes with its own copy of bine's process package.
// the methods are the same, so its processes go to bine as they are.
type libtorCreator struct{}

func (libtorCreator) New(ctx context.Context, args ...string) (process.Process, error) {
	return libtor.Creator.New(ctx, args...)
}
