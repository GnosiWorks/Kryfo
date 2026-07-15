import io, sys

p = 'main.dart'
s = io.open(p, encoding='utf-8').read()

if 'torWait < 300000' in s:
    print('patientsend: already applied')
    sys.exit(0)

# 1) four identical wait loops: 30s -> 5min. a send fired before tor is up now
#    waits on the hops pill instead of failing. honest violet on the slow phone
#    takes 1-3min, the old 30s cap guaranteed a fail-then-tap.
old = 'while (!_torReadyToSend() && torWait < 30000) {'
new = 'while (!_torReadyToSend() && torWait < 300000) {'
n = s.count(old)
assert n == 4, 'wait-loop count: %d' % n
s = s.replace(old, new)

# 2) retry the moment sending is possible (publishing), not just reachable.
#    _canSendNow mirrors _torReadyToSend so a queued send goes as soon as the
#    engine can actually publish, no green needed.
old2 = '''  void _retryFailedOnReconnect() {
    final reachable = appState.torStatus == TorStatus.reachable;
    if (reachable && !_wasReachable) {'''
new2 = '''  void _retryFailedOnReconnect() {
    final reachable = _torReadyToSend();
    if (reachable && !_wasReachable) {'''
assert s.count(old2) == 1, 'retry-edge anchor: %d' % s.count(old2)
s = s.replace(old2, new2)

io.open(p, 'w', encoding='utf-8').write(s)
print('patientsend: 2 edits ok (4 loops + retry edge)')

# 3) tidy: this sheet still lists bootstrapped as a usable tor state, but that
#    status was removed - dead branch. drop it so nobody trusts it later.
s = io.open(p, encoding='utf-8').read()
old3 = '''          final usable =
              appState.torStatus == TorStatus.bootstrapped ||
              appState.torStatus == TorStatus.publishing;'''
new3 = '''          final usable = appState.torStatus == TorStatus.publishing;'''
if old3 in s:
    assert s.count(old3) == 1, 'usable anchor: %d' % s.count(old3)
    s = s.replace(old3, new3)
    io.open(p, 'w', encoding='utf-8').write(s)
    print('patientsend: +1 tidy (dead bootstrapped branch)')
else:
    print('patientsend: tidy skipped (already clean)')
