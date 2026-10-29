// SPDX-License-Identifier: GPL-3.0-or-later
//go:build !windows

package main

import (
	"context"

	libtor "github.com/alexballas/go-libtor"
	"github.com/cretz/bine/process"
)

type libtorCreator struct{} // go-libtor has its own copy of bine's process types, same methods

func (libtorCreator) New(ctx context.Context, args ...string) (process.Process, error) {
	return libtor.Creator.New(ctx, args...)
}
