# go-libtor

[![PkgGoDev](https://pkg.go.dev/badge/github.com/alexballas/go-libtor)](https://pkg.go.dev/github.com/alexballas/go-libtor)

`go-libtor` embeds Tor and its C dependencies directly into a Go build. The result is a self-contained Go package that can start an in-process Tor instance through CGO, without requiring a system Tor installation.

This repository is a maintained fork of `gen2brain/go-libtor`. The current module path is:

```text
github.com/alexballas/go-libtor
```

## Bundled upstreams

| Library | Version | Commit |
| :- | :- | :- |
| zlib | 1.3.2 | [`da607da739fa6047df13e66a2af6b8bec7c2a498`](https://github.com/madler/zlib/commit/da607da739fa6047df13e66a2af6b8bec7c2a498) |
| libevent | 2.2.1-alpha-dev | [`fe9dc8f614db0520027e8e2adb95769193d4f0a3`](https://github.com/libevent/libevent/commit/fe9dc8f614db0520027e8e2adb95769193d4f0a3) |
| OpenSSL | 3.6.1 | [`c9a9e5b10105ad850b6e4d1122c645c67767c341`](https://github.com/openssl/openssl/commit/c9a9e5b10105ad850b6e4d1122c645c67767c341) |
| Tor | 0.4.9.5 | [`1442ca4852283d6650dcad60bdb4e9167aceb495`](https://gitlab.torproject.org/tpo/core/tor/-/commit/1442ca4852283d6650dcad60bdb4e9167aceb495) |

## Supported targets

- Linux `amd64`, `386`, `arm64`, `arm`
- Android `amd64`, `386`, `arm64`, `arm`
- macOS `amd64`, `arm64`
- iOS `amd64`, `arm64`
- Windows `amd64`, `386`

## Install

Add the module and use it through [`bine`](https://github.com/cretz/bine):

```bash
go get github.com/alexballas/go-libtor
go get github.com/cretz/bine/tor
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
	"github.com/cretz/bine/tor"
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
		Version3:    true,
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

- OpenSSL 3 builds currently emit deprecation warnings from Tor 0.4.9.5. Those warnings are expected and do not block the build.
- Linux builds in this tree are expected to work with the vendored OpenSSL 3 and libevent 2.2 line.
- If you are embedding this in an app, let your application own shutdown behavior. Tor and your own listeners should be stopped explicitly on process termination.

## Credits

This repository started as a fork of [ipsn/go-libtor](https://github.com/ipsn/go-libtor), later maintained as [gen2brain/go-libtor](https://github.com/gen2brain/go-libtor). Credit for the vendored C code belongs to the Tor, OpenSSL, libevent, and zlib upstream projects.

This tree also includes portability work originally contributed for macOS and iOS support.

## License

3-Clause BSD.
