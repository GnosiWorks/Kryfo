#!/bin/bash
# one-time: fetch/compute the real go + ndk checksums and drop them into the
# Dockerfile, replacing the placeholders. run once, commit the result.
#
# go hash comes from go.dev's signed json index (not the .sha256 sidecar,
# which now redirects to html). ndk hash is computed from the actual google
# download so the number comes from real bytes, not a copied web snippet.
set -e
cd "$(dirname "$0")"

echo "fetching go 1.25.0 checksum from go.dev json index..."
GO_SHA=$(curl -fsSL "https://go.dev/dl/?mode=json&include=all" \
  | grep -A40 '"version": "go1.25.0"' \
  | grep -A3 'go1.25.0.linux-amd64.tar.gz' \
  | grep '"sha256"' | head -1 \
  | sed 's/.*"sha256": "\([a-f0-9]*\)".*/\1/')
if [ -z "$GO_SHA" ]; then
  echo "  could not parse go hash. get it manually from https://go.dev/dl/ (go1.25.0 linux-amd64) and edit Dockerfile."
  exit 1
fi
echo "  go:  $GO_SHA"

echo "computing ndk r28b checksum from google download (~700mb, one time)..."
curl -fsSL "https://dl.google.com/android/repository/android-ndk-r28b-linux.zip" -o /tmp/ndk-verify.zip
NDK_SHA=$(sha256sum /tmp/ndk-verify.zip | cut -d' ' -f1)
# sanity: google publishes sha1 f574d3165405bd59ffc5edaadac02689075a729f for this file
NDK_SHA1=$(sha1sum /tmp/ndk-verify.zip | cut -d' ' -f1)
rm /tmp/ndk-verify.zip
if [ "$NDK_SHA1" != "f574d3165405bd59ffc5edaadac02689075a729f" ]; then
  echo "  WARNING: ndk sha1 mismatch, expected f574d31... got $NDK_SHA1 - do not trust this download"
  exit 1
fi
echo "  ndk: $NDK_SHA (sha1 verified against google)"

sed -i "s|^ENV GO_SHA256=.*|ENV GO_SHA256=$GO_SHA|" Dockerfile
sed -i "s|^ENV NDK_SHA256=.*|ENV NDK_SHA256=$NDK_SHA|" Dockerfile

echo
echo "Dockerfile updated:"
grep "SHA256=" Dockerfile
