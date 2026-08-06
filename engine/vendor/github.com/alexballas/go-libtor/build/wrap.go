//go:build none
// +build none

package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"text/template"
)

// nobuild can be used to prevent the wrappers from triggering a build after
// each step. This should only be used in production mode when there's a final
// build check outside of the wrapping.
var nobuild = flag.Bool("nobuild", false, "Prevents the wrappers from building")
var genLock = flag.Bool("update", false, "Pulls new commits, if unset the libs commits will be taken from lock.json.")

func main() {
	flag.Parse()
	var lock *lockJson
	var currentLock *lockJson
	if f, err := os.Open("lock.json"); err == nil {
		currentLock = &lockJson{}
		err = json.NewDecoder(f).Decode(currentLock)
		f.Close()
		if err != nil {
			panic(err)
		}
	} else if !os.IsNotExist(err) {
		panic(err)
	}
	if !*genLock {
		if currentLock == nil {
			panic(errors.New("missing lock.json"))
		}
		lock = currentLock
	}

	// TarGeT stores the target to generate, the idea is a target is block of oses
	// compatible with each others (Linux and Android, OSX and IOS)
	var tgt string
	switch runtime.GOOS {
	case "linux", "android":
		tgt = "linux"
	case "darwin":
		tgt = "darwin"
	case "windows":
		tgt = "windows"
	default:
		panic(fmt.Errorf("Sorry but your os : %s is not yet supported.", runtime.GOOS))
	}

	// Clean up any previously generated files
	if _, err := os.Stat("libtor"); !os.IsNotExist(err) && *genLock {
		os.RemoveAll("libtor")
	}
	// Do the same in the target directory
	if _, err := os.Stat(tgt); !os.IsNotExist(err) {
		os.RemoveAll(tgt)
	}
	// Copy in the library preamble with the architecture definitions
	if err := os.MkdirAll("libtor", 0755); err != nil {
		panic(err)
	}
	blob, _ := ioutil.ReadFile(filepath.Join("build", "libtor_preamble.go.in"))
	ioutil.WriteFile(filepath.Join("libtor", "libtor_preamble.go"), blob, 0644)

	// Create target directory
	if err := os.MkdirAll(tgt, 0755); err != nil {
		panic(err)
	}

	// Wrap each of the component libraries into megator
	zlibVer, zlibHash, err := wrapZlib(tgt, lock)
	if err != nil {
		panic(err)
	}
	libeventVer, libeventHash, err := wrapLibevent(tgt, lock)
	if err != nil {
		panic(err)
	}
	opensslVer, opensslHash, err := wrapOpenSSL(tgt, lock)
	if err != nil {
		panic(err)
	}
	torLock := lock
	if *genLock {
		torLock = currentLock
	}
	torVer, torHash, err := wrapTor(tgt, torLock)
	if err != nil {
		panic(err)
	}

	// Copy and fill out the libtor entrypoint wrappers and the readme template.
	blob, _ = ioutil.ReadFile(filepath.Join("build", "libtor_external.go.in"))
	ioutil.WriteFile(filepath.Join("libtor.go"), blob, 0644)
	blob, _ = ioutil.ReadFile(filepath.Join("build", "libtor_internal.go.in"))
	ioutil.WriteFile(filepath.Join("libtor", "libtor.go"), blob, 0644)

	if !*nobuild {
		builder := exec.Command("go", "build", ".")
		builder.Stdout = os.Stdout
		builder.Stderr = os.Stderr

		if err := builder.Run(); err != nil {
			panic(err)
		}
	}

	// Update
	if *genLock {
		if _, err := os.Stat(filepath.Join("build", "README.md")); err == nil {
			tmpl := template.Must(template.ParseFiles(filepath.Join("build", "README.md")))
			buf := new(bytes.Buffer)
			tmpl.Execute(buf, map[string]string{
				"zlibVer":      zlibVer,
				"zlibHash":     zlibHash,
				"libeventVer":  libeventVer,
				"libeventHash": libeventHash,
				"opensslVer":   opensslVer,
				"opensslHash":  opensslHash,
				"torVer":       torVer,
				"torHash":      torHash,
			})
			ioutil.WriteFile("README.md", buf.Bytes(), 0644)
		}
		buff, err := json.Marshal(lockJson{
			Zlib:     zlibHash,
			Libevent: libeventHash,
			Openssl:  opensslHash,
			Tor:      torHash,
		})
		if err != nil {
			panic(err)
		}
		ioutil.WriteFile("lock.json", buff, 0644)
	}
}

type versionTag struct {
	Name       string
	Version    []int
	Prerelease int
}

func listGitTags(repo string, pattern string) ([]string, error) {
	lister := exec.Command("git", "tag", "--list", pattern)
	lister.Dir = repo

	out, err := lister.CombinedOutput()
	if err != nil {
		fmt.Println(string(out))
		return nil, err
	}
	tags := strings.Fields(string(out))
	sort.Strings(tags)

	return tags, nil
}

func parseVersionParts(raw string) ([]int, error) {
	parts := strings.Split(raw, ".")
	version := make([]int, len(parts))

	for i, part := range parts {
		n, err := strconv.Atoi(part)
		if err != nil {
			return nil, err
		}
		version[i] = n
	}
	return version, nil
}

func compareVersionParts(a, b []int) int {
	limit := len(a)
	if len(b) > limit {
		limit = len(b)
	}
	for i := 0; i < limit; i++ {
		var ai, bi int
		if i < len(a) {
			ai = a[i]
		}
		if i < len(b) {
			bi = b[i]
		}
		if ai < bi {
			return -1
		}
		if ai > bi {
			return 1
		}
	}
	return 0
}

func uniqueStrings(items []string) []string {
	seen := make(map[string]struct{}, len(items))
	out := make([]string, 0, len(items))
	for _, item := range items {
		if _, ok := seen[item]; ok {
			continue
		}
		seen[item] = struct{}{}
		out = append(out, item)
	}
	sort.Strings(out)
	return out
}

func containsString(items []string, want string) bool {
	for _, item := range items {
		if item == want {
			return true
		}
	}
	return false
}

