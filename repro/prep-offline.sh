#!/bin/bash
# one-time prep for the offline build. everything here survives a dying
# connection: wget -c resumes from the exact byte, the retry loops just keep
# hammering, and go modules download one at a time so a drop only loses the
# module in flight. run it, walk away, run it again if it stops - every step
# skips what's already done.
set -e
cd "$(dirname "$0")"
mkdir -p dl

GO_TGZ=dl/go1.25.0.linux-amd64.tar.gz
NDK_ZIP=dl/android-ndk-r28b-linux.zip
NDK_TGZ=dl/android-ndk-r28b.tgz
NDK_SHA1_GOOGLE=f574d3165405bd59ffc5edaadac02689075a729f

fetch() {
  until wget -c -q --show-progress "$1" -O "$2"; do
    echo "  dropped, retrying in 5s..."
    sleep 5
  done
}

# 1. go toolchain
if [ ! -f "$GO_TGZ.ok" ]; then
  echo "go 1.25.0 (~57mb)..."
  fetch "https://dl.google.com/go/go1.25.0.linux-amd64.tar.gz" "$GO_TGZ"
  # cross-check against go.dev's json index if the net allows (tiny request)
  WANT=$(curl -fsSL --max-time 20 "https://go.dev/dl/?mode=json&include=all" 2>/dev/null \
    | grep -A40 '"version": "go1.25.0"' | grep -A3 'linux-amd64.tar.gz' \
    | grep '"sha256"' | head -1 | sed 's/.*"sha256": "\([a-f0-9]*\)".*/\1/')
  GOT=$(sha256sum "$GO_TGZ" | cut -d' ' -f1)
  if [ -n "$WANT" ] && [ "$WANT" != "$GOT" ]; then
    echo "go tarball sha256 mismatch vs go.dev - do not trust, deleting"
    rm -f "$GO_TGZ"; exit 1
  fi
  [ -z "$WANT" ] && echo "  (couldn't reach go.dev index to cross-check, using local hash)"
  touch "$GO_TGZ.ok"
fi

# 2. ndk (the big one, ~700mb)
if [ ! -f "$NDK_TGZ" ]; then
  if [ ! -f "$NDK_ZIP.ok" ]; then
    echo "ndk r28b (~700mb, resumes if it dies)..."
    fetch "https://dl.google.com/android/repository/android-ndk-r28b-linux.zip" "$NDK_ZIP"
    GOT=$(sha1sum "$NDK_ZIP" | cut -d' ' -f1)
    if [ "$GOT" != "$NDK_SHA1_GOOGLE" ]; then
      echo "ndk sha1 mismatch (got $GOT) - partial or tampered, deleting"
      rm -f "$NDK_ZIP"; exit 1
    fi
    touch "$NDK_ZIP.ok"
  fi
  # repack zip -> tgz so the slim image needs no unzip (= no apt = no network)
  echo "repacking ndk zip -> tgz (a few min, local only)..."
  rm -rf dl/ndk-tmp && mkdir dl/ndk-tmp
  unzip -q "$NDK_ZIP" -d dl/ndk-tmp
  tar -C dl/ndk-tmp -czf "$NDK_TGZ" android-ndk-r28b
  rm -rf dl/ndk-tmp
fi

# 3. go module cache, one module at a time (wsl chokes on parallel downloads)
echo "go module cache..."
export GOMODCACHE="$PWD/dl/gomod"
mkdir -p "$GOMODCACHE"
cd ../engine
grep -E '^\s+[a-z]' go.mod | awk '{print $1"@"$2}' | while read -r mod; do
  until GOMODCACHE="$GOMODCACHE" go mod download "$mod" 2>/dev/null; do
    echo "  $mod dropped, retrying..."
    sleep 5
  done
  echo "  $mod ok"
done
# sweep for anything go.mod listing missed (transitive)
until GOMODCACHE="$GOMODCACHE" go mod download; do sleep 5; done
cd ../repro

# 4. fill real hashes into BOTH dockerfiles from the local bytes.
# fill-checksums.sh is dead - it re-downloaded the 700mb ndk just to hash it.
GO_SHA=$(sha256sum "$GO_TGZ" | cut -d' ' -f1)
NDK_TGZ_SHA=$(sha256sum "$NDK_TGZ" | cut -d' ' -f1)
NDK_ZIP_SHA=$(sha256sum "$NDK_ZIP" | cut -d' ' -f1)
sed -i "s|^ENV GO_SHA256=.*|ENV GO_SHA256=$GO_SHA|" Dockerfile.offline
sed -i "s|^ENV NDK_TGZ_SHA256=.*|ENV NDK_TGZ_SHA256=$NDK_TGZ_SHA|" Dockerfile.offline
sed -i "s|^ENV GO_SHA256=.*|ENV GO_SHA256=$GO_SHA|" Dockerfile
sed -i "s|^ENV NDK_SHA256=.*|ENV NDK_SHA256=$NDK_ZIP_SHA|" Dockerfile

echo
echo "done. dl/ holds everything, builds are offline from here:"
echo "  OFFLINE=1 ./verify.sh"
du -sh dl 2>/dev/null
