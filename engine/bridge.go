// halo engine — ffi bridge for flutter
// phase 0: tor onion service + plaintext message exchange.

package main

import "C"

import (
"bufio"
"context"
"fmt"
"io"
"log"
"net"
"os"
"strings"
"sync"
"time"

libtor "github.com/alexballas/go-libtor"
"github.com/cretz/bine/tor"
)

var (
mu       sync.Mutex
torNode  *tor.Tor
listener net.Listener
myAddr   string
lastRecv string
)

//export HaloPing
func HaloPing() *C.char {
return C.CString("pong from go engine")
}

//export HaloVersion
func HaloVersion() *C.char {
return C.CString("halo-engine v0.0.3")
}

//export HaloStartListener
func HaloStartListener() *C.char {
mu.Lock()
defer mu.Unlock()

if myAddr != "" {
return C.CString(myAddr)
}

log.Println("halo: starting embedded tor...")
t, err := tor.Start(nil, &tor.StartConf{
ProcessCreator: libtor.Creator,
DataDir:        "/data/data/com.halo.halo_app/files/tor",
DebugWriter:    os.Stderr,
})
if err != nil {
return C.CString(fmt.Sprintf("error: tor start: %v", err))
}
torNode = t

ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
defer cancel()

onion, err := t.Listen(ctx, &tor.ListenConf{
Version3:    true,
RemotePorts: []int{80},
})
if err != nil {
return C.CString(fmt.Sprintf("error: listen: %v", err))
}
listener = onion
myAddr = fmt.Sprintf("%s.onion", onion.ID)

go acceptLoop(onion)

log.Printf("halo: listening on %s", myAddr)
return C.CString(myAddr)
}

func acceptLoop(l net.Listener) {
for {
conn, err := l.Accept()
if err != nil {
log.Printf("halo: accept err: %v", err)
return
}
log.Printf("halo: incoming connection from %s", conn.RemoteAddr())
go handleConn(conn)
}
}

func handleConn(conn net.Conn) {
defer conn.Close()
r := bufio.NewReader(conn)
line, err := r.ReadString('\n')
if err != nil && err != io.EOF {
log.Printf("halo: read err: %v", err)
return
}
line = strings.TrimSpace(line)
mu.Lock()
lastRecv = line
mu.Unlock()
conn.Write([]byte("ack\n"))
log.Printf("halo: received: %s", line)
}

//export HaloLastReceived
func HaloLastReceived() *C.char {
mu.Lock()
defer mu.Unlock()
return C.CString(lastRecv)
}

//export HaloSendTo
func HaloSendTo(cAddr *C.char, cMsg *C.char) *C.char {
addr := C.GoString(cAddr)
msg := C.GoString(cMsg)

mu.Lock()
t := torNode
mu.Unlock()
if t == nil {
return C.CString("error: tor not started")
}

log.Printf("halo: dialing %s...", addr)
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
defer cancel()

dialer, err := t.Dialer(ctx, nil)
if err != nil {
return C.CString(fmt.Sprintf("error: dialer: %v", err))
}

conn, err := dialer.DialContext(ctx, "tcp", addr+":80")
if err != nil {
return C.CString(fmt.Sprintf("error: dial: %v", err))
}
defer conn.Close()

_, err = conn.Write([]byte(msg + "\n"))
if err != nil {
return C.CString(fmt.Sprintf("error: write: %v", err))
}

log.Printf("halo: sent %d bytes to %s", len(msg), addr)
return C.CString("ok")
}

func main() {}