func extractLibeventObjects(out string) []string {
	matches := regexp.MustCompile(`(?m)(?:^|[[:space:]])([a-z0-9_]+)\.lo(?:[[:space:];]|$)`).FindAllStringSubmatch(out, -1)
	deps := make([]string, 0, len(matches))
	for _, match := range matches {
		deps = append(deps, match[1])
	}
	return uniqueStrings(deps)
}

func extractOpenSSLSources(out string) []string {
	matches := regexp.MustCompile(`(?m)-c\s+-o\s+(\S+)\s+([A-Za-z0-9_./+-]+)\.c(?:\s|$)`).FindAllStringSubmatch(out, -1)
	deps := make([]string, 0, len(matches))
	for _, match := range matches {
		object := strings.TrimPrefix(match[1], "./")
		if !strings.Contains(object, "libcrypto-lib-") &&
			!strings.Contains(object, "libssl-lib-") &&
			!strings.Contains(object, "libcommon-lib-") &&
			!strings.Contains(object, "libdefault-lib-") {
			continue
		}
		deps = append(deps, strings.TrimPrefix(match[2], "./"))
	}
	return uniqueStrings(deps)
}

func libeventPrereleaseRank(label string) int {
	switch label {
	case "", "stable":
		return 4
	case "rc":
		return 3
	case "beta":
		return 2
	case "alpha", "alpha-dev", "dev":
		return 1
	default:
		return 0
	}
}

func latestZlibTag(repo string) (string, error) {
	tags, err := listGitTags(repo, "v*")
	if err != nil {
		return "", err
	}
	re := regexp.MustCompile(`^v([0-9]+(?:\.[0-9]+)*)$`)

	var best *versionTag
	for _, tag := range tags {
		match := re.FindStringSubmatch(tag)
		if len(match) == 0 {
			continue
		}
		version, err := parseVersionParts(match[1])
		if err != nil {
			return "", err
		}
		candidate := &versionTag{Name: tag, Version: version}
		if best == nil || compareVersionParts(candidate.Version, best.Version) > 0 {
			best = candidate
		}
	}
	if best == nil {
		return "", errors.New("no zlib release tag found")
	}
	return best.Name, nil
}

func latestLibeventTag(repo string) (string, error) {
	tags, err := listGitTags(repo, "release-*")
	if err != nil {
		return "", err
	}
	re := regexp.MustCompile(`^release-([0-9]+(?:\.[0-9]+){2})(?:-([A-Za-z0-9.-]+))?$`)

	var best *versionTag
	for _, tag := range tags {
		match := re.FindStringSubmatch(tag)
		if len(match) == 0 {
			continue
		}
		version, err := parseVersionParts(match[1])
		if err != nil {
			return "", err
		}
		label := strings.ToLower(match[2])
		candidate := &versionTag{
			Name:       tag,
			Version:    version,
			Prerelease: libeventPrereleaseRank(label),
		}
		if best == nil {
			best = candidate
			continue
		}
		if cmp := compareVersionParts(candidate.Version, best.Version); cmp > 0 {
			best = candidate
			continue
		} else if cmp == 0 && candidate.Prerelease > best.Prerelease {
			best = candidate
		}
	}
	if best == nil {
		return "", errors.New("no libevent release tag found")
	}
	return best.Name, nil
}

func latestOpenSSLTag(repo string) (string, error) {
	tags, err := listGitTags(repo, "openssl-*")
	if err != nil {
		return "", err
	}
	re := regexp.MustCompile(`^openssl-([0-9]+(?:\.[0-9]+){2})$`)

	var best *versionTag
	for _, tag := range tags {
		match := re.FindStringSubmatch(tag)
		if len(match) == 0 {
			continue
		}
		version, err := parseVersionParts(match[1])
		if err != nil {
			return "", err
		}
		candidate := &versionTag{Name: tag, Version: version}
		if best == nil || compareVersionParts(candidate.Version, best.Version) > 0 {
			best = candidate
		}
	}
	if best == nil {
		return "", errors.New("no OpenSSL release tag found")
	}
	return best.Name, nil
}

func openSSLVersionData(repo string) (map[string]string, error) {
	blob, err := ioutil.ReadFile(filepath.Join(repo, "VERSION.dat"))
	if err != nil {
		return nil, err
	}
	parse := func(key string) (string, error) {
		re := regexp.MustCompile(`(?m)^` + key + `="?([^"\n]+)"?$`)
		match := re.FindSubmatch(blob)
		if len(match) == 0 {
			return "", fmt.Errorf("could not parse OpenSSL %s", strings.ToLower(key))
		}
		return string(match[1]), nil
	}
	fields := map[string]string{}
	for _, key := range []string{"MAJOR", "MINOR", "PATCH", "SHLIB_VERSION"} {
		value, err := parse(key)
		if err != nil {
			return nil, err
		}
		fields[key] = value
	}
	for _, key := range []string{"PRE_RELEASE_TAG", "BUILD_METADATA", "RELEASE_DATE"} {
		re := regexp.MustCompile(`(?m)^` + key + `="?([^"\n]*)"?$`)
		match := re.FindSubmatch(blob)
		if len(match) == 0 {
			return nil, fmt.Errorf("could not parse OpenSSL %s", strings.ToLower(key))
		}
		fields[key] = string(match[1])
	}
	return fields, nil
}

func openSSLVersion(repo string) (string, error) {
	fields, err := openSSLVersionData(repo)
	if err != nil {
		return "", err
	}
	version := strings.Join([]string{fields["MAJOR"], fields["MINOR"], fields["PATCH"]}, ".")
	if fields["PRE_RELEASE_TAG"] != "" {
		version += fields["PRE_RELEASE_TAG"]
	}
	return version, nil
}

