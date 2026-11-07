#!/bin/sh
# sums.sh on fake release files: repro/sums-test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
run() { "$here/sums.sh" "$@" >"$t/log" 2>&1; }

d=$t/out
mkdir "$d"
for a in arm64-v8a armeabi-v7a universal x86_64; do echo "$a" >"$d/app-$a-release.apk"; done
echo src >"$d/libkryfo_signal-0.6.0-source.tar.gz"

run "$d" 0.6.0 && ok "apks only" || bad "apks only"
[ "$(wc -l <"$d/SHA256SUMS")" -eq 5 ] && ok "five lines" || bad "five lines"
[ ! -e "$d/SHA256SUMS-windows" ] && [ ! -e "$d/SHA256SUMS-linux" ] && ok "no windows or linux file" || bad "no windows or linux file"
run --check "$d" 0.6.0 && ok "check passes" || bad "check passes"

echo exe >"$d/kryfo-0.6.0-windows-x64-setup.exe"
run "$d" 0.6.0 && bad "installer without zip" || ok "installer without zip refused"
echo zip >"$d/kryfo-0.6.0-windows-x64.zip"
echo tgz >"$d/kryfo-0.6.0-beta-linux-x64.tar.gz"
run "$d" 0.6.0 && ok "all three" || bad "all three"
[ "$(wc -l <"$d/SHA256SUMS-windows")" -eq 2 ] && ok "windows two lines" || bad "windows two lines"
grep -q '  kryfo-0.6.0-beta-linux-x64.tar.gz$' "$d/SHA256SUMS-linux" && ok "linux line" || bad "linux line"
! grep -q windows "$d/SHA256SUMS" && ! grep -q linux "$d/SHA256SUMS" && ok "apk sums stay apk only" || bad "apk sums stay apk only"
run --check "$d" 0.6.0 && ok "check all three" || bad "check all three"
(cd "$d" && sha256sum --strict -c SHA256SUMS-windows >/dev/null) && ok "sha256sum reads it" || bad "sha256sum reads it"

echo changed >"$d/kryfo-0.6.0-windows-x64.zip"
run --check "$d" 0.6.0 && bad "changed zip passes" || ok "changed zip caught"
echo zip >"$d/kryfo-0.6.0-windows-x64.zip"

echo tgz >"$d/kryfo-0.6.0-linux-x64.tar.gz"
run "$d" 0.6.0 && bad "two linux tarballs" || ok "two linux tarballs refused"
rm "$d/kryfo-0.6.0-linux-x64.tar.gz"

echo rc >"$d/app-arm64-v8a-release-rc.apk"
run "$d" 0.6.0 && bad "candidate file" || ok "candidate file refused"
rm "$d/app-arm64-v8a-release-rc.apk"
run "$d" 0.6.0-rc && bad "candidate version" || ok "candidate version refused"

rm "$d/app-universal-release.apk"
run "$d" 0.6.0 && bad "missing universal" || ok "missing universal refused"
run "$d" 0.6.1 && bad "wrong version" || ok "wrong version refused"

exit $fail
