#!/bin/bash
# builds the release apks in the pinned container, at the path f-droid
# builds in, and signs them there with the release key.
#
# this is the release build, not a check on one. the three apks it leaves
# in repro/out are what goes on the github release, so there is nothing to
# reconcile afterwards: f-droid rebuilding the tag gets the same bytes by
# construction. the dart snapshot and two plugin libraries bake in the
# build path, so a build anywhere else cannot match, whatever else is
# pinned.
#
# usage:
#   ./release.sh              build the current commit
#   ./release.sh --ref v0.2.8
#   ./release.sh --unsigned   no keystore in the container; sign on the
#                             host yourself with apksigner
#
# the keystore is mounted read only and the generated key.properties lives
# in a temporary clone that is deleted at the end. the password is already
# in plain text in mobile/android/key.properties on this machine, so the
# container sees nothing the disk does not. --unsigned if you would rather
# it did not.
set -e
cd "$(dirname "$0")"

IMAGE=kryfo-repro
REF=HEAD
SIGN=1
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) REF="$2"; shift 2 ;;
    --unsigned) SIGN=; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
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
KEYSTORE=
if [ -n "$SIGN" ]; then
  [ -f "$KEYPROPS" ] || { echo "no mobile/android/key.properties; use --unsigned" >&2; exit 2; }
  KEYSTORE=$(grep '^storeFile=' "$KEYPROPS" | cut -d= -f2-)
  [ -f "$KEYSTORE" ] || { echo "keystore not found: $KEYSTORE" >&2; exit 2; }
fi

WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
git clone -q "$REPO" "$WORK/src"
git -C "$WORK/src" checkout -q "$COMMIT"
mkdir -p "$WORK/out"

MOUNTS=(-v "$WORK/src:/home/vagrant/build/app.kryfo" -v "$WORK/out:/out")
if [ -n "$SIGN" ]; then
  # the keystore goes in read only at a fixed path, and the clone gets a
  # key.properties pointing at it. both die with $WORK.
  cp "$KEYPROPS" "$WORK/src/mobile/android/key.properties"
  sed -i "s|^storeFile=.*|storeFile=/keystore.jks|" "$WORK/src/mobile/android/key.properties"
  MOUNTS+=(-v "$KEYSTORE:/keystore.jks:ro")
fi

echo "== image"
docker build -q -t "$IMAGE" . >/dev/null
echo "== building (no gradle cache is shared: the host's journal lock deadlocks)"
docker run --rm -u "$(id -u):$(id -g)" "${MOUNTS[@]}" "$IMAGE"

mkdir -p out
cp "$WORK/out/"app-*-release.apk out/
echo
echo "== out/"
( cd out && sha256sum app-*-release.apk )

if [ -n "$SIGN" ]; then
  APKSIGNER=$(ls -d "${ANDROID_HOME:-$HOME/android-sdk}"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1)
  if [ -n "$APKSIGNER" ]; then
    echo
    echo "== signature"
    for f in out/app-*-release.apk; do
      echo "  $(basename "$f")"
      "$APKSIGNER" verify --print-certs "$f" 2>/dev/null \
        | grep -i "SHA-256 digest" | head -1 | sed 's/^/    /'
    done
  fi
else
  echo
  echo "unsigned. sign each with:"
  echo "  apksigner sign --ks <keystore> out/app-<abi>-release.apk"
fi

echo
echo "these three are the release. attach them to the github release."
echo "to have someone else confirm them, or to check them later:"
echo "  ./verify.sh --ref $REF out/app-arm64-v8a-release.apk ..."