func writeOpenSSLVersionHeader(path string, fields map[string]string) error {
	version := strings.Join([]string{fields["MAJOR"], fields["MINOR"], fields["PATCH"]}, ".")
	fullVersion := version + fields["PRE_RELEASE_TAG"] + fields["BUILD_METADATA"]

	tmpl, err := template.New("").Parse(`/*
 * Generated by go-libtor's wrapper.
 */

#ifndef OPENSSL_OPENSSLV_H
#define OPENSSL_OPENSSLV_H
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#define OPENSSL_VERSION_MAJOR {{.Major}}
#define OPENSSL_VERSION_MINOR {{.Minor}}
#define OPENSSL_VERSION_PATCH {{.Patch}}
#define OPENSSL_VERSION_PRE_RELEASE "{{.PreRelease}}"
#define OPENSSL_VERSION_BUILD_METADATA "{{.BuildMetadata}}"
#define OPENSSL_SHLIB_VERSION {{.ShlibVersion}}
#define OPENSSL_VERSION_PREREQ(maj, min) \
    ((OPENSSL_VERSION_MAJOR << 16) + OPENSSL_VERSION_MINOR >= ((maj) << 16) + (min))
#define OPENSSL_VERSION_STR "{{.Version}}"
#define OPENSSL_FULL_VERSION_STR "{{.FullVersion}}"
#define OPENSSL_RELEASE_DATE "{{.ReleaseDate}}"
#define OPENSSL_VERSION_TEXT "OpenSSL {{.FullVersion}} {{.ReleaseDate}}"
#define OPENSSL_VERSION_NUMBER          \
    ( (OPENSSL_VERSION_MAJOR<<28)        \
      |(OPENSSL_VERSION_MINOR<<20)       \
      |(OPENSSL_VERSION_PATCH<<4)        \
      |0x0L )

#ifdef __cplusplus
}
#endif

#endif
`)
	if err != nil {
		return err
	}
	buff := new(bytes.Buffer)
	if err := tmpl.Execute(buff, map[string]string{
		"Major":         fields["MAJOR"],
		"Minor":         fields["MINOR"],
		"Patch":         fields["PATCH"],
		"PreRelease":    fields["PRE_RELEASE_TAG"],
		"BuildMetadata": fields["BUILD_METADATA"],
		"ShlibVersion":  fields["SHLIB_VERSION"],
		"Version":       version,
		"FullVersion":   fullVersion,
		"ReleaseDate":   fields["RELEASE_DATE"],
	}); err != nil {
		return err
	}
	return ioutil.WriteFile(path, buff.Bytes(), 0644)
}

// targetFilters maps a build target to the builds tags to apply to it
var targetFilters = map[string]string{
	"linux":   "linux || android",
	"darwin":  "(darwin && (amd64 || arm64)) || (ios && (amd64 || arm64))",
	"windows": "windows && (amd64 || 386)",
}

func openSSLConfigureTarget() (string, error) {
	switch runtime.GOOS {
	case "linux":
		switch runtime.GOARCH {
		case "amd64":
			return "linux-x86_64", nil
		case "386":
			return "linux-x86", nil
		case "arm64":
			return "linux-aarch64", nil
		case "arm":
			return "linux-armv4", nil
		}
	case "darwin":
		switch runtime.GOARCH {
		case "amd64":
			return "darwin64-x86_64-cc", nil
		case "arm64":
			return "darwin64-arm64-cc", nil
		}
	case "windows":
		switch runtime.GOARCH {
		case "amd64":
			return "mingw64", nil
		case "386":
			return "mingw", nil
		}
	}
	return "", fmt.Errorf("unsupported OpenSSL configure target for %s/%s", runtime.GOOS, runtime.GOARCH)
}

// lockJson stores the commits for later reuse.
type lockJson struct {
	Zlib     string `json:"zlib"`
	Libevent string `json:"libevent"`
	Openssl  string `json:"openssl"`
	Tor      string `json:"tor"`
}

// wrapZlib clones the zlib library into the local repository and wraps it into
// a Go package.
//
// Zlib is a small and simple C library which can be wrapped by inserting an empty
// Go file among the C sources, causing the Go compiler to pick up all the loose
// sources and build them together into a static library.
func wrapZlib(tgt string, lock *lockJson) (string, string, error) {
	// TarGeT Full
	tgtf := filepath.Join(tgt, "zlib")

	cloner := exec.Command("git", "clone", "https://github.com/madler/zlib")
	cloner.Stdout = os.Stdout
	cloner.Stderr = os.Stderr
	cloner.Dir = tgt

	if err := cloner.Run(); err != nil {
		return "", "", err
	}

	var checkout string
	if lock != nil {
		checkout = lock.Zlib
	} else {
		var err error
		checkout, err = latestZlibTag(tgtf)
		if err != nil {
			return "", "", err
		}
	}
	checkouter := exec.Command("git", "checkout", checkout)
	checkouter.Dir = tgtf

	if err := checkouter.Run(); err != nil {
		return "", "", err
	}

	// Save the latest upstream commit hash for later reference
	parser := exec.Command("git", "rev-parse", "HEAD")
	parser.Dir = tgtf

	commit, err := parser.CombinedOutput()
	if err != nil {
		fmt.Println(string(commit))
		return "", "", err
	}
	commit = bytes.TrimSpace(commit)

	// Retrieve the version of the current commit
	conf, _ := ioutil.ReadFile(filepath.Join(tgtf, "zlib.h"))
	strver := regexp.MustCompile("define ZLIB_VERSION \"(.+)\"").FindSubmatch(conf)[1]

	// Wipe everything from the library that's non-essential
	files, err := ioutil.ReadDir(tgtf)
	if err != nil {
		return "", "", err
	}
	for _, file := range files {
		if file.IsDir() {
			os.RemoveAll(filepath.Join(tgtf, file.Name()))
			continue
		}
		if ext := filepath.Ext(file.Name()); ext != ".h" && ext != ".c" {
			os.Remove(filepath.Join(tgtf, file.Name()))
		}
	}

	// TarGeTFILTer
	tgtFilt := targetFilters[tgt]

	// Generate Go wrappers for each C source individually
	tmpl, err := template.New("").Parse(zlibTemplate)
	if err != nil {
		return "", "", err
	}
	for _, file := range files {
		if file.IsDir() {
			continue
		}
		if ext := filepath.Ext(file.Name()); ext == ".c" {
			name := strings.TrimSuffix(file.Name(), ext)
			buff := new(bytes.Buffer)
			if err := tmpl.Execute(buff, map[string]string{
				"TargetFilter": tgtFilt,
				"File":         name,
			}); err != nil {
				return "", "", err
			}
			ioutil.WriteFile(filepath.Join("libtor", tgt+"_zlib_"+name+".go"), buff.Bytes(), 0644)
		}
	}

	tmpl, err = template.New("").Parse(zlibPreamble)
	if err != nil {
		return "", "", err
	}
	buff := new(bytes.Buffer)
	if err := tmpl.Execute(buff, map[string]string{
		"TargetFilter": tgtFilt,
		"Target":       tgt,
	}); err != nil {
		return "", "", err
	}
	ioutil.WriteFile(filepath.Join("libtor", tgt+"_zlib_preamble.go"), buff.Bytes(), 0644)
	return string(strver), string(commit), nil
}

