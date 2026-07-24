#!/usr/bin/env python3
# add a cooldown to restartTor so a genuinely-quiet-but-alive relay can't drive
# a restart loop. min 3 min between restarts; the CAS already blocks concurrent.
p = "bridge.go"
s = open(p, encoding="utf-8").read()

anchor = '''var torRestarting int32

func restartTor() {
\t// collapse concurrent triggers - only one restart at a time.
\tif !atomic.CompareAndSwapInt32(&torRestarting, 0, 1) {
\t\treturn
\t}
\tdefer atomic.StoreInt32(&torRestarting, 0)'''
assert s.count(anchor) == 1, "restart head anchor x%d" % s.count(anchor)

s = s.replace(anchor, '''var torRestarting int32
var lastTorRestart int64 // unix seconds of the last restart, for cooldown

func restartTor() {
\t// collapse concurrent triggers - only one restart at a time.
\tif !atomic.CompareAndSwapInt32(&torRestarting, 0, 1) {
\t\treturn
\t}
\tdefer atomic.StoreInt32(&torRestarting, 0)

\t// cooldown: a quiet-but-alive relay shouldn't drive a restart loop. hold
\tto at least 3 min between restarts. the deaf-cycle trigger can be noisy;
\t// the dialer-hang trigger is rarer but shares the same floor.
\tnow := time.Now().Unix()
\tif prev := atomic.LoadInt64(&lastTorRestart); prev != 0 && now-prev < 180 {
\t\tlog.Printf("halo: restartTor skipped - %ds since last (cooldown 180s)", now-prev)
\t\treturn
\t}
\tatomic.StoreInt64(&lastTorRestart, now)''')

open(p, "w", encoding="utf-8").write(s)
print("e2: restart cooldown added")
