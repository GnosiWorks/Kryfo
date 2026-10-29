#!/bin/bash
# builds the release apks in the pinned container, at the path f-droid
# builds in, then signs them here with apksigner.
#
# this is the release build, not a check on one. the four apks it leaves
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
#   ./release.sh --fetch      only fill cache/ with the commit's pub,
#                             gradle and shim crate dependencies (needs the
#                             network)
#   ./release.sh --offline    fetch if cache/ is not for this commit, then
#                             build with the container's network cut
#   ./release.sh --rc         a release candidate (with KRYFO_RC=1): the one
#                             build the developer's phone takes before the
#                             final, whose dev card it has not made yet. it
#                             goes to out/rc/, every file named -rc, its
#                             version name <version>-rc. verify it with
#                             HALO_BUILD_NAME=<version>-rc ./verify.sh
set -e
cd "$(dirname "$0")"

# KRYFO_REPRO_IMAGE names the image apart, for a box building two trees at once
IMAGE=${KRYFO_REPRO_IMAGE:-kryfo-repro}
REF=HEAD
SIGN=1
MODE=
RC=
while [ $# -gt 0 ]; do
  case "$1" in
    --rc) RC=1; shift ;;
    --ref) REF="$2"; shift 2 ;;
    --unsigned) SIGN=; shift ;;
    --fetch) MODE=fetch; shift ;;
    --offline) MODE=offline; shift ;;
    -h|--help) sed -n '2,27p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
# fetching builds nothing that ships, so there is nothing to sign
[ "$MODE" = fetch ] && SIGN=
# a final pins the developer card the candidate's first start made on his
# phone. KRYFO_RC=1 is for the candidate alone: a final is never built
# with it set, and a candidate is never built without it
if [ -n "${KRYFO_RC:-}" ] && [ -z "$RC" ]; then
  echo "KRYFO_RC is set: a final release is never built with it (--rc for a candidate)" >&2
  exit 2
fi
if [ -n "$RC" ] && [ "${KRYFO_RC:-}" != 1 ]; then
  echo "--rc needs KRYFO_RC=1" >&2
  exit 2
fi

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
# a signed release pins the key that signs version.json: 32 bytes, not the
# placeholder
if [ -n "$SIGN" ]; then
  git -C "$REPO" show "$COMMIT:mobile/lib/update_check.dart" |
    "$REPO/scripts/check-version-key.sh" - >/dev/null || exit 2
fi
if [ -n "$RC" ]; then
  echo "== release candidate: the dev card is not checked"
elif [ "$MODE" != fetch ]; then
  git -C "$REPO" show "$COMMIT:mobile/lib/devchat/dev_key.dart" |
    "$REPO/scripts/check-dev-card.sh" - || exit 2
fi
# a candidate never lands where a final does, and never looks like one
OUT=out
BUILD_NAME=
if [ -n "$RC" ]; then
  OUT=out/rc
  version=$(git -C "$REPO" show "$COMMIT:mobile/pubspec.yaml" | sed -n 's/^version: *\([^+ ]*\).*/\1/p')
  [ -n "$version" ] || { echo "no version in mobile/pubspec.yaml at $COMMIT" >&2; exit 2; }
  BUILD_NAME="$version-rc"
  echo "== release candidate $BUILD_NAME, into $OUT"
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

SHIM_TARGET=mobile/native/kryfo_signal/target

fetch_step() {
  clone_to "$WORK/fetch" || return 1
  rm -rf cache/pub cache/gradle cache/cargo cache/commit "$WORK/fetch-out"
  mkdir -p cache/pub cache/gradle cache/cargo "$WORK/fetch-out"
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
    cp -a "$WORK/fetch/$SHIM_TARGET/vendor" "$WORK/fetch/$SHIM_TARGET/vendor.toml" \
      "$WORK/fetch/$SHIM_TARGET/vendor.lock" cache/cargo/ &&
    du -sh cache/pub cache/gradle cache/cargo
}

build_step() {
  clone_to "$WORK/src" || return 1
  # the shim's crates where build-android.sh looks for them
  if [ "$MODE" = offline ]; then
    mkdir -p "$WORK/src/$SHIM_TARGET"
    cp -a cache/cargo/. "$WORK/src/$SHIM_TARGET/"
  fi
  rm -rf "$WORK/out"
  mkdir -p "$WORK/out"
  "${RUN[@]}" "$@" ${BUILD_NAME:+-e "HALO_BUILD_NAME=$BUILD_NAME"} \
    -v "$WORK/src:/home/vagrant/build/app.kryfo" \
    -v "$WORK/out:/out" \
    "$IMAGE"
}