// zlibPreamble is the CGO preamble injected to configure the C compiler.
var zlibPreamble = `// go-libtor - Self-contained Tor from Go
// Copyright (c) 2018 Péter Szilágyi. All rights reserved.
//go:build {{.TargetFilter}}
// +build {{.TargetFilter}}

package libtor


/*
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/zlib
#cgo CFLAGS: -DHAVE_UNISTD_H -DHAVE_STDARG_H
*/
import "C"
`

// zlibTemplate is the source file template used in zlib Go wrappers.
var zlibTemplate = `// go-libtor - Self-contained Tor from Go
// Copyright (c) 2018 Péter Szilágyi. All rights reserved.
//go:build {{.TargetFilter}}
// +build {{.TargetFilter}}

package libtor

/*
#include <../zlib/{{.File}}.c>
*/
import "C"
`

// wrapLibevent clones the libevent library into the local repository and wraps
// it into a Go package.
//
// Libevent is a fairly straightforward C library, however it heavily relies on
// makefiles to mix-and-match the correct sources for the correct platforms. It
// also relies on autoconf and family to generate platform specific configs.
//
// Since it's not meaningfully feasible to build libevent without the make tools,
// yet that approach cannot create a portable Go library, we're going to hook
// into the original build mechanism and use the emitted events as a driver for
// the Go wrapping.
func wrapLibevent(tgt string, lock *lockJson) (string, string, error) {
	// TarGeT Full
	tgtf := filepath.Join(tgt, "libevent")

	cloner := exec.Command("git", "clone", "https://github.com/libevent/libevent")
	cloner.Stdout = os.Stdout
	cloner.Stderr = os.Stderr
	cloner.Dir = tgt

	if err := cloner.Run(); err != nil {
		return "", "", err
	}

	var checkout string
	if lock != nil {
		checkout = lock.Libevent
	} else {
		var err error
		checkout, err = latestLibeventTag(tgtf)
		if err != nil {
			return "", "", err
		}
	}
	checkouter := exec.Command("git", "checkout", checkout)
	checkouter.Dir = tgtf

	if err := checkouter.Run(); err != nil {
		return "", "", err
	}

	// Save the latest upstream commit hash for later reference
	parser := exec.Command("git", "rev-parse", "HEAD")
	parser.Dir = tgtf

	commit, err := parser.CombinedOutput()
	if err != nil {
		fmt.Println(string(commit))
		return "", "", err
	}
	commit = bytes.TrimSpace(commit)

	// Configure the library for compilation
	autogen := exec.Command("./autogen.sh")
	autogen.Dir = tgtf
	autogen.Stdout = os.Stdout
	autogen.Stderr = os.Stderr

	if err := autogen.Run(); err != nil {
		return "", "", err
	}
	configure := exec.Command("./configure", "--disable-shared", "--enable-static", "--enable-openssl", "--disable-mbedtls",
		"--disable-libevent-regress", "--enable-thread-support", "--disable-samples", "--disable-verbose-debug",
		"--disable-malloc-replacement")
	configure.Dir = tgtf
	configure.Stdout = os.Stdout
	configure.Stderr = os.Stderr

	if err := configure.Run(); err != nil {
		return "", "", err
	}
	// Build and stage libevent locally so Tor can link against it during its
	// configure checks without requiring distro-level libevent-dev packages.
	libeventPrefix, err := filepath.Abs(filepath.Join("builddeps", "libevent"))
	if err != nil {
		return "", "", err
	}
	if err := os.RemoveAll(libeventPrefix); err != nil {
		return "", "", err
	}
	if err := os.MkdirAll(libeventPrefix, 0755); err != nil {
		return "", "", err
	}
	installer := exec.Command("make", fmt.Sprintf("-j%d", runtime.NumCPU()), "install", "DESTDIR="+libeventPrefix)
	installer.Dir = tgtf
	installer.Stdout = os.Stdout
	installer.Stderr = os.Stderr

	if err := installer.Run(); err != nil {
		return "", "", err
	}
	// Retrieve the version of the current commit
	conf, _ := ioutil.ReadFile(filepath.Join(tgtf, "configure.ac"))
	numver := regexp.MustCompile("AC_DEFINE\\(NUMERIC_VERSION, (0x[0-9a-z]{8}),").FindSubmatch(conf)[1]
	strver := regexp.MustCompile("AC_INIT\\(libevent,(.+)\\)").FindSubmatch(conf)[1]

	// Hook the make system and gather the needed sources
	maker := exec.Command("make", "--dry-run", "libevent.la")
	maker.Dir = tgtf

	out, err := maker.CombinedOutput()
	if err != nil {
		fmt.Println(string(out))
		return "", "", err
	}
	deps := extractLibeventObjects(string(out))
	if len(deps) == 0 {
		return "", "", errors.New("failed to detect libevent object files from make --dry-run output")
	}
	if containsString(deps, "ws") {
		if _, err := os.Stat(filepath.Join(tgtf, "sha1.c")); err == nil && !containsString(deps, "sha1") {
			deps = append(deps, "sha1")
			sort.Strings(deps)
		} else if err != nil && !os.IsNotExist(err) {
			return "", "", err
		}
	}

	// Wipe everything from the library that's non-essential
	files, err := ioutil.ReadDir(tgtf)
	if err != nil {
		return "", "", err
	}
	for _, file := range files {
		// Remove all folders apart from the headers
		if file.IsDir() {
			if file.Name() == "include" || file.Name() == "compat" {
				continue
			}
			os.RemoveAll(filepath.Join(tgtf, file.Name()))
			continue
		}
		// Remove all files apart from the sources and license
		if file.Name() == "LICENSE" {
			continue
		}
		if ext := filepath.Ext(file.Name()); ext != ".h" && ext != ".c" {
			os.Remove(filepath.Join(tgtf, file.Name()))
		}
	}

	// TarGeTFILTer
	tgtFilt := targetFilters[tgt]

	// Generate Go wrappers for each C source individually
	tmpl, err := template.New("").Parse(libeventTemplate)
	if err != nil {
		return "", "", err
	}
	for _, dep := range deps {
		buff := new(bytes.Buffer)
		if err := tmpl.Execute(buff, map[string]string{
			"TargetFilter": tgtFilt,
			"File":         dep,
		}); err != nil {
			return "", "", err
		}
		ioutil.WriteFile(filepath.Join("libtor", tgt+"_libevent_"+dep+".go"), buff.Bytes(), 0644)
	}
	tmpl, err = template.New("").Parse(libeventPreamble)
	if err != nil {
		return "", "", err
	}
	buff := new(bytes.Buffer)
	if err := tmpl.Execute(buff, map[string]string{
		"TargetFilter": tgtFilt,
		"Target":       tgt,
	}); err != nil {
		return "", "", err
	}
	ioutil.WriteFile(filepath.Join("libtor", tgt+"_libevent_preamble.go"), buff.Bytes(), 0644)

	// Inject the configuration headers and ensure everything builds
	os.MkdirAll(filepath.Join("libevent_config", "event2"), 0755)

	for _, arch := range []string{"", ".linux64", ".linux32", ".android64", ".android32", ".macos64", ".ios64", ".windows32", ".windows64"} {
		blob, _ := ioutil.ReadFile(filepath.Join("config", "libevent", fmt.Sprintf("event-config%s.h", arch)))
		tmpl, err := template.New("").Parse(string(blob))
		if err != nil {
			return "", "", err
		}
		buff := new(bytes.Buffer)
		if err := tmpl.Execute(buff, struct{ NumVer, StrVer string }{string(numver), string(strver)}); err != nil {
			return "", "", err
		}
		ioutil.WriteFile(filepath.Join("libevent_config", "event2", fmt.Sprintf("event-config%s.h", arch)), buff.Bytes(), 0644)
	}
	return string(strver), string(commit), nil
}

