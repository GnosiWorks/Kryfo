// halo engine — ffi bridge for flutter
// phase 1 stage C-prep: identity + tor onion + ECDH + key export/restore for persistence.

package main

import "C"

import (
	"golang.org/x/crypto/scrypt"
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
"github.com/cretz/bine/control"
	"github.com/cretz/bine/tor"
"github.com/tyler-smith/go-bip39"
"golang.org/x/crypto/curve25519"
)

var (
mu       sync.Mutex
torNode  *tor.Tor
listener net.Listener
myAddr   string
inbox    []string

myEdPriv ed25519.PrivateKey
myEdPub  ed25519.PublicKey
myXPriv  [32]byte
myXPub   [32]byte
myId     string
)

var (
	statusMu     sync.RWMutex
	torStatus    = "off"
	bootstrapPct = 0
	hsdirUploads = 0
)

func setStatus(s string) {
	statusMu.Lock()
	defer statusMu.Unlock()
	if torStatus != s {
		log.Printf("halo: status %s -> %s", torStatus, s)
		torStatus = s
	}
}


//export HaloPing
func HaloPing() *C.char {
return C.CString("pong from go engine")
}

//export HaloVersion
func HaloVersion() *C.char {
return C.CString("halo-engine v0.1.3")
}

//export HaloGenerateIdentity
func HaloGenerateIdentity() *C.char {
mu.Lock()
defer mu.Unlock()

pub, priv, err := ed25519.GenerateKey(rand.Reader)
if err != nil {
return C.CString(fmt.Sprintf("error: ed keygen: %v", err))
}
myEdPub = pub
myEdPriv = priv

if _, err := rand.Read(myXPriv[:]); err != nil {
return C.CString(fmt.Sprintf("error: x keygen: %v", err))
}
curve25519.ScalarBaseMult(&myXPub, &myXPriv)

myId = idFromPubkey(pub)
log.Printf("halo: identity generated: %s", myId)
return C.CString(myId)
}

// restores identity from hex-encoded ed25519 priv (64 bytes hex = 128 chars) +
// X25519 priv (32 bytes hex = 64 chars). recomputes pubkeys + halo_id.
//export HaloRestoreIdentity
func HaloRestoreIdentity(cEdPriv *C.char, cXPriv *C.char) *C.char {
mu.Lock()
defer mu.Unlock()

edPrivHex := C.GoString(cEdPriv)
xPrivHex := C.GoString(cXPriv)

edPrivBytes, err := hex.DecodeString(edPrivHex)
if err != nil || len(edPrivBytes) != ed25519.PrivateKeySize {
return C.CString("error: bad ed priv hex")
}
xPrivBytes, err := hex.DecodeString(xPrivHex)
if err != nil || len(xPrivBytes) != 32 {
return C.CString("error: bad x priv hex")
}

myEdPriv = ed25519.PrivateKey(edPrivBytes)
myEdPub = myEdPriv.Public().(ed25519.PublicKey)

copy(myXPriv[:], xPrivBytes)
curve25519.ScalarBaseMult(&myXPub, &myXPriv)

myId = idFromPubkey(myEdPub)
log.Printf("halo: identity restored: %s", myId)
return C.CString(myId)
}

//export HaloMyId
func HaloMyId() *C.char {
mu.Lock()
defer mu.Unlock()
return C.CString(myId)
}

//export HaloMyEdPubkey
func HaloMyEdPubkey() *C.char {
mu.Lock()
defer mu.Unlock()
if myEdPub == nil {
return C.CString("")
}
return C.CString(hex.EncodeToString(myEdPub))
}

//export HaloMyXPubkey
func HaloMyXPubkey() *C.char {
mu.Lock()
defer mu.Unlock()
return C.CString(hex.EncodeToString(myXPub[:]))
}

// exports private keys so the dart side can persist them encrypted.
// only call this once after generation; do NOT log or transmit.
//export HaloMyEdPrivkey
func HaloMyEdPrivkey() *C.char {
mu.Lock()
defer mu.Unlock()
if myEdPriv == nil {
return C.CString("")
}
return C.CString(hex.EncodeToString(myEdPriv))
}

