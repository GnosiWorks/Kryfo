#!/bin/bash
# checks the desktop packaging on linux, without flatpak runtimes, windows or
# inno setup: the tor pins agree, every file the flatpak manifest and the
# inno script take is where the build leaves it, tor staging refuses what it
# should, and the desktop file and metainfo validate.
#   packaging/test.sh                  stand-in bundles
#   LINUX_BUNDLE=mobile/build/linux/x64/release/bundle packaging/test.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
fail=0
ok() { echo "ok   $*"; }
no() { echo "FAIL $*"; fail=1; }
skip() { echo "skip $*"; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
pinfile="$HERE/windows/tor-pin.txt"
pin() { sed -n "s/^$1=//p" "${2:-$pinfile}"; }

# the tor.exe pin in the installer is the one in tor-pin.txt
iss_pin="$(sed -n 's/^#define TorExeSha256 "\(.*\)"$/\1/p' "$HERE/windows/kryfo.iss")"
[ -n "$iss_pin" ] && [ "$iss_pin" = "$(pin TOR_EXE_SHA256)" ] \
  && ok "kryfo.iss tor.exe pin equals tor-pin.txt" \
  || no "kryfo.iss pins '$iss_pin', tor-pin.txt pins '$(pin TOR_EXE_SHA256)'"
for k in TOR_BUNDLE_SHA256 TOR_EXE_SHA256; do
  [[ "$(pin $k)" =~ ^[0-9a-f]{64}$ ]] || no "$k is not 64 hex"
  [ "$(pin $k)" = "$(printf '0%.0s' {1..64})" ] && echo "note $k is still a placeholder"
done
v="$(pin TOR_BUNDLE_VERSION)"
[[ "$(pin TOR_BUNDLE_URL)" == */torbrowser/$v/tor-expert-bundle-windows-x86_64-$v.tar.gz ]] \
  && ok "tor bundle url names version $v" || no "tor bundle url does not match version $v"
# the installer has no version of its own, kryfo.iss reads pubspec.yaml
grep -qE '#define +AppVersion +"[0-9]' "$HERE/windows/kryfo.iss" \
  && no "kryfo.iss has a version of its own" || ok "kryfo.iss takes the version from pubspec.yaml"
grep -q '^MimeType=x-scheme-handler/kryfo;$' "$HERE/flatpak/app.kryfo.Kryfo.desktop" \
  && grep -q '^Exec=kryfo %u$' "$HERE/flatpak/app.kryfo.Kryfo.desktop" \
  && ok "kryfo: links open the app" || no "the desktop file does not take kryfo: links"
# the installer takes the shim from where its windows build leaves it
sb="$ROOT/mobile/native/kryfo_signal/build-windows.sh"
st="$(sed -n 's/^T=//p' "$sb")"
[ -n "$st" ] && grep -qF 'DLL="target/$T/release/kryfo_signal.dll"' "$sb" \
  && grep -qF "\\kryfo_signal\\target\\$st\\release\\kryfo_signal.dll\"" "$HERE/windows/kryfo.iss" \
  && ok "kryfo.iss takes kryfo_signal.dll from build-windows.sh" \
  || no "kryfo.iss and build-windows.sh disagree on kryfo_signal.dll"

# a stand-in tree with the build outputs where the build leaves them
R="$tmp/repo"
mkdir -p "$R/packaging" "$R/engine/out/windows-x64" "$R/mobile/windows/runner/resources"
cp -a "$HERE/flatpak" "$HERE/windows" "$HERE/check_packaging.py" "$R/packaging/"
cp "$ROOT/LICENSE" "$R/"
cp "$ROOT/mobile/pubspec.yaml" "$R/mobile/"
mkdir -p "$R/mobile/linux" && cp "$ROOT/mobile/linux/build-sqlcipher.sh" "$R/mobile/linux/"
cp "$ROOT/mobile/windows/runner/resources/app_icon.ico" "$R/mobile/windows/runner/resources/"
LB="$R/mobile/build/linux/x64/release/bundle"
if [ -n "${LINUX_BUNDLE:-}" ]; then
  mkdir -p "$(dirname "$LB")"
  cp -a "$(cd "$ROOT" && cd "$LINUX_BUNDLE" && pwd)" "$LB"
  echo "using the real linux bundle $LINUX_BUNDLE"
else
  # what flutter build linux leaves, with engine.cmake adding libhalo.so
  mkdir -p "$LB/lib" "$LB/data/flutter_assets"
  printf '#!/bin/sh\n' > "$LB/kryfo" && chmod +x "$LB/kryfo"
  touch "$LB/lib/libapp.so" "$LB/lib/libflutter_linux_gtk.so" "$LB/lib/libhalo.so" "$LB/lib/libsqlcipher.so.0" \
    "$LB/lib/libkryfo_signal.so" "$LB/lib/libflutter_zxing.so" "$LB/data/icudtl.dat" "$LB/data/kryfo.png" \
    "$LB/data/flutter_assets/AssetManifest.bin"
  cp -a "$ROOT/mobile/linux/icons" "$LB/data/"
fi
# what flutter build windows leaves
WB="$R/mobile/build/windows/x64/runner/Release"
mkdir -p "$WB/data/flutter_assets"
touch "$WB/kryfo.exe" "$WB/flutter_windows.dll" "$WB/flutter_secure_storage_windows_plugin.dll" \
  "$WB/data/app.so" "$WB/data/icudtl.dat" "$WB/data/flutter_assets/AssetManifest.bin"
SD="$R/mobile/native/kryfo_signal/target/x86_64-pc-windows-gnu/release"
mkdir -p "$SD" && touch "$SD/kryfo_signal.dll"

# a stand-in expert bundle, pinned in a stand-in pin file
B="$tmp/bundle"
mkdir -p "$B/tor/pluggable_transports" "$B/data" "$B/docs"
printf 'stand-in tor.exe\n' > "$B/tor/tor.exe"
touch "$B/tor/tor-gencert.exe" "$B/tor/pluggable_transports/lyrebird.exe" "$B/data/geoip"
for l in tor openssl libevent zlib; do printf 'stand-in %s licence\n' "$l" > "$B/docs/$l.txt"; done
tar -czf "$tmp/bundle.tar.gz" -C "$B" tor data docs
exe_sum="$(sha256sum "$B/tor/tor.exe" | cut -d' ' -f1)"
fake_pin="$tmp/pin.txt"
{ echo "TOR_BUNDLE_VERSION=$v"
  echo "TOR_BUNDLE_SHA256=$(sha256sum "$tmp/bundle.tar.gz" | cut -d' ' -f1)"
  echo "TOR_EXE_SHA256=$exe_sum"; } > "$fake_pin"
stage() { TOR_PIN="$1" TOR_STAGE="$R/packaging/build/windows/tor" "$HERE/windows/stage-tor.sh" "${@:2}"; }

if stage "$fake_pin" "$tmp/bundle.tar.gz" >/dev/null; then
  ok "stage-tor.sh takes the pinned bundle"
  S="$R/packaging/build/windows/tor"
  [ -f "$S/tor.exe" ] && [ -f "$S/licenses/tor.txt" ] && [ -f "$S/licenses/libevent.txt" ] \
    && [ -f "$S/licenses/openssl.txt" ] && [ -f "$S/licenses/zlib.txt" ] \
    || no "staged tor lacks tor.exe or its licenses"
  [ -e "$S/pluggable_transports" ] && no "pluggable_transports were staged"
else
  no "stage-tor.sh refused the pinned bundle"
fi
sed "s/^TOR_BUNDLE_SHA256=.*/TOR_BUNDLE_SHA256=$(printf 'a%.0s' {1..64})/" "$fake_pin" > "$tmp/pin-badtar.txt"
stage "$tmp/pin-badtar.txt" "$tmp/bundle.tar.gz" >/dev/null 2>&1 \
  && no "stage-tor.sh took a bundle with another sha256" || ok "stage-tor.sh refuses another bundle"
sed "s/^TOR_EXE_SHA256=.*/TOR_EXE_SHA256=$(printf 'b%.0s' {1..64})/" "$fake_pin" > "$tmp/pin-badexe.txt"
stage "$tmp/pin-badexe.txt" "$tmp/bundle.tar.gz" >/dev/null 2>&1 \
  && no "stage-tor.sh took another tor.exe" || ok "stage-tor.sh refuses another tor.exe"
stage "$pinfile" "$tmp/bundle.tar.gz" >/dev/null 2>&1 \
  && no "the checked-in pin took a stand-in bundle" || ok "the checked-in pin refuses a stand-in bundle"

# halo.dll carries the pin as build-windows.sh puts it there with -X
printf 'MZ\0\0%s\0\0' "$exe_sum" > "$R/engine/out/windows-x64/halo.dll"
stage "$fake_pin" --check-dll "$R/engine/out/windows-x64/halo.dll" >/dev/null \
  && ok "stage-tor.sh finds the pin in halo.dll" || no "stage-tor.sh missed the pin in halo.dll"
printf 'MZ\0\0dev build\0' > "$tmp/halo-dev.dll"
stage "$fake_pin" --check-dll "$tmp/halo-dev.dll" >/dev/null 2>&1 \
  && no "stage-tor.sh took a halo.dll without the pin" || ok "stage-tor.sh refuses a halo.dll without the pin"
# a real halo.dll holds 64 zeros in a row somewhere, so the placeholder has
# to be refused by name
printf 'MZ\0\0%s\0' "$(printf '0%.0s' {1..64})" > "$tmp/halo-zeros.dll"
sed "s/^TOR_EXE_SHA256=.*/TOR_EXE_SHA256=$(printf '0%.0s' {1..64})/" "$fake_pin" > "$tmp/pin-zero.txt"
stage "$tmp/pin-zero.txt" --check-dll "$tmp/halo-zeros.dll" >/dev/null 2>&1 \
  && no "stage-tor.sh took the placeholder pin" || ok "stage-tor.sh refuses the placeholder pin"

python3 -I "$HERE/check_packaging.py" flatpak "$R" "$tmp/app" || fail=1
python3 -I "$HERE/check_packaging.py" iss "$R" || fail=1

if command -v desktop-file-validate >/dev/null; then
  out="$(desktop-file-validate "$HERE/flatpak/app.kryfo.Kryfo.desktop" 2>&1)"
  [ -z "$out" ] && ok "desktop-file-validate" || no "desktop-file-validate: $out"
else
  skip "desktop-file-validate (apt install desktop-file-utils)"
fi
if command -v appstreamcli >/dev/null; then
  out="$(appstreamcli validate --no-net --no-color "$HERE/flatpak/app.kryfo.Kryfo.metainfo.xml" 2>&1)"
  rest="$(echo "$out" | grep -E '^[EW]:')"
  [ -z "$rest" ] && ok "appstreamcli validate" || no "appstreamcli: $rest"
else
  skip "appstreamcli validate (apt install appstream)"
fi
if command -v flatpak-builder >/dev/null; then
  # run from tmp: it leaves a .flatpak-builder dir where it runs
  out="$(cd "$tmp" && flatpak-builder --show-manifest "$HERE/flatpak/app.kryfo.Kryfo.yml" 2>&1 >/dev/null)"
  [ -z "$out" ] && ok "flatpak-builder reads the manifest" || no "flatpak-builder: $out"
  # flatpak checks the id before it looks for the sdk, which is not installed
  id="$(sed -n 's/^id: //p' "$HERE/flatpak/app.kryfo.Kryfo.yml")"
  rv="$(sed -n "s/^runtime-version: '\(.*\)'$/\1/p" "$HERE/flatpak/app.kryfo.Kryfo.yml")"
  out="$(flatpak build-init "$tmp/init" "$id" org.freedesktop.Sdk org.freedesktop.Platform "$rv" 2>&1)"
  echo "$out" | grep -q 'not a valid application name' \
    && no "flatpak refuses the id $id: $out" || ok "flatpak takes the id $id"
else
  skip "flatpak-builder --show-manifest (apt install flatpak-builder)"
fi
command -v iscc >/dev/null || skip "inno setup compile (windows only)"

[ "$fail" = 0 ] && echo "packaging ok" || echo "packaging FAILED"
exit "$fail"