// libeventPreamble is the CGO preamble injected to configure the C compiler.
var libeventPreamble = `// go-libtor - Self-contained Tor from Go
// Copyright (c) 2018 Péter Szilágyi. All rights reserved.
//go:build {{.TargetFilter}}
// +build {{.TargetFilter}}

package libtor

/*
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/libevent
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/libevent/compat
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/libevent/include
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/libevent/include/event2
#cgo windows LDFLAGS: -lbcrypt
*/
import "C"
`

// libeventTemplate is the source file template used in libevent Go wrappers.
var libeventTemplate = `// go-libtor - Self-contained Tor from Go
// Copyright (c) 2018 Péter Szilágyi. All rights reserved.
//go:build {{.TargetFilter}}
// +build {{.TargetFilter}}

package libtor

/*
#include <event2/event-config.h>
#include <evconfig-private.h>
#include <compat/sys/queue.h>
#if !defined(BIG_ENDIAN) && !defined(LITTLE_ENDIAN)
#if defined(__BYTE_ORDER__) && (__BYTE_ORDER__ == __ORDER_BIG_ENDIAN__)
#define BIG_ENDIAN 1
#else
#define LITTLE_ENDIAN 1
#endif
#endif
#include <../{{.File}}.c>
*/
import "C"
`

// wrapOpenSSL clones the OpenSSL library into the local repository and wraps
// it into a Go package.
//
// OpenSSL is a fairly complex C library, heavily relying on makefiles to mix-
// and-match the correct sources for the correct platforms and it also relies on
// platform specific assembly sources for more performant builds.
//
// Since it's not meaningfully feasible to build OpenSSL without the make tools,
// yet that approach cannot create a portable Go library, we're going to hook
// into the original build mechanism and use the emitted events as a driver for
// the Go wrapping.
//
// In addition, assembly is disabled altogether to retain Go's portability. This
// is a downside we unfortunately have to live with for now.
func wrapOpenSSL(tgt string, lock *lockJson) (string, string, error) {
	// TarGeT Full
	tgtf := filepath.Join(tgt, "openssl")

	cloner := exec.Command("git", "clone", "https://github.com/openssl/openssl")
	cloner.Stdout = os.Stdout
	cloner.Stderr = os.Stderr
	cloner.Dir = tgt

	if err := cloner.Run(); err != nil {
		return "", "", err
	}

	var checkout string
	if lock != nil {
		checkout = lock.Openssl
	} else {
		var err error
		checkout, err = latestOpenSSLTag(tgtf)
		if err != nil {
			return "", "", err
		}
	}
	switcher := exec.Command("git", "checkout", checkout)
	switcher.Dir = tgtf

	if out, err := switcher.CombinedOutput(); err != nil {
		fmt.Println(string(out))
		return "", "", err
	}
	// Save the latest upstream commit hash for later reference
	parser := exec.Command("git", "rev-parse", "HEAD")
	parser.Dir = tgtf

	commit, err := parser.CombinedOutput()
	if err != nil {
		fmt.Println(string(commit))
		return "", "", err
	}
	commit = bytes.TrimSpace(commit)

	//Save the latest
	timer := exec.Command("git", "show", "-s", "--format=%cd")
	timer.Dir = tgtf

	date, err := timer.CombinedOutput()
	if err != nil {
		fmt.Println(string(date))
		return "", "", err
	}
	date = bytes.TrimSpace(date)

	versionData, err := openSSLVersionData(tgtf)
	if err != nil {
		return "", "", err
	}
	strver := strings.Join([]string{versionData["MAJOR"], versionData["MINOR"], versionData["PATCH"]}, ".")
	if versionData["PRE_RELEASE_TAG"] != "" {
		strver += versionData["PRE_RELEASE_TAG"]
	}

	// Configure the library for compilation.
	opensslTarget, err := openSSLConfigureTarget()
	if err != nil {
		return "", "", err
	}
	config := exec.Command("./Configure", opensslTarget, "no-shared", "no-zlib", "no-asm", "no-async", "no-sctp")
	config.Dir = tgtf
	config.Stdout = os.Stdout
	config.Stderr = os.Stderr

	if err := config.Run(); err != nil {
		return "", "", err
	}
	generator := exec.Command("make", "build_generated")
	generator.Dir = tgtf
	generator.Stdout = os.Stdout
	generator.Stderr = os.Stderr

	if err := generator.Run(); err != nil {
		return "", "", err
	}
	// Hook the make system and gather the needed sources
	maker := exec.Command("make", "--dry-run")
	maker.Dir = tgtf

	out, err := maker.CombinedOutput()
	if err != nil {
		fmt.Println(string(out))
		return "", "", err
	}
	deps := extractOpenSSLSources(string(out))
	if len(deps) == 0 {
		return "", "", errors.New("failed to detect openssl source files from make --dry-run output")
	}
	var generatedDeps []string
	for _, dep := range deps {
		source := filepath.Join(tgtf, dep+".c")
		if _, err := os.Stat(source); err == nil {
			continue
		}
		if !os.IsNotExist(err) {
			return "", "", err
		}
		if _, err := os.Stat(filepath.Join(tgtf, dep+".c.in")); err == nil {
			generatedDeps = append(generatedDeps, dep+".c")
		} else if !os.IsNotExist(err) {
			return "", "", err
		}
	}
	if len(generatedDeps) > 0 {
		sort.Strings(generatedDeps)
		generator := exec.Command("make", generatedDeps...)
		generator.Dir = tgtf
		generator.Stdout = os.Stdout
		generator.Stderr = os.Stderr

		if err := generator.Run(); err != nil {
			return "", "", err
		}
	}

	// Wipe everything from the library that's non-essential
	files, err := ioutil.ReadDir(tgtf)
	if err != nil {
		return "", "", err
	}
	for _, file := range files {
		// Remove all folders apart from the headers
		if file.IsDir() {
			if file.Name() == "crypto" || file.Name() == "engines" || file.Name() == "include" || file.Name() == "providers" || file.Name() == "ssl" {
				continue
			}
			os.RemoveAll(filepath.Join(tgtf, file.Name()))
			continue
		}
		// Remove all files apart from the license and sources
		if file.Name() == "LICENSE" {
			continue
		}
		if ext := filepath.Ext(file.Name()); ext != ".h" && ext != ".c" {
			os.Remove(filepath.Join(tgtf, file.Name()))
		}
	}

	// TarGeTFILTer
	tgtFilt := targetFilters[tgt]

	// Generate Go wrappers for each C source individually
	tmpl, err := template.New("").Parse(opensslTemplate)
	if err != nil {
		return "", "", err
	}
	wrapperCount := 0
	for _, dep := range deps {
		// Skip any files not needed for the library
		if strings.HasPrefix(dep, "apps/") {
			continue
		}
		if strings.HasPrefix(dep, "fuzz/") {
			continue
		}
		if strings.HasPrefix(dep, "test/") {
			continue
		}
		if strings.HasSuffix(dep, "_test") {
			continue
		}
		// Anything else is wrapped directly with Go
		gofile := strings.Replace(dep, "/", "_", -1) + ".go"
		buff := new(bytes.Buffer)
		if err := tmpl.Execute(buff, map[string]string{
			"TargetFilter": tgtFilt,
			"File":         dep,
		}); err != nil {
			return "", "", err
		}
		if err := ioutil.WriteFile(filepath.Join("libtor", tgt+"_openssl_"+gofile), buff.Bytes(), 0644); err != nil {
			return "", "", err
		}
		wrapperCount++
	}
	if wrapperCount == 0 {
		return "", "", errors.New("no openssl wrapper files generated after filtering")
	}
	tmpl, err = template.New("").Parse(opensslPreamble)
	if err != nil {
		return "", "", err
	}
	buff := new(bytes.Buffer)
	if err := tmpl.Execute(buff, map[string]string{
		"TargetFilter": tgtFilt,
		"Target":       tgt,
	}); err != nil {
		return "", "", err
	}
	if err := ioutil.WriteFile(filepath.Join("libtor", tgt+"_openssl_preamble.go"), buff.Bytes(), 0644); err != nil {
		return "", "", err
	}

	// Inject the configuration headers and ensure everything builds.
	if err := os.RemoveAll("openssl_config"); err != nil {
		return "", "", err
	}
	os.MkdirAll(filepath.Join("openssl_config", "crypto"), 0755)
	os.MkdirAll(filepath.Join("openssl_config", "openssl"), 0755)

	for _, arch := range []string{"", ".linux", ".darwin", ".windows"} {
		blob, _ := ioutil.ReadFile(filepath.Join("config", "openssl", fmt.Sprintf("dso_conf%s.h", arch)))
		ioutil.WriteFile(filepath.Join("openssl_config", "crypto", fmt.Sprintf("dso_conf%s.h", arch)), blob, 0644)
	}

	for _, arch := range []string{"", ".x64", ".x86"} {
		blob, _ := ioutil.ReadFile(filepath.Join("config", "openssl", fmt.Sprintf("bn_conf%s.h", arch)))
		ioutil.WriteFile(filepath.Join("openssl_config", "crypto", fmt.Sprintf("bn_conf%s.h", arch)), blob, 0644)
	}
	for _, arch := range []string{"", ".x64", ".x86", ".macos64", ".ios64", ".windows32", ".windows64"} {
		blob, _ := ioutil.ReadFile(filepath.Join("config", "openssl", fmt.Sprintf("buildinf%s.h", arch)))
		tmpl, err := template.New("").Parse(string(blob))
		if err != nil {
			return "", "", err
		}
		buff := new(bytes.Buffer)
		if err := tmpl.Execute(buff, struct{ Date string }{string(date)}); err != nil {
			return "", "", err
		}
		ioutil.WriteFile(filepath.Join("openssl_config", fmt.Sprintf("buildinf%s.h", arch)), buff.Bytes(), 0644)
	}

	if _, err := os.Stat(filepath.Join(tgtf, "include", "openssl", "configuration.h")); err == nil {
		blob, err := ioutil.ReadFile(filepath.Join(tgtf, "include", "openssl", "opensslconf.h"))
		if err != nil {
			return "", "", err
		}
		if err := ioutil.WriteFile(filepath.Join("openssl_config", "openssl", "opensslconf.h"), blob, 0644); err != nil {
			return "", "", err
		}
		blob, err = ioutil.ReadFile(filepath.Join(tgtf, "include", "openssl", "configuration.h"))
		if err != nil {
			return "", "", err
		}
		if err := ioutil.WriteFile(filepath.Join("openssl_config", "openssl", "configuration.h"), blob, 0644); err != nil {
			return "", "", err
		}
		if err := writeOpenSSLVersionHeader(filepath.Join("openssl_config", "openssl", "opensslv.h"), versionData); err != nil {
			return "", "", err
		}
	} else {
		for _, arch := range []string{"", ".x64", ".x86", ".macos64", ".ios64", ".windows32", ".windows64"} {
			blob, _ := ioutil.ReadFile(filepath.Join("config", "openssl", fmt.Sprintf("opensslconf%s.h", arch)))
			ioutil.WriteFile(filepath.Join("openssl_config", "openssl", fmt.Sprintf("opensslconf%s.h", arch)), blob, 0644)
		}
	}
	return string(strver), string(commit), nil
}

