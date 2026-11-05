// SPDX-License-Identifier: GPL-3.0-or-later
//go:build windows

package main

import (
	"context"
	"errors"
	"log"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"syscall"
	"time"
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
	dir := torexe.ArgValue(args, "--DataDirectory")
	if dir != "" {
		stopLeftoverTor(torexe.PidPath(dir), path)
		// one whose pid file is gone, or from another copy of the app on
		// the same folder: found by its command line
		stopToursOn(dir)
	}
	cmd := exec.CommandContext(ctx, path, torexe.Args(os.Getpid(), args)...)
	cmd.Env = torexe.Env(os.Environ(), filepath.Dir(path))
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: createNoWindow}
	if sa := torProcessAttrs(); sa != nil {
		cmd.SysProcAttr.ProcessAttributes = sa
	}
	tail := &torexe.Tail{}
	cmd.Stdout = tail
	return &torProc{
		Cmd:      cmd,
		tail:     tail,
		dir:      dir,
		portFile: torexe.ArgValue(args, "--ControlPortWriteToFile"),
	}, nil
}

// tor.exe in kryfo's job, and a start that says why it failed
type torProc struct {
	*exec.Cmd
	tail     *torexe.Tail
	dir      string
	portFile string
}

func (p *torProc) EmbeddedControlConn() (net.Conn, error) {
	return nil, process.ErrControlConnUnsupported
}

func (p *torProc) Start() error {
	if err := p.Cmd.Start(); err != nil {
		why := "tor.exe did not start"
		var errno syscall.Errno
		if errors.As(err, &errno) {
			why = torexe.StartReason(uintptr(errno))
		}
		return p.failed(why)
	}
	h, err := windows.OpenProcess(windows.SYNCHRONIZE|windows.PROCESS_QUERY_LIMITED_INFORMATION|
		windows.PROCESS_SET_QUOTA|windows.PROCESS_TERMINATE, false, uint32(p.Process.Pid))
	if err != nil {
		log.Printf("tor.exe: no handle to it: %v", err)
		return nil
	}
	defer windows.CloseHandle(h)
	joinTorJob(h)
	return p.untilUp(h)
}

// up once its control port is written; an exit before that is the start's
// error, with tor's reason. bine itself waits only two seconds, and tor
// waits five on a held lock before it gives up
func (p *torProc) untilUp(h windows.Handle) error {
	if p.portFile == "" {
		return nil
	}
	for end := time.Now().Add(15 * time.Second); time.Now().Before(end); {
		if b, err := os.ReadFile(p.portFile); err == nil {
			if _, err := process.ControlPortFromFileContents(string(b)); err == nil {
				os.Remove(startNote(p.dir))
				return nil
			}
		}
		if ev, _ := windows.WaitForSingleObject(h, 200); ev == windows.WAIT_OBJECT_0 {
			var code uint32
			windows.GetExitCodeProcess(h, &code)
			// bine never waits on a process whose start failed
			p.Cmd.Wait()
			return p.failed(torexe.Reason(p.tail.Lines(), code))
		}
	}
	return nil
}

// the reason goes back as the start's error and into tor-start.txt in
// tor's folder, a line the user can read without a debug build
func (p *torProc) failed(why string) error {
	log.Printf("tor.exe: %s", why)
	if p.dir != "" {
		line := time.Now().Format(time.RFC3339) + " " + why + "\r\n"
		os.WriteFile(startNote(p.dir), []byte(line), 0600)
	}
	return errors.New(why)
}

func startNote(dir string) string {
	return filepath.Join(dir, "tor-start.txt")
}

// one job for every tor.exe of this run, with kill on close: the handle is
// never closed, so windows ends tor when kryfo.exe ends, however it ends
var torJob struct {
	once sync.Once
	h    windows.Handle
}

func joinTorJob(proc windows.Handle) {
	torJob.once.Do(func() {
		j, err := windows.CreateJobObject(nil, nil)
		if err != nil {
			log.Printf("tor.exe: no job: %v", err)
			return
		}
		var info windows.JOBOBJECT_EXTENDED_LIMIT_INFORMATION
		info.BasicLimitInformation.LimitFlags = windows.JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
		if _, err := windows.SetInformationJobObject(j, windows.JobObjectExtendedLimitInformation,
			uintptr(unsafe.Pointer(&info)), uint32(unsafe.Sizeof(info))); err != nil {
			log.Printf("tor.exe: job limits refused: %v", err)
			windows.CloseHandle(j)
			return
		}
		torJob.h = j
	})
	if torJob.h == 0 {
		return
	}
	if err := windows.AssignProcessToJobObject(torJob.h, proc); err != nil {
		log.Printf("tor.exe: not in the job: %v", err)
	}
}

// every tor.exe of this user whose command line names this data folder is
// ended: only one tor can hold it, and kryfo holds the folder. another
// program's tor has its own folder and is never touched
func stopToursOn(dataDir string) {
	snap, err := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPPROCESS, 0)
	if err != nil {
		return
	}
	defer windows.CloseHandle(snap)
	var e windows.ProcessEntry32
	e.Size = uint32(unsafe.Sizeof(e))
	for err := windows.Process32First(snap, &e); err == nil; err = windows.Process32Next(snap, &e) {
		if strings.EqualFold(windows.UTF16ToString(e.ExeFile[:]), "tor.exe") {
			stopIfOn(e.ProcessID, dataDir)
		}
	}
}

func stopIfOn(pid uint32, dataDir string) {
	h, err := windows.OpenProcess(windows.PROCESS_QUERY_LIMITED_INFORMATION|windows.PROCESS_TERMINATE|
		windows.SYNCHRONIZE, false, pid)
	if err != nil {
		// another user's, or one this user may not touch
		return
	}
	defer windows.CloseHandle(h)
	args, ok := commandLineOf(h)
	if !ok || !torexe.ForDataDir(args, dataDir) {
		return
	}
	log.Printf("tor.exe: ending a leftover tor on this data folder")
	if windows.TerminateProcess(h, 1) == nil {
		windows.WaitForSingleObject(h, 5000)
	}
}

// another process's command line, with query limited information only
func commandLineOf(h windows.Handle) ([]string, bool) {
	n := uint32(4096)
	for i := 0; i < 4; i++ {
		buf := make([]byte, n)
		var need uint32
		err := windows.NtQueryInformationProcess(h, windows.ProcessCommandLineInformation,
			unsafe.Pointer(&buf[0]), n, &need)
		if err == nil {
			s := (*windows.NTUnicodeString)(unsafe.Pointer(&buf[0])).String()
			runtime.KeepAlive(buf)
			args, err := windows.DecomposeCommandLine(s)
			return args, err == nil
		}
		if need <= n {
			return nil, false
		}
		n = need
	}
	return nil, false
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
