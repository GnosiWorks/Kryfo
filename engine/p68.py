#!/usr/bin/env python3
# p68: the receive lag. publish returns on first accept (own relay, fast) but
# the receiver's sub to that relay can be mid-heal - retry sleeps were 10s and
# dead-circuit detection 4m, so a landed message sat unread. own relay (first
# in the list) now heals hard: 3s connect retry, 2s reconnect, 75s deaf check.
# public relays keep the gentle timers.
import io

p = "nostr.go"
s = io.open(p, encoding="utf-8").read()

def rep(old, new):
    global s
    n = s.count(old)
    assert n == 1, f"anchor x{n}: {old[:60]!r}"
    s = s.replace(old, new)

rep(
    "\tfor _, url := range urls {\n\t\tgo func(u string) {\n\t\t\tvar last nostr.Timestamp\n",
    "\tfor i, url := range urls {\n\t\t// first relay is our own - it carries the traffic, heal it hard\n\t\town := i == 0\n\t\tgo func(u string) {\n\t\t\tvar last nostr.Timestamp\n\t\t\tretry := 10 * time.Second\n\t\t\trejoin := 5 * time.Second\n\t\t\tdeaf := 4 * time.Minute\n\t\t\tif own {\n\t\t\t\tretry = 3 * time.Second\n\t\t\t\trejoin = 2 * time.Second\n\t\t\t\tdeaf = 75 * time.Second\n\t\t\t}\n",
)
rep(
    "\t\t\t\t\tlog.Printf(\"nostr: subscribe-connect %s: %v\", u, err)\n\t\t\t\t\ttime.Sleep(10 * time.Second)\n",
    "\t\t\t\t\tlog.Printf(\"nostr: subscribe-connect %s: %v\", u, err)\n\t\t\t\t\ttime.Sleep(retry)\n",
)
rep(
    "\t\t\t\t\tlog.Printf(\"nostr: subscribe %s: %v\", u, err)\n\t\t\t\t\tr.Close()\n\t\t\t\t\ttime.Sleep(10 * time.Second)\n",
    "\t\t\t\t\tlog.Printf(\"nostr: subscribe %s: %v\", u, err)\n\t\t\t\t\tr.Close()\n\t\t\t\t\ttime.Sleep(retry)\n",
)
rep(
    "\t\t\t\tidle := time.NewTimer(4 * time.Minute)\n",
    "\t\t\t\tidle := time.NewTimer(deaf)\n",
)
rep(
    "\t\t\t\t\t\tidle.Reset(4 * time.Minute)\n",
    "\t\t\t\t\t\tidle.Reset(deaf)\n",
)
rep(
    "\t\t\t\t\tcase <-idle.C:\n\t\t\t\t\t\tlog.Printf(\"nostr: %s quiet 4m, cycling the sub\", u)\n",
    "\t\t\t\t\tcase <-idle.C:\n\t\t\t\t\t\tlog.Printf(\"nostr: %s quiet %s, cycling the sub\", u, deaf)\n",
)
rep(
    "\t\t\treconnect:\n\t\t\t\ttime.Sleep(5 * time.Second)\n",
    "\t\t\treconnect:\n\t\t\t\ttime.Sleep(rejoin)\n",
)

io.open(p, "w", encoding="utf-8").write(s)
print("p68 ok - own relay sub heals in seconds not minutes")