// opensslPreamble is the CGO preamble injected to configure the C compiler.
var opensslPreamble = `// go-libtor - Self-contained Tor from Go
// Copyright (c) 2018 Péter Szilágyi. All rights reserved.
//go:build {{.TargetFilter}}
// +build {{.TargetFilter}}

package libtor

/*
#cgo CFLAGS: -I${SRCDIR}/../openssl_config
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/openssl
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/openssl/include
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/openssl/crypto/ec/curve448
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/openssl/crypto/ec/curve448/arch_32
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/openssl/crypto/modes
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/openssl/include/openssl
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/openssl/providers/common/include
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/openssl/providers/fips/include
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/openssl/providers/implementations/include
#cgo CFLAGS: -include ${SRCDIR}/../openssl_config/gotor_extra.h
*/
import "C"
`

// opensslTemplate is the source file template used in OpenSSL Go wrappers.
var opensslTemplate = `// go-libtor - Self-contained Tor from Go
// Copyright (c) 2018 Péter Szilágyi. All rights reserved.
//go:build {{.TargetFilter}}
// +build {{.TargetFilter}}

package libtor

/*
#define DSO_NONE
#define OPENSSLDIR "/usr/local/ssl"
#define ENGINESDIR "/usr/local/lib/engines"

#include <../{{.File}}.c>
*/
import "C"
`

