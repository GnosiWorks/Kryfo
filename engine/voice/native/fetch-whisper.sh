#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# unpacks the pinned whisper.cpp into .third_party/ and prints its path. the
# tarball is github's archive of the pinned commit, checked against its
# sha256 before anything reads it. KV_WHISPER_TARBALL takes a copy fetched
# beforehand, for a build without the network; KV_WHISPER_DIR a clean git
# checkout of the pinned commit, as an f-droid srclib is. both give the
# same files. the dot keeps go's tools and the engine's source checks out
# of whisper.cpp's own go bindings.
set -euo pipefail
cd "$(dirname "$0")"
. ./whisper.lock

DEST=".third_party/whisper.cpp-$WHISPER_COMMIT"
STAMP="$DEST/.kv-pin"
if [[ -f "$STAMP" && "$(cat "$STAMP")" == "$WHISPER_COMMIT" ]]; then
  echo "$(pwd)/$DEST"
  exit 0
fi

# a fresh place to unpack into, once the source is known to be the pin
fresh() {
  rm -rf "$DEST" "$DEST.tmp"
  mkdir -p "$DEST.tmp"
}

if [[ -n "${KV_WHISPER_DIR:-}" ]]; then
  head="$(git -C "$KV_WHISPER_DIR" rev-parse HEAD)"
  if [[ "$head" != "$WHISPER_COMMIT" ]]; then
    echo "error: $KV_WHISPER_DIR is at $head, pinned $WHISPER_COMMIT" >&2
    exit 1
  fi
  if [[ -n "$(git -C "$KV_WHISPER_DIR" status --porcelain)" ]]; then
    echo "error: $KV_WHISPER_DIR has changes" >&2
    exit 1
  fi
  fresh
  git -C "$KV_WHISPER_DIR" archive --format=tar --prefix="whisper.cpp-$WHISPER_COMMIT/" "$WHISPER_COMMIT" |
    tar -x -C "$DEST.tmp" --no-same-owner --no-same-permissions
  mv "$DEST.tmp/whisper.cpp-$WHISPER_COMMIT" "$DEST"
  rmdir "$DEST.tmp"
  echo "$WHISPER_COMMIT" >"$STAMP"
  echo "$(pwd)/$DEST"
  exit 0
fi

mkdir -p .third_party/dl
TAR=".third_party/dl/whisper.cpp-$WHISPER_COMMIT.tar.gz"
if [[ -n "${KV_WHISPER_TARBALL:-}" ]]; then
  cp "$KV_WHISPER_TARBALL" "$TAR"
elif [[ ! -f "$TAR" ]]; then
  command -v curl >/dev/null || { echo "error: curl not found" >&2; exit 1; }
  curl -fsSL --retry 2 -o "$TAR.part" \
    "https://github.com/ggml-org/whisper.cpp/archive/$WHISPER_COMMIT.tar.gz" >&2
  mv "$TAR.part" "$TAR"
fi

got="$(sha256sum "$TAR" | cut -d' ' -f1)"
if [[ "$got" != "$WHISPER_SHA256" ]]; then
  # a wrong file would only fail the same way again
  rm -f "$TAR"
  echo "error: whisper.cpp tarball sha256 $got, pinned $WHISPER_SHA256" >&2
  exit 1
fi

fresh
tar -xzf "$TAR" -C "$DEST.tmp" --no-same-owner --no-same-permissions
mv "$DEST.tmp/whisper.cpp-$WHISPER_COMMIT" "$DEST"
rmdir "$DEST.tmp"
echo "$WHISPER_COMMIT" >"$STAMP"
echo "$(pwd)/$DEST"
