# go-libtor

[![PkgGoDev](https://pkg.go.dev/badge/github.com/alexballas/go-libtor)](https://pkg.go.dev/github.com/alexballas/go-libtor)

`go-libtor` embeds Tor and its C dependencies directly into a Go build. The result is a self-contained Go package that can start an in-process Tor instance through CGO, without requiring a system Tor installation.

> **Linux-only.** This fork supports Linux and Android targets only. macOS, iOS, and Windows support has been removed.

This repository is a maintained fork of `gen2brain/go-libtor`. The current module path is:

```text
github.com/alexballas/go-libtor
```

Local maintenance notes for vendored-source patches live in [`PATCHES.md`](PATCHES.md).

## Bundled upstreams

| Library | Version | Commit |
| :- | :- | :- |
| zlib | 1.3.2 | [`da607da739fa6047df13e66a2af6b8bec7c2a498`](https://github.com/madler/zlib/commit/da607da739fa6047df13e66a2af6b8bec7c2a498) |
| libevent | 2.2.1-alpha-dev | [`fe9dc8f614db0520027e8e2adb95769193d4f0a3`](https://github.com/libevent/libevent/commit/fe9dc8f614db0520027e8e2adb95769193d4f0a3) |
| OpenSSL | 3.6.3 | [`aae016bfd52fcad2bc9657c2c782cfdf73b1ed5f`](https://github.com/openssl/openssl/commit/aae016bfd52fcad2bc9657c2c782cfdf73b1ed5f) |
| Tor | 0.4.9.12 | [`78923280eed3eff6a77910bba59ecc1fa2244e02`](https://gitlab.torproject.org/tpo/core/tor/-/commit/78923280eed3eff6a77910bba59ecc1fa2244e02) |

## Supported targets

- Linux `amd64`, `386`, `arm64`, `arm`
- Android `amd64`, `386`, `arm64`, `arm`

> This is a Linux-only fork. macOS, iOS, and Windows targets have been removed.

## Install

Add the module and use it through [`bine`](https://github.com/alexballas/bine):

```bash
go get github.com/alexballas/go-libtor
go get github.com/alexballas/bine/tor
```

The first build is expensive. `go-libtor` compiles a large vendored C codebase, so `go build -x` is useful if you want visible progress.

## Usage

`go-libtor` provides the embedded Tor process creator. `bine` provides the higher-level control API.

```go
package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/alexballas/go-libtor"
	"github.com/alexballas/bine/tor"
)

func main() {
	fmt.Println("Starting and registering onion service, please wait a bit...")

	t, err := tor.Start(context.Background(), &tor.StartConf{
		ProcessCreator: libtor.Creator,
		DebugWriter:    os.Stderr,
	})
	if err != nil {
		log.Fatalf("start tor: %v", err)
	}
	defer t.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()

	onion, err := t.Listen(ctx, &tor.ListenConf{
		RemotePorts: []int{80},
	})
	if err != nil {
		log.Fatalf("create onion service: %v", err)
	}
	defer onion.Close()

	fmt.Printf("Open http://%s.onion in a Tor-capable browser\n", onion.ID)

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "Hello, Tor!")
	})

	log.Fatal(http.Serve(onion, nil))
}
```

## Build notes

- OpenSSL/Tor vendoring carries a small local patch set for release packaging and warning reduction. Review [`PATCHES.md`](PATCHES.md) when updating upstream source trees.
- Linux builds in this tree are expected to work with the vendored OpenSSL 3 and libevent 2.2 line.
- If you are embedding this in an app, let your application own shutdown behavior. Tor and your own listeners should be stopped explicitly on process termination.

## Credits

This repository started as a fork of [ipsn/go-libtor](https://github.com/ipsn/go-libtor), later maintained as [gen2brain/go-libtor](https://github.com/gen2brain/go-libtor). Credit for the vendored C code belongs to the Tor, OpenSSL, libevent, and zlib upstream projects.

## License

3-Clause BSD.
