#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# checks a windows dll or exe the app ships:
#   check-pe.sh <file>             x64, aslr and dep flags, zero timestamp,
#                                  only windows' own dlls imported, no build path,
#                                  a version resource with ProductName Kryfo
#   check-pe.sh --exports <file>   prints the exported names, one per line
# OBJDUMP_W picks the objdump; the host's reads pe files too.
set -euo pipefail
die() { echo "FAIL: $*" >&2; exit 1; }

OBJDUMP_W="${OBJDUMP_W:-x86_64-w64-mingw32-objdump}"
command -v "$OBJDUMP_W" >/dev/null || OBJDUMP_W=objdump
OBJCOPY_W="${OBJCOPY_W:-x86_64-w64-mingw32-objcopy}"
command -v "$OBJCOPY_W" >/dev/null || OBJCOPY_W=objcopy

exports=0
if [ "${1:-}" = --exports ]; then exports=1; shift; fi
f="${1:?usage: check-pe.sh [--exports] <file>}"
[ -f "$f" ] || die "no file $f"
dump="$(TZ=UTC "$OBJDUMP_W" -p "$f")" || die "$OBJDUMP_W cannot read $f"

if [ $exports = 1 ]; then
  awk '/^\[Ordinal\/Name Pointer\] Table/{on=1; next} on && /^\s*\[/{print $NF} on && /^$/{on=0}' <<<"$dump"
  exit 0
fi

grep -q 'file format pei-x86-64' <<<"$dump" || die "$f is not a pe32+ x64 file"
for flag in DYNAMIC_BASE HIGH_ENTROPY_VA NX_COMPAT; do
  grep -qE "^\s+$flag$" <<<"$dump" || die "$f lacks $flag"
done
grep -qE '^Time/Date\s+Thu Jan  1 00:00:00 1970$' <<<"$dump" || die "$f has a pe timestamp"

# windows' own dlls only, so nothing else has to ship beside it
bad=$(sed -n 's/^\s*DLL Name: //p' <<<"$dump" | tr 'A-Z' 'a-z' |
  grep -vxE '(kernel32|ntdll|advapi32|bcrypt|bcryptprimitives|crypt32|ws2_32|userenv|user32|gdi32|shell32|shlwapi|iphlpapi|ole32|oleaut32|secur32|winmm|msvcrt|ucrtbase)\.dll|api-ms-win-[a-z0-9-]+\.dll' || true)
[ -z "$bad" ] || die "$f imports $(echo $bad)"

grep -qaE '/home/|/tmp/|/root/' "$f" && die "a build path is left in $f"

# a version resource (type 16) whose ProductName is Kryfo, as signpath wants
grep -qE '^[0-9a-f]+   Entry: ID: 0x000010,' <<<"$dump" || die "$f has no version resource"
rsrc="$(mktemp)"
trap 'rm -f "$rsrc"' EXIT
"$OBJCOPY_W" -O binary --only-section=.rsrc "$f" "$rsrc" || die "$OBJCOPY_W cannot read $f"
u16() { sed 's/./&\\x00/g' <<<"$1"; }
LC_ALL=C grep -qaP "$(u16 ProductName)(\\x00\\x00)+$(u16 Kryfo)\\x00\\x00" "$rsrc" ||
  die "$f has no ProductName Kryfo in its version resource"
echo "pe ok: $f"
