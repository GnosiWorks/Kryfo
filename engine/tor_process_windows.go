// SPDX-License-Identifier: GPL-3.0-or-later
//go:build windows

package main

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"unsafe"

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
		cmd.Env = torexe.Env(os.Environ(), filepath.Dir(path))
		cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: createNoWindow}
		if sa := torProcessAttrs(); sa != nil {
			cmd.SysProcAttr.ProcessAttributes = sa
		}
		return cmd, nil
	})
	return run.New(ctx, torexe.Args(os.Getpid(), args)...)
}

// the security attributes tor.exe is made with (torexe.ProcessSDDL). nil
// when the user's sid cannot be read: tor then gets windows' default
func torProcessAttrs() *syscall.SecurityAttributes {
	tu, err := windows.GetCurrentProcessToken().GetTokenUser()
	if err != nil {
		return nil
	}
	sd, err := windows.SecurityDescriptorFromString(torexe.ProcessSDDL(tu.User.Sid.String()))
	if err != nil {
		return nil
	}
	sa := &syscall.SecurityAttributes{SecurityDescriptor: uintptr(unsafe.Pointer(sd))}
	sa.Length = uint32(unsafe.Sizeof(*sa))
	// the attributes hold the descriptor as a bare address: kept here so
	// the collector never frees one before tor.exe is made. a few per run
	torSDs = append(torSDs, sd)
	return sa
}

var torSDs []*windows.SECURITY_DESCRIPTOR

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