//export HaloMyXPrivkey
func HaloMyXPrivkey() *C.char {
mu.Lock()
defer mu.Unlock()
return C.CString(hex.EncodeToString(myXPriv[:]))
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

func deriveSharedKey(peerXPubHex string) ([32]byte, error) {
var key [32]byte
peerPub, err := hex.DecodeString(peerXPubHex)
if err != nil || len(peerPub) != 32 {
return key, fmt.Errorf("bad peer pubkey")
}
var peer [32]byte
copy(peer[:], peerPub)

shared, err := curve25519.X25519(myXPriv[:], peer[:])
if err != nil {
return key, err
}
key = sha256.Sum256(shared)
return key, nil
}

//export HaloEncryptFor
func HaloEncryptFor(cPeerPub *C.char, cPlain *C.char) *C.char {
peerPub := C.GoString(cPeerPub)
plain := C.GoString(cPlain)

key, err := deriveSharedKey(peerPub)
if err != nil {
return C.CString(fmt.Sprintf("error: derive: %v", err))
}

block, err := aes.NewCipher(key[:])
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
ct := gcm.Seal(nil, nonce, []byte(plain), nil)
out := append(nonce, ct...)
return C.CString(base64.StdEncoding.EncodeToString(out))
}

//export HaloDecryptFrom
func HaloDecryptFrom(cPeerPub *C.char, cB64 *C.char) *C.char {
peerPub := C.GoString(cPeerPub)
b64 := C.GoString(cB64)

key, err := deriveSharedKey(peerPub)
if err != nil {
return C.CString(fmt.Sprintf("error: derive: %v", err))
}

raw, err := base64.StdEncoding.DecodeString(b64)
if err != nil {
return C.CString(fmt.Sprintf("error: b64: %v", err))
}
block, err := aes.NewCipher(key[:])
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
func HaloStartListener(cDataDir *C.char) *C.char {
	mu.Lock()
	defer mu.Unlock()

	if myAddr != "" {
		return C.CString(myAddr)
	}

	dataDir := C.GoString(cDataDir)
	if dataDir == "" {
		return C.CString("error: empty data dir")
	}
	torDataDir := dataDir + "/tor"
	if err := os.MkdirAll(torDataDir, 0700); err != nil {
		return C.CString(fmt.Sprintf("error: mkdir tor: %v", err))
	}

	setStatus("starting")
	log.Println("halo: starting embedded tor...")
	t, err := tor.Start(nil, &tor.StartConf{
		ProcessCreator: libtor.Creator,
		DataDir:        torDataDir,
		DebugWriter:    os.Stderr,
	})
	if err != nil {
		return C.CString(fmt.Sprintf("error: tor start: %v", err))
	}
	torNode = t
	setStatus("bootstrapped")


	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	keyPath := dataDir + "/onion.key"
	var key ed25519.PrivateKey
	if data, rerr := os.ReadFile(keyPath); rerr == nil && len(data) == ed25519.PrivateKeySize {
		key = ed25519.PrivateKey(data)
		log.Println("halo: loaded onion key from disk")
	} else {
		_, key, err = ed25519.GenerateKey(rand.Reader)
		if err != nil {
			return C.CString(fmt.Sprintf("error: gen onion key: %v", err))
		}
		if werr := os.WriteFile(keyPath, key, 0600); werr != nil {
			log.Printf("halo: WARN onion key save failed: %v", werr)
		} else {
			log.Println("halo: generated and saved new onion key")
		}
	}

	setStatus("publishing")
	onion, err := t.Listen(ctx, &tor.ListenConf{
		Version3:    true,
		RemotePorts: []int{80},
		Key:         key,
	})
	if err != nil {
		return C.CString(fmt.Sprintf("error: listen: %v", err))
	}
	listener = onion
	myAddr = fmt.Sprintf("%s.onion", onion.ID)

	go func() {
		watchHSDirUpload(t, onion.ID)
		statusMu.Lock()
		if torStatus == "publishing" {
			log.Println("halo: status publishing -> reachable (HSDir uploaded)")
			torStatus = "reachable"
			go func() {
				if _, err := torNostrClient(); err != nil {
					log.Printf("halo: nostr client pre-warm failed: %v", err)
				} else {
					log.Println("halo: nostr client pre-warmed")
				}
			}()
		}
		statusMu.Unlock()
	}()

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
inbox = append(inbox, line)
mu.Unlock()
conn.Write([]byte("ack\n"))
log.Printf("halo: received %d bytes", len(line))
}

//export HaloGetStatus
func HaloGetStatus() *C.char {
	statusMu.RLock()
	defer statusMu.RUnlock()
	return C.CString(fmt.Sprintf("%s|%d|%d", torStatus, bootstrapPct, hsdirUploads))
}

//export HaloDrainInbox
func HaloDrainInbox() *C.char {
	mu.Lock()
	defer mu.Unlock()
	if len(inbox) == 0 {
		return C.CString("")
	}
	out := strings.Join(inbox, "\n")
	inbox = inbox[:0]
	return C.CString(out)
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
ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
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

conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
_, err = conn.Write([]byte(msg + "\n"))
if err != nil {
return C.CString(fmt.Sprintf("error: write: %v", err))
}

log.Printf("halo: sent %d bytes to %s", len(msg), addr)
return C.CString("ok")
}

func main() {}

//export HaloIdFromEdPub
// derives the 3-word BIP-39 halo id from an ed25519 public key hex string.
// used during back-pair when a stranger's first message arrives and we need
// to compute their halo id from the identity key in the libsignal envelope.
func HaloIdFromEdPub(cHexPub *C.char) *C.char {
hexPub := C.GoString(cHexPub)
pub, err := hex.DecodeString(hexPub)
if err != nil || len(pub) != 32 {
return C.CString("")
}
return C.CString(idFromPubkey(pub))
}

//export HaloEncryptBackup
// encrypts a UTF-8 plaintext payload (typically a JSON blob containing
// the user's identity keys + db + prefs) with a passphrase using scrypt
// (32768 / 8 / 1) + AES-256-GCM. returns "halo-backup:v1:" + base64
// (salt || nonce || ciphertext+tag). returns "error: ..." on failure.
func HaloEncryptBackup(cPlain, cPassphrase *C.char) *C.char {
plain := []byte(C.GoString(cPlain))
passphrase := C.GoString(cPassphrase)

salt := make([]byte, 16)
if _, err := io.ReadFull(rand.Reader, salt); err != nil {
return C.CString("error: rand: " + err.Error())
}
key, err := scrypt.Key([]byte(passphrase), salt, 32768, 8, 1, 32)
if err != nil {
return C.CString("error: scrypt: " + err.Error())
}
block, err := aes.NewCipher(key)
if err != nil {
return C.CString("error: aes: " + err.Error())
}
gcm, err := cipher.NewGCM(block)
if err != nil {
return C.CString("error: gcm: " + err.Error())
}
nonce := make([]byte, gcm.NonceSize())
if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
return C.CString("error: nonce: " + err.Error())
}
ct := gcm.Seal(nil, nonce, plain, nil)
blob := append(append(salt, nonce...), ct...)
return C.CString("halo-backup:v1:" + base64.StdEncoding.EncodeToString(blob))
}

//export HaloDecryptBackup
// inverse of HaloEncryptBackup. returns plaintext on success or
// "error: wrong passphrase or corrupt" on auth failure.
func HaloDecryptBackup(cBlob, cPassphrase *C.char) *C.char {
blob := C.GoString(cBlob)
passphrase := C.GoString(cPassphrase)
prefix := "halo-backup:v1:"
if !strings.HasPrefix(blob, prefix) {
return C.CString("error: not a halo backup")
}
raw, err := base64.StdEncoding.DecodeString(blob[len(prefix):])
if err != nil {
return C.CString("error: bad base64")
}
if len(raw) < 16+12+16 {
return C.CString("error: blob too short")
}
salt := raw[:16]
rest := raw[16:]
key, err := scrypt.Key([]byte(passphrase), salt, 32768, 8, 1, 32)
if err != nil {
return C.CString("error: scrypt: " + err.Error())
}
block, err := aes.NewCipher(key)
if err != nil {
return C.CString("error: aes: " + err.Error())
}
gcm, err := cipher.NewGCM(block)
if err != nil {
return C.CString("error: gcm: " + err.Error())
}
nonceSize := gcm.NonceSize()
nonce := rest[:nonceSize]
ct := rest[nonceSize:]
plain, err := gcm.Open(nil, nonce, ct, nil)
if err != nil {
return C.CString("error: wrong passphrase or corrupt")
}
return C.CString(string(plain))
}

// watchHSDirUpload subscribes to tor's HS_DESC events and returns as
// soon as an UPLOADED action is reported for our onion id, or after
// 60s as a fallback. without this we'd just wait the full 60s
// heuristic — most networks UPLOAD within 5-15 seconds.
func watchHSDirUpload(t *tor.Tor, onionID string) {
if t == nil || t.Control == nil {
time.Sleep(60 * time.Second)
return
}
ch := make(chan control.Event, 16)
if err := t.Control.AddEventListener(ch, control.EventCodeHSDesc); err != nil {
log.Printf("halo: HSDesc subscribe failed: %v — falling back to 60s wait", err)
time.Sleep(60 * time.Second)
return
}
defer t.Control.RemoveEventListener(ch, control.EventCodeHSDesc)

timeout := time.After(60 * time.Second)
for {
select {
case ev := <-ch:
hs, ok := ev.(*control.HSDescEvent)
if !ok {
continue
}
if hs.Action == "UPLOADED" && (hs.Address == onionID || hs.Address == onionID+".onion") {
log.Printf("halo: HS_DESC UPLOADED received for %s", onionID)
return
}
case <-timeout:
log.Printf("halo: HSDesc event timed out, falling back")
return
}
}
}
