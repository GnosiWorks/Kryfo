#!/bin/bash
# builds the release apks in the pinned container, at the path f-droid
# builds in, then signs them here with apksigner.
#
# this is the release build, not a check on one. the three apks it leaves
# in repro/out are what goes on the github release, so there is nothing to
# reconcile afterwards: f-droid rebuilding the tag gets the same bytes by
# construction. the dart snapshot and two plugin libraries bake in the
# build path, so a build anywhere else cannot match, whatever else is
# pinned.
#
# the container builds unsigned and the keystore never goes into it.
# signing adds only what verify.sh leaves out of the comparison, so it
# changes nothing that is checked.
#
# usage:
#   ./release.sh              build the current commit and sign it
#   ./release.sh --ref v0.2.8
#   ./release.sh --unsigned   stop after the container, sign it yourself
#   ./release.sh --fetch      only fill cache/ with the commit's pub and
#                             gradle dependencies (needs the network)
#   ./release.sh --offline    fetch if cache/ is not for this commit, then
#                             build with the container's network cut
set -e
cd "$(dirname "$0")"

IMAGE=kryfo-repro
REF=HEAD
SIGN=1
MODE=
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) REF="$2"; shift 2 ;;
    --unsigned) SIGN=; shift ;;
    --fetch) MODE=fetch; shift ;;
    --offline) MODE=offline; shift ;;
    -h|--help) sed -n '2,23p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
# fetching builds nothing that ships, so there is nothing to sign
[ "$MODE" = fetch ] && SIGN=

command -v docker >/dev/null || { echo "docker is not installed" >&2; exit 2; }
docker info >/dev/null 2>&1 || { echo "the docker daemon is not running" >&2; exit 2; }

REPO=$(git rev-parse --show-toplevel)
COMMIT=$(git rev-parse "$REF")
# what ships must be a commit. a dirty tree builds something nobody else
# can ever rebuild, which is the whole thing this is here to prevent.
if [ -n "$(git -C "$REPO" status --porcelain --untracked-files=no)" ]; then
  echo "the working tree has uncommitted changes. commit them first." >&2
  exit 2
fi
echo "== release build of $REF ($COMMIT)"

KEYPROPS="$REPO/mobile/android/key.properties"
APKSIGNER=$(ls -d "${ANDROID_HOME:-$HOME/android-sdk}"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1)
if [ -n "$SIGN" ]; then
  [ -f "$KEYPROPS" ] || { echo "no mobile/android/key.properties; use --unsigned" >&2; exit 2; }
  [ -n "$APKSIGNER" ] || { echo "no apksigner in the android sdk build-tools" >&2; exit 2; }
  KEYSTORE=$(grep '^storeFile=' "$KEYPROPS" | cut -d= -f2-)
  [ -f "$KEYSTORE" ] || { echo "keystore not found: $KEYSTORE" >&2; exit 2; }
fi

WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
mkdir -p out cache

# a step that fails on the network (a dropped connection, a mirror or a vpn
# answering 404) runs again, twice at most, after a pause. anything else is
# a real failure and stops at once: it would only fail the same way again.
TRIES=3
PAUSE=60
NET_ERRORS='could not (get|head|download) |could not (resolve|find) [a-z0-9_.-]+:[a-z0-9_.-]+|received status code [45][0-9][0-9]|server returned http response code|was not found in any of the following sources|could not install gradle distribution|connection (reset|refused|closed|timed out)|connect timed out|read timed out|java\.net\.[a-z]*exception|socketexception|handshakeexception|tlsexception|clientexception|failed host lookup|got socket error|could not find package|http error [45][0-9][0-9]|failed to download|network is unreachable|no route to host|temporary failure (in name resolution|resolving)|could not resolve host|unable to access|i/o timeout|curl: \((6|7|18|28|35|52|56)\)'
with_retry() {
  local what="$1" try=1 rc hit
  shift
  local log="out/$what.log"
  while :; do
    set +e
    "$@" 2>&1 | tee "$log"
    rc=${PIPESTATUS[0]}
    set -e
    [ "$rc" -eq 0 ] && return 0
    hit=$(tail -n 80 "$log" | grep -iE -m1 "$NET_ERRORS" || true)
    if [ -z "$hit" ]; then
      echo >&2
      echo "the $what step failed, and not on the network, so it is not retried." >&2
      echo "the lines above say why. the whole log: repro/$log" >&2
      exit 1
    fi
    if [ "$try" -ge "$TRIES" ]; then
      echo >&2
      echo "giving up: the $what step failed $try times on the network. the last error:" >&2
      echo "  $hit" >&2
      echo "check the connection. a vpn can make google's maven answer 404." >&2
      echo "the whole log: repro/$log" >&2
      exit 1
    fi
    echo
    echo "== the $what step failed on the network:"
    echo "   $hit"
    echo "== trying again in ${PAUSE}s ($((TRIES - try)) left)"
    sleep "$PAUSE"
    try=$((try + 1))
    PAUSE=$((PAUSE * 2))
  done
}

# a fresh clone for every try, so a retry never builds on what a failed
# one left behind
clone_to() {
  rm -rf "$1"
  git clone -q "$REPO" "$1" && git -C "$1" checkout -q "$COMMIT"
}

# cgo opens more files at once building tor and openssl than the 1024 a
# container gets by default
RUN=(docker run --rm --ulimit nofile=65536:65536 -u "$(id -u):$(id -g)")

