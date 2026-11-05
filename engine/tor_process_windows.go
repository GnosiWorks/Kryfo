// SPDX-License-Identifier: GPL-3.0-or-later
//go:build windows

package main

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"

	"github.com/cretz/bine/process"
	"github.com/halo/engine/torexe"
	"golang.org/x/sys/windows"
)

// set by build-windows.sh: the sha256 of the tor.exe shipped with the app,
// and "1" in a dev build, which takes any tor.exe
var (
	torExeSHA256 string
	torExeDev    string
)

// no console window flashes up for tor
const createNoWindow = 0x08000000

// same name as the libtor one, so bridge.go builds unchanged
type libtorCreator struct{}

func (libtorCreator) New(ctx context.Context, args ...string) (process.Process, error) {
	exe, err := os.Executable()
	if err != nil {
		return nil, err
	}
	path := torexe.Path(filepath.Dir(exe))
	if err := torexe.Check(path, torExeSHA256, torExeDev == "1"); err != nil {
		return nil, err
	}
	if d := torexe.ArgValue(args, "--DataDirectory"); d != "" {
		stopLeftoverTor(torexe.PidPath(d), path)
	}
	run := process.CmdCreatorFunc(func(ctx context.Context, args ...string) (*exec.Cmd, error) {
		cmd := exec.CommandContext(ctx, path, args...)
		cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: createNoWindow}
		return cmd, nil
	})
	return run.New(ctx, torexe.Args(os.Getpid(), args)...)
}

// a crashed run's tor.exe holds the data dir lock until it sees its owner
// gone, so the next start would fail
func stopLeftoverTor(pidPath, exePath string) {
	pid := torexe.ReadPid(pidPath)
	if pid == 0 || pid == os.Getpid() {
		return
	}
	h, err := windows.OpenProcess(windows.PROCESS_QUERY_LIMITED_INFORMATION|windows.PROCESS_TERMINATE|windows.SYNCHRONIZE, false, uint32(pid))
	if err != nil {
		os.Remove(pidPath)
		return
	}
	defer windows.CloseHandle(h)
	buf := make([]uint16, windows.MAX_LONG_PATH)
	n := uint32(len(buf))
	if windows.QueryFullProcessImageName(h, 0, &buf[0], &n) != nil {
		return
	}
	if !torexe.SameExe(windows.UTF16ToString(buf[:n]), exePath) {
		os.Remove(pidPath)
		return
	}
	if windows.TerminateProcess(h, 1) == nil {
		windows.WaitForSingleObject(h, 5000)
	}
	os.Remove(pidPath)
}

// tor.exe is a process of its own: every start is a fresh one
func torMayLaunch() bool { return true }
