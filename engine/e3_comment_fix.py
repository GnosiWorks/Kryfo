#!/usr/bin/env python3
# fixes the comment prefix in the cooldown block (harmless if already correct)
p = "bridge.go"
s = open(p, encoding="utf-8").read()
bad = "\t// cooldown: a quiet-but-alive relay shouldn't drive a restart loop. hold\n\tto at least 3 min between restarts. the deaf-cycle trigger can be noisy;"
good = "\t// cooldown: a quiet-but-alive relay shouldn't drive a restart loop. hold\n\t// to at least 3 min between restarts. the deaf-cycle trigger can be noisy;"
if bad in s:
    s = s.replace(bad, good); open(p, "w").write(s); print("e3: comment fixed")
else:
    print("e3: already correct, skipping")
