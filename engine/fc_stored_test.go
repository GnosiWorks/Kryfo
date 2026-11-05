// SPDX-License-Identifier: GPL-3.0-or-later
package main

// a hello sent to an invite's first-contact address before anything here
// listened on it is on the relay already: the listener that starts later
// finds it there, on a first start and on one that heard the address before

import (
	"encoding/hex"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	"fiatjaf.com/nostr"
	"github.com/mailru/easyjson"
	nostr2 "github.com/nbd-wtf/go-nostr"
)

func helloStored(t *testing.T, sender xid, owner [32]byte, fcPk, msg string) nostr.Event {
	t.Helper()
	gw, err := helloWrap(sender, owner, fcPk, msg)
	if err != nil {
		t.Fatal(err)
	}
	var ev nostr.Event
	if err := easyjson.Unmarshal([]byte(gw.String()), &ev); err != nil {
		t.Fatal(err)
	}
	return ev
}

func inboxHasAt(tag, body string) bool {
	nostrMu.Lock()
	defer nostrMu.Unlock()
	for _, l := range nostrInbox {
		if strings.HasPrefix(l, tag+"|") && strings.HasSuffix(l, "|"+body) {
			return true
		}
	}
	return false
}

func TestAHelloStoredBeforeTheListenerStartsComesIn(t *testing.T) {
	for _, heardBefore := range []bool{false, true} {
		name := "first start"
		if heardBefore {
			name = "heard the address a day ago"
		}
		t.Run(name, func(t *testing.T) {
			socks := newSocksStandIn(t)
			a := newRelayStandIn(t, 0)
			b := newRelayStandIn(t, 0)
			useStandIns(t, modePrivate, socks, a, b)
			freshInbox(t)
			me, err := identityOf(mainIdent)
			if err != nil {
				t.Fatal(err)
			}
			sk := nostr2.GeneratePrivateKey()
			pk, err := fcKeyPk(sk)
			if err != nil {
				t.Fatal(err)
			}
			invite := hex.EncodeToString(make([]byte, 16))
			t.Cleanup(func() { unsubscribeFcKey(mainIdent, invite) })
			if heardBefore {
				// the files a start a day ago left: every relay heard to then,
				// nothing opened since
				day := (time.Now().Add(-24*time.Hour).UnixMilli() / 900000) * 900000
				var lines []string
				for _, u := range []string{a.url(), b.url()} {
					lines = append(lines, u+" "+strconv.FormatInt(day, 10))
				}
				if err := os.WriteFile(heardFile(pk), []byte(strings.Join(lines, "\n")+"\n"), 0600); err != nil {
					t.Fatal(err)
				}
				_, last := addressFiles(pk)
				if err := os.WriteFile(last, []byte("0"), 0600); err != nil {
					t.Fatal(err)
				}
			}
			// sent hours before this start, to our relay alone
			a.store(helloStored(t, newXid(t), me.pub, pk, "KHL1 stored"))

			if err := subscribeFcKey(mainIdent, invite, sk); err != nil {
				t.Fatal(err)
			}
			tag := fcSubKey(mainIdent, invite)
			waitFor(t, "the stored hello in the inbox", 20*time.Second, func() bool {
				return inboxHasAt(tag, "KHL1 stored")
			})
		})
	}
}