echo "== image"
with_retry image docker build -q -t "$IMAGE" .

if [ -n "$MODE" ] && [ "$(cat cache/commit 2>/dev/null)" != "$COMMIT" ]; then
  echo "== fetching pub, gradle and shim crate dependencies into repro/cache"
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

mkdir -p "$OUT"
rm -f "$OUT"/app-*.apk
cp "$WORK/out/"app-*.apk "$OUT"/
# a candidate's files carry -rc in their names
if [ -n "$RC" ]; then
  for f in "$OUT"/app-*.apk; do
    case "$f" in *-rc.apk) ;; *) mv "$f" "${f%.apk}-rc.apk" ;; esac
  done
fi

# a test engine that acts as if tor were blocked never ships. an apk
# without an engine is refused too, so this cannot pass by finding nothing
for f in "$OUT"/app-*.apk; do
  unzip -l "$f" | grep -q 'lib/[^/]*/libhalo\.so' || { echo "$f has no engine" >&2; exit 1; }
  unzip -l "$f" | grep -q 'lib/[^/]*/libkryfo_signal\.so' || { echo "$f has no signal shim" >&2; exit 1; }
  # built from the libsignal and spqr the lock pins, as ks_build_info says
  ./shim-check.sh --ref "$COMMIT" "$f" || exit 1
  scan=$(mktemp -d)
  unzip -q -o "$f" 'lib/*/libhalo.so' -d "$scan"
  if ! ../engine/censor-scan.sh "$scan"/lib/*/libhalo.so; then
    rm -rf "$scan"
    echo "$f carries the test censor, not releasing" >&2
    exit 1
  fi
  rm -rf "$scan"
  # the universal apk: both arm abis, each whole, and no other
  case "$f" in
    */app-universal-release*)
      got=$(unzip -Z1 "$f" 'lib/*' | grep -v '/$' | cut -d/ -f2 | sort -u | tr '\n' ' ')
      [ "$got" = "arm64-v8a armeabi-v7a " ] || { echo "$f carries the abis $got" >&2; exit 1; }
      for a in arm64-v8a armeabi-v7a; do
        for l in libflutter libapp libhalo libkryfo_signal; do
          unzip -Z1 "$f" | grep -qx "lib/$a/$l.so" || { echo "$f has no lib/$a/$l.so" >&2; exit 1; }
        done
      done
      ;;
  esac
done
ls "$OUT"/app-universal-release*.apk >/dev/null 2>&1 || { echo "the container made no universal apk" >&2; exit 1; }

# the shim's complete source goes on the release page beside the apks
# (agpl and gpl section 6), from the vendor dir this build used
rm -f "$OUT"/libsignal-*-source.tar.gz "$OUT"/libkryfo_signal-*-source.tar.gz
./shim-source.sh "$WORK/src/$SHIM_TARGET/vendor" "$OUT"
if [ -n "$RC" ]; then
  for f in "$OUT"/libkryfo_signal-*-source.tar.gz; do
    case "$f" in *-rc.tar.gz) ;; *) mv "$f" "${f%.tar.gz}-rc.tar.gz" ;; esac
  done
fi

if [ -z "$SIGN" ]; then
  echo
  ( cd "$OUT" && sha256sum app-*.apk libkryfo_signal-*-source*.tar.gz )
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
for f in "$OUT"/app-*-release.apk "$OUT"/app-*-release-rc.apk; do
  [ -f "$f" ] || continue
  # a candidate is signed only in out/rc, under its -rc name
  if [ -n "$RC" ]; then
    case "$f" in out/rc/*-rc.apk) ;; *) echo "refusing to sign a candidate as $f" >&2; exit 1 ;; esac
  fi
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

ls "$OUT"/app-*-release*.apk >/dev/null 2>&1 || { echo "the container produced no apks" >&2; exit 1; }
echo
echo "== $OUT/"
( cd "$OUT" && sha256sum app-*.apk libkryfo_signal-*-source*.tar.gz )
echo
echo "these are the release. attach them and the shim's source tarball to"
echo "the github release."
echo "to have someone else confirm them, or to check them later:"
echo "  ${BUILD_NAME:+HALO_BUILD_NAME=$BUILD_NAME }./verify.sh --ref $REF $OUT/app-*-release*.apk"
