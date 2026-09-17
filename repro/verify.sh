#!/bin/bash
# builds the whole apk in the pinned container, twice, and asks the two
# questions that decide whether f-droid will publish us.
#
#   1. does the apk you published match a build of that commit at the path
#      f-droid builds in? every zip entry, byte for byte, and then
#      apksigcopier compare, which is the check f-droid itself runs.
#   2. does that same source produce the same bytes somewhere else?
#
# the second one is the one we learned the hard way. our own container
# agreeing with our own build at one path says our pipeline is
# deterministic, which is not the question anyone is asking. f-droid built
# 0.2.8 on their machine and disagreed with ours on libdartjni.so, and
# nothing here could see it, because both sides of the comparison were the
# same build at the same path.
#
# only the signature is left out: the container builds unsigned and the
# published apk is signed, so the v1 files exist on one side only, and the
# v2/v3 signature lives in the signing block, which is not an entry.
#
# usage:
#   ./verify.sh app-arm64-v8a-release.apk [more.apk...]
#   ./verify.sh --ref v0.2.8 app-arm64-v8a-release.apk
#   ./verify.sh --compare built.apk published.apk    no container, diff only
#
# options:
#   --ref <rev>   the commit to build (default: HEAD of this repo). a release
#                 is verified against its tag.
#   --no-cross    skip the second build. halves the wait, and gives up the
#                 only check that speaks to what f-droid's machine will do.
#                 fine while iterating, not before a tag.
#   --cache       mount ~/.pub-cache into the container so the second run
#                 does not fetch every package again. the gradle cache is
#                 never shared: the host's journal lock deadlocks against
#                 the container's daemon and the build hangs.
#   --keep        leave the checkouts and the container output in place
set -e
cd "$(dirname "$0")"

IMAGE=kryfo-repro
REF=HEAD
CACHE=
KEEP=
CROSS=1
APKS=()

# where f-droid builds. the release has to be made here, because the dart
# snapshot bakes this path in and nothing can strip it.
FDROID_PATH=/home/vagrant/build/app.kryfo
# deliberately unlike the above in length and shape, so anything that
# leaks a path shows up as a difference rather than by luck
ALT_PATH=/home/vagrant/elsewhere/kryfo-built-somewhere-else

# entries allowed to differ between the two builds, as an extended regex
# over the unzipped paths. keep this list as short as the truth allows:
# every name here is a thing we have given up on making path-independent.
PATH_DEPENDENT='^\./lib/[^/]+/libapp\.so$'

while [ $# -gt 0 ]; do
  case "$1" in
    --ref) REF="$2"; shift 2 ;;
    --cache) CACHE=1; shift ;;
    --keep) KEEP=1; shift ;;
    --no-cross) CROSS=; shift ;;
    --compare) shift; COMPARE_ONLY=1 ;;
    -h|--help) sed -n '2,36p' "$0"; exit 0 ;;
    *) APKS+=("$1"); shift ;;
  esac
done

# every zip entry with its sha256, minus the v1 signature files
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

# names the entries that differ between two entry listings
differing() {
  diff <(echo "$1") <(echo "$2") | awk '/^[<>]/ {print $3}' | LC_ALL=C sort -u
}

hash_of() { echo "$1" | awk -v e="$2" '$2==e {print substr($1,1,12)}'; }

