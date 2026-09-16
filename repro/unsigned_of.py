#!/usr/bin/env python3
# cuts the apk signing block out of a signed apk and writes what is left.
#
# f-droid does the same with apksigcopier and compares the result to their
# own unsigned build byte for byte - not entry by entry. entry hashes matched
# on 0.2.8 and 0.2.10 and both were refused, because apksigner had re-padded
# the zip on the way through and what was left was not the container they
# built. verify.sh makes this comparison now.
#
# the block sits between the last entry and the central directory:
#   [size u64][id-value pairs][size u64]"APK Sig Block 42"
# removing it moves the central directory, so the end-of-central-directory
# record's offset is patched to match. a file with no block is copied as is.
import struct
import sys


def unsigned_of(signed: bytes) -> bytes:
    eocd = signed.rfind(b"PK\x05\x06")
    if eocd < 0:
        raise SystemExit("not a zip: no end of central directory")
    cd = struct.unpack("<I", signed[eocd + 16 : eocd + 20])[0]
    if signed[cd - 16 : cd] != b"APK Sig Block 42":
        return signed
    size = struct.unpack("<Q", signed[cd - 24 : cd - 16])[0]
    start = cd - size - 8
    out = bytearray(signed[:start] + signed[cd:])
    e = out.rfind(b"PK\x05\x06")
    struct.pack_into("<I", out, e + 16, start)
    return bytes(out)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: unsigned_of.py <signed.apk> <out.apk>")
    with open(sys.argv[1], "rb") as f:
        data = f.read()
    with open(sys.argv[2], "wb") as f:
        f.write(unsigned_of(data))