// wrapTor clones the Tor library into the local repository and wraps it into a
// Go package.
func wrapTor(tgt string, lock *lockJson) (string, string, error) {
	// TarGeT Full
	tgtf := filepath.Join(tgt, "tor")

	cloner := exec.Command("git", "clone", "https://git.torproject.org/tor.git")
	cloner.Stdout = os.Stdout
	cloner.Stderr = os.Stderr
	cloner.Dir = tgt

	if err := cloner.Run(); err != nil {
		return "", "", err
	}

	var checkout string
	// If we have a commit lock, checkout these commits.
	if lock != nil {
		checkout = lock.Tor
	} else {
		checkout = "release-0.4.6"
	}
	checkouter := exec.Command("git", "checkout", checkout)
	checkouter.Dir = tgtf

	if err := checkouter.Run(); err != nil {
		return "", "", err
	}
	// Save the latest upstream commit hash for later reference
	parser := exec.Command("git", "rev-parse", "HEAD")
	parser.Dir = tgtf

	commit, err := parser.CombinedOutput()
	if err != nil {
		fmt.Println(string(commit))
		return "", "", err
	}
	commit = bytes.TrimSpace(commit)

	// Configure the library for compilation
	autogen := exec.Command("./autogen.sh")
	autogen.Dir = tgtf
	autogen.Stdout = os.Stdout
	autogen.Stderr = os.Stderr

	if err := autogen.Run(); err != nil {
		return "", "", err
	}
	libeventPrefix, err := filepath.Abs(filepath.Join("builddeps", "libevent", "usr", "local"))
	if err != nil {
		return "", "", err
	}
	configure := exec.Command("./configure", "--disable-asciidoc", "--disable-seccomp",
		"--disable-libscrypt", "--disable-lzma", "--disable-zstd", "--disable-systemd",
		"--with-libevent-dir="+libeventPrefix)
	configure.Dir = tgtf
	configure.Stdout = os.Stdout
	configure.Stderr = os.Stderr
	configure.Env = append(os.Environ(),
		"PKG_CONFIG_PATH="+filepath.Join(libeventPrefix, "lib", "pkgconfig"),
		"CFLAGS=-I"+filepath.Join(libeventPrefix, "include"),
		"LDFLAGS=-L"+filepath.Join(libeventPrefix, "lib"),
	)

	if err := configure.Run(); err != nil {
		return "", "", err
	}
	// Retrieve the configured Tor version from the generated top-level header.
	orconf, _ := ioutil.ReadFile(filepath.Join(tgtf, "orconfig.h"))
	strver := regexp.MustCompile("define VERSION \"(.+)\"").FindSubmatch(orconf)[1]
	hasModulePow := regexp.MustCompile(`(?m)^#define HAVE_MODULE_POW 1$`).Match(orconf)

	// Hook the make system and gather the needed sources
	maker := exec.Command("make", "--dry-run")
	maker.Dir = tgtf

	out, err := maker.CombinedOutput()
	if err != nil {
		fmt.Println(string(out))
		return "", "", err
	}
	deps := regexp.MustCompile("(?m)([a-z0-9_/-]+)\\.c").FindAllStringSubmatch(string(out), -1)

	// Wipe everything from the library that's non-essential
	files, err := ioutil.ReadDir(tgtf)
	if err != nil {
		return "", "", err
	}
	for _, file := range files {
		// Remove all folders apart from the sources
		if file.IsDir() {
			if file.Name() == "src" {
				continue
			}
			os.RemoveAll(filepath.Join(tgtf, file.Name()))
			continue
		}
		// Remove all files apart from the license
		if file.Name() == "LICENSE" {
			continue
		}
		os.Remove(filepath.Join(tgtf, file.Name()))
	}
	// Wipe all the sources from the library that are non-essential
	files, err = ioutil.ReadDir(filepath.Join(tgtf, "src"))
	if err != nil {
		return "", "", err
	}
	for _, file := range files {
		if file.IsDir() {
			if file.Name() == "app" || file.Name() == "core" || file.Name() == "ext" || file.Name() == "feature" || file.Name() == "lib" || file.Name() == "trunnel" || file.Name() == "win32" {
				continue
			}
			os.RemoveAll(filepath.Join(tgtf, "src", file.Name()))
			continue
		}
		os.Remove(filepath.Join(tgtf, "src", file.Name()))
	}
	// Wipe all the weird .Po files containing dummies
	if err := filepath.Walk(filepath.Join(tgtf, "src"),
		func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			if filepath.Base(path) == ".deps" {
				os.RemoveAll(path)
				return filepath.SkipDir
			}
			return nil
		},
	); err != nil {
		return "", "", err
	}

	// TarGeTFILTer
	tgtFilt := targetFilters[tgt]

	tmpl, err := template.New("").Parse(torTemplate)
	if err != nil {
		return "", "", err
	}
	for _, dep := range deps {
		// Skip any files not needed for the library
		if strings.HasPrefix(dep[1], "src/ext/tinytest") {
			continue
		}
		if strings.HasPrefix(dep[1], "src/test/") {
			continue
		}
		if strings.HasPrefix(dep[1], "src/tools/") {
			continue
		}
		if dep[1] == "src/feature/hs/hs_pow" && !hasModulePow {
			continue
		}
		// Skip the main tor entry point, we're wrapping a lib
		if strings.HasSuffix(dep[1], "tor_main") {
			continue
		}
		// The donna crypto library needs architecture specific linking
		if strings.HasSuffix(dep[1], "-c64") {
			for _, arch := range []string{"amd64", "arm64"} {
				gofile := strings.Replace(dep[1], "/", "_", -1) + "_" + arch + ".go"
				buff := new(bytes.Buffer)
				if err := tmpl.Execute(buff, map[string]string{
					"TargetFilter": tgtFilt,
					"File":         dep[1],
				}); err != nil {
					return "", "", err
				}
				ioutil.WriteFile(filepath.Join("libtor", tgt+"_tor_"+gofile), buff.Bytes(), 0644)
			}
			for _, arch := range []string{"386", "arm"} {
				gofile := strings.Replace(dep[1], "/", "_", -1) + "_" + arch + ".go"
				buff := new(bytes.Buffer)
				if err := tmpl.Execute(buff, map[string]string{
					"TargetFilter": tgtFilt,
					"File":         strings.Replace(dep[1], "-c64", "", -1),
				}); err != nil {
					return "", "", err
				}
				ioutil.WriteFile(filepath.Join("libtor", tgt+"_tor_"+gofile), buff.Bytes(), 0644)
			}
			continue
		}
		// Anything else gets wrapped directly
		gofile := strings.Replace(dep[1], "/", "_", -1) + ".go"
		buff := new(bytes.Buffer)
		if err := tmpl.Execute(buff, map[string]string{
			"TargetFilter": tgtFilt,
			"File":         dep[1],
		}); err != nil {
			return "", "", err
		}
		ioutil.WriteFile(filepath.Join("libtor", tgt+"_tor_"+gofile), buff.Bytes(), 0644)
	}
	tmpl, err = template.New("").Parse(torPreamble)
	if err != nil {
		return "", "", err
	}
	buff := new(bytes.Buffer)
	if err := tmpl.Execute(buff, map[string]string{
		"TargetFilter": tgtFilt,
		"Target":       tgt,
	}); err != nil {
		return "", "", err
	}
	ioutil.WriteFile(filepath.Join("libtor", tgt+"_tor_preamble.go"), buff.Bytes(), 0644)

	// Inject the configuration headers and ensure everything builds
	os.MkdirAll(filepath.Join("tor_config"), 0755)

	for _, arch := range []string{"", ".linux64", ".linux32", ".android64", ".android32", ".macos64", ".ios64", ".windows64", ".windows32"} {
		blob, _ := ioutil.ReadFile(filepath.Join("config", "tor", fmt.Sprintf("orconfig%s.h", arch)))
		tmpl, err := template.New("").Parse(string(blob))
		if err != nil {
			return "", "", err
		}
		buff := new(bytes.Buffer)
		if err := tmpl.Execute(buff, struct{ StrVer string }{string(strver)}); err != nil {
			return "", "", err
		}
		ioutil.WriteFile(filepath.Join("tor_config", fmt.Sprintf("orconfig%s.h", arch)), buff.Bytes(), 0644)
	}
	blob, _ := ioutil.ReadFile(filepath.Join("config", "tor", "micro-revision.i"))
	ioutil.WriteFile(filepath.Join("tor_config", "micro-revision.i"), blob, 0644)
	return string(strver), string(commit), nil
}