# prints MATCH or the differing entries; returns 1 on a difference
compare() {
  local built="$1" shipped="$2"
  local a b
  a=$(entries "$built"); b=$(entries "$shipped")
  if [ "$a" = "$b" ]; then
    # the entries agree. now the comparison f-droid actually makes, with the
    # tool they make it with: apksigcopier copies the shipped apk's signature
    # onto the container build and the result has to be the shipped apk,
    # byte for byte. entry hashes matched on 0.2.8 and 0.2.10 and both were
    # refused, because apksigner had re-padded the zip around the entries.
    # not a raw cmp of the two with the signature cut out: apksig page-aligns
    # the start of the signing block with zeros, their build does not have
    # them, their tool puts them back, and a cmp is wrong about it forever.
    local sh bu out
    sh=$(realpath "$shipped"); bu=$(realpath "$built")
    docker image inspect "$IMAGE" >/dev/null 2>&1 || docker build -q -t "$IMAGE" . >/dev/null
    if out=$(docker run --rm --entrypoint sh -u "$(id -u):$(id -g)" \
        -v "$sh:/shipped.apk:ro" -v "$bu:/built.apk:ro" "$IMAGE" -c \
        'PATH=$(ls -d /opt/android-sdk/build-tools/* | sort -V | tail -1):$PATH
         apksigcopier compare /shipped.apk --unsigned /built.apk' 2>&1); then
      echo "  MATCH  $(basename "$shipped"): apksigcopier puts its signature on the container build and gets the same file"
      return 0
    fi
    echo "  CONTAINER DIFFERS  $(basename "$shipped"): every entry matches, the zip around them does not"
    echo "$out" | tail -3 | sed 's/^/    /'
    local stripped
    stripped=$(mktemp)
    python3 "$(dirname "$0")/unsigned_of.py" "$shipped" "$stripped"
    echo "    first byte that differs with the signature cut out: $(cmp "$stripped" "$built" 2>&1 | head -1 | sed 's/.*differ: //')"
    rm -f "$stripped"
    echo "    this is the check f-droid runs. the usual cause is the signer re-padding the"
    echo "    zip: release.sh passes --alignment-preserved to apksigner for that reason."
    return 1
  fi
  echo "  DIFFERS  $(basename "$shipped")"
  differing "$a" "$b" | while read -r e; do
    printf '    %-48s built %-12s shipped %-12s\n' \
      "$e" "$(hash_of "$a" "$e")" "$(hash_of "$b" "$e")"
  done
  return 1
}

# the cross-path check: the same source built in two places. anything that
# differs outside the allowlist means this source is not reproducible
# anywhere but here.
compare_cross() {
  local one="$1" two="$2" name="$3"
  local a b bad
  a=$(entries "$one"); b=$(entries "$two")
  bad=$(differing "$a" "$b" | grep -Ev "$PATH_DEPENDENT" || true)
  if [ -z "$bad" ]; then
    echo "  SAME     $name is the same bytes built at either path"
    return 0
  fi
  echo "  PATH-DEPENDENT  $name"
  echo "$bad" | while read -r e; do
    printf '    %-48s here %-12s elsewhere %-12s\n' \
      "$e" "$(hash_of "$a" "$e")" "$(hash_of "$b" "$e")"
  done
  cat <<EOF

    what this means: the entries above come out different depending on
    where the source was built. f-droid builds this commit on their own
    machine. if a file changes with the build path, their rebuild will not
    agree with the apk you published, no matter what our own container
    says, and they will refuse the release. this is exactly how 0.2.8
    failed on libdartjni.so.

    the usual cause is a native library keeping a gnu build-id, or an
    absolute path baked into its objects. the cmake flags that fix it are
    in mobile/android/build.gradle.kts, and repro/README.md says where
    they come from.

    lib/*/libapp.so is exempt on purpose, and is not reported here. the
    dart snapshot embeds the path of the generated plugin registrant and
    nothing can strip it, which is the whole reason release.sh builds at
    f-droid's path instead of anywhere convenient.
EOF
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
cleanup() { [ -n "$KEEP" ] || rm -rf "$WORK"; }
trap cleanup EXIT

echo "== image (the first build pulls the jdk, go, the sdk, flutter: a while)"
docker build -q -t "$IMAGE" . >/dev/null

# one clean clone and one build per path. they cannot share a tree: the
# generated plugin registrant and the build output both carry the path,
# and a reused tree would agree with itself for the wrong reason.
build_at() {
  local srcpath="$1" tag="$2"
  git clone -q "$REPO" "$WORK/$tag"
  git -C "$WORK/$tag" checkout -q "$COMMIT"
  mkdir -p "$WORK/out-$tag"
  local mounts=(-v "$WORK/$tag:$srcpath" -v "$WORK/out-$tag:/out")
  if [ -n "$CACHE" ]; then
    mkdir -p "$HOME/.pub-cache"
    mounts+=(-v "$HOME/.pub-cache:/home/vagrant/.pub-cache")
  fi
  echo "== building at $srcpath"
  # cgo opens a lot of files at once building tor and openssl. the daemon
  # hands a container 1024 by default, which is under what that needs: the
  # engine build then dies with "too many open files", sometimes, which is
  # worse than always.
  docker run --rm --ulimit nofile=65536:65536 -u "$(id -u):$(id -g)" \
    -e "HALO_SRC=$srcpath" -w "$srcpath" "${mounts[@]}" "$IMAGE"
}

build_at "$FDROID_PATH" primary
[ -n "$CROSS" ] && build_at "$ALT_PATH" alt

# the container's apk is unsigned, so its name may carry -unsigned. match
# on the abi rather than the whole basename.
built_for() {
  local abi="$1" tag="$2"
  ls "$WORK/out-$tag/app-$abi-release"*.apk 2>/dev/null | head -1
}

echo
echo "== against what you published"
rc=0
for shipped in "${APKS[@]}"; do
  abi=$(basename "$shipped" | sed -n 's/^app-\(.*\)-release.*\.apk$/\1/p')
  built=$(built_for "$abi" primary)
  if [ -z "$abi" ] || [ ! -f "$built" ]; then
    echo "  the container made nothing for $(basename "$shipped")"
    rc=1
    continue
  fi
  compare "$built" "$shipped" || rc=1
done

if [ -n "$CROSS" ]; then
  echo
  echo "== the same source built somewhere else"
  for shipped in "${APKS[@]}"; do
    abi=$(basename "$shipped" | sed -n 's/^app-\(.*\)-release.*\.apk$/\1/p')
    one=$(built_for "$abi" primary)
    two=$(built_for "$abi" alt)
    if [ -z "$one" ] || [ -z "$two" ]; then
      echo "  no pair to compare for $abi"
      rc=1
      continue
    fi
    compare_cross "$one" "$two" "app-$abi-release.apk" || rc=1
  done
else
  echo
  echo "== cross-path check skipped (--no-cross)"
  echo "   our pipeline agreeing with itself is not what f-droid asks."
fi

[ -n "$KEEP" ] && echo && echo "kept: $WORK"
exit $rc
