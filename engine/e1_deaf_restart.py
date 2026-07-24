#!/usr/bin/env python3
# engine fix: the tor-wedge that only a manual app restart cleared.
# restartTor() already exists but only fires from the dialer HANG path
# (ctx timeout). the samsung wedge was different: the circuit went silently
# mute - websocket open, no error, no hang - so it hit the deaf-timer, which
# only cycled the subscription and reconnected to the same dead tor forever.
# fix: count consecutive deaf cycles on our own relay; after 2 in a row
# (~2.5 min mute with no traffic) the tor process is wedged, so restart it.
p = "nostr.go"
s = open(p, encoding="utf-8").read()

# add a deaf counter just before the idle timer is created
anchor = '''\t\t\t\tlog.Printf("nostr: listening on %s for addr %s...", u, rcvPk[:12])'''
assert s.count(anchor) == 1, "listen anchor x%d" % s.count(anchor)
s = s.replace(anchor, anchor + '''
\t\t\t\t// consecutive deaf cycles on our own relay = tor is wedged mute.
\t\t\t\t// tracked across reconnects via deafRuns (declared above the loop).''')

# declare deafRuns above the reconnect loop (inside the goroutine, per-relay)
anchor2 = '''\t\t\tlast := nostr.Timestamp(lastSaved)
\t\t\tretry := 10 * time.Second'''
assert s.count(anchor2) == 1, "decl anchor x%d" % s.count(anchor2)
s = s.replace(anchor2, '''\t\t\tlast := nostr.Timestamp(lastSaved)
\t\t\tdeafRuns := 0
\t\t\tretry := 10 * time.Second''')

# in the deaf branch, bump the counter and restart tor after 2 on our own relay
anchor3 = '''\t\t\t\t\tcase <-idle.C:
\t\t\t\t\t\tlog.Printf("nostr: %s quiet %s, cycling the sub", u, deaf)
\t\t\t\t\t\tr.Close()
\t\t\t\t\t\tgoto reconnect'''
assert s.count(anchor3) == 1, "deaf anchor x%d" % s.count(anchor3)
s = s.replace(anchor3, '''\t\t\t\t\tcase <-idle.C:
\t\t\t\t\t\tlog.Printf("nostr: %s quiet %s, cycling the sub", u, deaf)
\t\t\t\t\t\tr.Close()
\t\t\t\t\t\t// mute is how a wedged tor looks when the dialer doesn't
\t\t\t\t\t\t// hang. our own relay carries the traffic, so two silent
\t\t\t\t\t\t// cycles in a row means the circuit is dead - restart tor
\t\t\t\t\t\t// the same way the hang path does. non-own relays just
\t\t\t\t\t\t// cycle (a quiet public relay isn't proof of anything).
\t\t\t\t\t\tif own {
\t\t\t\t\t\t\tdeafRuns++
\t\t\t\t\t\t\tif deafRuns >= 2 {
\t\t\t\t\t\t\t\tdeafRuns = 0
\t\t\t\t\t\t\t\tlog.Println("nostr: own relay mute twice, tor wedged -> restart")
\t\t\t\t\t\t\t\tgo restartTor()
\t\t\t\t\t\t\t}
\t\t\t\t\t\t}
\t\t\t\t\t\tgoto reconnect'''
)

# any event received resets the deaf run - a live circuit isn't wedged.
anchor4 = '''\t\t\t\t\t\t\tdispatch(ev)
\t\t\t\t\t\t}'''
assert s.count(anchor4) == 1, "dispatch anchor x%d" % s.count(anchor4)
s = s.replace(anchor4, '''\t\t\t\t\t\t\tdispatch(ev)
\t\t\t\t\t\t}
\t\t\t\t\t\tdeafRuns = 0''')

open(p, "w", encoding="utf-8").write(s)
print("e1: deaf-cycle tor-wedge restart wired")
