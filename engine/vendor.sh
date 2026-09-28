#!/usr/bin/env bash
# rebuilds ./vendor from go.mod and go.sum, use it instead of `go mod vendor`.
# go mod vendor copies only go package dirs, while go-libtor and a few others
# compile c and asm from dirs next to them, and it knows nothing of the
# 32-bit header fix in vendor-patches/ (see VENDOR_PATCHES.md). this copies
# those modules whole from the module cache and applies the patch.
# modules missing from the cache are downloaded. after it: git status should
# show only what the go.mod change meant, then HALO_FULL=1 ./build.sh
set -euo pipefail
cd "$(dirname "$0")"
ulimit -n "$(ulimit -Hn)"
export GOFLAGS=-mod=mod
MC="$(go env GOMODCACHE)"

rm -rf vendor
go mod vendor

for p in github.com/alexballas/go-libtor github.com/bytedance/sonic \
         github.com/bytedance/sonic/loader github.com/cloudwego/base64x \
         github.com/twitchyliquid64/golang-asm; do
  v="$(awk -v p="$p" '$1 == "#" && $2 == p {print $3}' vendor/modules.txt)"
  [ -n "$v" ] || { echo "not in vendor/modules.txt: $p"; exit 1; }
  cp -r --update=none "$MC/$p@$v/." "vendor/$p/"
done
chmod -R u+w vendor

# what the repo does not keep: ignored files (keys and certs of upstream
# tests), libevent's pkgconfig, a stray .gitignore, and the upper-case notes
# at a module's top other than its readme, licence and changelog
git ls-files -z -o -i --exclude-standard vendor | xargs -0 -r rm -f
rm -rf vendor/github.com/alexballas/go-libtor/builddeps/libevent/usr/local/lib
rm -f vendor/github.com/nbd-wtf/go-nostr/.gitignore
awk '$1 == "#" && $3 !~ /^=>/ {print $2}' vendor/modules.txt | while read -r m; do
  for f in "vendor/$m"/*.md; do
    n="$(basename "$f")"
    case "$n" in README* | LICENSE* | CHANGELOG*) continue ;; esac
    if [[ "$n" =~ ^[A-Z_]+\.md$ ]]; then rm -f "$f"; fi
  done
done
find vendor -type d -empty -delete

patch -s -p1 -d vendor/github.com/alexballas/go-libtor \
  < vendor-patches/go-libtor.patch
echo "vendor rebuilt"
