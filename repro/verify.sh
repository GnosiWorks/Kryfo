#!/bin/bash
# builds the whole apk in the pinned container, from a clean checkout of one
# commit, at the path f-droid builds in, and diffs every zip entry against
# the apk you published. a MATCH means every entry in the shipped apk is byte
# for byte what this source, this toolchain and this path produce; only the
# signature is left out, because the container has no keystore and f-droid
# copies yours across before it compares. this is f-droid's own check.
#
# usage:
#   ./verify.sh app-arm64-v8a-release.apk [more.apk...]
#   ./verify.sh --ref v0.2.8 app-arm64-v8a-release.apk
#   ./verify.sh --compare built.apk published.apk    no container, diff only
#
# options:
#   --ref <rev>   the commit to build (default: HEAD of this repo). a release
#                 is verified against its tag.
#   --cache       mount ~/.gradle and ~/.pub-cache into the container so the
#                 second run does not download the world again. the build
#                 output does not depend on the caches, only the wait does.
#   --keep        leave the checkout and the container output in place
set -e
cd "$(dirname "$0")"

IMAGE=kryfo-repro
REF=HEAD
CACHE=
KEEP=
APKS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) REF="$2"; shift 2 ;;
    --cache) CACHE=1; shift ;;
    --keep) KEEP=1; shift ;;
    --compare) shift; COMPARE_ONLY=1 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) APKS+=("$1"); shift ;;
  esac
done

# every zip entry with its sha256, minus the v1 signature files (a container
# build is signed with a throwaway debug key). the v2/v3 signature lives in
# the signing block, which is not an entry, so nothing else is skipped.
entries() {
  local dir
  dir=$(mktemp -d)
  unzip -q "$1" -d "$dir"
  ( cd "$dir" && find . -type f \
      ! -regex '\./META-INF/[^/]*\.\(SF\|RSA\|DSA\|EC\)' \
      ! -path './META-INF/MANIFEST.MF' \
      | LC_ALL=C sort | xargs sha256sum )
  rm -rf "$dir"
}

# prints MATCH or the differing entries; returns 1 on a difference
compare() {
  local built="$1" shipped="$2"
  local a b
  a=$(entries "$built"); b=$(entries "$shipped")
  if [ "$a" = "$b" ]; then
    echo "  MATCH  every entry of $(basename "$shipped") is byte for byte the container build"
    return 0
  fi
  echo "  DIFFERS  $(basename "$shipped")"
  # entries whose hash or presence differ, one line each
  diff <(echo "$a") <(echo "$b") | awk '/^[<>]/ {print $3}' | LC_ALL=C sort -u | while read -r e; do
    local ha hb
    ha=$(echo "$a" | awk -v e="$e" '$2==e {print substr($1,1,12)}')
    hb=$(echo "$b" | awk -v e="$e" '$2==e {print substr($1,1,12)}')
    printf '    %-48s built %-12s shipped %-12s\n' "$e" "${ha:-missing}" "${hb:-missing}"
  done
  return 1
}

if [ -n "$COMPARE_ONLY" ]; then
  [ ${#APKS[@]} -eq 2 ] || { echo "usage: ./verify.sh --compare built.apk published.apk" >&2; exit 2; }
  compare "${APKS[0]}" "${APKS[1]}"
  exit $?
fi

[ ${#APKS[@]} -gt 0 ] || { echo "give the published apk(s) to compare against. ./verify.sh --help" >&2; exit 2; }
for f in "${APKS[@]}"; do [ -f "$f" ] || { echo "no such apk: $f" >&2; exit 2; }; done
command -v docker >/dev/null || { echo "docker is not installed" >&2; exit 2; }
docker info >/dev/null 2>&1 || { echo "the docker daemon is not running" >&2; exit 2; }

REPO=$(git rev-parse --show-toplevel)
COMMIT=$(git rev-parse "$REF")
echo "== source: $REF ($COMMIT)"
WORK=$(mktemp -d)
# a clean clone: nothing untracked, no jniLibs, no key.properties, no
# .gocache. what f-droid gets is what the container gets.
git clone -q "$REPO" "$WORK/src"
git -C "$WORK/src" checkout -q "$COMMIT"

echo "== image (the first build pulls the jdk, go, the sdk, flutter: a while)"
docker build -q -t "$IMAGE" . >/dev/null

MOUNTS=(-v "$WORK/src:/home/vagrant/build/app.kryfo" -v "$WORK/out:/out")
if [ -n "$CACHE" ]; then
  mkdir -p "$HOME/.gradle" "$HOME/.pub-cache"
  MOUNTS+=(-v "$HOME/.gradle:/home/vagrant/.gradle" -v "$HOME/.pub-cache:/home/vagrant/.pub-cache")
fi
mkdir -p "$WORK/out"
echo "== building in the container"
docker run --rm -u "$(id -u):$(id -g)" "${MOUNTS[@]}" "$IMAGE"

echo
echo "== compare"
rc=0
for shipped in "${APKS[@]}"; do
  built="$WORK/out/$(basename "$shipped")"
  if [ ! -f "$built" ]; then
    echo "  the container made no $(basename "$shipped"); it makes app-<abi>-release.apk"
    rc=1
    continue
  fi
  compare "$built" "$shipped" || rc=1
done

if [ -n "$KEEP" ]; then
  echo
  echo "kept: $WORK (src/ is the checkout, out/ the container's apks)"
else
  rm -rf "$WORK"
fi
exit $rc
