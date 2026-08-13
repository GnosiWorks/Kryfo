// SPDX-License-Identifier: GPL-3.0-or-later
// halo engine - ffi bridge for flutter
// phase 1 stage C-prep: identity + tor onion + ECDH + key export/restore for persistence.

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
	"golang.org/x/crypto/scrypt"
	"io"
	"log"
	"net"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	libtor "github.com/alexballas/go-libtor"
	"github.com/cretz/bine/control"
	"github.com/cretz/bine/tor"
	"github.com/tyler-smith/go-bip39"
	"golang.org/x/crypto/curve25519"
)

var (
	mu           sync.Mutex
	startMu      sync.Mutex
	torNode      *tor.Tor
	listener     net.Listener
	myAddr       string
	savedDataDir string // kept so the dialer watchdog can relaunch tor
	inbox        []string

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

// debugOn gates every engine log line (see androidLogWriter). off by default
// so release builds stay silent; dart flips it on in debug via HaloSetDebug.
var debugOn int32

//export HaloSetDebug
func HaloSetDebug(on C.int) {
	v := int32(0)
	if on != 0 {
		v = 1
	}
	atomic.StoreInt32(&debugOn, v)
	mu.Lock()
	dbg := debugTorWriter
	mu.Unlock()
	if dbg != nil {
		atomic.StoreInt32(&dbg.on, v)
	}
}

// gatedWriter feeds tor's DebugWriter. when off it discards everything so
// tor's circuit/HSDir chatter never reaches release logcat.
type gatedWriter struct{ on int32 }

func (g *gatedWriter) Write(p []byte) (int, error) {
	if atomic.LoadInt32(&g.on) == 0 {
		return len(p), nil
	}
	return log.Writer().Write(p)
}

var debugTorWriter *gatedWriter

func setStatus(s string) {
	statusMu.Lock()
	defer statusMu.Unlock()
	if torStatus != s {
		log.Printf("halo: status %s -> %s", torStatus, s)
		if torStatus == "publishing" {
			notePublished()
		}
		torStatus = s
	}
}

//export HaloPing
func HaloPing() *C.char {
	return C.CString("pong from go engine")
}

//export HaloVersion
func HaloVersion() *C.char {
	return C.CString("halo-engine v0.1.4")
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
//
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
//
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
	// startMu serializes start against shutdown. mu is only taken around
	// the shared vars so other ffi calls don't freeze for the seconds tor
	// takes to come up.
	startMu.Lock()
	defer startMu.Unlock()

	mu.Lock()
	if myAddr != "" {
		addr := myAddr
		mu.Unlock()
		return C.CString(addr)
	}
	mu.Unlock()

	dataDir := C.GoString(cDataDir)
	if dataDir == "" {
		return C.CString("error: empty data dir")
	}
	torDataDir := dataDir + "/tor"
	if err := os.MkdirAll(torDataDir, 0700); err != nil {
		return C.CString(fmt.Sprintf("error: mkdir tor: %v", err))
	}
	mu.Lock()
	savedDataDir = dataDir
	mu.Unlock()

	// a hard-killed previous process can leave tor's lock behind, which blocks
	// this start and froze a fast relaunch. tor is single-instance per data dir
	// and we hold startMu, so removing a stale lock here is safe.
	// same reasoning as the restart path: a run file left by a process that
	// was killed rather than closed will fail the next start outright.
	cleanTorRunFiles(torDataDir)

	setStatus("starting")
	log.Println("halo: starting embedded tor...")
	t, err := tor.Start(nil, &tor.StartConf{
		ProcessCreator: libtor.Creator,
		DataDir:        torDataDir,
		DebugWriter:    newTorDebugWriter(),
		ExtraArgs:      bridgeTorArgs(),
	})
	if err != nil {
		return C.CString(fmt.Sprintf("error: tor start: %v", err))
	}
	mu.Lock()
	torNode = t
	mu.Unlock()
	// stay "starting" - tor.Start returns before any circuit exists. the
	// bootstrap watcher owns the flip at a real 100%.
	go watchBootstrap(t)

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

	// no status flip here - publishing means nothing while bootstrap is at
	// 50%. the watcher sets it when tor is actually there.
	// subscribe before Listen - the first UPLOADED can fire while Listen is
	// still blocking, and missing it meant sitting out the full fallback.
	hsCh := make(chan control.Event, 16)
	hsSubbed := false
	if t.Control != nil {
		if aerr := t.Control.AddEventListener(hsCh, control.EventCodeHSDesc); aerr == nil {
			hsSubbed = true
		} else {
			log.Printf("halo: HSDesc subscribe failed: %v", aerr)
		}
	}
	// tor starts with the network off. bine normally turns it on inside
	// Listen, but only on the branch we skip with NoWait - so the onion got
	// created and never published. turn it on ourselves before listening.
	if eerr := t.EnableNetwork(ctx, false); eerr != nil {
		log.Printf("halo: enable network: %v", eerr)
	}

	listenStart := time.Now()
	onion, err := t.Listen(ctx, &tor.ListenConf{
		NoWait:      true,
		Version3:    true,
		RemotePorts: []int{80},
		Key:         key,
	})
	if err != nil {
		log.Printf("halo: listen failed after %.0fs: %v", time.Since(listenStart).Seconds(), err)
		return C.CString(fmt.Sprintf("error: listen: %v", err))
	}
	log.Printf("halo: listen returned in %.0fs", time.Since(listenStart).Seconds())
	mu.Lock()
	listener = onion
	myAddr = fmt.Sprintf("%s.onion", onion.ID)
	addr := myAddr
	mu.Unlock()

	go func() {
		if hsSubbed {
			defer t.Control.RemoveEventListener(hsCh, control.EventCodeHSDesc)
		}
		for {
			if watchHSDirUpload(t, hsCh, hsSubbed, onion.ID) {
				break
			}
			statusMu.RLock()
			stillPub := torStatus == "publishing"
			statusMu.RUnlock()
			if !stillPub {
				return
			}
			// no confirmed upload yet - the same listener stays live, loop
			// and wait for a late descriptor instead of lying reachable.
		}
		statusMu.Lock()
		if torStatus == "publishing" {
			log.Println("halo: status publishing -> reachable (HSDir uploaded)")
			torStatus = "reachable"
			notePublished()
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

	log.Printf("halo: listening on %s", addr)
	return C.CString(addr)
}

// bine writes a fresh torrc and control-port file per run and does not always
// clean them up. a half-written one left by a dying process is read by the
// next start as "invalid port format", which killed the restart outright.
func cleanTorRunFiles(dir string) {
	os.Remove(dir + "/lock")
	ents, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	for _, e := range ents {
		n := e.Name()
		if strings.HasPrefix(n, "control-port-") || strings.HasPrefix(n, "torrc-") {
			os.Remove(dir + "/" + n)
		}
	}
}

// restartTor tears down the wedged tor and brings a fresh one up on the same
// data dir + onion key. triggered by the dialer watchdog when the control
// conn is provably dead. serialized on startMu against Start/Shutdown so two
// restarts (or a restart racing shutdown) can't overlap.
var torRestarting int32
var lastTorRestart int64 // unix seconds of the last restart, for cooldown

// how many old tor instances are still shutting down. each one holds its
// memory and its circuits until it finishes, so starting another on top is
// how the process gets killed.
var torClosing int32

func restartTor() {
	// collapse concurrent triggers - only one restart at a time.
	if !atomic.CompareAndSwapInt32(&torRestarting, 0, 1) {
		return
	}
	defer atomic.StoreInt32(&torRestarting, 0)

	if n := atomic.LoadInt32(&torClosing); n > 0 {
		log.Printf("halo: restartTor skipped - %d old tor still closing", n)
		return
	}

	// cooldown: a quiet-but-alive relay shouldn't drive a restart loop. hold
	// to at least 3 min between restarts. the deaf-cycle trigger can be noisy;
	// the dialer-hang trigger is rarer but shares the same floor.
	now := time.Now().Unix()
	if prev := atomic.LoadInt64(&lastTorRestart); prev != 0 && now-prev < 180 {
		log.Printf("halo: restartTor skipped - %ds since last (cooldown 180s)", now-prev)
		return
	}
	atomic.StoreInt64(&lastTorRestart, now)

	startMu.Lock()
	defer startMu.Unlock()

	mu.Lock()
	old := torNode
	dir := savedDataDir
	mu.Unlock()
	if dir == "" {
		log.Println("halo: restartTor skipped - no saved data dir")
		return
	}
	log.Println("halo: restarting embedded tor (dialer wedged)")
	statusMu.Lock()
	hsdirUploads = 0
	statusMu.Unlock()
	setStatus("starting")

	// drop the old node + cached client so nothing keeps dialing the dead one.
	mu.Lock()
	torNode = nil
	listener = nil
	myAddr = ""
	mu.Unlock()
	nostrResetClient()
	if old != nil {
		// closing a tor with live circuits can block for minutes. nothing
		// still points at it, so do not wait.
		atomic.AddInt32(&torClosing, 1)
		go func() {
			defer atomic.AddInt32(&torClosing, -1)
			done := make(chan struct{})
			go func() {
				old.Close()
				close(done)
			}()
			select {
			case <-done:
				log.Println("halo: old tor closed")
			case <-time.After(20 * time.Second):
				log.Println("halo: old tor is taking its time, moving on")
			}
		}()
	}

	torDataDir := dir + "/tor"
	// give the old process a moment to let go of its files. without this the
	// new tor reads a control port file the dying one is still rewriting.
	if old != nil {
		for i := 0; i < 30; i++ {
			if atomic.LoadInt32(&torClosing) == 0 {
				break
			}
			time.Sleep(200 * time.Millisecond)
		}
	}
	cleanTorRunFiles(torDataDir)

	var t *tor.Tor
	var err error
	for attempt := 0; attempt < 2; attempt++ {
		t, err = tor.Start(nil, &tor.StartConf{
			ProcessCreator: libtor.Creator,
			DataDir:        torDataDir,
			DebugWriter:    newTorDebugWriter(),
			ExtraArgs:      bridgeTorArgs(),
		})
		if err == nil {
			break
		}
		log.Printf("halo: restartTor tor.Start failed: %v", err)
		// a stale control port file is the usual cause and clearing it is
		// cheap. one retry beats leaving the app at "off" with no way back.
		time.Sleep(2 * time.Second)
		cleanTorRunFiles(torDataDir)
	}
	if err != nil {
		log.Printf("halo: restartTor gave up: %v", err)
		setStatus("off")
		return
	}
	mu.Lock()
	torNode = t
	mu.Unlock()
	go watchBootstrap(t)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	keyPath := dir + "/onion.key"
	var key ed25519.PrivateKey
	if data, rerr := os.ReadFile(keyPath); rerr == nil && len(data) == ed25519.PrivateKeySize {
		key = ed25519.PrivateKey(data)
	} else {
		log.Println("halo: restartTor WARN missing onion key, address will change")
	}

	if eerr := t.EnableNetwork(ctx, false); eerr != nil {
		log.Printf("halo: restartTor enable network: %v", eerr)
	}
	onion, lerr := t.Listen(ctx, &tor.ListenConf{
		NoWait:      true,
		Version3:    true,
		RemotePorts: []int{80},
		Key:         key,
	})
	if lerr != nil {
		log.Printf("halo: restartTor listen failed: %v", lerr)
		return
	}
	mu.Lock()
	listener = onion
	myAddr = fmt.Sprintf("%s.onion", onion.ID)
	mu.Unlock()
	go acceptLoop(onion)
	log.Printf("halo: tor restarted, listening on %s.onion", onion.ID)
}

//export HaloShutdown
func HaloShutdown() {
	// stop tor cleanly so its data dir lock is released. without this a fast
	// relaunch raced the dying process for the dir and blocked the new ui
	// thread long enough to anr.
	startMu.Lock()
	defer startMu.Unlock()
	mu.Lock()
	t := torNode
	torNode = nil
	listener = nil
	myAddr = ""
	mu.Unlock()
	nostrResetClient()
	if t != nil {
		t.Close()
	}
}

func newTorDebugWriter() *gatedWriter {
	mu.Lock()
	defer mu.Unlock()
	debugTorWriter = &gatedWriter{on: atomic.LoadInt32(&debugOn)}
	return debugTorWriter
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
	// cap the line and the wait - an unbounded ReadString from a hostile
	// peer was an easy oom, and an idle conn held a goroutine forever.
	conn.SetReadDeadline(time.Now().Add(30 * time.Second))
	r := bufio.NewReader(io.LimitReader(conn, 512*1024))
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
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
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

	conn.SetReadDeadline(time.Now().Add(15 * time.Second))
	if _, err := bufio.NewReader(conn).ReadString('\n'); err != nil {
		return C.CString(fmt.Sprintf("error: no ack: %v", err))
	}

	log.Printf("halo: sent %d bytes to %s", len(msg), addr)
	return C.CString("ok")
}

func main() {}

// derives the 3-word BIP-39 halo id from an ed25519 public key hex string.
// used during back-pair when a stranger's first message arrives and we need
// to compute their halo id from the identity key in the libsignal envelope.
//
//export HaloIdFromEdPub
func HaloIdFromEdPub(cHexPub *C.char) *C.char {
	hexPub := C.GoString(cHexPub)
	pub, err := hex.DecodeString(hexPub)
	if err != nil || len(pub) != 32 {
		return C.CString("")
	}
	return C.CString(idFromPubkey(pub))
}

// encrypts a UTF-8 plaintext payload (typically a JSON blob containing
// the user's identity keys + db + prefs) with a passphrase using scrypt
// (32768 / 8 / 1) + AES-256-GCM. returns "halo-backup:v1:" + base64
// (salt || nonce || ciphertext+tag). returns "error: ..." on failure.
//
//export HaloEncryptBackup
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

// inverse of HaloEncryptBackup. returns plaintext on success or
// "error: wrong passphrase or corrupt" on auth failure.
//
//export HaloDecryptBackup
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
// heuristic - most networks UPLOAD within 5-15 seconds.
func watchHSDirUpload(t *tor.Tor, ch chan control.Event, subbed bool, onionID string) bool {
	if t == nil || t.Control == nil || !subbed {
		time.Sleep(120 * time.Second)
		return false
	}

	timeout := time.After(120 * time.Second)
	// how many hsdirs we have handed the descriptor to. the hashring is six
	// per replica, so three is a comfortable majority of one replica and the
	// descriptor is fetchable well before that.
	uploads := 0
	const enough = 3
	for {
		select {
		case ev := <-ch:
			hs, ok := ev.(*control.HSDescEvent)
			if !ok {
				continue
			}
			// log every action, not just the two we care about. an upload
			// that is never attempted looks identical to one that fails if
			// you only watch for FAILED.
			mine := hs.Address == onionID || hs.Address == onionID+".onion"
			log.Printf(
				"halo: HS_DESC %s addr=%s hsdir=%s reason=%s mine=%t",
				hs.Action, hs.Address, hs.HSDir, hs.Reason, mine,
			)
			if hs.Action == "UPLOAD" && mine {
				uploads++
				statusMu.Lock()
				hsdirUploads = uploads
				statusMu.Unlock()
				if uploads == enough {
					log.Printf(
						"halo: descriptor handed to %d hsdirs, treating as published",
						uploads,
					)
					return true
				}
			}
			if hs.Action == "UPLOADED" && mine {
				log.Printf("halo: HS_DESC UPLOADED received for %s", onionID)
				return true
			}
		case <-timeout:
			log.Printf("halo: WARN no HSDir upload confirmed in 120s - staying in publishing, still trying")
			return false
		}
	}
}

// polls tor for real bootstrap progress. tor.Start only means the process
// is up; the network comes alive inside Listen, so this is the only true
// progress signal. self-terminates at 100% or after ~5 min.
func watchBootstrap(t *tor.Tor) {
	lastPct := -1
	for i := 0; i < 300; i++ {
		if t == nil || t.Control == nil {
			return
		}
		kv, err := t.Control.GetInfo("status/bootstrap-phase")
		if err == nil && len(kv) > 0 {
			pct := parseBootstrapPct(kv[0].Val)
			if pct != lastPct {
				lastPct = pct
				statusMu.Lock()
				bootstrapPct = pct
				noteBootstrapProgress(pct)
				statusMu.Unlock()
				log.Printf("halo: tor bootstrap %d%%", pct)
			}
			if pct >= 100 {
				statusMu.Lock()
				cur := torStatus
				statusMu.Unlock()
				if cur != "reachable" {
					setStatus("publishing")
					notePublishing()
				}
				return
			}
		}
		time.Sleep(2 * time.Second)
	}
}

func parseBootstrapPct(v string) int {
	i := strings.Index(v, "PROGRESS=")
	if i < 0 {
		return 0
	}
	v = v[i+len("PROGRESS="):]
	n := 0
	for _, c := range v {
		if c < '0' || c > '9' {
			break
		}
		n = n*10 + int(c-'0')
	}
	return n
}