fetch_step() {
  clone_to "$WORK/fetch" || return 1
  rm -rf cache/pub cache/gradle cache/commit "$WORK/fetch-out"
  mkdir -p cache/pub cache/gradle "$WORK/fetch-out"
  "${RUN[@]}" -e HALO_STEP=fetch \
    -v "$WORK/fetch:/home/vagrant/build/app.kryfo" \
    -v "$PWD/cache/pub:/home/vagrant/.pub-cache" \
    -v "$PWD/cache/gradle:/home/vagrant/.gradle" \
    -v "$WORK/fetch-out:/out" \
    "$IMAGE" || return 1
  # keep only what was downloaded: gradle's dependency cache and its
  # distribution. transforms, compiled scripts and daemon state are left
  # for the release build to make itself, so nothing built here reaches its
  # output. done here, once the container and its daemons are gone.
  find cache/gradle -mindepth 1 -maxdepth 1 ! -name caches ! -name wrapper -exec rm -rf {} + &&
    find cache/gradle/caches -mindepth 1 -maxdepth 1 ! -name modules-2 -exec rm -rf {} + &&
    du -sh cache/pub cache/gradle
}

build_step() {
  clone_to "$WORK/src" || return 1
  rm -rf "$WORK/out"
  mkdir -p "$WORK/out"
  "${RUN[@]}" "$@" \
    -v "$WORK/src:/home/vagrant/build/app.kryfo" \
    -v "$WORK/out:/out" \
    "$IMAGE"
}

echo "== image"
with_retry image docker build -q -t "$IMAGE" .

if [ -n "$MODE" ] && [ "$(cat cache/commit 2>/dev/null)" != "$COMMIT" ]; then
  echo "== fetching pub and gradle dependencies into repro/cache"
  with_retry fetch fetch_step
  rm -rf "$WORK/fetch" "$WORK/fetch-out"
  echo "$COMMIT" > cache/commit
elif [ -n "$MODE" ]; then
  echo "== repro/cache already holds $COMMIT's dependencies"
fi
[ "$MODE" = fetch ] && exit 0

if [ "$MODE" = offline ]; then
  echo "== building with no network (no gradle cache from this machine is shared)"
  # the build gets a copy, so the cache stays exactly what was fetched.
  # the paths inside the container are the ones a networked build uses.
  mkdir -p "$WORK/cache"
  cp -a cache/pub cache/gradle "$WORK/cache/"
  set +e
  build_step --network none -e HALO_OFFLINE=1 \
    -v "$WORK/cache/pub:/home/vagrant/.pub-cache" \
    -v "$WORK/cache/gradle:/home/vagrant/.gradle" \
    2>&1 | tee out/build.log
  rc=${PIPESTATUS[0]}
  set -e
  if [ "$rc" -ne 0 ]; then
    echo >&2
    echo "the offline build failed. the whole log: repro/out/build.log" >&2
    if grep -qiE 'offline mode|no cached version' out/build.log; then
      echo "gradle wanted something that is not in repro/cache. run ./release.sh --fetch" >&2
      echo "after deleting repro/cache, or build without --offline." >&2
    fi
    exit 1
  fi
else
  echo "== building (no gradle cache is shared: the host's journal lock deadlocks)"
  with_retry build build_step
fi

rm -f out/app-*.apk
cp "$WORK/out/"app-*.apk out/

if [ -z "$SIGN" ]; then
  echo
  ( cd out && sha256sum app-*.apk )
  echo
  echo "unsigned. sign each with:"
  echo "  apksigner sign --ks <keystore> --v1-signing-enabled false app-<abi>-release.apk"
  exit 0
fi

# the passwords are read here and passed on stdin, so they are never an
# argument anyone can see in a process list
STOREPASS=$(grep '^storePassword=' "$KEYPROPS" | cut -d= -f2-)
KEYPASS=$(grep '^keyPassword=' "$KEYPROPS" | cut -d= -f2-)
ALIAS=$(grep '^keyAlias=' "$KEYPROPS" | cut -d= -f2-)

echo
echo "== signing"
# flutter renames the output whether or not it is signed, so these carry
# the plain name and are signed in place
for f in out/app-*-release.apk; do
  [ -f "$f" ] || { echo "the container produced no apks" >&2; exit 1; }
  # --alignment-preserved, or apksigner re-pads every entry on the way
  # through, and f-droid compares their unsigned build to ours with the
  # signature cut out, byte for byte. with the flag signing is a pure
  # insertion.
  # v2/v3 only: f-droid copies our signature onto their unsigned build, and
  # v1 entries inside the zip move bytes around, so the v2 digest fails.
  # minSdk is 24 and v1 is only needed below that.
  printf '%s\n%s\n' "$STOREPASS" "$KEYPASS" | "$APKSIGNER" sign \
    --ks "$KEYSTORE" --ks-key-alias "$ALIAS" \
    --ks-pass stdin --key-pass stdin \
    --v1-signing-enabled false \
    --v2-signing-enabled true \
    --v3-signing-enabled true \
    --alignment-preserved \
    "$f"
  rm -f "$f.idsig"
  echo "  $(basename "$f")"
  "$APKSIGNER" verify --print-certs "$f" 2>/dev/null \
    | grep -i "SHA-256 digest" | head -1 | sed 's/^/    /'
done

echo
echo "== out/"
( cd out && sha256sum app-*.apk )
echo
echo "these are the release. attach them to the github release."
echo "to have someone else confirm them, or to check them later:"
echo "  ./verify.sh --ref $REF out/app-arm64-v8a-release.apk ..."
