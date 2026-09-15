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
# signing adds the block and the v1 files, which is exactly what the
# comparison in verify.sh leaves out, so it changes nothing that is
# checked.
#
# usage:
#   ./release.sh              build the current commit and sign it
#   ./release.sh --ref v0.2.8
#   ./release.sh --unsigned   stop after the container, sign it yourself
set -e
cd "$(dirname "$0")"

IMAGE=kryfo-repro
REF=HEAD
SIGN=1
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) REF="$2"; shift 2 ;;
    --unsigned) SIGN=; shift ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

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
git clone -q "$REPO" "$WORK/src"
git -C "$WORK/src" checkout -q "$COMMIT"
mkdir -p "$WORK/out"

echo "== image"
docker build -q -t "$IMAGE" . >/dev/null
echo "== building (no gradle cache is shared: the host's journal lock deadlocks)"
docker run --rm -u "$(id -u):$(id -g)" \
  -v "$WORK/src:/home/vagrant/build/app.kryfo" \
  -v "$WORK/out:/out" \
  "$IMAGE"

mkdir -p out
rm -f out/app-*.apk
cp "$WORK/out/"app-*.apk out/

if [ -z "$SIGN" ]; then
  echo
  ( cd out && sha256sum app-*.apk )
  echo
  echo "unsigned. sign each with:"
  echo "  apksigner sign --ks <keystore> app-<abi>-release.apk"
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
  printf '%s\n%s\n' "$STOREPASS" "$KEYPASS" | "$APKSIGNER" sign \
    --ks "$KEYSTORE" --ks-key-alias "$ALIAS" \
    --ks-pass stdin --key-pass stdin \
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
