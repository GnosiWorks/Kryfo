// SPDX-License-Identifier: GPL-3.0-or-later
//go:build !windows

package main

import (
	"context"
	"sync/atomic"

	libtor "github.com/alexballas/go-libtor"
	"github.com/cretz/bine/process"
)

type libtorCreator struct{} // go-libtor has its own copy of bine's process types, same methods

func (libtorCreator) New(ctx context.Context, args ...string) (process.Process, error) {
	p, err := libtor.Creator.New(ctx, args...)
	if err != nil {
		return nil, err
	}
	return launched{p}, nil
}

// the embedded tors this process ran. tor survives one shutdown per process
// (see torRestarting): a start that failed, which bine closes, may go once
// more, and never a third time
var torLaunches atomic.Int32

type launched struct{ process.Process }

func (p launched) Start() error {
	torLaunches.Add(1)
	return p.Process.Start()
}

// whether a tor may run in this process now
func torMayLaunch() bool { return torLaunches.Load() < 2 }
