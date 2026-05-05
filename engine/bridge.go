// halo engine — ffi bridge for flutter
// phase 1: identity + tor onion + AES-GCM encryption (stage A).

package main

import "C"

import (
"bufio"
"context"
"crypto/aes"
"crypto/cipher"
"crypto/ed25519"
"crypto/rand"
"crypto/sha256"
"encoding/base64"
"encoding/hex"
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
"github.com/tyler-smith/go-bip39"
)

// stage A: hard-coded test key. stage B replaces this with ECDH-derived per-peer keys.
var testKey = sha256.Sum256([]byte("halo-stage-a-do-not-ship"))

var (
mu       sync.Mutex
torNode  *tor.Tor
listener net.Listener
myAddr   string
lastRecv string

myPriv ed25519.PrivateKey
myPub  ed25519.PublicKey
myId   string
)

//export HaloPing
func HaloPing() *C.char {
return C.CString("pong from go engine")
}

//export HaloVersion
func HaloVersion() *C.char {
return C.CString("halo-engine v0.1.1")
}

//export HaloGenerateIdentity
func HaloGenerateIdentity() *C.char {
mu.Lock()
defer mu.Unlock()

pub, priv, err := ed25519.GenerateKey(rand.Reader)
if err != nil {
return C.CString(fmt.Sprintf("error: keygen: %v", err))
}
myPub = pub
myPriv = priv
myId = idFromPubkey(pub)

log.Printf("halo: identity generated: %s", myId)
return C.CString(myId)
}

//export HaloMyId
func HaloMyId() *C.char {
mu.Lock()
defer mu.Unlock()
return C.CString(myId)
}

//export HaloMyPubkey
func HaloMyPubkey() *C.char {
mu.Lock()
defer mu.Unlock()
if myPub == nil {
return C.CString("")
}
return C.CString(hex.EncodeToString(myPub))
}

//export HaloIdFromPubkey
func HaloIdFromPubkey(cHex *C.char) *C.char {
pubHex := C.GoString(cHex)
pub, err := hex.DecodeString(pubHex)
if err != nil {
return C.CString(fmt.Sprintf("error: bad hex: %v", err))
}
return C.CString(idFromPubkey(pub))
}

func idFromPubkey(pub []byte) string {
h := sha256.Sum256(pub)
wordlist := bip39.GetWordList()
bits := uint64(h[0])<<32 | uint64(h[1])<<24 | uint64(h[2])<<16 | uint64(h[3])<<8 | uint64(h[4])
w1 := wordlist[(bits>>22)&0x7FF]
w2 := wordlist[(bits>>11)&0x7FF]
w3 := wordlist[bits&0x7FF]
return fmt.Sprintf("%s-%s-%s", w1, w2, w3)
}

// AES-256-GCM encrypt. returns base64(nonce || ciphertext) or "error: ..."
//export HaloEncrypt
func HaloEncrypt(cPlain *C.char) *C.char {
plain := C.GoString(cPlain)
block, err := aes.NewCipher(testKey[:])
if err != nil {
return C.CString(fmt.Sprintf("error: cipher: %v", err))
}
gcm, err := cipher.NewGCM(block)
if err != nil {
return C.CString(fmt.Sprintf("error: gcm: %v", err))
}
nonce := make([]byte, gcm.NonceSize())
if _, err := rand.Read(nonce); err != nil {
return C.CString(fmt.Sprintf("error: nonce: %v", err))
}
ciphertext := gcm.Seal(nil, nonce, []byte(plain), nil)
out := append(nonce, ciphertext...)
return C.CString(base64.StdEncoding.EncodeToString(out))
}

// AES-256-GCM decrypt. takes base64(nonce || ciphertext). returns plaintext or "error: ..."
//export HaloDecrypt
func HaloDecrypt(cB64 *C.char) *C.char {
b64 := C.GoString(cB64)
raw, err := base64.StdEncoding.DecodeString(b64)
if err != nil {
return C.CString(fmt.Sprintf("error: b64: %v", err))
}
block, err := aes.NewCipher(testKey[:])
if err != nil {
return C.CString(fmt.Sprintf("error: cipher: %v", err))
}
gcm, err := cipher.NewGCM(block)
if err != nil {
return C.CString(fmt.Sprintf("error: gcm: %v", err))
}
nsize := gcm.NonceSize()
if len(raw) < nsize {
return C.CString("error: ciphertext too short")
}
nonce, ct := raw[:nsize], raw[nsize:]
plain, err := gcm.Open(nil, nonce, ct, nil)
if err != nil {
return C.CString(fmt.Sprintf("error: open: %v", err))
}
return C.CString(string(plain))
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
log.Printf("halo: received %d bytes", len(line))
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
