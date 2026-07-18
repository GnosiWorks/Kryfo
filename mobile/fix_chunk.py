#!/usr/bin/env python3
# the 48kb group chunk bump trips nip-44's hard 64kB plaintext limit once the
# chunk is wrapped in a json envelope + gift-wrapped: "plaintext should be
# between 1b and 64kB". 1:1 uses 16kb everywhere and sends fine over the relay.
# revert group to 16kb to match. more chunks, but they actually send - and with
# the own relay reliable now, chunk count barely matters. run from ~/halo/mobile.
import io
p = 'lib/main.dart'
s = io.open(p, encoding='utf-8').read()
old = """    // 48k chunks (vs 16k): a 235kb file drops from ~20 chunks to ~7, and each
    // extra chunk is another chance for a tor blip to lose one and stall the
    // whole reassembly. still well under the relay event-size ceiling.
    const chunkSize = 48 * 1024;"""
new = """    // 16k chunks: bigger chunks (48k) tripped nip-44's 64kB plaintext ceiling
    // once wrapped in the envelope + gift wrap, so every chunk failed. 16k
    // matches 1:1 and stays safely under the limit. the own relay makes the
    // extra chunk count cheap.
    const chunkSize = 16 * 1024;"""
c = s.count(old); assert c == 1, f"anchor x{c}"
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8').write(s)
print('fix_chunk ok')