// torPreamble is the CGO preamble injected to configure the C compiler.
var torPreamble = `// go-libtor - Self-contained Tor from Go
// Copyright (c) 2018 Péter Szilágyi. All rights reserved.
//go:build {{.TargetFilter}}
// +build {{.TargetFilter}}

package libtor

/*
#cgo CFLAGS: -I${SRCDIR}/../tor_config
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/tor
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/tor/src
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/tor/src/core/or
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/tor/src/ext
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/tor/src/ext/equix/include
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/tor/src/ext/equix/src
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/tor/src/ext/equix/hashx/include
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/tor/src/ext/equix/hashx/src
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/tor/src/ext/trunnel
#cgo CFLAGS: -I${SRCDIR}/../{{.Target}}/tor/src/feature/api

#cgo CFLAGS: -D_GNU_SOURCE
#cgo CFLAGS: -Wno-deprecated-declarations
#cgo CFLAGS: -DED25519_CUSTOMRANDOM -DED25519_CUSTOMHASH -DED25519_SUFFIX=_donna
#cgo CFLAGS: -include ${SRCDIR}/../tor_config/gotor_extra.h

#cgo LDFLAGS: -lm
#cgo windows LDFLAGS: -lshlwapi
*/
import "C"
`

// torTemplate is the source file template used in Tor Go wrappers.
var torTemplate = `// go-libtor - Self-contained Tor from Go
// Copyright (c) 2018 Péter Szilágyi. All rights reserved.
//go:build {{.TargetFilter}}
// +build {{.TargetFilter}}

package libtor

/*
#define BUILDDIR ""

#include <../{{.File}}.c>
*/
import "C"
`
